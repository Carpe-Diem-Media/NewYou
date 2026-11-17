import tempfile
import threading
import unittest
from pathlib import Path
import sys
import multiprocessing
import fcntl
import json
import os
import socket
import stat
import subprocess
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import local_plt_cache
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

    def test_fifo_manifest_is_rejected_without_blocking_or_changing_cache(self):
        cache = self.cache()
        cache.namespace.mkdir(parents=True)
        os.mkfifo(cache.manifest)
        lock_path = cache.cache_root / (cache.namespace.name + ".lock")
        script = "\n".join((
            "import sys",
            "from pathlib import Path",
            "from tools.local_plt_cache import Cache",
            "root=Path(sys.argv[1])",
            "cache=Cache(root/'cache',root/'work',"
            "{'otp':'27.2','elixir':'1.20.4','dialyxir':'1.4.8',"
            "'apps':['mix','ex_unit'],'revision':1},"
            "['dialyxir_erlang-27.2.plt','dialyxir_elixir.plt'])",
            "try:",
            "    cache.prepare(lambda _:None,root/'work'/'copy')",
            "except RuntimeError:",
            "    pass",
            "else:",
            "    raise AssertionError('FIFO manifest accepted')",
        ))
        result = subprocess.run(
            [sys.executable, "-c", script, str(self.root)],
            cwd=Path(__file__).resolve().parents[1],
            capture_output=True,
            text=True,
            timeout=2,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(cache.manifest.is_fifo())
        with lock_path.open("a+b") as lock_file:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)

    def test_directory_symlink_and_socket_manifests_are_rejected(self):
        target = self.root / "outside-manifest"
        target.write_text("preserve")
        socket_path = self.root / "socket-manifest"
        for kind in ("directory", "symlink", "socket"):
            with self.subTest(kind=kind):
                cache = self.cache({"manifest-kind": kind})
                cache.namespace.mkdir(parents=True)
                listener = None
                if kind == "directory":
                    cache.manifest.mkdir()
                elif kind == "symlink":
                    cache.manifest.symlink_to(target)
                else:
                    listener = socket.socket(socket.AF_UNIX)
                    listener.bind(str(socket_path))
                    os.replace(socket_path, cache.manifest)
                try:
                    self._assert_manifest_rejected_and_unlocked(cache)
                    if kind == "directory":
                        self.assertTrue(cache.manifest.is_dir())
                    elif kind == "symlink":
                        self.assertTrue(cache.manifest.is_symlink())
                        self.assertEqual(target.read_text(), "preserve")
                    else:
                        self.assertTrue(stat.S_ISSOCK(cache.manifest.lstat().st_mode))
                finally:
                    if listener is not None:
                        listener.close()

    def test_wrong_owner_manifest_is_rejected_and_lock_is_released(self):
        cache = self.cache()
        cache.prepare(self.producer, self.root / "work" / "first")
        actual_fstat = os.fstat

        def report_wrong_owner(descriptor):
            result = actual_fstat(descriptor)
            return SimpleNamespace(st_mode=result.st_mode, st_uid=os.getuid() + 1)

        with patch.object(local_plt_cache.os, "fstat", side_effect=report_wrong_owner):
            with self.assertRaisesRegex(RuntimeError, "incomplete or invalid"):
                cache.prepare(self.producer, self.root / "work" / "rejected")

        self.assertTrue(cache.manifest.is_file())
        self._assert_lock_available(cache)

    def _assert_manifest_rejected_and_unlocked(self, cache):
        with self.assertRaisesRegex(RuntimeError, "incomplete or invalid"):
            cache.prepare(self.producer, self.root / "work" / "rejected")
        self._assert_lock_available(cache)

    def _assert_lock_available(self, cache):
        lock_path = cache.cache_root / (cache.namespace.name + ".lock")
        with lock_path.open("a+b") as lock_file:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)

    def test_interrupted_private_copy_replacement_restores_owned_copy(self):
        cache = self.cache()
        destination = cache.prepare(self.producer, self.root / "work" / "analysis")
        original = {path.name: path.read_bytes() for path in destination.iterdir()}
        real_replace = os.replace

        def fail_staged_install(source, target):
            if Path(source).name.startswith(".core-copy-") and Path(target) == destination:
                raise OSError("injected private-copy install interruption")
            return real_replace(source, target)

        (destination / "dialyxir_erlang-27.2.plt").unlink()
        del original["dialyxir_erlang-27.2.plt"]
        with patch.object(local_plt_cache.os, "replace", side_effect=fail_staged_install):
            with self.assertRaisesRegex(OSError, "injected private-copy install interruption"):
                cache.prepare(self.producer, destination)

        self.assertEqual({path.name: path.read_bytes() for path in destination.iterdir()}, original)
        self.assertFalse(destination.with_name(destination.name + ".previous").exists())
        cache.validate_baseline()
        self._assert_lock_available(cache)

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

    def test_symlinked_build_ancestor_is_rejected_without_touching_target(self):
        outside = self.root / "outside"
        outside.mkdir()
        sentinel = outside / "sentinel"
        sentinel.write_bytes(b"keep")
        work_root = self.root / "worktree" / "_build" / "plts"
        work_root.parent.parent.mkdir(parents=True)
        work_root.parent.parent.joinpath("_build").symlink_to(outside, target_is_directory=True)
        cache = Cache(
            self.root / "cache",
            work_root,
            {"otp": "27.2", "elixir": "1.20.4", "dialyxir": "1.4.8", "apps": ["mix", "ex_unit"], "revision": 1},
            ["dialyxir_erlang-27.2.plt", "dialyxir_elixir.plt"],
        )

        with self.assertRaises(RuntimeError):
            cache.prepare(self.producer, work_root / "local-core")

        self.assertEqual(sentinel.read_bytes(), b"keep")
        self.assertEqual(list(outside.iterdir()), [sentinel])

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
