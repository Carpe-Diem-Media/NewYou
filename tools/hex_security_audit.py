#!/usr/bin/env python3
"""Run a fresh, unsuppressed Hex audit against every locked Hex package."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

HEX_VERSION = "2.6.0"


class AuditError(Exception):
    """Missing, invalid or unacceptable audit evidence. Always fail closed."""


def disposition(evidence: dict, status: int) -> str:
    """Accept only a complete clean SARIF report with no findings or suppressions."""
    try:
        if evidence["version"] != "2.1.0" or len(evidence["runs"]) != 1:
            raise ValueError("SARIF version/run count")

        run = evidence["runs"][0]
        driver = run["tool"]["driver"]
        if driver["name"] != "mix hex.audit" or driver["version"] != HEX_VERSION:
            raise ValueError("unexpected scanner/version")

        results = run["results"]
        rules = driver["rules"]
        if not isinstance(results, list) or not isinstance(rules, list):
            raise ValueError("results/rules must be arrays")
        if status != (1 if results else 0):
            raise AuditError(f"Hex audit failed or exit status contradicts evidence: {status}")
        if not all(isinstance(result, dict) for result in results):
            raise AuditError("Malformed Hex audit finding")
        if any(result.get("suppressions") for result in results):
            raise AuditError("Hex audit finding contains a suppression")
        if results:
            findings = sorted({str(result.get("ruleId", "UNKNOWN")) for result in results})
            raise AuditError(
                "Fresh Hex audit found advisory or retirement findings: " + ", ".join(findings)
            )
        if rules:
            raise ValueError("rules without findings")

        return "CLEAN: fresh unsuppressed Hex audit found no advisories or retirements"
    except (KeyError, TypeError, IndexError, ValueError) as error:
        raise AuditError(f"Invalid or malformed Hex audit evidence: {error}") from error


def locked_dependencies(lock: str) -> str:
    """Accept only the repository's canonical Hex lock shape and pin every Hex package."""
    entries = []
    lines = lock.strip().splitlines()
    if not lines or lines[0] != "%{" or lines[-1] != "}":
        raise AuditError("Invalid committed lock")

    for line in lines[1:-1]:
        # Hex does not scan Git dependencies. Preserve these entries but never
        # fetch or execute them in this package-registry audit.
        if re.fullmatch(
            r'  "[a-z0-9_]+": \{:git, "https://github.com/[a-zA-Z0-9_/.-]+", "[a-f0-9]{40}", \[.*\]\},',
            line,
        ):
            continue

        match = re.fullmatch(
            r'  "([a-z0-9_]+)": \{:hex, :([a-z0-9_]+), "([0-9][a-zA-Z0-9.+-]*)", .*\},',
            line,
        )
        if not match or '], "hexpm", "' not in line:
            raise AuditError("Unsupported lock entry; review required")

        app, package, version = match.groups()
        entries.append(f'{{:{app}, "== {version}", hex: :{package}}}')

    if not entries:
        raise AuditError("Empty lock cannot establish audit coverage")

    return ",\n".join(entries)


def execute(root: Path) -> str:
    """Install pinned Hex, resolve the committed lock and run the real CLI once."""
    lock = (root / "mix.lock").read_text()
    deps = locked_dependencies(lock)

    with tempfile.TemporaryDirectory(prefix="newyou-hex-audit-") as directory:
        work = Path(directory)
        env = {
            key: value
            for key, value in os.environ.items()
            if not key.startswith(("HEX_", "MIX_", "ERL_", "ELIXIR_"))
        }
        env.update(HEX_HOME=str(work / "hex"), MIX_HOME=str(work / "mix"), MIX_ENV="prod")
        (work / "mix.lock").write_text(lock)
        (work / "mix.exs").write_text(
            'defmodule SecurityAudit.MixProject do\n use Mix.Project\n'
            ' def project, do: [app: :security_audit, version: "0.0.0", deps: [\n'
            + deps
            + "\n]]\nend\n"
        )

        commands = [
            (["mix", "local.hex", HEX_VERSION, "--force"], "Pinned Hex installation"),
            (["mix", "deps.get", "--check-locked"], "Committed lock resolution"),
            (["mix", "hex.audit", "--format", "sarif", "--output", "audit.sarif"], "Fresh Hex audit"),
        ]

        for command, label in commands:
            print(f"{label}: {' '.join(command)}", flush=True)
            result = subprocess.run(command, cwd=work, env=env, check=False, timeout=600)
            if label != "Fresh Hex audit" and result.returncode != 0:
                raise AuditError(f"{label} failed with status {result.returncode}")

        if (work / "mix.lock").read_text() != lock:
            raise AuditError("Committed lock changed during audit resolution")

        evidence_file = work / "audit.sarif"
        if not evidence_file.is_file():
            raise AuditError(f"Fresh Hex audit failed to produce evidence, status {result.returncode}")

        evidence = json.loads(evidence_file.read_text())
        print(evidence_file.read_text(), flush=True)
        return disposition(evidence, result.returncode)


def main() -> int:
    try:
        print(execute(Path(__file__).resolve().parents[1]))
        return 0
    except (AuditError, OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f"HEX SECURITY AUDIT FAILURE: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
