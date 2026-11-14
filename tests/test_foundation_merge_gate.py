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
                    "run: bash tools/ci/prepare_cached_dependencies.sh",
                    "run: mix deps.unlock --check-unused",
                    "      - name: Provision isolated TEST role and database",
                    f"run: mix {'check' if job == 'mix-check' else 'check.deep'}",
                ]
                for command in commands:
                    self.assertIn(command + "\n", block)
                positions = [block.index(command) for command in commands]
                self.assertEqual(sorted(positions), positions)
                self.assertEqual(1, block.count("continue-on-error: true"))
                restore = block.split("      - name: Restore dependency cache\n", 1)[1].split("      - name:", 1)[0]
                self.assertIn("continue-on-error: true\n        uses: actions/cache/restore@v4", restore)
                self.assertNotIn("run: mix deps.get\n", block)
                self.assertNotIn("if:", block.split("    steps:", 1)[1])

    def test_cache_writer_is_main_only_and_pr_jobs_restore_only(self):
        warmer = (WORKFLOWS / "application-cache.yml").read_text(encoding="utf-8")
        application = (WORKFLOWS / "application-ci.yml").read_text(encoding="utf-8")
        self.assertIn("  push:\n    branches: [main]\n    paths:", warmer)
        self.assertIn("  workflow_dispatch:", warmer)
        self.assertIn("    if: github.ref == 'refs/heads/main'", warmer)
        for path in (
            "mix.exs",
            "mix.lock",
            ".tool-versions",
            "config/**/*.exs",
            ".github/workflows/application-cache.yml",
            ".github/workflows/application-ci.yml",
            "tools/ci/**",
        ):
            with self.subTest(path=path):
                self.assertIn(f"      - '{path}'", warmer)
        # Exact filter ownership prevents a broad docs/lib/** entry from
        # accidentally restoring the every-merge workflow trigger.
        import re
        filters = re.findall(r"^      - '([^']+)'$", warmer, re.MULTILINE)
        self.assertEqual({"mix.exs", "mix.lock", ".tool-versions", "config/**/*.exs",
                          ".github/workflows/application-cache.yml",
                          ".github/workflows/application-ci.yml", "tools/ci/**"}, set(filters))
        save = warmer.split("      - name: Save trusted dependency cache", 1)[1]
        self.assertNotIn("continue-on-error", save)
        self.assertLess(warmer.index("run: bash tools/ci/prepare_cached_dependencies.sh"),
                        warmer.index("run: python3 tools/ci/cache_manifest.py write"))
        self.assertLess(warmer.index("run: python3 tools/ci/cache_manifest.py write"),
                        warmer.index("uses: actions/cache/save@v4"))
        self.assertNotIn("pull_request", warmer)
        self.assertNotIn("workflow_run", warmer)
        self.assertIn("actions/cache/save@v4", warmer)
        self.assertEqual(2, application.count("actions/cache/restore@v4"))
        self.assertNotIn("actions/cache/save@v4", application)
        self.assertNotIn("pull_request_target", warmer + application)
        key = "app-deps-v3-${{ runner.os }}-${{ runner.arch }}-${{ steps.cache_platform.outputs.image }}-test-${{ hashFiles('.tool-versions', 'mix.lock', 'mix.exs', 'config/**/*.exs', '.github/workflows/application-cache.yml', '.github/workflows/application-ci.yml', 'tools/ci/**') }}"
        self.assertEqual(4, (application + warmer).count(key))

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


class FoundationAggregateExecutionTests(unittest.TestCase):
    def test_aggregate_requires_all_selected_results_and_accepts_only_expected_skips(self):
        import os
        import subprocess
        workflow = (WORKFLOWS / 'foundation-integrity.yml').read_text()
        script = workflow.split('          set -euo pipefail\n', 1)[1]
        script = 'set -euo pipefail\n' + '\n'.join(line[10:] for line in script.splitlines())
        baseline = dict(os.environ, ROUTE_RESULT='success', SMOKE_RESULT='success',
                        APP_REQUIRED='false', APP_RESULT='skipped',
                        AUDIT_REQUIRED='false', AUDIT_RESULT='skipped')
        cases = [({}, True), ({'APP_REQUIRED': 'true', 'APP_RESULT': 'success'}, True)]
        for key in ('ROUTE_RESULT', 'SMOKE_RESULT'):
            for result in ('', 'failure', 'cancelled', 'skipped'):
                cases.append(({key: result}, False))
        for required, result in (('', 'skipped'), ('true', ''), ('true', 'skipped'),
                                 ('true', 'failure'), ('false', ''), ('false', 'success')):
            cases.append(({'APP_REQUIRED': required, 'APP_RESULT': result}, False))
            cases.append(({'AUDIT_REQUIRED': required, 'AUDIT_RESULT': result}, False))
        for changes, expected in cases:
            with self.subTest(changes=changes):
                result = subprocess.run(['bash', '-c', script], env=dict(baseline, **changes),
                                        capture_output=True, text=True)
                self.assertEqual(expected, result.returncode == 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
