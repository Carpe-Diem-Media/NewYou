import copy
import json
import shutil
import tempfile
import unittest
from pathlib import Path

from tools import check_well157_email_applicability as evidence


ROOT = Path(__file__).resolve().parents[1]


class Well157ApplicabilityTest(unittest.TestCase):
    def test_exact_approved_context_packet_is_eligible_for_named_development_context(self):
        packet = evidence.read_packet(ROOT)
        self.assertEqual([], evidence.validate_packet(ROOT, packet))
        self.assertTrue(evidence.eligible_for(ROOT, packet, "bounded non-production FP-001 Phase-9 WELL-156 verification"))

    def test_context_and_non_delivery_authority_fail_closed(self):
        packet = evidence.read_packet(ROOT)
        for context in ("production", "other Phase 9", "live delivery", "WELL-157"):
            with self.subTest(context=context):
                self.assertFalse(evidence.eligible_for(ROOT, packet, context))
        changed = copy.deepcopy(packet)
        changed["messages"][0]["state"] = "withdrawn"
        self.assertFalse(evidence.eligible_for(ROOT, changed, evidence.CONTEXT))
        changed = copy.deepcopy(packet)
        changed["status"] = "WITHDRAWN"
        self.assertFalse(evidence.eligible_for(ROOT, changed, evidence.CONTEXT))
        changed = copy.deepcopy(packet)
        changed["lifecycle"]["state"] = "withdrawn"
        self.assertFalse(evidence.eligible_for(ROOT, changed, evidence.CONTEXT))
        changed = copy.deepcopy(packet)
        changed["lifecycle"]["state"] = "superseded"
        self.assertFalse(evidence.eligible_for(ROOT, changed, evidence.CONTEXT))
        replay = copy.deepcopy(packet)
        replay["new_applicability_events"].append(copy.deepcopy(replay["new_applicability_events"][0]))
        self.assertTrue(evidence.eligible_for(ROOT, replay, evidence.CONTEXT))
        changed = copy.deepcopy(packet)
        changed["new_applicability_events"].append(copy.deepcopy(changed["new_applicability_events"][0]))
        changed["new_applicability_events"][-1]["decision"] = "REJECT_SCOPE_EXTENSION"
        self.assertFalse(evidence.eligible_for(ROOT, changed, evidence.CONTEXT))
        changed = copy.deepcopy(packet)
        changed["delivery_authorized"] = True
        self.assertIn("delivery must remain disabled", evidence.validate_packet(ROOT, changed))
        changed = copy.deepcopy(packet)
        changed["messages"][0]["sha256"] = "0" * 64
        self.assertTrue(evidence.validate_packet(ROOT, changed))

    def test_approval_events_bind_exact_sources_without_claiming_direct_plane_posts(self):
        packet = evidence.read_packet(ROOT)
        self.assertEqual(5, len(packet["new_applicability_events"]))
        for event in packet["new_applicability_events"]:
            self.assertEqual("agent_transcription_of_direct_user_decision", event["source_type"])
            self.assertFalse(event["direct_owner_plane_post"])
            self.assertFalse(event["independent_review"])
            self.assertEqual(evidence.PROPOSAL_SHA256, event["proposal_sha256"])
            self.assertEqual(evidence.BINDINGS_SHA256, event["bindings_sha256"])

    def test_historical_packet_and_owner_attribution_remain_byte_identical(self):
        packet = evidence.read_packet(ROOT)
        for item in (packet["historical_packet"], packet["historical_owner_attribution"]):
            path = ROOT / item["path"]
            self.assertEqual(item["sha256"], evidence.sha256(path.read_bytes()))

    def test_missing_or_rebound_decisions_and_locale_bindings_fail_closed(self):
        packet = evidence.read_packet(ROOT)
        missing = copy.deepcopy(packet)
        missing["new_applicability_events"].pop()
        self.assertFalse(evidence.eligible_for(ROOT, missing, evidence.CONTEXT))

        rebound_decision = copy.deepcopy(packet)
        rebound_decision["new_applicability_events"][1]["subjects"][0]["sha256"] = "0" * 64
        self.assertFalse(evidence.eligible_for(ROOT, rebound_decision, evidence.CONTEXT))

        rebound_locale = copy.deepcopy(packet)
        rebound_locale["messages"][0]["locale"] = "af"
        self.assertFalse(evidence.eligible_for(ROOT, rebound_locale, evidence.CONTEXT))

        rebound_token_contract = copy.deepcopy(packet)
        rebound_token_contract["new_applicability_events"][1]["subjects"][0]["token_contract_sha256"] = "0" * 64
        self.assertFalse(evidence.eligible_for(ROOT, rebound_token_contract, evidence.CONTEXT))

        superseded = copy.deepcopy(packet)
        superseded["messages"][0]["state"] = "superseded"
        self.assertFalse(evidence.eligible_for(ROOT, superseded, evidence.CONTEXT))

    def test_current_route_and_proposal_source_changes_fail_closed(self):
        packet = evidence.read_packet(ROOT)
        with tempfile.TemporaryDirectory() as temporary:
            temp_root = Path(temporary)
            shutil.copytree(ROOT / "docs", temp_root / "docs")

            router_path = temp_root / evidence.GOVERNANCE_ROUTER
            router = json.loads(router_path.read_text())
            platform = next(item for item in router["governing_documents"] if item["document_id"] == "PLATFORM_PRODUCT_LAW")
            platform["semver"] = "1.18.0"
            router_path.write_text(json.dumps(router))
            self.assertTrue(evidence.validate_packet(temp_root, packet))

            shutil.rmtree(temp_root / "docs")
            shutil.copytree(ROOT / "docs", temp_root / "docs")
            proposal_path = temp_root / evidence.PROPOSAL_PATH
            proposal_path.write_text(proposal_path.read_text() + " ")
            self.assertTrue(evidence.validate_packet(temp_root, packet))

            shutil.rmtree(temp_root / "docs")
            shutil.copytree(ROOT / "docs", temp_root / "docs")
            historical_path = temp_root / evidence.HISTORICAL_PACKET
            historical_path.write_bytes(historical_path.read_bytes() + b"\n")
            self.assertTrue(evidence.validate_packet(temp_root, packet))

    def test_email_change_legacy_evidence_check_accepts_current_v119_authority(self):
        from tools import check_email_change_message_evidence as legacy

        self.assertEqual([], legacy.validate(ROOT))


if __name__ == "__main__":
    unittest.main()
