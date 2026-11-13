"""Validate WELL-98's non-authoritative password-reset message evidence."""

from __future__ import annotations

import argparse
import copy
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
APPROVED_PACKET_PATH = Path(
    "docs/delivery/content-evidence/content_media/password_reset_messages/"
    "PASSWORD_RESET_MESSAGE_EVIDENCE_PACKET_v0.2.0.json"
)
OWNER_APPROVALS_PATH = Path(
    "docs/delivery/content-evidence/content_media/password_reset_messages/OWNER_APPROVALS_v1.json"
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
EXPECTED_PROMOTED_GOVERNANCE = {
    "PLATFORM_PRODUCT_LAW": {
        "repository_path": "docs/governance/product/00_PLATFORM_v1.15.0.md",
        "sha256": "c7f5510817028d28edd4eb29e71b9150e13d0354cccf1af23666e067e0eed0b8",
        "semver": "1.15.0",
    },
    "PRODUCT_DECISIONS": {
        "repository_path": "docs/governance/product/01_DECISIONS_v1.15.0.md",
        "sha256": "db57b0b73ed9faf8f3ade458c01d0d4798e4c2401172a35b9a1ad129ce8ae8d4",
        "semver": "1.15.0",
    },
}
EXPECTED_CURRENT_GOVERNANCE = {
    "PLATFORM_PRODUCT_LAW": {
        "repository_path": "docs/governance/product/00_PLATFORM_v1.17.0.md",
        "sha256": "ad38c25c49ba9d1de40e90d74b494705156605af724bc0e1d5a66d38b81cc39f", "semver": "1.17.0",
    },
    "PRODUCT_DECISIONS": {
        "repository_path": "docs/governance/product/01_DECISIONS_v1.17.0.md",
        "sha256": "1d2c3cf6ec3ea4cd318ceccda8fa0a9b2c9797eec8f934a399e8d59f93090d8b", "semver": "1.17.0",
    },
}
EXPECTED_CURRENT_GOVERNANCE_PREDECESSORS = {
    "PLATFORM_PRODUCT_LAW": {
        "repository_path": "docs/governance/product/00_PLATFORM_v1.16.0.md",
        "sha256": "bcc26cec59b8157a4d284d6bb533ec16bf41e85b88d7c5c14ff1ec1141019174",
    },
    "PRODUCT_DECISIONS": {
        "repository_path": "docs/governance/product/01_DECISIONS_v1.16.0.md",
        "sha256": "1a5d6d7c2bb0ca2a595dd28e2e371340298aa0b62ff613939c5de141831eb7f8",
    },
}
RECOVERY_PROPOSAL_PATH = "docs/delivery/content-evidence/content_media/recovery_messages/PRODUCT_CLASSIFICATION_PROPOSALS_v0.1.0.md"
RECOVERY_PROPOSAL_SHA = "04f41fe344428a9c7cb30398c599c341d6a416af79c51d8446215ef9075e1b64"
EXPECTED_OWNER_APPROVALS_SHA256 = "80b95f1f25df5bd67b08792a665965b6ab34cf265f400b389cb90e77df203b4b"
APPROVED_MAIN_SHA = "64841ae010275dbd94f1fd3f0cc70f8d71af3bc7"
EXPECTED_APPROVALS = [
    {
        "decision_id": "WELL-98-PRODUCT-APPROVAL-20261109",
        "accountable_owner": "Product",
        "role": "accountable Product owner",
        "comment_id": "a6cedfea-2ee2-4c9b-97eb-a735793a4d92",
        "recorded_at": "2026-11-09T06:59:05.698111Z",
    },
    {
        "decision_id": "WELL-98-CONTENT-EN-V1-APPROVAL-20261109",
        "accountable_owner": "Content & Media",
        "role": "Content & Media owner, exact EN V1",
        "comment_id": "85949fee-f36c-4d6c-b54f-890ef4ad04eb",
        "recorded_at": "2026-11-09T06:59:14.529529Z",
    },
    {
        "decision_id": "WELL-98-CONTENT-AF-V2-APPROVAL-20261109",
        "accountable_owner": "Content & Media",
        "role": "Content & Media owner, exact AF V2",
        "comment_id": "56697c18-e585-403e-8b99-ef417d9acf6b",
        "recorded_at": "2026-11-09T06:59:21.569208Z",
    },
    {
        "decision_id": "WELL-98-LANG-EN-V1-APPROVAL-20261109",
        "accountable_owner": "English Language Reviewer",
        "role": "English Language Reviewer, exact EN V1",
        "comment_id": "b6c2dc5e-5622-49ac-8e12-a0f5855acce3",
        "recorded_at": "2026-11-09T06:59:27.114634Z",
    },
    {
        "decision_id": "WELL-98-LANG-AF-V2-APPROVAL-20261109",
        "accountable_owner": "Afrikaans Language Reviewer",
        "role": "Afrikaans Language Reviewer, exact AF V2",
        "comment_id": "3fd2448a-39f3-4c61-bbaf-85253e3d2c5f",
        "recorded_at": "2026-11-09T06:59:32.524540Z",
    },
]
EXPECTED_APPROVAL_ACTOR = "2d75ac08-a11c-4fe1-9545-c1d885f83955"
EXPECTED_APPROVAL_SUMMARY_COMMENT = "510ff609-f47a-4f54-8e77-9d2ba6345276"
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

    record(
        packet.get("product_proposal", {}).get("current_governance_routes_unchanged") is True,
        "historical candidate must record that it left governance routes unchanged",
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


def approved_proposal_sections(root: Path, findings: list[str]) -> tuple[str, str]:
    product_proposal_path = safe_source_path(
        root, EXPECTED_PROPOSALS[0]["path"], findings
    )
    decisions_proposal_path = safe_source_path(
        root, EXPECTED_PROPOSALS[1]["path"], findings
    )
    if product_proposal_path is None or decisions_proposal_path is None:
        return "", ""

    product_proposal = product_proposal_path.read_text(encoding="utf-8")
    sections = product_proposal[product_proposal.index("## Proposed §21E.23") :].strip()
    sections = sections.replace("## Proposed §21E.23", "## 21E.23", 1)
    sections = sections.replace("## Proposed §21E.24", "## 21E.24", 1)
    sections = sections.replace(
        "Recommend `editorial_low_risk` for wording only, subject to an explicit Product-owner decision.",
        "The approved wording risk is `editorial_low_risk` under §21E.4.",
    )
    sections = sections.replace(
        "This candidate proposes Class A with `identity_security` content risk; that copy classification does not replace the proposed Product wording classification.",
        "This approved type is Class A with `identity_security` content risk. That content risk remains distinct from the wording classification.",
    )
    sections = sections.replace(
        "This proposal grants no runtime Content role",
        "This extension grants no runtime Content role",
    )
    sections = sections.replace(
        "This proposal grants none of them.", "This extension grants none of them."
    )

    decisions_proposal = decisions_proposal_path.read_text(encoding="utf-8")
    dec322 = decisions_proposal[
        decisions_proposal.index("## Proposed DEC-322") :
    ].strip()
    dec322 = dec322.replace("## Proposed DEC-322", "## DEC-322", 1)
    dec322 = dec322.replace(
        "**Status:** PROPOSED / PRODUCT-OWNER DECISION PENDING",
        "**Status:** LOCKED",
        1,
    )
    dec322 = dec322.replace(
        "Subject to explicit Product-owner acceptance of proposed Product §§21E.23–21E.24, add the narrow `password_reset_message` type for the email that carries Identity-owned password-reset proof to an existing Account. Recommend `editorial_low_risk` for wording only.",
        "Under approved Product §§21E.23–21E.24, add the narrow `password_reset_message` type for the email that carries Identity-owned password-reset proof to an existing Account. The Product owner approves `editorial_low_risk` for wording only.",
    )
    dec322 = dec322.replace(
        "The candidate scope is local development, automated tests, development environments and bounded P8-12 Phase-8 proof.",
        "Applicability is limited to local development, automated tests, development environments and bounded P8-12 Phase-8 proof.",
    )
    dec322 = dec322.replace(
        "Development eligibility requires the Product extension to be current and attributable Product-owner and Content & Media decisions bound to the exact proposed law and locale artifacts.",
        "Development eligibility requires the Product extension to be current, the attributable Product decision to bind the exact proposal documents, separate Content & Media decisions for exact EN V1 and AF V2, and English and Afrikaans language reviews bound to those exact locale bytes.",
    )
    dec322 = dec322.replace(
        "It creates no runtime role, publication, sender/provider approval, Identity grant or production permission.",
        "It creates no runtime Content role, publication, sender/provider approval, Identity grant, password-reset implementation permission or production permission.",
    )
    return sections, dec322


def expected_approval_events(
    candidate: dict[str, Any], approval_source: dict[str, Any], findings: list[str]
) -> list[dict[str, Any]]:
    source_records = approval_source.get("decisions", [])
    record(
        len(source_records) == len(EXPECTED_APPROVALS),
        "five separate owner and language-review records are required",
        findings,
    )
    by_id = {
        item.get("decision_id"): item
        for item in source_records
        if isinstance(item, dict)
    }
    versions = {
        item.get("locale"): item
        for item in candidate.get("locale_versions", [])
        if isinstance(item, dict)
    }
    scope = candidate.get("scope", {})
    proposal_docs = candidate.get("product_proposal", {}).get("documents", [])
    proposal_digests = [item.get("sha256") for item in proposal_docs]
    content_binding = {
        "content_item_id": EXPECTED_CONTENT_ITEM_ID,
        "content_version_id": EXPECTED_CONTENT_VERSION_ID,
        "format_id": EXPECTED_FORMAT_ID,
        "token_contract_sha256": candidate.get("token_contract_sha256"),
        "applicability": scope,
        "product_proposal_digests": proposal_digests,
    }
    language_binding = {
        "review_scope": "language quality only; no Product classification or Content eligibility grant",
        "format_id": EXPECTED_FORMAT_ID,
        "token_contract_sha256": candidate.get("token_contract_sha256"),
        "applicability": scope,
        "product_proposal_digests": proposal_digests,
    }
    product_binding = {
        "content_type": "password_reset_message",
        "wording_risk": "editorial_low_risk",
        "content_class": "Class A",
        "content_risk": "identity_security",
        "identity_security_risk": "HIGH",
        "applicability": scope,
    }
    expected_events = []
    for index, expected in enumerate(EXPECTED_APPROVALS):
        source = by_id.get(expected["decision_id"], {})
        plane_record = source.get("plane_record", {})
        comment_text = source.get("plane_comment_text", "")
        record(
            source.get("decision_id") == expected["decision_id"]
            and source.get("accountable_owner") == expected["accountable_owner"]
            and source.get("role") == expected["role"]
            and source.get("decision") == "APPROVE"
            and source.get("actor_identity") == EXPECTED_APPROVAL_ACTOR
            and plane_record.get("comment_id") == expected["comment_id"]
            and plane_record.get("recorded_at") == expected["recorded_at"]
            and plane_record.get("created_by") == EXPECTED_APPROVAL_ACTOR
            and plane_record.get("updated_by") is None
            and plane_record.get("edited_at") is None
            and plane_record.get("project_id") == "846031af-971b-4f08-92c3-7f008522a5ac"
            and plane_record.get("workitem_id") == "0609cc82-9dc8-4fb8-829f-2467b373ee74"
            and plane_record.get("access") == "INTERNAL"
            and f"Decision ID: {expected['decision_id']}" in comment_text
            and "self-attestation of accountability" in comment_text,
            f"Plane approval provenance mismatch: {expected['decision_id']}",
            findings,
        )
        comment_lower = comment_text.casefold()
        record(
            APPROVED_MAIN_SHA in comment_text
            and all(value.casefold() in comment_lower for value in scope["allowed"])
            and all(value.casefold() in comment_lower for value in scope["prohibited"]),
            f"approval baseline or applicability changed: {expected['decision_id']}",
            findings,
        )

        if index == 0:
            subjects = proposal_docs
            binding = product_binding
            product_values = [
                "password_reset_message",
                "editorial_low_risk",
                "Class A",
                "identity_security",
                "HIGH",
            ]
            product_values.extend(
                value
                for proposal in proposal_docs
                for value in (proposal.get("path"), proposal.get("sha256"))
            )
            record(
                all(value in comment_text for value in product_values),
                "Product approval is not bound to exact proposal documents and classifications",
                findings,
            )
        else:
            locale = "en" if index in (1, 3) else "af"
            version = versions.get(locale, {})
            subject = {
                "locale": locale,
                "content_translation_version_id": version.get("id"),
                "artifact": version.get("artifact"),
                "subject": version.get("subject"),
                "body": version.get("body"),
            }
            subjects = [subject]
            binding = content_binding if index in (1, 2) else language_binding
            exact_values = [
                version.get("id"),
                version.get("artifact", {}).get("path"),
                str(version.get("artifact", {}).get("bytes")),
                version.get("artifact", {}).get("sha256"),
                candidate.get("content_item_id"),
                candidate.get("content_version_id"),
                EXPECTED_FORMAT_ID,
                candidate.get("token_contract_sha256"),
            ]
            record(
                all(value and str(value) in comment_text for value in exact_values),
                f"Plane approval is not bound to exact {locale.upper()} content: {expected['decision_id']}",
                findings,
            )
            if index in (1, 2):
                field_values = [
                    version.get("subject", {}).get("sha256"),
                    version.get("body", {}).get("sha256"),
                ]
                record(
                    all(value and value in comment_text for value in field_values),
                    f"Content & Media approval omits exact {locale.upper()} subject/body binding",
                    findings,
                )
            if index == 2:
                record(
                    "AF V1 remains unchanged, historical and unapproved" in comment_text,
                    "AF V1 historical status changed",
                    findings,
                )
            if index == 4:
                record(
                    "wysig" in comment_text
                    and "AF V1 remains historical/unapproved" in comment_text,
                    "Afrikaans language decision must bind Wysig and preserve AF V1 history",
                    findings,
                )

        expected_event = {
            "decision_id": expected["decision_id"],
            "owner": expected["accountable_owner"],
            "role": expected["role"],
            "decision": "approve",
            "actor_identity": EXPECTED_APPROVAL_ACTOR,
            "accountable_owner_evidence": {
                "path": OWNER_APPROVALS_PATH.as_posix(),
                "sha256": EXPECTED_OWNER_APPROVALS_SHA256,
                "comment_id": expected["comment_id"],
                "basis": "Self-attested accountable role recorded by the requesting user; not a runtime role or grant.",
            },
            "decision_reference": {
                "project_id": "846031af-971b-4f08-92c3-7f008522a5ac",
                "workitem_id": "0609cc82-9dc8-4fb8-829f-2467b373ee74",
                "comment_id": expected["comment_id"],
                "summary_comment_id": EXPECTED_APPROVAL_SUMMARY_COMMENT,
            },
            "recorded_at": expected["recorded_at"],
            "approved_head": APPROVED_MAIN_SHA,
            "subjects": subjects,
            "binding": binding,
            "applicability": scope,
        }
        if index > 0:
            locale = "en" if index in (1, 3) else "af"
            expected_event.update(
                {
                    "locale": locale,
                    "content_item_id": EXPECTED_CONTENT_ITEM_ID,
                    "content_version_id": EXPECTED_CONTENT_VERSION_ID,
                    "content_translation_version_id": versions.get(locale, {}).get("id"),
                }
            )
        expected_events.append(expected_event)
    record(
        [item.get("decision_id") for item in source_records]
        == [item["decision_id"] for item in EXPECTED_APPROVALS],
        "Plane approval records must retain their distinct canonical order",
        findings,
    )
    return expected_events


def validate_development(root: Path) -> dict[str, Any]:
    """Verify approved, bounded development evidence against the immutable candidate and live routes."""
    findings: list[str] = []
    candidate_result = validate(root)
    findings.extend(candidate_result["findings"])
    candidate = load_json(root, PACKET_PATH, findings)
    packet_path = safe_source_path(root, APPROVED_PACKET_PATH.as_posix(), findings)
    if packet_path is None:
        packet = {}
        packet_bytes = b""
    else:
        packet_bytes = packet_path.read_bytes()
        try:
            packet = json.loads(packet_bytes.decode("utf-8"))
        except (UnicodeError, json.JSONDecodeError) as exc:
            findings.append(f"cannot parse approved development packet: {exc}")
            packet = {}
    if not isinstance(packet, dict):
        findings.append("approved development packet must be a JSON object")
        packet = {}

    approval_path = safe_source_path(root, OWNER_APPROVALS_PATH.as_posix(), findings)
    if approval_path is None:
        approval_source = {}
    else:
        approval_bytes = approval_path.read_bytes()
        record(
            sha256(approval_bytes) == EXPECTED_OWNER_APPROVALS_SHA256,
            "immutable Plane owner-approval snapshot changed",
            findings,
        )
        try:
            approval_source = json.loads(approval_bytes.decode("utf-8"))
        except (UnicodeError, json.JSONDecodeError) as exc:
            findings.append(f"cannot parse Plane owner-approval snapshot: {exc}")
            approval_source = {}
    if not isinstance(approval_source, dict):
        findings.append("Plane owner-approval snapshot must be a JSON object")
        approval_source = {}

    expected_events = expected_approval_events(candidate, approval_source, findings)
    record(
        approval_source.get("record_id") == "WELL-98-OWNER-APPROVALS-V1"
        and approval_source.get("approved_head") == APPROVED_MAIN_SHA
        and approval_source.get("actor_identity") == EXPECTED_APPROVAL_ACTOR
        and approval_source.get("attribution", {}).get("independence") is False
        and approval_source.get("attribution", {}).get("runtime_identity_or_grant") is False
        and approval_source.get("plane_source", {}).get("project_id")
        == "846031af-971b-4f08-92c3-7f008522a5ac"
        and approval_source.get("plane_source", {}).get("workitem_id")
        == "0609cc82-9dc8-4fb8-829f-2467b373ee74"
        and approval_source.get("plane_source", {}).get("summary_comment_id")
        == EXPECTED_APPROVAL_SUMMARY_COMMENT,
        "Plane approval source identity or attribution mismatch",
        findings,
    )
    record(
        approval_source.get("authorizations")
        == {
            "merge": False,
            "password_reset_implementation": False,
            "runtime_content_role": False,
            "sender_or_provider": False,
            "publication_or_release": False,
            "production_or_real_participant": False,
            "phase_9": False,
        },
        "owner decisions must not imply implementation, runtime or release authority",
        findings,
    )

    record(
        packet.get("packet_id") == "password-reset-message-email-development-evidence-v0.2.0"
        and packet.get("status") == "DEVELOPMENT_ONLY_APPROVED; RUNTIME_RELEASE_PROHIBITED"
        and packet.get("owner") == "Content & Media",
        "approved development packet identity or status mismatch",
        findings,
    )
    record(
        packet.get("predecessor_packet")
        == {
            "path": PACKET_PATH.as_posix(),
            "sha256": "7d9df40d8b8ed8ca2c1bf204682a70d88425f4619a7663ac89db401036c01132",
        },
        "unchanged candidate predecessor binding mismatch",
        findings,
    )
    record(
        packet.get("approval_source")
        == {
            "path": OWNER_APPROVALS_PATH.as_posix(),
            "sha256": EXPECTED_OWNER_APPROVALS_SHA256,
            "summary_comment_id": EXPECTED_APPROVAL_SUMMARY_COMMENT,
        }
        and packet.get("approved_head") == APPROVED_MAIN_SHA,
        "approval source or approved main binding mismatch",
        findings,
    )
    record(
        packet.get("activation")
        == {
            "basis": "All five exact-bound Plane decisions and the Product v1.15.0 authority route are mechanically verified in this PR branch.",
            "effective_only_after_merge": True,
            "requires_independent_master_gate_and_authorised_merge": True,
            "password_reset_implementation_permission": False,
        },
        "activation timing or permission boundary mismatch",
        findings,
    )
    record(
        packet.get("product_proposal")
        == {
            "status": "APPROVED_AND_PROMOTED_IN_CURRENT_GOVERNANCE_ROUTE",
            "approved_type": "password_reset_message",
            "approved_wording_risk": "editorial_low_risk",
            "content_class": "Class A",
            "content_risk": "identity_security",
            "identity_security_risk": "HIGH",
            "source_documents": candidate.get("product_proposal", {}).get("documents"),
        },
        "approved Product classification mismatch",
        findings,
    )
    record(
        packet.get("scope") == candidate.get("scope")
        and packet.get("eligibility")
        == {
            "development": True,
            "automated_tests": True,
            "development_environments": True,
            "bounded_p8_12_proof": True,
            "runtime_release": False,
            "production": False,
            "public_release": False,
            "paid_pilot": False,
            "real_participant_delivery": False,
            "phase_9": False,
        },
        "bounded development scope or eligibility flags mismatch",
        findings,
    )
    for key in ("content_item_id", "content_version_id", "binding", "serialization", "token_allowlist", "token_contract_sha256", "locale_versions", "security"):
        record(
            packet.get(key) == candidate.get(key),
            f"approved packet changed immutable candidate binding: {key}",
            findings,
        )

    expected_authority = []
    for document_id, expected in EXPECTED_PROMOTED_GOVERNANCE.items():
        proposal = next(
            (item for item in candidate.get("product_proposal", {}).get("documents", []) if item.get("document_id") == document_id),
            {},
        )
        expected_authority.append(
            {
                "document_id": document_id,
                "path": expected["repository_path"],
                "sha256": expected["sha256"],
                "semver": expected["semver"],
                "predecessor": proposal.get("predecessor"),
                "predecessor_sha256": proposal.get("predecessor_sha256"),
                "approved_amendment_path": proposal.get("path"),
                "approved_amendment_sha256": proposal.get("sha256"),
            }
        )
    record(
        packet.get("promoted_authority") == expected_authority,
        "promoted authority binding mismatch",
        findings,
    )

    governance = load_json(root, GOVERNANCE_ROUTER_PATH, findings)
    current_routes = {
        item.get("document_id"): item
        for item in governance.get("governing_documents", [])
        if isinstance(item, dict)
    }
    record(governance.get("status") == "CURRENT", "governance router is not current", findings)
    for document_id, expected in EXPECTED_CURRENT_GOVERNANCE.items():
        matches = [item for item in governance.get("governing_documents", []) if item.get("document_id") == document_id]
        record(len(matches) == 1, f"missing or duplicate Product authority route: {document_id}", findings)
        route = current_routes.get(document_id, {})
        path = safe_source_path(root, expected["repository_path"], findings)
        record(
            route.get("repository_path") == expected["repository_path"]
            and route.get("canonical_filename") == Path(expected["repository_path"]).name
            and route.get("sha256") == expected["sha256"]
            and route.get("semver") == expected["semver"],
            f"current Product authority route mismatch: {document_id}",
            findings,
        )
        if path:
            record(
                sha256(path.read_bytes()) == expected["sha256"],
                f"current Product authority digest mismatch: {document_id}",
                findings,
            )
    proposal_path = safe_source_path(root, RECOVERY_PROPOSAL_PATH, findings)
    if proposal_path:
        record(sha256(proposal_path.read_bytes()) == RECOVERY_PROPOSAL_SHA, "recovery proposal digest mismatch", findings)
    for document_id, prior in EXPECTED_PROMOTED_GOVERNANCE.items():
        current = EXPECTED_CURRENT_GOVERNANCE[document_id]
        current_predecessor = EXPECTED_CURRENT_GOVERNANCE_PREDECESSORS[document_id]
        previous = safe_source_path(root, prior["repository_path"], findings)
        successor = safe_source_path(root, current["repository_path"], findings)
        immediate_predecessor = safe_source_path(root, current_predecessor["repository_path"], findings)
        if previous:
            record(sha256(previous.read_bytes()) == prior["sha256"], "prior Product authority digest mismatch", findings)
        if immediate_predecessor:
            record(
                sha256(immediate_predecessor.read_bytes()) == current_predecessor["sha256"],
                "current Product authority predecessor digest mismatch",
                findings,
            )
        if successor:
            text = successor.read_text(encoding="utf-8")
            record(
                f"**Predecessor:** `{current_predecessor['repository_path']}`" in text
                and "**SemVer transition:** `v1.16.0 → v1.17.0`" in text,
                "current Product authority lineage mismatch",
                findings,
            )
    product_path = root / EXPECTED_PROMOTED_GOVERNANCE["PLATFORM_PRODUCT_LAW"]["repository_path"]
    decisions_path = root / EXPECTED_PROMOTED_GOVERNANCE["PRODUCT_DECISIONS"]["repository_path"]
    product_source = safe_source_path(root, product_path.relative_to(root).as_posix(), findings)
    decisions_source = safe_source_path(root, decisions_path.relative_to(root).as_posix(), findings)
    expected_product_sections, expected_dec322 = approved_proposal_sections(root, findings)
    if product_source:
        product_text = product_source.read_text(encoding="utf-8")
        if "## 21E.23 Password-reset message classification" in product_text and "# 21F." in product_text:
            start = product_text.index("## 21E.23 Password-reset message classification")
            end = product_text.index("# 21F.", start)
            record(
                product_text[start:end].strip() == expected_product_sections,
                "promoted Product clauses differ from the exact approved proposal",
                findings,
            )
        else:
            findings.append("promoted Product clauses are missing")
        record(
            "password_reset_message" in product_text
            and product_text.count("password_reset_message\n") == 1,
            "controlled Product catalogue must add the narrow type exactly once",
            findings,
        )
    if decisions_source:
        decisions_text = decisions_source.read_text(encoding="utf-8")
        if "## DEC-322 Password-reset message classification and bounded development eligibility" in decisions_text:
            actual_dec322 = decisions_text[
                decisions_text.index("## DEC-322 Password-reset message classification and bounded development eligibility") :
            ].strip()
            record(
                actual_dec322 == expected_dec322,
                "DEC-322 differs from the exact approved Product proposal",
                findings,
            )
        else:
            findings.append("DEC-322 is missing from current Decisions authority")

    delivery = load_json(root, DELIVERY_ROUTER_PATH, findings)
    active_routes = [
        item for item in delivery.get("delivery_contracts", [])
        if item.get("document_id") == "PASSWORD_RESET_MESSAGE_DEVELOPMENT_EVIDENCE"
    ]
    record(len(active_routes) == 1, "exactly one approved password-reset evidence route is required", findings)
    if len(active_routes) == 1:
        route = active_routes[0]
        record(
            route.get("repository_path") == APPROVED_PACKET_PATH.as_posix()
            and route.get("canonical_filename") == APPROVED_PACKET_PATH.name
            and route.get("contract_type") == "content_evidence"
            and route.get("status") == packet.get("status")
            and route.get("sha256") == sha256(packet_bytes),
            "approved development-router binding or digest mismatch",
            findings,
        )

    # The first copy is the recorded decision; exact duplicate replays are idempotent.
    event_map: dict[str, dict[str, Any]] = {}
    for event in packet.get("approval_events", []):
        if not isinstance(event, dict):
            findings.append("approval history contains a malformed event")
            continue
        decision_id = event.get("decision_id")
        if decision_id in event_map:
            record(
                event == event_map[decision_id],
                f"conflicting decision replay; STOP and reconcile: {decision_id}",
                findings,
            )
        else:
            event_map[decision_id] = event
    expected_event_map = {event["decision_id"]: event for event in expected_events}
    record(
        event_map == expected_event_map,
        "missing, extra or mismatched exact approval event",
        findings,
    )
    record(
        packet.get("owner_decisions") == expected_events[:3]
        and packet.get("locale_reviews") == expected_events[3:],
        "owner decisions and locale reviews do not match their exact approval events",
        findings,
    )

    expected_lifecycle = copy.deepcopy(candidate.get("lifecycle", {}))
    expected_lifecycle["state"] = "development_approved"
    expected_lifecycle["activation_evidence"] = {
        "predecessor_packet": {
            "path": PACKET_PATH.as_posix(),
            "sha256": "7d9df40d8b8ed8ca2c1bf204682a70d88425f4619a7663ac89db401036c01132",
        },
        "required_decision_ids": [item["decision_id"] for item in EXPECTED_APPROVALS],
        "current_product_authority": [
            {"document_id": item["document_id"], "path": item["repository_path"], "sha256": item["sha256"]}
            for item in (
                {"document_id": key, **value}
                for key, value in EXPECTED_PROMOTED_GOVERNANCE.items()
            )
        ],
        "conflict_resolution": "No conflict, supersession or withdrawal event was present in the verified source records. Any later conflicting, superseding or withdrawal decision must be appended and revalidated; this packet does not override it.",
        "effective_only_after_merge": True,
    }
    record(
        packet.get("lifecycle") == expected_lifecycle,
        "approved lifecycle state or transition evidence mismatch",
        findings,
    )

    expected_authorization = {
        "product_classification": "APPROVED by exact Product-owner decision and promoted Product Law/DEC-322 route",
        "content_en": "APPROVED for exact immutable EN V1 by Content & Media owner; English language review complete",
        "content_af": "APPROVED for exact immutable AF V2 by Content & Media owner; Afrikaans language review complete",
        "development_use": {
            "status": "GRANTED_FOR_BOUNDED_DEVELOPMENT_ONLY",
            "allowed": ALLOWED_SCOPE,
            "prohibited": PROHIBITED_SCOPE,
        },
        "runtime_release": "NOT_GRANTED",
        "production": "PROHIBITED",
        "public_release": "PROHIBITED",
        "paid_pilot": "PROHIBITED",
        "real_participant_delivery": "PROHIBITED",
        "phase_9": "PROHIBITED",
        "development_implementation_permission": candidate.get("authorization", {}).get("development_implementation_permission"),
        "runtime_content_role": "NOT_GRANTED",
        "sender_or_provider": "NOT_GRANTED",
        "publication_or_release": "NOT_GRANTED",
    }
    record(
        packet.get("authorization") == expected_authorization,
        "development authorization exceeds approved scope or grants implementation/runtime rights",
        findings,
    )

    expected_contract = copy.deepcopy(candidate.get("approval_contract", {}))
    expected_contract["recording"] = "APPEND_ONLY; original Plane decision comments are preserved by ID and text."
    expected_contract["required_decisions"] = [
        "Product-owner approval of the exact classification, wording risk, content risk and bounded applicability",
        "Content & Media owner approval of exact EN V1 bytes, digest, tokens and applicability",
        "Content & Media owner approval of exact AF V2 bytes, digest, tokens and applicability",
        "English Language Reviewer approval bound to exact EN V1 bytes",
        "Afrikaans Language Reviewer approval bound to exact AF V2 bytes",
    ]
    expected_contract["required_event_fields"] = [
        "decision_id", "actor_identity", "accountable_owner_evidence", "decision_reference",
        "recorded_at", "approved_head", "decision", "owner", "role", "subjects", "binding", "applicability"
    ]
    expected_contract["timestamp_semantics"] = "recorded_at is the Plane comment creation timestamp; it is not asserted to be the original user-message timestamp."
    expected_contract["required_decision_ids"] = [item["decision_id"] for item in EXPECTED_APPROVALS]
    expected_contract["no_approval_substitutes"] = list(dict.fromkeys(
        expected_contract.get("no_approval_substitutes", []) + [
            "Content & Media approval of the other locale",
            "language review as Product or Content & Media approval",
            "self-attested role evidence as a runtime Identity role or grant",
        ]
    ))
    expected_contract["owner_decisions_do_not_grant"] = list(dict.fromkeys(
        expected_contract.get("owner_decisions_do_not_grant", []) + [
            "password-reset runtime implementation",
            "current-message send authority",
            "real participant or Phase 9 use",
        ]
    ))
    record(
        packet.get("approval_contract") == expected_contract,
        "approval contract is incomplete or substitutes one decision for another",
        findings,
    )

    return {
        "integrity": "FAIL" if findings else "PASS",
        "candidate_eligible": False,
        "development_eligible": not findings,
        "runtime_release_eligible": False,
        "findings": findings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    evidence = validate_development(args.root.resolve())
    print(json.dumps(evidence, ensure_ascii=False, indent=2))
    return 1 if evidence["integrity"] == "FAIL" else 0


if __name__ == "__main__":
    raise SystemExit(main())
