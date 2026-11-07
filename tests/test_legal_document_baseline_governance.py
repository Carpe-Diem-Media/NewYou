from __future__ import annotations

from foundation_test_support import current_governance_router_data, historical_platform_readme_text, historical_platform_readme_path, live_platform_readme_text
import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs" / "00_platform"
MANIFEST = json.loads((DOCS / "CURRENT_AUTHORITY_MANIFEST_v1.0.0.json").read_text(encoding="utf-8"))
ROUTER = json.loads((DOCS / "CURRENT_AUTHORITY_ROUTER_v1.0.0.json").read_text(encoding="utf-8"))
CONTENT_MANIFEST_PATH = DOCS / "working/content_media/LEGAL_BASELINE_CONTENT_MANIFEST_v0.1.0.json"
CONTENT_MANIFEST = json.loads(CONTENT_MANIFEST_PATH.read_text(encoding="utf-8"))


def current_document(document_id: str) -> Path:
    record = next(item for item in ROUTER["governing_documents"] if item["document_id"] == document_id)
    return ROOT / record["repository_path"]


class LegalDocumentBaselineGovernanceTests(unittest.TestCase):
    def test_dec316_is_a_narrow_successor_to_dec124(self) -> None:
        product = current_document("PLATFORM_BASELINE").read_text(encoding="utf-8")
        decisions = current_document("DECISION_REGISTER").read_text(encoding="utf-8")
        dec124 = decisions.split("## DEC-124 — Risk-based bilingual publication", 1)[1].split("## DEC-125", 1)[0]
        dec027 = decisions.split("## DEC-027 — Registration fields", 1)[1].split("## DEC-028", 1)[0]
        dec028 = decisions.split("## DEC-028 — Multilingual launch", 1)[1].split("## DEC-029", 1)[0]
        dec316 = decisions.split("## DEC-316 — English-only governing legal documents and development baseline gate", 1)[1].split("# Open Gates", 1)[0]

        self.assertIn("SUPERSEDED IN PART BY DEC-316 FOR GOVERNING TERMS AND PRIVACY DOCUMENT BODIES ONLY", dec124)
        self.assertIn("All other DEC-124 bilingual publication requirements remain unchanged", dec124)
        self.assertIn("Require both languages for paid, contractual, assessment, plan, clinical, safety and core-onboarding content", dec124)
        self.assertIn("DEC-124 is superseded in part only for the governing Terms and Privacy document bodies", dec316)
        self.assertIn("DEC-028's bilingual platform requirement", dec316)
        self.assertIn("DEC-027's required Terms/Privacy acceptance", dec316)
        self.assertIn("English only as the single authoritative legal documents", dec316)
        self.assertIn("consent notices, assessments, plans, clinical and safety content, core onboarding, verification UI and general paid content", dec316)
        self.assertIn("participant-facing consent and privacy notices, except for the governing Terms and Privacy document bodies", product)
        self.assertIn("The NewYou platform remains bilingual in Afrikaans and English", product)
        self.assertIn("No official Afrikaans legal translation is required or maintained", product)
        self.assertIn("DEC-027 acceptance requirement remain unchanged", product)
        self.assertIn("Require first name, surname, email, authentication credential, preferred language, 18+ confirmation and terms/privacy acceptance", dec027)
        self.assertIn("Support Afrikaans and English from launch", dec028)

    def test_baseline_records_pin_nonapproved_english_only_versions(self) -> None:
        self.assertEqual("NON-AUTHORITATIVE CONTENT VERSION RECORD", CONTENT_MANIFEST["status"])
        self.assertEqual(2, len(CONTENT_MANIFEST["versions"]))
        self.assertEqual(
            {"terms", "privacy"},
            {version["document_type"] for version in CONTENT_MANIFEST["versions"]},
        )
        self.assertIn("NOT LEGALLY APPROVED FOR PRODUCTION OR REAL-PARTICIPANT RELEASE", CONTENT_MANIFEST["warning"])

        expected_ids = {
            "terms": "NEWYOU-TERMS-EN-DEV-2026-10-27-001",
            "privacy": "NEWYOU-PRIVACY-EN-DEV-2026-10-27-001",
        }
        for version in CONTENT_MANIFEST["versions"]:
            with self.subTest(document_type=version["document_type"]):
                path = ROOT / version["artifact_path"]
                html = path.read_text(encoding="utf-8")
                version_id = expected_ids[version["document_type"]]
                artifact_hash = hashlib.sha256(path.read_bytes()).hexdigest()
                self.assertEqual(version_id, version["content_version_id"])
                self.assertEqual("en", version["document_locale"])
                self.assertEqual("DEVELOPMENT_ONLY_CURRENT", version["applicability_status"])
                self.assertFalse(version["effective_for_participants"])
                self.assertEqual("NOT_LEGALLY_APPROVED", version["approval_state"])
                self.assertIsNone(version["approval_reference"])
                self.assertIsNone(version["approval_date"])
                self.assertEqual({"supersedes": None, "superseded_by": None}, version["supersession"])
                self.assertEqual("NOT_WITHDRAWN", version["withdrawal"]["status"])
                self.assertTrue(version["source"]["source_page_is_mutable"])
                self.assertIn("bounded_phase_8_architectural_proof", version["allowed_contexts"])
                self.assertTrue({"production", "public_release", "paid_pilot", "real_participant_use"}.issubset(version["prohibited_contexts"]))
                self.assertIn('lang="en"', html)
                self.assertIn(f'content="{version_id}"', html)
                self.assertIn("NOT LEGALLY APPROVED FOR PRODUCTION OR REAL-PARTICIPANT RELEASE", html)
                self.assertIn("NOT_LEGALLY_APPROVED", html)
                self.assertIn(version["exact_content_sha256"], html)
                self.assertEqual(
                    artifact_hash,
                    MANIFEST["integrity_rules"]["legal_development_baselines"]["artifact_sha256"][version["artifact_path"]],
                )

    def test_locale_separation_and_fail_closed_release_contract(self) -> None:
        product = current_document("PLATFORM_BASELINE").read_text(encoding="utf-8")
        decisions = current_document("DECISION_REGISTER").read_text(encoding="utf-8")
        spec = (ROOT / "docs/delivery/execution/p8-05-registration-jit-spec.md").read_text(encoding="utf-8")
        legal_contract = product.split("## 21E.18 Governing Terms and Privacy documents", 1)[1].split("# 21F", 1)[0]

        self.assertIn("participant interaction/preferred locale", legal_contract)
        self.assertIn("each legal document's locale", legal_contract)
        self.assertIn("acceptance timestamp", legal_contract)
        self.assertIn("exact Terms version", legal_contract)
        self.assertIn("exact Privacy version", legal_contract)
        self.assertIn("A separately approved legal version receives a new immutable version ID", legal_contract)
        self.assertIn("There is no environment fallback", legal_contract)
        self.assertIn("`latest` lookup", legal_contract)
        self.assertIn("default unapproved version", legal_contract)
        self.assertIn("runtime translation", legal_contract)
        self.assertIn("fail closed", legal_contract)

        self.assertIn("interaction/preferred locale (af or en)", spec)
        self.assertIn("legal document locale is en for both documents", spec)
        self.assertIn("There is no environment fallback to a baseline legal version", spec)
        self.assertIn("latest lookup", spec)
        self.assertIn("default unapproved version", spec)
        self.assertIn("fails closed otherwise", spec)
        self.assertIn(
            "P8-05 / WELL-6 IMPLEMENTATION: AUTHORISED — BOUNDED PHASE 8 ARCHITECTURAL PROOF ONLY",
            spec,
        )
        self.assertIn("legal document locale is en for both documents", spec)
        self.assertIn("not legally approved", spec.casefold())
        self.assertIn("fail closed", spec.casefold())
        self.assertIn("WELL-45 is a release/legal-readiness gate, not a blanket development blocker", spec)
        for line in spec.splitlines():
            if line.startswith(("| WELL-48 |", "| WELL-49 |", "| WELL-50 |", "| WELL-51 |", "| WELL-52 |", "| WELL-53 |")):
                dependencies = line.split("|")[3]
                self.assertNotIn("WELL-45", dependencies)

        self.assertIn("DEC-124 is superseded in part only", decisions)

    def test_current_routes_separate_development_readiness_from_release_readiness(self) -> None:
        open_work_record = next(item for item in MANIFEST["governing_documents"] if item["document_id"] == "OPEN_WORK")
        open_work = (ROOT / open_work_record["repository_path"]).read_text(encoding="utf-8")
        readme = live_platform_readme_text(ROOT)
        product = current_document("PLATFORM_BASELINE").read_text(encoding="utf-8")
        spec = (ROOT / "docs/delivery/execution/p8-05-registration-jit-spec.md").read_text(encoding="utf-8")
        self.assertIn("WELL-45: LEGAL/PRIVACY RELEASE GATE OPEN — DEVELOPMENT BASELINE PERMITTED; NOT LEGALLY APPROVED", open_work)
        self.assertIn("Current Product Law v1.12.0 continues to permit the immutable English development baselines under DEC-316", open_work)
        self.assertIn("both immutable EN development baselines", open_work)
        self.assertIn("explicit P8-05 implementation authorization", open_work)
        self.assertIn("WELL-45 is now a release/legal-readiness gate", open_work)
        self.assertIn("It is not legally approved", open_work)
        self.assertIn("Production, public release, paid pilot and applicable real-participant flows remain fail-closed", open_work)
        routed_governance = {
            entry["canonical_filename"]
            for collection in ("governing_documents", "architecture_references", "supporting_documents")
            for entry in current_governance_router_data(ROOT).get(collection, [])
        }
        for stem in ("00_PLATFORM", "01_DECISIONS"):
            successors = [name for name in routed_governance if name.startswith(stem + "_v")]
            self.assertEqual(1, len(successors))
            version = successors[0].removeprefix(stem + "_v").removesuffix(".md")
            self.assertGreaterEqual(tuple(map(int, version.split("."))), (1, 13, 0))
        self.assertIn("Plane project `WELL` remains the live execution authority", readme)
        self.assertIn("runtime authorization", product.casefold())
        self.assertIn(
            "WELL-45 is a release/legal-readiness gate, not a blanket development blocker",
            spec,
        )


if __name__ == "__main__":
    unittest.main()
