#!/usr/bin/env python3
"""Route repository changes to the application CI lane.

Every changed path is classified into exactly one category:

* ``application``: application source, delivery contracts, development docs,
  agent instructions, application tests and normal engineering files. These
  run Application CI.
* ``governance``: durable governance, frozen history/provenance, and the
  Foundation Full/Smoke routing machinery. These rely on always-on Foundation
  Smoke and do not select Application CI by location alone.
* ``unknown``: anything unclassified. Unknown paths fail the route job.

Live delivery-state changes are not repository paths after WELL-66: Ready/In
Progress/Blocked/Done, dependencies and sequencing live in Plane. Therefore the
classifier does not need a special "status-only" GitHub lane.

Pull requests are routed from their exact diff. The classifier also supports
push ranges for callers that explicitly use them; Foundation Integrity does
not run on main pushes. Governance paths rely on always-on Foundation Smoke.
Unknown paths, empty ranges and unreadable ranges fail closed by failing the
route job. Ordinary application changes run Application CI and Foundation
Smoke. Superseded PR workflow runs are cancelled by the workflow concurrency
policy. Scheduled nightly hardening runs Foundation Full and
``mix check.deep`` against ``main`` at 02:00 Africa/Johannesburg. GitHub may
delay or drop scheduled starts, so this is the configured target time rather
than a guaranteed runner start time.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import PurePosixPath


# --- Application / normal engineering --------------------------------------

APPLICATION_FILES = frozenset(
    {
        "tools/hex_security_audit.py",
        "tools/check_magic_login_evidence.py",
        "tools/check_password_reset_message_evidence.py",
        ".github/workflows/hex-security-audit.yml",
        "mix.exs",
        "mix.lock",
        ".formatter.exs",
        ".tool-versions",
        ".gitignore",
        ".gitattributes",
        ".credo.exs",
        "README.md",
        "AGENTS.md",
        "docs/README.md",
        ".github/workflows/application-ci.yml",
    }
)

APPLICATION_PREFIXES = (
    ".agents/",
    ".devcore/",
    "assets/",
    "config/",
    "docs/delivery/",
    "docs/development/",
    "docs/superpowers/",
    "lib/",
    "priv/",
    "test/",
    "tests/",
    "tools/architecture/",
    "tools/hex_audit/",
)

# The fast Application CI lane runs for every classified engineering change.
# Dialyzer is reserved for changes that can alter the Elixir application or its
# dependency graph; documentation, agent guidance and regression-test edits do
# not need that slower lane by location alone.
DEEP_APPLICATION_FILES = frozenset({"mix.exs", "mix.lock", ".tool-versions"})
DEEP_APPLICATION_PREFIXES = ("lib/", "priv/")


# --- Governance, history and provenance machinery --------------------------


class RoutingError(ValueError):
    """Raised when a change range cannot be routed safely."""

GOVERNANCE_FILES = frozenset(
    {
        "tools/__init__.py",
        "tools/foundation_integrity_audit.py",
        "tools/foundation_integrity_routing.py",
        "tools/foundation_integrity_smoke.py",
        "tools/run_foundation_full_tests.py",
        ".github/workflows/foundation-integrity.yml",
        ".github/workflows/foundation-full.yml",
        ".github/workflows/nightly-hardening.yml",
        "tests/foundation_test_support.py",
        "tests/test_foundation_full.py",
        "tests/test_foundation_integrity_audit.py",
        "tests/test_historical_scope.py",
    }
)

# Directory ownership is the default. These exact paths implement governance,
# Foundation routing and frozen provenance rather than application behavior.
GOVERNANCE_PREFIXES = (
    "docs/governance/",
    "docs/history/",
    "tools/foundation_integrity_",
)


def classify_path(path: str) -> str:
    """Return ``application``, ``governance`` or ``unknown`` for one repo path."""

    normalized = path.removeprefix("./")
    parts = PurePosixPath(normalized).parts
    if not normalized or normalized.startswith("/") or "\\" in normalized or ".." in parts:
        return "unknown"
    if normalized in GOVERNANCE_FILES or normalized.startswith(GOVERNANCE_PREFIXES):
        return "governance"
    if normalized in APPLICATION_FILES or normalized.startswith(APPLICATION_PREFIXES):
        return "application"
    return "unknown"


def is_application_path(path: str) -> bool:
    """Return True only for normal engineering paths."""

    return classify_path(path) == "application"


def classify_changed_paths(paths: list[str]) -> dict[str, bool]:
    """Route a list of changed paths.

    * Empty change ranges and unknown paths fail closed by rejecting the route.
    * Governance paths do not select Application CI by location alone.
    * Application or engineering paths select Application CI.
    """

    normalized = [path for path in paths if path]
    if not normalized:
        raise RoutingError("change range is empty; refusing to skip routed CI")
    categories = {classify_path(path) for path in normalized}
    if "unknown" in categories:
        unknown = sorted(path for path in normalized if classify_path(path) == "unknown")
        raise RoutingError(f"unclassified changed path(s): {', '.join(unknown)}")
    return {"application_changes": "application" in categories}


def classify_deep_application_changes(paths: list[str]) -> bool:
    """Return whether changed paths need the slower Dialyzer lane."""

    for path in paths:
        normalized = path.removeprefix("./")
        if classify_path(normalized) != "application":
            continue
        if normalized in DEEP_APPLICATION_FILES or normalized.startswith(DEEP_APPLICATION_PREFIXES):
            return True
    return False


def _changed_paths(event_name: str, base_sha: str, head_sha: str, cwd: str) -> list[str]:
    separator = "..." if event_name == "pull_request" else ".."
    result = subprocess.run(
        ["git", "diff", "--no-renames", "--name-only", "-z", f"{base_sha}{separator}{head_sha}"],
        cwd=cwd,
        capture_output=True,
        check=True,
    )
    return [os.fsdecode(path) for path in result.stdout.split(b"\0") if path]


def _validated_event_paths(event_name: str, base_sha: str, head_sha: str, cwd: str) -> list[str]:
    if event_name not in {"pull_request", "push"}:
        raise RoutingError(f"unsupported routing event: {event_name or '<missing>'}")
    if not base_sha or not head_sha:
        raise RoutingError(f"{event_name} change range is missing a base or head SHA")
    try:
        paths = _changed_paths(event_name, base_sha, head_sha, cwd)
    except (OSError, subprocess.CalledProcessError) as exc:
        raise RoutingError(f"could not read {event_name} change range") from exc
    if not paths:
        raise RoutingError(f"{event_name} change range is empty; refusing to skip routed CI")
    return paths


def classify_event(event_name: str, base_sha: str, head_sha: str, cwd: str = ".") -> dict[str, bool]:
    """Classify a GitHub event, failing closed when its range is unknown."""

    return classify_changed_paths(_validated_event_paths(event_name, base_sha, head_sha, cwd))


def classify_deep_event(event_name: str, base_sha: str, head_sha: str, cwd: str = ".") -> bool:
    """Classify whether an event needs the slower Application CI lane.

    Missing, unreadable, empty or unclassified ranges fail the route job. The
    event classifier validates these conditions before selecting any lane.
    """

    paths = _validated_event_paths(event_name, base_sha, head_sha, cwd)
    classify_changed_paths(paths)
    return classify_deep_application_changes(paths)


def classify_hex_audit_changes(paths: list[str]) -> bool:
    """Select security evidence for dependencies, reachability and gate machinery."""
    return not paths or any(
        path in {"mix.exs", "mix.lock", ".tool-versions"}
        or path.startswith(("lib/", "config/", "tools/", ".github/workflows/", "tests/"))
        or path == "test/new_you_web/security/authentication_reachability_test.exs"
        for path in paths
    )


def classify_hex_audit_event(event: str, base: str, head: str, root: str = ".") -> bool:
    """Unknown ranges fail closed. Nightly execution does not use PR routing."""
    if event not in {"pull_request", "push"} or not base or not head:
        return True
    try:
        return classify_hex_audit_changes(_changed_paths(event, base, head, root))
    except (OSError, subprocess.CalledProcessError):
        return True


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--event", default=os.environ.get("GITHUB_EVENT_NAME", ""))
    parser.add_argument("--base-sha", default=os.environ.get("BASE_SHA", ""))
    parser.add_argument("--head-sha", default=os.environ.get("HEAD_SHA", ""))
    parser.add_argument("--root", default=".")
    args = parser.parse_args(argv)

    try:
        decision = classify_event(args.event, args.base_sha, args.head_sha, args.root)
        deep_application_changes = classify_deep_event(
            args.event, args.base_sha, args.head_sha, args.root
        )
    except RoutingError as exc:
        print(f"CI lane routing failed: {exc}", file=sys.stderr)
        return 2
    print(f"application_changes={str(decision['application_changes']).lower()}")
    print(f"deep_application_changes={str(deep_application_changes).lower()}")
    print(f"hex_audit_changes={str(classify_hex_audit_event(args.event, args.base_sha, args.head_sha, args.root)).lower()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
