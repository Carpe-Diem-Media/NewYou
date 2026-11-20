"""Regression checks for the optional ExUnit benchmark evidence."""

import copy
import unittest

from tools import exunit_shadow as shadow
from tools.foundation_integrity_routing import (
    classify_changed_paths,
    classify_deep_application_changes,
    classify_hex_audit_changes,
)


class ShadowEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.files = ["test/a_test.exs", "test/b_test.exs", "test/c_test.exs"]
        self.jobs = {}
        self.artifacts = {}
        for seed in shadow.SEEDS:
            for mode in shadow.MODES:
                job = shadow.job_name(seed, mode)
                self.jobs[job] = {
                    "name": job,
                    "conclusion": "success",
                    "started_at": "2026-11-20T12:00:00Z",
                    "completed_at": "2026-11-20T12:10:00Z",
                    "steps": [{"name": "Run benchmark", "started_at": "2026-11-20T12:01:00Z",
                               "completed_at": "2026-11-20T12:09:00Z"}],
                }
                files = shadow.select(self.files, mode)
                self.artifacts[job] = {
                    "metadata": {
                        "sha": "a" * 40, "seed": seed, "mode": mode, "image": "ubuntu24-example",
                        "arch": "X64", "cpus": 4, "cache": "cold", "files": shadow.digest(files),
                        "run_id": "42", "attempt": "1",
                    },
                    "events": [
                        *({"kind": "test", "file": file, "module": "Example",
                           "name": "test case", "status": "passed", "us": 20} for file in files),
                        *({"kind": "module", "file": file, "module": "Example",
                           "status": "passed", "us": 30} for file in files),
                        {"kind": "suite", "load": 50, "run": 100, "async": 30, "seed": seed,
                         "max_cases": 8},
                    ],
                }

    def verify(self):
        return shadow.verify(self.files, self.jobs, self.artifacts, "a" * 40, "42", "1")

    def test_disjoint_suite_and_comparable_pairs_pass(self):
        result = self.verify()
        self.assertEqual(set(shadow.SEEDS), set(result))
        self.assertEqual(3, result[shadow.SEEDS[0]]["control"]["tests"])

    def test_missing_job_or_artifact_is_detected(self):
        job = shadow.job_name(shadow.SEEDS[0], "shard-2")
        with self.subTest("job"):
            saved = self.jobs.pop(job)
            with self.assertRaisesRegex(ValueError, "missing job"):
                self.verify()
            self.jobs[job] = saved
        with self.subTest("artifact"):
            self.artifacts.pop(job)
            with self.assertRaisesRegex(ValueError, "missing artifact"):
                self.verify()

    def test_non_success_jobs_are_detected_even_with_artifacts(self):
        job = shadow.job_name(shadow.SEEDS[0], "shard-2")
        for conclusion in ("failure", "skipped", "cancelled", None):
            with self.subTest(conclusion=conclusion):
                self.jobs[job]["conclusion"] = conclusion
                with self.assertRaisesRegex(ValueError, "job conclusion"):
                    self.verify()

    def test_duplicate_and_missing_test_identity_are_detected(self):
        job = shadow.job_name(shadow.SEEDS[0], "shard-1")
        events = self.artifacts[job]["events"]
        duplicate = copy.copy(events[0])
        events.insert(1, duplicate)
        with self.assertRaisesRegex(ValueError, "duplicate test identity"):
            self.verify()
        events.pop(1)
        events[0]["name"] = "test different assertion"
        with self.assertRaisesRegex(ValueError, "test identities differ"):
            self.verify()

    def test_records_with_non_passing_outcomes_are_detected(self):
        job = shadow.job_name(shadow.SEEDS[0], "shard-1")
        event = self.artifacts[job]["events"][0]
        for status in ("failed", "skipped", "invalid", "excluded"):
            with self.subTest(status=status):
                event["status"] = status
                with self.assertRaisesRegex(ValueError, "non-passing test"):
                    self.verify()

    def test_evidence_binding_and_runner_drift_are_detected(self):
        job = shadow.job_name(shadow.SEEDS[0], "shard-2")
        metadata = self.artifacts[job]["metadata"]
        for key in ("sha", "attempt", "files", "image", "cache"):
            with self.subTest(key=key):
                old = metadata[key]
                metadata[key] = "wrong"
                with self.assertRaisesRegex(ValueError, "binding|runner"):
                    self.verify()
                metadata[key] = old

    def test_wrong_file_assignment_does_not_pass_with_matching_test_count(self):
        job = shadow.job_name(shadow.SEEDS[0], "shard-1")
        self.artifacts[job]["events"][0]["file"] = self.files[1]
        with self.assertRaisesRegex(ValueError, "unexpected test file"):
            self.verify()

    def test_missing_suite_completion_is_detected(self):
        job = shadow.job_name(shadow.SEEDS[0], "control")
        self.artifacts[job]["events"].pop()
        with self.assertRaisesRegex(ValueError, "suite completion"):
            self.verify()

    def test_shadow_changes_keep_the_required_application_and_hex_routes(self):
        files = [".github/workflows/exunit-shadow.yml", "tools/exunit_shadow.py"]
        for path in files:
            with self.subTest(path=path):
                self.assertEqual({"application_changes": True}, classify_changed_paths([path]))
                self.assertFalse(classify_deep_application_changes([path]))
                self.assertTrue(classify_hex_audit_changes([path]))
