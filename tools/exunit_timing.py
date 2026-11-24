"""Publish and consume advisory ExUnit timings through trusted-main artifacts."""

from datetime import datetime, timedelta, timezone
from io import BytesIO
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import statistics
import subprocess
import sys
from zipfile import BadZipFile, ZipFile

HISTORY = 5
DEFAULT_FILE_US = 5_000_000
MAX_FILE_US = 25 * 60 * 1_000_000
MAX_ARTIFACT = 1024 * 1024
LIFETIME = timedelta(days=21)
BOOTSTRAP_LIFETIME = timedelta(days=45)
SHA = re.compile(r"[a-f0-9]{40}")
FILE = re.compile(r"test/(?:[\w.-]+/)*[\w.-]+_test\.exs", re.ASCII)
RECOVERABLE = (KeyError, TypeError, ValueError, OSError, BadZipFile, subprocess.SubprocessError)


def check(condition, message):
    if not condition:
        raise ValueError(message)


def file_path(path):
    return isinstance(path, str) and FILE.fullmatch(path) and ".." not in PurePosixPath(path).parts


def bounded(value):
    return type(value) is int and 0 < value <= MAX_FILE_US


def validate(snapshot, expiry, now=None):
    now = now or datetime.now(timezone.utc)
    check(snapshot["version"] == 1, "unknown timing register version")
    saved = datetime.fromisoformat(snapshot["generated_at"])
    check(now - expiry <= saved <= now, "stale or future timing register")
    check(isinstance(snapshot["provenance"], str) and len(snapshot["provenance"]) <= 160,
          "invalid provenance")
    check(isinstance(snapshot["files"], dict) and len(snapshot["files"]) <= 10_000,
          "invalid timing rows")
    for path, row in snapshot["files"].items():
        check(file_path(path) and SHA.fullmatch(row["blob"]), "invalid timing file identity")
        samples = row["samples"]
        check(isinstance(samples, list) and 1 <= len(samples) <= HISTORY
              and all(bounded(value) for value in samples), "invalid timing samples")
    return snapshot


def read_bootstrap(path):
    try:
        return validate(json.loads(path.read_text()), BOOTSTRAP_LIFETIME)
    except RECOVERABLE as error:
        print(f"Timing bootstrap unavailable ({type(error).__name__}); using positive defaults.",
              file=sys.stderr)
        return None


def weights(files, snapshot):
    known = (snapshot or {}).get("files", {})
    samples = {path: int(statistics.median(known[path]["samples"])) for path, blob in files.items()
               if path in known and known[path]["blob"] == blob}
    ranked = sorted(samples.values())
    # Upper quartile of matching history, with a conservative positive floor.
    upper_quartile = ranked[(len(ranked) - 1) * 3 // 4] if ranked else 0
    fallback = max(DEFAULT_FILE_US, upper_quartile)
    counts = {"measured": len(samples), "changed": len(files.keys() & known.keys()) - len(samples),
              "new_or_unmeasured": len(files.keys() - known.keys()),
              "fallback": len(files) - len(samples)}
    estimates = {
        path: samples.get(path, max(fallback, int(statistics.median(known[path]["samples"])))
                          if path in known else fallback)
        for path in files
    }
    return estimates, counts


def artifact(gh, repo, run, name, member, job=None):
    check(run["head_repository"]["full_name"] == repo, "foreign workflow origin")
    rows = gh(f"repos/{repo}/actions/runs/{run['id']}/artifacts?per_page=100")["artifacts"]
    matches = [row for row in rows if row["name"] == name]
    check(len(matches) == 1, "missing or ambiguous artifact")
    row = matches[0]
    origin = row["workflow_run"]
    check(not row["expired"] and 0 < row["size_in_bytes"] <= MAX_ARTIFACT
          and origin["id"] == run["id"] and origin["head_sha"] == run["head_sha"]
          and origin["repository_id"] == origin["head_repository_id"] == run["repository"]["id"],
          "untrusted artifact origin or size")
    if job is not None:
        check(job["started_at"] <= row["created_at"] <= job["completed_at"],
              "artifact was not created during the coverage job")
    archive = subprocess.check_output(
        ["gh", "api", f"repos/{repo}/actions/artifacts/{row['id']}/zip"], timeout=45
    )
    check(len(archive) <= MAX_ARTIFACT, "oversized timing artifact")
    check("sha256:" + hashlib.sha256(archive).hexdigest() == row["digest"],
          "timing archive digest mismatch")
    with ZipFile(BytesIO(archive)) as zipfile:
        check(zipfile.namelist() == [member] and zipfile.getinfo(member).file_size <= MAX_ARTIFACT,
              "unexpected timing archive")
        return json.loads(zipfile.read(member))


def trusted_snapshot(gh, repo, base, profile, exclude=None):
    try:
        endpoint = f"repos/{repo}/actions/workflows/application-timing.yml/runs"
        runs = gh(f"{endpoint}?branch=main&event=push&status=success&per_page=10")["workflow_runs"]
    except RECOVERABLE:
        return None, "trusted timing producer unavailable"
    for run in runs:
        try:
            check(run["id"] != exclude and run["head_branch"] == "main" and run["event"] == "push"
                  and run["conclusion"] == "success"
                  and run["path"] == ".github/workflows/application-timing.yml",
                  "unexpected timing workflow")
            if run["head_sha"] != base:
                relationship = gh(f"repos/{repo}/compare/{run['head_sha']}...{base}")
                check(relationship["status"] in {"ahead", "identical"}, "timing run is not on base history")
            name = f"application-timing-registry-attempt-{run['run_attempt']}"
            data = validate(artifact(gh, repo, run, name, "registry.json"), LIFETIME)
            check(data["publisher"] == {"run": run["id"], "attempt": run["run_attempt"],
                                        "sha": run["head_sha"]}, "wrong registry publisher")
            check(data["profile"] == profile, "incompatible runtime or dependency graph")
            return data, data["provenance"]
        except RECOVERABLE:
            continue
    return None, "no compatible fresh main snapshot"


def observe_success(previous, report, publisher, generated_at):
    check(report["version"] == 1 and report["verdict"] == "complete" and report["comparable"]
          and type(report["tests"]) is int and report["tests"] > 0
          and len(report["shards"]) == 8
          and {row["shard"] for row in report["shards"]} == set(range(1, 9)),
          "missing, failed or incomparable coverage cohort")
    prior = previous["files"] if previous and previous["profile"] == report["profile"] else {}
    rows = {}
    for path, item in report["files"].items():
        check(bounded(item["us"]), "invalid duration observation")
        history = prior.get(path, {})
        samples = history["samples"] if history.get("blob") == item["blob"] else []
        rows[path] = {"blob": item["blob"], "samples": [*samples, item["us"]][-HISTORY:]}
    check(rows, "empty timing cohort")
    snapshot = {"version": 1, "generated_at": generated_at, "publisher": publisher,
                "profile": report["profile"], "provenance": f"trusted main {publisher['sha']} "
                f"from verified run {report['run']} attempt {report['attempt']}",
                "files": rows}
    return validate(snapshot, LIFETIME)


def integrated_report(gh, repo, sha, base, head, tree):
    pulls = gh(f"repos/{repo}/commits/{head}/pulls?per_page=30")
    merged = [pr for pr in pulls if pr.get("merged_at") and pr["merge_commit_sha"] == sha
              and pr["head"]["sha"] == head and pr["base"]["ref"] == "main"]
    check(len(merged) == 1, "main commit is not an identified merged PR")
    endpoint = f"repos/{repo}/actions/workflows/foundation-integrity.yml/runs"
    runs = gh(f"{endpoint}?event=pull_request&head_sha={head}&status=success&per_page=10")["workflow_runs"]
    for run in runs:
        try:
            pr = merged[0]
            check(run["event"] == "pull_request" and run["conclusion"] == "success"
                  and run["head_sha"] == head and run["updated_at"] <= pr["merged_at"]
                  and run["path"] == ".github/workflows/foundation-integrity.yml",
                  "wrong required workflow")
            check(not run["pull_requests"]
                  or any(p["number"] == pr["number"] for p in run["pull_requests"]),
                  "required run is not associated with merged PR")
            attempt = run["run_attempt"]
            api = f"repos/{repo}/actions/runs/{run['id']}"
            jobs = gh(f"{api}/attempts/{attempt}/jobs?per_page=100")["jobs"]
            required = {"Foundation Integrity", "Application CI / Verify application coverage",
                        "Application CI / Discover application tests", "Application CI / Static application checks",
                        *(f"Application CI / Test shard {n}" for n in range(1, 9))}
            for job in jobs:
                if job["name"] in required and job["conclusion"] == "success" and (
                        job["run_attempt"], job["head_sha"], job["run_id"]) == (attempt, head, run["id"]):
                    required.remove(job["name"])
            check(not required, "required cohort incomplete at current attempt")
            coverage, = [job for job in jobs if job["name"] == "Application CI / Verify application coverage"]
            report = artifact(gh, repo, run, f"application-timings-attempt-{attempt}", "report.json",
                              job=coverage)
            check(all(report[key] == value for key, value in
                      {"head": head, "base": base, "tree": tree, "run": run["id"],
                       "attempt": attempt, "repository": repo, "pr": pr["number"]}.items()),
                  "report does not bind integrated tree")
            candidate = gh(f"repos/{repo}/commits/{report['sha']}")
            check(candidate["commit"]["tree"]["sha"] == tree
                  and [p["sha"] for p in candidate["parents"]] == [base, head],
                  "hosted merge candidate differs from integrated tree")
            return report
        except RECOVERABLE:
            continue
    raise ValueError("no complete applicable PR evidence for this main commit")


def publish(output):
    import os
    from tools.exunit_ci import git, github

    check(os.environ["GITHUB_EVENT_NAME"] == "push" and os.environ["GITHUB_REF"] == "refs/heads/main",
          "timing publisher is main push only")
    repo = os.environ["GITHUB_REPOSITORY"]
    sha = git("rev-parse", "HEAD")
    check(sha == os.environ["GITHUB_SHA"], "wrong publisher checkout")
    parents = git("rev-list", "--parents", "-n1", "HEAD").split()
    check(len(parents) == 3, "expected a protected merge commit")
    _, base, head = parents
    try:
        report = integrated_report(github, repo, sha, base, head, git("rev-parse", "HEAD^{tree}"))
        run = int(os.environ["GITHUB_RUN_ID"])
        previous, _ = trusted_snapshot(github, repo, base, report["profile"], exclude=run)
        publisher = {"run": run, "attempt": int(os.environ["GITHUB_RUN_ATTEMPT"]), "sha": sha}
        snapshot = observe_success(previous, report, publisher, datetime.now(timezone.utc).isoformat())
    except RECOVERABLE as error:
        print(f"No new timing registry: {type(error).__name__}. Retaining prior evidence.")
        return
    output.write_text(json.dumps(snapshot, sort_keys=True))


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    publish(parser.parse_args().output)
