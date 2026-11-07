"""WELL-97 candidate package must never imply approval or delivery eligibility."""

import copy
import hashlib
import json
import re
import unittest
from pathlib import Path

from tools.check_magic_login_evidence import validate


ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "docs/delivery/content-evidence/content_media/magic_login_messages"
PACKET = DIRECTORY / "MAGIC_LOGIN_MESSAGE_EVIDENCE_PACKET_v0.1.0.json"
EXPECTED = {
    "en": (278, "3527fcea7813b4348dd9c2ff06ed0c617c7a8eb6a356e16c4afa63c6b168707b", 273,
           "3e29c7fc2e55a215875b35ba92cb7b81186cf21d8a470d4c564a9e623708b015"),
    "af": (327, "05c09bd18c805572f7bbc75717f5f6a09d3b5eca44f6bb08959ae2bd4fdc3f89", 322,
           "e45d82eca89e990b1c1f99ad2995bef09a848eeaa9cfb20859bbac493c522205"),
}


class MagicLoginEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.packet = json.loads(PACKET.read_text())

    def test_exact_html_source_resolves_both_hashes_without_copy_edits(self):
        source = json.loads((DIRECTORY / "WELL-12-candidate-comment.json").read_text())
        blocks = re.findall(r"<pre>(.*?)</pre>", source["comment_html"], re.S)
        for locale, block, version in zip(("en", "af"), blocks, self.packet["locale_versions"]):
            count, digest, compact_count, compact_digest = EXPECTED[locale]
            raw = block.encode("utf-8")
            compact = raw.replace(b"\n\n", b"\n")
            self.assertEqual((count, digest), (len(raw), hashlib.sha256(raw).hexdigest()))
            self.assertEqual((compact_count, compact_digest),
                             (len(compact), hashlib.sha256(compact).hexdigest()))
            self.assertEqual(raw, (ROOT / version["artifact"]["path"]).read_bytes())
            self.assertEqual(5, len(raw) - len(compact))

    def test_candidate_packet_is_valid_and_ineligible(self):
        self.assertEqual([], validate(ROOT, self.packet))
        self.assertEqual("candidate", self.packet["lifecycle"]["state"])
        self.assertFalse(self.packet["eligibility"]["development"])
        self.assertFalse(self.packet["eligibility"]["runtime_release"])

    def test_missing_owner_evidence_cannot_be_promoted(self):
        for field in ("state",):
            changed = copy.deepcopy(self.packet)
            changed["lifecycle"][field] = "development_approved"
            self.assertTrue(validate(ROOT, changed))
        for field in ("development", "runtime_release"):
            changed = copy.deepcopy(self.packet)
            changed["eligibility"][field] = True
            self.assertTrue(validate(ROOT, changed))
        changed = copy.deepcopy(self.packet)
        changed["approval_events"] = [{"actor": "coding-agent", "decision": "approve"}]
        self.assertTrue(validate(ROOT, changed))

    def test_wrong_version_digest_locale_token_or_scope_fails_closed(self):
        mutations = [
            lambda p: p["locale_versions"][0]["artifact"].update(sha256="0" * 64),
            lambda p: p["locale_versions"][0].update(id="latest"),
            lambda p: p["locale_versions"][1].update(locale="en"),
            lambda p: p["token_allowlist"].append({"literal": "{{verification_link}}", "type": "url"}),
            lambda p: p["scope"]["allowed"].append("production"),
            lambda p: p["binding"].update(silent_locale_fallback=True),
            lambda p: p["owner_decisions"][0].update(status="approved"),
            lambda p: p["owner_decisions"][1].update(actor_identity="developer"),
            lambda p: p["owner_decisions"][1]["binding"].update(content_version_id="latest"),
            lambda p: p["owner_decisions"][1]["binding"].update(token_contract_sha256="0" * 64),
            lambda p: p["owner_decisions"][0]["binding"].update(identity_security_risk="LOW"),
            lambda p: p["lifecycle"].update(conflict="last_write_wins"),
            lambda p: p["lifecycle"].update(idempotency_key=["decision_id"]),
            lambda p: p["lifecycle"]["transition_guards"].update(candidate_to_development_approved=["developer approval"]),
            lambda p: p["approval_contract"].update(recording="OVERWRITE"),
            lambda p: p["approval_contract"].update(required_fields=["actor_identity"]),
            lambda p: p["lifecycle"].update(reconciliation="x"),
            lambda p: p["lifecycle"].update(history="x"),
            lambda p: p["lifecycle"].update(recovery="x"),
        ]
        for mutation in mutations:
            changed = copy.deepcopy(self.packet)
            mutation(changed)
            self.assertTrue(validate(ROOT, changed), mutation)

    def test_proposed_successors_preserve_current_law_and_unrelated_text(self):
        for proposal in self.packet["product_proposal"]["documents"]:
            old = (ROOT / proposal["predecessor"]).read_bytes()
            self.assertEqual(proposal["predecessor_sha256"], hashlib.sha256(old).hexdigest())
            candidate = (ROOT / proposal["path"]).read_text()
            # Amendment-form successors depend on the complete, unchanged predecessor.
            self.assertIn(proposal["predecessor"], candidate)
            self.assertIn(proposal["predecessor_sha256"], candidate)
            self.assertIn("PROPOSED / NON-AUTHORITATIVE", candidate)
        router = json.loads((ROOT / "docs/governance/CURRENT_GOVERNANCE_ROUTER.json").read_text())
        for route in router["governing_documents"]:
            self.assertNotIn("proposals/", route["repository_path"])

    def test_approval_subjects_bind_both_locales_and_proposed_law(self):
        for decision in self.packet["owner_decisions"]:
            self.assertEqual("pending", decision["status"])
            self.assertIsNone(decision["actor_identity"])
            self.assertIsNone(decision["accountable_owner_evidence"])
            self.assertIsNone(decision["decision_reference"])
            self.assertTrue(decision["subjects"])
        self.assertEqual(2, len(self.packet["owner_decisions"][1]["subjects"]))


if __name__ == "__main__":
    unittest.main()
