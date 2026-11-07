"""Owner-approved development evidence must bind the immutable candidate exactly."""

import copy
import json
import unittest
from pathlib import Path

from tools.check_magic_login_evidence import validate_development


ROOT = Path(__file__).resolve().parents[1]
PACKET = ROOT / "docs/delivery/content-evidence/content_media/magic_login_messages/MAGIC_LOGIN_MESSAGE_EVIDENCE_PACKET_v0.2.0.json"


class MagicLoginDevelopmentApprovalTests(unittest.TestCase):
    def setUp(self):
        self.packet = json.loads(PACKET.read_text())

    def test_exact_owner_approval_permits_only_bounded_development(self):
        self.assertEqual([], validate_development(ROOT, self.packet))
        self.assertEqual("development_approved", self.packet["lifecycle"]["state"])
        self.assertTrue(self.packet["eligibility"]["development"])
        self.assertFalse(self.packet["eligibility"]["runtime_release"])

    def test_incomplete_or_changed_owner_binding_fails_closed(self):
        mutations = [
            lambda p: p["approval_events"].pop(),
            lambda p: p["approval_events"][0].update(actor_identity=None),
            lambda p: p["approval_events"][0].update(decision_reference="unverifiable"),
            lambda p: p["approval_events"][1]["subjects"][0]["artifact"].update(sha256="0" * 64),
            lambda p: p["approval_events"][1]["binding"].update(format_id="other"),
            lambda p: p["approval_events"][1]["binding"].update(token_contract_sha256="0" * 64),
            lambda p: p["scope"]["allowed"].append("production"),
            lambda p: p["eligibility"].update(runtime_release=True),
            lambda p: p["lifecycle"].update(state="withdrawn"),
            lambda p: p["promoted_authority"][0].update(sha256="0" * 64),
        ]
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                packet = copy.deepcopy(self.packet)
                mutate(packet)
                self.assertTrue(validate_development(ROOT, packet))

    def test_identical_approval_replay_is_idempotent_and_conflict_stops(self):
        repeated = copy.deepcopy(self.packet)
        repeated["approval_events"].append(copy.deepcopy(repeated["approval_events"][1]))
        self.assertEqual([], validate_development(ROOT, repeated))
        repeated["approval_events"][-1]["binding"]["format_id"] = "changed"
        self.assertTrue(validate_development(ROOT, repeated))

    def test_successor_changes_only_approved_semantics(self):
        for document in self.packet["promoted_authority"]:
            before = (ROOT / document["predecessor"]).read_text()
            after = (ROOT / document["path"]).read_text()
            before_body = before[before.index("## v1.13.0 Amendment Scope"):]
            after_body = after[after.index("## v1.13.0 Amendment Scope"):]
            amendment = (ROOT / document["approved_amendment_path"]).read_text()
            if document["document_id"] == "PLATFORM_PRODUCT_LAW":
                start = after_body.index("## 21E.21 Magic-login message classification")
                end = after_body.index("# 21F.", start)
                expected = amendment[amendment.index("## Proposed §21E.21"):].replace("## Proposed §21E.", "## 21E.")
                expected = expected.replace("The proposed wording risk is `editorial_low_risk` under §21E.4, subject to an explicit Product-owner decision.", "The approved wording risk is `editorial_low_risk` under §21E.4.")
                self.assertEqual(expected.strip(), after_body[start:end].strip())
                after_body = after_body[:start] + after_body[end:]
                after_body = after_body.replace("verification_message\nmagic_login_message\n", "verification_message\n", 1)
            else:
                expected = amendment[amendment.index("## Proposed DEC-321"):].replace("## Proposed DEC-321", "## DEC-321").replace("**Status:** PROPOSED / OWNER DECISION PENDING", "**Status:** LOCKED")
                expected = expected.replace("Subject to explicit Product-owner acceptance of proposed Product §§21E.21–21E.22, add", "Under approved Product §§21E.21–21E.22, add").replace("Recommend `editorial_low_risk` for wording only", "Approve `editorial_low_risk` for wording only").replace("are proposed Product §21E.22", "are Product §21E.22")
                self.assertEqual(expected.strip(), after_body[after_body.index("\n## DEC-321"):].strip())
                after_body = after_body[:after_body.index("\n## DEC-321")]
            self.assertEqual(before_body.rstrip(), after_body.rstrip())


if __name__ == "__main__":
    unittest.main()
