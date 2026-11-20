"""Run and verify the optional, cold-cache ExUnit benchmark for WELL-103."""

import argparse
from collections import Counter
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess

SEEDS = (852013, 211963)
MODES = ("control", "shard-1", "shard-2")


def job_name(seed, mode):
    return f"shadow-{seed}-{mode}"


def inventory():
    tracked = subprocess.check_output(["git", "ls-files", "-z", "--", "test"])
    # Mirrors the current project test_load_filters. The unrestricted control
    # and the runtime file checks below detect drift from Mix discovery.
    return sorted({path for path in tracked.decode().split("\0")
                   if path.endswith("_test.exs") and path != "test/proof/self_test.exs"})


def select(files, mode):
    if mode == "control":
        return files
    return files[MODES.index(mode) - 1::2]


def digest(files):
    return hashlib.sha256(json.dumps(files, separators=(",", ":")).encode()).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_events(events, files, seed, job):
    identities = Counter()
    modules = []
    tests = []
    suites = []
    for event in events:
        kind = event["kind"]
        if kind == "suite":
            suites.append(event)
            continue
        require(kind in ("module", "test"), f"{job}: unexpected event kind")
        require(event["file"] in files, f"{job}: unexpected test file {event['file']}")
        require(event["status"] == "passed", f"{job}: non-passing {kind} {event['status']}")
        require(type(event["us"]) is int and event["us"] >= 0, f"{job}: invalid duration")
        if kind == "test":
            identity = (event["file"], event["module"], event["name"])
            identities[identity] += 1
            tests.append(event)
        else:
            modules.append(event)

    require(identities and all(n == 1 for n in identities.values()),
            f"{job}: empty or duplicate test identity")
    require({file for file, _, _ in identities} == set(files), f"{job}: missing test file")
    module_keys = {(event["file"], event["module"]) for event in modules}
    require(module_keys == {(file, module) for file, module, _ in identities}
            and len(modules) == len(module_keys), f"{job}: missing or duplicate module")
    require(len(suites) == 1 and events[-1]["kind"] == "suite",
            f"{job}: missing or duplicate suite completion")
    suite = suites[0]
    require(suite["seed"] == seed and suite["max_cases"] > 0, f"{job}: wrong ExUnit configuration")
    return identities, {
        "tests": len(tests), "suite": suite,
        "slow_tests": sorted(tests, key=lambda event: -event["us"])[:15],
        "slow_modules": sorted(modules, key=lambda event: -event["us"])[:15],
    }


def timestamp(value):
    return datetime.fromisoformat(value).timestamp()


def verify(files, jobs, artifacts, sha, run_id, attempt):
    results = {}
    for seed in SEEDS:
        cohort = set()
        identities = {}
        rows = {}
        for mode in MODES:
            name = job_name(seed, mode)
            require(name in jobs, f"{name}: missing job")
            job = jobs[name]
            require(job["conclusion"] == "success", f"{name}: job conclusion {job['conclusion']}")
            require(name in artifacts, f"{name}: missing artifact")
            evidence = artifacts[name]
            metadata = evidence["metadata"]
            selected = select(files, mode)
            expected = {
                "sha": sha, "seed": seed, "mode": mode, "cache": "cold",
                "files": digest(selected), "run_id": run_id, "attempt": attempt,
            }
            require(all(metadata[key] == value for key, value in expected.items()),
                    f"{name}: evidence binding mismatch")
            require(metadata["image"] and metadata["arch"] and metadata["cpus"] > 0,
                    f"{name}: runner metadata missing")
            identities[mode], row = read_events(evidence["events"], selected, seed, name)
            cohort.add((metadata["image"], metadata["arch"], metadata["cpus"],
                        row["suite"]["max_cases"]))
            row["start"] = timestamp(job["started_at"])
            row["end"] = timestamp(job["completed_at"])
            row["runner_s"] = row["end"] - row["start"]
            row["steps_s"] = {
                step["name"]: timestamp(step["completed_at"]) - timestamp(step["started_at"])
                for step in job["steps"] if step.get("started_at") and step.get("completed_at")
            }
            rows[mode] = row

        require(len(cohort) == 1, f"{seed}: incomparable runner or ExUnit settings")
        first, second = (identities[mode] for mode in MODES[1:])
        require(not (first.keys() & second.keys()) and first + second == identities["control"],
                f"{seed}: control and shard test identities differ")
        control, first_job, second_job = (rows[mode] for mode in MODES)
        pair_start = min(row["start"] for row in rows.values())
        rows["control_wall_s"] = control["end"] - pair_start
        rows["shard_wall_s"] = max(first_job["end"], second_job["end"]) - pair_start
        rows["extra_runner_s"] = first_job["runner_s"] + second_job["runner_s"] - control["runner_s"]
        rows["runner"] = next(iter(cohort))
        results[seed] = rows
    return results


def run_benchmark(seed, mode, output):
    require("MIX_TEST_PARTITION" not in os.environ, "partition environment must be unset")
    require(os.environ.get("MIX_ENV") == "test", "benchmark requires MIX_ENV=test")
    selected = select(inventory(), mode)
    require(selected, "empty test-file inventory")
    output.mkdir()
    metadata = {
        "sha": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
        "seed": seed, "mode": mode, "cache": "cold", "files": digest(selected),
        "image": f"{os.environ['ImageOS']}-{os.environ['ImageVersion']}",
        "arch": os.environ["RUNNER_ARCH"], "cpus": int(subprocess.check_output(["nproc"])),
        "run_id": os.environ["GITHUB_RUN_ID"], "attempt": os.environ["GITHUB_RUN_ATTEMPT"],
    }
    (output / "job.json").write_text(json.dumps(metadata) + "\n", encoding="utf-8")
    os.environ["NEWYOU_SHADOW_EVENTS_FILE"] = str(output / "events.jsonl")
    task = "test" if mode == "shard-2" else "check"
    args = ["mix", task, "--seed", str(seed), "--formatter", "ExUnit.CLIFormatter",
            "--formatter", "NewYou.ShadowBenchmarkFormatter"]
    if mode != "control":
        args.extend(selected)
    os.execvp("mix", args)


def report(directory, jobs_file, sha, run_id, attempt):
    jobs = {}
    for job in json.loads(jobs_file.read_text(encoding="utf-8"))["jobs"]:
        if job["name"].startswith("shadow-"):
            require(job["name"] not in jobs, f"duplicate job {job['name']}")
            jobs[job["name"]] = job
    artifacts = {}
    suffix = f"-attempt-{attempt}"
    for path in sorted(directory.glob(f"shadow-*{suffix}")):
        metadata = path / "job.json"
        events = path / "events.jsonl"
        if metadata.is_file() and events.is_file():
            artifacts[path.name.removesuffix(suffix)] = {
                "metadata": json.loads(metadata.read_text(encoding="utf-8")),
                "events": [json.loads(line) for line in events.read_text(encoding="utf-8").splitlines()],
            }
    print(json.dumps(verify(inventory(), jobs, artifacts, sha, run_id, attempt), indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    run = commands.add_parser("run")
    run.add_argument("seed", type=int, choices=SEEDS)
    run.add_argument("mode", choices=MODES)
    run.add_argument("output", type=Path)
    verify_parser = commands.add_parser("report")
    verify_parser.add_argument("directory", type=Path)
    verify_parser.add_argument("jobs", type=Path)
    verify_parser.add_argument("sha")
    verify_parser.add_argument("run_id")
    verify_parser.add_argument("attempt")
    args = parser.parse_args()
    try:
        if args.command == "run":
            run_benchmark(args.seed, args.mode, args.output)
        else:
            report(args.directory, args.jobs, args.sha, args.run_id, args.attempt)
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f"ExUnit shadow benchmark: {error}\n")


if __name__ == "__main__":
    main()
