from datetime import datetime, timedelta, timezone
import unittest
from unittest.mock import patch

from tools import exunit_ci as ci, exunit_timing as timing


NOW = datetime.now(timezone.utc)
A = "test/a_test.exs"
B = "test/b_test.exs"
C = "test/c_test.exs"
OLD = "a" * 40
NEW = "b" * 40
PROFILE = {"image": "pinned", "cpus": 2, "graph": "locked"}
PUBLISHER = {"sha": "c" * 40, "run": 30, "attempt": 1}
REPO = "owner/project"
HEAD = "d" * 40
BASE = "e" * 40
PR = 17
TREE = "1" * 40


def report(weights, **overrides):
    example = {
        "version": 1, "verdict": "complete", "comparable": True, "tests": 8,
        "shards": [{"shard": n} for n in range(1, 9)], "profile": PROFILE,
        "head": HEAD, "base": BASE, "tree": TREE, "sha": "2" * 40,
        "run": 20, "attempt": 1, "pr": PR, "repository": REPO,
        "files": {path: {"blob": OLD, "us": weight * 1_000_000} for path, weight in weights.items()},
    }
    return {**example, **overrides}


class TimingTests(unittest.TestCase):
    def update(self, weights, previous=None):
        return timing.observe_success(previous, report(weights), PUBLISHER, NOW.isoformat())

    def test_unknown_changed_renamed_and_deleted_files_are_scheduled_from_current_inventory(self):
        snapshot = self.update({A: 60, B: 10})
        files = {A: NEW, C: OLD}
        weights, counts = timing.weights(files, snapshot)
        self.assertEqual(set(weights), set(files))
        self.assertEqual(counts, {"measured": 0, "changed": 1, "new_or_unmeasured": 1, "fallback": 2})
        self.assertEqual(weights[A], 60_000_000)
        self.assertGreater(weights[C], 0)
        self.assertEqual(ci.allocate(weights, 2)[0], [[A], [C]])
        self.assertEqual(set(timing.weights(files, None)[0]), set(files))

    def test_rolling_history_consumed_by_subsequent_allocation(self):
        first = self.update({A: 14, B: 10, C: 6})
        shifted = first
        for _ in range(6):
            shifted = self.update({A: 6, B: 30, C: 22}, shifted)
        self.assertEqual(shifted["files"][B]["samples"], [30_000_000] * 5)
        files = {p: OLD for p in (A, B, C)}
        self.assertEqual(ci.allocate(timing.weights(files, first)[0], 2)[0], [[A], [B, C]])
        self.assertEqual(ci.allocate(timing.weights(files, shifted)[0], 2)[0], [[B], [A, C]])
        old = self.update({A: 10})
        with_outlier = self.update({A: 600}, self.update({A: 12}, old))
        self.assertEqual(timing.weights({A: OLD}, with_outlier)[0][A], 12_000_000)

    def test_nonfinite_negative_expired_and_incomplete_are_rejected(self):
        sample = self.update({A: 10})
        for invalid in (-1, 0, float("nan"), float("inf"), True):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                timing.validate({**sample, "files": {A: {"blob": OLD, "samples": [invalid]}}},
                                timing.LIFETIME)
        with self.assertRaisesRegex(ValueError, "stale"):
            timing.validate(sample, timing.LIFETIME, NOW + timedelta(days=22))
        for override in ({"comparable": False}, {"verdict": "failed"}, {"shards": []}):
            with self.assertRaisesRegex(ValueError, "cohort"):
                timing.observe_success(None, report({A: 10}, **override), PUBLISHER, NOW.isoformat())


class TrustedPublicationTests(unittest.TestCase):
    def test_integrated_report_uses_required_attempt_and_exact_candidate_tree(self):
        result = report({A: 60})
        attempt = 1
        run = {"id": 20, "head_sha": HEAD, "path": ".github/workflows/foundation-integrity.yml",
               "event": "pull_request", "conclusion": "success", "run_attempt": attempt,
               "updated_at": "2026-11-24T12:00:00Z", "pull_requests": []}
        jobs = [{"name": name, "conclusion": "success", "run_id": 20, "run_attempt": attempt,
                 "head_sha": HEAD}
                for name in ["Foundation Integrity", "Application CI / Verify application coverage",
                             "Application CI / Discover application tests",
                             "Application CI / Static application checks",
                             *(f"Application CI / Test shard {n}" for n in range(1, 9))]]

        def api(path):
            if "/pulls?" in path:
                return [{"number": PR, "merged_at": "2026-11-24T12:01:00Z",
                         "merge_commit_sha": PUBLISHER["sha"], "head": {"sha": HEAD},
                         "base": {"ref": "main"}}]
            if "/workflows/" in path:
                return {"workflow_runs": [run]}
            if "/jobs?" in path:
                return {"jobs": jobs}
            return {"commit": {"tree": {"sha": TREE}}, "parents": [{"sha": BASE}, {"sha": HEAD}]}

        with patch.object(timing, "artifact", return_value=result):
            self.assertEqual(timing.integrated_report(api, REPO, PUBLISHER["sha"], BASE, HEAD, TREE),
                             result)
            jobs[-1]["run_attempt"] = 2
            with self.assertRaisesRegex(ValueError, "no complete"):
                timing.integrated_report(api, REPO, PUBLISHER["sha"], BASE, HEAD, TREE)

    def test_only_fresh_main_ancestor_with_compatible_profile_is_consumed(self):
        snapshot = timing.observe_success(None, report({A: 16}), PUBLISHER, NOW.isoformat())
        run = {"id": 30, "head_branch": "main", "head_sha": PUBLISHER["sha"], "run_attempt": 1,
               "event": "push", "conclusion": "success", "path": ".github/workflows/application-timing.yml"}
        relationship = {"status": "ahead"}

        def api(path):
            return relationship if "/compare/" in path else {"workflow_runs": [run]}

        with patch.object(timing, "artifact", return_value=snapshot):
            data, provenance = timing.trusted_snapshot(api, REPO, BASE, PROFILE)
            self.assertIn("verified run 20", provenance)
            self.assertEqual(timing.weights({A: OLD}, data)[0][A], 16_000_000)
            self.assertIsNone(timing.trusted_snapshot(api, REPO, BASE, {**PROFILE, "cpus": 4})[0])
            relationship["status"] = "diverged"
            self.assertIsNone(timing.trusted_snapshot(api, REPO, BASE, PROFILE)[0])
            relationship["status"] = "ahead"
            snapshot["generated_at"] = (NOW - timedelta(days=30)).isoformat()
            self.assertIsNone(timing.trusted_snapshot(api, REPO, BASE, PROFILE)[0])


if __name__ == "__main__":
    unittest.main()
