#!/usr/bin/env python3
"""Validate WELL-97's permanently candidate evidence. This tool grants no eligibility."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACKET_PATH = Path("docs/delivery/content-evidence/content_media/magic_login_messages/MAGIC_LOGIN_MESSAGE_EVIDENCE_PACKET_v0.1.0.json")
ALLOWED = ["local development", "automated tests", "development environments", "bounded P8-09 Phase-8 proof"]
PROHIBITED = ["production", "public release", "paid pilot", "real-participant delivery"]
ITEM = "NEWYOU-CONTENTITEM-MAGIC-LOGIN-MESSAGE-EMAIL"
VERSION = "NEWYOU-CONTENTVERSION-MAGIC-LOGIN-MESSAGE-EMAIL-V1"
TOKENS = ["{{platform_name}}", "{{magic_login_link}}"]


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def validate(root: Path, packet: dict) -> list[str]:
    """Return integrity findings, never approval. Noncandidate records need new review."""
    errors = []

    def check(ok, message):
        if not ok:
            errors.append(message)

    def artifact(record):
        path = root / record["path"]
        if not path.resolve().is_relative_to(root.resolve()) or path.is_symlink():
            raise ValueError("unsafe artifact path")
        raw = path.read_bytes()
        check(digest(raw) == record["sha256"], "artifact digest mismatch: " + record["path"])
        if "bytes" in record:
            check(len(raw) == record["bytes"], "artifact byte count mismatch")
        return raw

    try:
        check(packet["packet_id"] == "magic-login-message-email-candidate-evidence-v0.1.0", "wrong packet identity")
        check(packet["status"] == "CANDIDATE_NOT_APPROVED", "candidate status required")
        check(packet["owner"] == "Content & Media", "wrong content owner")
        check(packet["content_item_id"] == ITEM and packet["content_version_id"] == VERSION, "wrong parent identities")
        check(packet["eligibility"] == dict.fromkeys([
            "development", "runtime_release", "production", "public_release", "paid_pilot", "real_participant_delivery"
        ], False), "candidate must be ineligible in every context")
        check(packet["scope"] == {"allowed": ALLOWED, "prohibited": PROHIBITED}, "invalid scope")
        check(packet["binding"] == {"resolution": "exact IDs only", "latest_alias": False, "silent_locale_fallback": False}, "invalid content binding")
        check(packet["approval_events"] == [], "candidate cannot contain approval events")
        lifecycle = packet["lifecycle"]
        check(lifecycle["state"] == "candidate", "candidate lifecycle required")
        check(lifecycle["states"] == ["candidate", "development_approved", "superseded", "withdrawn"], "wrong lifecycle states")
        check(lifecycle["transitions"] == {"candidate": ["development_approved"], "development_approved": ["superseded", "withdrawn"], "superseded": [], "withdrawn": []}, "wrong lifecycle transitions")
        check(lifecycle["terminal_for_new_use"] == ["superseded", "withdrawn"], "terminal states required")
        check(lifecycle["idempotency_key"] == ["decision_id", "content_item_id", "content_version_id", "content_translation_version_id", "locale", "format_id", "sha256", "token_contract_sha256", "applicability"], "incomplete idempotency binding")
        check(lifecycle["conflict"] == "STOP_AND_RECONCILE; never last-write-wins", "conflicts must stop new use")
        check(lifecycle["transition_guards"] == {
            "candidate_to_development_approved": ["accountable Product-owner approval", "accountable Content & Media owner exact-byte approval", "all exact subjects and token/scope bindings verified", "no conflicting unresolved decision", "complete append-only history"],
            "terminal_transition": ["accountable Content & Media owner decision", "exact prior version and digest", "supersession names an immutable successor"]
        }, "missing accountable transition guards")
        for key, expected in {
            "reconciliation": "Append accountable owner resolution referencing every conflicting event; no new use until resolved. Never edit prior events or bytes.",
            "history": "APPEND_ONLY; changed bytes require new ContentTranslationVersion ID and fresh approval; shared structure changes require successor ContentVersion.",
            "recovery": "Revalidate complete reviewed history and all exact bindings before new use; missing history fails closed."
        }.items():
            check(lifecycle[key] == expected, "invalid lifecycle policy: " + key)
        serialization = packet["serialization"]
        check(serialization["format_id"] == "magic-login-message-subject-body-text-v1", "wrong serialization format")
        check(serialization["encoding"] == "UTF-8" and serialization["line_endings"] == "LF" and serialization["bom"] is False and serialization["terminal_lf_count"] == 1, "invalid encoding")
        check(serialization["subject_prefix"] == "subject: " and serialization["subject_body_boundary"] == "one blank line" and serialization["body_paragraph_boundary"] == "one blank line", "invalid field boundaries")
        tokens = packet["token_allowlist"]
        check([x["literal"] for x in tokens] == TOKENS, "invalid literal token allowlist")
        check([x["type"] for x in tokens] == ["platform_display_name", "identity_magic_login_url"], "invalid token types")
        check([x["allowed_fields"] for x in tokens] == [["subject", "body"], ["body"]], "invalid token field restrictions")
        contract_digest = digest(json.dumps(tokens, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode())
        check(contract_digest == packet["token_contract_sha256"], "token contract digest mismatch")
        source = json.loads(artifact(packet["source"]))
        check(source["comment_id"] == packet["source"]["comment_id"] == "a8059c05-e55a-4802-9a29-5a1273257af1", "wrong candidate source")
        blocks = re.findall(r"<pre>(.*?)</pre>", source["comment_html"], re.S)
        check(len(blocks) == 2, "source must contain both locale blocks")
        check([x["locale"] for x in packet["locale_versions"]] == ["en", "af"], "exact EN/AF locales required")
        for locale, block in zip(packet["locale_versions"], blocks):
            raw = artifact(locale["artifact"])
            check(raw == block.encode("utf-8"), "copy differs from source HTML")
            check(locale["id"] == f"NEWYOU-CONTENTTRANSLATIONVERSION-MAGIC-LOGIN-MESSAGE-EMAIL-{locale['locale'].upper()}-V1", "wrong locale version")
            text = raw.decode("utf-8")
            check(not raw.startswith(b"\xef\xbb\xbf") and b"\r" not in raw and raw.endswith(b"\n") and not raw.endswith(b"\n\n"), "invalid artifact serialization")
            check(text.startswith("subject: ") and all(line == line.rstrip() for line in text.splitlines()), "invalid prefix or trailing whitespace")
            check(set(re.findall(r"\{\{[^{}]+\}\}", text)) == set(TOKENS), "unexpected or missing tokens")
            check(not re.search(r"https?://|www\.|Bearer\s+\S+", text, re.I), "rendered link or bearer in source")
            subject_line, body = raw.split(b"\n\n", 1)
            subject = subject_line[9:]
            for field, value, offset in (("subject", subject, 9), ("body", body, len(subject_line) + 2)):
                check(locale[field] == {"offset": offset, "bytes": len(value), "sha256": digest(value)}, "field binding mismatch")
            compact = raw.replace(b"\n\n", b"\n")
            check(locale["contiguous_rendering"] == {"bytes": len(compact), "sha256": digest(compact)}, "contiguous rendering proof mismatch")
            check(len(raw) - len(compact) == 5, "expected five omitted LF bytes")
        proposal = packet["product_proposal"]
        check((proposal["status"], proposal["recommended_type"], proposal["recommended_wording_risk"], proposal["identity_security_risk"]) == ("PROPOSED_NON_AUTHORITATIVE", "magic_login_message", "editorial_low_risk", "HIGH"), "invalid proposed classification")
        governance = json.loads((root / "docs/governance/CURRENT_GOVERNANCE_ROUTER.json").read_text())
        for document in proposal["documents"]:
            text = artifact(document).decode("utf-8")
            artifact({"path": document["predecessor"], "sha256": document["predecessor_sha256"]})
            check("PROPOSED / NON-AUTHORITATIVE" in text and document["predecessor_sha256"] in text, "unbound or authoritative proposal")
            current = next(x for x in governance["governing_documents"] if x["document_id"] == document["document_id"])
            check(current["repository_path"] == document["predecessor"] and current["sha256"] == document["predecessor_sha256"], "premature current-law promotion")
            indexed = next(x for x in governance["proposed_successors"] if x["document_id"] == document["document_id"])
            check(indexed["repository_path"] == document["path"] and indexed["sha256"] == document["sha256"] and indexed["status"] == "PROPOSED_NON_AUTHORITATIVE", "invalid proposal route")
        decisions = packet["owner_decisions"]
        check([x["owner"] for x in decisions] == ["Product", "Content & Media"], "both owner decisions required")
        for decision in decisions:
            check(decision["status"] == "pending", "unapproved owner decision")
            check(all(decision[x] is None for x in ("actor_identity", "accountable_owner_evidence", "decision_id", "decision_reference", "decided_at")), "candidate must not invent owner evidence")
        check(decisions[0]["subjects"] == proposal["documents"], "Product decision must bind both proposal digests")
        check(decisions[0]["binding"] == {"content_type": "magic_login_message", "wording_risk": "editorial_low_risk", "identity_security_risk": "HIGH", "applicability": packet["scope"]}, "Product decision must bind classification and scope")
        expected = [{"locale": x["locale"], "content_translation_version_id": x["id"], "artifact": x["artifact"], "subject": x["subject"], "body": x["body"]} for x in packet["locale_versions"]]
        check(decisions[1]["subjects"] == expected, "Content decision must bind both exact locale artifacts")
        check(decisions[1]["binding"] == {"content_item_id": ITEM, "content_version_id": VERSION, "format_id": serialization["format_id"], "token_contract_sha256": contract_digest, "applicability": packet["scope"], "product_proposal_digests": [x["sha256"] for x in proposal["documents"]]}, "Content decision must bind parents, format, tokens, scope and Product proposals")
        check(packet["approval_contract"]["recording"] == "APPEND_ONLY", "approval history must be append-only")
        check(packet["approval_contract"]["required_fields"] == ["decision_id", "actor_identity", "accountable_owner_evidence", "decision_reference", "decided_at", "decision", "content_item_id", "content_version_id", "subjects", "format_id", "token_contract_sha256", "applicability", "product_proposal_digests"], "incomplete owner evidence contract")
        check(packet["security"] == {"assent_disposition": "WELL-91 unchanged", "exclusive_expiry": "2026-11-18T00:00:00Z", "authentication_input_rebinding": False, "protected_bearer_retention_extension": False, "runtime_changes": False}, "security boundary changed")
    except (KeyError, TypeError, ValueError, OSError, StopIteration, IndexError) as error:
        errors.append("malformed or missing evidence: " + str(error))
    return errors


if __name__ == "__main__":
    try:
        findings = validate(ROOT, json.loads((ROOT / PACKET_PATH).read_text()))
    except (OSError, ValueError) as error:
        findings = [str(error)]
    print(json.dumps({"integrity": "FAIL" if findings else "PASS", "development_eligible": False, "runtime_release_eligible": False, "findings": findings}, indent=2))
    raise SystemExit(bool(findings))
