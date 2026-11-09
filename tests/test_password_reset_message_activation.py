"""WELL-98 approvals permit only exact bounded development use."""

import copy
import hashlib
import json
import shutil
import tempfile
from pathlib import Path
import unittest

from tools import check_password_reset_message_evidence as evidence


ROOT = Path(__file__).resolve().parents[1]


class PasswordResetMessageActivationTests(unittest.TestCase):
    def setUp(self):
        self.packet = json.loads((ROOT / evidence.APPROVED_PACKET_PATH).read_text())

    def copy_evidence(self):
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        paths = [
            Path("docs/governance"),
            Path("docs/delivery/CURRENT_DELIVERY_ROUTER.json"),
            evidence.APPROVED_PACKET_PATH.parent,
            Path("docs/delivery/content-evidence/copy/COPY_INVENTORY.md"),
            Path("docs/delivery/content-evidence/copy/COPY_REGISTRY.json"),
            Path("docs/delivery/content-evidence/copy/REVIEW_REPORT.md"),
            Path("docs/delivery/content-evidence/copy/WORKSPACE_CHECKSUMS.tsv"),
        ]
        for relative in paths:
            source = ROOT / relative
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            if source.is_dir():
                shutil.copytree(source, destination, dirs_exist_ok=True)
            else:
                shutil.copy2(source, destination)
        return temporary, root

    def write_packet(self, root, packet):
        path = root / evidence.APPROVED_PACKET_PATH
        path.write_text(json.dumps(packet, ensure_ascii=False, indent=2) + "\n")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        router_path = root / evidence.DELIVERY_ROUTER_PATH
        router = json.loads(router_path.read_text())
        route = next(
            item for item in router["delivery_contracts"]
            if item["document_id"] == "PASSWORD_RESET_MESSAGE_DEVELOPMENT_EVIDENCE"
        )
        route["sha256"] = digest
        router_path.write_text(json.dumps(router, ensure_ascii=False, indent=2) + "\n")

    def assert_rejected(self, root, expected_finding=None):
        result = evidence.validate_development(root)
        self.assertEqual("FAIL", result["integrity"], result["findings"])
        self.assertFalse(result["candidate_eligible"])
        self.assertFalse(result["development_eligible"])
        self.assertFalse(result["runtime_release_eligible"])
        if expected_finding:
            self.assertIn(expected_finding, " ".join(result["findings"]))

    def test_exact_approved_authority_and_five_decisions_enable_development_only(self):
        result = evidence.validate_development(ROOT)

        self.assertEqual("PASS", result["integrity"], result["findings"])
        self.assertFalse(result["candidate_eligible"])
        self.assertTrue(result["development_eligible"])
        self.assertFalse(result["runtime_release_eligible"])
        self.assertEqual(
            [item["decision_id"] for item in evidence.EXPECTED_APPROVALS],
            [item["decision_id"] for item in self.packet["approval_events"]],
        )
        self.assertEqual(
            ["en", "af"],
            [item["locale"] for item in self.packet["locale_versions"]],
        )

    def test_exact_replay_is_idempotent_and_conflicting_replay_fails(self):
        temporary, root = self.copy_evidence()
        with temporary:
            replay = copy.deepcopy(self.packet)
            replay["approval_events"].append(copy.deepcopy(replay["approval_events"][1]))
            self.write_packet(root, replay)
            self.assertEqual([], evidence.validate_development(root)["findings"])

            replay["approval_events"][-1]["binding"]["token_contract_sha256"] = "0" * 64
            self.write_packet(root, replay)
            self.assert_rejected(root, "conflicting decision replay")

    def test_missing_stale_or_conflicting_decision_evidence_fails_closed(self):
        for mutate, finding in (
            (lambda p: p["approval_events"].pop(), "missing, extra or mismatched exact approval event"),
            (lambda p: p["approval_events"][0].update(approved_head="0" * 40), "missing, extra or mismatched exact approval event"),
            (lambda p: p["approval_events"].append({**p["approval_events"][0], "decision_id": "WELL-98-CONFLICT"}), "missing, extra or mismatched exact approval event"),
            (lambda p: p["owner_decisions"][1]["subjects"][0]["artifact"].update(sha256="0" * 64), "owner decisions and locale reviews do not match"),
        ):
            temporary, root = self.copy_evidence()
            with temporary, self.subTest(finding=finding):
                packet = copy.deepcopy(self.packet)
                mutate(packet)
                self.write_packet(root, packet)
                self.assert_rejected(root, finding)

    def test_plane_approval_snapshot_cannot_be_truncated_or_rebound(self):
        temporary, root = self.copy_evidence()
        with temporary:
            source_path = root / evidence.OWNER_APPROVALS_PATH
            source = json.loads(source_path.read_text())
            source["decisions"].pop()
            source_path.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n")
            self.assert_rejected(root, "immutable Plane owner-approval snapshot changed")

    def test_withdrawn_or_superseded_state_and_route_are_terminal_for_new_use(self):
        for state in ("withdrawn", "superseded"):
            temporary, root = self.copy_evidence()
            with temporary, self.subTest(state=state):
                packet = copy.deepcopy(self.packet)
                packet["lifecycle"]["state"] = state
                self.write_packet(root, packet)
                self.assert_rejected(root, "approved lifecycle state or transition evidence mismatch")

        for status in ("WITHDRAWN", "SUPERSEDED"):
            temporary, root = self.copy_evidence()
            with temporary, self.subTest(status=status):
                router_path = root / evidence.DELIVERY_ROUTER_PATH
                router = json.loads(router_path.read_text())
                route = next(
                    item for item in router["delivery_contracts"]
                    if item["document_id"] == "PASSWORD_RESET_MESSAGE_DEVELOPMENT_EVIDENCE"
                )
                route["status"] = status
                router_path.write_text(json.dumps(router, ensure_ascii=False, indent=2) + "\n")
                self.assert_rejected(root, "approved development-router binding or digest mismatch")

    def test_production_alias_fallback_or_stale_product_authority_fails_closed(self):
        for mutate, finding in (
            (lambda p: p["eligibility"].update(production=True), "bounded development scope or eligibility flags mismatch"),
            (lambda p: p["binding"].update(latest_alias=True), "approved packet changed immutable candidate binding: binding"),
            (lambda p: p["binding"].update(silent_locale_fallback=True), "approved packet changed immutable candidate binding: binding"),
        ):
            temporary, root = self.copy_evidence()
            with temporary:
                packet = copy.deepcopy(self.packet)
                mutate(packet)
                self.write_packet(root, packet)
                self.assert_rejected(root, finding)

        temporary, root = self.copy_evidence()
        with temporary:
            router_path = root / evidence.GOVERNANCE_ROUTER_PATH
            router = json.loads(router_path.read_text())
            route = next(
                item for item in router["governing_documents"]
                if item["document_id"] == "PLATFORM_PRODUCT_LAW"
            )
            route.update(
                canonical_filename="00_PLATFORM_v1.14.0.md",
                repository_path="docs/governance/product/00_PLATFORM_v1.14.0.md",
                sha256="bcec310103319441d12c6efae1c7c779a013a503b3831da630abb4a55187314b",
                semver="1.14.0",
            )
            router_path.write_text(json.dumps(router, ensure_ascii=False, indent=2) + "\n")
            self.assert_rejected(root, "current Product authority route mismatch")

    def test_product_and_decision_successors_preserve_all_unrelated_prior_text(self):
        old_product = (ROOT / "docs/governance/product/00_PLATFORM_v1.14.0.md").read_text()
        new_product = (ROOT / "docs/governance/product/00_PLATFORM_v1.15.0.md").read_text()
        product_start = "## v1.14.0 amendment scope"
        old_product_body = old_product[old_product.index(product_start) :]
        new_product_body = new_product[new_product.index(product_start) :]
        new_start = new_product_body.index("## 21E.23 Password-reset message classification")
        new_end = new_product_body.index("# 21F.", new_start)
        new_product_body = new_product_body[:new_start] + new_product_body[new_end:]
        new_product_body = new_product_body.replace(
            "magic_login_message\npassword_reset_message\n",
            "magic_login_message\n",
            1,
        )
        new_product_body = new_product_body.replace(
            "The narrow `verification_message` meaning and its bounded proof applicability are defined in §§21E.19–21E.20. The narrow `password_reset_message` meaning and its bounded development applicability are defined in §§21E.23–21E.24.",
            "The narrow `verification_message` meaning and its bounded proof applicability are defined in §§21E.19–21E.20.",
            1,
        )
        self.assertEqual(old_product_body.rstrip(), new_product_body.rstrip())

        old_decisions = (ROOT / "docs/governance/product/01_DECISIONS_v1.14.0.md").read_text()
        new_decisions = (ROOT / "docs/governance/product/01_DECISIONS_v1.15.0.md").read_text()
        decisions_start = "## v1.14.0 amendment scope"
        old_decisions_body = old_decisions[old_decisions.index(decisions_start) :]
        new_decisions_body = new_decisions[new_decisions.index(decisions_start) :]
        dec322_start = new_decisions_body.index(
            "## DEC-322 Password-reset message classification and bounded development eligibility"
        )
        new_decisions_body = new_decisions_body[:dec322_start].rstrip() + "\n"
        self.assertEqual(old_decisions_body.rstrip(), new_decisions_body.rstrip())


if __name__ == "__main__":
    unittest.main()
