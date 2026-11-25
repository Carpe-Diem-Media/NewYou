"""Plan and verify complete, independently discovered ExUnit execution."""

import argparse
from collections import Counter
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from tools import exunit_timing as timing

SHARDS = 8
CAPACITY = "Application CI / "
BOOTSTRAP = Path("tools/ci/exunit-bootstrap.json")
TEST_FILE = re.compile(r"test/(?:[\w.-]+/)*[\w.-]+_test\.exs", re.ASCII)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def github(*args):
    return json.loads(subprocess.check_output(["gh", "api", *args], timeout=45))


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def test_file(path):
    return isinstance(path, str) and TEST_FILE.fullmatch(path) and ".." not in Path(path).parts


def allocate(weights, count=SHARDS):
    """Assign longest files first with stable path and shard tie breaking."""
    require(len(weights) >= count > 0, "expected at least one file per shard")
    require(all(test_file(file) and type(weight) is int and weight > 0
                for file, weight in weights.items()), "invalid scheduling weights")
    shards = [[] for _ in range(count)]
    loads = [0] * count
    for file in sorted(weights, key=lambda file: (-weights[file], file)):
        index = min(range(count), key=lambda index: (loads[index], index))
        shards[index].append(file)
        loads[index] += weights[file]
    return [sorted(shard) for shard in shards], loads


def read_events(path):
    return [json.loads(line) for line in path.read_text().splitlines()]


def identity(row):
    file, module, name, parameter = row["identity"]
    require(test_file(file) and isinstance(module, str) and module
            and isinstance(name, str) and name
            and re.fullmatch(r"(?:[0-9a-f]{64})?", parameter), "invalid test identity")
    return file, module, name, parameter


def observe(rows, mode, seed):
    require(rows and rows[-1]["kind"] == "suite", "missing suite completion")
    suite = rows[-1]
    require(suite["mode"] == mode and suite["seed"] == seed
            and type(suite["max_cases"]) is int and suite["max_cases"] > 0,
            "wrong ExUnit mode, seed or scheduler settings")
    declared = Counter()
    finished = Counter()
    file_times = Counter()
    for row in rows[:-1]:
        kind = row["kind"]
        if kind == "declared":
            declared[identity(row)] += 1
            continue
        require(mode == "execute" and kind in {"finished", "module"},
                "unexpected event for ExUnit mode")
        require(row["status"] == "passed", f"unexpected ExUnit {row['status']} evidence")
        require(type(row["us"]) is int and row["us"] >= 0, "invalid ExUnit duration")
        if kind == "finished":
            finished[identity(row)] += 1
        else:
            require(test_file(row["file"]), "invalid timing file")
            file_times[row["file"]] += row["us"]
    require(declared and all(n == 1 for n in declared.values()), "empty or duplicate registration")
    if mode == "execute":
        require(finished == declared, "execution differs from declared test identities")
        require(set(file_times) == {key[0] for key in declared}, "incomplete module timings")
    return declared, file_times, suite


def candidate():
    sha = git("rev-parse", "HEAD")
    require(sha == os.environ["GITHUB_SHA"], "checkout differs from workflow candidate")
    base, head = git("rev-parse", "HEAD^1", "HEAD^2").splitlines()
    require(base == os.environ["CI_BASE"] and head == os.environ["CI_HEAD"],
            "checkout parents differ from PR base and head")
    return {"sha": sha, "tree": git("rev-parse", "HEAD^{tree}"), "base": base, "head": head,
            "repository": os.environ["GITHUB_REPOSITORY"], "pr": int(os.environ["CI_PR"]),
            "run": int(os.environ["GITHUB_RUN_ID"]),
            "attempt": int(os.environ["GITHUB_RUN_ATTEMPT"])}


def runner():
    return {
        "provider": os.environ["RUNNER_ENVIRONMENT"],
        "image": os.environ.get("ImageOS", "") + "-" + os.environ.get("ImageVersion", ""),
        "arch": os.environ["RUNNER_ARCH"],
        "cpus": len(os.sched_getaffinity(0)),
        "postgres": os.environ["CI_TEST_POSTGRES_VERSION"],
        "beam": subprocess.check_output(["elixir", "--version"], text=True).splitlines(),
    }


def compatibility(machine, max_cases):
    return {**machine, "max_cases": max_cases,
            "graph": hashlib.sha256(Path("mix.lock").read_bytes()).hexdigest()}


def capture(directory, mode, seed, files=()):
    require(not os.environ.get("MIX_TEST_PARTITION"), "unexpected partition environment")
    require(os.environ.get("MIX_ENV") == "test", "CI requires MIX_ENV=test")
    require(all(test_file(file) and Path(file).is_file() for file in files),
            "invalid shard files")
    directory.mkdir()
    envelope = {**candidate(), "seed": seed, "runner": os.environ["RUNNER_NAME"],
                "profile": runner(), "allocation": os.environ["CI_TEST_DATABASE_ID"],
                "cache_key": os.environ["CI_TEST_CACHE_KEY"],
                "cache_result": os.environ["CI_TEST_CACHE_RESULT"]}
    (directory / "job.json").write_text(json.dumps(envelope))
    env = dict(os.environ, NEWYOU_CI_TEST_MODE=mode,
               NEWYOU_CI_TEST_EVENTS=str(directory / "events.jsonl"))
    env.pop("GH_TOKEN", None)
    args = ["--seed", str(seed), "--formatter", "ExUnit.CLIFormatter",
            "--formatter", "NewYou.CIExUnitFormatter"]
    if mode == "discover":
        args.append("--dry-run")
    else:
        require(files, "empty shard")
    subprocess.run(["mix", "test", *args, *files], env=env, check=True,
                   stdout=sys.stderr if mode == "discover" else None)


def fingerprint(files):
    entries = {}
    for line in git("ls-tree", "-r", "HEAD", "test").splitlines():
        meta, path = line.split("\t", 1)
        mode, kind, sha = meta.split()
        if kind == "blob" and mode in {"100644", "100755"} and path in files:
            entries[path] = sha
    require(set(entries) == set(files), "untracked or unsupported registered test file")
    return entries


def plan(directory, seed):
    capture(directory, "discover", seed)
    declared, _, suite = observe(read_events(directory / "events.jsonl"), "discover", seed)
    meta = json.loads((directory / "job.json").read_text())
    files = fingerprint({key[0] for key in declared})
    profile = compatibility(meta["profile"], suite["max_cases"])
    snapshot, source = timing.trusted_snapshot(github, meta["repository"], meta["base"], profile)
    if snapshot is None:
        snapshot = timing.read_bootstrap(BOOTSTRAP)
        source = f"{snapshot['provenance']} ({source})" if snapshot else f"positive fallback ({source})"
    weights, counts = timing.weights(files, snapshot)
    shards, predicted = allocate(weights)
    manifest = {"seed": seed, "files": files, "identities": sorted(declared), "shards": shards,
                "predicted": predicted, "source": source, "weight_counts": counts,
                "timing_generated_at": snapshot["generated_at"] if snapshot else None,
                "profile": profile}
    (directory / "plan.json").write_text(json.dumps(manifest))
    matrix = {"include": [{"shard": n, "files": group}
                          for n, group in enumerate(shards, 1)]}
    print("matrix=" + json.dumps(matrix, separators=(",", ":")))


def seconds(start, finish):
    return (datetime.fromisoformat(finish) - datetime.fromisoformat(start)).total_seconds()


def verified_job(evidence, jobs, artifacts, name, key, binding):
    job = jobs.get(CAPACITY + name)
    rerun = f"Run all jobs together for complete evidence (attempt {binding['attempt']})."
    require(job is not None, f"{name}: missing job. {rerun}")
    require(job["conclusion"] == "success" and job["run_id"] == binding["run"]
            and job["run_attempt"] == binding["attempt"] and job["head_sha"] == binding["head"],
            f"{name}: missing, failed or stale job")
    artifact = artifacts.get(key)
    require(artifact is not None, f"{name}: missing artifact {key}. {rerun}")
    origin = artifact["workflow_run"]
    require(origin["id"] == binding["run"] and origin["head_sha"] == binding["head"]
            and origin["repository_id"] == int(os.environ["GITHUB_REPOSITORY_ID"])
            and origin["head_repository_id"] == int(os.environ["CI_HEAD_REPOSITORY"])
            and not artifact["expired"]
            and job["started_at"] <= artifact["created_at"] <= job["completed_at"],
            f"{name}: artifact is stale or has the wrong origin")
    path = evidence / key
    metadata = path / "job.json"
    require(metadata.is_file(), f"{name}: missing downloaded metadata for {key}. {rerun}")
    env = json.loads(metadata.read_text())
    require(all(env.get(field) == value for field, value in binding.items())
            and env["runner"] == job["runner_name"], f"{name}: wrong execution binding")
    return path, job, env


def unique(rows, key):
    result = {row[key]: row for row in rows}
    require(len(result) == len(rows), f"duplicate {key} metadata")
    return result


def verify(directory, report):
    binding = candidate()
    repo, run, attempt = (binding[k] for k in ("repository", "run", "attempt"))
    api = f"repos/{repo}/actions/runs/{run}"
    jobs = unique(github(f"{api}/attempts/{attempt}/jobs?per_page=100")["jobs"], "name")
    static = jobs[CAPACITY + "Static application checks"]
    require((static["conclusion"], static["run_id"], static["run_attempt"], static["head_sha"])
            == ("success", run, attempt, binding["head"]), "static checks absent or stale")
    artifacts = unique(github(f"{api}/artifacts?per_page=100")["artifacts"], "name")
    suffix = f"-attempt-{attempt}"
    path, discovery, _ = verified_job(directory, jobs, artifacts, "Discover application tests",
                                      "application-evidence-plan" + suffix, binding)
    manifest = json.loads((path / "plan.json").read_text())
    seed = manifest["seed"]
    expected, _, _ = observe(read_events(path / "events.jsonl"), "discover", seed)
    require(expected == Counter(map(tuple, manifest["identities"])), "planner inventory drift")
    require(fingerprint({key[0] for key in expected}) == manifest["files"], "wrong file inventory")
    groups = manifest["shards"]
    require(len(groups) == SHARDS and all(groups)
            and Counter(file for group in groups for file in group) == Counter(manifest["files"].keys()),
            "assignment does not cover each declared file exactly once")
    require({name for name in jobs if name.startswith(CAPACITY + "Test shard ")}
            == {CAPACITY + f"Test shard {n}" for n in range(1, SHARDS + 1)}, "wrong shard job set")
    allocations = set()
    union = Counter()
    micros = {}
    summaries = []
    profiles = []
    for n, files in enumerate(groups, 1):
        path, job, env = verified_job(directory, jobs, artifacts, f"Test shard {n}",
                                      f"application-evidence-{n}" + suffix, binding)
        require(env["seed"] == seed and env["allocation"] not in allocations,
                "wrong seed or reused database allocation")
        allocations.add(env["allocation"])
        observed, durations, suite = observe(read_events(path / "events.jsonl"), "execute", seed)
        require(observed == Counter({key: value for key, value in expected.items() if key[0] in files}),
                f"shard {n}: executed identities differ from assignment")
        union.update(observed)
        micros.update(durations)
        profiles.append(compatibility(env["profile"], suite["max_cases"]))
        steps = job["steps"]
        prepare = next(step for step in steps if step["name"] == "Prepare isolated test environment")
        summaries.append({"shard": n, "job": job["id"],
                          "predicted_us": manifest["predicted"][n - 1],
                          "actual_us": sum(durations.values()),
                          "execution_us": suite["timings"]["run"],
                          "queue_seconds": seconds(job["created_at"], job["started_at"]),
                          "runner_seconds": seconds(job["started_at"], job["completed_at"]),
                          "prepare_seconds": seconds(prepare["started_at"], prepare["completed_at"]),
                          "cache_key": env["cache_key"], "cache_result": env["cache_result"]})
    require(union == expected, "full execution differs from independent inventory")
    elapsed = [s["runner_seconds"] for s in summaries]
    result = {**binding, "version": 1, "verdict": "complete", "seed": seed, "tests": len(expected),
              "profile": profiles[0], "comparable": all(p == profiles[0] for p in profiles)
              and bool(profiles[0]["image"].split("-", 1)[-1]),
              "weights": manifest["weight_counts"], "timing_source": manifest["source"],
              "timing_generated_at": manifest["timing_generated_at"],
              "files": {file: {"blob": blob, "us": max(1, micros[file])}
                        for file, blob in manifest["files"].items()},
              "shards": summaries, "fastest_seconds": min(elapsed), "slowest_seconds": max(elapsed),
              "runner_minutes": round(sum(elapsed) / 60, 2),
              "discovery_seconds": seconds(discovery["started_at"], discovery["completed_at"])}
    report.write_text(json.dumps(result, sort_keys=True))
    lines = [
        f"Complete coverage: {len(expected)} tests in {len(micros)} files.",
        f"Timing source: {manifest['source']}. Snapshot date: {manifest['timing_generated_at']}.",
        f"Scheduling files: {manifest['weight_counts']}.",
        f"Runner seconds: {min(elapsed):.0f}–{max(elapsed):.0f} "
        f"({max(elapsed) - min(elapsed):.0f}s spread). {result['runner_minutes']} runner-minutes.",
        "", "| Shard | Predicted s | File s | ExUnit s | Queue s | Setup s | Cache |",
        "| --- | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    lines.extend(f"| {s['shard']} | {s['predicted_us']/1e6:.1f} | {s['actual_us']/1e6:.1f} "
                 f"| {s['execution_us']/1e6:.1f} | {s['queue_seconds']:.0f} "
                 f"| {s['prepare_seconds']:.0f} | {s['cache_result']} |" for s in summaries)
    print("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("plan", "execute"):
        command = sub.add_parser(name)
        command.add_argument("directory", type=Path)
        command.add_argument("seed", type=int)
        if name == "execute":
            command.add_argument("files", type=json.loads)
    check = sub.add_parser("verify")
    check.add_argument("directory", type=Path)
    check.add_argument("report", type=Path)
    args = parser.parse_args()
    if args.command == "plan":
        plan(args.directory, args.seed)
    elif args.command == "execute":
        capture(args.directory, "execute", args.seed, args.files)
    else:
        verify(args.directory, args.report)


if __name__ == "__main__":
    main()
