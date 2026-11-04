"""Fail-closed checks for a reviewed PR candidate and its resulting main tree.

The caller must independently collect the evidence from GitHub and Git; this
module does not establish the provenance of supplied JSON or perform a review.
"""
from __future__ import annotations

import re


class AttestationError(ValueError):
    """The evidence is missing, inconsistent, or cannot establish the proof."""


def require(condition: object, message: str) -> None:
    if not condition:
        raise AttestationError(message)


def verify_candidate(e: dict) -> None:
    for name in ("head", "base", "candidate", "tree"):
        require(isinstance(e.get(name), str) and re.fullmatch(r"[0-9a-f]{40}", e[name]),
                f"missing or invalid {name}")
    require(e.get("pr") and e.get("run_pr") == e["pr"], "run is not bound to this PR")
    require(e.get("run_event") == "pull_request", "run is not a pull request run")
    require(e.get("run_head") == e["head"] == e.get("current_head") == e.get("reviewed_head"),
            "head or reviewed head differs from the run")
    require(e.get("base") == e.get("current_base") == e.get("premerge_main"), "base or main drifted")
    require(e.get("candidate_parents") == [e["base"], e["head"]], "candidate parents differ")
    check = e.get("required_check")
    require(isinstance(check, dict) and bool(check.get("id"))
            and check.get("name") == "Foundation Integrity"
            and check.get("status") == "completed" and check.get("conclusion") == "success",
            "required check did not succeed")
    checkouts = e.get("checkout_shas")
    require(isinstance(checkouts, list) and len(checkouts) >= 2
            and all(sha == e["candidate"] for sha in checkouts),
            "missing or inconsistent job checkouts")
    require(e.get("strict_ruleset") is True, "strict required ruleset not established")


def verify_result(candidate: dict, result: dict) -> None:
    verify_candidate(candidate)
    merge = result.get("merge_sha")
    require(isinstance(merge, str) and re.fullmatch(r"[0-9a-f]{40}", merge), "missing merge SHA")
    require(result.get("method") == "merge", "merge method is not provable as a merge commit")
    require(result.get("main") == merge, "resulting main drifted")
    require(result.get("parents") == [candidate["base"], candidate["head"]], "merge parents differ")
    require(result.get("tree") == candidate["tree"], "resulting tree differs from tested tree")


def checkout_from_log(log: str) -> str:
    """Read the full checkout SHA emitted by actions/checkout, or fail closed."""
    lines = log.splitlines()
    found = []
    for left, right in zip(lines, lines[1:]):
        if "[command]/usr/bin/git log -1 --format=%H" in left:
            match = re.search(r"\s([0-9a-f]{40})$", right)
            if match:
                found.append(match.group(1))
    require(len(found) == 1, "job has missing or ambiguous checkout evidence")
    return found[0]


def _command(*args: str) -> str:
    import subprocess
    try:
        return subprocess.run(args, check=True, capture_output=True, text=True).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        raise AttestationError(f"cannot collect GitHub evidence: {exc}") from exc


def _api(path: str) -> dict:
    import json
    try:
        value = json.loads(_command("gh", "api", path))
    except ValueError as exc:
        raise AttestationError("invalid GitHub API response") from exc
    require(isinstance(value, dict), "unexpected GitHub API response")
    return value


def _ruleset_ok(repo: str) -> bool:
    ruleset = _api(f"repos/{repo}/rulesets/24191860")
    if ruleset.get("name") != "Protect main" or ruleset.get("enforcement") != "active":
        return False
    if ruleset.get("bypass_actors") != []:
        return False
    refs = ruleset.get("conditions", {}).get("ref_name", {})
    if "~DEFAULT_BRANCH" not in refs.get("include", []) or refs.get("exclude") != []:
        return False
    rules = ruleset.get("rules", [])
    if not any(rule.get("type") == "pull_request" for rule in rules):
        return False
    for rule in rules:
        if rule.get("type") == "required_status_checks":
            params = rule.get("parameters", {})
            return (params.get("strict_required_status_checks_policy") is True
                    and any(item.get("context") == "Foundation Integrity"
                            for item in params.get("required_status_checks", [])))
    return False


def collect(pr_number: int, reviewed_head: str, run_id: int, *, candidate_sha: str | None = None,
            after_merge: bool = False) -> dict:
    """Collect run, checkout, PR, Git and ruleset evidence directly from GitHub."""
    repo = "JCSchoeman96/NewYou"
    pr = _api(f"repos/{repo}/pulls/{pr_number}")
    require(pr.get("base", {}).get("ref") == "main", "PR does not target main")
    require(pr.get("merged") is after_merge
            and pr.get("state") == ("closed" if after_merge else "open"),
            "PR merge state is unexpected")
    head = pr["head"]["sha"]
    base = pr["base"]["sha"]
    candidate = candidate_sha if after_merge else pr.get("merge_commit_sha")
    require(isinstance(candidate, str) and re.fullmatch(r"[0-9a-f]{40}", candidate),
            "GitHub did not provide a merge candidate")
    main = _api(f"repos/{repo}/commits/main")["sha"]
    run = _api(f"repos/{repo}/actions/runs/{run_id}")
    require(run.get("path", "").split("@")[0] == ".github/workflows/foundation-integrity.yml",
            "unexpected workflow")
    require(run.get("status") in ("in_progress", "completed"), "workflow has unexpected status")
    require(run.get("event") == "pull_request" and run.get("head_sha") == head,
            "workflow is not for the current PR head")
    associations = run.get("pull_requests", [])
    require((after_merge and not associations) or any(p.get("number") == pr_number for p in associations),
            "workflow is not associated with the PR")
    runs = _api(f"repos/{repo}/actions/workflows/foundation-integrity.yml/runs?event=pull_request&head_sha={head}&per_page=100")
    relevant = [item for item in runs.get("workflow_runs", [])
                if (after_merge and not item.get("pull_requests"))
                or any(p.get("number") == pr_number for p in item.get("pull_requests", []))]
    require(relevant and relevant[0].get("id") == run_id, "run is superseded or unavailable")
    require(runs.get("total_count", 0) <= 100, "too many runs to establish latest run")
    attempt = run.get("run_attempt")
    require(isinstance(attempt, int) and attempt > 0, "run attempt is missing")
    jobs_response = _api(f"repos/{repo}/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100")
    jobs = jobs_response.get("jobs", [])
    require(jobs_response.get("total_count", 0) == len(jobs), "job list is incomplete")
    by_name = {job.get("name"): job for job in jobs}
    require(len(by_name) == len(jobs), "duplicate job names")
    for name in ("Route CI lanes", "Foundation Smoke", "Foundation Integrity"):
        require(name in by_name and by_name[name].get("status") == "completed"
                and by_name[name].get("conclusion") == "success", f"{name} did not succeed")
    aggregate = by_name["Foundation Integrity"]
    check = _api(f"repos/{repo}/check-runs/{aggregate['id']}")
    require(check.get("app", {}).get("slug") == "github-actions"
            and check.get("check_suite", {}).get("id") == run.get("check_suite_id")
            and check.get("head_sha") == head, "required check identity is unverifiable")
    checkouts = []
    job_ids = []
    job_evidence = []
    for job in sorted(jobs, key=lambda item: item["id"]):
        name = job.get("name", "")
        if name.startswith("Foundation Full"):
            continue
        job_evidence.append({k: job.get(k) for k in ("id", "name", "status", "conclusion")})
        if name == "Foundation Integrity":
            continue
        require(job.get("status") == "completed", f"job {name} is incomplete")
        if job.get("conclusion") == "skipped":
            continue
        require(job.get("conclusion") == "success", f"job {name} failed")
        log = _command("gh", "api", "--allow-escape-sequences",
                       f"repos/{repo}/actions/jobs/{job['id']}/logs")
        checkouts.append(checkout_from_log(log))
        job_ids.append(job["id"])
    commit = _api(f"repos/{repo}/git/commits/{candidate}")
    e = {"pr": pr_number, "head": head, "base": base, "candidate": candidate,
         "tree": commit["tree"]["sha"], "candidate_parents": [p["sha"] for p in commit["parents"]],
         "current_head": head, "current_base": base, "premerge_main": base if after_merge else main,
         "run_head": run["head_sha"], "run_event": run["event"], "run_pr": pr_number,
         "required_check": {k: check.get(k) for k in ("id", "name", "status", "conclusion")},
         "checkout_shas": checkouts, "strict_ruleset": _ruleset_ok(repo),
         "reviewed_head": reviewed_head, "run_id": run_id, "run_attempt": attempt,
         "check_suite_id": run["check_suite_id"], "job_ids": job_ids, "jobs": job_evidence}
    verify_candidate(e)
    fresh_pr = _api(f"repos/{repo}/pulls/{pr_number}")
    require(fresh_pr["head"]["sha"] == head and fresh_pr["base"]["sha"] == base
            and fresh_pr.get("merged") is after_merge
            and fresh_pr.get("state") == ("closed" if after_merge else "open")
            and fresh_pr.get("merge_commit_sha") == pr.get("merge_commit_sha"),
            "PR changed while collecting evidence")
    fresh_run = _api(f"repos/{repo}/actions/runs/{run_id}")
    require(fresh_run.get("run_attempt") == attempt, "workflow was rerun while collecting evidence")
    fresh_runs = _api(f"repos/{repo}/actions/workflows/foundation-integrity.yml/runs?event=pull_request&head_sha={head}&per_page=100")
    fresh_relevant = [item for item in fresh_runs.get("workflow_runs", [])
                      if (after_merge and not item.get("pull_requests"))
                      or any(p.get("number") == pr_number for p in item.get("pull_requests", []))]
    require(fresh_relevant and fresh_relevant[0].get("id") == run_id, "run was superseded while collecting evidence")
    require(_api(f"repos/{repo}/commits/main")["sha"] == main, "main changed while collecting evidence")
    if after_merge:
        merge_sha = pr.get("merge_commit_sha")
        require(isinstance(merge_sha, str) and re.fullmatch(r"[0-9a-f]{40}", merge_sha), "missing PR merge SHA")
        merge = _api(f"repos/{repo}/git/commits/{merge_sha}")
        parents = [p["sha"] for p in merge["parents"]]
        result = {"method": "merge" if len(parents) == 2 else "unknown", "merge_sha": merge_sha,
                  "main": main, "parents": parents, "tree": merge["tree"]["sha"]}
        verify_result(e, result)
        require(_api(f"repos/{repo}/commits/main")["sha"] == main, "main changed while verifying result")
        return {"candidate": e, "result": result}
    return e


def main() -> int:
    import argparse
    import json
    import sys
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("before", "after"))
    parser.add_argument("--pr", type=int, required=True)
    parser.add_argument("--reviewed-head", required=True, help="exact head independently reviewed by Master Gate")
    parser.add_argument("--run", type=int, required=True)
    parser.add_argument("--before", help="saved pre-merge evidence, required after merge")
    args = parser.parse_args()
    try:
        if args.phase == "before":
            require(args.before is None, "--before is only valid after merge")
            proof = collect(args.pr, args.reviewed_head, args.run)
        else:
            require(args.before is not None, "--before is required after merge")
            with open(args.before, encoding="utf-8") as file:
                before = json.load(file)
            verify_candidate(before)
            proof = collect(args.pr, args.reviewed_head, args.run,
                            candidate_sha=before["candidate"], after_merge=True)
            require(proof["candidate"] == before, "pre-merge evidence differs from live GitHub evidence")
        print(json.dumps(proof, indent=2, sort_keys=True))
        return 0
    except (AttestationError, KeyError, TypeError, ValueError, OSError) as exc:
        print(f"attestation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
