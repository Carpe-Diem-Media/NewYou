#!/usr/bin/env python3
"""Fast checks for current governance and delivery routing boundaries."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


DEFAULT_GOVERNANCE_ROUTER = Path("docs/governance/CURRENT_GOVERNANCE_ROUTER.json")
DEFAULT_DELIVERY_ROUTER = Path("docs/delivery/CURRENT_DELIVERY_ROUTER.json")
EXPECTED_GOVERNING_IDS = frozenset(
    {
        "NORTH_STAR_AND_MVP",
        "PLATFORM_PRODUCT_LAW",
        "PRODUCT_DECISIONS",
        "ARCHITECTURE_LAW",
        "DOMAIN_LAW",
        "GOVERNING_ROADMAP",
    }
)
EXPECTED_ARCHITECTURE_REFERENCES = frozenset(
    {"ARCHITECTURE_REQUIREMENTS", "ARCHITECTURE_LAW_REFERENCE", "REFERENCE_FLOW_PRESSURE_TESTS"}
)
EXPECTED_SUPPORTING_IDS = frozenset(
    {
        "PLATFORM_OPERATING_MODEL",
        "FRONTEND_EXPERIENCE_SYSTEM",
        "ENGINEERING_STANDARDS",
        "DELIVERY_GOVERNANCE_STANDARD",
    }
)
EXPECTED_DELIVERY_TYPES = frozenset(
    {"feature_contract", "jit", "proof", "execution", "content_evidence"}
)
FORBIDDEN_GOVERNANCE_KEYS = frozenset(
    {
        "delivery_contracts",
        "feature_contracts",
        "jit",
        "proof",
        "execution_authority",
        "delivery_status",
        "plane",
    }
)
FORBIDDEN_DELIVERY_KEYS = frozenset(
    {
        "governing_documents",
        "architecture_references",
        "supporting_documents",
        "authority_precedence",
        "execution_authority",
        "plane",
    }
)
DOCUMENT_VERSION_PATTERN = re.compile(
    r"^[-*]\s+\*\*Document version:\*\*\s+v?(\d+\.\d+\.\d+)\s*$", re.MULTILINE
)
DOCUMENT_FILE_REFERENCE_PATTERN = re.compile(
    r"(?<![A-Za-z0-9_])((?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+\.(?:md|json))"
)
MARKDOWN_LINK_DESTINATION_PATTERN = re.compile(r"\]\(\s*<?([^\s)>]+)>?")
DOCUMENT_LOCATION_FIELDS = frozenset({"path", "archive_path", "repository_path", "target_path"})
STATUS_VERSION_PATTERN = re.compile(
    r"^[-*]\s+\*\*Document status:\*\*.*?\bv(\d+\.\d+\.\d+)\b", re.MULTILINE
)
STALE_CURRENT_ENTRYPOINT_PATTERNS = (
    r"(?i)proof classification (?:is|remains) not finalised",
    r"(?i)architectural proof classification is next",
    r"(?i)architectural proof classification.*remains unperformed",
)


def _default_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _record(
    report: dict[str, Any],
    name: str,
    ok: bool,
    message: str,
    *,
    path: str | None = None,
) -> None:
    check: dict[str, Any] = {"name": name, "status": "PASS" if ok else "FAIL", "message": message}
    if path is not None:
        check["path"] = path
    report["checks"].append(check)
    if not ok:
        finding = {"check": name, "message": message}
        if path is not None:
            finding["path"] = path
        report["findings"].append(finding)


def _relative_target(root: Path, relative: str, required_root: str) -> tuple[bool, Path]:
    route = Path(relative)
    target = root / route
    try:
        resolved = target.resolve(strict=True)
        resolved.relative_to(root)
    except (OSError, ValueError):
        return False, target
    if (
        route.is_absolute()
        or ".." in route.parts
        or not route.is_relative_to(Path(required_root))
        or "history" in route.parts
        or "archive" in route.parts
        or target.is_symlink()
        or not resolved.is_file()
    ):
        return False, resolved
    # Reject symlinked parent directories as well as symlinked final files.
    cursor = root
    for part in route.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            return False, resolved
    return True, resolved


def _declared_version(text: str) -> str | None:
    match = DOCUMENT_VERSION_PATTERN.search(text)
    if match:
        return match.group(1)
    match = STATUS_VERSION_PATTERN.search(text)
    return match.group(1) if match else None


def _check_hashed_route(
    root: Path,
    report: dict[str, Any],
    entry: dict[str, Any],
    *,
    kind: str,
    required_root: str,
) -> None:
    relative = str(entry.get("repository_path", ""))
    document_id = str(entry.get("document_id", ""))
    safe, target = _relative_target(root, relative, required_root)
    filename_ok = safe and target.name == entry.get("canonical_filename")
    expected_hash = str(entry.get("sha256", ""))
    actual_hash = hashlib.sha256(target.read_bytes()).hexdigest() if safe else None
    hash_ok = safe and len(expected_hash) == 64 and actual_hash == expected_hash
    version_ok = True
    if "semver" in entry:
        try:
            declared = _declared_version(target.read_text(encoding="utf-8")) if safe else None
        except UnicodeDecodeError:
            declared = None
        version_ok = declared == str(entry.get("semver"))
    ok = safe and filename_ok and hash_ok and version_ok
    _record(
        report,
        f"smoke_{kind}_route",
        ok,
        f"{kind} route valid for {document_id}"
        if ok
        else (
            f"invalid {kind} route for {document_id}: safe={safe}, filename={filename_ok}, "
            f"hash={hash_ok}, version={version_ok}"
        ),
        path=relative,
    )


def _load_router(root: Path, report: dict[str, Any], relative: Path, label: str) -> dict[str, Any] | None:
    path = root / relative
    try:
        router = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError, json.JSONDecodeError) as error:
        _record(report, f"smoke_{label}_router_load", False, f"cannot load {label} router: {error}", path=relative.as_posix())
        return None
    _record(
        report,
        f"smoke_{label}_router_identity",
        isinstance(router, dict)
        and router.get("router_id") == f"CURRENT_{label.upper()}_ROUTER"
        and router.get("status") == "CURRENT",
        f"current {label} router identity and status valid"
        if isinstance(router, dict)
        and router.get("router_id") == f"CURRENT_{label.upper()}_ROUTER"
        and router.get("status") == "CURRENT"
        else f"{label} router must identify CURRENT_{label.upper()}_ROUTER with CURRENT status",
        path=relative.as_posix(),
    )
    return router if isinstance(router, dict) else None


def _check_router_boundary(
    report: dict[str, Any], router: dict[str, Any], *, label: str, forbidden: frozenset[str]
) -> None:
    forbidden_found = sorted(forbidden.intersection(router))
    _record(
        report,
        f"smoke_{label}_router_boundary",
        not forbidden_found,
        f"{label} router stays within its semantic boundary"
        if not forbidden_found
        else f"{label} router contains fields owned by another authority boundary: {forbidden_found}",
    )


def _check_current_routing_guidance(
    root: Path,
    report: dict[str, Any],
    governance: dict[str, Any] | None,
    delivery: dict[str, Any] | None,
) -> None:
    guidance_files = (
        ("AGENTS.md", "smoke_agents_architecture_references"),
        (
            "docs/development/chatgpt-project-master-gate-instructions.md",
            "smoke_master_gate_architecture_references",
        ),
    )
    for relative, check in guidance_files:
        path = root / relative
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            text = ""
        valid = "architecture_references" in text and "deep_reference_documents" not in text
        _record(
            report,
            check,
            valid,
            f"{relative} names the current architecture_references field"
            if valid
            else f"{relative} must route deep Architecture/source tracing through architecture_references",
            path=relative,
        )

    supporting = governance.get("supporting_documents", []) if governance else []
    standard_route = next(
        (
            entry
            for entry in supporting
            if isinstance(entry, dict)
            and entry.get("document_id") == "DELIVERY_GOVERNANCE_STANDARD"
        ),
        None,
    )
    standard_path = root / str(standard_route.get("repository_path", "")) if standard_route else None
    try:
        standard = standard_path.read_text(encoding="utf-8") if standard_path else ""
    except OSError:
        standard = ""
    routing_section = standard.partition("## 8. Current routing and historical integrity")[2].partition("## 9.")[0]
    ci_section = standard.partition("## 9. CI topology")[2].partition("## 10.")[0]
    routing_valid = all(
        token in routing_section
        for token in (
            "docs/governance/CURRENT_GOVERNANCE_ROUTER.json",
            "docs/delivery/CURRENT_DELIVERY_ROUTER.json",
            "docs/history/",
            "Plane",
        )
    ) and "deep_reference_documents" not in routing_section
    ci_valid = all(
        token in ci_section
        for token in (
            "both current routers",
            "docs/governance/**",
            "docs/history/**",
            "docs/delivery/**",
            "Foundation Full runs only through the scheduled Nightly hardening workflow",
            "no pull request or manual-dispatch trigger",
            "Unknown paths, empty ranges and unreadable ranges fail the route job",
            "GitHub scheduled starts are best effort",
        )
    )
    _record(
        report,
        "smoke_delivery_governance_router_model",
        routing_valid and ci_valid,
        "current Delivery Governance Standard describes separate routers, Plane/history boundaries and CI lanes"
        if routing_valid and ci_valid
        else "current Delivery Governance Standard must describe separate governance/delivery routers, Plane/history boundaries and current CI lanes",
        path=standard_route.get("repository_path") if standard_route else "docs/governance/CURRENT_GOVERNANCE_ROUTER.json",
    )

    identity_route = next(
        (
            entry
            for entry in (delivery.get("delivery_contracts", []) if delivery else [])
            if isinstance(entry, dict) and entry.get("document_id") == "FP001_IDENTITY_ACCESS_JIT"
        ),
        None,
    )
    identity_path = root / str(identity_route.get("repository_path", "")) if identity_route else None
    try:
        identity = identity_path.read_text(encoding="utf-8") if identity_path else ""
    except OSError:
        identity = ""
    historical_identity_paths = (
        "docs/history/platform/archive/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.2.0.md",
        "docs/history/platform/archive/identity_promotions/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.1.4.md",
    )
    identity_links_valid = bool(identity_route) and all(
        reference in identity and (root / reference).is_file()
        for reference in historical_identity_paths
    )
    _record(
        report,
        "smoke_identity_historical_routes",
        identity_links_valid,
        "current Identity JIT dossier resolves its preserved historical candidates"
        if identity_links_valid
        else "current Identity JIT dossier must point to both preserved candidates under docs/history",
        path=identity_route.get("repository_path") if identity_route else "docs/delivery/CURRENT_DELIVERY_ROUTER.json",
    )


def _without_fenced_code_blocks(text: str) -> str:
    visible: list[str] = []
    fence_character: str | None = None
    fence_length = 0

    for line in text.splitlines(keepends=True):
        fence = re.match(r"^\s{0,3}(`{3,}|~{3,})", line)
        if fence_character is None:
            if fence:
                marker = fence.group(1)
                fence_character = marker[0]
                fence_length = len(marker)
                visible.append("\n" if line.endswith("\n") else "")
            else:
                visible.append(line)
            continue

        if fence:
            marker = fence.group(1)
            if marker[0] == fence_character and len(marker) >= fence_length:
                fence_character = None
                fence_length = 0
        visible.append("\n" if line.endswith("\n") else "")

    return "".join(visible)


def _json_document_references(value: Any, key: str = "") -> list[str]:
    references: list[str] = []
    if isinstance(value, dict):
        for child_key, child in value.items():
            if child_key in DOCUMENT_LOCATION_FIELDS and isinstance(child, str):
                references.append(child)
            elif child_key != "original_path":
                references.extend(_json_document_references(child, child_key))
    elif isinstance(value, list):
        for child in value:
            references.extend(_json_document_references(child, key))
    return references


def _document_reference_resolves(root: Path, source: Path, reference: str) -> bool:
    route = Path(reference)
    if route.is_absolute() or reference.startswith(("http://", "https://", "mailto:", "#")):
        return False

    # These are command-generated outputs, not links into the checked-in repository.
    if route.parts and route.parts[0] == "tmp":
        return True

    repository_rooted = "docs" in route.parts
    if repository_rooted:
        if ".." in route.parts:
            return False
        candidates = (root / route,)
    else:
        candidates = (source.parent / route, root / route)

    for target in candidates:
        try:
            resolved = target.resolve(strict=True)
            resolved.relative_to(root)
        except (OSError, ValueError):
            continue
        if not resolved.exists():
            continue

        if repository_rooted:
            cursor = root
            for part in route.parts:
                cursor = cursor / part
                if cursor.is_symlink():
                    break
            else:
                return True
        else:
            return True

    return False


def _check_active_document_references(root: Path, report: dict[str, Any]) -> None:
    missing: set[str] = set()
    for semantic_root in ("docs/governance", "docs/delivery", "docs/development"):
        directory = root / semantic_root
        if not directory.is_dir():
            missing.add(f"{semantic_root}/ (semantic root is missing)")
            continue
        sources = sorted((*directory.rglob("*.md"), *directory.rglob("*.json")))
        for source in sources:
            try:
                text = source.read_text(encoding="utf-8")
            except OSError:
                missing.add(f"{source.relative_to(root)} (could not be read)")
                continue

            if source.suffix == ".json":
                try:
                    payload = json.loads(text)
                except json.JSONDecodeError:
                    missing.add(f"{source.relative_to(root)} (invalid JSON)")
                    continue
                # PR change records preserve locators at their historical base/head.
                # Deleted/renamed source is valid snapshot evidence, not a live
                # documentation link. CI regenerates the exact mechanical record.
                # Keep checking any other reference fields and every current map.
                if (source.relative_to(root).parent == Path("docs/development/knowledge/history")
                        and isinstance(payload, dict)
                        and type(payload.get("schema_version")) is int
                        and payload["schema_version"] == 1
                        and type(payload.get("pr")) is int and payload["pr"] > 0
                        and source.stem == f"pr-{payload['pr']}"):
                    payload = {key: value for key, value in payload.items()
                               if key not in ("files", "symbols")}
                references = _json_document_references(payload)
            else:
                navigable_text = _without_fenced_code_blocks(text)
                references = DOCUMENT_FILE_REFERENCE_PATTERN.findall(navigable_text)
                references.extend(
                    destination
                    for destination in MARKDOWN_LINK_DESTINATION_PATTERN.findall(navigable_text)
                    if destination.lower().endswith((".md", ".json"))
                )

            for reference in sorted(set(references)):
                if not _document_reference_resolves(root, source, reference):
                    missing.add(f"{source.relative_to(root)} → {reference}")

    _record(
        report,
        "smoke_active_document_references",
        not missing,
        "repository document references resolve in current semantic roots"
        if not missing
        else "current documentation contains unresolved repository file references: "
        + "; ".join(sorted(missing)[:8]),
    )


def run_smoke_audit(
    root: Path,
    governance_router_path: Path = DEFAULT_GOVERNANCE_ROUTER,
    delivery_router_path: Path = DEFAULT_DELIVERY_ROUTER,
) -> dict[str, Any]:
    """Validate both current routers, semantic roots, entrypoint and CI topology."""

    root = Path(root).resolve()
    governance_router_path = Path(governance_router_path)
    delivery_router_path = Path(delivery_router_path)
    if not governance_router_path.is_absolute():
        governance_router_path = root / governance_router_path
    if not delivery_router_path.is_absolute():
        delivery_router_path = root / delivery_router_path

    report: dict[str, Any] = {
        "status": "PASS",
        "assertion_count": 0,
        "counts": {},
        "checks": [],
        "findings": [],
    }

    governance_relative = governance_router_path.relative_to(root) if governance_router_path.is_relative_to(root) else Path(str(governance_router_path))
    delivery_relative = delivery_router_path.relative_to(root) if delivery_router_path.is_relative_to(root) else Path(str(delivery_router_path))
    governance = _load_router(root, report, governance_relative, "governance")
    delivery = _load_router(root, report, delivery_relative, "delivery")

    if governance is not None:
        _check_router_boundary(report, governance, label="governance", forbidden=FORBIDDEN_GOVERNANCE_KEYS)
        precedence_ok = governance.get("authority_precedence") == [
            "product", "architecture", "domain", "roadmap", "supporting"
        ]
        _record(
            report,
            "smoke_governance_precedence",
            precedence_ok,
            "governance router preserves authority precedence"
            if precedence_ok
            else "governance router authority_precedence must be Product, Architecture, Domain, Roadmap, supporting",
        )

        collections = (
            ("governing_documents", EXPECTED_GOVERNING_IDS),
            ("architecture_references", EXPECTED_ARCHITECTURE_REFERENCES),
            ("supporting_documents", EXPECTED_SUPPORTING_IDS),
        )
        for collection, expected_ids in collections:
            entries = governance.get(collection, [])
            ids = {str(entry.get("document_id")) for entry in entries if isinstance(entry, dict)} if isinstance(entries, list) else set()
            valid = ids == expected_ids
            _record(
                report,
                f"smoke_governance_{collection}",
                valid,
                f"governance {collection} inventory valid"
                if valid
                else f"governance {collection} must contain exactly {sorted(expected_ids)}; got {sorted(ids)}",
            )
            for entry in entries if isinstance(entries, list) else []:
                if isinstance(entry, dict):
                    _check_hashed_route(root, report, entry, kind="governance", required_root="docs/governance")

    if delivery is not None:
        _check_router_boundary(report, delivery, label="delivery", forbidden=FORBIDDEN_DELIVERY_KEYS)
        contracts = delivery.get("delivery_contracts", [])
        contract_types = {
            str(entry.get("contract_type")) for entry in contracts if isinstance(entry, dict)
        } if isinstance(contracts, list) else set()
        types_ok = EXPECTED_DELIVERY_TYPES.issubset(contract_types)
        _record(
            report,
            "smoke_delivery_contract_types",
            types_ok,
            "delivery router covers Feature, JIT, proof, execution and content evidence"
            if types_ok
            else f"delivery router is missing contract types: {sorted(EXPECTED_DELIVERY_TYPES - contract_types)}",
        )
        ids = [str(entry.get("document_id")) for entry in contracts if isinstance(entry, dict)] if isinstance(contracts, list) else []
        unique_ids = len(ids) == len(set(ids)) and bool(ids)
        _record(
            report,
            "smoke_delivery_inventory",
            unique_ids,
            "delivery router has a non-empty unique contract inventory"
            if unique_ids
            else "delivery router contracts must be a non-empty list with unique document_id values",
        )
        for entry in contracts if isinstance(contracts, list) else []:
            if isinstance(entry, dict):
                _check_hashed_route(root, report, entry, kind="delivery", required_root="docs/delivery")

    _check_active_document_references(root, report)
    _check_current_routing_guidance(root, report, governance, delivery)

    required_paths = (
        "AGENTS.md",
        "docs/README.md",
        "docs/governance/README.md",
        "docs/delivery/README.md",
        "docs/history/README.md",
        "docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json",
        "docs/history/02_OPEN_WORK_v1.2.90.md",
        "docs/development/foundation-integrity-merge-gate.md",
    )
    for relative in required_paths:
        path = root / relative
        _record(
            report,
            "smoke_required_file",
            path.is_file() and not path.is_symlink(),
            f"required current/history entrypoint exists: {relative}"
            if path.is_file() and not path.is_symlink()
            else f"required current/history entrypoint is missing or not a regular file: {relative}",
            path=relative,
        )

    entrypoint_path = root / "docs/README.md"
    entrypoint = entrypoint_path.read_text(encoding="utf-8") if entrypoint_path.is_file() else ""
    entrypoint_tokens = ("governance/", "delivery/", "development/", "history/", "Plane")
    entrypoint_ok = all(token.lower() in entrypoint.lower() for token in entrypoint_tokens)
    _record(
        report,
        "smoke_documentation_entrypoint",
        entrypoint_ok,
        "documentation entrypoint describes the semantic roots and Plane"
        if entrypoint_ok
        else "documentation entrypoint must describe governance, delivery, development, history and Plane",
        path="docs/README.md",
    )
    stale_current_prose = [
        pattern
        for pattern in STALE_CURRENT_ENTRYPOINT_PATTERNS
        if re.search(pattern, entrypoint)
    ]
    _record(
        report,
        "smoke_documentation_entrypoint_current_prose",
        not stale_current_prose,
        "documentation entrypoint has no stale current proof-classification claims"
        if not stale_current_prose
        else f"documentation entrypoint contains stale current proof-classification claims: {stale_current_prose}",
        path="docs/README.md",
    )

    workflow_path = root / ".github/workflows/foundation-integrity.yml"
    workflow = workflow_path.read_text(encoding="utf-8") if workflow_path.is_file() else ""
    smoke_match = re.search(r"(?ms)^  foundation-smoke:\n(.*?)(?=^  [a-zA-Z0-9_-]+:\n|\Z)", workflow)
    aggregate_match = re.search(r"(?m)^    needs: \[([^\]]+)\]$", workflow)
    aggregate_needs = {item.strip() for item in aggregate_match.group(1).split(",")} if aggregate_match else set()
    nightly_path = root / ".github/workflows/nightly-hardening.yml"
    nightly = nightly_path.read_text(encoding="utf-8") if nightly_path.is_file() else ""
    full_path = root / ".github/workflows/foundation-full.yml"
    full = full_path.read_text(encoding="utf-8") if full_path.is_file() else ""
    full_callers = [
        candidate.name
        for candidate in (root / ".github/workflows").glob("*.yml")
        if "uses: ./.github/workflows/foundation-full.yml"
        in candidate.read_text(encoding="utf-8")
    ]
    topology_ok = (
        smoke_match is not None
        and re.search(r"(?m)^    if:", smoke_match.group(1)) is None
        and "foundation-full.yml" not in workflow
        and "foundation_full" not in workflow
        and "hex-security-audit:" in workflow
        and "AUDIT_RESULT: ${{ needs.hex-security-audit.result }}" in workflow
        and "application-ci:" in workflow
        and aggregate_needs == {"route", "foundation-smoke", "application-ci", "hex-security-audit"}
        and "workflow_call:" in full
        and "workflow_dispatch:" not in full
        and "workflow_dispatch:" not in nightly
        and "pull_request:" not in nightly
        and "push:" not in nightly
        and "    - cron: '0 2 * * *'\n      timezone: Africa/Johannesburg" in nightly
        and "uses: ./.github/workflows/foundation-full.yml" in nightly
        and full_callers == ["nightly-hardening.yml"]
    )
    _record(
        report,
        "smoke_merge_gate_topology",
        topology_ok,
        "Foundation Smoke is always-on; Foundation Full runs only from the 02:00 SAST nightly; required aggregate waits on Smoke and applicable Application CI"
        if topology_ok
        else "merge-gate topology must keep Smoke always-on, route Foundation Full only from the nightly schedule, and exclude Full from the PR workflow and required aggregate",
        path=".github/workflows/foundation-integrity.yml",
    )

    report["counts"] = {
        "governing_documents": len(governance.get("governing_documents", [])) if governance else 0,
        "architecture_references": len(governance.get("architecture_references", [])) if governance else 0,
        "supporting_documents": len(governance.get("supporting_documents", [])) if governance else 0,
        "delivery_contracts": len(delivery.get("delivery_contracts", [])) if delivery else 0,
    }
    report["assertion_count"] = len(report["checks"])
    report["status"] = "PASS" if not report["findings"] else "FAIL"
    return report


def _print_human(report: dict[str, Any]) -> None:
    print(f"Foundation Smoke: {report['status']} ({report['assertion_count']} assertions)")
    for finding in report["findings"]:
        location = f" [{finding.get('path')}]" if finding.get("path") else ""
        print(f"- {finding['check']}{location}: {finding['message']}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=None)
    parser.add_argument("--governance-router", type=Path, default=DEFAULT_GOVERNANCE_ROUTER)
    parser.add_argument("--delivery-router", type=Path, default=DEFAULT_DELIVERY_ROUTER)
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args(argv)
    root = args.root or _default_root()
    report = run_smoke_audit(root, args.governance_router, args.delivery_router)
    if args.as_json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        _print_human(report)
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
