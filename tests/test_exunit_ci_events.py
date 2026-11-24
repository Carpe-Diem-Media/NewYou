"""Exercise the production verifier with the real pinned ExUnit event manager."""

from collections import Counter
import json
import os
from pathlib import Path
import shlex
import subprocess
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from tools import exunit_ci as ci


class ExUnitEventTests(unittest.TestCase):
    def events(self, mode, profile, exit_code, names="only"):
        with TemporaryDirectory() as directory:
            output = Path(directory) / "events.jsonl"
            command = shlex.split(os.environ.get("CI_EVENT_ELIXIR", "elixir"))
            result = subprocess.run(
                [*command, "-r", "test/support/ci_exunit_formatter.ex",
                 "tools/ci/fixtures/exunit_events.exs"],
                env=dict(os.environ, NEWYOU_CI_TEST_MODE=mode, NEWYOU_CI_TEST_EVENTS=str(output),
                         NEWYOU_FIXTURE_PROFILE=profile, NEWYOU_FIXTURE_NAMES=names),
                capture_output=True, text=True, timeout=30,
            )
            self.assertEqual(result.returncode, exit_code, result.stdout + result.stderr)
            self.assertTrue(output.exists(), result.stdout + result.stderr)
            return ci.read_events(output)

    def test_dry_run_declares_without_execution_and_real_run_covers_generated_parameters(self):
        plan = self.events("discover", "pass", 0)
        execution = self.events("execute", "pass", 0)
        expected, _, _ = ci.observe(plan, "discover", 17)
        actual, timings, _ = ci.observe(execution, "execute", 17)
        self.assertFalse(any(row["kind"] == "finished" for row in plan))
        self.assertEqual(expected, actual)
        self.assertEqual(len(actual), 6)
        self.assertEqual(len({key[3] for key in actual}), 2)
        self.assertGreater(sum(timings.values()), 0)
        completed = next(row for row in execution if row["kind"] == "finished")
        execution.remove(completed)
        with self.assertRaisesRegex(ValueError, "execution differs"):
            ci.observe(execution, "execute", 17)

    def test_partial_filters_and_skips_survive_module_finished(self):
        expected, _, _ = ci.observe(self.events("discover", "filtered", 0), "discover", 17)
        execution = self.events("execute", "filtered", 0)
        self.assertEqual(len(expected), 8)
        outcomes = Counter(row["status"] for row in execution if row["kind"] == "finished")
        self.assertEqual(outcomes, {"passed": 4, "excluded": 2, "skipped": 2})
        with self.assertRaisesRegex(ValueError, "ExUnit (excluded|skipped)"):
            ci.observe(execution, "execute", 17)

    def test_invalid_setup_is_an_outcome_and_cannot_certify(self):
        execution = self.events("execute", "invalid", 2)
        self.assertTrue(any(row.get("status") == "invalid" for row in execution))
        with self.assertRaisesRegex(ValueError, "ExUnit (failed|invalid)"):
            ci.observe(execution, "execute", 17)


    def test_complete_eight_shard_verifier_uses_real_events_and_rejects_a_missing_completion(self):
        names = [f"case{n}" for n in range(1, 9)]
        declared = self.events("discover", "pass", 0, ",".join(names))
        completed = self.events("execute", "pass", 0, ",".join(names))
        expected, _, _ = ci.observe(declared, "discover", 17)
        files = {key[0]: "a" * 40 for key in expected}
        groups, predicted = ci.allocate({file: 1 for file in files})
        binding = {"run": 1, "attempt": 2, "head": "head", "base": "base", "sha": "candidate",
                   "tree": "tree", "repository": "owner/project"}
        jobs, artifacts = [], []

        with TemporaryDirectory() as directory:
            root = Path(directory)
            stamp = "2026-11-24T10:00:00Z"

            def job(name, evidence=None, rows=None):
                jobs.append({"name": ci.CAPACITY + name, "id": len(jobs) + 1,
                             "conclusion": "success", "head_sha": "head", "run_id": 1,
                             "run_attempt": 2, "runner_name": name, "created_at": stamp,
                             "started_at": stamp, "completed_at": stamp,
                             "steps": [{"name": "Prepare isolated test environment",
                                        "started_at": stamp, "completed_at": stamp}]})
                if evidence is None:
                    return
                path = root / f"{evidence}-attempt-2"
                path.mkdir()
                artifacts.append({"name": path.name, "expired": False, "created_at": stamp,
                                  "workflow_run": {"id": 1, "head_sha": "head",
                                                   "repository_id": 2, "head_repository_id": 2}})
                env = {**binding, "runner": name, "seed": 17, "allocation": name,
                       "profile": {"image": "ubuntu-v1"}, "cache_key": "", "cache_result": "cold"}
                (path / "job.json").write_text(json.dumps(env))
                (path / "events.jsonl").write_text("\n".join(map(json.dumps, rows)))
                return path

            discovery = job("Discover application tests", "application-evidence-plan", declared)
            (discovery / "plan.json").write_text(json.dumps({
                "files": files, "shards": groups, "predicted": predicted, "seed": 17,
                "identities": sorted(expected), "weight_counts": {}, "source": "fixture",
                "timing_generated_at": None,
            }))
            job("Static application checks")
            for index, group in enumerate(groups, 1):
                subset = [row for row in completed[:-1]
                          if (row["identity"][0] if "identity" in row else row["file"]) in group]
                job(f"Test shard {index}", f"application-evidence-{index}", [*subset, completed[-1]])
            report = root / "report.json"
            with (patch.object(ci, "candidate", return_value=binding),
                  patch.object(ci, "fingerprint", return_value=files),
                  patch.object(ci, "github", side_effect=[{"jobs": jobs}, {"artifacts": artifacts}]),
                  patch.dict(os.environ, GITHUB_REPOSITORY_ID="2", CI_HEAD_REPOSITORY="2")):
                ci.verify(root, report)
            self.assertEqual(json.loads(report.read_text())["tests"], 48)

            shard = root / "application-evidence-8-attempt-2/events.jsonl"
            rows = ci.read_events(shard)
            rows.remove(next(row for row in rows if row["kind"] == "finished"))
            shard.write_text("\n".join(map(json.dumps, rows)))
            with (patch.object(ci, "candidate", return_value=binding),
                  patch.object(ci, "fingerprint", return_value=files),
                  patch.object(ci, "github", side_effect=[{"jobs": jobs}, {"artifacts": artifacts}]),
                  patch.dict(os.environ, GITHUB_REPOSITORY_ID="2", CI_HEAD_REPOSITORY="2")):
                with self.assertRaisesRegex(ValueError, "execution differs"):
                    ci.verify(root, report)


if __name__ == "__main__":
    unittest.main()
