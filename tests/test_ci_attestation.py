from __future__ import annotations

import copy
import unittest

from tools.ci_attestation import AttestationError, verify_candidate, verify_result


def evidence():
    return {
        "pr": 42,
        "head": "a" * 40,
        "base": "b" * 40,
        "candidate": "c" * 40,
        "tree": "d" * 40,
        "candidate_parents": ["b" * 40, "a" * 40],
        "current_head": "a" * 40,
        "current_base": "b" * 40,
        "premerge_main": "b" * 40,
        "run_head": "a" * 40,
        "run_event": "pull_request",
        "run_pr": 42,
        "required_check": {"id": 12, "name": "Foundation Integrity", "status": "completed", "conclusion": "success"},
        "checkout_shas": ["c" * 40, "c" * 40],
        "trust_mode": "private-procedural",
        "repository": {"full_name": "JCSchoeman96/NewYou", "private": True,
                       "visibility": "private", "default_branch": "main"},
        "branch": {"name": "main", "protected": False},
        "reviewed_head": "a" * 40,
    }


class CandidateAttestationTest(unittest.TestCase):
    def test_review_record_requires_independent_review_reference_and_exact_head(self):
        from tools.ci_attestation import validate_review_record
        record = {"reviewed_head": "a" * 40, "reviewer": "reviewer",
                  "review_reference": "https://example.test/review/42",
                  "diff_sha256": "b" * 64}
        validate_review_record(record, "a" * 40)
        for change in ({"reviewed_head": "e" * 40}, {"reviewer": ""},
                       {"review_reference": ""}, {"diff_sha256": "bad"}):
            with self.subTest(change=change), self.assertRaises(AttestationError):
                validate_review_record(dict(record, **change), "a" * 40)

    def test_current_candidate_passes(self):
        verify_candidate(evidence())

    def test_stale_or_missing_evidence_fails_closed(self):
        for key, value in [
            ("current_head", "e" * 40), ("current_base", "e" * 40),
            ("premerge_main", "e" * 40), ("run_head", "e" * 40), ("run_event", "push"),
            ("run_pr", 41), ("reviewed_head", "e" * 40),
            ("candidate_parents", ["b" * 40, "e" * 40]),
            ("checkout_shas", ["c" * 40, "e" * 40]), ("checkout_shas", []),
            ("trust_mode", None), ("repository", {}), ("branch", {}), ("required_check", None),
        ]:
            with self.subTest(key=key, value=value):
                data = evidence()
                data[key] = value
                with self.assertRaises(AttestationError):
                    verify_candidate(data)

    def test_skipped_failed_and_pending_required_checks_fail(self):
        for conclusion in ["skipped", "failure", "neutral", None]:
            data = evidence()
            data["required_check"]["conclusion"] = conclusion
            with self.subTest(conclusion=conclusion), self.assertRaises(AttestationError):
                verify_candidate(data)

    def test_resulting_main_requires_merge_parents_exact_tree_and_no_drift(self):
        data = evidence()
        result = {"method": "merge", "merge_sha": "f" * 40, "main": "f" * 40,
                  "parents": [data["base"], data["head"]], "tree": data["tree"]}
        verify_result(data, result)
        for key, value in [("method", "squash"), ("method", "rebase"), ("method", "unknown"),
                           ("main", "e" * 40), ("tree", "e" * 40),
                           ("parents", [data["base"]]), ("merge_sha", None)]:
            changed = copy.deepcopy(result)
            changed[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(AttestationError):
                verify_result(data, changed)

class CheckoutLogTest(unittest.TestCase):
    def test_extracts_only_a_complete_checkout_record(self):
        from tools.ci_attestation import checkout_from_log
        sha = "c" * 40
        log = f"job\tstep\ttime [command]/usr/bin/git log -1 --format=%H\njob\tstep\ttime {sha}\n"
        self.assertEqual(sha, checkout_from_log(log))
        for invalid in ["", sha, log + log, log.replace(sha, sha[:7])]:
            with self.subTest(log=invalid), self.assertRaises(AttestationError):
                checkout_from_log(invalid)

class GitHubCollectionTest(unittest.TestCase):
    def setUp(self):
        from unittest.mock import patch
        self.patch = patch
        self.e = evidence()
        self.run = {"id": 100, "path": ".github/workflows/foundation-integrity.yml", "status": "completed",
                    "event": "pull_request", "head_sha": self.e["head"], "run_attempt": 1,
                    "check_suite_id": 77, "pull_requests": [{"number": 42}]}
        self.pr = {"merged": False, "state": "open", "head": {"sha": self.e["head"]},
                   "base": {"sha": self.e["base"], "ref": "main"},
                   "merge_commit_sha": self.e["candidate"]}
        self.jobs = [{"id": 1, "name": "Route CI lanes", "status": "completed", "conclusion": "success"},
                     {"id": 2, "name": "Foundation Smoke", "status": "completed", "conclusion": "success"},
                     {"id": 12, "name": "Foundation Integrity", "status": "completed", "conclusion": "success"}]
        self.check = dict(self.e["required_check"], app={"slug": "github-actions"},
                          check_suite={"id": 77}, head_sha=self.e["head"])
        self.commit = {"tree": {"sha": self.e["tree"]},
                       "parents": [{"sha": x} for x in self.e["candidate_parents"]]}
        self.repository = self.e["repository"].copy()
        self.branch = self.e["branch"].copy()

    def api(self, path):
        if path == "repos/JCSchoeman96/NewYou":
            return self.repository
        if path.endswith("branches/main"):
            return self.branch
        if path.endswith("pulls/42"):
            return self.pr
        if path.endswith("commits/main"):
            return {"sha": self.e["base"]}
        if path.endswith("actions/runs/100"):
            return self.run
        if "/workflows/" in path:
            return {"total_count": 1, "workflow_runs": [self.run]}
        if "/attempts/" in path:
            return {"total_count": len(self.jobs), "jobs": self.jobs}
        if path.endswith("check-runs/12"):
            return self.check
        if "/git/commits/" in path:
            return self.commit
        raise AssertionError(path)

    def log(self, *args):
        return f"job\tstep\ttime [command]/usr/bin/git log -1 --format=%H\njob\tstep\ttime {self.e['candidate']}\n"

    def test_private_procedural_mode_requires_explicit_verified_identity(self):
        from tools.ci_attestation import verify_trust_mode
        repo = {"full_name": "JCSchoeman96/NewYou", "private": True,
                "visibility": "private", "default_branch": "main"}
        branch = {"name": "main", "protected": False}
        verify_trust_mode("private-procedural", repo, branch)
        for mode, repository, current_branch in [
            (None, repo, branch), ("unknown", repo, branch),
            ("private-procedural", {}, branch),
            ("private-procedural", dict(repo, full_name="other/repo"), branch),
            ("private-procedural", dict(repo, private=False), branch),
            ("private-procedural", dict(repo, visibility="public"), branch),
            ("private-procedural", repo, {}),
            ("private-procedural", None, branch),
            ("private-procedural", repo, None),
            ("private-procedural", repo, dict(branch, protected=True)),
        ]:
            with self.subTest(mode=mode, repo=repository, branch=current_branch):
                with self.assertRaises(AttestationError):
                    verify_trust_mode(mode, repository, current_branch)

    def collect(self):
        from tools.ci_attestation import collect
        with self.patch("tools.ci_attestation._api", side_effect=self.api), self.patch("tools.ci_attestation._command", side_effect=self.log):
            return collect(42, self.e["head"], 100, trust_mode="private-procedural")

    def test_collector_binds_live_run_checks_and_checkout(self):
        result = self.collect()
        self.assertEqual(result["candidate"], self.e["candidate"])
        self.assertEqual(result["job_ids"], [1, 2])
        self.assertEqual(result["check_suite_id"], 77)

    def test_collector_requires_opt_in_and_rejects_api_failure(self):
        from tools.ci_attestation import collect
        with self.assertRaises(AttestationError):
            collect(42, self.e["head"], 100)
        with self.patch("tools.ci_attestation._api", side_effect=AttestationError("API failure")):
            with self.assertRaises(AttestationError):
                collect(42, self.e["head"], 100, trust_mode="private-procedural")

    def test_superseded_run_cannot_be_reused(self):
        old_api = self.api
        def api(path):
            if "/workflows/" in path:
                newer = dict(self.run, id=101)
                return {"total_count": 2, "workflow_runs": [newer, self.run]}
            return old_api(path)
        with self.patch("tools.ci_attestation._api", side_effect=api), self.patch("tools.ci_attestation._command", side_effect=self.log):
            from tools.ci_attestation import collect
            with self.assertRaises(AttestationError):
                collect(42, self.e["head"], 100, trust_mode="private-procedural")

    def test_nonblocking_full_does_not_delay_required_proof(self):
        self.run["status"] = "in_progress"
        self.jobs.append({"id": 99, "name": "Foundation Full / Foundation Full",
                          "status": "in_progress", "conclusion": None})
        result = self.collect()
        self.assertEqual(result["required_check"]["conclusion"], "success")

    def test_candidate_checkout_mismatch_is_rejected(self):
        self.e["candidate"] = "e" * 40
        with self.assertRaises(AttestationError):
            self.collect()

    def test_collector_rejects_wrong_source_and_missing_or_failed_jobs(self):
        mutations = [
            lambda: self.pr.update(state="closed"),
            lambda: self.run.update(head_sha="e" * 40),
            lambda: self.check.update(app={"slug": "other"}),
            lambda: self.check.update(check_suite={"id": 99}),
            lambda: self.jobs[1].update(conclusion="skipped"),
            lambda: self.repository.update(visibility="public"),
            lambda: self.branch.update(protected=True),
        ]
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                self.setUp()
                mutate()
                with self.assertRaises(AttestationError):
                    self.collect()

class ResultCollectionTest(GitHubCollectionTest):
    def test_postmerge_rechecks_live_run_and_exact_main_tree(self):
        from tools.ci_attestation import collect
        old_api = self.api
        merge_sha = "f" * 40
        self.pr.update(merged=True, state="closed", merge_commit_sha=merge_sha)
        self.run["pull_requests"] = []
        def api(path):
            if path.endswith("commits/main"):
                return {"sha": merge_sha}
            if path.endswith("git/commits/" + merge_sha):
                return self.commit
            return old_api(path)
        with self.patch("tools.ci_attestation._api", side_effect=api), self.patch("tools.ci_attestation._command", side_effect=self.log):
            result = collect(42, self.e["head"], 100, candidate_sha=self.e["candidate"], after_merge=True,
                             trust_mode="private-procedural")
        self.assertEqual(result["result"]["main"], merge_sha)
        self.assertEqual(result["result"]["tree"], self.e["tree"])
