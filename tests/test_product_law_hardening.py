from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

from tools import foundation_integrity_audit
from foundation_test_support import current_document_path, current_governance_router_data, current_working_path, frozen_manifest_document_path, historical_platform_readme_path, historical_platform_readme_text, live_platform_readme_text


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs" / "00_platform"
MANIFEST = DOCS / "CURRENT_AUTHORITY_MANIFEST_v1.0.0.json"
ROUTER = DOCS / "CURRENT_AUTHORITY_ROUTER_v1.0.0.json"

# The Atlas header routes live authority. Its source table retains these citations.
ATLAS_PRODUCT_SOURCES = (
    "docs/governance/product/00_PLATFORM_v1.15.0.md",
    "docs/governance/product/01_DECISIONS_v1.15.0.md",
)


def frozen_manifest_document(document_id: str) -> str:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entry = next(item for item in manifest["governing_documents"] if item["document_id"] == document_id)
    return frozen_manifest_document_path(ROOT, entry).read_text(encoding="utf-8")


def matrix_rows(text: str, name: str) -> list[dict[str, str]]:
    start = f"<!-- NEWYOU:PRODUCT-MATRIX:{name}:START -->"
    end = f"<!-- NEWYOU:PRODUCT-MATRIX:{name}:END -->"
    if text.count(start) != 1 or text.count(end) != 1:
        raise AssertionError(f"expected one marked {name} matrix")
    section = text.split(start, 1)[1].split(end, 1)[0]
    table = [line for line in section.splitlines() if line.strip().startswith("|")]
    if len(table) < 3:
        raise AssertionError(f"{name} matrix has no data rows")

    def cells(line: str) -> list[str]:
        return [cell.strip().strip("`") for cell in line.strip().strip("|").split("|")]

    headers = cells(table[0])
    rows: list[dict[str, str]] = []
    for line in table[2:]:
        values = cells(line)
        if len(values) != len(headers):
            raise AssertionError(f"malformed row in {name} matrix: {line}")
        rows.append(dict(zip(headers, values)))
    return rows


def document_section(document: str, heading: str) -> str:
    match = re.search(rf"^{re.escape(heading)}\s*$", document, re.MULTILINE)
    if match is None:
        raise AssertionError(f"missing current-authority heading: {heading}")
    content_start = match.end()
    next_section = re.search(r"^#{1,2}\s", document[content_start:], re.MULTILINE)
    content_end = content_start + next_section.start() if next_section else len(document)
    return document[content_start:content_end]


class ProductLawHardeningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.product = frozen_manifest_document("PLATFORM_BASELINE")
        cls.decisions = frozen_manifest_document("DECISION_REGISTER")
        cls.open_work = frozen_manifest_document("OPEN_WORK")
        cls.roadmap = frozen_manifest_document("ROADMAP")
        cls.readme = historical_platform_readme_text(ROOT)
        cls.architecture = (DOCS / "03_ARCHITECTURE_v1.1.1.md").read_text(encoding="utf-8")
        cls.domain_map = frozen_manifest_document("DOMAIN_MAP")
        cls.operating_model = frozen_manifest_document("PLATFORM_OPERATING_MODEL")
        cls.fes = (DOCS / "FRONTEND_EXPERIENCE_SYSTEM_v1.0.1.md").read_text(encoding="utf-8")
        cls.atlas = current_working_path(ROOT, "DELIVERY_ATLAS_WORKING_").read_text(encoding="utf-8")
        cls.harden02 = current_working_path(ROOT, "HARDEN-02_CONTRACT_WORKING_").read_text(encoding="utf-8")
        cls.fp001 = current_working_path(ROOT, "FP-001_FEATURE_PACK_SKELETON_WORKING_").read_text(
            encoding="utf-8"
        )
        cls.integrity_rules = json.loads(MANIFEST.read_text(encoding="utf-8"))["integrity_rules"]

    def test_dec315_statutory_membership_cancellation_semantics_are_locked(self):
        product = document_section(self.product, "## 21A.6 Billing and cancellation")
        decision = document_section(
            self.decisions, "## DEC-315 — Statutory consumer cancellation and refund rights"
        )
        policy = f"{product}\n{decision}"

        self.assertIn(
            "ordinary commercial cancellation, renewal and refund rules apply except to the extent that a non-waivable statutory consumer right provides otherwise",
            product,
        )
        self.assertIn("This is a Product behaviour requirement", product)
        self.assertIn("ordinary commercial cancellation, renewal and refund rules apply except to the extent", decision)

        self.assertIn("genuine month-to-month product with no minimum term", product)
        self.assertIn("ordinary monthly cancellation prevents the next renewal", product)
        self.assertIn("Membership access remains available through the paid billing period", product)
        self.assertIn("does not change monthly Membership into a minimum-term product", decision)

        self.assertIn("Where applicable law classifies a Membership agreement as a fixed-term consumer agreement", product)
        self.assertIn("recorded form legally sufficient for that right", product)
        self.assertIn("pending/effective lifecycle", product)
        self.assertIn("record the received notice and legally effective date", product)
        self.assertIn("legally sufficient recorded notice", decision)
        self.assertIn("legally effective mid-term cancellation lifecycle", decision)

        amounts_due = product.index("collect only amounts lawfully owing through the effective cancellation date")
        penalty = product.index("impose a cancellation penalty only where law permits")
        credit = product.index("credit or refund any amount that remains the consumer's")
        self.assertLess(amounts_due, penalty)
        self.assertLess(penalty, credit)
        self.assertIn("lawful amounts owing", decision)
        self.assertIn("any required credit or refund", decision)

        self.assertIn("only if the amount is reasonable under the applicable legal test", product)
        self.assertIn("reasonable under the applicable legal factors", decision)
        self.assertIn("evidence", product)
        self.assertIn("evidence-based", decision)
        self.assertIn("deterministic, versioned and auditable results after legal approval", product)
        self.assertIn("deterministic, versioned and auditable policy after legal approval", decision)

        self.assertIn("Product Law selects no percentage or formula", product)
        self.assertIn("No percentage or formula is selected", decision)
        self.assertNotRegex(policy, r"\b\d+(?:\.\d+)?\s*(?:%|percent|per cent)\b")
        self.assertNotRegex(
            policy,
            r"(?i)\b(?:penalty|cancellation charge|cancellation fee)\b[^.\n]{0,160}"
            r"\b(?:equals?|equal to|calculated as|computed as|fixed at|set at|pro rata|pro-rata|"
            r"proportional to|fraction of|portion of|sum of|per remaining|for each remaining|"
            r"per month|per day|multiplied by)\b",
        )
        self.assertIn("more consumer-favourable cap or a zero-penalty policy", product)
        self.assertIn("more consumer-favourable cap or zero penalty", decision)
        self.assertIn("unsupported penalty cannot be charged or used to delay or deny cancellation", product)
        self.assertIn("unsupported penalty cannot delay or deny cancellation", decision)
        self.assertIn("Provider behaviour, provider pricing and future lost revenue do not establish the lawful penalty", product)
        self.assertIn("Provider behaviour, provider pricing and future lost revenue do not establish a lawful penalty", decision)

        self.assertIn("provide required expiry notice with the timing, information and options required by law", product)
        self.assertIn("expressly agrees to another fixed term where law requires", product)
        self.assertIn("month-to-month continuation where it is the default", product)
        self.assertIn("consumer's express agreement where law requires", decision)
        self.assertIn("month-to-month continuation is supported where law makes it the default", decision)

    def test_dec315_narrow_supersession_preserves_unrelated_product_truths(self):
        product = document_section(self.product, "## 21A.6 Billing and cancellation")
        decision_039 = document_section(self.decisions, "## DEC-039 — Membership billing")
        decision_045 = document_section(self.decisions, "## DEC-045 — Refund boundaries")
        decision_313 = document_section(
            self.decisions, "## DEC-313 — Assessment-credit claim, hold, delivery and release"
        )
        decision_315 = document_section(
            self.decisions, "## DEC-315 — Statutory consumer cancellation and refund rights"
        )

        self.assertIn("**Status:** SUPERSEDED IN PART BY DEC-315", decision_039)
        self.assertIn("supersedes only the unconditional cancellation timing", decision_039)
        self.assertIn(
            "where an applicable non-waivable statutory consumer right requires another effective date",
            decision_039,
        )
        self.assertIn("**Status:** SUPERSEDED IN PART BY DEC-315", decision_045)
        self.assertIn("supersedes only Membership's ordinary partial-period boundary", decision_045)
        self.assertIn(
            "to the extent an applicable non-waivable statutory right provides a cancellation, refund or credit",
            decision_045,
        )
        self.assertIn("Assessment, Plan and Event rules remain unchanged as ordinary commercial boundaries", decision_045)
        self.assertIn("DEC-039's absolute end-of-paid-period cancellation timing", decision_315)
        self.assertIn("DEC-045's Membership ordinary partial-period refund boundary", decision_315)
        self.assertIn("does not change monthly Membership into a minimum-term product", decision_315)
        self.assertIn("ordinary Assessment, Plan, gift or Event refund rules", product)
        self.assertIn("alter Assessment, Plan, gift, Event or payment-reversal rules", decision_315)

        self.assertIn("does not change DEC-313's Assessment-credit hold, consumption or release semantics", product)
        self.assertIn("change DEC-313 Assessment-credit semantics", decision_315)
        self.assertIn("first valid saved answer claims/holds the same credit in `held_unconsumed`", decision_313)
        self.assertIn("only successful complete paid digital Assessment delivery", decision_313)
        self.assertIn("releases the same credit to `available_unused`", decision_313)

        self.assertIn("independently purchased Assessments, once-off Plans and historical check-ins remain", product)
        self.assertIn("unused Membership-derived reassessment entitlements follow their existing expiry rule", product)
        self.assertIn("Membership termination, payment refund or reversal, Entitlement termination and full Account deletion remain separate Product truths", product)
        self.assertIn("alter Entitlement or Account-deletion rules", decision_315)

        closure = document_section(self.product, "## 21I.2 Account closure")
        deletion = document_section(self.product, "## 21I.3 Full deletion")
        self.assertIn("Account closure is distinct from full deletion", closure)
        self.assertIn("30 days", closure)
        self.assertIn("14-day cancellation window", deletion)
        self.assertIn("no reconstruction from transactions, backups or retained records", deletion)
        self.assertIn("Use a 30-day recoverable account-closure window and a 14-day full-deletion cancellation window", self.decisions)
        self.assertIn("completed deletion has no recovery or reconstruction path", self.decisions)

    def test_dec315_preserves_commerce_entitlements_and_provider_authority_boundaries(self):
        product = document_section(self.product, "## 21A.6 Billing and cancellation")
        decision = document_section(
            self.decisions, "## DEC-315 — Statutory consumer cancellation and refund rights"
        )

        self.assertIn("Commerce remains authoritative for the Membership contract and commercial cancellation/refund truth", decision)
        self.assertIn("Entitlements remains authoritative for current access and grants", decision)
        self.assertIn("Provider state remains evidence", decision)
        self.assertIn("Commerce's cancellation effective date is authoritative", product)
        self.assertIn("A provider cannot delay or reverse that date", product)
        self.assertIn("cannot reactivate Membership", product)
        self.assertIn("change Domain ownership", decision)

        commerce = next(line for line in self.domain_map.splitlines() if "Membership/subscription/add-on commercial contract" in line)
        entitlements = next(line for line in self.domain_map.splitlines() if "Entitlement/access grant" in line)
        self.assertIn("**Commerce**", commerce)
        self.assertIn("**Entitlements**", entitlements)
        self.assertIn("external-provider state never become hidden business authority", self.domain_map)

    def test_paid_plan_matrix_covers_each_safety_outcome_and_terminal_closeout(self):
        rows = matrix_rows(self.product, "ELIGIBILITY-PAID-PLAN")
        cases = {row["case"]: row for row in rows}
        self.assertEqual(
            {
                "eligible_automated",
                "insufficient_information",
                "professional_review_required",
                "general_wellness_only",
                "terminal_unfulfillable_outcome",
            },
            set(cases),
        )
        self.assertIn("consume_on_successful_delivery", cases["eligible_automated"]["entitlement consequence"])
        self.assertIn("technical_failure=preserve_unconsumed", cases["eligible_automated"]["entitlement consequence"])
        self.assertIn("held_unconsumed", cases["insufficient_information"]["entitlement consequence"])
        self.assertIn("no_expiry_for_incomplete_information", cases["insufficient_information"]["entitlement consequence"])
        self.assertIn("held_unconsumed_pending_review", cases["professional_review_required"]["entitlement consequence"])
        self.assertIn("not_personalised_plan_fulfilment", cases["general_wellness_only"]["commercial consequence"])
        self.assertIn("retained_right_no_expiry_solely_due_to_gw_status", cases["general_wellness_only"]["entitlement consequence"])
        self.assertIn("no_choice_by_end_of_single_14_day_window=refund_snapshot_and_close", cases["general_wellness_only"]["commercial consequence"])
        self.assertIn("refund_allocated_plan_component", cases["terminal_unfulfillable_outcome"]["commercial consequence"])

    def test_commercial_reversal_matrix_covers_access_and_history_consequences(self):
        rows = matrix_rows(self.product, "COMMERCIAL-REVERSAL")
        cases = {row["case"]: row for row in rows}
        self.assertEqual(
            {
                "refund_before_entitlement_use",
                "plan_refund_before_generation",
                "verified_technical_failure_refund",
                "duplicate_payment_refund",
                "membership_duplicate_billing_refund",
                "unverified_provider_signal",
                "confirmed_disputed_chargeback",
                "chargeback_payment_restored",
                "final_lost_chargeback",
                "post_delivery_full_reversal",
            },
            set(cases),
        )
        self.assertIn("end_refunded_component", cases["refund_before_entitlement_use"]["entitlement/access consequence"])
        self.assertIn("preserve_one_valid_right", cases["duplicate_payment_refund"]["entitlement/access consequence"])
        self.assertIn("no_entitlement_mutation", cases["unverified_provider_signal"]["entitlement/access consequence"])
        self.assertIn("suspend_after_commerce_confirmation", cases["confirmed_disputed_chargeback"]["entitlement/access consequence"])
        self.assertIn("restore_idempotently", cases["chargeback_payment_restored"]["entitlement/access consequence"])
        self.assertIn("end_paid_access", cases["final_lost_chargeback"]["entitlement/access consequence"])
        for row in rows:
            self.assertIn("preserve_historical_record", row["historical record consequence"])

    def test_consent_matrix_separates_future_processing_from_delivered_plan_access(self):
        rows = matrix_rows(self.product, "CONSENT-WITHDRAWAL")
        cases = {row["event"]: row for row in rows}
        self.assertEqual(
            {
                "personalisation_withdrawal",
                "automated_recommendation_withdrawal",
                "practitioner_sharing_withdrawal",
                "optional_ai_withdrawal",
                "health_storage_withdrawal",
                "full_account_deletion",
            },
            set(cases),
        )
        for event in (
            "personalisation_withdrawal",
            "automated_recommendation_withdrawal",
            "practitioner_sharing_withdrawal",
            "optional_ai_withdrawal",
        ):
            self.assertIn("stop_affected_future_processing", cases[event]["future processing"])
            self.assertIn("entitlement_unchanged", cases[event]["commercial entitlement"])
        self.assertIn("conditional_on_independent_lawful_basis", cases["health_storage_withdrawal"]["delivered plan access"])
        self.assertIn("end_ordinary_access", cases["full_account_deletion"]["delivered plan access"])
        self.assertIn("separate_lifecycle", cases["full_account_deletion"]["commercial entitlement"])

    def test_provenance_matrix_forbids_exact_scores_without_digital_assessment(self):
        rows = matrix_rows(self.product, "TEMPERAMENT-PROVENANCE")
        cases = {row["provenance"]: row for row in rows}
        self.assertEqual(
            {"self_reported", "book_derived", "digitally_assessed", "later_digital_completion"},
            set(cases),
        )
        for provenance in ("self_reported", "book_derived"):
            self.assertEqual("no", cases[provenance]["exact digital scores"])
            self.assertEqual("no", cases[provenance]["paid digital report"])
            self.assertEqual("unused", cases[provenance]["included assessment credit"])
        self.assertEqual("yes", cases["digitally_assessed"]["exact digital scores"])
        self.assertEqual("yes", cases["digitally_assessed"]["paid digital report"])
        self.assertIn("preserve_prior_provenance", cases["later_digital_completion"]["result history"])

    def test_repeat_assessment_matrix_distinguishes_sale_credit_attempt_and_retake(self):
        rows = matrix_rows(self.product, "ASSESSMENT-PURCHASE-USE")
        cases = {row["case"]: row for row in rows}
        self.assertEqual(
            {
                "standalone_purchase_without_unused_credit",
                "standalone_purchase_with_unused_paid_credit",
                "purchase_when_annual_use_interval_blocks_attempt",
                "bundle_purchase_with_unused_paid_credit",
                "premium_annual_reassessment_credit",
                "plan_only_purchase_with_assessment_credit",
            },
            set(cases),
        )
        self.assertEqual("one", cases["standalone_purchase_without_unused_credit"]["maximum active unused ordinary paid credits"])
        self.assertIn("reject", cases["standalone_purchase_with_unused_paid_credit"]["purchase eligibility"])
        self.assertIn("reject", cases["purchase_when_annual_use_interval_blocks_attempt"]["purchase eligibility"])
        self.assertIn("route_to_approved_plan_only_offer", cases["bundle_purchase_with_unused_paid_credit"]["purchase eligibility"])
        self.assertIn("non_accumulating", cases["premium_annual_reassessment_credit"]["Premium credit rule"])
        self.assertIn("independent_of_assessment_credit", cases["plan_only_purchase_with_assessment_credit"]["purchase eligibility"])

    def test_resolved_oq034_and_harden02_lifecycle_are_current_in_all_routes(self):
        decision = re.search(r"^## OQ-034[^\n]*\n\*\*Status:\*\* ([^\n]+)", self.decisions, re.MULTILINE)
        self.assertIsNotNone(decision)
        self.assertIn("RESOLVED / ARCHITECTURE SELECTION", decision.group(1))
        for document_name, document in (("Roadmap", self.roadmap), ("FP-001", self.fp001)):
            for line in document.splitlines():
                if "OQ-034" in line:
                    self.assertNotIn("BLOCKS_THIS_FP", line, f"{document_name} still blocks on resolved OQ-034")
            self.assertRegex(document.lower(), r"phase 8.{0,180}proof|proof.{0,180}phase 8")
            self.assertRegex(document.lower(), r"proof[^\n]{0,100}(not complete|not finalised|not finalized|incomplete)")

        identity_pmr_gate = next(
            line for line in self.roadmap.splitlines() if "Verified account + required PMR" in line
        )
        self.assertNotIn("OQ-034", identity_pmr_gate)
        self.assertIn("OQ-035", identity_pmr_gate)
        self.assertIn("OQ-036", identity_pmr_gate)
        major_gate_lines = [
            line for line in self.roadmap.splitlines() if line.lower().startswith("**major gates")
        ]
        self.assertTrue(major_gate_lines)
        self.assertFalse(any("OQ-034" in line for line in major_gate_lines))

        state = matrix_rows(self.open_work, "HARDEN-02-LIFECYCLE")
        statuses = {row["gate"]: row["status"] for row in state}
        self.assertEqual(
            {
                "CONTRACT_LIFECYCLE": "COMPLETE / CERTIFIED",
                "PRE_MERGE_CERTIFICATION": "COMPLETE",
                "EXACT_HEAD_CI": "PASS",
                "CERTIFIED_HEAD_MERGE": "COMPLETE_UNCHANGED",
                "RESULTING_MAIN_CI": "PASS",
                "POST_MERGE_INDEPENDENT_REVIEW": "PASS",
                "POST_MERGE_ATTESTATION": "COMPLETE",
                "EXECUTION": "COMPLETE_CERTIFIED",
            },
            statuses,
        )
        self.assertIn("POST-MERGE CERTIFICATION: COMPLETE", self.readme)
        self.assertIn("HARDEN-02 EXECUTION: COMPLETE / CERTIFIED", self.readme)
        self.assertIn("ENGINEERING STANDARDS AUTHORITY PROMOTION: COMPLETE / CERTIFIED", self.readme)
        self.assertIn("ARCHITECTURAL PROOF CLASSIFICATION: COMPLETE / FINALISED", self.readme)
        self.assertIn("PROOF CLASSIFICATION: NEW_TRACER_BULLET", self.readme)
        self.assertIn("DEVELOPMENT ENTRY HARD STOP: PASS / ALL 10 CONDITIONS SATISFIED", self.readme)
        self.assertIn("## Historical status evidence", self.readme)
        self.assertIn("Phase 8 and executable implementation remain UNAUTHORISED", self.readme.split("## Historical status evidence", 1)[1])
        self.assertNotIn("PENDING INDEPENDENT PRE-MERGE CERTIFICATION", self.readme)
        self.assertIn("352f304139b9d4f8ee3ba205cde9e34d0ad8437f", self.harden02)
        self.assertIn("36101210535", self.harden02)

    def test_foundation_integrity_audit_runs_the_product_semantic_checks(self):
        report = foundation_integrity_audit.run_audit(ROOT, MANIFEST)
        checks = {item["name"]: item for item in report["checks"]}
        expected = {
            "eligibility_commercial_consequences",
            "commercial_reversal_consequences",
            "consent_withdrawal_consequences",
            "temperament_provenance_outputs",
            "assessment_purchase_governance",
            "resolved_oq_not_blocking",
            "harden_02_lifecycle_state",
            "bundle_component_allocation_governance",
            "product_hardening_feature_pack_propagation",
        }
        self.assertTrue(expected <= checks.keys())
        for check in expected:
            self.assertEqual("PASS", checks[check]["status"], checks[check]["message"])

    def test_feature_pack_propagation_checker_catches_missing_pack_contract(self):
        requirements = self.integrity_rules["product_hardening_feature_pack_requirements"]
        self.assertEqual(
            {"FP-002", "FP-003", "FP-004", "FP-005", "FP-010"},
            set(requirements),
        )
        self.assertEqual(
            [], foundation_integrity_audit._feature_pack_propagation_issues(self.roadmap, requirements)
        )

        missing_provenance = self.roadmap.replace(
            "declared_temperament_has_no_exact_digital_score_or_report",
            "declared_temperament_may_have_exact_digital_score_or_report",
            1,
        )
        issues = foundation_integrity_audit._feature_pack_propagation_issues(
            missing_provenance, requirements
        )
        self.assertTrue(any("FP-003" in issue for issue in issues), issues)

        missing_authority = self.roadmap.replace(
            "`DEC-302`, `DEC-303`", "`DEC-303`", 1
        )
        issues = foundation_integrity_audit._feature_pack_propagation_issues(
            missing_authority, requirements
        )
        self.assertTrue(any("FP-003 does not cite DEC-302" in issue for issue in issues), issues)

    def test_bundle_allocation_checker_requires_snapshot_governance_and_reconciled_prices(self):
        requirements = self.integrity_rules["product_hardening_bundle_allocation_requirements"]
        self.assertEqual(
            [],
            foundation_integrity_audit._bundle_component_allocation_issues(
                self.product, self.decisions, requirements
            ),
        )

        missing_refund_basis = self.product.replace(
            "| `component_refund` | `refund_from_original_order_snapshot; never_current_price` |",
            "| `component_refund` | `refund_from_current_price` |",
            1,
        )
        issues = foundation_integrity_audit._bundle_component_allocation_issues(
            missing_refund_basis, self.decisions, requirements
        )
        self.assertTrue(any("component_refund" in issue for issue in issues), issues)

        invalid_example = self.product.replace(
            "R249_assessment + R399_plan - R99_bundle_discount = R549_accepted_bundle_amount",
            "R249_assessment + R399_plan - R99_bundle_discount = R550_accepted_bundle_amount",
            1,
        )
        issues = foundation_integrity_audit._bundle_component_allocation_issues(
            invalid_example, self.decisions, requirements
        )
        self.assertTrue(any("launch_bundle" in issue for issue in issues), issues)

        missing_decision_rule = self.decisions.replace(
            "versioned deterministic allocation rule",
            "unversioned allocation rule",
            1,
        )
        issues = foundation_integrity_audit._bundle_component_allocation_issues(
            self.product, missing_decision_rule, requirements
        )
        self.assertTrue(
            any("DEC-299 does not carry" in issue for issue in issues), issues
        )

    def test_current_governance_source_trails_resolve_to_current_or_archived_files(self):
        self.assertIn("05_ROADMAP_v1.2.4.md", self.open_work)
        self.assertIn("archive/05_ROADMAP_v1.1.0.md", self.open_work)
        self.assertIn("archive/03_ARCHITECTURE_v1.1.0.md", self.open_work)
        self.assertIn("archive/04_DOMAIN_MAP_v1.1.0.md", self.open_work)
        self.assertIn("archive/00_PLATFORM_v1.3.0.md", self.decisions)
        self.assertEqual(
            "docs/governance/architecture/03_ARCHITECTURE_v1.1.1.md",
            current_document_path(ROOT, "ARCHITECTURE_SYNTHESIS").relative_to(ROOT).as_posix(),
        )
        self.assertEqual(
            "docs/governance/domain/04_DOMAIN_MAP_v1.2.0.md",
            current_document_path(ROOT, "DOMAIN_MAP").relative_to(ROOT).as_posix(),
        )
        self.assertTrue(
            "docs/history/platform/superseded-delivery/DELIVERY_ATLAS_WORKING_v0.2.1.md" in self.fp001,
            "FP-001 retains its pinned v0.2.1 Atlas source-at-freeze path unchanged",
        )
        self.assertEqual(
            "docs/governance/architecture/references/REFERENCE_FLOW_PRESSURE_TESTS_WORKING_v0.3.0.md",
            current_document_path(ROOT, "REFERENCE_FLOW_PRESSURE_TESTS").relative_to(ROOT).as_posix(),
        )
        self.assertIn("docs/history/platform/archive/02_OPEN_WORK_v1.2.28.md", self.fp001)
        self.assertIn("docs/history/platform/archive/DELIVERY_ATLAS_WORKING_v0.1.0.md", self.fp001)
        atlas_reconciliation = self.atlas.split("## 26.18 ATLAS reconciliation (`v0.3.0`) completion standard", 1)[1]
        historical_source_routing = next(
            line for line in atlas_reconciliation.splitlines() if "| Current-source routing |" in line
        )
        self.assertIn(
            "North Star/MVP `v1.3.0`, Product `v1.6.0`, Decisions `v1.6.0`, "
            "Architecture `v1.1.1`, Domain Map `v1.2.0`, Roadmap `v1.2.0` and current Open Work `v1.2.59`",
            historical_source_routing,
        )
        self.assertNotIn("Product `v1.5.1`", historical_source_routing)
        self.assertNotIn("Roadmap `v1.1.5`", historical_source_routing)
        current_source_table = self.atlas.split("## 1.1 Authority hierarchy", 1)[1].split("## 1.2 Purpose", 1)[0]
        for current_name in (
            "PROJECT_NORTH_STAR_AND_MVP_v1.3.0.md",
            *ATLAS_PRODUCT_SOURCES,
            current_document_path(ROOT, "OPEN_WORK").name,
            "04_DOMAIN_MAP_v1.2.0.md",
            current_document_path(ROOT, "ROADMAP").name,
        ):
            self.assertIn(current_name, current_source_table)
        self.assertNotIn("Product `v1.3.0`", historical_source_routing)
        self.assertNotIn("Architecture `v1.1.0`", historical_source_routing)

        source_trails = {
            "Open Work": self.open_work,
            "Decision Register": self.decisions,
            "FP-001": self.fp001,
            "Architecture": self.architecture,
            "Domain Map": self.domain_map,
            "Operating Model": self.operating_model,
            "Delivery Atlas": self.atlas,
            "HARDEN-02": self.harden02,
            "Frontend Experience System": self.fes,
        }
        moved_predecessors = (
            "PROJECT_NORTH_STAR_AND_MVP_v1.2.1.md",
            "00_PLATFORM_v1.2.1.md",
            "00_PLATFORM_v1.3.0.md",
            "01_DECISIONS_v1.2.2.md",
            "01_DECISIONS_v1.3.0.md",
            "05_ROADMAP_v1.1.0.md",
            "05_ROADMAP_v1.0.0.md",
            "03_ARCHITECTURE_v1.0.0.md",
            "03_ARCHITECTURE_v1.1.0.md",
            "04_DOMAIN_MAP_v1.0.0.md",
            "04_DOMAIN_MAP_v1.1.0.md",
            "PLATFORM_OPERATING_MODEL_v1.0.0.md",
            "02_OPEN_WORK_v1.2.36.md",
            "02_OPEN_WORK_v1.2.37.md",
            "02_OPEN_WORK_v1.2.39.md",
            "02_OPEN_WORK_v1.2.43.md",
            "REFERENCE_FLOW_PRESSURE_TESTS_WORKING_v0.2.0.md",
            "HARDEN-02_CONTRACT_WORKING_v0.3.0.md",
            "HARDEN-02_CONTRACT_WORKING_v0.4.0.md",
            "DELIVERY_ATLAS_WORKING_v0.1.0.md",
            "DELIVERY_ATLAS_WORKING_v0.2.0.md",
            "FRONTEND_EXPERIENCE_SYSTEM_v1.0.0.md",
            "02_OPEN_WORK_v1.2.28.md",
        )
        for document_name, document in source_trails.items():
            for filename in moved_predecessors:
                with self.subTest(document=document_name, filename=filename):
                    self.assertIsNone(
                        re.search(r"(?<!archive/)" + re.escape(filename), document),
                        f"{document_name} uses an unarchived predecessor path: {filename}",
                    )

        current_reference_sources = {
            "Open Work": (
                "ARCHITECTURE_LAW_WORKING_v0.36.0.md",
                "REFERENCE_FLOW_PRESSURE_TESTS_WORKING_v0.3.0.md",
            ),
            "Architecture": (
                "ARCHITECTURE_REQUIREMENTS_WORKING_v1.1.0.md",
                "ARCHITECTURE_LAW_WORKING_v0.36.0.md",
                "REFERENCE_FLOW_PRESSURE_TESTS_WORKING_v0.3.0.md",
            ),
            "Domain Map": ("ARCHITECTURE_LAW_WORKING_v0.36.0.md",),
        }
        for document_name, filenames in current_reference_sources.items():
            for filename in filenames:
                with self.subTest(document=document_name, current_reference=filename):
                    self.assertIn("reference/" + filename, source_trails[document_name])
                    self.assertIsNone(
                        re.search(r"(?<!reference/)" + re.escape(filename), source_trails[document_name]),
                        f"{document_name} contains an unresolved reference path: {filename}",
                    )

        self.assertIn(
            "docs/governance/architecture/references/REFERENCE_FLOW_PRESSURE_TESTS_WORKING_v0.3.0.md",
            source_trails["FP-001"],
        )
        self.assertIn(
            "| `docs/governance/architecture/references/REFERENCE_FLOW_PRESSURE_TESTS_WORKING_v0.3.0.md §§1.1, 2, 3` |",
            self.fp001,
        )
        self.assertIn(
            "docs/governance/architecture/references/ARCHITECTURE_LAW_WORKING_v0.36.0.md",
            source_trails["Delivery Atlas"],
        )

        archived_source_paths = (
            "docs/00_platform/archive/PROJECT_NORTH_STAR_AND_MVP_v1.2.4.md",
            "docs/00_platform/archive/00_PLATFORM_v1.5.1.md",
            "docs/00_platform/archive/01_DECISIONS_v1.5.0.md",
            "docs/00_platform/archive/02_OPEN_WORK_v1.2.50.md",
            "docs/00_platform/archive/05_ROADMAP_v1.1.5.md",
            "docs/00_platform/archive/DELIVERY_ATLAS_WORKING_v0.3.2.md",
            "docs/00_platform/archive/HARDEN-02_CONTRACT_WORKING_v0.4.4.md",
            "docs/00_platform/archive/05_ROADMAP_v1.1.0.md",
            "docs/00_platform/archive/PROJECT_NORTH_STAR_AND_MVP_v1.2.1.md",
            "docs/00_platform/archive/00_PLATFORM_v1.2.1.md",
            "docs/00_platform/archive/00_PLATFORM_v1.3.0.md",
            "docs/00_platform/archive/00_PLATFORM_v1.4.1.md",
            "docs/00_platform/archive/01_DECISIONS_v1.2.2.md",
            "docs/00_platform/archive/01_DECISIONS_v1.3.0.md",
            "docs/00_platform/archive/01_DECISIONS_v1.4.1.md",
            "docs/00_platform/archive/02_OPEN_WORK_v1.2.45.md",
            "docs/00_platform/archive/02_OPEN_WORK_v1.2.36.md",
            "docs/00_platform/archive/02_OPEN_WORK_v1.2.37.md",
            "docs/00_platform/archive/02_OPEN_WORK_v1.2.39.md",
            "docs/00_platform/archive/02_OPEN_WORK_v1.2.43.md",
            "docs/00_platform/archive/03_ARCHITECTURE_v1.0.0.md",
            "docs/00_platform/archive/03_ARCHITECTURE_v1.1.0.md",
            "docs/00_platform/archive/04_DOMAIN_MAP_v1.0.0.md",
            "docs/00_platform/archive/04_DOMAIN_MAP_v1.1.0.md",
            "docs/00_platform/archive/04_DOMAIN_MAP_v1.1.1.md",
            "docs/00_platform/archive/05_ROADMAP_v1.0.0.md",
            "docs/00_platform/archive/PLATFORM_OPERATING_MODEL_v1.0.0.md",
            "docs/00_platform/archive/REFERENCE_FLOW_PRESSURE_TESTS_WORKING_v0.2.0.md",
            "docs/00_platform/archive/HARDEN-02_CONTRACT_WORKING_v0.3.0.md",
            "docs/00_platform/archive/HARDEN-02_CONTRACT_WORKING_v0.4.0.md",
            "docs/00_platform/archive/DELIVERY_ATLAS_WORKING_v0.1.0.md",
            "docs/00_platform/archive/DELIVERY_ATLAS_WORKING_v0.2.0.md",
            "docs/00_platform/archive/DELIVERY_ATLAS_WORKING_v0.2.1.md",
            "docs/00_platform/archive/FRONTEND_EXPERIENCE_SYSTEM_v1.0.0.md",
            "docs/00_platform/archive/02_OPEN_WORK_v1.2.28.md",
        )
        for relative_path in archived_source_paths:
            with self.subTest(path=relative_path):
                self.assertTrue((ROOT / relative_path).is_file())

        current_source_paths = (
            "docs/00_platform/PROJECT_NORTH_STAR_AND_MVP_v1.3.0.md",
            current_document_path(ROOT, "PLATFORM_BASELINE").relative_to(ROOT).as_posix(),
            current_document_path(ROOT, "DECISION_REGISTER").relative_to(ROOT).as_posix(),
            current_document_path(ROOT, "OPEN_WORK").relative_to(ROOT).as_posix(),
            current_document_path(ROOT, "ROADMAP").relative_to(ROOT).as_posix(),
            "docs/00_platform/03_ARCHITECTURE_v1.1.1.md",
            "docs/00_platform/04_DOMAIN_MAP_v1.2.0.md",
            current_document_path(ROOT, "PLATFORM_OPERATING_MODEL").relative_to(ROOT).as_posix(),
            "docs/00_platform/FRONTEND_EXPERIENCE_SYSTEM_v1.0.1.md",
            current_working_path(ROOT, "DELIVERY_ATLAS_WORKING_").relative_to(ROOT).as_posix(),
            current_working_path(ROOT, "HARDEN-02_CONTRACT_WORKING_").relative_to(ROOT).as_posix(),
            "docs/00_platform/reference/REFERENCE_FLOW_PRESSURE_TESTS_WORKING_v0.3.0.md",
            "docs/00_platform/reference/ARCHITECTURE_REQUIREMENTS_WORKING_v1.1.0.md",
            "docs/00_platform/reference/ARCHITECTURE_LAW_WORKING_v0.36.0.md",
        )
        for relative_path in current_source_paths:
            with self.subTest(path=relative_path):
                self.assertTrue((ROOT / relative_path).is_file())

    def test_active_authority_headers_resolve_historical_inputs_through_archive(self):
        expected_archived_sources = {
            "Architecture": (
                "archive/PROJECT_NORTH_STAR_AND_MVP_v1.2.1.md",
                "archive/00_PLATFORM_v1.3.0.md",
                "archive/01_DECISIONS_v1.3.0.md",
                "archive/02_OPEN_WORK_v1.2.36.md",
                "archive/03_ARCHITECTURE_v1.1.0.md",
            ),
            "Domain Map": (
                "archive/PROJECT_NORTH_STAR_AND_MVP_v1.2.1.md",
                "archive/00_PLATFORM_v1.3.0.md",
                "archive/01_DECISIONS_v1.3.0.md",
                "archive/02_OPEN_WORK_v1.2.37.md",
                "archive/04_DOMAIN_MAP_v1.1.0.md",
            ),
            "Operating Model": (
                "archive/PLATFORM_OPERATING_MODEL_v1.0.1.md",
            ),
            "Frontend Experience System": ("archive/FRONTEND_EXPERIENCE_SYSTEM_v1.0.0.md",),
        }
        documents = {
            "Architecture": self.architecture,
            "Domain Map": self.domain_map,
            "Operating Model": self.operating_model,
            "Frontend Experience System": self.fes,
        }
        for name, paths in expected_archived_sources.items():
            for path in paths:
                with self.subTest(document=name, path=path):
                    self.assertTrue(path in documents[name], f"{name} is missing {path}")
                    filename = path.removeprefix("archive/")
                    self.assertIsNone(
                        re.search(r"(?<!archive/)" + re.escape(filename), documents[name]),
                        f"{name} contains an unresolved unarchived source path: {filename}",
                    )

    def test_pass2_product_semantics_and_roadmap_gates_are_encoded_with_closed_evaluation_and_unchanged_programme_lifecycle(self):
        for number in range(305, 313):
            with self.subTest(decision=number):
                self.assertEqual(1, self.decisions.count(f"## DEC-{number:03d} —"))

        personalisation = self.product.split("## 21T.1 Temperament as behavioural-personalisation input", 1)[1].split("# 22.", 1)[0]
        self.assertIn("clinical / safety truth\n→ nutritional / health truth\n→ participant context and constraints\n→ temperament-informed behavioural strategy\n→ participant feedback and learned preferences\n→ presentation", personalisation)
        for truth in (
            "historical assessment result",
            "current temperament / profile interpretation",
            "active personalisation preferences",
            "learned behavioural preferences",
        ):
            self.assertIn(truth, personalisation)
        self.assertIn("not automatically a mask temperament", personalisation)
        self.assertIn("may version low-risk behavioural application rules", personalisation)
        self.assertIn("without methodology approval for each application change", personalisation)
        self.assertIn("Methodology-neutral infrastructure such as assessment attempts", personalisation)
        self.assertIn("may be designed or implemented where otherwise authorised", personalisation)
        self.assertIn("must not infer trauma", personalisation)
        self.assertIn("remain methodology-owned", personalisation)
        self.assertIn("a clinical personality diagnosis", personalisation)

        self.assertIn("not fulfilment of the purchased personalised plan", personalisation)
        self.assertIn("plan entitlement remains held_unconsumed", personalisation)
        self.assertIn("automatically refunds the original snapshotted plan-component allocation", personalisation)
        self.assertIn("NewYou remains intentionally a platform", personalisation)
        self.assertIn("100%-discount purchases", personalisation)
        self.assertIn("3 or more pauses commercial expansion", personalisation)
        self.assertIn("Considering what you paid", personalisation)
        self.assertIn("two Afrikaans-first and two English-first", personalisation)
        self.assertIn("at least one engagement after Day 1", personalisation)
        self.assertIn("at least 70% survey response", personalisation)
        self.assertIn("MVP success does not prove the long-term North Star", personalisation)
        self.assertIn("no hard customer acquisition cost, lifetime value or profit-margin threshold", personalisation)
        self.assertIn("Practitioner services have separate service economics", personalisation)

        pilot_criteria = self.product.split("## 21L.23 First paid-pilot success criteria", 1)[1].split("## 21L.24", 1)[0]
        self.assertIn("metric definitions in §21T.7", pilot_criteria)
        self.assertIn("health-onboarding completion using the §21T.7 denominator", pilot_criteria)
        self.assertIn("meaningful seven-day usage under the §21T.7 definition", pilot_criteria)
        self.assertNotIn("among eligible purchasers", pilot_criteria)
        self.assertIn("at least 70% of the cohort must respond to the value survey", pilot_criteria)

        def pack(pack_id: str) -> str:
            start = self.roadmap.index(f"## {pack_id} —")
            following = re.search(r"(?m)^## FP-\d{3} —", self.roadmap[start + 1 :])
            end = start + 1 + following.start() if following else len(self.roadmap)
            return self.roadmap[start:end]

        fp003 = pack("FP-003")
        self.assertIn("production-intended proprietary assessment encoding", fp003)
        self.assertIn("may be designed or implemented only where otherwise authorised", fp003)
        fp006 = pack("FP-006")
        for metric_field in ("numerator", "denominator", "qualifying event", "measurement window", "missing-data treatment", "definition version"):
            self.assertIn(metric_field, fp006)
        self.assertIn("Day 30 and Day 90 evidence in parallel", fp006)
        fp009 = pack("FP-009")
        self.assertIn("Before recurring scale is treated as commercially validated", fp009)
        self.assertIn("does not establish healthy economics", fp009)
        fp012 = pack("FP-012")
        self.assertIn("Practitioner-service economics are reviewed separately", fp012)

        historical_open_work = (DOCS / "archive" / "02_OPEN_WORK_v1.2.68.md").read_text(encoding="utf-8")
        self.assertIn("Foundation Evaluation Pass 2 remain COMPLETE / CLOSED / PASS", historical_open_work)
        self.assertIn("**Evaluation status:** CLOSED / PASS.", self.open_work)
        self.assertIn("24eeb2834d58e19e0c833f09d769118d75fc9061", self.open_work)
        self.assertIn("36852114112", self.open_work)
        self.assertIn("HARDEN-02 EXECUTION COMPLETE / CERTIFIED", self.open_work)
        phase7c_candidate_predecessor = (
            DOCS / "archive" / "02_OPEN_WORK_v1.2.69.md"
        ).read_text(encoding="utf-8")
        self.assertIn(
            "PHASE 7C: IN PROGRESS / CANDIDATE AUTHORED / NOT COMPLETE / CERTIFICATION PENDING",
            phase7c_candidate_predecessor,
        )
        self.assertIn("PHASE 7C: COMPLETE / CERTIFIED / CURRENT", self.open_work)
        self.assertIn("PHASE 7C EXECUTION/CONTROL TRACKER #124: CLOSED / COMPLETED", self.open_work)
        self.assertIn("ARCHITECTURAL PROOF CLASSIFICATION: COMPLETE / FINALISED", self.open_work)
        self.assertIn('"proof_classification": "NEW_TRACER_BULLET"', self.open_work)
        self.assertIn(
            "PHASE 8: AUTHORISED (ARCHITECTURAL PROOF ONLY)",
            self.open_work,
        )

    def test_pass2_review_corrections_are_locked_without_resolving_methodology_or_future_products(self):
        product_sections = self.product.split("# 17. Data Ownership and Control", 1)[1].split("# 18.", 1)[0]
        temperament = self.product.split(
            "## 21T.1 Temperament as behavioural-personalisation input", 1
        )[1].split("# 22.", 1)[0]
        assessment = self.product.split("## 21B.5 Primary, secondary and score display", 1)[1].split("## 21B.6", 1)[0]
        decisions = self.decisions.split("## DEC-306 —", 1)[1].split("## DEC-307 —", 1)[0]
        decision308 = self.decisions.split("## DEC-308 —", 1)[1].split("## DEC-309 —", 1)[0]
        decision299 = self.decisions.split("## DEC-299 —", 1)[1].split("## DEC-300 —", 1)[0]
        decision058 = self.decisions.split("## DEC-058 —", 1)[1].split("## DEC-059 —", 1)[0]

        for required in (
            "determined by the governing IP agreement",
            "Participant-specific personal, account and health records",
            "only to the extent owned or licensed under applicable agreements",
        ):
            self.assertIn(required, product_sections)
        self.assertNotIn("The platform retains intellectual-property rights in the assessment methodology", product_sections)
        self.assertNotIn("scoring logic", product_sections)

        for required in (
            "approved percentage/proportion result across all four colours",
            "does not state that a participant is a percentage of a colour as a person",
            "underlying governed scores",
            "only when the approved methodology resolves that ordering",
            "unresolved exact ties or other ambiguity visibly as tied or ambiguous",
        ):
            self.assertIn(required.lower(), assessment.lower())

        for required in (
            "approved percentage/proportion result across all four colours",
            "does not describe a participant as a percentage of a colour",
            "underlying governed scores",
            "only when the approved methodology resolves that ordering",
            "unresolved exact ties or other ambiguity visibly as tied or ambiguous",
            "two distinguishing dimensions",
            "extrovert ↔ introvert",
            "relationship-oriented ↔ task-oriented",
        ):
            self.assertIn(required.lower(), temperament.lower())
        self.assertIn("DEC-058", decisions)
        self.assertIn("percentage/proportion result", decisions)
        self.assertIn("Preserve unresolved exact ties or other ambiguity visibly", decisions)
        self.assertIn("**Status:** SUPERSEDED IN PART BY DEC-306", decision058)
        self.assertIn("DEC-308 and §21T.4", decision299)

        for requirement in (
            "does not expire solely because she remains `general_wellness_only`",
            "one 14-day choice window",
            "Any reminders occur within that same window",
            "applicable pre-purchase disclosure",
        ):
            self.assertIn(requirement, decision308)
        for required in (
            "does not expire solely because she remains `general_wellness_only`",
            "future expiry or forced closure requires separately governed and versioned Product Law",
            "Any reminders occur within that same 14-day window",
            "by the end of the window",
        ):
            self.assertIn(required, temperament)
        self.assertNotIn("after the governed decision and reminder period", temperament)


    def test_atlas_routes_authority_through_routers_and_keeps_oq034_resolved(self):
        header = self.atlas.split("## ", 1)[0]
        for router in ("governance", "delivery"):
            self.assertIn(f"`docs/{router}/CURRENT_{router.upper()}_ROUTER.json`", header)

        source_references = (
            "PROJECT_NORTH_STAR_AND_MVP_v1.3.0.md",
            *ATLAS_PRODUCT_SOURCES,
            "03_ARCHITECTURE_v1.1.1.md",
            "04_DOMAIN_MAP_v1.2.0.md",
            current_document_path(ROOT, "ROADMAP").name,
            current_document_path(ROOT, "OPEN_WORK").name,
            "FRONTEND_EXPERIENCE_SYSTEM_v1.0.1.md",
        )
        source_table = self.atlas.split("## 1.2 Purpose", 1)[0]
        for filename in source_references:
            with self.subTest(filename=filename):
                self.assertTrue(filename in source_table, f"Atlas source table is missing {filename}")
        for reference in ATLAS_PRODUCT_SOURCES:
            self.assertTrue((ROOT / reference).is_file(), reference)
        fp001_section = self.atlas.split("## FP-001", 1)[1].split("## FP-002", 1)[0]
        self.assertNotRegex(fp001_section, r"OQ-034[^\n]*BLOCKS_THIS_FP")
        self.assertIn("OQ-034", fp001_section)
        self.assertIn("RESOLVED / ARCHITECTURE SELECTION", fp001_section)

    def test_resolved_oq034_semantics_detect_an_atlas_blocker(self):
        blocker = "OQ-034 — BLOCKS_THIS_FP: stale Atlas status"
        self.assertTrue(foundation_integrity_audit._has_oq034_fp_blocker([blocker]))
        self.assertFalse(
            foundation_integrity_audit._has_oq034_fp_blocker(
                [self.roadmap, self.fp001, self.atlas]
            )
        )


if __name__ == "__main__":
    unittest.main()

class RoleAuthorityRegressionTests(unittest.TestCase):
    def test_current_role_authority_and_agent_invariants(self):
        product = frozen_manifest_document('PLATFORM_BASELINE')
        decisions = frozen_manifest_document('DECISION_REGISTER')
        operating = frozen_manifest_document('PLATFORM_OPERATING_MODEL')
        open_work = frozen_manifest_document('OPEN_WORK')
        agents = (ROOT / 'AGENTS.md').read_text(encoding='utf-8')
        skeleton = current_working_path(ROOT, 'FP-001_FEATURE_PACK_SKELETON_WORKING_').read_text(encoding='utf-8')
        for phrase in (
            'Capabilities belong to governed roles/scopes and applicable relationships',
            'No ordinary direct user-to-capability grant is permitted',
            'A person is a subject of grants, never the definition of capability authority',
            'Relationships constrain scope or applicability and do not create hidden per-user grants',
            'An internal granular privilege must derive from a governed role/scope grant',
            'no ordinary direct per-user capability API is authorised',
            'One person may hold several roles',
            'Platform Administrator is the broad day-to-day platform administration role and ordinary operational delegator',
            'ordinary non-sensitive operational roles/scopes within its governed delegation catalogue',
            'Sensitivity attaches to role and scope',
            'Product authority may permit explicit, scoped, auditable and revocable self-assignment only for ordinary non-sensitive operational scopes',
            'Sensitive roles cannot be self-approved',
            'Super Admin is not a universal bypass',
            'Super Admin is exceptional break-glass authority, not an everyday working role',
            'Self-revocation is allowed',
            "An existing Super Admin may approve another identity's Super Admin grant where policy permits",
            'Developer role covers its defined technical work and alone grants no business-domain authority',
            'Platform Administrator and Super Admin do not automatically confer clinical',
            'JC is the expected initial subject of Platform Administrator, Developer and dormant break-glass Super Admin grants',
            'GOVERNED BOOTSTRAP AUTHORITY',
            'sealed after successful bootstrap',
            'It is not a normal runtime endpoint',
            'It establishes only explicit role/scope grants and never grants a capability directly to a person',
            'subject identity',
            'environment/applicability',
            'environment/applicability, reason',
            'governing Product/Decision authority version',
            'effective time',
            'execution evidence',
            'expiry/review where applicable',
            'subsequent revocation/supersession evidence',
            'approver identity must differ from the subject identity',
            'Do not remove the final valid privileged grant approver without a valid successor or the governed recovery ceremony',
            'If no designated approver exists, STOP',
            'strong phishing-resistant authentication',
            'passkey/WebAuthn-class credentials',
            'WELL-65 owns later Identity & Access implementation planning',
            'Identity & Access owns the durable role grant',
            'supersedes any interpretation of the certified Identity dossier',
            'One identity may hold multiple explicit roles',
            'Bootstrap cannot grant expert authority for convenience',
            'environment/applicability',
            'effective time',
            'subsequent revocation/supersession evidence',
            'The approval authority recorded for an initial bootstrap or recovery grant is the governed bootstrap authority, not the subject',
            'strong MFA',
            'step-up for sensitive actions',
            'strong recovery',
            'session/device revocation',
            'no shared credentials',
            'full privileged-action audit',
        ):
            self.assertIn(phrase, product)
        for phrase in ('DEC-021', 'DEC-317', 'DEC-318', 'Platform Administrator', 'Super Admin', 'Developer'):
            self.assertIn(phrase, decisions)
        self.assertIn('## DEC-021 — Multiple roles', decisions)
        self.assertIn('## DEC-022 — Staff roles', decisions)
        self.assertIn('Initial staff categories include Support, Finance, Platform Administrator, Super Admin', decisions)
        self.assertIn('Platform Administrator is the broad day-to-day platform administration role', decisions)
        self.assertIn('DEC-317', skeleton)
        self.assertIn('DEC-318', skeleton)
        self.assertIn('00_PLATFORM_v1.12.0.md', skeleton)
        self.assertIn('current Decision Register `01_DECISIONS_v1.12.0.md`', skeleton)
        identity = current_working_path(ROOT, 'FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_').read_text(encoding='utf-8')
        self.assertIn('role/capability', identity)
        self.assertIn('ordinary direct user-to-capability grant', product)
        self.assertIn('Identity & Access owns the durable role grant', product)
        for phrase in (
            'Platform Administrator', 'Developer', 'break-glass', 'role/scope',
            'JC is the expected initial subject', 'GOVERNED BOOTSTRAP AUTHORITY',
            'Super Admin independently approves platform-operational privileged grants',
            'Domain-sensitive grants require their designated Domain approval',
        ):
            self.assertIn(phrase, operating)
        for phrase in ('Named people may receive explicit grants',
                       'bootstrap itself holds no business capability',
                       'An unresolved required approver authority is a STOP condition', 'Super Admin is break-glass'):
            self.assertIn(phrase, agents)
        self.assertIn('WELL-64 is COMPLETE', open_work)
        self.assertNotIn('pending independent Master Gate review', open_work)
        current_status = open_work.split('## 12.41 — WELL-63 completion and WELL-61 verification-message candidate evidence', 1)[1]
        self.assertIn('historical status; superseded by §12.44', open_work.split('## 12.41 —', 1)[1].split('\n', 1)[0])
        self.assertIn('WELL-63 is COMPLETE', current_status)
        self.assertIn('WELL-61 is PLANNING and unblocked by WELL-63', current_status)
        self.assertIn('WELL-49 remains BLOCKED / WAITING ON WELL-60 AND WELL-61', current_status)
        self.assertIn('WELL-49 remains BLOCKED / WAITING ON WELL-61', open_work)
        self.assertIn('WELL-65 owns later privileged-authentication implementation planning', open_work)
        self.assertIn('No runtime RBAC, authentication or Content & Media implementation is authorized here', open_work)

    def test_readme_routes_current_platform_roots_and_tracks_decision_head(self):
        router = current_governance_router_data(ROOT)
        readme = live_platform_readme_text(ROOT)
        routed_documents = {
            item["document_id"]: item
            for collection in ("governing_documents", "architecture_references", "supporting_documents")
            for item in router.get(collection, [])
        }
        for document_id in (
            "NORTH_STAR_AND_MVP",
            "PLATFORM_PRODUCT_LAW",
            "PRODUCT_DECISIONS",
            "ARCHITECTURE_LAW",
            "DOMAIN_LAW",
            "GOVERNING_ROADMAP",
            "PLATFORM_OPERATING_MODEL",
            "FRONTEND_EXPERIENCE_SYSTEM",
        ):
            route = routed_documents[document_id]
            self.assertTrue((ROOT / route["repository_path"]).is_file(), route)
        self.assertIn("governance/CURRENT_GOVERNANCE_ROUTER.json", readme)
        self.assertIn("Plane project `WELL` remains the live execution authority", readme)
