"""Allocate and verify WELL-202 shadow jobs using full-suite ExUnit evidence."""

import argparse
from collections import Counter
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import statistics
import subprocess

TOPOLOGIES = {"native-4": ("native", 4), "balanced-4": ("balanced", 4),
              "balanced-6": ("balanced", 6), "balanced-8": ("balanced", 8)}
TEST_FILE = re.compile(r"test/(?:[\w.-]+/)*[\w.-]+_test\.exs", re.ASCII)
PREPARE = "shadow-control"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def options(body):
    prefix = "<!-- well-202:"
    lines = [line.strip() for line in body.splitlines() if line.strip().startswith(prefix)]
    if not lines:
        return "all", "cold", 852013, "configured"
    match = re.fullmatch(
        r"<!-- well-202: (all|native-4|balanced-[468]) (cold|restore) ([1-9][0-9]{0,5})(?: (configured|github))? -->",
        lines[0],
    )
    require(len(lines) == 1 and match, "invalid or repeated WELL-202 experiment selector")
    topology, cache, seed, provider = match.groups()
    return topology, cache, int(seed), provider or "configured"


def candidate():
    revision = git("HEAD")
    require(revision == os.environ["GITHUB_SHA"], "checkout differs from workflow candidate")
    base, head = git("HEAD^1"), git("HEAD^2")
    require(base == os.environ["SHADOW_PR_BASE"] and head == os.environ["SHADOW_PR_HEAD"],
            "checkout parents differ from pull request base and head")
    return {"sha": revision, "tree": git("HEAD^{tree}"), "base": base, "head": head}


def allocate(files, timings, count, mode):
    files = sorted(files)
    require(len(set(files)) == len(files) and 0 < count <= len(files),
            "expected distinct files and nonempty shards")
    if mode == "native":
        # Mix 1.20.5 sorts discovered files then selects indices modulo --partitions.
        # Preserve that allocation without MIX_TEST_PARTITION, which TEST rejects.
        return [files[index::count] for index in range(count)]

    require(mode == "balanced" and set(timings) <= set(files), "invalid allocation inputs")
    require(all(type(value) is int and value >= 0 for value in timings.values()),
            "invalid file duration")
    fallback = max(1, int(statistics.median(timings.values()))) if timings else 1
    weights = {file: max(1, timings.get(file, fallback)) for file in files}
    shards = [[] for _ in range(count)]
    loads = [0] * count
    for file in sorted(files, key=lambda file: (-weights[file], file)):
        index = min(range(count), key=lambda index: (loads[index], index))
        shards[index].append(file)
        loads[index] += weights[file]
    return [sorted(shard) for shard in shards]


def identities(records, seed):
    suites = [row for row in records if row["kind"] == "suite"]
    require(len(suites) == 1 and records[-1] == suites[0], "missing or duplicate suite completion")
    require(suites[0]["seed"] == seed and suites[0]["max_cases"] > 0, "wrong ExUnit configuration")
    result = Counter()
    modules = Counter()
    for row in records[:-1]:
        require(row["kind"] in {"test", "module"}, "unexpected formatter event")
        require(row["status"] == "passed", f"non-passing {row['kind']} in {row['file']}")
        require(TEST_FILE.fullmatch(row["file"]) and ".." not in Path(row["file"]).parts,
                "invalid test path")
        require(type(row["us"]) is int and row["us"] >= 0, "invalid duration")
        require(re.fullmatch(r"(?:[a-f0-9]{64})?", row["parameter"]), "invalid parameter identity")
        module = (row["file"], row["module"], row["parameter"])
        if row["kind"] == "module":
            modules[module] += 1
        else:
            result[*module, row["name"]] += 1
    require(result and all(count == 1 for count in result.values()), "empty or duplicate inventory")
    require(modules == Counter(set(key[:3] for key in result)), "missing or duplicate module completion")
    return result


def coverage(expected, shards):
    total = sum(shards, Counter())
    require(total == expected, "test identity coverage differs from independent inventory")


def read_events(path):
    return [json.loads(line) for line in path.read_text().splitlines()]


def git(ref):
    return subprocess.check_output(["git", "rev-parse", ref], text=True).strip()


def metadata(name, seed, cache):
    return {
        **candidate(), "name": name, "seed": seed,
        "run": os.environ["GITHUB_RUN_ID"], "attempt": os.environ["GITHUB_RUN_ATTEMPT"],
        "cache_request": cache,
        "cache_result": os.environ["SHADOW_CACHE_RESULT"],
        "cache_key": os.environ["SHADOW_CACHE_KEY"],
        "runner": os.environ["RUNNER_NAME"],
        "provider": os.environ["RUNNER_ENVIRONMENT"],
        "image": "-".join(os.environ.get(key, "") for key in ("ImageOS", "ImageVersion")),
        "arch": os.environ["RUNNER_ARCH"],
        "cpus": len(os.sched_getaffinity(0)),
        "postgres": os.environ["SHADOW_POSTGRES_VERSION"],
        "toolchain": Path(".tool-versions").read_text().splitlines(),
        "allocation": os.environ["SHADOW_DATABASE_ID"],
    }


def benchmark(name, seed, cache, output, files=None):
    require(not os.environ.get("MIX_TEST_PARTITION"), "unexpected partition environment")
    require(os.environ.get("MIX_ENV") == "test", "benchmark requires MIX_ENV=test")
    output.mkdir()
    (output / "job.json").write_text(json.dumps(metadata(name, seed, cache)) + "\n")
    env = dict(os.environ, NEWYOU_SHADOW_EVENTS_FILE=str(output / "events.jsonl"))
    args = ["--seed", str(seed), "--formatter", "ExUnit.CLIFormatter",
            "--formatter", "NewYou.ShadowBenchmarkFormatter"]
    if files is None:
        subprocess.run(["mix", "check", *args], env=env, check=True)
    else:
        require(files and all(TEST_FILE.fullmatch(file) and ".." not in Path(file).parts
                              and Path(file).is_file() for file in files), "invalid shard files")
        subprocess.run(["mix", "test", *args, *files], env=env, check=True)


def discover(output, seed):
    require(not os.environ.get("MIX_TEST_PARTITION"), "unexpected partition environment")
    env = dict(os.environ, NEWYOU_SHADOW_EVENTS_FILE=str(output / "inventory.jsonl"))
    subprocess.run(["mix", "test", "--dry-run", "--seed", str(seed), "--formatter",
                    "NewYou.ShadowBenchmarkFormatter"], env=env, check=True)


def make_plan(output, seed, topology):
    expected = identities(read_events(output / "inventory.jsonl"), seed)
    records = read_events(output / "events.jsonl")
    coverage(expected, [identities(records, seed)])
    files = sorted({key[0] for key in expected})
    timings = Counter()
    for row in records:
        if row["kind"] == "module":
            timings[row["file"]] += row["us"]
    plans = []
    for key, (mode, count) in TOPOLOGIES.items():
        if topology not in {"all", key}:
            continue
        for index, shard in enumerate(allocate(files, timings, count, mode), 1):
            plans.append({"name": f"shadow-{key}-{index}", "topology": key, "files": shard})
    require(plans, "empty benchmark matrix")
    return {"include": plans}


def load_evidence(directory, name, jobs, artifacts, binding):
    job = jobs.get(name)
    require(job and job["conclusion"] == "success", f"{name}: missing or unsuccessful GitHub job")
    require(str(job["run_id"]) == binding["run"] and str(job["run_attempt"]) == binding["attempt"]
            and job["head_sha"] == binding["head"], f"{name}: stale GitHub job identity")
    artifact = artifacts.get(f"{name}-attempt-{binding['attempt']}")
    require(artifact and artifact["created_at"] >= job["started_at"]
            and artifact["created_at"] <= job["completed_at"], f"{name}: missing or stale artifact")
    origin = artifact["workflow_run"]
    require(str(origin["id"]) == binding["run"] and origin["head_sha"] == binding["head"]
            and origin["repository_id"] == origin["head_repository_id"] and not artifact["expired"],
            f"{name}: wrong artifact origin")
    envelope = json.loads((directory / artifact["name"] / "job.json").read_text())
    require(all(envelope.get(key) == value for key, value in binding.items())
            and envelope["name"] == name and envelope["runner"] == job["runner_name"],
            f"{name}: wrong candidate, run, attempt or job")
    return job, envelope, directory / artifact["name"]


def unique_records(rows, key):
    result = {row[key]: row for row in rows}
    require(len(result) == len(rows), f"duplicate {key} in GitHub metadata")
    return result


def seconds(start, finish):
    return (datetime.fromisoformat(finish) - datetime.fromisoformat(start)).total_seconds()


def summarize(job, envelope, records):
    suite = records[-1]
    return {
        "job_id": job["id"],
        "runner": {key: envelope[key] for key in ("provider", "image", "arch", "cpus", "postgres", "toolchain")},
        "cache": {key: envelope[key] for key in ("cache_request", "cache_key", "cache_result")},
        "runner_seconds": seconds(job["started_at"], job["completed_at"]),
        "queue_seconds": seconds(job["created_at"], job["started_at"]),
        "started_at": job["started_at"],
        "completed_at": job["completed_at"],
        "steps_seconds": {step["name"]: seconds(step["started_at"], step["completed_at"])
                          for step in job["steps"]
                          if step.get("started_at") and step.get("completed_at")},
        "suite": suite,
        "slow_tests": sorted((r for r in records if r["kind"] == "test"),
                             key=lambda r: -r["us"])[:20],
        "slow_modules": sorted((r for r in records if r["kind"] == "module"),
                               key=lambda r: -r["us"])[:20],
    }


def verify(directory, jobs, artifacts, binding, topology):
    jobs = unique_records([job for job in jobs if job["name"].startswith("shadow-")], "name")
    artifacts = unique_records([a for a in artifacts if a["name"].endswith(
        f"-attempt-{binding['attempt']}")], "name")
    control, baseline, output = load_evidence(directory, PREPARE, jobs, artifacts, binding)
    seed = binding["seed"]
    plans = make_plan(output, seed, topology)["include"]
    expected_names = {PREPARE, *(plan["name"] for plan in plans)}
    require(set(jobs) == expected_names | {"shadow-configure", "shadow-verify"}, "unexpected or missing GitHub jobs")
    require(jobs["shadow-configure"]["conclusion"] == "success", "experiment setup was unsuccessful")
    require(set(artifacts) == {f"{name}-attempt-{binding['attempt']}" for name in expected_names},
            "unexpected or missing artifacts")
    expected = identities(read_events(output / "inventory.jsonl"), seed)
    control_records = read_events(output / "events.jsonl")
    phase_ready = control["completed_at"]
    report = {"binding": binding, "phase_ready": phase_ready, "expected_tests": len(expected), "files": len({k[0] for k in expected}),
              "control": summarize(control, baseline, control_records), "topologies": {}}
    allocations = {baseline["allocation"]}
    control_settings = (baseline["provider"], baseline["image"], baseline["arch"], baseline["cpus"],
                        baseline["postgres"], baseline["cache_result"], baseline["cache_key"],
                        control_records[-1]["max_cases"])
    for key in {plan["topology"] for plan in plans}:
        shards = []
        summaries = []
        comparable = True
        for plan in (plan for plan in plans if plan["topology"] == key):
            job, envelope, output = load_evidence(directory, plan["name"], jobs, artifacts, binding)
            require(envelope["allocation"] not in allocations, "database allocation reused")
            allocations.add(envelope["allocation"])
            records = read_events(output / "events.jsonl")
            observed = identities(records, seed)
            require({item[0] for item in observed} == set(plan["files"]), "wrong shard file assignment")
            shards.append(observed)
            summary = summarize(job, envelope, records)
            summary["dispatch_to_start_seconds"] = seconds(phase_ready, job["started_at"])
            summaries.append(summary)
            settings = (envelope["provider"], envelope["image"], envelope["arch"], envelope["cpus"],
                        envelope["postgres"], envelope["cache_result"], envelope["cache_key"],
                        records[-1]["max_cases"])
            comparable = comparable and settings == control_settings
        coverage(expected, shards)
        elapsed = [row["runner_seconds"] for row in summaries]
        phase_seconds = max(seconds(phase_ready, row["completed_at"]) for row in summaries)
        report["topologies"][key] = {
            "shard_phase_seconds": phase_seconds,
            "comparable": comparable, "slowest_shard_seconds": max(elapsed),
            "runner_minutes": sum(elapsed) / 60, "shard_spread_seconds": max(elapsed) - min(elapsed),
            "shards": summaries,
        }
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("options")
    run = sub.add_parser("run")
    run.add_argument("name")
    run.add_argument("seed", type=int)
    run.add_argument("cache", choices=["cold", "restore"])
    run.add_argument("output", type=Path)
    run.add_argument("--files", type=json.loads)
    inventory = sub.add_parser("inventory")
    inventory.add_argument("output", type=Path)
    inventory.add_argument("seed", type=int)
    plan = sub.add_parser("plan")
    plan.add_argument("output", type=Path)
    plan.add_argument("seed", type=int)
    plan.add_argument("topology", choices=["all", *TOPOLOGIES])
    report = sub.add_parser("verify")
    report.add_argument("directory", type=Path)
    report.add_argument("jobs", type=Path)
    report.add_argument("artifacts", type=Path)
    report.add_argument("seed", type=int)
    report.add_argument("cache", choices=["cold", "restore"])
    report.add_argument("topology", choices=["all", *TOPOLOGIES])
    args = parser.parse_args()

    if args.command == "options":
        topology, cache, seed, provider = options(os.environ["PR_BODY"])
        print(f"topology={topology}\ncache={cache}\nseed={seed}\nprovider={provider}")
    elif args.command == "run":
        benchmark(args.name, args.seed, args.cache, args.output, args.files)
    elif args.command == "inventory":
        discover(args.output, args.seed)
    elif args.command == "plan":
        print(json.dumps(make_plan(args.output, args.seed, args.topology), separators=(",", ":")))
    else:
        binding = {**candidate(), "run": os.environ["GITHUB_RUN_ID"],
                   "attempt": os.environ["GITHUB_RUN_ATTEMPT"], "seed": args.seed,
                   "cache_request": args.cache}
        print(json.dumps(verify(args.directory, json.loads(args.jobs.read_text()),
                                json.loads(args.artifacts.read_text()), binding, args.topology),
                         indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
