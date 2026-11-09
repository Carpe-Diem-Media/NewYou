from __future__ import annotations

import hashlib
import json
import re
import subprocess
import unittest
from pathlib import Path

from foundation_test_support import (
    FOUNDATION_WORKFLOW_BASELINE_SHA256,
    WELL38_BASE_SHA,
    git_show_text_at_revision,
    git_snapshot_bytes,
    historical_platform_readme_path,
    historical_platform_readme_text,
)


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs" / "00_platform"
CONTRACT = DOCS / "archive" / "HARDEN-02_CONTRACT_WORKING_v0.4.0.md"
CONTRACT_CURRENT = DOCS / "archive" / "HARDEN-02_CONTRACT_WORKING_v0.5.8.md"
CONTRACT_STATUS_PREDECESSOR = DOCS / "archive" / "HARDEN-02_CONTRACT_WORKING_v0.4.3.md"
CONTRACT_CURRENT_PREDECESSOR = DOCS / "archive" / "HARDEN-02_CONTRACT_WORKING_v0.5.6.md"
CONTRACT_V0_4_1_ARCHIVE = DOCS / "archive" / "HARDEN-02_CONTRACT_WORKING_v0.4.1.md"
CONTRACT_V0_3_ARCHIVE = DOCS / "archive" / "HARDEN-02_CONTRACT_WORKING_v0.3.0.md"
CONTRACT_PREDECESSOR = DOCS / "archive" / "HARDEN-02_CONTRACT_WORKING_v0.2.0.md"
CONTRACT_OLDER_PREDECESSOR = DOCS / "archive" / "HARDEN-02_CONTRACT_WORKING_v0.1.0.md"
OPEN_WORK = DOCS / "archive" / "02_OPEN_WORK_v1.2.43.md"
OPEN_WORK_V1_2_44_ARCHIVE = DOCS / "archive" / "02_OPEN_WORK_v1.2.44.md"
OPEN_WORK_V1_2_46_ARCHIVE = DOCS / "archive" / "02_OPEN_WORK_v1.2.46.md"
OPEN_WORK_V1_2_47_ARCHIVE = DOCS / "archive" / "02_OPEN_WORK_v1.2.47.md"
OPEN_WORK_V1_2_48_ARCHIVE = DOCS / "archive" / "02_OPEN_WORK_v1.2.48.md"
OPEN_WORK_PREDECESSOR = DOCS / "archive" / "02_OPEN_WORK_v1.2.42.md"
OPEN_WORK_OLDER_PREDECESSOR = DOCS / "archive" / "02_OPEN_WORK_v1.2.41.md"
README = historical_platform_readme_path(ROOT)
MANIFEST = DOCS / "CURRENT_AUTHORITY_MANIFEST_v1.0.0.json"
BASELINE_MAIN_SHA = "3566f1353ef34af58773aa13c6f5bd61d2613d96"


def _baseline_text(path: Path) -> str:
    return git_show_text_at_revision(ROOT, BASELINE_MAIN_SHA, path)

EXPECTED_BASE_SHA = "6f9ce049616881805b1086d19ce747358de3c067"
EXPECTED_RECOVERY_PR_NUMBER = 40
EXPECTED_CONTRACT_V0_3_SHA256 = "d24a1b460c9e10ae7fa3a50fdf260613e8b5ea72edf8d01eb2577de1b3d9eda2"
EXPECTED_CONTRACT_V0_2_SHA256 = "9fab2f79b1e5720378a6852bcda9c81aafe8564cd0866a0ea38c1242e7b34f5f"
EXPECTED_CONTRACT_V0_4_SHA256 = "59d2da53b36e146d7f1e9928c5572e9c9a5035b5f186b748ea6aea4cdbc7be65"
EXPECTED_CONTRACT_V0_4_1_SHA256 = "7ce62a580754b6a56644c2921ae82cd9ebcd56f3a69b7b664f0701fd9c079bca"
EXPECTED_OPEN_WORK_V1_2_42_SHA256 = "2f9baad6ef314b23b53f9c0daa79976347bfbc5b937d68f7937b3149415e55a3"
EXPECTED_OPEN_WORK_V1_2_41_SHA256 = "85dd9946cf5684b0907f49e973ef75b59541c0f265ac46d44465d1527535da62"
EXPECTED_OPEN_WORK_V1_2_44_SHA256 = "a296edf5f9c4bccd48b3b3057dba96b0a70ca822c1f8a162f9b44a985d328c1e"
EXPECTED_OPEN_WORK_V1_2_46_SHA256 = "d19ba98b486478ff8fea36b74a72b4102e8fe192a797af919318a1fc31c8c870"
EXPECTED_OPEN_WORK_V1_2_47_SHA256 = "71d6f4641cdc70aaa57c8630887d4b24d1a971d34e390c607dda7dbcc8c05118"
EXPECTED_OPEN_WORK_V1_2_48_SHA256 = "270172784629197f2bb6faa60dbe6d4184bd9d04d878876f6877c98390fd8d17"
EXPECTED_ATLAS_V0_2_SHA256 = "c122c0f4a903c9679529e0e65a794999dcdaf957a66fcff00df990a0644bbb7f"

PROTECTED_UPSTREAM_HASHES = {
    "docs/00_platform/archive/PROJECT_NORTH_STAR_AND_MVP_v1.2.1.md": "5bf5a8582d5ada7c7c39d937a6730e29d219c11b688a31fb763e439047d89a20",
    "docs/00_platform/archive/00_PLATFORM_v1.3.0.md": "4694f841cfa92c2a802b50a1db7dcf3a5043e8a62a2a5250d6dfe819e5388445",
    "docs/00_platform/archive/01_DECISIONS_v1.3.0.md": "43ecce4423cd90afbf97fa3c447a54a591e0d34acb7e6a5250a8b91c7b650a96",
    "docs/00_platform/archive/03_ARCHITECTURE_v1.1.0.md": "d44615f0db3f5f0b38bb68a2904db6066d23e1f82c55da134745c4f6d70b6852",
    "docs/00_platform/archive/04_DOMAIN_MAP_v1.1.0.md": "2c66142e624ccd626727ae36511121fcb64333ca774986ab97ce31eebe5c5ef2",
    "docs/00_platform/archive/05_ROADMAP_v1.1.0.md": "eaeaf6031e47653777caf5885ad9eb0ceba58783c99d7d6d255acfbca53fa613",
    "docs/00_platform/archive/PLATFORM_OPERATING_MODEL_v1.0.0.md": "884a7231a86b438a220f057e03ba9c06357820b43629e018d50c92cc773b2811",
    "docs/00_platform/archive/FRONTEND_EXPERIENCE_SYSTEM_v1.0.0.md": "caadd2dfc3c7ed872fda5806efdba467d753b9662e1ff47af16b6303d90b9fa3",
    "docs/00_platform/archive/FP-001_FEATURE_PACK_SKELETON_WORKING_v0.1.0.md": "8719971d92f70fc2a485e5fb9b23b9d2bc897313bc697025b91bd86802ee23be",
    "docs/00_platform/archive/FP-001_IDENTITY_ACCESS_JIT_DOMAIN_DOSSIER_WORKING_v0.1.0.md": "f96dcbbf26cdee35ac9aded273dbfc33346bb559fd88525f41112e85c23d798b",
    "docs/00_platform/archive/02_OPEN_WORK_v1.2.39.md": "5af9c6965d214bb0dd46cd3215a2e23ed1a17d546ef53ccd4de31be346d11e21",
    "docs/00_platform/archive/02_OPEN_WORK_v1.2.40.md": "e53d416efe2b859053e4d2167b36065383f4f67603db56d833f20247d5120b3e",
    "docs/00_platform/archive/HARDEN-02_CONTRACT_WORKING_v0.1.0.md": "71615d3363a91a7e6002d907c6edd474fbd87f77bdfc6a38f5b11afd240a5626",
    "docs/00_platform/archive/DELIVERY_ATLAS_WORKING_v0.2.0.md": EXPECTED_ATLAS_V0_2_SHA256,
}

PROHIBITED_PRESENT_PATHS = (
    "docs/00_platform/02_OPEN_WORK_v1.2.39.md",
    "docs/00_platform/02_OPEN_WORK_v1.2.40.md",
    "docs/00_platform/02_OPEN_WORK_v1.2.41.md",
    "docs/00_platform/02_OPEN_WORK_v1.2.42.md",
    "docs/00_platform/working/HARDEN-02_CONTRACT_WORKING_v0.1.0.md",
    "docs/00_platform/working/HARDEN-02_CONTRACT_WORKING_v0.2.0.md",
    "docs/00_platform/working/HARDEN-02_CONTRACT_WORKING_v0.3.0.md",
    "docs/00_platform/ENGINEERING_STANDARDS_v1.0.0.md",
    "docs/00_platform/reference/ENGINEERING_STANDARDS_WORKING_v0.1.0.md",
    "docs/00_platform/working/ENGINEERING_STANDARDS_WORKING_v0.1.0.md",
    "mix.exs",
)

EXPECTED_RECOVERY_STATE = {
    "baseline_main_sha": EXPECTED_BASE_SHA,
    "current_stage": "HARDEN-02_CONTRACT_RECOVERY_REQUIRED",
    "next_stage": "HARDEN-02_CONTRACT_RECOVERY_REQUIRED",
    "contract_version": "0.4.0",
    "contract_status": "OPEN / PENDING INDEPENDENT PRE-MERGE CERTIFICATION",
    "pr_39_merged": True,
    "v0_3_0_retroactive_certification": "NOT SATISFIED",
    "pre_merge_certification": "PENDING",
    "exact_head_ci": "PENDING",
    "certified_head_merge": "PENDING",
    "post_merge_certification": "PENDING",
    "harden_02_execution": "NOT STARTED / NOT AUTHORISED",
    "harden_02_scope": "PHASE-7 GOVERNANCE / STRUCTURAL HARDENING ONLY",
    "store_cer": "EXCLUDED",
    "completed_milestones": [
        "TARGETED PRODUCT AMENDMENT PROGRAMME",
        "FP-001 PHASE 7A",
        "IDENTITY & ACCESS JIT DOMAIN DOSSIER",
    ],
    "engineering_standards_authority_promotion": "DOWNSTREAM / NOT STARTED",
    "fp001_reconciliation": "REQUIRED / DOWNSTREAM / NOT PERFORMED",
    "communications": "REQUIRED / NOT_STARTED",
    "conditional_dossiers": {
        "privacy_consent": "CONDITIONAL / PENDING EXPLICIT ADJUDICATION",
        "content_media": "CONDITIONAL / PENDING EXPLICIT ADJUDICATION",
        "audit_evidence": "CONDITIONAL / PENDING EXPLICIT ADJUDICATION",
        "analytics": "NOT REQUIRED",
    },
    "phase_7c": "BLOCKED / NOT_STARTED",
    "proof_classification": "NOT FINALISED",
    "application_implementation": "BLOCKED",
    "pr_38": "STALE / BLOCKED / NOT AUTHORITY",
    "downstream_route": [
        "CERTIFIED HARDEN-02 EXECUTION",
        "ENGINEERING_STANDARDS_AUTHORITY_PROMOTION_REQUIRED",
        "CERTIFIED ENGINEERING STANDARDS AUTHORITY PROMOTION",
        "FP001_RECONCILIATION_REQUIRED",
        "COMMUNICATIONS JIT DOMAIN DOSSIER",
        "REMAINING REQUIRED / CONDITIONAL PHASE 7B",
        "PHASE 7C",
        "PROOF CLASSIFICATION",
        "PHASE 8 ONLY AFTER DEVELOPMENT ENTRY HARD STOP PASSES",
    ],
}


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _section(text: str, heading: str, next_heading: str) -> str:
    start = text.index(heading)
    end = text.index(next_heading, start)
    return text[start:end]


def _reject_duplicate_json_keys(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise AssertionError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _marked_json(text: str, start_marker: str, end_marker: str) -> dict[str, object]:
    if text.count(start_marker) != 1 or text.count(end_marker) != 1:
        raise AssertionError("expected one marked JSON record")
    start = text.index(start_marker) + len(start_marker)
    end = text.index(end_marker, start)
    region = text[start:end]
    match = re.search(r"```json\s*(\{.*?\})\s*```", region, re.DOTALL)
    if match is None:
        raise AssertionError("marked JSON record is missing")
    return json.loads(match.group(1), object_pairs_hook=_reject_duplicate_json_keys)


def _route_declaration(text: str, label: str) -> str:
    declarations = re.findall(
        rf"^\s*(?:-\s*)?{re.escape(label)}:\s*(.+)$",
        text,
        re.MULTILINE,
    )
    if len(declarations) != 1:
        raise AssertionError(f"expected one {label} declaration, found {len(declarations)}")
    return declarations[0].strip()


def _assert_no_current_execution_authority(text: str) -> None:
    if re.search(
        r"^\s*(?:-\s*)?HARDEN-02 EXECUTION:\s*NEXT\s*/\s*AUTHORISED\s*$",
        text,
        re.MULTILINE,
    ):
        raise AssertionError("recovery text grants execution authority")
    if re.search(r"^HARDEN-02_EXECUTION_REQUIRED\s*$", text, re.MULTILINE):
        raise AssertionError("legacy execution route appears as current")


def _valid_sha(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def _valid_pr_record_url(value: object, expected_pr_number: int) -> bool:
    if not isinstance(value, str):
        return False
    match = re.fullmatch(
        r"https://github\.com/JCSchoeman96/NewYou/pull/(\d+)#(?:pullrequestreview|issuecomment)-\d+",
        value,
    )
    return match is not None and int(match.group(1)) == expected_pr_number


def _valid_actions_url(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(
        r"https://github\.com/JCSchoeman96/NewYou/actions/runs/\d+",
        value,
    ) is not None


def _record_has_fields(record: object, required_fields: object) -> bool:
    return (
        isinstance(record, dict)
        and isinstance(required_fields, list)
        and all(isinstance(field, str) and field in record for field in required_fields)
    )


def _post_merge_attestation_valid(
    post_cert: dict[str, object],
    *,
    main_sha: str,
    pr_author: str,
    candidate_author: str,
    expected_pr_number: int,
) -> bool:
    actor = post_cert.get("independent_review_actor")
    poster = post_cert.get("attestation_poster_github_identity")
    if post_cert.get("outcome") != "PASS":
        return False
    if post_cert.get("resulting_main_sha") != main_sha:
        return False
    if not isinstance(actor, str) or not actor.strip():
        return False
    if not isinstance(poster, str) or not poster.strip():
        return False
    if post_cert.get("poster_equals_pr_author_disclosed") is not True:
        return False
    poster_equals = post_cert.get("poster_equals_pr_author")
    if not isinstance(poster_equals, bool):
        return False
    if poster_equals and poster.casefold() != pr_author.casefold():
        return False
    if not poster_equals and poster.casefold() == pr_author.casefold():
        return False
    if post_cert.get("review_actor_authored_or_modified_candidate") is not False:
        return False
    if post_cert.get("substantive_reviewer_is_review_actor_not_poster") is not True:
        return False
    if actor.casefold() == candidate_author.casefold():
        return False
    return _valid_pr_record_url(post_cert.get("record_url"), expected_pr_number)


def _review_attestation_valid(
    review: dict[str, object],
    *,
    expected_head_sha: str,
    pr_author: str,
    candidate_author: str,
    expected_pr_number: int,
) -> bool:
    actor = review.get("independent_review_actor")
    poster = review.get("attestation_poster_github_identity")
    if review.get("outcome") != "PASS":
        return False
    if review.get("reviewed_head_sha") != expected_head_sha:
        return False
    if review.get("reviewed_head_is_certified_head") is not True:
        return False
    if not isinstance(actor, str) or not actor.strip():
        return False
    if not isinstance(poster, str) or not poster.strip():
        return False
    if review.get("poster_equals_pr_author_disclosed") is not True:
        return False
    poster_equals = review.get("poster_equals_pr_author")
    if not isinstance(poster_equals, bool):
        return False
    if poster_equals and poster.casefold() != pr_author.casefold():
        return False
    if not poster_equals and poster.casefold() == pr_author.casefold():
        return False
    if review.get("review_actor_authored_or_modified_candidate") is not False:
        return False
    if review.get("substantive_reviewer_is_review_actor_not_poster") is not True:
        return False
    if actor.casefold() == candidate_author.casefold():
        return False
    if not _valid_pr_record_url(review.get("record_url"), expected_pr_number):
        return False
    return True


def _pre_merge_attestation_ci_binding_valid(
    review: dict[str, object],
    pre_ci: dict[str, object],
    *,
    expected_head_sha: str,
) -> bool:
    ci_head = review.get("ci_head_sha")
    ci_workflow = review.get("ci_workflow")
    ci_conclusion = review.get("ci_conclusion")
    ci_run_url = review.get("ci_run_url")
    if not _valid_sha(expected_head_sha):
        return False
    if ci_head != expected_head_sha:
        return False
    if pre_ci.get("head_sha") != expected_head_sha:
        return False
    if ci_head != pre_ci.get("head_sha"):
        return False
    if ci_workflow != "Foundation Integrity":
        return False
    if ci_workflow != pre_ci.get("workflow"):
        return False
    if ci_conclusion != "PASS":
        return False
    if ci_conclusion != pre_ci.get("conclusion"):
        return False
    if ci_run_url != pre_ci.get("run_url"):
        return False
    return _valid_actions_url(ci_run_url)


def _execution_entry_passes(
    expected_pr_number: int,
    expected_head_sha: str,
    pr_author: str,
    candidate_author: str,
    evidence: object,
    evidence_spec: dict[str, object],
) -> bool:
    if (
        not isinstance(expected_pr_number, int)
        or isinstance(expected_pr_number, bool)
        or expected_pr_number <= 0
        or not _valid_sha(expected_head_sha)
        or not isinstance(pr_author, str)
        or not pr_author
        or not isinstance(candidate_author, str)
        or not candidate_author
        or not isinstance(evidence, dict)
    ):
        return False

    keys = (
        "pre_merge_review",
        "pre_merge_ci",
        "merge",
        "post_merge_ci",
        "post_merge_certification",
    )
    if not all(_record_has_fields(evidence.get(key), evidence_spec.get(key)) for key in keys):
        return False

    review = evidence["pre_merge_review"]
    pre_ci = evidence["pre_merge_ci"]
    merge = evidence["merge"]
    post_ci = evidence["post_merge_ci"]
    post_cert = evidence["post_merge_certification"]
    if not all(isinstance(record, dict) for record in (review, pre_ci, merge, post_ci, post_cert)):
        return False

    main_sha = merge["resulting_main_sha"]
    return all(
        (
            _review_attestation_valid(
                review,
                expected_head_sha=expected_head_sha,
                pr_author=pr_author,
                candidate_author=candidate_author,
                expected_pr_number=expected_pr_number,
            ),
            _pre_merge_attestation_ci_binding_valid(
                review,
                pre_ci,
                expected_head_sha=expected_head_sha,
            ),
            pre_ci["head_sha"] == expected_head_sha,
            pre_ci["conclusion"] == "PASS",
            pre_ci["workflow"] == "Foundation Integrity",
            _valid_actions_url(pre_ci["run_url"]),
            merge["certified_head_sha"] == expected_head_sha,
            merge["head_sha_verified_before_merge"] == expected_head_sha,
            merge["merged_head_sha"] == expected_head_sha,
            _valid_sha(main_sha),
            post_ci["head_sha"] == main_sha,
            post_ci["conclusion"] == "PASS",
            post_ci["workflow"] == "Foundation Integrity",
            _valid_actions_url(post_ci["run_url"]),
            post_cert["resulting_main_sha"] == main_sha,
            post_cert["certified_head_sha"] == expected_head_sha,
            post_cert["ci_head_sha"] == main_sha,
            post_cert["ci_conclusion"] == "PASS",
            post_cert["ci_run_url"] == post_ci["run_url"],
            post_cert["outcome"] == "PASS",
            _post_merge_attestation_valid(
                post_cert,
                main_sha=main_sha,
                pr_author=pr_author,
                candidate_author=candidate_author,
                expected_pr_number=expected_pr_number,
            ),
        )
    )


class Harden02ContractRecoveryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = CONTRACT.read_text(encoding="utf-8")
        cls.current_contract = CONTRACT_CURRENT.read_text(encoding="utf-8")
        cls.contract_current_predecessor = CONTRACT_CURRENT_PREDECESSOR.read_text(encoding="utf-8")
        cls.contract_v0_4_1 = CONTRACT_V0_4_1_ARCHIVE.read_text(encoding="utf-8")
        cls.contract_status_predecessor = CONTRACT_STATUS_PREDECESSOR.read_text(encoding="utf-8")
        cls.contract_v0_3 = CONTRACT_V0_3_ARCHIVE.read_text(encoding="utf-8")
        cls.contract_predecessor = CONTRACT_PREDECESSOR.read_text(encoding="utf-8")
        cls.open_work = OPEN_WORK.read_text(encoding="utf-8")
        cls.readme = _baseline_text(README)
        cls.manifest = json.loads(_baseline_text(MANIFEST))
        open_work_entry = next(
            entry for entry in cls.manifest["governing_documents"]
            if entry["document_id"] == "OPEN_WORK"
        )
        cls.current_open_work_path = DOCS / "archive" / "02_OPEN_WORK_v1.2.64.md"
        cls.current_open_work = cls.current_open_work_path.read_text(encoding="utf-8")
        cls.current_lifecycle_state = _marked_json(
            cls.current_open_work,
            "<!-- HARDEN_02_LIFECYCLE_STATE_START -->",
            "<!-- HARDEN_02_LIFECYCLE_STATE_END -->",
        )
        cls.recovery_state = _marked_json(
            cls.open_work,
            "<!-- HARDEN_02_RECOVERY_STATE_START -->",
            "<!-- HARDEN_02_RECOVERY_STATE_END -->",
        )
        cls.evidence_spec = _marked_json(
            cls.contract,
            "<!-- HARDEN_02_CERTIFICATION_EVIDENCE_SPEC_START -->",
            "<!-- HARDEN_02_CERTIFICATION_EVIDENCE_SPEC_END -->",
        )

    def _recovery_entry_passes(
        self,
        expected_head_sha: str,
        evidence: object,
        pr_author: str = "JCSchoeman96",
        candidate_author: str = "JCSchoeman96",
    ) -> bool:
        return _execution_entry_passes(
            EXPECTED_RECOVERY_PR_NUMBER,
            expected_head_sha,
            pr_author,
            candidate_author,
            evidence,
            self.evidence_spec,
        )

    def test_certified_v0_4_contract_is_preserved_as_historical_artifact(self):
        self.assertTrue(CONTRACT.is_file())
        self.assertIn("Plan / contract version:** `v0.4.0`", self.contract)
        self.assertIn("OPEN / PENDING INDEPENDENT PRE-MERGE CERTIFICATION", self.contract)
        self.assertEqual(EXPECTED_CONTRACT_V0_4_SHA256, _sha256(CONTRACT))
        self.assertIn(f"Re-baseline main SHA:** `{EXPECTED_BASE_SHA}`", self.contract)
        self.assertEqual(EXPECTED_BASE_SHA, self.recovery_state["baseline_main_sha"])
        self.assertIn("Review actor versus attestation poster", self.contract)

    def test_v0_4_1_and_open_work_v1_2_44_are_archived_byte_identically(self):
        self.assertEqual(EXPECTED_CONTRACT_V0_4_1_SHA256, _sha256(CONTRACT_V0_4_1_ARCHIVE))
        self.assertEqual(EXPECTED_OPEN_WORK_V1_2_44_SHA256, _sha256(OPEN_WORK_V1_2_44_ARCHIVE))
        self.assertFalse((DOCS / "working" / "HARDEN-02_CONTRACT_WORKING_v0.4.1.md").exists())
        self.assertFalse((DOCS / "02_OPEN_WORK_v1.2.44.md").exists())

    def test_v0_5_7_updates_current_route_without_changing_contract_semantics(self):
        self.assertEqual(
            "b7384ed3f3b159c69d9644977d4ff5d9df6fa1a0eacf453c50a08f7fb9ef6e1f",
            _sha256(CONTRACT_CURRENT_PREDECESSOR),
        )
        self.assertIn("Plan / contract version:** `v0.5.8`", self.current_contract)
        self.assertIn("original v0.4.0 semantics are certified", self.current_contract)
        self.assertIn("Execution-start baseline main SHA", self.current_contract)
        self.assertIn("HARDEN-02 execution **COMPLETE / CERTIFIED**", self.current_contract)
        self.assertIn("PASS WITH NON-BLOCKING CORRECTIONS", self.current_contract)
        current_status = self.current_contract.split("### 11.5 PR #40 lifecycle evidence and current state", 1)[1]
        self.assertIn("v0.5.5", self.current_contract)
        self.assertNotIn("post-merge attestation remain pending", current_status)
        self.assertNotIn("contract lifecycle remains open", current_status)
        for start, end in (
            ("## 1. Objective", "## 2. Authority basis"),
            ("## 3. Accepted human scope decisions", "## 4. In scope"),
            ("## 4. In scope", "## 5. Explicitly out of scope"),
            ("## 5. Explicitly out of scope", "## 6. Reuse classification"),
            ("## 13. Failure / recovery / STOP criteria", "## 14. Domain-authority boundaries"),
            ("### Execution stage (later, separately authorised)", "## 18. Downstream consequence"),
            ("## 19. Explicit exclusion confirmations", "## 20. Contract-stage STOP"),
        ):
            self.assertEqual(
                _section(self.contract_current_predecessor, start, end),
                _section(self.current_contract, start, end),
                start,
            )
        current_i05 = _section(
            self.current_contract,
            "## 8. Current structural invariant suite",
            "## 9. Stale-state / restart pressure tests",
        )
        predecessor_i05 = _section(
            self.contract_current_predecessor,
            "## 8. Current structural invariant suite",
            "## 9. Stale-state / restart pressure tests",
        )
        current_i05 = current_i05.replace(
            "The previous Open Work v1.2.61 status left Privacy & Consent, Content & Media, and Audit & Evidence pending explicit adjudication. Open Work v1.2.64 records the Phase 7B Audit dossier work start under dedicated execution tracker #116, linked to adjudication #114 and programme router #111. Privacy & Consent, Content & Media and Analytics remain NOT_REQUIRED. Audit is REQUIRED / IN PROGRESS / NOT COMPLETE / CERTIFICATION PENDING; candidate v0.1.0 is authored and review-ready in PR #118 but remains NOT CERTIFIED / NOT CURRENT, with fresh independent exact-head review/certification next. This current-status route does not alter any source Domain ownership.",
            "The previous Open Work v1.2.61 status left Privacy & Consent, Content & Media, and Audit & Evidence pending explicit adjudication. Open Work v1.2.62 and the bounded tracker #114 now record Privacy & Consent and Content & Media as NOT_REQUIRED, Audit & Evidence as REQUIRED / NEXT / NOT_STARTED, and Analytics as NOT_REQUIRED. This current-status route does not alter any source Domain ownership.",
            1,
        )
        self.assertEqual(predecessor_i05, current_i05)

    def test_contract_stage_stop_tracks_completed_lifecycle_without_weakening_gates(self):
        stop_heading = "## 20. Contract-stage STOP"
        predecessor_stop = self.contract_v0_4_1[self.contract_v0_4_1.index(stop_heading):]
        current_stop = self.current_contract[self.current_contract.index(stop_heading):]
        stable_boundary = predecessor_stop.split("\n\nDo not:", 1)[0]
        current_stop_folded = current_stop.casefold()

        self.assertTrue(current_stop.startswith(stable_boundary))
        self.assertNotIn("missing post-merge", current_stop_folded)
        self.assertNotIn("missing lifecycle records", current_stop_folded)
        self.assertNotIn("not started / not authorised", current_stop_folded)
        self.assertNotIn("do not execute harden-02", current_stop_folded)
        self.assertNotIn("- execute harden-02;", current_stop_folded)
        self.assertIn("the original v0.4.0 contract lifecycle remains complete / certified", current_stop_folded)
        self.assertIn("do not reopen it", current_stop_folded)
        self.assertIn("this status-sync artifact itself does not execute harden-02", current_stop_folded)
        self.assertIn("harden-02 execution remains complete / certified under this status successor", current_stop_folded)
        self.assertIn("full pr #59 exact-head", current_stop_folded)
        self.assertIn("current-main revalidation", current_stop_folded)
        self.assertIn("engineering standards authority promotion", current_stop_folded)
        self.assertIn("fp-001 reconciliation", current_stop_folded)
        self.assertIn("communications", current_stop_folded)
        self.assertIn("phase 7c", current_stop_folded)
        self.assertIn("proof classification", current_stop_folded)
        self.assertIn("phase 8", current_stop_folded)
        self.assertIn("no application implementation is authorised", current_stop_folded)
        self.assertIn("this lifecycle-status synchronization does not authorise application implementation", current_stop_folded)
        downstream_route = current_stop_folded.split("preserve the fail-closed downstream gates:", 1)[1]
        ordered_gates = (
            "engineering standards authority promotion",
            "fp-001 reconciliation",
            "communications",
            "phase 7c",
            "proof classification",
            "phase 8",
        )
        route_positions = [downstream_route.index(gate) for gate in ordered_gates]
        self.assertEqual(sorted(route_positions), route_positions)
        self.assertNotIn(
            "harden-02 execution remains not started / not authorised throughout this recovery pr",
            self.current_contract.casefold(),
        )
        self.assertIn("under that historical v0.3.0 recovery pr", self.current_contract.casefold())

    def test_v0_3_archived_byte_identically(self):
        self.assertTrue(CONTRACT_V0_3_ARCHIVE.is_file())
        self.assertEqual(EXPECTED_CONTRACT_V0_3_SHA256, _sha256(CONTRACT_V0_3_ARCHIVE))
        self.assertFalse((DOCS / "working" / "HARDEN-02_CONTRACT_WORKING_v0.3.0.md").exists())
        self.assertIn("does **not** satisfy v0.3.0's GitHub-account independence rule", self.contract)
        self.assertIn("5809723449", self.contract)
        self.assertIn("887230fee605f34d4aef36d044737c1cfe257c49", self.contract)
        self.assertIn("35969382003", self.contract)

    def test_open_work_v1_2_42_archived_byte_identically(self):
        self.assertTrue(OPEN_WORK_PREDECESSOR.is_file())
        self.assertEqual(EXPECTED_OPEN_WORK_V1_2_42_SHA256, _sha256(OPEN_WORK_PREDECESSOR))
        self.assertFalse((DOCS / "02_OPEN_WORK_v1.2.42.md").exists())
        self.assertIn("v1.2.42 → v1.2.43", self.open_work)

    def test_harden_02_scope_invariants_preserved_from_v0_3(self):
        for start, end in (
            ("## 3. Accepted human scope decisions", "## 4. In scope"),
            ("## 8. Current structural invariant suite", "## 9. Stale-state / restart pressure tests"),
        ):
            predecessor_section = _section(self.contract_v0_3, start, end)
            successor_section = _section(self.contract, start, end)
            if start.startswith("## 3."):
                for scope_id in ("H02-1", "H02-2", "H02-3", "H02-3R"):
                    predecessor_row = next(
                        line for line in predecessor_section.splitlines()
                        if line.startswith(f"| `{scope_id}` |")
                    )
                    successor_row = next(
                        line for line in successor_section.splitlines()
                        if line.startswith(f"| `{scope_id}` |")
                    )
                    self.assertEqual(predecessor_row, successor_row, scope_id)
            else:
                self.assertEqual(predecessor_section, successor_section)

    def test_execution_is_current_stage_and_rejects_appended_routes(self):
        historical_label = "HARDEN-02 CONTRACT RECOVERY / SOLO-MAINTAINER CERTIFICATION AMENDMENT"
        historical_next = "HARDEN-02_CONTRACT_RECOVERY_REQUIRED"
        current_label = "FP-001 PHASE 7B AUDIT & EVIDENCE JIT DOMAIN DOSSIER CANDIDATE REVIEW"
        current_next = "FRESH INDEPENDENT EXACT-HEAD CANDIDATE REVIEW/CERTIFICATION"
        historical_open_work_current = _route_declaration(self.open_work, "CURRENT AUTHORITY-STAGE PROGRAMME")
        current_open_work_current = _route_declaration(self.current_open_work, "CURRENT AUTHORITY-STAGE PROGRAMME")
        readme_current = _route_declaration(self.readme, "CURRENT AUTHORITY-STAGE PROGRAMME")
        historical_open_work_next = _route_declaration(self.open_work, "NEXT STAGE")
        current_open_work_next = _route_declaration(self.current_open_work, "NEXT STAGE")
        readme_next = _route_declaration(self.readme, "NEXT STAGE")
        self.assertEqual(historical_label, historical_open_work_current)
        self.assertEqual(historical_next, historical_open_work_next)
        self.assertEqual(current_label, current_open_work_current)
        self.assertEqual(current_label, readme_current)
        self.assertEqual(current_next, current_open_work_next)
        self.assertEqual(current_next, readme_next)
        self.assertEqual(EXPECTED_RECOVERY_STATE, self.recovery_state)
        _assert_no_current_execution_authority(self.open_work)
        self.assertEqual("COMPLETE / CERTIFIED", self.current_lifecycle_state["harden_02_execution"])
        self.assertIn("HARDEN-02 EXECUTION: COMPLETE / CERTIFIED", self.current_open_work)
        self.assertIn("HARDEN-02 EXECUTION: COMPLETE / CERTIFIED", self.readme)
        self.assertEqual("COMPLETE / CERTIFIED", self.current_lifecycle_state["engineering_standards_authority_promotion"])

        conflicting_text = (
            self.open_work
            + "\nCURRENT AUTHORITY-STAGE PROGRAMME: HARDEN-02 EXECUTION / STRUCTURAL HARDENING\n"
            + "NEXT STAGE: HARDEN-02_EXECUTION_REQUIRED\n"
        )
        with self.assertRaises(AssertionError):
            _route_declaration(conflicting_text, "CURRENT AUTHORITY-STAGE PROGRAMME")
        with self.assertRaises(AssertionError):
            _route_declaration(conflicting_text, "NEXT STAGE")
        with self.assertRaises(AssertionError):
            _assert_no_current_execution_authority(
                self.open_work + "\nHARDEN-02 EXECUTION: NEXT / AUTHORISED\n"
            )

    def test_programme_state_table_does_not_claim_v0_3_is_current(self):
        section = self.open_work.split("## 12.1 Programme state", maxsplit=1)[1].split("## 12.2", maxsplit=1)[0]
        later_rows = [line for line in section.splitlines() if line.startswith("| Later |")]
        self.assertEqual(1, len(later_rows))
        later_row = later_rows[0].casefold()
        self.assertIn("v0.4.0", later_row)
        self.assertNotIn("v0.3.0 is current", later_row)
        self.assertNotIn("under v0.3.0 is current", later_row)
        self.assertIn("not started / not authorised", later_row)

    def test_solo_maintainer_same_poster_may_pass_when_review_actor_independent(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(
            head_sha,
            review_actor="ChatGPT / GPT-5.6 Sol",
            poster="JCSchoeman96",
            poster_equals_pr_author=True,
        )
        self.assertTrue(self._recovery_entry_passes(head_sha, evidence))

    def test_review_actor_authored_candidate_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        evidence["pre_merge_review"]["review_actor_authored_or_modified_candidate"] = True
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_missing_review_actor_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        del evidence["pre_merge_review"]["independent_review_actor"]
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_missing_posting_identity_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        evidence["pre_merge_review"]["attestation_poster_github_identity"] = ""
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_missing_poster_equals_author_disclosure_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        evidence["pre_merge_review"]["poster_equals_pr_author_disclosed"] = False
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_pre_merge_truthful_poster_not_equals_pr_author_passes(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(
            head_sha,
            poster="independent-github-reviewer",
            poster_equals_pr_author=False,
        )
        self.assertTrue(self._recovery_entry_passes(head_sha, evidence))

    def test_pre_merge_false_disclosure_poster_equals_but_different_identity_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(
            head_sha,
            poster="independent-github-reviewer",
            poster_equals_pr_author=True,
        )
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_pre_merge_false_disclosure_poster_not_equals_but_same_identity_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(
            head_sha,
            poster="JCSchoeman96",
            poster_equals_pr_author=False,
        )
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_post_merge_truthful_poster_not_equals_pr_author_passes(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(
            head_sha,
            poster="independent-github-reviewer",
            poster_equals_pr_author=False,
        )
        self.assertTrue(self._recovery_entry_passes(head_sha, evidence))

    def test_post_merge_false_disclosure_poster_equals_but_different_identity_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(
            head_sha,
            poster="independent-github-reviewer",
            poster_equals_pr_author=True,
        )
        evidence["post_merge_certification"]["attestation_poster_github_identity"] = (
            "independent-github-reviewer"
        )
        evidence["post_merge_certification"]["poster_equals_pr_author"] = True
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_post_merge_false_disclosure_poster_not_equals_but_same_identity_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        evidence["post_merge_certification"]["poster_equals_pr_author"] = False
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_reviewed_head_mismatch_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        evidence["pre_merge_review"]["reviewed_head_sha"] = "b" * 40
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_changed_head_after_review_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        self.assertFalse(self._recovery_entry_passes("c" * 40, evidence))

    def test_ci_head_mismatch_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        evidence["pre_merge_ci"]["head_sha"] = "b" * 40
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_merge_head_mismatch_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        evidence["merge"]["merged_head_sha"] = "b" * 40
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_resulting_main_mismatch_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        evidence["post_merge_certification"]["resulting_main_sha"] = "e" * 40
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_missing_post_merge_review_actor_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        del evidence["post_merge_certification"]["independent_review_actor"]
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_missing_post_merge_attestation_fields_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        del evidence["post_merge_certification"]["record_url"]
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_pre_merge_attestation_wrong_pr_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        evidence["pre_merge_review"]["record_url"] = (
            "https://github.com/JCSchoeman96/NewYou/pull/39#pullrequestreview-1"
        )
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_post_merge_attestation_wrong_pr_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        evidence["post_merge_certification"]["record_url"] = (
            "https://github.com/JCSchoeman96/NewYou/pull/39#issuecomment-2"
        )
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_misattributing_poster_as_substantive_reviewer_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        evidence["pre_merge_review"]["substantive_reviewer_is_review_actor_not_poster"] = False
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_review_actor_same_as_candidate_author_fails(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha, review_actor="JCSchoeman96")
        self.assertFalse(self._recovery_entry_passes(head_sha, evidence))

    def test_contract_rejects_fixture_only_certification(self):
        self.assertIn(
            "Passing contract-stage unit tests or fixture syntax alone does **not** establish certification",
            self.contract,
        )

    def test_pre_merge_lifecycle_allows_review_and_ci_in_either_order(self):
        lifecycle = _section(
            self.contract,
            "### 11.4 v0.4.0 certification lifecycle",
            "The smallest required attestation field groups are:",
        )
        self.assertIn("either may happen first", lifecycle)
        self.assertIn("may complete in either order", lifecycle)
        self.assertIn("only after both", lifecycle.casefold())
        self.assertIn(
            "does **not** require `review → attestation → CI` as a strict chronological sequence",
            lifecycle,
        )
        self.assertNotIn(
            "→ durable GitHub attestation records the review and exact SHA\n→ Foundation Integrity PASS on same exact head",
            lifecycle,
        )

    def test_pre_merge_attestation_evidence_binds_review_pass_and_ci_pass_on_same_head(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        self.assertTrue(self._recovery_entry_passes(head_sha, evidence))

        missing_review_pass = self._complete_evidence(head_sha)
        missing_review_pass["pre_merge_review"]["outcome"] = "FAIL"
        self.assertFalse(self._recovery_entry_passes(head_sha, missing_review_pass))

        missing_ci_pass = self._complete_evidence(head_sha)
        missing_ci_pass["pre_merge_ci"]["conclusion"] = "FAIL"
        self.assertFalse(self._recovery_entry_passes(head_sha, missing_ci_pass))

        ci_head_mismatch = self._complete_evidence(head_sha)
        ci_head_mismatch["pre_merge_ci"]["head_sha"] = "b" * 40
        self.assertFalse(self._recovery_entry_passes(head_sha, ci_head_mismatch))

    def test_pre_merge_attestation_ci_binding_exact_match_passes(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)
        review = evidence["pre_merge_review"]
        pre_ci = evidence["pre_merge_ci"]
        self.assertTrue(
            _pre_merge_attestation_ci_binding_valid(
                review,
                pre_ci,
                expected_head_sha=head_sha,
            )
        )
        self.assertTrue(self._recovery_entry_passes(head_sha, evidence))

    def test_pre_merge_attestation_ci_binding_fail_closed(self):
        head_sha = "a" * 40
        evidence = self._complete_evidence(head_sha)

        missing_ci_head = self._complete_evidence(head_sha)
        del missing_ci_head["pre_merge_review"]["ci_head_sha"]
        self.assertFalse(self._recovery_entry_passes(head_sha, missing_ci_head))

        wrong_ci_head = self._complete_evidence(head_sha)
        wrong_ci_head["pre_merge_review"]["ci_head_sha"] = "b" * 40
        self.assertFalse(self._recovery_entry_passes(head_sha, wrong_ci_head))

        wrong_workflow = self._complete_evidence(head_sha)
        wrong_workflow["pre_merge_review"]["ci_workflow"] = "Other Workflow"
        self.assertFalse(self._recovery_entry_passes(head_sha, wrong_workflow))

        non_pass_conclusion = self._complete_evidence(head_sha)
        non_pass_conclusion["pre_merge_review"]["ci_conclusion"] = "FAIL"
        self.assertFalse(self._recovery_entry_passes(head_sha, non_pass_conclusion))

        different_run_url = self._complete_evidence(head_sha)
        different_run_url["pre_merge_review"]["ci_run_url"] = (
            "https://github.com/JCSchoeman96/NewYou/actions/runs/9999"
        )
        self.assertFalse(self._recovery_entry_passes(head_sha, different_run_url))

    def test_certification_schema_matches_v0_4_attestation_fields(self):
        self.assertEqual(
            {
                "pre_merge_review": [
                    "reviewed_head_sha",
                    "outcome",
                    "reviewed_head_is_certified_head",
                    "independent_review_actor",
                    "attestation_poster_github_identity",
                    "poster_equals_pr_author_disclosed",
                    "poster_equals_pr_author",
                    "review_actor_authored_or_modified_candidate",
                    "substantive_reviewer_is_review_actor_not_poster",
                    "ci_head_sha",
                    "ci_workflow",
                    "ci_conclusion",
                    "ci_run_url",
                    "record_url",
                ],
                "pre_merge_ci": ["head_sha", "conclusion", "workflow", "run_url"],
                "merge": [
                    "certified_head_sha",
                    "head_sha_verified_before_merge",
                    "merged_head_sha",
                    "resulting_main_sha",
                ],
                "post_merge_ci": ["head_sha", "conclusion", "workflow", "run_url"],
                "post_merge_certification": [
                    "resulting_main_sha",
                    "certified_head_sha",
                    "ci_head_sha",
                    "ci_conclusion",
                    "ci_run_url",
                    "outcome",
                    "independent_review_actor",
                    "attestation_poster_github_identity",
                    "poster_equals_pr_author_disclosed",
                    "poster_equals_pr_author",
                    "review_actor_authored_or_modified_candidate",
                    "substantive_reviewer_is_review_actor_not_poster",
                    "record_url",
                ],
            },
            self.evidence_spec,
        )

    def test_execution_and_downstream_remain_blocked(self):
        self.assertEqual("NOT STARTED / NOT AUTHORISED", self.recovery_state["harden_02_execution"])
        self.assertEqual("DOWNSTREAM / NOT STARTED", self.recovery_state["engineering_standards_authority_promotion"])
        self.assertEqual("REQUIRED / DOWNSTREAM / NOT PERFORMED", self.recovery_state["fp001_reconciliation"])
        self.assertEqual("REQUIRED / NOT_STARTED", self.recovery_state["communications"])
        self.assertEqual("STALE / BLOCKED / NOT AUTHORITY", self.recovery_state["pr_38"])

    def test_readme_open_work_and_manifest_route_the_lifecycle_successor(self):
        self.assertIn(self.current_open_work_path.name, self.readme)
        self.assertIn("working/HARDEN-02_CONTRACT_WORKING_v0.5.8.md", self.readme)
        self.assertIn("archive/HARDEN-02_CONTRACT_WORKING_v0.4.0.md", self.readme)
        self.assertNotIn("POST-MERGE CERTIFICATION: PENDING", self.readme)
        self.assertIn("POST-MERGE CERTIFICATION: COMPLETE", self.readme)
        self.assertIn("HARDEN-02 EXECUTION: COMPLETE / CERTIFIED", self.readme)
        self.assertIn("ENGINEERING STANDARDS AUTHORITY PROMOTION: COMPLETE / CERTIFIED", self.readme)
        self.assertNotIn("PENDING INDEPENDENT PRE-MERGE CERTIFICATION", self.readme)
        self.assertIn("archive/02_OPEN_WORK_v1.2.44.md", self.readme)
        self.assertIn("archive/02_OPEN_WORK_v1.2.48.md", self.readme)
        self.assertIn("archive/02_OPEN_WORK_v1.2.42.md", self.readme)
        self.assertIn("archive/HARDEN-02_CONTRACT_WORKING_v0.3.0.md", self.readme)
        current = {
            entry["document_id"]: entry
            for section in ("governing_documents", "reference_documents")
            for entry in self.manifest[section]
        }
        self.assertEqual("1.2.64", current["OPEN_WORK"]["semver"])
        self.assertEqual(
            "docs/00_platform/02_OPEN_WORK_v1.2.64.md",
            current["OPEN_WORK"]["repository_path"],
        )
        self.assertEqual("02_OPEN_WORK_v1.2.64.md", self.current_open_work_path.name)
        self.assertEqual(_sha256(self.current_open_work_path), current["OPEN_WORK"]["sha256"])
        navigation_paths = self.manifest["integrity_rules"]["graph_rules"]["navigation_document_paths"]
        self.assertIn("docs/00_platform/working/HARDEN-02_CONTRACT_WORKING_v0.5.8.md", navigation_paths)
        self.assertNotIn("docs/00_platform/working/HARDEN-02_CONTRACT_WORKING_v0.4.1.md", navigation_paths)
        historical = {entry["document_id"]: entry for entry in self.manifest["historical_documents"]}
        self.assertEqual("historical", historical["OPEN_WORK_V1_2_47"]["lifecycle"])
        self.assertEqual("1.2.48", historical["OPEN_WORK_V1_2_47"]["superseded_version"])
        self.assertEqual(EXPECTED_OPEN_WORK_V1_2_47_SHA256, historical["OPEN_WORK_V1_2_47"]["sha256"])
        self.assertEqual(EXPECTED_OPEN_WORK_V1_2_47_SHA256, _sha256(OPEN_WORK_V1_2_47_ARCHIVE))
        self.assertEqual("historical", historical["OPEN_WORK_V1_2_48"]["lifecycle"])
        self.assertEqual("1.2.49", historical["OPEN_WORK_V1_2_48"]["superseded_version"])
        self.assertEqual(EXPECTED_OPEN_WORK_V1_2_48_SHA256, historical["OPEN_WORK_V1_2_48"]["sha256"])
        self.assertEqual(EXPECTED_OPEN_WORK_V1_2_48_SHA256, _sha256(OPEN_WORK_V1_2_48_ARCHIVE))
        self.assertEqual("historical", historical["OPEN_WORK_V1_2_46"]["lifecycle"])
        self.assertEqual("1.2.47", historical["OPEN_WORK_V1_2_46"]["superseded_version"])
        self.assertEqual(EXPECTED_OPEN_WORK_V1_2_46_SHA256, historical["OPEN_WORK_V1_2_46"]["sha256"])
        self.assertEqual(EXPECTED_OPEN_WORK_V1_2_46_SHA256, _sha256(OPEN_WORK_V1_2_46_ARCHIVE))
        self.assertEqual("historical", historical["OPEN_WORK_V1_2_44"]["lifecycle"])
        self.assertEqual("1.2.45", historical["OPEN_WORK_V1_2_44"]["superseded_version"])
        self.assertEqual(EXPECTED_OPEN_WORK_V1_2_44_SHA256, historical["OPEN_WORK_V1_2_44"]["sha256"])
        self.assertEqual(_sha256(OPEN_WORK), historical["OPEN_WORK_V1_2_43"]["sha256"])
        self.assertEqual(EXPECTED_OPEN_WORK_V1_2_42_SHA256, historical["OPEN_WORK_V1_2_42"]["sha256"])

    def test_current_lifecycle_state_binds_all_certification_evidence_and_downstream_gates(self):
        state = self.current_lifecycle_state
        self.assertEqual("COMPLETE / CERTIFIED", state["contract_status"])
        self.assertEqual("COMPLETE / CERTIFIED", state["harden_02_execution"])
        self.assertEqual("FP-001 PHASE 7B AUDIT & EVIDENCE JIT DOMAIN DOSSIER CANDIDATE REVIEW", state["current_stage"])
        self.assertEqual("FRESH INDEPENDENT EXACT-HEAD CANDIDATE REVIEW/CERTIFICATION", state["next_stage"])
        self.assertEqual("0.5.8", state["status_successor_version"])
        self.assertEqual("1.2.64", next(row for row in self.manifest["governing_documents"] if row["document_id"] == "OPEN_WORK")["semver"])
        self.assertEqual("5f5a994e48d9458aaa6397044b3af4d72c5d5e81", state["status_successor_base_sha"])
        self.assertEqual("COMPLETE / CERTIFIED", _route_declaration(self.current_open_work, "HARDEN-02 EXECUTION"))
        self.assertNotIn("POST-MERGE INDEPENDENT INSPECTION AND ATTESTATION PENDING", self.current_open_work)
        self.assertNotIn("POST-MERGE CERTIFICATION: PENDING", self.readme)
        certification = state["execution_certification"]
        pr59 = certification["pr59_final_summary_recovery"]
        current_main = certification["current_main_revalidation"]
        self.assertEqual("0dd89f749eb3d3dbd659d1f6f01485984952ddfd", pr59["candidate_sha"])
        self.assertEqual("9c7f70df8fd4d7a688e7c76e7c217cf33c0c5752", pr59["candidate_tree_sha"])
        self.assertEqual("5890210520", pr59["pre_merge_attestation_url"].rsplit("-", 1)[1])
        self.assertEqual("36567933267", pr59["resulting_main_ci_run_url"].rsplit("/", 1)[1])
        self.assertEqual("PASS WITH NON-BLOCKING CORRECTIONS", pr59["post_merge_review_outcome"])
        self.assertEqual("5890574449", pr59["post_merge_attestation_url"].rsplit("-", 1)[1])
        self.assertIn("entire Roadmap §21 section remained byte-identical", pr59["non_blocking_correction"])
        self.assertEqual("d4e7390b71cdf61b649b534e1080102a044efe63", current_main["main_sha"])
        self.assertEqual("36856102830", current_main["foundation_integrity_run_url"].rsplit("/", 1)[1])
        self.assertEqual("110348834922", current_main["foundation_integrity_job_url"].rsplit("/", 1)[1])
        self.assertEqual("251 PASS", current_main["unit_tests"])
        self.assertEqual("I-01 THROUGH I-13 PASS", current_main["invariant_proofs"])
        self.assertEqual("BOTH PASS", current_main["i04_adversarial_tests"])
        self.assertEqual(506, current_main["fia_assertions"])
        self.assertEqual(0, current_main["fia_findings"])
        self.assertEqual("PASS", current_main["fia_result"])
        self.assertEqual("COMPLETE / CERTIFIED", state["engineering_standards_authority_promotion"])
        self.assertEqual("COMPLETE / CERTIFIED", state["fp001_reconciliation"])
        self.assertEqual("COMPLETE / CERTIFIED / CURRENT v0.1.0", state["communications"])
        self.assertEqual(
            {
                "pr_url": "https://github.com/JCSchoeman96/NewYou/pull/67",
                "candidate_sha": "79d0540c66f0224ece0330181e61dfef8ab4b458",
                "prior_main_sha": "38022caea64cb2522ab8fc4db730099a94cd6600",
                "resulting_main_sha": "4000ae50660930114e3ad43108dc029fd0673d32",
                "candidate_tree_sha": "a71dbeb2cca79bea0013f9997e40f34769f262f3",
                "exact_head_ci_run": "36991113390",
                "resulting_main_ci_run": "37009244020",
                "pre_merge_attestation_comment": "5952693308",
                "post_merge_attestation_comment": "5955641536",
                "post_merge_independent_review": "PASS",
            },
            state["fp001_reconciliation_certification"],
        )
        self.assertEqual("NOT_REQUIRED", state["conditional_dossiers"]["privacy_consent"])
        self.assertEqual("NOT_REQUIRED", state["conditional_dossiers"]["content_media"])
        self.assertEqual("REQUIRED / IN PROGRESS / NOT COMPLETE / CERTIFICATION PENDING", state["conditional_dossiers"]["audit_evidence"])
        self.assertEqual("NOT_REQUIRED", state["conditional_dossiers"]["analytics"])
        self.assertEqual("REQUIRED / IN PROGRESS / NOT COMPLETE / CERTIFICATION PENDING", state["audit_dossier"])
        self.assertEqual(
            "Audit & Evidence dossier must be COMPLETE / CERTIFIED / CURRENT and subsequent Phase 7B reconciliation must succeed",
            state["phase_7c_block_reason"],
        )
        self.assertEqual("BLOCKED / NOT_STARTED", state["phase_7c"])
        self.assertEqual("NOT FINALISED", state["proof_classification"])
        self.assertEqual("UNAUTHORISED / BLOCKED UNTIL PHASE 8 ENTRY CONDITIONS PASS", state["application_implementation"])
        self.assertEqual("STALE / BLOCKED / NOT AUTHORITY", state["pr_38"])

    def test_active_open_work_sections_do_not_route_to_historical_contract_recovery(self):
        active_sections = (
            _section(
                self.current_open_work,
                "## Phase 6 — COMPLETE: Roadmap-amendment successor v1.1.1",
                "## Phase 7 — Feature Pack Preparation + JIT Domain Dossiers",
            ),
            _section(
                self.current_open_work,
                "## 12.6 Roadmap Sequencing Grill and Roadmap amendment completion",
                "## 12.7 — Historical Delivery Atlas reconciliation",
            ),
            _section(
                self.current_open_work,
                "## 12.7 — Historical Delivery Atlas reconciliation",
                "## 12.8 — Historical HARDEN-02 contract v0.2.0 attempt",
            ),
        )
        stale_current_claims = (
            "the current stage is contract recovery / re-certification",
            "the current stage is v0.3.0 contract recovery / re-certification",
            "the current fail-closed recovery lifecycle",
            "superseded for the current stage by contract recovery / re-certification in v1.2.42",
            "after certified harden-02 execution under the v0.3.0 lifecycle",
        )
        for section in active_sections:
            section = section.casefold()
            for claim in stale_current_claims:
                self.assertNotIn(claim, section)

    def test_protected_hashes_unchanged(self):
        for relative_path, expected_hash in PROTECTED_UPSTREAM_HASHES.items():
            self.assertEqual(expected_hash, _sha256(ROOT / relative_path), relative_path)
        workflow_baseline = git_snapshot_bytes(
            ROOT,
            WELL38_BASE_SHA,
            ".github/workflows/foundation-integrity.yml",
        )
        self.assertEqual(
            FOUNDATION_WORKFLOW_BASELINE_SHA256,
            hashlib.sha256(workflow_baseline).hexdigest(),
        )

    def test_harden_02_not_in_authority_manifest(self):
        paths = [
            entry.get("repository_path", "")
            for section in ("governing_documents", "reference_documents", "historical_documents")
            for entry in self.manifest[section]
        ]
        self.assertTrue(all("HARDEN-02" not in path for path in paths))

    @staticmethod
    def _complete_evidence(
        head_sha: str,
        *,
        review_actor: str = "ChatGPT / GPT-5.6 Sol",
        poster: str = "JCSchoeman96",
        poster_equals_pr_author: bool = True,
    ) -> dict[str, object]:
        main_sha = "d" * 40
        pre_ci_url = "https://github.com/JCSchoeman96/NewYou/actions/runs/1001"
        post_ci_url = "https://github.com/JCSchoeman96/NewYou/actions/runs/1002"
        pre_ci = {
            "head_sha": head_sha,
            "conclusion": "PASS",
            "workflow": "Foundation Integrity",
            "run_url": pre_ci_url,
        }
        attestation = {
            "independent_review_actor": review_actor,
            "attestation_poster_github_identity": poster,
            "poster_equals_pr_author_disclosed": True,
            "poster_equals_pr_author": poster_equals_pr_author,
            "review_actor_authored_or_modified_candidate": False,
            "substantive_reviewer_is_review_actor_not_poster": True,
        }
        return {
            "pre_merge_review": {
                "reviewed_head_sha": head_sha,
                "outcome": "PASS",
                "reviewed_head_is_certified_head": True,
                "ci_head_sha": pre_ci["head_sha"],
                "ci_workflow": pre_ci["workflow"],
                "ci_conclusion": pre_ci["conclusion"],
                "ci_run_url": pre_ci["run_url"],
                "record_url": f"https://github.com/JCSchoeman96/NewYou/pull/{EXPECTED_RECOVERY_PR_NUMBER}#pullrequestreview-1",
                **attestation,
            },
            "pre_merge_ci": pre_ci,
            "merge": {
                "certified_head_sha": head_sha,
                "head_sha_verified_before_merge": head_sha,
                "merged_head_sha": head_sha,
                "resulting_main_sha": main_sha,
            },
            "post_merge_ci": {
                "head_sha": main_sha,
                "conclusion": "PASS",
                "workflow": "Foundation Integrity",
                "run_url": post_ci_url,
            },
            "post_merge_certification": {
                "resulting_main_sha": main_sha,
                "certified_head_sha": head_sha,
                "ci_head_sha": main_sha,
                "ci_conclusion": "PASS",
                "ci_run_url": post_ci_url,
                "outcome": "PASS",
                "record_url": f"https://github.com/JCSchoeman96/NewYou/pull/{EXPECTED_RECOVERY_PR_NUMBER}#issuecomment-2",
                **attestation,
            },
        }


class FoundationIntegrityWorkflowTests(unittest.TestCase):
    def test_foundation_full_is_nightly_only_and_not_started_by_pr_or_dispatch(self):
        required_workflow = (ROOT / ".github" / "workflows" / "foundation-integrity.yml").read_text(
            encoding="utf-8"
        )
        workflow = (ROOT / ".github" / "workflows" / "foundation-full.yml").read_text(
            encoding="utf-8"
        )
        nightly = (ROOT / ".github" / "workflows" / "nightly-hardening.yml").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("foundation-full.yml", required_workflow)
        self.assertNotIn("workflow_dispatch:", workflow)
        self.assertNotIn("workflow_dispatch:", nightly)
        self.assertIn("workflow_call:", workflow)
        self.assertIn("uses: ./.github/workflows/foundation-full.yml", nightly)
        self.assertIn("    - cron: '0 2 * * *'\n      timezone: Africa/Johannesburg", nightly)


if __name__ == "__main__":
    unittest.main()
