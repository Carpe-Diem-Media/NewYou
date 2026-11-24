import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from tools import exunit_shadow as shadow
from tools.foundation_integrity_routing import classify_changed_paths, classify_deep_application_changes


def test_event(file="test/a_test.exs", name="test runs", state="passed"):
    return {"kind": "test", "file": file, "module": "Example", "name": name,
            "parameter": "", "status": state, "us": 10}


def events(*tests):
    modules = {(row["file"], row["module"], row["parameter"]) for row in tests}
    return [*tests, *({"kind": "module", "file": file, "module": module, "parameter": parameter,
                       "status": "passed", "us": 12} for file, module, parameter in sorted(modules)),
            {"kind": "suite", "seed": 17, "max_cases": 4}]


class AllocationTests(unittest.TestCase):
    def test_native_matches_pinned_mix_sorted_stride(self):
        self.assertEqual(shadow.allocate(list("hgafcbde"), {}, 4, "native"),
                         [list("ae"), list("bf"), list("cg"), list("dh")])

    def test_balanced_assigns_longest_first_with_stable_ties_and_unknown_weight(self):
        timings = {"a": 10, "b": 8, "c": 2, "d": 2}
        self.assertEqual(shadow.allocate(list("edcba"), timings, 2, "balanced"),
                         [list("acd"), list("be")])

    def test_empty_shards_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "nonempty"):
            shadow.allocate(["a"], {"a": 10}, 4, "balanced")


class IdentityTests(unittest.TestCase):
    def test_parameter_instances_have_distinct_identities(self):
        first = test_event()
        second = {**first, "parameter": "a" * 64}
        self.assertEqual(len(shadow.identities(events(first, second), 17)), 2)

    def test_fails_closed_on_missing_suite_duplicate_skip_and_wrong_seed(self):
        test = test_event()
        for malformed in ([test], events(test, test), events({**test, "status": "excluded"}),
                          [test, {**events()[-1], "seed": 18}]):
            with self.subTest(malformed=malformed), self.assertRaises(ValueError):
                shadow.identities(malformed, 17)

    def test_same_count_substitution_and_cross_shard_duplicate_rejected(self):
        first, second = test_event(), test_event(name="test other")
        expected = shadow.identities(events(first, second), 17)
        shadow.coverage(expected, [shadow.identities(events(first), 17),
                                   shadow.identities(events(second), 17)])
        for replacement in (first, test_event(name="test substitution")):
            with self.assertRaisesRegex(ValueError, "coverage"):
                shadow.coverage(expected, [shadow.identities(events(first), 17),
                                           shadow.identities(events(replacement), 17)])


class HostedEvidenceTests(unittest.TestCase):
    def test_only_approved_experiment_inputs_are_accepted(self):
        self.assertEqual(shadow.options("WELL-202"), ("all", "cold", 852013, "configured"))
        selector = "<!-- well-202: balanced-6 restore 211963 github -->"
        self.assertEqual(shadow.options(selector), ("balanced-6", "restore", 211963, "github"))
        for body in (selector + "\n" + selector, selector.replace("balanced-6", "balanced-99")):
            with self.subTest(body=body), self.assertRaisesRegex(ValueError, "selector"):
                shadow.options(body)

    def test_verifies_job_artifact_and_candidate_binding(self):
        name = "shadow-balanced-4-1"
        artifact_name = f"{name}-attempt-2"
        binding = {"sha": "exact commit", "tree": "exact tree", "run": "42", "attempt": "2", "head": "PR head"}
        job = {"conclusion": "success", "runner_name": "isolated", "run_id": 42,
               "run_attempt": 2, "head_sha": "PR head",
               "started_at": "2026-11-24T10:00:00Z", "completed_at": "2026-11-24T10:04:00Z"}
        artifact = {"name": artifact_name, "created_at": "2026-11-24T10:03:00Z", "expired": False,
                    "workflow_run": {"id": 42, "head_sha": "PR head", "repository_id": 1,
                                     "head_repository_id": 1}}
        envelope = {**binding, "name": name, "runner": "isolated"}
        with TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / artifact_name
            path.mkdir()
            record = path / "job.json"
            record.write_text(json.dumps(envelope))
            self.assertEqual(shadow.load_evidence(root, name, {name: job},
                                                  {artifact_name: artifact}, binding)[1], envelope)
            for result in ("failure", "cancelled", "skipped", None):
                with self.subTest(result=result), self.assertRaisesRegex(ValueError, "job"):
                    shadow.load_evidence(root, name, {name: {**job, "conclusion": result}},
                                         {artifact_name: artifact}, binding)
            for bad_artifact in ({}, {artifact_name: {**artifact, "created_at": "2026-11-23"}}):
                with self.subTest(artifact=bad_artifact), self.assertRaisesRegex(ValueError, "artifact"):
                    shadow.load_evidence(root, name, {name: job}, bad_artifact, binding)
            for key in ("attempt", "run", "sha", "tree", "runner"):
                record.write_text(json.dumps({**envelope, key: "incorrect"}))
                with self.subTest(key=key), self.assertRaisesRegex(ValueError, "wrong candidate"):
                    shadow.load_evidence(root, name, {name: job}, {artifact_name: artifact}, binding)

    def test_shadow_paths_preserve_routed_required_application_ci(self):
        paths = [".github/workflows/exunit-shadow.yml", ".github/actions/exunit-shadow-setup/action.yml",
                 "test/support/shadow_benchmark_formatter.ex", "tools/exunit_shadow.py",
                 "tests/test_exunit_shadow.py"]
        self.assertEqual(classify_changed_paths(paths), {"application_changes": True})
        self.assertFalse(classify_deep_application_changes(paths))


if __name__ == "__main__":
    unittest.main()
