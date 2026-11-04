from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

from tools.foundation_integrity_routing import (
    classify_changed_paths,
    classify_deep_application_changes,
    classify_deep_event,
    classify_event,
    classify_path,
)


ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github/workflows"


def _route(paths: list[str]) -> dict[str, bool]:
    return classify_changed_paths(paths)


class ApplicationAndEngineeringRoutingTests(unittest.TestCase):
    """Scenario A and B: ordinary application and engineering changes never select Full."""

    def test_application_source_runs_application_ci_without_full(self):
        decision = _route(["lib/new_you/accounts.ex"])
        self.assertEqual({"foundation_full": False, "application_changes": True}, decision)

    def test_root_engineering_files_run_engineering_checks_without_full(self):
        for path in ["AGENTS.md", ".tool-versions", ".gitattributes", ".devcore/project.conf", ".agents/skills/project-implementation/SKILL.md"]:
            with self.subTest(path=path):
                self.assertEqual("application", classify_path(path))
                self.assertEqual({"foundation_full": False, "application_changes": True}, _route([path]))

    def test_known_engineering_document_paths_run_application_ci_without_full(self):
        for path in [
            "docs/development/example.md",
            "docs/superpowers/specs/example.md",
            "docs/delivery/execution/FP-001/specs/example.md",
        ]:
            with self.subTest(path=path):
                self.assertEqual("application", classify_path(path))
                self.assertEqual({"foundation_full": False, "application_changes": True}, _route([path]))

    def test_engineering_tooling_and_ci_are_classified_intentionally(self):
        for path in [
            "mix.exs",
            "mix.lock",
            ".credo.exs",
            "tools/architecture/ash_write_boundary.ex",
            ".github/workflows/application-ci.yml",
            "config/test.exs",
            "priv/repo/migrations/20261022104847_initialize_extensions_1.exs",
        ]:
            with self.subTest(path=path):
                self.assertEqual("application", classify_path(path))


class GovernanceRoutingTests(unittest.TestCase):
    """Scenario C: governance-sensitive changes select Full."""

    def test_current_platform_authority_selects_full_only(self):
        path = "docs/governance/product/00_PLATFORM_v1.13.0.md"
        self.assertEqual("governance", classify_path(path))
        self.assertEqual({"foundation_full": True, "application_changes": False}, _route([path]))

    def test_delivery_contracts_are_application_paths(self):
        path = "docs/delivery/jit/identity/example.md"
        self.assertEqual("application", classify_path(path))
        self.assertEqual({"foundation_full": False, "application_changes": True}, _route([path]))

    def test_governed_authority_document_selects_full(self):
        decision = _route(["docs/history/02_OPEN_WORK_v1.2.90.md"])
        self.assertEqual({"foundation_full": True, "application_changes": False}, decision)

    def test_governance_audit_code_selects_full(self):
        for path in [
            "tools/foundation_integrity_audit.py",
            "tools/foundation_integrity_routing.py",
            "tests/test_foundation_full.py",
        ]:
            with self.subTest(path=path):
                self.assertEqual("governance", classify_path(path))
                self.assertTrue(_route([path])["foundation_full"])

    def test_governance_full_workflow_itself_selects_full(self):
        self.assertEqual("governance", classify_path(".github/workflows/foundation-full.yml"))
        self.assertEqual("governance", classify_path(".github/workflows/foundation-integrity.yml"))
        self.assertTrue(_route([".github/workflows/foundation-full.yml"])["foundation_full"])


class MixedAndUnknownRoutingTests(unittest.TestCase):
    """Scenario D (mixed) and scenario E (unknown, fails closed)."""

    def test_mixed_application_and_governance_runs_both(self):
        decision = _route(["lib/new_you/accounts.ex", "docs/history/02_OPEN_WORK_v1.2.90.md"])
        self.assertEqual({"foundation_full": True, "application_changes": True}, decision)

    def test_unknown_paths_fail_closed_to_full(self):
        for path in ["new-surface/authority.md", ".github/CODEOWNERS", "tools/unclassified.py", "vendor/blob.bin"]:
            with self.subTest(path=path):
                self.assertEqual("unknown", classify_path(path))
                self.assertTrue(_route([path])["foundation_full"])

    def test_unclassified_document_paths_fail_closed_to_full(self):
        for path in ["docs/unclassified-area/example.md", "docs/something-new/foo.md"]:
            with self.subTest(path=path):
                self.assertEqual("unknown", classify_path(path))
                self.assertEqual({"foundation_full": True, "application_changes": False}, _route([path]))


class SemanticRootRoutingTests(unittest.TestCase):
    """CI ownership follows semantic roots, with explicit Full machinery exceptions."""

    def test_governance_and_history_roots_select_full(self):
        paths = [
            "docs/governance/product/PROJECT_NORTH_STAR_AND_MVP_v1.3.0.md",
            "docs/governance/product/00_PLATFORM_v1.13.0.md",
            "docs/governance/product/01_DECISIONS_v1.13.0.md",
            "docs/governance/architecture/03_ARCHITECTURE_v1.1.1.md",
            "docs/governance/domain/04_DOMAIN_MAP_v1.2.0.md",
            "docs/governance/roadmap/05_ROADMAP_v1.2.5.md",
            "docs/governance/supporting/PLATFORM_OPERATING_MODEL_v1.3.0.md",
            "docs/governance/supporting/ENGINEERING_STANDARDS_v1.0.1.md",
            "docs/governance/supporting/DELIVERY_GOVERNANCE_STANDARD_v1.1.0.md",
            "docs/governance/CURRENT_GOVERNANCE_ROUTER.json",
            "docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json",
            "docs/history/02_OPEN_WORK_v1.2.90.md",
            "docs/history/platform/archive/00_PLATFORM_v1.12.0.md",
            "docs/history/delivery-packs/live_replay/deep/archive/previous.md",
        ]
        for path in paths:
            with self.subTest(path=path):
                self.assertEqual("governance", classify_path(path))
                self.assertEqual(
                    {"foundation_full": True, "application_changes": False},
                    _route([path]),
                )

    def test_delivery_development_and_python_regressions_skip_full(self):
        paths = [
            "docs/delivery/jit/identity/IDENTITY_JIT.md",
            "docs/delivery/feature-contracts/FP-001/FEATURE_CONTRACT.md",
            "docs/delivery/proof/FP-001/TRACER_BULLET.md",
            "docs/delivery/execution/p8-05-registration-jit-spec.md",
            "docs/delivery/content-evidence/verification-messages/evidence.json",
            "docs/delivery/CURRENT_DELIVERY_ROUTER.json",
            "docs/development/foundation-integrity-merge-gate.md",
            "docs/README.md",
            "AGENTS.md",
            ".agents/skills/ticket-implement/SKILL.md",
            "tests/test_application_regression.py",
            "tests/test_delivery_contract_regression.py",
            "tests/test_foundation_smoke.py",
            "tests/test_foundation_lane_routing.py",
            "lib/new_you/accounts.ex",
            "priv/repo/migrations/20261101000000_example.exs",
        ]
        for path in paths:
            with self.subTest(path=path):
                self.assertEqual("application", classify_path(path))
                self.assertEqual(
                    {"foundation_full": False, "application_changes": True},
                    _route([path]),
                )

    def test_deep_application_lane_is_limited_to_code_and_dependency_inputs(self):
        for path in [
            "docs/delivery/jit/identity/IDENTITY_JIT.md",
            "docs/development/foundation-integrity-merge-gate.md",
            ".agents/skills/ticket-implement/SKILL.md",
            "tests/test_application_regression.py",
            "test/new_you/accounts_test.exs",
        ]:
            with self.subTest(path=path):
                self.assertFalse(classify_deep_application_changes([path]))

        for path in [
            "lib/new_you/accounts.ex",
            "priv/repo/migrations/20261101000000_example.exs",
            "mix.exs",
            "mix.lock",
            ".tool-versions",
        ]:
            with self.subTest(path=path):
                self.assertTrue(classify_deep_application_changes([path]))

    def test_full_machinery_and_provenance_tests_select_full(self):
        paths = [
            "tools/foundation_integrity_routing.py",
            "tools/foundation_integrity_audit.py",
            "tools/foundation_integrity_smoke.py",
            "tools/run_foundation_full_tests.py",
            "tests/foundation_test_support.py",
            "tests/test_foundation_full.py",
            "tests/test_foundation_integrity_audit.py",
            "tests/test_historical_scope.py",
            ".github/workflows/foundation-integrity.yml",
            ".github/workflows/foundation-full.yml",
        ]
        for path in paths:
            with self.subTest(path=path):
                self.assertEqual("governance", classify_path(path))
                self.assertTrue(_route([path])["foundation_full"])

    def test_unknown_document_paths_fail_closed(self):
        for path in ["docs/unclassified/example.md", "docs/00_platform/legacy.md"]:
            with self.subTest(path=path):
                self.assertEqual("unknown", classify_path(path))
                self.assertEqual(
                    {"foundation_full": True, "application_changes": False},
                    _route([path]),
                )

    def test_path_escapes_and_backslashes_fail_closed(self):
        for path in ["../lib/x.ex", "/lib/x.ex", r"lib\x.ex"]:
            with self.subTest(path=path):
                self.assertEqual("unknown", classify_path(path))

    def test_empty_change_range_fails_closed(self):
        self.assertEqual({"foundation_full": True, "application_changes": False}, _route([]))


class EventRoutingTests(unittest.TestCase):
    """Scenario F and manual certification."""

    def _repo(self, directory: str):
        root = Path(directory)

        def git(*args: str) -> str:
            return subprocess.run(["git", *args], cwd=root, check=True, capture_output=True, text=True).stdout.strip()

        git("init", "--quiet", "-b", "main")
        git("config", "user.email", "routing@example.invalid")
        git("config", "user.name", "Routing Test")
        (root / "lib").mkdir()
        (root / "lib/app.ex").write_text("defmodule App do\nend\n", encoding="utf-8")
        (root / "docs/governance/product").mkdir(parents=True)
        (root / "docs/governance/product/authority.md").write_text("v1\n", encoding="utf-8")
        git("add", ".")
        git("commit", "--quiet", "-m", "baseline")
        return root, git

    def test_manual_dispatch_selects_full_only(self):
        decision = classify_event("workflow_dispatch", "", "", str(ROOT))
        self.assertEqual({"foundation_full": True, "application_changes": False}, decision)
        self.assertFalse(classify_deep_event("workflow_dispatch", "", "", str(ROOT)))

    def test_unknown_push_range_fails_closed_for_all_selected_lanes(self):
        self.assertTrue(classify_deep_event("push", "", "", str(ROOT)))

    def test_explicit_push_range_classification_remains_available(self):
        """Explicit push ranges remain classifiable, independent of workflow triggers."""
        with tempfile.TemporaryDirectory() as directory:
            root, git = self._repo(directory)
            git("checkout", "--quiet", "-b", "feature")
            (root / "lib/app.ex").write_text("defmodule App do\n  def run, do: :ok\nend\n", encoding="utf-8")
            git("commit", "--quiet", "-am", "application change")
            pr_head = git("rev-parse", "HEAD")
            git("checkout", "--quiet", "main")
            merge_base = git("rev-parse", "HEAD")
            git("merge", "--quiet", "--no-ff", "-m", "merge PR", "feature")
            merged = git("rev-parse", "HEAD")

            pull_request = classify_event("pull_request", merge_base, pr_head, str(root))
            self.assertEqual({"foundation_full": False, "application_changes": True}, pull_request)

            post_merge = classify_event("push", merge_base, merged, str(root))
            self.assertFalse(post_merge["foundation_full"])
            self.assertTrue(post_merge["application_changes"])

    def test_governance_push_range_classifies_as_full(self):
        with tempfile.TemporaryDirectory() as directory:
            root, git = self._repo(directory)
            base = git("rev-parse", "HEAD")
            (root / "docs/governance/product/authority.md").write_text("v2\n", encoding="utf-8")
            git("commit", "--quiet", "-am", "governance change")
            head = git("rev-parse", "HEAD")

            self.assertEqual(
                {"foundation_full": True, "application_changes": False},
                classify_event("push", base, head, str(root)),
            )

    def test_unknown_push_range_fails_closed_to_full(self):
        with tempfile.TemporaryDirectory() as directory:
            root, git = self._repo(directory)
            base = git("rev-parse", "HEAD")
            (root / "unclassified-authority.txt").write_text("unknown\n", encoding="utf-8")
            git("add", "unclassified-authority.txt")
            git("commit", "--quiet", "-m", "unclassified change")
            head = git("rev-parse", "HEAD")

            self.assertEqual(
                {"foundation_full": True, "application_changes": False},
                classify_event("push", base, head, str(root)),
            )

    def test_pull_request_with_governance_change_selects_full_from_exact_diff(self):
        with tempfile.TemporaryDirectory() as directory:
            root, git = self._repo(directory)
            base = git("rev-parse", "HEAD")
            git("checkout", "--quiet", "-b", "governed")
            (root / "docs/governance/product/authority.md").write_text("v2\n", encoding="utf-8")
            git("commit", "--quiet", "-am", "governance change")
            head = git("rev-parse", "HEAD")
            self.assertTrue(classify_event("pull_request", base, head, str(root))["foundation_full"])


class TopologyTests(unittest.TestCase):
    """The lane topology is physically split and wired through native reusable workflows."""

    def test_nightly_hardening_is_main_only_cold_and_separate_from_pr_checks(self):
        workflow = (WORKFLOWS / "nightly-hardening.yml").read_text(encoding="utf-8")
        self.assertIn("  schedule:", workflow)
        self.assertIn("    - cron:", workflow)
        self.assertIn("  workflow_dispatch:", workflow)
        self.assertNotIn("  push:", workflow)
        self.assertNotIn("  pull_request:", workflow)
        self.assertEqual(2, workflow.count("if: github.ref == 'refs/heads/main'"))
        self.assertIn("uses: ./.github/workflows/foundation-full.yml", workflow)
        self.assertIn("sha: ${{ github.sha }}", workflow)
        self.assertIn("run: mix check.deep", workflow)
        self.assertNotIn("actions/cache", workflow)
        full = (WORKFLOWS / "foundation-full.yml").read_text(encoding="utf-8")
        self.assertNotIn("actions/cache", full)
        integrity = (WORKFLOWS / "foundation-integrity.yml").read_text(encoding="utf-8")
        self.assertNotIn("nightly-hardening", integrity)

    def test_required_entry_point_keeps_name_and_routes_both_lanes(self):
        workflow = (WORKFLOWS / "foundation-integrity.yml").read_text(encoding="utf-8")
        self.assertIn("name: Foundation Integrity", workflow)
        self.assertIn("uses: ./.github/workflows/application-ci.yml", workflow)
        self.assertIn("uses: ./.github/workflows/foundation-full.yml", workflow)
        self.assertIn("needs.route.outputs.application_changes == 'true'", workflow)
        self.assertIn("needs.route.outputs.foundation_full == 'true'", workflow)

    def test_application_ci_runs_canonical_gates_and_never_historical_full(self):
        workflow = (WORKFLOWS / "application-ci.yml").read_text(encoding="utf-8")
        self.assertIn("run: mix check\n", workflow)
        self.assertIn("run: mix check.deep", workflow)
        lowered = workflow.lower()
        self.assertNotIn("unittest", lowered)
        self.assertNotIn("foundation_integrity", lowered)
        self.assertNotIn("redis", lowered)
        self.assertNotIn("dev_database", lowered)

    def test_application_ci_uses_isolated_test_database_contract(self):
        workflow = (WORKFLOWS / "application-ci.yml").read_text(encoding="utf-8")
        self.assertIn('TEST_DATABASE_PORT: "55433"', workflow)
        self.assertIn("TEST_DATABASE_USERNAME: new_you_test", workflow)
        self.assertIn("CREATE ROLE new_you_test LOGIN NOSUPERUSER NOCREATEDB", workflow)
        self.assertNotIn("DEV_DATABASE", workflow)

    def test_foundation_full_is_called_only_and_keeps_historical_checks(self):
        workflow = (WORKFLOWS / "foundation-full.yml").read_text(encoding="utf-8")
        self.assertIn("workflow_call:", workflow)
        self.assertNotIn("pull_request:", workflow)
        self.assertNotIn("push:", workflow)
        self.assertIn("python tools/run_foundation_full_tests.py", workflow)
        self.assertIn("tools/foundation_integrity_audit.py --manifest docs/history/CURRENT_AUTHORITY_MANIFEST_v1.0.0.json --json", workflow)


if __name__ == "__main__":
    unittest.main()
