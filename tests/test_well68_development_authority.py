from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
ROUTER_PATH = DOCS / "governance/CURRENT_GOVERNANCE_ROUTER.json"
FROZEN_ROUTER_PATH = DOCS / "history/platform/CURRENT_AUTHORITY_ROUTER_v1.0.0.json"
PACKET_PATH = DOCS / "delivery/content-evidence/content_media/verification_messages/VERIFICATION_MESSAGE_EVIDENCE_PACKET_v0.2.0.json"
SOURCE_DIR = DOCS / "delivery/content-evidence/content_media/verification_messages"

EXPECTED_VERSIONS = {
    "en": (
        "NEWYOU-CONTENTTRANSLATIONVERSION-VERIFICATION-MESSAGE-EMAIL-ADDRESS-EN-V1",
        "NEWYOU-VERIFICATION-MESSAGE-EMAIL-ADDRESS-EN-V1.txt",
        221,
        "a8ceecc466497bd3d79ae9255a7f004b18461a2d6a1791028a68bcb1efd2a072",
    ),
    "af": (
        "NEWYOU-CONTENTTRANSLATIONVERSION-VERIFICATION-MESSAGE-EMAIL-ADDRESS-AF-V1",
        "NEWYOU-VERIFICATION-MESSAGE-EMAIL-ADDRESS-AF-V1.txt",
        247,
        "c3212222fdcd878af6bdc2b17895d4d6cab44e162814e2a8deee10b7fd916494",
    ),
}


def routed_document(router: dict, document_id: str) -> str:
    aliases = {
        "PLATFORM_BASELINE": "PLATFORM_PRODUCT_LAW",
        "DECISION_REGISTER": "PRODUCT_DECISIONS",
    }
    target_id = aliases.get(document_id, document_id)
    entries = [
        item
        for collection in ("governing_documents", "architecture_references", "supporting_documents")
        for item in router[collection]
    ]
    entry = next(item for item in entries if item["document_id"] == target_id)
    return (ROOT / entry["repository_path"]).read_text(encoding="utf-8")


class WELL68DevelopmentAuthorityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.router = json.loads(ROUTER_PATH.read_text(encoding="utf-8"))
        cls.frozen_router = json.loads(FROZEN_ROUTER_PATH.read_text(encoding="utf-8"))
        cls.product = routed_document(cls.router, "PLATFORM_BASELINE")
        cls.decisions = routed_document(cls.router, "DECISION_REGISTER")
        cls.operating_model = routed_document(cls.router, "PLATFORM_OPERATING_MODEL")
        cls.delivery = routed_document(cls.router, "DELIVERY_GOVERNANCE_STANDARD")
        cls.p8 = (ROOT / "docs/delivery/execution/p8-05-registration-jit-spec.md").read_text(encoding="utf-8")
        packet_path = PACKET_PATH if PACKET_PATH.is_file() else SOURCE_DIR / "VERIFICATION_MESSAGE_EVIDENCE_PACKET_v0.1.0.json"
        cls.packet = json.loads(packet_path.read_text(encoding="utf-8"))

    def test_current_route_is_authoritative_and_frozen_status_sources_stay_historical(self) -> None:
        self.assertEqual("CURRENT", self.router["status"])
        product_route = next(row for row in self.router["governing_documents"] if row["document_id"] == "PLATFORM_PRODUCT_LAW")
        decisions_route = next(row for row in self.router["governing_documents"] if row["document_id"] == "PRODUCT_DECISIONS")
        for route, stem in ((product_route, "00_PLATFORM"), (decisions_route, "01_DECISIONS")):
            self.assertGreaterEqual(tuple(map(int, route["semver"].split("."))), (1, 13, 0))
            self.assertEqual(f"{stem}_v{route['semver']}.md", route["canonical_filename"])
        self.assertEqual("PLATFORM_OPERATING_MODEL_v1.3.0.md", next(row for row in self.router["supporting_documents"] if row["document_id"] == "PLATFORM_OPERATING_MODEL")["canonical_filename"])
        self.assertNotIn("OPEN_WORK", {row["document_id"] for row in self.router["governing_documents"]})
        legacy = next(row for row in self.frozen_router["legacy_snapshots"] if row["document_id"] == "OPEN_WORK_FINAL_LEGACY_SNAPSHOT")
        self.assertFalse(legacy["live_execution_authority"])
        self.assertEqual("7ae61b682322628826d05e130546a644cb127baaf6f5fa737aa773aa19936ea5", legacy["sha256"])
        historical = json.loads((DOCS / "history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json").read_text(encoding="utf-8"))
        self.assertEqual("OPEN_WORK", next(row for row in historical["governing_documents"] if row["document_id"] == "OPEN_WORK")["document_id"])

    def test_ready_and_durable_authority_are_sufficient_for_implementation(self) -> None:
        rule = self.product.split("## 15.1B", 1)[0]
        self.assertIn("durable authority plus a dependency-cleared plane `ready` ticket is sufficient permission to implement", rule.casefold())
        self.assertIn("A runtime authorization mechanism, real operator identity, runtime role grant or production capability assignment must not be required to exist before development of that authorization mechanism or its dependent feature may proceed", rule)
        self.assertIn("implementation permission", self.delivery.casefold())
        self.assertIn("runtime grants do not separately block ordinary implementation", self.delivery.casefold())
        self.assertIn("implementing or proving the real authorization/provisioning mechanism may include creating or validating real grants as the ticket's deliverable", self.delivery.casefold())
        self.assertIn("those grants must not be treated as pre-existing entry prerequisites", self.delivery.casefold())
        self.assertIn("intrinsically necessary even for the bounded development action", self.delivery)
        self.assertNotIn("runtime grants may block implementation only when the ticket", self.delivery.casefold())
        self.assertIn("a future production role or grant requirement alone is not an implementation prerequisite", self.delivery.casefold())

    def test_synthetic_authorization_proof_is_allowed_and_keeps_runtime_design_intact(self) -> None:
        for text in (self.product, self.operating_model):
            normalized = text.casefold()
            for phrase in (
                "deterministic synthetic accounts",
                "synthetic roles and grants",
                "authorised actions",
                "denied actions",
                "missing grants",
                "wrong scopes",
                "expired and revoked grants",
                "sensitive-role boundaries",
                "relevant audit behaviour",
            ):
                self.assertIn(phrase, normalized)
        self.assertIn("no production authority", self.product.casefold())
        self.assertIn("NewYou.Identity.Account", self.product)
        self.assertIn("creates no cross-environment governance identity", self.product.casefold())
        self.assertNotIn("cross-environment identity", self.operating_model.casefold())

    def test_jc_has_nonproduction_engineering_freedom_without_universal_business_authority(self) -> None:
        for phrase in (
            "JC is currently the sole developer/operator",
            "migrations and seeds",
            "database reset/rebuild",
            "test-data creation and deletion",
            "synthetic user/account creation",
            "synthetic role/grant creation",
            "invoking private development/test interfaces",
            "inspecting internal state",
            "simulating different staff/business roles",
            "testing failure, recovery and revocation paths",
        ):
            self.assertIn(phrase, self.operating_model)
        for phrase in (
            "production role", "public-release authority", "paid-pilot authority", "real-participant authority",
            "Content publication authority", "clinical authority", "safety authority", "legal/privacy approval authority",
            "financial approval authority", "Domain-business authority", "Super Admin production bypass",
        ):
            self.assertIn(phrase.casefold(), self.operating_model.casefold())

    def test_production_and_release_authorization_still_fails_closed(self) -> None:
        for text in (self.product, self.p8):
            self.assertIn("development-only shortcuts", text.casefold())
            self.assertIn("production", text.casefold())
            self.assertIn("fail closed", text.casefold())
            normalized = text.replace("`", "")
            self.assertIn("current Identity & Access grant for Content + verification_message_lifecycle", normalized)
        for requirement in (
            "Each EN locale version requires two approvals: Content Approver + English Language Reviewer",
            "Each AF locale version requires two approvals: Content Approver + Afrikaans Language Reviewer",
            "The paired EN/AF verification content therefore requires four separate approval events in total",
            "explicit Content & Media release/eligibility decision",
        ):
            self.assertIn(requirement, self.product.replace("`", ""))
        for requirement in (
            "each EN locale version requires two exact-byte approvals: Content Approver + English Language Reviewer",
            "each AF locale version requires two exact-byte approvals: Content Approver + Afrikaans Language Reviewer",
            "paired EN/AF verification versions therefore require four separate approval events in total",
            "explicit Content & Media release/eligibility decision",
        ):
            self.assertIn(requirement, self.p8.replace("`", ""))
        self.assertIn("Before production, public release, paid-pilot or real-participant use", self.p8)

    def test_verification_message_development_baseline_needs_no_runtime_content_grant(self) -> None:
        proof = self.product.split("## 21E.20", 1)[1].split("# 21F.", 1)[0]
        self.assertRegex(proof, r"does not require a materialised (?:runtime )?Account, IdentityGrant, Content role grant,? or lifecycle actor")
        for applicability in ("local development", "automated tests", "development environments", "bounded P8-05 Phase-8 architectural proof"):
            self.assertIn(applicability, proof)
        self.assertIn("development_approved != runtime_approved != published != latest != production_eligible", proof)
        self.assertIn("JC's exact-wording owner approval remains valid provenance for development", proof)
        self.assertIn("Before production, public release, paid-pilot or real-participant use", proof)

    def test_evidence_packet_separates_development_lifecycle_from_runtime_release_evidence(self) -> None:
        self.assertEqual("verification-message-email-address-candidate-evidence-v0.2.0", self.packet["packet_id"])
        lifecycle = self.packet["development_fixture_lifecycle"]
        self.assertEqual(["candidate", "development_approved", "superseded", "withdrawn"], lifecycle["states"])
        self.assertEqual("development_approved", lifecycle["status"])
        self.assertEqual("APPEND_ONLY", lifecycle["recording"])
        guards = lifecycle["transition_guards"]
        effects = lifecycle["side_effects"]
        supersede = "development_approved → superseded"
        withdraw = "development_approved → withdrawn"
        self.assertIn("current state is development_approved", guards[supersede])
        self.assertIn("authorised owner/governance decision exists", guards[supersede])
        self.assertIn("successor immutable version identity and exact digest are pinned", guards[supersede])
        self.assertTrue(any("successor has a fresh development_approved decision" in item for item in guards[supersede]))
        self.assertIn("old version is unavailable for new development consumption", effects[supersede])
        self.assertIn("append-only event records superseded_by and decision provenance", effects[supersede])
        self.assertIn("old immutable bytes and history remain", effects[supersede])
        self.assertIn("current state is development_approved", guards[withdraw])
        self.assertIn("authorised owner/governance withdrawal decision and reason exist", guards[withdraw])
        self.assertIn("new development consumption stops immediately", effects[withdraw])
        self.assertIn("append-only withdrawal evidence records reason and decision provenance", effects[withdraw])
        self.assertIn("old immutable bytes and history remain", effects[withdraw])
        self.assertIn("conflicting decisions for the same immutable version STOP and reconcile", lifecycle["conflict_policy"])
        self.assertEqual(["superseded", "withdrawn"], lifecycle["terminal_for_new_consumption"])
        self.assertEqual(["superseded", "withdrawn"], lifecycle["no_outgoing_transitions"])
        self.assertIn("same exact transition/decision/version/digest is idempotent", lifecycle["idempotency"])
        self.assertEqual(
            ["transition", "decision", "content_translation_version_id", "exact_source_sha256"],
            lifecycle["decision_key"],
        )
        self.assertTrue(
            all(event["transition"] == "candidate → development_approved" for event in lifecycle["development_decision_events"])
        )
        self.assertIn("competing supersede/withdraw decisions fail closed and STOP for reconciliation", lifecycle["concurrency_and_retry"]["competing_terminal_decisions"])
        self.assertIn("same exact transition/decision/version/digest is idempotent", lifecycle["concurrency_and_retry"]["identical_transition_retry"])
        self.assertFalse(lifecycle["runtime_identity_or_grant_required"])
        self.assertFalse(lifecycle["creates_runtime_or_production_authority"])
        self.assertEqual("PENDING_REQUIRED_EVIDENCE", self.packet["runtime_release_eligibility"]["status"])
        self.assertFalse(self.packet["runtime_release_eligibility"]["eligible"])
        slots = self.packet["runtime_release_eligibility"]["approval_slots"]
        by_locale = {
            locale: {slot["required_approver_role"] for slot in slots if slot["locale"] == locale}
            for locale in ("en", "af")
        }
        self.assertEqual({"Content Approver", "English Language Reviewer"}, by_locale["en"])
        self.assertEqual({"Content Approver", "Afrikaans Language Reviewer"}, by_locale["af"])
        self.assertEqual([], self.packet["runtime_release_eligibility"]["lifecycle_grant_evidence"])
        self.assertEqual([], self.packet["runtime_release_eligibility"]["content_release_decisions"])
        self.assertNotIn("governance_identity", json.dumps(self.packet).casefold())

    def test_en_af_version_bytes_and_digests_are_unchanged(self) -> None:
        by_locale = {row["locale"]: row for row in self.packet["locale_versions"]}
        for locale, (version_id, filename, byte_count, digest) in EXPECTED_VERSIONS.items():
            with self.subTest(locale=locale):
                artifact = (SOURCE_DIR / filename).read_bytes()
                version = by_locale[locale]
                self.assertEqual(version_id, version["id"])
                self.assertEqual(byte_count, len(artifact))
                self.assertEqual(digest, hashlib.sha256(artifact).hexdigest())
                self.assertEqual(byte_count, version["byte_count"])
                self.assertEqual(digest, version["sha256"])


if __name__ == "__main__":
    unittest.main()
