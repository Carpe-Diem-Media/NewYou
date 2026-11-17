import tempfile
import threading
import unittest
from pathlib import Path
import sys
import multiprocessing
import fcntl
import json
import subprocess

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from local_plt_cache import Cache, write_request


class LocalPltCacheTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.calls = 0
        self.call_lock = threading.Lock()

    def tearDown(self):
        self.temp.cleanup()

    def producer(self, destination):
        with self.call_lock:
            self.calls += 1
        (destination / "dialyxir_erlang-27.2.plt").write_bytes(b"erlang baseline")
        (destination / "dialyxir_elixir.plt").write_bytes(b"elixir baseline")

    def cache(self, key=None):
        return Cache(self.root / "cache", self.root / "work", key or {"otp": "27.2", "elixir": "1.20.4", "dialyxir": "1.4.8", "apps": ["mix", "ex_unit"], "revision": 1}, ["dialyxir_erlang-27.2.plt", "dialyxir_elixir.plt"])

    def test_publishes_valid_baseline_and_independent_copies(self):
        cache = self.cache()
        left = cache.prepare(self.producer, self.root / "work" / "left")
        right = cache.prepare(self.producer, self.root / "work" / "right")
        self.assertEqual(self.calls, 1)
        self.assertNotEqual(left, right)
        self.assertFalse(left.joinpath("dialyxir_erlang-27.2.plt").samefile(right / "dialyxir_erlang-27.2.plt"))
        left.joinpath("dialyxir_erlang-27.2.plt").write_bytes(b"changed")
        self.assertEqual((right / "dialyxir_erlang-27.2.plt").read_bytes(), b"erlang baseline")
        self.assertEqual(cache.prepare(self.producer, left), left)
        self.assertEqual((left / "dialyxir_erlang-27.2.plt").read_bytes(), b"changed")
        self.assertEqual(self.calls, 1)
        cache.validate_baseline()

    def test_key_drift_creates_distinct_namespace(self):
        self.cache().prepare(self.producer, self.root / "work" / "one")
        self.cache({"otp": "28.0", "elixir": "1.20.4", "dialyxir": "1.4.8", "apps": ["mix", "ex_unit"], "revision": 1}).prepare(self.producer, self.root / "work" / "two")
        self.assertEqual(self.calls, 2)

    def test_incomplete_or_dirty_baseline_is_rejected(self):
        cache = self.cache()
        with self.assertRaises(RuntimeError):
            cache.prepare(lambda path: (path / "dialyxir_erlang-27.2.plt").write_bytes(b"partial"), self.root / "work" / "broken")
        self.assertFalse(cache.namespace.exists())
        cache.prepare(self.producer, self.root / "work" / "good")
        (cache.namespace / "dialyxir_erlang-27.2.plt").write_bytes(b"tampered")
        with self.assertRaises(RuntimeError):
            cache.validate_baseline()

    def test_failure_does_not_publish_and_retry_succeeds(self):
        cache = self.cache()
        def failed(path):
            (path / "dialyxir_erlang-27.2.plt").write_bytes(b"partial")
            raise OSError("producer interrupted")
        with self.assertRaises(OSError):
            cache.prepare(failed, self.root / "work" / "broken")
        self.assertFalse(cache.namespace.exists())
        cache.prepare(self.producer, self.root / "work" / "retry")

    def test_parallel_cold_requests_prepare_once_and_copy_after_lock(self):
        cache = self.cache()
        barrier = threading.Barrier(6)
        results = []
        def request(index):
            barrier.wait()
            results.append(cache.prepare(self.producer, self.root / "work" / str(index)))
        threads = [threading.Thread(target=request, args=(i,)) for i in range(6)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
        self.assertEqual(self.calls, 1)
        self.assertEqual(len(set(results)), 6)
        self.assertEqual(len(list(cache.work_root.glob("*/"))), 6)

    def test_lock_is_released_before_prepare_returns(self):
        cache = self.cache()
        cache.prepare(self.producer, self.root / "work" / "analysis")
        lock_path = cache.cache_root / (cache.namespace.name + ".lock")
        with lock_path.open("a+b") as lock_file:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)

    def test_subprocess_producer_receives_private_stage_and_core_plan(self):
        names = ["dialyxir_erlang-27.2.plt", "dialyxir_erlang-27.2_elixir-1.20.4.plt"]
        request = {
            "cache_root": str(self.root / "cache"),
            "work_root": str(self.root / "work"),
            "destination": str(self.root / "work" / "private"),
            "key": {"otp": "27.2-full", "architecture": "x86_64", "elixir": "1.20.4", "dialyxir": "1.4.8", "apps": ["erts", "kernel", "stdlib", "crypto", "elixir"], "inputs": "abc", "format": 1},
            "plt_names": names,
            "producer_plan": "safe-test-plan",
            "producer": [
                sys.executable,
                "-c",
                "import os,pathlib; p=pathlib.Path(os.environ['NEWYOU_PLT_STAGING']); assert os.environ['NEWYOU_PLT_PLAN']=='safe-test-plan'; [ (p/n).write_bytes(n.encode()) for n in " + repr(names) + " ]",
            ],
        }
        request_path = self.root / "request.json"
        request_path.write_text(json.dumps(request))
        subprocess.run([sys.executable, "tools/local_plt_cache.py", str(request_path)], check=True)
        self.assertEqual(sorted(path.name for path in (self.root / "work" / "private").glob("*.plt")), sorted(names))

    def test_request_file_is_created_with_private_permissions(self):
        path = self.root / "request.json"
        write_request(path, b"{}")
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_processes_share_one_cold_preparation(self):
        context = multiprocessing.get_context("fork")
        barrier = context.Barrier(4)
        counter = context.Value("i", 0)
        output = context.Queue()
        args = (str(self.root / "cache"), str(self.root / "work"), barrier, counter, output)
        workers = [context.Process(target=_process_request, args=(index, *args)) for index in range(4)]
        for worker in workers:
            worker.start()
        for worker in workers:
            worker.join(10)
            self.assertEqual(worker.exitcode, 0)
        paths = [output.get(timeout=1) for _ in workers]
        self.assertEqual(counter.value, 1)
        self.assertEqual(len(set(paths)), 4)


def _process_request(index, cache_root, work_root, barrier, counter, output):
    key = {"otp": "27.2", "elixir": "1.20.4", "dialyxir": "1.4.8", "apps": ["mix", "ex_unit"], "revision": 1}
    names = ["dialyxir_erlang-27.2.plt", "dialyxir_elixir.plt"]
    cache = Cache(cache_root, work_root, key, names)
    barrier.wait()

    def produce(destination):
        with counter.get_lock():
            counter.value += 1
        (destination / names[0]).write_bytes(b"erlang")
        (destination / names[1]).write_bytes(b"elixir")

    output.put(str(cache.prepare(produce, Path(work_root) / f"process-{index}")))


if __name__ == "__main__":
    unittest.main()
