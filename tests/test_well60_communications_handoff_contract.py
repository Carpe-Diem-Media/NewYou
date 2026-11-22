from __future__ import annotations

from foundation_test_support import historical_platform_readme_text, historical_platform_readme_path
import hashlib
import json
import re
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
CANDIDATE = DOCS / "delivery/feature-contracts/fp-001/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.3.md"
APPROVED_ARCHIVE = DOCS / "history/platform/archive/FP-001_TRACER_BULLET_CONTRACT_WORKING_APPROVED_CURRENT_v0.1.2.md"
REVIEWED_CANDIDATE_ARCHIVE = DOCS / "history/platform/archive/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.2.md"
PROMOTED_CANDIDATE_ARCHIVE = DOCS / "history/platform/archive/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.3.md"
JIT = ROOT / "docs/delivery/execution/p8-05-registration-jit-spec.md"
MANIFEST_PATH = DOCS / "history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json"
OPEN_WORK = DOCS / "history/02_OPEN_WORK_v1.2.90.md"
REVIEWED_CANDIDATE_SHA256 = "e4ad6fd47bb1a04cd299fd900c2757e075352235ca286b6f368637942ae3cf6d"
MIGRATION_BASE_SHA = "a2dfeff5d6cf88d7534cd100c28f39d3045bc814"


class WELL60CommunicationsHandoffContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.candidate = CANDIDATE.read_text(encoding="utf-8")
        cls.jit = JIT.read_text(encoding="utf-8")
        cls.open_work = OPEN_WORK.read_text(encoding="utf-8")
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

    def test_reviewed_candidate_is_preserved_and_v013_is_current(self) -> None:
        rule = self.manifest["integrity_rules"]["well60_communications_handoff_candidate"]
        phase8 = self.manifest["integrity_rules"]["fp001_phase8_proof_contract_lifecycle"]
        self.assertEqual("0.1.3", rule["candidate_version"])
        self.assertEqual(
            "CURRENT / APPROVED FOR BOUNDED PHASE 8 PROOF EXECUTION",
            rule["candidate_lifecycle"],
        )
        self.assertEqual(
            "docs/00_platform/archive/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.3.md",
            rule["reviewed_candidate_archive_path"],
        )
        self.assertEqual(REVIEWED_CANDIDATE_SHA256, rule["candidate_sha256"])
        self.assertEqual(REVIEWED_CANDIDATE_SHA256, rule["reviewed_candidate_archive_sha256"])
        self.assertEqual(REVIEWED_CANDIDATE_SHA256, hashlib.sha256(PROMOTED_CANDIDATE_ARCHIVE.read_bytes()).hexdigest())
        reviewed_head = rule["reviewed_candidate_head_sha"]
        reviewed_bytes = subprocess.run(
            [
                "git",
                "show",
                f"{reviewed_head}:docs/00_platform/working/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.3.md",
            ],
            cwd=ROOT,
            check=True,
            capture_output=True,
        ).stdout
        self.assertEqual(reviewed_bytes, PROMOTED_CANDIDATE_ARCHIVE.read_bytes())
        self.assertEqual(
            "CURRENT / APPROVED FOR BOUNDED PHASE 8 PROOF EXECUTION",
            phase8["candidate_lifecycle"],
        )
        self.assertEqual(
            "docs/00_platform/working/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.3.md",
            phase8["candidate_path"],
        )
        delivery_router = json.loads(
            (DOCS / "delivery/CURRENT_DELIVERY_ROUTER.json").read_text(encoding="utf-8")
        )
        current_route = next(
            entry
            for entry in delivery_router["delivery_contracts"]
            if entry["document_id"] == "FP001_TRACER_BULLET"
        )
        self.assertEqual(CANDIDATE.relative_to(ROOT).as_posix(), current_route["repository_path"])
        self.assertEqual(
            current_route["sha256"],
            hashlib.sha256(CANDIDATE.read_bytes()).hexdigest(),
        )
        base_candidate = subprocess.run(
            [
                "git",
                "show",
                f"{MIGRATION_BASE_SHA}:docs/00_platform/working/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.3.md",
            ],
            cwd=ROOT,
            check=True,
            capture_output=True,
        ).stdout
        self.assertEqual(
            phase8["current_contract_sha256"],
            hashlib.sha256(base_candidate).hexdigest(),
        )
        self.assertNotIn(
            "The current status route uses Open Work v1.2.89, Delivery Atlas v0.4.30, FP-001 Skeleton v0.1.30 and HARDEN-02 v0.5.32.",
            self.candidate,
        )
        self.assertIn(
            "At PR #165 promotion time, the status route was Open Work v1.2.89, Delivery Atlas v0.4.30, FP-001 Skeleton v0.1.30 and HARDEN-02 v0.5.32",
            self.candidate,
        )
        self.assertEqual(
            phase8["current_contract_sha256"],
            phase8["current_route_sha256"][phase8["candidate_path"]],
        )
        self.assertEqual(
            "73725a3d3339bf07fdcd44b9a7ec86026db3e984",
            rule["reviewed_candidate_head_sha"],
        )
        self.assertEqual(
            "429677295a396b8c78e9ab6b436a57d9249eaddc",
            rule["candidate_merge_sha"],
        )
        self.assertEqual(
            "c947544000f66c104a51240e2aee3d0d123b23ec",
            rule["candidate_merge_tree_sha"],
        )
        self.assertEqual(41021446051, rule["candidate_exact_head_ci_run"])
        self.assertEqual(41022376748, rule["resulting_main_ci_run"])
        self.assertEqual(
            "429677295a396b8c78e9ab6b436a57d9249eaddc",
            rule["status_promotion_base_main_sha"],
        )
        self.assertFalse(
            (DOCS / "delivery/feature-contracts/fp-001/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.2.md").exists()
        )
        self.assertEqual(
            "973503deee2ec86f182cd7239ffe4360cd5abe92d22eee3148f472d66d11f3b4",
            hashlib.sha256(APPROVED_ARCHIVE.read_bytes()).hexdigest(),
        )
        self.assertEqual(
            "f071d9edae90e3d5ae2030a98f79d9d1698aa68bf90ed9ce474a4f9120f82836",
            hashlib.sha256(REVIEWED_CANDIDATE_ARCHIVE.read_bytes()).hexdigest(),
        )
        previous_promotion = next(
            item for item in phase8["promotion_history"] if item["artifact_version"] == "0.1.2"
        )
        self.assertEqual("5486c94c1b659dfeb026dcbe6abf91978655c535", previous_promotion["reviewed_candidate_head_sha"])
        self.assertEqual("4234965c8da20dbb4ef0a7128614a5070244619a", previous_promotion["candidate_merge_sha"])
        self.assertEqual("f071d9edae90e3d5ae2030a98f79d9d1698aa68bf90ed9ce474a4f9120f82836", previous_promotion["reviewed_candidate_archive_sha256"])
        self.assertEqual("973503deee2ec86f182cd7239ffe4360cd5abe92d22eee3148f472d66d11f3b4", previous_promotion["approved_current_snapshot_sha256"])
        self.assertEqual("STARTED", phase8["proof_execution"])
        self.assertEqual("INCOMPLETE / COVERAGE-INCOMPLETE", phase8["proof_result"])
        self.assertEqual("NOT CERTIFIED", phase8["proof_certification"])
        self.assertEqual("NOT STARTED / NOT AUTHORISED", phase8["phase9_vertical_slices"])
        self.assertEqual([], phase8["application_source_paths_created"])
        self.assertEqual("NONE", rule["runtime_change"])
        self.assertEqual("NONE", rule["dependency_change"])
        self.assertEqual("NONE", rule["migration_change"])
        predecessor_header = re.search(
            r"(?m)^- \*\*Design predecessor:\*\* `([^`]+)`",
            self.candidate,
        )
        predecessor_history = re.search(
            r"approved-current v0\.1\.2 status snapshot (?:remains at|at) `([^`]+)`",
            self.candidate,
        )
        self.assertIsNotNone(predecessor_header)
        self.assertIsNotNone(predecessor_history)
        stated_predecessors = (
            predecessor_header.group(1),
            predecessor_history.group(1),
        )
        manifest_predecessor = rule["predecessor_archive_path"]
        self.assertEqual(
            "docs/00_platform/archive/FP-001_TRACER_BULLET_CONTRACT_WORKING_APPROVED_CURRENT_v0.1.2.md",
            manifest_predecessor,
        )
        manifest_predecessor_path = DOCS / "history/platform/archive" / Path(manifest_predecessor).name
        self.assertTrue(manifest_predecessor_path.is_file())
        for stated_path in stated_predecessors:
            resolved_path = DOCS / "history/platform/archive" / Path(stated_path).name
            self.assertEqual(manifest_predecessor_path, resolved_path)
            self.assertTrue(resolved_path.is_file())
            self.assertEqual(APPROVED_ARCHIVE.read_bytes(), resolved_path.read_bytes())
            self.assertEqual(
                hashlib.sha256(resolved_path.read_bytes()).hexdigest(),
                rule["predecessor_sha256"],
            )
        self.assertEqual(
            "docs/00_platform/archive/FP-001_TRACER_BULLET_CONTRACT_WORKING_APPROVED_CURRENT_v0.1.2.md",
            manifest_predecessor,
        )
        self.assertNotIn(
            CANDIDATE.as_posix().replace(str(ROOT) + "/", ""),
            {entry["repository_path"] for entry in self.manifest["governing_documents"]},
        )
        readme = historical_platform_readme_text(ROOT)
        self.assertIn(CANDIDATE.name, readme)
        self.assertNotIn("FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.2.md` — TB-001 proof-contract successor/task definition", readme)
        self.assertIn(CANDIDATE.name, self.open_work)
        self.assertIn(
            phase8["candidate_path"],
            self.manifest["integrity_rules"]["graph_rules"]["navigation_document_paths"],
        )
        self.assertIn("CONTRACT/DESIGN REVIEW: COMPLETE / PASS", self.candidate)
        self.assertIn("CURRENT / APPROVED FOR BOUNDED PHASE 8 PROOF EXECUTION", self.candidate)
        self.assertIn("INCOMPLETE / COVERAGE-INCOMPLETE", self.candidate)
        self.assertIn("PROOF CERTIFICATION: NOT CERTIFIED", self.candidate)
        self.assertIn("PHASE 9 / VERTICAL SLICES: NOT STARTED / NOT AUTHORISED", self.candidate)
        for path in (
            "working/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.3.md",
            "CURRENT / APPROVED FOR BOUNDED PHASE 8 PROOF EXECUTION",
            "WELL-49: BLOCKED / WAITING ON WELL-61",
        ):
            self.assertIn(path, self.open_work)
        active_route = readme.split("## Active Working Artifacts", 1)[1].split("\n## ", 1)[0]
        self.assertIn("working/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.3.md", active_route)
        self.assertNotIn("working/FP-001_TRACER_BULLET_CONTRACT_WORKING_v0.1.2.md", active_route)
        candidate_body = PROMOTED_CANDIDATE_ARCHIVE.read_text(encoding="utf-8")
        candidate_contract = candidate_body.split("## 2. Outcome and proof claim", 1)[1].split("## 11. Version, history and lifecycle", 1)[0]
        promoted_contract = self.candidate.split("## 2. Outcome and proof claim", 1)[1].split("## 11. Version, history and lifecycle", 1)[0]
        self.assertEqual(candidate_contract, promoted_contract)

    def test_status_promotion_keeps_model_b_boundaries_and_changes_no_runtime(self) -> None:
        for clause in (
            "A valid registration or resend commits its source transition, exact Communications `MessageIntent`, required source/provenance references, and required WELL-46 protected-delivery envelope in the same authoritative PostgreSQL transaction.",
            "No Communications Oban job is required at registration/resend acceptance.",
            "The committed eligible open MessageIntent remains durably discoverable through the Communications owner interface when no job exists.",
            "P8-10 discovers eligible committed open MessageIntents, recovers backlog after restart, and idempotently schedules their real Communications executor",
            "DeliveryAttempt admission commits before provider I/O; no authoritative transaction spans provider I/O.",
            "P8-05 proves MessageIntent/envelope atomicity with source acceptance",
            "P8-10 proves restart/backlog discovery",
        ):
            with self.subTest(clause=clause):
                self.assertIn(clause.casefold(), self.candidate.casefold())
        rule = self.manifest["integrity_rules"]["well60_communications_handoff_candidate"]
        self.assertEqual("NONE", rule["runtime_change"])
        self.assertEqual("NONE", rule["dependency_change"])
        self.assertEqual("NONE", rule["migration_change"])
        self.assertEqual([], rule["application_source_paths_created"])
        self.assertIn("WELL-49 remains BLOCKED / WAITING ON WELL-61", self.open_work)
        self.assertIn("WELL-60: COMPLETE / PR #165 RESULTING-MAIN VERIFIED", self.open_work)

    def test_identity_source_contract_preserves_reviewed_v020_citation(self) -> None:
        _, source_heading, source_contents = self.candidate.partition(
            "Current FP-001 source contracts:"
        )
        self.assertTrue(source_heading)
        cited_sources = source_contents.split("\n## ", 1)[0]
        identity_source = (
            "docs/delivery/jit/identity/"
            "FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.2.0.md"
        )
        identity_citations = re.findall(
            r"`([^`]*FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v[^`]+\.md)`",
            cited_sources,
        )
        self.assertEqual([identity_source], identity_citations)
        self.assertTrue((ROOT / identity_source).is_file())

    def test_no_lost_handoff_and_executor_boundary_are_explicit(self) -> None:
        candidate_clauses = (
            "No Communications Oban job is required at registration/resend acceptance",
            "Failure to create a later P8-10 Communications job never rolls back",
            "durably discoverable through the Communications owner interface when no job exists",
            "recovers backlog after restart",
            "idempotently schedules",
            "concurrent discoverers/executors cannot multiply",
            "Oban uniqueness is not business idempotency",
            "only `MessageIntent.id`",
            "verification bearer, protected capability, destination, rendered body, Account data, Identity payload",
            "exact Content & Media content/locale eligibility and binding",
            "protected capability authority before DeliveryAttempt admission",
            "Failure before enqueue, after enqueue, or during execution",
            "DeliveryAttempt admission commits before provider I/O",
        )
        for clause in candidate_clauses:
            with self.subTest(candidate_clause=clause):
                self.assertIn(clause.casefold(), self.candidate.casefold())
        for clause in (
            "A Communications Oban job is not required to exist or be inserted by registration.",
            "Failure to create a future P8-10 Communications job cannot roll back an otherwise valid committed registration.",
            "remains durable and discoverable even when no Communications job exists",
            "restart/backlog discovery",
            "recreation of missing, deleted, or failed executor work",
            "duplicate scheduling convergence",
            "concurrent discoverer/executor safety",
            "AshOban job uniqueness is not business idempotency",
            "only Communications business reference in Oban arguments is `MessageIntent.id`",
            "Bearer, protected capability, destination, rendered body, Account data, Identity payload, and other protected source data remain absent from arguments",
            "exact content/locale eligibility and binding",
            "protected capability authority before `DeliveryAttempt` admission",
            "failures before enqueue, after enqueue, and during execution",
            "The admission transaction commits before provider I/O",
            "If later P8-10 scheduling fails, the valid resend remains committed",
        ):
            with self.subTest(jit_clause=clause):
                self.assertIn(clause.casefold(), self.jit.casefold())

    def test_states_resource_boundary_and_audit_atomicity_are_preserved(self) -> None:
        for clause in (
            "Communications physical Resources are exactly `MessageIntent` and `DeliveryAttempt`",
            "`open`, `held`, `reconciliation_required` and `closed`",
            "`queued`, `scheduled`, `ready`, or `preflighted`",
            "no placeholder/no-op action, inert worker, generic dispatcher",
            "initial Audit E2 schedule atomicity",
        ):
            with self.subTest(clause=clause):
                self.assertIn(clause.casefold(), self.candidate.casefold())
        self.assertIn("source transition, `EvidenceObligation` and initial durable scheduling share the required acceptance boundary", self.candidate)
        self.assertIn("rollback between Communications and Audit schedules", self.jit)
        self.assertIn("Audit E2 failure continues to roll back initial registration", self.jit)
        self.assertIn("P8-05 executes no Communications worker/provider", self.candidate)

    def test_p8_05_proof_does_not_depend_on_p8_10_executor(self) -> None:
        self.assertIn("P8-05 can complete this acceptance and discoverability proof without the P8-10 executor existing", self.candidate)
        self.assertIn("P8-05 is not blocked on P8-10 executor implementation", self.jit)
        self.assertIn("P8-10/WELL-10 follows the completed P8-05 intent contract", self.jit)
        self.assertIn("Candidate contract:", self.open_work)
        self.assertIn("WELL-49 remains BLOCKED until WELL-60 and WELL-61 clear", self.open_work)


if __name__ == "__main__":
    unittest.main()
