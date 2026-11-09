"""Validate WELL-98's non-authoritative password-reset message evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


BASE_SHA = "022a0eb1bb93b5b84a722d132e0ee1d084fc3a67"
PACKET_PATH = Path(
    "docs/delivery/content-evidence/content_media/password_reset_messages/"
    "PASSWORD_RESET_MESSAGE_EVIDENCE_PACKET_v0.1.0.json"
)
DELIVERY_ROUTER_PATH = Path("docs/delivery/CURRENT_DELIVERY_ROUTER.json")
GOVERNANCE_ROUTER_PATH = Path("docs/governance/CURRENT_GOVERNANCE_ROUTER.json")
REGISTRY_PATH = Path("docs/delivery/content-evidence/copy/COPY_REGISTRY.json")
CHECKSUMS_PATH = Path("docs/delivery/content-evidence/copy/WORKSPACE_CHECKSUMS.tsv")
COPY_WORKSPACE_FILES = {
    "COPY_INVENTORY.md": Path("docs/delivery/content-evidence/copy/COPY_INVENTORY.md"),
    "COPY_REGISTRY.json": REGISTRY_PATH,
    "REVIEW_REPORT.md": Path("docs/delivery/content-evidence/copy/REVIEW_REPORT.md"),
}

ALLOWED_SCOPE = [
    "local development",
    "automated tests",
    "development environments",
    "bounded P8-12 Phase-8 proof",
]
PROHIBITED_SCOPE = [
    "production",
    "public release",
    "paid pilot",
    "real-participant delivery",
    "Phase 9",
]
LOCALES = [
    {
        "locale": "en",
        "id": "NEWYOU-CONTENTTRANSLATIONVERSION-PASSWORD-RESET-MESSAGE-EMAIL-EN-V1",
        "path": (
            "docs/delivery/content-evidence/content_media/password_reset_messages/"
            "NEWYOU-PASSWORD-RESET-MESSAGE-EMAIL-EN-V1.txt"
        ),
        "proposed_subject_key": "identity.password_reset.email.subject",
        "proposed_body_key": "identity.password_reset.email.body",
    },
    {
        "locale": "af",
        "id": "NEWYOU-CONTENTTRANSLATIONVERSION-PASSWORD-RESET-MESSAGE-EMAIL-AF-V2",
        "path": (
            "docs/delivery/content-evidence/content_media/password_reset_messages/"
            "NEWYOU-PASSWORD-RESET-MESSAGE-EMAIL-AF-V2.txt"
        ),
        "proposed_subject_key": "identity.password_reset.email.subject",
        "proposed_body_key": "identity.password_reset.email.body",
    },
]
EXPECTED_TOKENS = [
    {
        "literal": "{{platform_name}}",
        "type": "platform_display_name",
        "allowed_fields": ["subject", "body"],
        "source": "Approved non-secret platform configuration; single-line plain text.",
    },
    {
        "literal": "{{password_reset_link}}",
        "type": "identity_password_reset_url",
        "allowed_fields": ["body"],
        "source": (
            "Identity-issued purpose-bound password-reset proof URL; literal token only "
            "in source evidence, rendered value excluded."
        ),
    },
]
EXPECTED_PROPOSALS = [
    {
        "document_id": "PLATFORM_PRODUCT_LAW",
        "path": "docs/governance/product/proposals/well-98/00_PLATFORM_v1.15.0_PROPOSED.md",
        "predecessor": "docs/governance/product/00_PLATFORM_v1.14.0.md",
        "predecessor_sha256": "bcec310103319441d12c6efae1c7c779a013a503b3831da630abb4a55187314b",
        "version": "1.15.0",
    },
    {
        "document_id": "PRODUCT_DECISIONS",
        "path": "docs/governance/product/proposals/well-98/01_DECISIONS_v1.15.0_PROPOSED.md",
        "predecessor": "docs/governance/product/01_DECISIONS_v1.14.0.md",
        "predecessor_sha256": "d97cb742deefa744279b47686bf5148cceea4b95839fe5b32ad6bbe7d2b6b1fd",
        "version": "1.15.0",
    },
]
EXPECTED_CURRENT_GOVERNANCE = {
    "PLATFORM_PRODUCT_LAW": {
        "repository_path": "docs/governance/product/00_PLATFORM_v1.14.0.md",
        "sha256": "bcec310103319441d12c6efae1c7c779a013a503b3831da630abb4a55187314b",
        "semver": "1.14.0",
    },
    "PRODUCT_DECISIONS": {
        "repository_path": "docs/governance/product/01_DECISIONS_v1.14.0.md",
        "sha256": "d97cb742deefa744279b47686bf5148cceea4b95839fe5b32ad6bbe7d2b6b1fd",
        "semver": "1.14.0",
    },
}
EXPECTED_COPY_CHECKSUM_NAME = "COPY_REGISTRY.json"
PINNED_COPY_REGISTRY_SHA256 = "744f1a34ad80c0158c86395f3f66227622714969526f5e9d69ee62314fd48635"
EXPECTED_CONTENT_ITEM_ID = "NEWYOU-CONTENTITEM-PASSWORD-RESET-MESSAGE-EMAIL"
EXPECTED_CONTENT_VERSION_ID = "NEWYOU-CONTENTVERSION-PASSWORD-RESET-MESSAGE-EMAIL-V1"
EXPECTED_FORMAT_ID = "password-reset-message-subject-body-text-v1"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_digest(value: Any) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return sha256(encoded)


def load_json(root: Path, relative: Path, findings: list[str]) -> Any:
    path = root / relative
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        findings.append(f"cannot read {relative}: {exc}")
        return {}


def record(condition: bool, finding: str, findings: list[str]) -> None:
    if not condition:
        findings.append(finding)


def safe_source_path(root: Path, relative: str, findings: list[str]) -> Path | None:
    candidate = Path(relative)
    if candidate.is_absolute() or ".." in candidate.parts:
        findings.append(f"artifact path escapes repository: {relative}")
        return None
    path = root / candidate
    if path.is_symlink() or not path.is_file():
        findings.append(f"artifact is missing or is a symlink: {relative}")
        return None
    try:
        path.resolve().relative_to(root.resolve())
    except ValueError:
        findings.append(f"artifact resolves outside repository: {relative}")
        return None
    return path


def check_proposals(root: Path, packet: dict[str, Any], findings: list[str]) -> None:
    proposal_docs = packet.get("product_proposal", {}).get("documents", [])
    record(len(proposal_docs) == len(EXPECTED_PROPOSALS), "exact Product proposal pair required", findings)
    for expected, actual in zip(EXPECTED_PROPOSALS, proposal_docs):
        record(
            all(actual.get(key) == value for key, value in expected.items()),
            f"Product proposal binding mismatch: {expected['document_id']}",
            findings,
        )
        proposal_path = safe_source_path(root, expected["path"], findings)
        predecessor_path = safe_source_path(root, expected["predecessor"], findings)
        if proposal_path:
            proposed_hash = sha256(proposal_path.read_bytes())
            record(
                actual.get("sha256") == proposed_hash,
                f"Product proposal digest mismatch: {expected['document_id']}",
                findings,
            )
        if predecessor_path:
            record(
                sha256(predecessor_path.read_bytes()) == expected["predecessor_sha256"],
                f"Product proposal predecessor changed: {expected['document_id']}",
                findings,
            )

    governance = load_json(root, GOVERNANCE_ROUTER_PATH, findings)
    governing_docs = {
        item.get("document_id"): item for item in governance.get("governing_documents", [])
    }
    proposed_paths = {item["path"] for item in EXPECTED_PROPOSALS}
    for document_id, expected in EXPECTED_CURRENT_GOVERNANCE.items():
        current = governing_docs.get(document_id, {})
        record(
            all(current.get(key) == value for key, value in expected.items()),
            f"current governance route changed: {document_id}",
            findings,
        )
        actual_path = current.get("repository_path")
        record(
            actual_path not in proposed_paths,
            f"unapproved Product proposal is selected as current: {document_id}",
            findings,
        )
        path = safe_source_path(root, expected["repository_path"], findings)
        if path:
            record(
                sha256(path.read_bytes()) == expected["sha256"],
                f"current Product source changed: {document_id}",
                findings,
            )
    record(
        packet.get("product_proposal", {}).get("current_governance_routes_unchanged") is True,
        "candidate must leave current governance routes unchanged",
        findings,
    )


def check_router(root: Path, packet: dict[str, Any], packet_bytes: bytes, findings: list[str]) -> None:
    router = load_json(root, DELIVERY_ROUTER_PATH, findings)
    routes = [
        item for item in router.get("delivery_contracts", [])
        if item.get("document_id") == "PASSWORD_RESET_MESSAGE_CANDIDATE_EVIDENCE"
    ]
    record(len(routes) == 1, "exactly one candidate delivery-router entry required", findings)
    if routes:
        route = routes[0]
        record(
            route.get("repository_path") == PACKET_PATH.as_posix()
            and route.get("canonical_filename") == PACKET_PATH.name
            and route.get("contract_type") == "content_evidence"
            and route.get("status") == "CANDIDATE_NOT_APPROVED"
            and route.get("sha256") == sha256(packet_bytes),
            "delivery-router candidate binding or digest mismatch",
            findings,
        )


def check_registry(root: Path, packet: dict[str, Any], findings: list[str]) -> dict[str, dict[str, Any]]:
    registry = load_json(root, REGISTRY_PATH, findings)
    entries_list = registry.get("entries", [])
    entries = {entry.get("key"): entry for entry in entries_list}
    record(
        len(entries) == len(entries_list),
        "copy registry contains duplicate semantic keys",
        findings,
    )
    recovery = entries.get("identity.recovery.family", {})
    record(
        recovery.get("readiness") == "JIT"
        and recovery.get("development_eligible") is False
        and recovery.get("en", {}).get("status") == "missing"
        and recovery.get("af", {}).get("status") == "missing",
        "password-recovery UI must remain separate JIT copy",
        findings,
    )
    record(
        registry.get("workspace_version") == "0.3.0",
        "P8-05 runtime copy registry workspace version changed",
        findings,
    )
    proposed_keys = {
        item[key]
        for item in LOCALES
        for key in ("proposed_subject_key", "proposed_body_key")
    }
    record(
        not proposed_keys.intersection(entries),
        "candidate copy keys must remain outside the P8-05 runtime registry",
        findings,
    )

    checksums = load_checksum_map(root, findings)
    for checksum_name, relative_path in COPY_WORKSPACE_FILES.items():
        source_file = safe_source_path(root, relative_path.as_posix(), findings)
        if not source_file:
            continue
        actual_digest = sha256(source_file.read_bytes())
        record(
            checksums.get(checksum_name) == actual_digest,
            f"copy workspace checksum mismatch: {checksum_name}",
            findings,
        )
        if checksum_name == EXPECTED_COPY_CHECKSUM_NAME:
            record(
                actual_digest == PINNED_COPY_REGISTRY_SHA256,
                "P8-05 runtime copy registry bytes changed",
                findings,
            )
    return entries


def load_checksum_map(root: Path, findings: list[str]) -> dict[str, str]:
    path = root / CHECKSUMS_PATH
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as exc:
        findings.append(f"cannot read copy workspace checksums: {exc}")
        return {}
    record(bool(lines) and lines[0] == "sha256\tpath", "copy checksum header mismatch", findings)
    checksums: dict[str, str] = {}
    for row in lines[1:]:
        fields = row.split("\t", 1)
        if len(fields) == 2:
            checksums[fields[1]] = fields[0]
    return checksums


def check_artifacts(
    root: Path,
    packet: dict[str, Any],
    findings: list[str],
) -> None:
    versions = packet.get("locale_versions", [])
    locales = [version.get("locale") for version in versions]
    record(locales == ["en", "af"], "EN and AF locale binding must be exactly [en, af]", findings)
    ids = [version.get("id") for version in versions]
    record(len(ids) == len(set(ids)), "content translation version identities must be unique", findings)
    record(
        packet.get("content_item_id") == EXPECTED_CONTENT_ITEM_ID
        and packet.get("content_version_id") == EXPECTED_CONTENT_VERSION_ID,
        "content item and version identity mismatch",
        findings,
    )

    tokens = packet.get("token_allowlist", [])
    record(tokens == EXPECTED_TOKENS, "approved template token allowlist mismatch", findings)
    record(
        packet.get("token_contract_sha256") == canonical_digest(tokens),
        "token contract digest mismatch",
        findings,
    )
    token_fields = {item["literal"]: set(item["allowed_fields"]) for item in EXPECTED_TOKENS}

    for index, expected in enumerate(LOCALES):
        if index >= len(versions):
            continue
        version = versions[index]
        record(
            version.get("id") == expected["id"],
            f"canonical {expected['locale'].upper()} translation identity changed",
            findings,
        )
        record(
            version.get("proposed_copy_keys")
            == {
                "subject": expected["proposed_subject_key"],
                "body": expected["proposed_body_key"],
            },
            f"proposed semantic copy-key binding mismatch: {expected['locale']}",
            findings,
        )
        artifact = version.get("artifact", {})
        record(
            artifact.get("path") == expected["path"],
            f"canonical {expected['locale'].upper()} artifact path changed",
            findings,
        )
        path = safe_source_path(root, artifact.get("path", ""), findings)
        if path is None:
            continue
        raw = path.read_bytes()
        actual_digest = sha256(raw)
        record(
            artifact.get("bytes") == len(raw) and artifact.get("sha256") == actual_digest,
            f"artifact digest mismatch: {expected['locale']}",
            findings,
        )
        record(not raw.startswith(b"\xef\xbb\xbf"), f"UTF-8 BOM is prohibited: {expected['locale']}", findings)
        record(b"\r" not in raw, f"CR line ending is prohibited: {expected['locale']}", findings)
        record(
            len(raw) - len(raw.rstrip(b"\n")) == 1,
            f"artifact must have exactly one terminal LF: {expected['locale']}",
            findings,
        )
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            findings.append(f"artifact is not valid UTF-8: {expected['locale']}")
            continue

        if not text.startswith("subject: ") or "\n\n" not in text:
            findings.append(f"subject/body serialization mismatch: {expected['locale']}")
            continue
        subject_line, body_text = text.split("\n\n", 1)
        subject = subject_line.removeprefix("subject: ")
        if "\n" in subject or not subject or not body_text.endswith("\n"):
            findings.append(f"subject/body serialization mismatch: {expected['locale']}")
            continue
        body = body_text[:-1]
        subject_bytes = subject.encode("utf-8")
        body_bytes = body_text.encode("utf-8")
        expected_subject_meta = {
            "offset": len("subject: ".encode("utf-8")),
            "bytes": len(subject_bytes),
            "sha256": sha256(subject_bytes),
        }
        expected_body_meta = {
            "offset": len(subject_line.encode("utf-8")) + 2,
            "bytes": len(body_bytes),
            "sha256": sha256(body_bytes),
        }
        record(version.get("subject") == expected_subject_meta, f"subject binding mismatch: {expected['locale']}", findings)
        record(version.get("body") == expected_body_meta, f"body binding mismatch: {expected['locale']}", findings)
        compact = raw.replace(b"\n\n", b"\n")
        record(
            version.get("contiguous_rendering") == {"bytes": len(compact), "sha256": sha256(compact)},
            f"contiguous rendering binding mismatch: {expected['locale']}",
            findings,
        )

        fields = {"subject": subject, "body": body}
        for field, value in fields.items():
            found = re.findall(r"\{\{[^{}]*\}\}", value)
            unknown = set(found) - set(token_fields)
            missing = {token for token, allowed in token_fields.items() if field in allowed} - set(found)
            disallowed = {token for token in found if field not in token_fields.get(token, set())}
            if unknown or missing or disallowed:
                findings.append(
                    f"unknown or missing template token: {expected['locale']}/{field}"
                )
        if "{{" in text or "}}" in text:
            found_all = re.findall(r"\{\{[^{}]*\}\}", text)
            if text.count("{{") != len(found_all) or text.count("}}") != len(found_all):
                findings.append(f"malformed template token: {expected['locale']}")
        if re.search(r"(?i)https?://|\bwww\.|\bBearer\s+\S+|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", text):
            findings.append(f"rendered URL, bearer value or email address in source: {expected['locale']}")
        if re.search(r"(?i)\b(?:password|passphrase|secret|credential|api[-_ ]?key|token)\s*[:=]\s*\S+", text):
            findings.append(f"credential value in source: {expected['locale']}")
        if re.search(r"(?i)\b(?:account|user)[-_ ]?(?:id|number)\s*[:=]", text):
            findings.append(f"personal identifier in source: {expected['locale']}")



def check_candidate_authority(packet: dict[str, Any], findings: list[str]) -> None:
    record(packet.get("status") == "CANDIDATE_NOT_APPROVED", "candidate status must remain unapproved", findings)
    record(packet.get("owner") == "Content & Media", "Content & Media must own the versions", findings)
    record(
        packet.get("candidate_base", {}).get("main_sha") == BASE_SHA,
        "candidate base SHA mismatch",
        findings,
    )
    record(
        packet.get("product_proposal", {}).get("status") == "PROPOSED_NON_AUTHORITATIVE"
        and packet.get("product_proposal", {}).get("recommended_type") == "password_reset_message"
        and packet.get("product_proposal", {}).get("recommended_wording_risk") == "editorial_low_risk"
        and packet.get("product_proposal", {}).get("identity_security_risk") == "HIGH",
        "candidate classification proposal mismatch",
        findings,
    )
    scope = packet.get("scope", {})
    record(scope.get("allowed") == ALLOWED_SCOPE, "development applicability scope mismatch", findings)
    record(scope.get("prohibited") == PROHIBITED_SCOPE, "prohibited applicability scope mismatch", findings)
    record(
        packet.get("eligibility") == {
            "development": False,
            "automated_tests": False,
            "development_environments": False,
            "bounded_p8_12_proof": False,
            "runtime_release": False,
            "production": False,
            "public_release": False,
            "paid_pilot": False,
            "real_participant_delivery": False,
            "phase_9": False,
        },
        "candidate must remain ineligible",
        findings,
    )
    binding = packet.get("binding", {})
    record(
        binding.get("resolution") == "exact IDs only"
        and binding.get("latest_alias") is False
        and binding.get("silent_locale_fallback") is False
        and binding.get("required_locales") == ["en", "af"]
        and binding.get("paired_eligibility") is True,
        "exact locale binding, no latest alias and no fallback required",
        findings,
    )

    decisions = packet.get("owner_decisions", [])
    if not isinstance(decisions, list):
        findings.append("owner decisions must be an array")
        decisions = []
    expected_decisions = [
        ("Product", "classification"),
        ("Content & Media", "exact_locale_version"),
        ("Content & Media", "exact_locale_version"),
    ]
    actual_decisions = [(item.get("owner"), item.get("scope")) for item in decisions]
    record(
        len(decisions) == 3 and actual_decisions == expected_decisions,
        "separate pending Product and locale owner decisions required",
        findings,
    )
    record(
        all(
            item.get("status") == "pending"
            and item.get("decision_id") is None
            and item.get("actor_identity") is None
            and item.get("accountable_owner_evidence") is None
            and item.get("decision_reference") is None
            and item.get("decided_at") is None
            for item in decisions
        ),
        "candidate owner decisions must remain pending",
        findings,
    )
    if len(decisions) == 3:
        record(
            decisions[0].get("binding", {}).get("content_type") == "password_reset_message"
            and decisions[0].get("binding", {}).get("wording_risk") == "editorial_low_risk"
            and decisions[0].get("binding", {}).get("identity_security_risk") == "HIGH"
            and decisions[0].get("subjects") == packet.get("product_proposal", {}).get("documents"),
            "Product decision must bind exact proposed classification and documents",
            findings,
        )
    for index, locale in enumerate(("en", "af"), start=1):
        if index >= len(decisions):
            break
        decision = decisions[index]
        version = packet.get("locale_versions", [])[index - 1:index]
        if not version:
            continue
        version = version[0]
        expected_subject = {
            "locale": locale,
            "content_translation_version_id": version.get("id"),
            "artifact": version.get("artifact"),
            "subject": version.get("subject"),
            "body": version.get("body"),
        }
        actual_subject = (decision.get("subjects") or [{}])[0]
        record(
            decision.get("locale") == locale
            and actual_subject == expected_subject
            and decision.get("binding", {}).get("locale") == locale
            and decision.get("binding", {}).get("content_item_id") == EXPECTED_CONTENT_ITEM_ID
            and decision.get("binding", {}).get("content_version_id") == EXPECTED_CONTENT_VERSION_ID
            and decision.get("binding", {}).get("content_translation_version_id") == version.get("id")
            and decision.get("binding", {}).get("format_id") == EXPECTED_FORMAT_ID
            and decision.get("binding", {}).get("token_contract_sha256") == packet.get("token_contract_sha256")
            and decision.get("binding", {}).get("applicability") == scope
            and decision.get("binding", {}).get("product_proposal_digests")
            == [item.get("sha256") for item in packet.get("product_proposal", {}).get("documents", [])],
            f"Content & Media decision binding mismatch: {locale}",
            findings,
        )

    reviews = packet.get("locale_reviews", [])
    if not isinstance(reviews, list):
        findings.append("locale reviews must be an array")
        reviews = []
    record(
        [(item.get("locale"), item.get("role"), item.get("status"), item.get("decision_id"), item.get("evidence")) for item in reviews]
        == [
            ("en", "English Language Reviewer", "pending", None, None),
            ("af", "Afrikaans Language Reviewer", "pending", None, None),
        ],
        "English and Afrikaans locale review evidence must remain pending",
        findings,
    )
    record(packet.get("approval_events") == [], "candidate cannot contain approval events", findings)

    authorization = packet.get("authorization", {})
    record(
        authorization.get("development_use", {}).get("status") == "NOT_GRANTED"
        and authorization.get("development_implementation_permission")
        == {
            "status": "NOT_GRANTED_BY_WELL-98",
            "separate_authority": "A future dependency-cleared Ready implementation ticket authorizes its implementation agent to begin work.",
            "not_granted_by": [
                "Product classification approval",
                "Content & Media content eligibility approval",
                "WELL-98 Plane state",
                "WELL-98 GitHub merge",
            ],
        }
        and authorization.get("runtime_release") == "NOT_GRANTED"
        and authorization.get("production") == "PROHIBITED"
        and authorization.get("real_participant_delivery") == "PROHIBITED",
        "candidate must not grant development or runtime authorization",
        findings,
    )
    record(
        packet.get("lifecycle", {}).get("state") == "candidate"
        and packet.get("lifecycle", {}).get("states")
        == ["candidate", "development_approved", "superseded", "withdrawn"]
        and packet.get("lifecycle", {}).get("transitions")
        == {
            "candidate": ["development_approved"],
            "development_approved": ["superseded", "withdrawn"],
            "superseded": [],
            "withdrawn": [],
        },
        "candidate lifecycle state required",
        findings,
    )
    lifecycle = packet.get("lifecycle", {})
    record(
        lifecycle.get("transition_guards", {}).get("candidate_to_development_approved")
        == [
            "approved Product extension is selected by current governance",
            "attributable Product-owner decision for exact type, wording risk and applicability",
            "Content & Media owner decision bound to the exact EN version and digest",
            "Content & Media owner decision bound to the exact AF version and digest",
            "required locale review evidence bound to exact bytes",
            "both locale versions and the exact token contract verify",
            "no conflicting unresolved decision",
            "complete append-only history",
        ]
        and lifecycle.get("transition_guards", {}).get("terminal_transition")
        == [
            "accountable Content & Media owner decision",
            "exact prior version IDs and digests",
            "supersession names an immutable successor",
        ],
        "lifecycle transition guards mismatch",
        findings,
    )
    record(
        lifecycle.get("terminal_for_new_use") == ["superseded", "withdrawn"]
        and lifecycle.get("idempotency_key")
        == [
            "decision_id",
            "content_item_id",
            "content_version_id",
            "content_translation_version_id",
            "locale",
            "format_id",
            "sha256",
            "token_contract_sha256",
            "applicability",
        ]
        and lifecycle.get("conflict") == "STOP_AND_RECONCILE; never last-write-wins"
        and lifecycle.get("history") == "APPEND_ONLY; changed bytes require new ContentTranslationVersion ID and fresh approval; shared structure changes require successor ContentVersion."
        and lifecycle.get("revalidate_current_eligibility_before_new_use") is True
        and lifecycle.get("queued_or_cached_copy_preserves_eligibility") is False,
        "immutable lifecycle, replay and current-eligibility contract mismatch",
        findings,
    )
    approval_contract = packet.get("approval_contract", {})
    record(
        approval_contract.get("recording") == "APPEND_ONLY"
        and len(approval_contract.get("required_decisions", [])) == 4
        and approval_contract.get("required_event_fields")
        == [
            "decision_id",
            "actor_identity",
            "accountable_owner_evidence",
            "decision_reference",
            "decided_at",
            "decision",
            "content_item_id",
            "content_version_id",
            "locale",
            "content_translation_version_id",
            "artifact",
            "format_id",
            "token_contract_sha256",
            "applicability",
            "product_proposal_digests",
        ]
        and set(approval_contract.get("no_approval_substitutes", []))
        == {
            "implementation permission",
            "Plane ownership or state",
            "repository authorship",
            "GitHub merge",
            "approval of verification_message",
            "approval of magic_login_message",
        },
        "approval contract does not preserve distinct owner decisions",
        findings,
    )
    record(
        approval_contract.get("owner_decisions_do_not_grant")
        == [
            "password-reset implementation permission",
            "runtime Content role or eligibility",
            "Communications sender or provider permission",
            "publication or release authorization",
            "production or real-participant delivery",
        ],
        "Product and Content owner decisions must not grant implementation or release authority",
        findings,
    )
    security = packet.get("security", {})
    record(
        security.get("assent_disposition") == "WELL-91 unchanged"
        and security.get("exclusive_expiry") == "2026-11-18T00:00:00Z"
        and security.get("authentication_input_rebinding") is False
        and security.get("protected_bearer_retention_extension") is False
        and security.get("runtime_changes") is False,
        "WELL-91 security exception must remain unchanged",
        findings,
    )


def validate(root: Path) -> dict[str, Any]:
    findings: list[str] = []
    packet_path = safe_source_path(root, PACKET_PATH.as_posix(), findings)
    if packet_path:
        packet_bytes = packet_path.read_bytes()
        try:
            packet = json.loads(packet_bytes.decode("utf-8"))
        except (UnicodeError, json.JSONDecodeError) as exc:
            findings.append(f"cannot parse candidate packet: {exc}")
            packet = {}
        if not isinstance(packet, dict):
            findings.append("candidate packet must be a JSON object")
            packet = {}
    else:
        packet_bytes = b""
        packet = {}

    check_candidate_authority(packet, findings)
    check_proposals(root, packet, findings)
    check_router(root, packet, packet_bytes, findings)
    check_registry(root, packet, findings)
    check_artifacts(root, packet, findings)
    return {
        "integrity": "FAIL" if findings else "PASS",
        "candidate_eligible": False,
        "development_eligible": False,
        "runtime_release_eligible": False,
        "findings": findings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    evidence = validate(args.root.resolve())
    print(json.dumps(evidence, ensure_ascii=False, indent=2))
    return 1 if evidence["integrity"] == "FAIL" else 0


if __name__ == "__main__":
    raise SystemExit(main())
