"""Validate WELL-157's exact WELL-156-only email applicability evidence."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from tools import check_email_change_message_evidence as legacy

PACKET_PATH = Path(
    "docs/delivery/content-evidence/content_media/email_change_messages/"
    "WELL157_PHASE9_APPLICABILITY_EVIDENCE_v0.1.0.json"
)
PROPOSAL_PATH = Path(
    "docs/governance/product/proposals/well-157/PHASE9_EMAIL_APPLICABILITY_v0.1.0_PROPOSED.md"
)
BINDINGS_PATH = Path(
    "docs/governance/product/proposals/well-157/EXACT_BINDINGS_v0.1.0.json"
)
HISTORICAL_PACKET = legacy.PACKET_PATH
HISTORICAL_ATTRIBUTION = legacy.ATTRIBUTION_PATH
GOVERNANCE_ROUTER = legacy.GOVERNANCE_ROUTER_PATH
DELIVERY_ROUTER = legacy.DELIVERY_ROUTER_PATH
OWNER_ACTOR = "2d75ac08-a11c-4fe1-9545-c1d885f83955"
PROPOSAL_SHA256 = "a0d9c2e2ce038bddf36386974f1b1d02f24896e336b3f5214cf537463065909e"
BINDINGS_SHA256 = "75aaffb695fd2e49d20f9a6f8d91350e05f0ce19ef2033aa76e9d18b4024a027"
HISTORICAL_PACKET_SHA256 = "3db7668d20090ec5b53c7ba2213865ab64818e52f87d4da99b2e986ed19355df"
HISTORICAL_ATTRIBUTION_SHA256 = "cdc51ab89518febfe53a0dab5ca8a0beb969c2098c8ee602504baf33b91e5159"
CONTEXT = "bounded non-production FP-001 Phase-9 WELL-156 verification"
EVENTS = {
    "c0ca49a1-5a63-4c66-9898-50155fb70181": (
        "2026-11-18T15:20:52.818799Z", "Product owner", "WELL157-PRODUCT-v0.1.0", "product_law"
    ),
    "6db4ee63-b351-4b33-b80a-e69edb523237": (
        "2026-11-18T15:20:53.637249Z", "Content & Media owner", "WELL157-CONTENT-CONFIRM-EN-v0.1.0", "primary_email_change_confirmation_message:en"
    ),
    "01e932aa-45ee-4993-8ebb-c8308fd8262c": (
        "2026-11-18T15:20:56.928619Z", "Content & Media owner", "WELL157-CONTENT-CONFIRM-AF-v0.1.0", "primary_email_change_confirmation_message:af"
    ),
    "3228ed49-d9a4-416f-bf07-e8dad2f02957": (
        "2026-11-18T15:21:01.377499Z", "Content & Media owner", "WELL157-CONTENT-NOTICE-EN-v0.1.0", "primary_email_change_old_address_notice:en"
    ),
    "f18b7fe2-123e-498e-874f-f4823ee13bec": (
        "2026-11-18T15:21:04.973480Z", "Content & Media owner", "WELL157-CONTENT-NOTICE-AF-v0.1.0", "primary_email_change_old_address_notice:af"
    ),
}
CURRENT_AUTHORITY = {
    "PLATFORM_PRODUCT_LAW": {
        "path": "docs/governance/product/00_PLATFORM_v1.19.0.md",
        "sha256": "e94fd66f09aa4033fb66ffa3d73ab6f28a650c589dce33c086c746e2e508e9b9",
        "predecessor": "docs/governance/product/00_PLATFORM_v1.18.0.md",
        "predecessor_sha256": "a4f59321e6de36314633bf3bd202d365cd2f99fa52bfcb5639482a71ddcd392f",
    },
    "PRODUCT_DECISIONS": {
        "path": "docs/governance/product/01_DECISIONS_v1.19.0.md",
        "sha256": "ed90a1ec6adb201de094f130fc091c10bca6145e142a6e225fc840794553f4c2",
        "predecessor": "docs/governance/product/01_DECISIONS_v1.18.0.md",
        "predecessor_sha256": "937c4555c8f0d319c85a2f1fca02c60f181e9ad157d0f1c4349d2ab1f38996d0",
    },
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_json(root: Path, path: Path) -> dict[str, Any]:
    return json.loads((root / path).read_text(encoding="utf-8"))


def read_packet(root: Path) -> dict[str, Any]:
    return read_json(root, PACKET_PATH)


def _event_errors(packet: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    events = packet.get("new_applicability_events")
    if not isinstance(events, list):
        return ["five exact applicability decision transcriptions are required"]
    unique_events: dict[str, dict[str, Any]] = {}
    expected_quote = "Approve all five decisions in the named capacities"
    for event in events:
        if not isinstance(event, dict):
            errors.append("applicability decision event must be an object")
            continue
        ref = event.get("event_ref")
        if ref in unique_events:
            if event != unique_events[ref]:
                errors.append("conflicting applicability event replay")
            continue
        unique_events[ref] = event
        expected = EVENTS.get(ref)
        if expected is None:
            errors.append("unknown applicability event reference")
            continue
        recorded_at, role, label, subject = expected
        if (
            event.get("recording_comment_id") != ref
            or event.get("record_type") != "agent_authored_trace_of_direct_user_message"
            or event.get("recorded_at") != recorded_at
            or event.get("role") != role
            or event.get("decision_label") != label
            or event.get("subject") != subject
            or event.get("decision") != "APPROVE_SCOPE_EXTENSION"
            or event.get("actor_identity") != OWNER_ACTOR
            or event.get("source_type") != "agent_transcription_of_direct_user_decision"
            or event.get("source_quote") != expected_quote
            or event.get("direct_owner_plane_post") is not False
            or event.get("independent_review") is not False
            or event.get("proposal_sha256") != PROPOSAL_SHA256
            or event.get("bindings_sha256") != BINDINGS_SHA256
            or event.get("context") != CONTEXT
        ):
            errors.append("applicability event attribution or exact binding mismatch")
        if subject == "product_law":
            exact_subjects = [
                {"document_id": "PLATFORM_PRODUCT_LAW", "path": "docs/governance/product/00_PLATFORM_v1.19.0.md", "section": "§21E.30"},
                {"document_id": "PRODUCT_DECISIONS", "path": "docs/governance/product/01_DECISIONS_v1.19.0.md", "section": "DEC-326"},
            ]
        else:
            message_type, locale = subject.split(":")
            message = next((m for m in packet.get("messages", []) if isinstance(m, dict) and (m.get("type"), m.get("locale")) == (message_type, locale)), {})
            exact_subjects = [{
                "type": message_type,
                "locale": locale,
                "content_item_id": message.get("content_item_id"),
                "content_version_id": message.get("content_version_id"),
                "translation_version_id": message.get("translation_version_id"),
                "path": message.get("path"),
                "bytes": message.get("bytes"),
                "sha256": message.get("sha256"),
                "format_id": "subject-body-utf8-lf-v1",
                "token_contract_sha256": message.get("token_contract_sha256"),
                "communications_role": message.get("communications_role"),
            }]
        if event.get("subjects") != exact_subjects:
            errors.append("applicability event subject binding mismatch")
    if set(unique_events) != set(EVENTS):
        errors.append("incomplete applicability decision coverage")
    return errors


def _message_errors(root: Path, packet: dict[str, Any], old: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    messages = packet.get("messages")
    if messages != old.get("messages"):
        errors.append("historical message identities, approvals, language reviews or token bindings changed")
        return errors
    if len(messages) != 4:
        return ["exact EN/AF message coverage is incomplete"]
    for message in messages:
        key = (message.get("type"), message.get("locale"))
        expected = legacy.MESSAGE_VERSIONS.get(key)
        if expected is None:
            errors.append("unknown email message identity")
            continue
        path = root / expected["path"]
        try:
            content = path.read_bytes()
        except OSError:
            errors.append("immutable email message is missing")
            continue
        if len(content) != expected["bytes"] or sha256(content) != expected["sha256"]:
            errors.append("immutable email message bytes changed")
        if message.get("state") != "development_approved":
            errors.append("historical Phase-8 approval state changed")
    return errors


def validate_packet(root: Path, packet: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if packet.get("packet_id") != "WELL157_PRIMARY_EMAIL_CHANGE_PHASE9_APPLICABILITY_v0.1.0":
        errors.append("applicability packet identity mismatch")
    if packet.get("status") != "BOUNDED_WELL156_NONPRODUCTION_PHASE9_APPLICABILITY_APPROVED; DELIVERY_DISABLED":
        errors.append("applicability packet is not in its approved development state")
    if packet.get("implementation_ticket") != "WELL-156" or packet.get("context") != CONTEXT:
        errors.append("applicability is outside the named WELL-156 context")
    if packet.get("runtime_eligible") is not False:
        errors.append("runtime eligibility must remain disabled")
    if packet.get("delivery_authorized") is not False:
        errors.append("delivery must remain disabled")
    if packet.get("support_contact_bound") is not False or packet.get("support_contact_value") is not None:
        errors.append("support contact must remain unbound")
    if packet.get("independent_master_gate_complete") is not False:
        errors.append("independent Master Gate cannot be claimed")
    if packet.get("new_applicability_events_attributable_to_direct_owner_posts") is not False:
        errors.append("agent transcriptions cannot be described as direct owner posts")
    if packet.get("context_scope") != [
        "local development within WELL-156",
        "automated tests within WELL-156",
        "development environments within WELL-156",
        CONTEXT,
    ]:
        errors.append("context scope must remain limited to WELL-156")
    if packet.get("lifecycle") != {
        "state": "development_approved",
        "states": ["candidate", "development_approved", "superseded", "withdrawn"],
        "transition": "development_approved → development_approved by append-only exact-context evidence",
        "terminal_for_new_use": ["superseded", "withdrawn"],
        "revalidate_before_new_use": True,
        "revalidate_before_queued_use": True,
        "queued_use_retains_eligibility_after_withdrawal": False,
        "idempotency": "The same exact event reference, role, version, bytes, token contract and context is idempotent.",
        "conflicts": "Conflicting applicability decisions fail closed until explicit owner reconciliation.",
    }:
        errors.append("applicability lifecycle, withdrawal or replay guards mismatch")
    if packet.get("applicability") != {
        "existing_phase8_scope_preserved": True,
        "allowed": [CONTEXT],
        "prohibited": [
            "production", "public release", "paid pilot", "real participants",
            "real-participant delivery", "live email delivery", "external sender/provider",
            "runtime Content role", "any Phase-9 use outside WELL-156",
        ],
        "latest_alias": False,
        "silent_locale_fallback": False,
    }:
        errors.append("bounded applicability or explicit prohibitions mismatch")

    try:
        proposal = (root / PROPOSAL_PATH).read_bytes()
        bindings = (root / BINDINGS_PATH).read_bytes()
        historical = (root / HISTORICAL_PACKET).read_bytes()
        attribution = (root / HISTORICAL_ATTRIBUTION).read_bytes()
        old = json.loads(historical)
    except (OSError, json.JSONDecodeError):
        return errors + ["proposal, bindings or immutable historical evidence is unreadable"]
    if sha256(proposal) != PROPOSAL_SHA256 or sha256(bindings) != BINDINGS_SHA256:
        errors.append("approved proposal or exact bindings inventory digest mismatch")
    if packet.get("proposal_binding") != {
        "path": PROPOSAL_PATH.as_posix(), "sha256": PROPOSAL_SHA256,
        "approved_exact_sections": ["§21E.30", "DEC-326"],
    }:
        errors.append("approved Product proposal binding mismatch")
    if packet.get("bindings_inventory") != {"path": BINDINGS_PATH.as_posix(), "sha256": BINDINGS_SHA256}:
        errors.append("approved exact bindings inventory mismatch")
    predecessor = packet.get("historical_packet", {})
    if sha256(historical) != HISTORICAL_PACKET_SHA256 or predecessor != {"path": HISTORICAL_PACKET.as_posix(), "sha256": HISTORICAL_PACKET_SHA256, "preserved_unmodified": True}:
        errors.append("historical packet provenance mismatch")
    prior_attribution = packet.get("historical_owner_attribution", {})
    if sha256(attribution) != HISTORICAL_ATTRIBUTION_SHA256 or prior_attribution != {"path": HISTORICAL_ATTRIBUTION.as_posix(), "sha256": HISTORICAL_ATTRIBUTION_SHA256, "preserved_unmodified": True}:
        errors.append("historical owner attribution provenance mismatch")
    errors.extend(_message_errors(root, packet, old))

    try:
        router = read_json(root, GOVERNANCE_ROUTER)
        legacy.check_product_lineage(root, router, errors)
        platform, decisions = [], []
        for doc_id, expected in CURRENT_AUTHORITY.items():
            path = expected["path"]
            data = (root / path).read_bytes()
            prior = (root / expected["predecessor"]).read_bytes()
            if (
                sha256(data) != expected["sha256"]
                or sha256(prior) != expected["predecessor_sha256"]
                or f"**Predecessor:** `{expected['predecessor']}`".encode() not in data
                or "**SemVer transition:** `v1.18.0 → v1.19.0`".encode() not in data
            ):
                errors.append(f"historical WELL-157 Product authority lineage mismatch: {doc_id}")
            if doc_id == "PLATFORM_PRODUCT_LAW":
                platform = data.decode("utf-8")
            else:
                decisions = data.decode("utf-8")
        if "## 21E.30 WELL-156 bounded Phase-9 primary-email-change message applicability" not in platform:
            errors.append("current Product authority omits approved §21E.30")
        if "## DEC-326 WELL-156 primary-email-change bounded Phase-9 development exception" not in decisions:
            errors.append("current Product decisions omit approved DEC-326")
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        errors.append("current Product authority is unreadable")

    expected_authority = []
    for document_id, section in (("PLATFORM_PRODUCT_LAW", "§21E.30"), ("PRODUCT_DECISIONS", "DEC-326")):
        expected = CURRENT_AUTHORITY[document_id]
        expected_authority.append({
            "document_id": document_id,
            "path": expected["path"],
            "sha256": expected["sha256"],
            "section": section,
            "predecessor_path": expected["predecessor"],
            "predecessor_sha256": expected["predecessor_sha256"],
        })
    if packet.get("current_governing_authority") != expected_authority:
        errors.append("packet current Product authority binding mismatch")
    try:
        delivery = read_json(root, DELIVERY_ROUTER)
        packet_bytes = (root / PACKET_PATH).read_bytes()
        routes = [x for x in delivery.get("delivery_contracts", []) if x.get("document_id") == "WELL157_PRIMARY_EMAIL_CHANGE_PHASE9_APPLICABILITY_EVIDENCE"]
        expected_route = {
            "document_id": "WELL157_PRIMARY_EMAIL_CHANGE_PHASE9_APPLICABILITY_EVIDENCE",
            "canonical_filename": PACKET_PATH.name,
            "repository_path": PACKET_PATH.as_posix(),
            "sha256": sha256(packet_bytes),
            "contract_type": "content_evidence",
            "status": "BOUNDED_WELL156_NONPRODUCTION_PHASE9; DELIVERY_DISABLED",
        }
        if routes != [expected_route]:
            errors.append("current delivery route does not bind the exact applicability packet")
    except (OSError, json.JSONDecodeError):
        errors.append("current delivery router is unreadable")

    errors.extend(_event_errors(packet))
    return errors


def eligible_for(root: Path, packet: dict[str, Any], context: str) -> bool:
    return (
        context == CONTEXT
        and packet.get("context") == CONTEXT
        and packet.get("runtime_eligible") is False
        and packet.get("delivery_authorized") is False
        and not validate_packet(root, packet)
    )


def validate(root: Path) -> list[str]:
    try:
        packet = read_packet(root)
    except (OSError, json.JSONDecodeError):
        return ["applicability packet is unreadable"]
    return validate_packet(root, packet)


def main() -> int:
    errors = validate(Path.cwd())
    for error in errors:
        print(f"FAIL: {error}")
    if errors:
        return 1
    print("PASS: WELL-157 bounded applicability evidence")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
