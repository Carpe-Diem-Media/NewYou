from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github/workflows"


class FoundationMergeGateTopologyTests(unittest.TestCase):
    def test_path_routing_regressions_run_in_always_on_smoke_job(self):
        workflow = (WORKFLOWS / "foundation-integrity.yml").read_text(encoding="utf-8")

        self.assertIn(
            "python -m unittest discover -s tests -p 'test_foundation_lane_routing.py' -v",
            workflow,
        )

    def test_each_application_job_checks_dependencies_before_database_and_gates(self):
        workflow = (WORKFLOWS / "application-ci.yml").read_text(encoding="utf-8")
        for job in ("mix-check", "mix-check-deep"):
            with self.subTest(job=job):
                block = workflow.split(f"  {job}:\n", 1)[1].split("\n  mix-check-deep:", 1)[0]
                header = block.split("    steps:", 1)[0]
                if job == "mix-check":
                    self.assertNotIn("    if:", header)
                else:
                    self.assertIn("    if: inputs.deep_application_changes\n", header)
                commands = [
                    "uses: actions/checkout@v7",
                    "uses: erlef/setup-beam@v1",
                    "run: mix deps.get --check-locked",
                    "run: mix deps.unlock --check-unused",
                    "      - name: Provision isolated TEST role and database",
                    f"run: mix {'check' if job == 'mix-check' else 'check.deep'}",
                ]
                for command in commands:
                    self.assertIn(command + "\n", block)
                positions = [block.index(command) for command in commands]
                self.assertEqual(sorted(positions), positions)
                self.assertNotIn("continue-on-error", block)
                self.assertNotIn("run: mix deps.get\n", block)
                self.assertNotIn("if:", block.split("    steps:", 1)[1])

    def test_mix_aliases_enforce_warnings_and_strict_security_parsing(self):
        mix = (ROOT / "mix.exs").read_text(encoding="utf-8")
        self.assertIn('test: ["ecto.migrate --quiet", "test --warnings-as-errors"]', mix)
        self.assertIn('"compile --warnings-as-errors"', mix)
        self.assertIn(
            '"sobelow --exit --skip --private --strict --router lib/new_you_web/router.ex"',
            mix,
        )

    def test_required_gate_does_not_wait_for_foundation_full(self):
        workflow = (WORKFLOWS / "foundation-integrity.yml").read_text(encoding="utf-8")

        self.assertIn("needs: [route, foundation-smoke, application-ci, hex-security-audit]", workflow)
        self.assertNotIn("needs: [route, foundation-smoke, application-ci, foundation-full]", workflow)
        self.assertNotIn("FULL_REQUIRED:", workflow)
        self.assertNotIn("FULL_RESULT:", workflow)

    def test_pr_router_never_calls_foundation_full(self):
        workflow = (WORKFLOWS / "foundation-integrity.yml").read_text(encoding="utf-8")

        self.assertNotIn("foundation-full.yml", workflow)
        self.assertNotIn("foundation_full", workflow)

    def test_deep_application_lane_is_selected_by_code_routing(self):
        integrity = (WORKFLOWS / "foundation-integrity.yml").read_text(encoding="utf-8")
        application = (WORKFLOWS / "application-ci.yml").read_text(encoding="utf-8")

        self.assertIn("deep_application_changes:", integrity)
        self.assertIn(
            "deep_application_changes: ${{ needs.route.outputs.deep_application_changes == 'true' }}",
            integrity,
        )
        self.assertIn("deep_application_changes:", application)
        self.assertIn("if: inputs.deep_application_changes", application)

    def test_superseded_pr_runs_are_cancelled(self):
        workflow = (WORKFLOWS / "foundation-integrity.yml").read_text(encoding="utf-8")

        self.assertIn("concurrency:", workflow)
        self.assertIn("group: foundation-integrity-${{ github.event.pull_request.number || github.ref }}", workflow)
        self.assertIn("cancel-in-progress: true", workflow)

    def test_pr_gate_has_no_post_merge_push_trigger(self):
        integrity = (WORKFLOWS / "foundation-integrity.yml").read_text(encoding="utf-8")
        triggers = integrity.split("\non:\n", 1)[1].split("\nconcurrency:", 1)[0]
        self.assertIn("  pull_request:", triggers)
        self.assertNotIn("  push:", triggers)

    def test_attestation_regressions_run_in_smoke(self):
        integrity = (WORKFLOWS / "foundation-integrity.yml").read_text(encoding="utf-8")
        self.assertIn("python -m unittest discover -s tests -p 'test_ci_attestation.py' -v", integrity)

    def test_foundation_full_runs_only_in_scheduled_nightly_workflow(self):
        integrity = (WORKFLOWS / "foundation-integrity.yml").read_text(encoding="utf-8")
        full = (WORKFLOWS / "foundation-full.yml").read_text(encoding="utf-8")
        nightly = (WORKFLOWS / "nightly-hardening.yml").read_text(encoding="utf-8")

        self.assertNotIn("  workflow_dispatch:", integrity)
        self.assertIn("  workflow_call:", full)
        self.assertNotIn("workflow_dispatch:", full)
        self.assertNotIn("workflow_dispatch:", nightly)
        self.assertIn("    - cron: '0 2 * * *'\n      timezone: Africa/Johannesburg", nightly)
        self.assertIn("uses: ./.github/workflows/foundation-full.yml", nightly)


if __name__ == "__main__":
    unittest.main()
