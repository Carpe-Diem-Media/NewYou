#!/usr/bin/env python3
"""Verify WELL-97 candidate history and exact owner-approved development evidence."""

from __future__ import annotations

import hashlib
import copy
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
            check("proposals/" not in current["repository_path"], "proposal cannot be governing authority")
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


def validate_development(root: Path, packet: dict) -> list[str]:
    """Check the recorded owner decisions and their exact bindings, never runtime release."""
    errors = []

    def check(ok, message):
        if not ok:
            errors.append(message)

    def load_artifact(record):
        path = root / record["path"]
        if not path.resolve().is_relative_to(root.resolve()) or path.is_symlink():
            raise ValueError("unsafe evidence path")
        raw = path.read_bytes()
        check(digest(raw) == record["sha256"], "evidence digest mismatch: " + record["path"])
        return raw

    try:
        candidate = json.loads(load_artifact(packet["predecessor_packet"]))
        check(packet["predecessor_packet"]["path"] == PACKET_PATH.as_posix(), "wrong candidate predecessor")
        check(packet["predecessor_packet"]["sha256"] == "096401942a84e8c002d9f67d30537e70e1479e8bb2e521814b98e706b262b517", "approved candidate history changed")
        errors.extend(validate(root, candidate))
        source = json.loads(load_artifact(packet["approval_source"]))
        check(packet["approval_source"]["sha256"] == "ee4bb9d52d05c2c897334ead20b5d27fbcfd2174810c3be2c93a17321c2d8e41", "immutable owner decision record changed")
        check(packet["packet_id"] == "magic-login-message-email-development-evidence-v0.2.0", "wrong development packet identity")
        check(packet["status"] == "DEVELOPMENT_ONLY_APPROVED; RUNTIME_RELEASE_PROHIBITED", "wrong development status")
        check(packet["owner"] == "Content & Media", "wrong development owner")
        check(packet["approved_head"] == source["approved_head"] == "387d1f1ff30c4ddd8fb8b3b5f5e95758dfb07e78", "owner decision head mismatch")
        check(source["source"]["created_by"] == "user", "approval must originate from user")
        check(source["source"]["thread_id"] == "93dd4a5e-f360-444f-8363-3d90272308c9" and source["source"]["position"] == 219, "wrong original approval message")
        check(source["merge_authorized"] is False and source["runtime_release_authorized"] is False, "owner approval cannot imply merge or release")
        for field in ("content_item_id", "content_version_id", "scope", "binding", "locale_versions", "serialization", "token_allowlist", "token_contract_sha256", "security"):
            check(packet[field] == candidate[field], "approved candidate binding changed: " + field)
        lifecycle = copy.deepcopy(candidate["lifecycle"])
        lifecycle["state"] = "development_approved"
        check(packet["lifecycle"] == lifecycle, "wrong development lifecycle or terminal version in use")
        eligibility = copy.deepcopy(candidate["eligibility"])
        eligibility["development"] = True
        check(packet["eligibility"] == eligibility, "development cannot authorise runtime or release")
        delivery = json.loads((root / "docs/delivery/CURRENT_DELIVERY_ROUTER.json").read_text())
        active = [x for x in delivery["delivery_contracts"] if x["document_id"] == "MAGIC_LOGIN_MESSAGE_DEVELOPMENT_EVIDENCE"]
        check(len(active) == 1, "missing or ambiguous current development evidence")
        if len(active) == 1:
            route = active[0]
            expected_path = str(PACKET_PATH).replace("v0.1.0", "v0.2.0")
            check(route["repository_path"] == expected_path and route.get("status") == "DEVELOPMENT_ONLY_APPROVED; RUNTIME_RELEASE_PROHIBITED", "development evidence withdrawn, superseded or unsupported")
            load_artifact({"path": route["repository_path"], "sha256": route["sha256"]})
        expected_events = {}
        for index, owner in enumerate(("Product", "Content & Media")):
            decision = source["decisions"][index]
            expected_id = ("WELL-97-PRODUCT-APPROVAL-387d1f1", "WELL-97-CONTENT-APPROVAL-387d1f1")[index]
            answer = ("Approve as Product owner", "Approve exact artifacts as Content owner")[index]
            check(decision == {"decision_id": expected_id, "owner": owner, "answer": answer}, "wrong accountable owner decision")
            check(answer in source["source"]["text"], "owner answer absent from original message")
            expected_events[expected_id] = dict(
                decision_id=expected_id, owner=owner, decision="approve",
                actor_identity=source["actor_identity"], accountable_owner_evidence=packet["approval_source"],
                decision_reference=dict(thread_id=source["source"]["thread_id"], item_id=source["source"]["item_id"], position=219, plane_comment_id=source["plane_record"]["comment_id"]),
                decided_at=source["source"]["received_at"], approved_head=source["approved_head"],
                subjects=candidate["owner_decisions"][index]["subjects"], binding=candidate["owner_decisions"][index]["binding"])
        check(bool(source["actor_identity"]) and bool(source["authority_basis"]), "accountable actor evidence missing")
        seen = {}
        for event in packet["approval_events"]:
            key = event["decision_id"]
            if key in seen:
                check(event == seen[key], "conflicting same-ID approval; STOP and reconcile")
            else:
                seen[key] = event
        check(seen == expected_events, "missing, conflicting or mismatched exact owner approval")
        governance = json.loads((root / "docs/governance/CURRENT_GOVERNANCE_ROUTER.json").read_text())
        check([x["document_id"] for x in packet["promoted_authority"]] == ["PLATFORM_PRODUCT_LAW", "PRODUCT_DECISIONS"], "both approved law successors required")
        current_authority = {
            "PLATFORM_PRODUCT_LAW": {
                "repository_path": "docs/governance/product/00_PLATFORM_v1.15.0.md",
                "sha256": "c7f5510817028d28edd4eb29e71b9150e13d0354cccf1af23666e067e0eed0b8",
                "semver": "1.15.0",
                "predecessor": "docs/governance/product/00_PLATFORM_v1.14.0.md",
                "predecessor_sha256": "bcec310103319441d12c6efae1c7c779a013a503b3831da630abb4a55187314b",
                "approved_amendment_path": "docs/governance/product/proposals/well-98/00_PLATFORM_v1.15.0_PROPOSED.md",
                "approved_amendment_sha256": "a9ae584bccc984faca20aeed2428edc00a05ad54aead237a57a6d90388eedebb",
            },
            "PRODUCT_DECISIONS": {
                "repository_path": "docs/governance/product/01_DECISIONS_v1.15.0.md",
                "sha256": "db57b0b73ed9faf8f3ade458c01d0d4798e4c2401172a35b9a1ad129ce8ae8d4",
                "semver": "1.15.0",
                "predecessor": "docs/governance/product/01_DECISIONS_v1.14.0.md",
                "predecessor_sha256": "d97cb742deefa744279b47686bf5148cceea4b95839fe5b32ad6bbe7d2b6b1fd",
                "approved_amendment_path": "docs/governance/product/proposals/well-98/01_DECISIONS_v1.15.0_PROPOSED.md",
                "approved_amendment_sha256": "b4374a82d605320fba01733176cc8a57346a97da1a0d03095d79b818926f2017",
            },
        }
        for document, approved in zip(packet["promoted_authority"], candidate["product_proposal"]["documents"]):
            load_artifact(document)
            check(document["predecessor"] == approved["predecessor"] and document["predecessor_sha256"] == approved["predecessor_sha256"], "law predecessor drift")
            check(document["approved_amendment_path"] == approved["path"] and document["approved_amendment_sha256"] == approved["sha256"], "law approval subject drift")
            matches = [x for x in governance["governing_documents"] if x["document_id"] == document["document_id"]]
            check(len(matches) == 1, "missing or duplicate current authority route")
            route = matches[0] if len(matches) == 1 else {}
            prior_authority = current_authority[document["document_id"]]
            load_artifact({"path": prior_authority["repository_path"], "sha256": prior_authority["sha256"]})
            load_artifact({"path": prior_authority["predecessor"], "sha256": prior_authority["predecessor_sha256"]})
            load_artifact({"path": prior_authority["approved_amendment_path"], "sha256": prior_authority["approved_amendment_sha256"]})
            current_sha = {
                "PLATFORM_PRODUCT_LAW": "ad38c25c49ba9d1de40e90d74b494705156605af724bc0e1d5a66d38b81cc39f",
                "PRODUCT_DECISIONS": "1d2c3cf6ec3ea4cd318ceccda8fa0a9b2c9797eec8f934a399e8d59f93090d8b",
            }
            expected_current = {
                "repository_path": prior_authority["repository_path"].replace("v1.15.0", "v1.17.0"),
                "sha256": current_sha[document["document_id"]], "semver": "1.17.0",
                "predecessor": prior_authority["repository_path"].replace("v1.15.0", "v1.16.0"),
                "predecessor_sha256": {"PLATFORM_PRODUCT_LAW": "bcc26cec59b8157a4d284d6bb533ec16bf41e85b88d7c5c14ff1ec1141019174", "PRODUCT_DECISIONS": "1a5d6d7c2bb0ca2a595dd28e2e371340298aa0b62ff613939c5de141831eb7f8"}[document["document_id"]],
                "approved_amendment_path": "docs/delivery/content-evidence/content_media/email_change_messages/PRODUCT_CLASSIFICATION_PROPOSAL_v1.md",
                "approved_amendment_sha256": "5859094922ada891cdca887cf140d457991fa0fe5fcc76ea34ff4dd32ad8a8b1",
            }
            check(
                route.get("repository_path") == expected_current["repository_path"]
                and route.get("canonical_filename") == Path(expected_current["repository_path"]).name
                and route.get("sha256") == expected_current["sha256"]
                and route.get("semver") == expected_current["semver"],
                "approved authority route mismatch",
            )
            successor_bytes = load_artifact(
                {
                    "path": expected_current["repository_path"],
                    "sha256": expected_current["sha256"],
                }
            )
            check(
                f"**Predecessor:** `{expected_current['predecessor']}`" in successor_bytes.decode("utf-8")
                and "**SemVer transition:** `v1.16.0 → v1.17.0`" in successor_bytes.decode("utf-8"),
                "current authority successor lineage mismatch",
            )
            load_artifact({"path": prior_authority["repository_path"].replace("v1.15.0", "v1.16.0"), "sha256": expected_current["predecessor_sha256"]})
            load_artifact({"path": "docs/delivery/content-evidence/content_media/recovery_messages/PRODUCT_CLASSIFICATION_PROPOSALS_v0.1.0.md", "sha256": "04f41fe344428a9c7cb30398c599c341d6a416af79c51d8446215ef9075e1b64"})
            load_artifact(
                {
                    "path": expected_current["predecessor"],
                    "sha256": expected_current["predecessor_sha256"],
                }
            )
            load_artifact(
                {
                    "path": expected_current["approved_amendment_path"],
                    "sha256": expected_current["approved_amendment_sha256"],
                }
            )
    except (KeyError, TypeError, ValueError, OSError, StopIteration, IndexError) as error:
        errors.append("malformed approval evidence: " + str(error))
    return errors


if __name__ == "__main__":
    try:
        findings = validate(ROOT, json.loads((ROOT / PACKET_PATH).read_text()))
        delivery = json.loads((ROOT / "docs/delivery/CURRENT_DELIVERY_ROUTER.json").read_text())
        routes = [x for x in delivery["delivery_contracts"] if x["document_id"] == "MAGIC_LOGIN_MESSAGE_DEVELOPMENT_EVIDENCE"]
        if len(routes) != 1:
            raise ValueError("missing or ambiguous current development evidence")
        development = ROOT / routes[0]["repository_path"]
        findings.extend(validate_development(ROOT, json.loads(development.read_text())))
    except (OSError, ValueError) as error:
        findings = [str(error)]
    print(json.dumps({"integrity": "FAIL" if findings else "PASS", "candidate_eligible": False, "development_eligible": not findings, "runtime_release_eligible": False, "findings": findings}, indent=2))
    raise SystemExit(bool(findings))
