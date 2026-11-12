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
        "repository": {"id": 1332946467, "full_name": "Carpe-Diem-Media/NewYou", "private": True,
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
        if path == "repos/Carpe-Diem-Media/NewYou":
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
        repo = {"id": 1332946467, "full_name": "Carpe-Diem-Media/NewYou", "private": True,
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

    def test_public_protected_mode_requires_live_applicable_ruleset_and_effective_rules(self):
        from tools.ci_attestation import verify_trust_mode
        repo = {"id": 1332946467, "full_name": "Carpe-Diem-Media/NewYou", "private": False,
                "visibility": "public", "default_branch": "main"}
        branch = {"name": "main", "protected": True}
        ruleset = {
            "id": 24191860, "name": "Protect main", "enforcement": "active",
            "source": "Carpe-Diem-Media/NewYou", "source_type": "Repository",
            "current_user_can_bypass": "never",
            "target": "branch", "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
            "bypass_actors": [],
            "rules": [
                {"type": "required_status_checks", "parameters": {
                    "strict_required_status_checks_policy": True,
                    "required_status_checks": [{"context": "Foundation Integrity"}]}},
                {"type": "non_fast_forward"}, {"type": "deletion"},
                {"type": "pull_request", "parameters": {"allowed_merge_methods": ["merge", "squash", "rebase"]}},
            ],
        }
        effective_rules = [
            {"type": rule["type"], "parameters": rule.get("parameters", {}),
             "ruleset_id": ruleset["id"], "ruleset_source": "Carpe-Diem-Media/NewYou",
             "ruleset_source_type": "Repository"}
            for rule in ruleset["rules"]
        ]

        verify_trust_mode("public-protected", repo, branch, ruleset, effective_rules)

        cases = [
            ("missing ruleset", None, effective_rules),
            ("inactive ruleset", dict(ruleset, enforcement="disabled"), effective_rules),
            ("wrong branch condition", dict(ruleset, conditions={"ref_name": {"include": ["refs/heads/release"], "exclude": []}}), effective_rules),
            ("null conditions", dict(ruleset, conditions=None), effective_rules),
            ("missing strict check", dict(ruleset, rules=[
                rule for rule in ruleset["rules"] if rule["type"] != "required_status_checks"]), effective_rules),
            ("wrong required check", dict(ruleset, rules=[
                dict(rule, parameters=dict(rule["parameters"], required_status_checks=[{"context": "Other Check"}]))
                if rule["type"] == "required_status_checks" else rule for rule in ruleset["rules"]]), effective_rules),
            ("bypass actor", dict(ruleset, bypass_actors=[{"actor_type": "RepositoryRole", "actor_id": 5, "bypass_mode": "always"}]), effective_rules),
            ("configured pull request rule missing parameters", dict(ruleset, rules=[
                {"type": rule["type"]} if rule["type"] == "pull_request" else rule
                for rule in ruleset["rules"]]), effective_rules),
            ("effective pull request rule missing parameters", ruleset, [
                {key: value for key, value in rule.items() if key != "parameters"}
                if rule["type"] == "pull_request" else rule for rule in effective_rules]),
            ("effective permissions omit deletion restriction", ruleset,
             [rule for rule in effective_rules if rule["type"] != "deletion"]),
        ]
        for label, active_ruleset, active_rules in cases:
            with self.subTest(case=label), self.assertRaises(AttestationError):
                verify_trust_mode("public-protected", repo, branch, active_ruleset, active_rules)

        for mode, repository, current_branch in [
            ("private-procedural", repo, branch),
            ("public-protected", dict(repo, full_name="other/repo"), branch),
            ("public-protected", dict(repo, private=True, visibility="private"), branch),
            ("public-protected", repo, dict(branch, name="release")),
            ("public-protected", repo, dict(branch, protected=False)),
        ]:
            with self.subTest(mode=mode, repo=repository, branch=current_branch), self.assertRaises(AttestationError):
                verify_trust_mode(mode, repository, current_branch, ruleset, effective_rules)

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

    def test_pr_attestation_requires_no_foundation_full_job(self):
        self.assertFalse(any(job["name"].startswith("Foundation Full") for job in self.jobs))
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


class PublicProtectedCollectionTest(unittest.TestCase):
    def setUp(self):
        GitHubCollectionTest.setUp(self)
        self.repository.update(private=False, visibility="public")
        self.branch.update(protected=True)
        self.ruleset = {
            "id": 24191860, "name": "Protect main", "target": "branch",
            "source_type": "Repository", "source": "Carpe-Diem-Media/NewYou",
            "enforcement": "active", "current_user_can_bypass": "never", "bypass_actors": [],
            "conditions": {"ref_name": {"exclude": [], "include": ["~DEFAULT_BRANCH"]}},
            "rules": [
                {"type": "pull_request", "parameters": {"allowed_merge_methods": ["merge", "squash", "rebase"]}},
                {"type": "required_status_checks", "parameters": {
                    "strict_required_status_checks_policy": True,
                    "do_not_enforce_on_create": False,
                    "required_status_checks": [{"context": "Foundation Integrity"}]}},
                {"type": "non_fast_forward"}, {"type": "deletion"},
            ],
        }
        self.effective_rules = [
            {"type": rule["type"], "parameters": rule.get("parameters", {}),
             "ruleset_id": 24191860, "ruleset_source": "Carpe-Diem-Media/NewYou",
             "ruleset_source_type": "Repository"}
            for rule in self.ruleset["rules"]
        ]

    def log(self, *args):
        return GitHubCollectionTest.log(self, *args)

    def api(self, path):
        if path == "repos/Carpe-Diem-Media/NewYou/rulesets/24191860":
            return copy.deepcopy(self.ruleset)
        if path == "repos/Carpe-Diem-Media/NewYou/rules/branches/main":
            return copy.deepcopy(self.effective_rules)
        return GitHubCollectionTest.api(self, path)

    def collect_public(self):
        from tools.ci_attestation import collect
        with self.patch("tools.ci_attestation._api", side_effect=self.api), \
                self.patch("tools.ci_attestation._api_rules", side_effect=self.api), \
                self.patch("tools.ci_attestation._command", side_effect=self.log):
            return collect(42, self.e["head"], 100, trust_mode="public-protected")

    def test_public_collection_binds_current_ruleset_and_effective_rules(self):
        result = self.collect_public()
        self.assertEqual(result["ruleset"], self.ruleset)
        self.assertEqual(result["effective_rules"], self.effective_rules)
        self.assertEqual(result["candidate"], self.e["candidate"])

    def test_public_collection_rejects_different_repository_id(self):
        self.repository['id'] = 1
        with self.assertRaises(AttestationError):
            self.collect_public()

    def test_public_collection_rejects_rule_api_errors_and_rule_changes(self):
        from tools.ci_attestation import AttestationError
        for failing_path in ("rulesets/24191860", "rules/branches/main"):
            with self.subTest(api=failing_path):
                def failing_api(path):
                    if path.endswith(failing_path):
                        raise AttestationError("API failure")
                    return self.api(path)
                with self.patch("tools.ci_attestation._api", side_effect=failing_api), \
                        self.patch("tools.ci_attestation._api_rules", side_effect=failing_api), \
                        self.patch("tools.ci_attestation._command", side_effect=self.log):
                    from tools.ci_attestation import collect
                    with self.assertRaises(AttestationError):
                        collect(42, self.e["head"], 100, trust_mode="public-protected")

        for failing_path in ("rulesets/24191860", "rules/branches/main"):
            reads = 0
            def failing_fresh_api(path):
                nonlocal reads
                if path.endswith(failing_path):
                    reads += 1
                    if reads > 1:
                        raise AttestationError("fresh rules API failure")
                return self.api(path)
            with self.subTest(fresh_api=failing_path), \
                    self.patch("tools.ci_attestation._api", side_effect=failing_fresh_api), \
                    self.patch("tools.ci_attestation._api_rules", side_effect=failing_fresh_api), \
                    self.patch("tools.ci_attestation._command", side_effect=self.log):
                from tools.ci_attestation import collect
                with self.assertRaises(AttestationError):
                    collect(42, self.e["head"], 100, trust_mode="public-protected")

        ruleset_reads = 0
        def changing_rules(path):
            nonlocal ruleset_reads
            if path.endswith("rulesets/24191860"):
                ruleset_reads += 1
                current = copy.deepcopy(self.ruleset)
                if ruleset_reads > 1:
                    current["enforcement"] = "disabled"
                return current
            return self.api(path)
        with self.patch("tools.ci_attestation._api", side_effect=changing_rules), \
                self.patch("tools.ci_attestation._api_rules", side_effect=changing_rules), \
                self.patch("tools.ci_attestation._command", side_effect=self.log):
            from tools.ci_attestation import collect
            with self.assertRaises(AttestationError):
                collect(42, self.e["head"], 100, trust_mode="public-protected")

        rules_reads = 0
        def changing_effective_rules(path):
            nonlocal rules_reads
            if path.endswith("rules/branches/main"):
                rules_reads += 1
                active = copy.deepcopy(self.effective_rules)
                if rules_reads > 1:
                    return [rule for rule in active if rule["type"] != "deletion"]
                return active
            return self.api(path)
        with self.patch("tools.ci_attestation._api", side_effect=changing_effective_rules), \
                self.patch("tools.ci_attestation._api_rules", side_effect=changing_effective_rules), \
                self.patch("tools.ci_attestation._command", side_effect=self.log):
            from tools.ci_attestation import collect
            with self.assertRaises(AttestationError):
                collect(42, self.e["head"], 100, trust_mode="public-protected")

    def test_public_postmerge_collection_rechecks_protection_and_result(self):
        from tools.ci_attestation import collect
        merge_sha = "f" * 40
        self.pr.update(merged=True, state="closed", merge_commit_sha=merge_sha)
        self.run["pull_requests"] = []
        old_api = self.api
        def api(path):
            if path.endswith("commits/main"):
                return {"sha": merge_sha}
            if path.endswith("git/commits/" + merge_sha):
                return {"tree": {"sha": self.e["tree"]},
                        "parents": [{"sha": self.e["base"]}, {"sha": self.e["head"]}]}
            return old_api(path)
        with self.patch("tools.ci_attestation._api", side_effect=api), \
                self.patch("tools.ci_attestation._api_rules", side_effect=api), \
                self.patch("tools.ci_attestation._command", side_effect=self.log):
            result = collect(42, self.e["head"], 100, candidate_sha=self.e["candidate"],
                             after_merge=True, trust_mode="public-protected")
        self.assertEqual(result["candidate"]["effective_rules"], self.effective_rules)
        self.assertEqual(result["result"]["main"], merge_sha)


class NativeReviewTests(unittest.TestCase):
    def setUp(self):
        self.pr = {"number": 42, "head": {"sha": "a" * 40},
                   "user": {"id": 355419376, "login": "JC-Agents"}}
        self.review = {"id": 7, "state": "APPROVED", "commit_id": "a" * 40,
                       "user": {"id": 216185530, "login": "JCSchoeman96"},
                       "submitted_at": "2026-11-12T00:00:00Z",
                       "html_url": "https://github.com/Carpe-Diem-Media/NewYou/pull/42#pullrequestreview-7"}

    def test_one_current_head_founder_review_is_sufficient_without_special_body(self):
        from tools.ci_attestation import verify_native_review
        self.assertEqual(self.review, verify_native_review(self.pr, [self.review]))
        comment = dict(self.review, id=8, state="COMMENTED")
        self.assertEqual(self.review, verify_native_review(self.pr, [self.review, comment]))

    def test_missing_stale_forged_dismissed_or_withdrawn_approval_is_rejected(self):
        from tools.ci_attestation import verify_native_review
        for reviews in ([], [dict(self.review, commit_id="b" * 40)],
                        [dict(self.review, user={"id": 355419376, "login": "JCSchoeman96"})],
                        [dict(self.review, state="DISMISSED")],
                        [dict(self.review, html_url="https://example.test/review")],
                        [self.review, dict(self.review, id=8, state="CHANGES_REQUESTED")]):
            with self.subTest(reviews=reviews), self.assertRaises(AttestationError):
                verify_native_review(self.pr, reviews)

    def test_implementer_cannot_use_founder_identity(self):
        from tools.ci_attestation import verify_native_review
        with self.assertRaises(AttestationError):
            verify_native_review(dict(self.pr, user=self.review["user"]), [self.review])


class NativeProtectionTests(unittest.TestCase):
    def parameters(self):
        return {"required_approving_review_count": 1, "require_code_owner_review": True,
                "dismiss_stale_reviews_on_push": True, "require_last_push_approval": True,
                "required_review_thread_resolution": True, "allowed_merge_methods": ["merge"]}

    def test_each_native_review_requirement_is_checked_in_configured_and_effective_rules(self):
        from tools.ci_attestation import verify_native_review_rules
        rules = [{"type": "pull_request", "parameters": self.parameters()}]
        verify_native_review_rules(rules)
        for key, value in [("required_approving_review_count", 0), ("require_code_owner_review", False),
                           ("dismiss_stale_reviews_on_push", False), ("require_last_push_approval", False),
                           ("required_review_thread_resolution", False),
                           ("allowed_merge_methods", ["merge", "squash"])]:
            with self.subTest(key=key), self.assertRaises(AttestationError):
                verify_native_review_rules([{"type": "pull_request", "parameters": dict(self.parameters(), **{key: value})}])

    def test_native_cli_uses_live_collection_without_manual_records(self):
        from unittest.mock import patch
        from tools import ci_attestation as ci
        import sys
        for phase in ("native-candidate", "native-result"):
            args = ["ci_attestation", phase, "--pr", "42", "--reviewed-head", "a" * 40, "--run", "100"]
            if phase == "native-result":
                args += ["--candidate", "c" * 40]
            with self.subTest(phase=phase), patch.object(sys, "argv", args), \
                 patch.object(ci, "collect_native", return_value={"verified": True}) as collect, \
                 patch("builtins.print"):
                self.assertEqual(0, ci.main())
                self.assertEqual(phase == "native-result", collect.call_args.kwargs["after_merge"])


class NativeCollectionTests(unittest.TestCase):
    def setUp(self):
        import base64
        from unittest.mock import patch
        self.patch = patch
        self.e = evidence()
        params = NativeProtectionTests().parameters()
        self.e['ruleset'] = {'rules': [{'type': 'pull_request', 'parameters': params}]}
        self.e['effective_rules'] = [{'type': 'pull_request', 'parameters': params, 'ruleset_id': 24191860}]
        self.pr = NativeReviewTests()
        self.pr.setUp()
        self.owners = {'encoding': 'base64', 'content': base64.b64encode(b'* @JCSchoeman96\n').decode()}

    def api(self, path):
        if path == 'user':
            return {'login': 'JC-Agents', 'id': 355419376}
        if path.endswith('/JC-Agents/permission'):
            return {'permission': 'write', 'role_name': 'write'}
        if path.endswith('/JCSchoeman96/permission'):
            return {'permission': 'admin'}
        if path.endswith('memberships/JC-Agents'):
            return {'state': 'active', 'role': 'member'}
        if '/contents/' in path:
            self.assertTrue(path.endswith('?ref=' + self.e['base']))
            return self.owners
        if path.endswith('/pulls/42'):
            return dict(self.pr.pr, base={'sha': self.e['base']}, merged=False)
        if path == 'repos/Carpe-Diem-Media/NewYou':
            return {}
        raise AssertionError(path)

    def test_live_native_collection_has_no_custom_approval_body_or_private_files(self):
        import json
        from tools import ci_attestation as ci
        with self.patch.object(ci, 'collect', return_value=self.e), \
             self.patch.object(ci, '_api', side_effect=self.api), \
             self.patch.object(ci, '_command', return_value=json.dumps([[self.pr.review]])) as command, \
             self.patch('tools.newyou_attest.founder_account_id', return_value=216185530), \
             self.patch('builtins.open') as file:
            proof = ci.collect_native(42, self.e['head'], 100)
            self.assertEqual(7, proof['founder_review']['id'])
            self.assertEqual(('gh', 'api', '--paginate', '--slurp',
                              'repos/Carpe-Diem-Media/NewYou/pulls/42/reviews?per_page=100'), command.call_args.args)
            file.assert_not_called()

    def test_native_candidate_and_result_accept_approved_agent_permissions(self):
        import json
        from tools import ci_attestation as ci
        for permission in ('write', 'admin'):
            for after_merge in (False, True):
                def api(path):
                    if path.endswith('/JC-Agents/permission'):
                        return {'permission': permission, 'role_name': permission}
                    if path.endswith('/pulls/42'):
                        return dict(self.api(path), merged=after_merge)
                    return self.api(path)
                collected = {'candidate': self.e} if after_merge else self.e
                with self.subTest(permission=permission, after_merge=after_merge), \
                     self.patch.object(ci, 'collect', return_value=collected) as collect, \
                     self.patch.object(ci, '_api', side_effect=api), \
                     self.patch.object(ci, '_command', return_value=json.dumps([[self.pr.review]])), \
                     self.patch('tools.newyou_attest.founder_account_id', return_value=216185530):
                    proof = ci.collect_native(42, self.e['head'], 100,
                                              candidate_sha=self.e['candidate'] if after_merge else None,
                                              after_merge=after_merge)
                    candidate = proof['candidate'] if after_merge else proof
                    self.assertEqual(7, candidate['founder_review']['id'])
                    collect.assert_called_once_with(
                        42, self.e['head'], 100,
                        candidate_sha=self.e['candidate'] if after_merge else None,
                        after_merge=after_merge, trust_mode='public-protected')

    def test_unapproved_or_inconsistent_agent_permissions_fail(self):
        import json
        from tools import ci_attestation as ci
        for permission in ({'permission': 'read', 'role_name': 'read'},
                           {'permission': 'triage', 'role_name': 'triage'},
                           {'permission': 'maintain', 'role_name': 'maintain'},
                           {'permission': 'admin', 'role_name': 'write'},
                           {'permission': 'write', 'role_name': 'admin'},
                           {'permission': 'admin'}, {},
                           {'permission': 'admin', 'role_name': 'custom'}):
            def api(path):
                if path.endswith('/JC-Agents/permission'):
                    return permission
                return self.api(path)
            with self.subTest(permission=permission), \
                 self.patch.object(ci, 'collect', return_value=self.e), \
                 self.patch.object(ci, '_api', side_effect=api), \
                 self.patch.object(ci, '_command', return_value=json.dumps([[self.pr.review]])), \
                 self.assertRaisesRegex(AttestationError, 'agent must have effective Write or Admin'):
                ci.collect_native(42, self.e['head'], 100)

    def test_admin_agent_still_requires_current_head_founder_approval(self):
        import json
        from tools import ci_attestation as ci
        for reviews in ([], [dict(self.pr.review, commit_id='b' * 40)],
                        [dict(self.pr.review, user={'login': 'JC-Agents', 'id': 355419376})]):
            def api(path):
                if path.endswith('/JC-Agents/permission'):
                    return {'permission': 'admin', 'role_name': 'admin'}
                return self.api(path)
            with self.subTest(reviews=reviews), \
                 self.patch.object(ci, 'collect', return_value=self.e), \
                 self.patch.object(ci, '_api', side_effect=api), \
                 self.patch.object(ci, '_command', return_value=json.dumps([reviews])), \
                 self.patch('tools.newyou_attest.founder_account_id', return_value=216185530), \
                 self.assertRaisesRegex(AttestationError, 'founder approval'):
                ci.collect_native(42, self.e['head'], 100)

    def test_wrong_base_codeowners_unapproved_agent_and_changed_head_fail(self):
        import json
        from tools import ci_attestation as ci
        for change in ('codeowners', 'permission', 'actor', 'actor_id', 'actor_login', 'head'):
            def api(path):
                if change == 'codeowners' and '/contents/' in path:
                    return dict(self.owners, content='')
                if change == 'permission' and path.endswith('/JC-Agents/permission'):
                    return {'permission': 'read', 'role_name': 'read'}
                if change == 'actor' and path == 'user':
                    return {'login': 'JCSchoeman96', 'id': 216185530}
                if change == 'actor_id' and path == 'user':
                    return {'login': 'JC-Agents', 'id': 216185530}
                if change == 'actor_login' and path == 'user':
                    return {'login': 'JCSchoeman96', 'id': 355419376}
                if change == 'head' and path.endswith('/pulls/42'):
                    return dict(self.api(path), head={'sha': 'f' * 40})
                return self.api(path)
            with self.subTest(change=change), \
                 self.patch.object(ci, 'collect', return_value=self.e), \
                 self.patch.object(ci, '_api', side_effect=api), \
                 self.patch.object(ci, '_command', return_value=json.dumps([[self.pr.review]])), \
                 self.patch('tools.newyou_attest.founder_account_id', return_value=216185530), \
                 self.assertRaises(AttestationError):
                ci.collect_native(42, self.e['head'], 100)

    def test_uncertain_network_result_fails_once_without_any_merge_or_retry(self):
        from tools import ci_attestation as ci
        with self.patch.object(ci, 'collect', side_effect=AttestationError('uncertain API response')) as collect, \
             self.patch.object(ci, '_command') as command, self.assertRaises(AttestationError):
            try:
                ci.collect_native(42, self.e['head'], 100)
            finally:
                collect.assert_called_once()
                command.assert_not_called()
