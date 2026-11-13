"""Validate the exact, bounded WELL-122 primary-email-change content evidence."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any


EVIDENCE_DIR = Path(
    "docs/delivery/content-evidence/content_media/email_change_messages"
)
PACKET_PATH = EVIDENCE_DIR / "CANDIDATE_EVIDENCE_v1.json"
ATTRIBUTION_PATH = EVIDENCE_DIR / "OWNER_DECISION_ATTRIBUTION_v1.json"
PROPOSAL_PATH = EVIDENCE_DIR / "PRODUCT_CLASSIFICATION_PROPOSAL_v1.md"
CAPACITY_PATH = Path(
    "docs/delivery/content-evidence/content_media/recovery_messages/OWNER_APPROVALS_v1.json"
)
GOVERNANCE_ROUTER_PATH = Path("docs/governance/CURRENT_GOVERNANCE_ROUTER.json")
DELIVERY_ROUTER_PATH = Path("docs/delivery/CURRENT_DELIVERY_ROUTER.json")

OWNER_ACTOR = "2d75ac08-a11c-4fe1-9545-c1d885f83955"
PRODUCT_RECORD = "a2214bde-85ea-4799-80d0-61b864afc41d"
AF_BODY_RECORD = "b9a4839e-def6-4856-aa1a-2d602743c101"
PRODUCT_PROPOSAL_SHA256 = "5859094922ada891cdca887cf140d457991fa0fe5fcc76ea34ff4dd32ad8a8b1"
CAPACITY_SHA256 = "a3c84d4458afaaf8df2cf0f4e9fcaf4040e424da8950a1d6ef3f63efbf225b3c"

PRODUCT_DOCUMENTS = {
    "PLATFORM_PRODUCT_LAW": {
        "path": Path("docs/governance/product/00_PLATFORM_v1.17.0.md"),
        "sha256": "ad38c25c49ba9d1de40e90d74b494705156605af724bc0e1d5a66d38b81cc39f",
        "predecessor": Path("docs/governance/product/00_PLATFORM_v1.16.0.md"),
        "predecessor_sha256": "bcc26cec59b8157a4d284d6bb533ec16bf41e85b88d7c5c14ff1ec1141019174",
        "transition": "**SemVer transition:** `v1.16.0 → v1.17.0`",
    },
    "PRODUCT_DECISIONS": {
        "path": Path("docs/governance/product/01_DECISIONS_v1.17.0.md"),
        "sha256": "1d2c3cf6ec3ea4cd318ceccda8fa0a9b2c9797eec8f934a399e8d59f93090d8b",
        "predecessor": Path("docs/governance/product/01_DECISIONS_v1.16.0.md"),
        "predecessor_sha256": "1a5d6d7c2bb0ca2a595dd28e2e371340298aa0b62ff613939c5de141831eb7f8",
        "transition": "**SemVer transition:** `v1.16.0 → v1.17.0`",
    },
}

MESSAGE_VERSIONS = {
    ("primary_email_change_confirmation_message", "en"): {
        "communications_role": "email_change_confirmation",
        "path": EVIDENCE_DIR / "confirmation-en-v1.txt",
        "bytes": 454,
        "sha256": "225434e7cbdb52d7ea9a092927acbc8b9acde9a07b89f2572b633b3eb8b63ae5",
        "content_item_id": "NEWYOU-CONTENTITEM-PRIMARY-EMAIL-CHANGE-CONFIRMATION-MESSAGE-EMAIL",
        "content_version_id": "NEWYOU-CONTENTVERSION-PRIMARY-EMAIL-CHANGE-CONFIRMATION-MESSAGE-EMAIL-V1",
        "translation_version_id": "NEWYOU-CONTENTTRANSLATIONVERSION-PRIMARY-EMAIL-CHANGE-CONFIRMATION-MESSAGE-EMAIL-EN-V1",
        "tokens": [
            {"literal": "{{platform_name}}", "type": "platform_display_name", "fields": ["subject", "body"]},
            {"literal": "{{email_change_confirmation_link}}", "type": "identity_primary_email_change_confirmation_url", "fields": ["body"]},
        ],
    },
    ("primary_email_change_confirmation_message", "af"): {
        "communications_role": "email_change_confirmation",
        "path": EVIDENCE_DIR / "confirmation-af-v1.txt",
        "bytes": 498,
        "sha256": "be8a5049931e2a942c88fa4159715e0c0c460b55879a3d6b7a780d4f7f26e204",
        "content_item_id": "NEWYOU-CONTENTITEM-PRIMARY-EMAIL-CHANGE-CONFIRMATION-MESSAGE-EMAIL",
        "content_version_id": "NEWYOU-CONTENTVERSION-PRIMARY-EMAIL-CHANGE-CONFIRMATION-MESSAGE-EMAIL-V1",
        "translation_version_id": "NEWYOU-CONTENTTRANSLATIONVERSION-PRIMARY-EMAIL-CHANGE-CONFIRMATION-MESSAGE-EMAIL-AF-V1",
        "tokens": [
            {"literal": "{{platform_name}}", "type": "platform_display_name", "fields": ["subject", "body"]},
            {"literal": "{{email_change_confirmation_link}}", "type": "identity_primary_email_change_confirmation_url", "fields": ["body"]},
        ],
    },
    ("primary_email_change_old_address_notice", "en"): {
        "communications_role": "email_change_old_address_notice",
        "path": EVIDENCE_DIR / "notice-en-v1.txt",
        "bytes": 327,
        "sha256": "937b7aa3fb0018f12157946c7ace16d30503ddba8ab52f2a446cff98a1505abc",
        "content_item_id": "NEWYOU-CONTENTITEM-PRIMARY-EMAIL-CHANGE-OLD-ADDRESS-NOTICE-EMAIL",
        "content_version_id": "NEWYOU-CONTENTVERSION-PRIMARY-EMAIL-CHANGE-OLD-ADDRESS-NOTICE-EMAIL-V1",
        "translation_version_id": "NEWYOU-CONTENTTRANSLATIONVERSION-PRIMARY-EMAIL-CHANGE-OLD-ADDRESS-NOTICE-EMAIL-EN-V1",
        "tokens": [
            {"literal": "{{platform_name}}", "type": "platform_display_name", "fields": ["subject", "body"]},
            {"literal": "{{support_contact}}", "type": "approved_non_secret_support_contact", "fields": ["body"]},
        ],
    },
    ("primary_email_change_old_address_notice", "af"): {
        "communications_role": "email_change_old_address_notice",
        "path": EVIDENCE_DIR / "notice-af-v1.txt",
        "bytes": 369,
        "sha256": "6effc50c65c2e592ac237984b236f3d4aa1723f92378268d424fc05810571f3e",
        "content_item_id": "NEWYOU-CONTENTITEM-PRIMARY-EMAIL-CHANGE-OLD-ADDRESS-NOTICE-EMAIL",
        "content_version_id": "NEWYOU-CONTENTVERSION-PRIMARY-EMAIL-CHANGE-OLD-ADDRESS-NOTICE-EMAIL-V1",
        "translation_version_id": "NEWYOU-CONTENTTRANSLATIONVERSION-PRIMARY-EMAIL-CHANGE-OLD-ADDRESS-NOTICE-EMAIL-AF-V1",
        "tokens": [
            {"literal": "{{platform_name}}", "type": "platform_display_name", "fields": ["subject", "body"]},
            {"literal": "{{support_contact}}", "type": "approved_non_secret_support_contact", "fields": ["body"]},
        ],
    },
}

EXPECTED_ELIGIBILITY = {
    "development": True,
    "automated_tests": True,
    "development_environments": True,
    "bounded_p8_16_proof": True,
    "runtime_release": False,
    "publication": False,
    "production": False,
    "public_release": False,
    "paid_pilot": False,
    "real_participant_delivery": False,
    "phase_9": False,
}

APPROVAL_ROLES = {
    "Product owner": [PRODUCT_RECORD],
    "Content & Media owner": [PRODUCT_RECORD],
    "English Language Reviewer": [PRODUCT_RECORD],
    "Afrikaans Language Reviewer": [PRODUCT_RECORD, AF_BODY_RECORD],
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_json(root: Path, path: Path) -> dict[str, Any]:
    return json.loads((root / path).read_text(encoding="utf-8"))


def read_bytes(root: Path, path: Path) -> bytes:
    return (root / path).read_bytes()


def check_product_lineage(root: Path, router: dict[str, Any], errors: list[str]) -> None:
    all_rows = router.get("governing_documents", [])
    for document_id, expected in PRODUCT_DOCUMENTS.items():
        routes = [row for row in all_rows if row.get("document_id") == document_id]
        if len(routes) != 1:
            errors.append(f"missing current Product route: {document_id}")
            continue
        route = routes[0]

        path = expected["path"]
        try:
            current_bytes = read_bytes(root, path)
            predecessor_bytes = read_bytes(root, expected["predecessor"])
        except OSError:
            errors.append(f"Product successor or predecessor is unreadable: {document_id}")
            continue

        expected_route = {
            "document_id": document_id,
            "canonical_filename": path.name,
            "repository_path": path.as_posix(),
            "sha256": expected["sha256"],
            "semver": "1.17.0",
        }
        if {key: route.get(key) for key in expected_route} != expected_route:
            errors.append(f"current Product route mismatch: {document_id}")
        if sha256(current_bytes) != expected["sha256"]:
            errors.append(f"Product successor digest mismatch: {document_id}")
        if sha256(predecessor_bytes) != expected["predecessor_sha256"]:
            errors.append(f"Product predecessor digest mismatch: {document_id}")

        text = current_bytes.decode("utf-8")
        if f"**Predecessor:** `{expected['predecessor'].as_posix()}`" not in text:
            errors.append(f"Product predecessor lineage missing: {document_id}")
        if expected["transition"] not in text:
            errors.append(f"Product SemVer lineage missing: {document_id}")

    try:
        platform = read_bytes(root, PRODUCT_DOCUMENTS["PLATFORM_PRODUCT_LAW"]["path"]).decode("utf-8")
        decisions = read_bytes(root, PRODUCT_DOCUMENTS["PRODUCT_DECISIONS"]["path"]).decode("utf-8")
    except (OSError, UnicodeDecodeError):
        errors.append("Product successor text is unreadable")
        return

    required_platform_text = [
        "## 21E.27 Primary-email-change message classifications",
        "## 21E.28 Bounded P8-16 development content eligibility",
        "primary_email_change_confirmation_message",
        "primary_email_change_old_address_notice",
        "Both types are Class A with `identity_security` content risk.",
        "The `{{support_contact}}` token remains unbound and delivery remains disabled",
    ]
    if any(fragment not in platform for fragment in required_platform_text):
        errors.append("Product successor is missing approved WELL-122 classifications or scope")
    if "## DEC-324 Primary-email-change message classifications and bounded development eligibility" not in decisions:
        errors.append("DEC-324 is missing from the Product decision successor")


def check_delivery_route(root: Path, packet: dict[str, Any], errors: list[str]) -> None:
    try:
        router = read_json(root, DELIVERY_ROUTER_PATH)
        packet_bytes = read_bytes(root, PACKET_PATH)
    except (OSError, json.JSONDecodeError):
        errors.append("current delivery router or evidence packet is unreadable")
        return

    routes = [
        item
        for item in router.get("delivery_contracts", [])
        if item.get("document_id") == "PRIMARY_EMAIL_CHANGE_MESSAGE_DEVELOPMENT_EVIDENCE"
    ]
    expected = {
        "document_id": "PRIMARY_EMAIL_CHANGE_MESSAGE_DEVELOPMENT_EVIDENCE",
        "canonical_filename": PACKET_PATH.name,
        "repository_path": PACKET_PATH.as_posix(),
        "sha256": sha256(packet_bytes),
        "contract_type": "content_evidence",
        "status": "DEVELOPMENT_ONLY_APPROVED; DELIVERY_DISABLED",
    }
    if routes != [expected]:
        errors.append("current delivery evidence route mismatch")
    if packet.get("delivery_authorized") is not False:
        errors.append("delivery must remain disabled")
    if packet.get("support_contact_bound") is not False:
        errors.append("support contact must remain unbound")
    for field in ("runtime_release", "runtime_release_eligible"):
        if packet.get(field) is not False:
            errors.append(f"{field} must remain disabled")


def check_attribution(root: Path, packet: dict[str, Any], errors: list[str]) -> None:
    try:
        attribution_bytes = read_bytes(root, ATTRIBUTION_PATH)
        attribution = json.loads(attribution_bytes)
        capacity_bytes = read_bytes(root, CAPACITY_PATH)
        capacity = json.loads(capacity_bytes)
    except (OSError, json.JSONDecodeError):
        errors.append("owner attribution or role-capacity evidence is unreadable")
        return

    if sha256(attribution_bytes) != packet.get("approval_attribution_sha256"):
        errors.append("owner attribution digest mismatch")
    if sha256(capacity_bytes) != CAPACITY_SHA256:
        errors.append("role-capacity evidence digest mismatch")
    source = attribution.get("decision_source", {})
    if (
        attribution.get("actor_id") != OWNER_ACTOR
        or attribution.get("independent_human_approvals_claimed") is not False
        or source.get("kind") != "direct_owner_messages_in_this_conversation"
        or source.get("owner_actor_id") != OWNER_ACTOR
        or "not direct owner-authored Plane comments" not in source.get("trace_recording_note", "")
    ):
        errors.append("direct owner decisions and agent-authored Plane traces are conflated")

    recorded_sources = {
        item.get("id"): item.get("record_type")
        for item in attribution.get("source_comments", [])
    }
    expected_source_types = {
        PRODUCT_RECORD: "agent_authored_trace_of_direct_owner_message",
        AF_BODY_RECORD: "agent_authored_trace_of_direct_owner_message",
    }
    if recorded_sources != expected_source_types:
        errors.append("owner decision trace provenance mismatch")

    role_decisions = {item.get("role"): item for item in attribution.get("role_decisions", [])}
    if set(role_decisions) != set(APPROVAL_ROLES):
        errors.append("Product, Content, EN and AF role-attribution coverage mismatch")
    for role, expected_sources in APPROVAL_ROLES.items():
        decision = role_decisions.get(role, {})
        if (
            decision.get("decision") != "approve"
            or decision.get("source_comments") != expected_sources
            or decision.get("owner_decision_actor_id") != OWNER_ACTOR
            or decision.get("separate_owner_event_claimed") is not False
        ):
            errors.append(f"owner decision role attribution invalid: {role}")

    capacity_source = packet.get("role_capacity_source", {})
    if (
        capacity.get("record_id") != "WELL-110-OWNER-APPROVALS-V1"
        or capacity.get("role_attestation") != capacity_source.get("attestation_id")
        or capacity_source.get("path") != CAPACITY_PATH.as_posix()
        or capacity_source.get("sha256") != CAPACITY_SHA256
    ):
        errors.append("role-capacity attestation identity mismatch")


def check_message(root: Path, packet: dict[str, Any], message: dict[str, Any], errors: list[str]) -> None:
    key = (message.get("type"), message.get("locale"))
    expected = MESSAGE_VERSIONS.get(key)
    if expected is None:
        errors.append("unknown message type or locale")
        return

    for field in ("path", "bytes", "sha256", "content_item_id", "content_version_id", "translation_version_id", "communications_role"):
        value = expected[field]
        if field == "path":
            value = value.as_posix()
        if message.get(field) != value:
            errors.append(f"immutable message identity mismatch: {field}")

    try:
        data = read_bytes(root, expected["path"])
    except OSError:
        errors.append("message artifact missing")
        return

    if len(data) != expected["bytes"] or sha256(data) != expected["sha256"]:
        errors.append("message bytes differ from the approved immutable version")
    if not data.startswith(b"subject: ") or b"\r" in data or not data.endswith(b"\n") or data.endswith(b"\n\n"):
        errors.append("message serialization invalid")
    if len(data.split(b"\n\n", 1)) != 2:
        errors.append("subject/body separator invalid")

    tokens = message.get("tokens")
    if tokens != expected["tokens"]:
        errors.append("typed token contract mismatch")
        tokens = []
    actual_tokens = set(re.findall(rb"\{\{[^{}]+\}\}", data))
    if actual_tokens != {token["literal"].encode() for token in expected["tokens"]}:
        errors.append("literal token allowlist mismatch")
    token_hash = sha256(json.dumps(tokens, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode())
    if token_hash != message.get("token_contract_sha256"):
        errors.append("token contract digest mismatch")

    if (message.get("copy_class"), message.get("content_risk"), message.get("wording_risk"), message.get("identity_security_risk")) != ("A", "identity_security", "editorial_low_risk", "HIGH"):
        errors.append("message risk classification mismatch")
    if message.get("state") != "development_approved":
        errors.append("message is not eligible for bounded development use")

    roles = message.get("role_evidence", {})
    capacity_source = packet.get("role_capacity_source", {})
    language_role = f"{message.get('locale')}_language_reviewer"
    required_roles = {"product_owner", "content_media_owner", language_role}
    if set(roles) != required_roles:
        errors.append("exact-version role evidence missing")
        return

    for role_name, proof in roles.items():
        expected_recording_ids = (
            [PRODUCT_RECORD, AF_BODY_RECORD]
            if message.get("locale") == "af" and role_name != "product_owner"
            else [PRODUCT_RECORD]
        )
        if (
            proof.get("recording_comment_ids") != expected_recording_ids
            or proof.get("actor_id") != OWNER_ACTOR
            or proof.get("decision") != "approve"
            or proof.get("separate_owner_event_claimed") is not False
        ):
            errors.append(f"owner decision trace mismatch: {role_name}")
        if (
            proof.get("capacity_source_path") != capacity_source.get("path")
            or proof.get("capacity_source_sha256") != capacity_source.get("sha256")
            or proof.get("capacity_record") != capacity_source.get("attestation_id")
        ):
            errors.append(f"role-capacity binding mismatch: {role_name}")
        binding = proof.get("binding", {})
        if (
            binding.get("type") != message.get("type")
            or binding.get("locale") != message.get("locale")
            or binding.get("content_item_id") != expected["content_item_id"]
            or binding.get("content_version_id") != expected["content_version_id"]
            or binding.get("translation_version_id") != expected["translation_version_id"]
            or binding.get("sha256") != expected["sha256"]
            or binding.get("bytes") != expected["bytes"]
            or binding.get("token_contract_sha256") != message.get("token_contract_sha256")
            or binding.get("scope") != packet.get("scope")
        ):
            errors.append(f"exact message version binding mismatch: {role_name}")


def validate_packet(root: Path, packet: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    expected_scope = [
        "local development",
        "automated tests",
        "development environments",
        "bounded P8-16 Phase-8 proof",
    ]
    if packet.get("status") != "DEVELOPMENT_ONLY_APPROVED":
        errors.append("packet is not development approved")
    if packet.get("product_authority", {}).get("product_decision") != "DEC-324":
        errors.append("Product authority missing")
    if packet.get("product_authority", {}).get("source_comment_id") != PRODUCT_RECORD:
        errors.append("Product decision trace missing")
    if packet.get("product_authority", {}).get("proposal_path") != PROPOSAL_PATH.as_posix():
        errors.append("Product proposal path mismatch")
    try:
        if sha256(read_bytes(root, PROPOSAL_PATH)) != PRODUCT_PROPOSAL_SHA256:
            errors.append("Product proposal digest mismatch")
    except OSError:
        errors.append("Product classification proposal is missing")

    eligibility = packet.get("eligibility")
    # Identity checks reject JSON numbers such as 0/1 as well as missing,
    # extra or contradictory grants. This map is an authority allowlist.
    if (
        not isinstance(eligibility, dict)
        or set(eligibility) != set(EXPECTED_ELIGIBILITY)
        or any(eligibility[key] is not allowed for key, allowed in EXPECTED_ELIGIBILITY.items())
    ):
        errors.append("development-only eligibility map mismatch")
    if packet.get("scope") != expected_scope:
        errors.append("development-only applicability mismatch")
    if packet.get("latest_alias") is not False or packet.get("silent_locale_fallback") is not False:
        errors.append("latest alias and silent locale fallback must fail closed")
    lifecycle = packet.get("lifecycle", {})
    if lifecycle.get("terminal_for_new_use") != ["superseded", "withdrawn"] or lifecycle.get("revalidate_before_new_use") is not True:
        errors.append("lifecycle eligibility guards missing")

    try:
        governance_router = read_json(root, GOVERNANCE_ROUTER_PATH)
        check_product_lineage(root, governance_router, errors)
    except (OSError, json.JSONDecodeError):
        errors.append("current governance router is unreadable")
    check_delivery_route(root, packet, errors)
    check_attribution(root, packet, errors)

    messages = packet.get("messages")
    if not isinstance(messages, list) or len(messages) != len(MESSAGE_VERSIONS):
        return errors + ["expected four immutable EN/AF message versions"]
    seen: set[tuple[str, str]] = set()
    for message in messages:
        key = (message.get("type"), message.get("locale"))
        if key in seen:
            errors.append("duplicate type/locale version")
        seen.add(key)
        check_message(root, packet, message, errors)
    if seen != set(MESSAGE_VERSIONS):
        errors.append("incomplete type/locale coverage")
    return errors


def validate(root: Path) -> list[str]:
    try:
        packet = read_json(root, PACKET_PATH)
    except (OSError, json.JSONDecodeError) as exc:
        return [f"packet unreadable: {exc}"]
    return validate_packet(root, packet)


def main() -> int:
    errors = validate(Path.cwd())
    for error in errors:
        print(f"FAIL: {error}")
    if errors:
        return 1
    print("PASS: WELL-122 exact message evidence")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
