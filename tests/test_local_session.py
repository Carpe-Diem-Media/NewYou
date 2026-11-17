"""Local command admission tests use temporary metadata, never PostgreSQL."""

import fcntl
import multiprocessing
import os
import select
import signal
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr
from io import StringIO
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from tools import local_session


def lock_available(path):
    with path.open("a+b") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return True
        except BlockingIOError:
            return False


def hold_lock(path, entered, finish):
    with local_session.worktree_lock(Path(path)):
        entered.set()
        finish.wait(10)


class LocalSessionTests(unittest.TestCase):
    def test_cancelling_a_waiter_preserves_the_current_holder(self):
        root = Path(local_session.__file__).resolve().parent.parent
        waiter = """import sys
from pathlib import Path
from tools.local_session import worktree_lock
try:
    print('waiting', flush=True)
    with worktree_lock(Path(sys.argv[1])):
        raise SystemExit('unexpected admission')
except KeyboardInterrupt:
    raise SystemExit(130)
"""
        with tempfile.TemporaryDirectory() as directory:
            lock = Path(directory) / "build.lock"
            with local_session.worktree_lock(lock):
                process = subprocess.Popen([sys.executable, "-c", waiter, str(lock)],
                                           cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                try:
                    self.assertTrue(select.select([process.stdout], [], [], 5)[0])
                    self.assertEqual(process.stdout.readline().strip(), b"waiting")
                    process.send_signal(signal.SIGINT)
                    self.assertEqual(process.wait(timeout=5), 130)
                    self.assertFalse(lock_available(lock))
                finally:
                    if process.poll() is None:
                        process.terminate()
                        process.wait(timeout=5)
                    process.stdout.close()
                    process.stderr.close()
            self.assertTrue(lock_available(lock))

    def test_entry_point_rejects_old_installation_without_status_or_exec(self):
        root = Path(local_session.__file__).resolve().parent.parent
        calls = []

        def probe(arguments, **_kwargs):
            calls.append(arguments)
            return SimpleNamespace(returncode=0, stdout=(str(root) if arguments[0] == "git"
                                                        else "devcore-project 1.1.0"))

        check_version = local_session.check_version
        with patch.dict(os.environ, {}, clear=True), patch.object(local_session.subprocess, "run", probe), \
                patch.object(local_session.os, "execvp") as execute, redirect_stderr(StringIO()):
            # check_version's default adapter is bound at definition time.
            with patch.object(local_session, "check_version", lambda tool: check_version(tool, probe)):
                self.assertEqual(local_session.main(["test", "--", "mix", "test"]), 125)
        self.assertEqual(len(calls), 2)
        execute.assert_not_called()

    def test_entry_point_redacts_failed_status_and_launches_no_command(self):
        root = Path(local_session.__file__).resolve().parent.parent
        with tempfile.TemporaryDirectory() as directory:
            def probe(arguments, **_kwargs):
                if arguments[0] == "git":
                    value = str(root) if "--show-toplevel" in arguments else directory
                    return SimpleNamespace(returncode=0, stdout=value)
                return SimpleNamespace(returncode=1, stdout="private-placeholder", stderr="private-placeholder")

            output = StringIO()
            with patch.dict(os.environ, {}, clear=True), patch.object(local_session.subprocess, "run", probe), \
                    patch.object(local_session, "check_version"), patch.object(local_session.os, "execvp") as execute, \
                    redirect_stderr(output):
                self.assertEqual(local_session.main(["test", "--", "mix", "test"]), 125)
            self.assertNotIn("private-placeholder", output.getvalue())
            self.assertIn("no command launched", output.getvalue())
            execute.assert_not_called()

    def test_lock_survives_mise_bash_exec_and_launcher_exit_until_child_finishes(self):
        root = Path(local_session.__file__).resolve().parent.parent
        # This models descriptor propagation only. DevCore's descendant registry
        # and abnormal-supervisor recovery have separate allocator proofs.
        child = "import sys; print('ready', flush=True); sys.stdin.buffer.read(); print('done', flush=True)"
        supervisor = (
            "import subprocess, sys; "
            "subprocess.Popen([sys.executable, '-c', sys.argv[1]], close_fds=False)"
        )
        launcher = (
            "import os, sys; from pathlib import Path; from tools.local_session import worktree_lock; "
            "context = worktree_lock(Path(sys.argv[1])); context.__enter__(); "
            "os.execvp('mise', ['mise', 'exec', '--', 'bash', '-c', "
            "'exec python3 -c \"$1\" \"$2\"', 'newyou-lock-proof', sys.argv[2], sys.argv[3]])"
        )
        with tempfile.TemporaryDirectory() as directory:
            lock = Path(directory) / "build.lock"
            process = subprocess.Popen([sys.executable, "-c", launcher, str(lock), supervisor, child],
                                       cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                       stderr=subprocess.PIPE, start_new_session=True)
            try:
                self.assertTrue(select.select([process.stdout], [], [], 15)[0], "exec child did not start")
                self.assertEqual(process.stdout.readline().strip(), b"ready")
                self.assertEqual(process.wait(timeout=5), 0)
                self.assertFalse(lock_available(lock), "launcher exit released a child's inherited lock")
                process.stdin.close()
                self.assertTrue(select.select([process.stdout], [], [], 5)[0], "child did not finish")
                self.assertEqual(process.stdout.readline().strip(), b"done")
                self.assertTrue(select.select([process.stdout], [], [], 5)[0], "child retained stdout")
                self.assertEqual(process.stdout.read(), b"")
                self.assertTrue(lock_available(lock))
            finally:
                if process.stdin and not process.stdin.closed:
                    process.stdin.close()
                # EOF lets the owned orphan finish. Popen only signals its own
                # still-live direct child, never a stale process-group number.
                if process.poll() is None:
                    process.terminate()
                process.wait(timeout=5)
                process.stdout.close()
                process.stderr.close()

    def test_old_or_unknown_devcore_is_rejected_before_status_or_launch(self):
        for output in ("devcore-project 1.1.0", "unknown", "devcore-project 2.0.0"):
            calls = []

            def probe(arguments, **_kwargs):
                calls.append(arguments)
                return SimpleNamespace(returncode=0, stdout=output)

            with self.assertRaisesRegex(local_session.SessionError, "DevCore"):
                local_session.check_version(Path("/fake/devcore-project"), probe)
            self.assertEqual(len(calls), 1)
            self.assertEqual(calls[0][-1], "--version")

    def test_in_use_and_uncertain_jobs_block_same_worktree_without_process_actions(self):
        root = Path("/tmp/worktree-a")
        for state in ("preparing", "in_use", "cleaning", "quarantined"):
            with self.assertRaisesRegex(local_session.SessionError, "worktree"):
                local_session.check_jobs(root, [{"worktree": str(root), "state": state, "jobs": {}}])

        with self.assertRaises(local_session.SessionError):
            local_session.check_jobs(root, [{"worktree": str(root), "state": "retained", "jobs": {"job": {}}}])

    def test_idle_retained_diagnosis_and_other_worktrees_do_not_serialize_new_work(self):
        root = Path("/tmp/worktree-a")
        local_session.check_jobs(root, [
            {"worktree": str(root), "state": "retained", "jobs": {}},
            {"worktree": "/tmp/worktree-b", "state": "in_use", "jobs": {"job": {}}},
        ])

    def test_a_live_lock_excludes_the_same_worktree_but_not_a_sibling(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            entered, finish = multiprocessing.Event(), multiprocessing.Event()
            process = multiprocessing.Process(target=hold_lock, args=(str(root / "a.lock"), entered, finish))
            process.start()
            try:
                self.assertTrue(entered.wait(5), "holder did not acquire temporary lock")
                self.assertFalse(lock_available(root / "a.lock"))
                self.assertTrue(lock_available(root / "b.lock"))
            finally:
                finish.set()
                process.join(5)
                if process.is_alive():
                    process.terminate()
                    process.join()
            self.assertEqual(process.exitcode, 0)
            self.assertTrue(lock_available(root / "a.lock"))

    def test_lock_is_private_inheritable_and_does_not_follow_a_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with local_session.worktree_lock(root / "build.lock") as descriptor:
                self.assertTrue(os.get_inheritable(descriptor))
                self.assertEqual((root / "build.lock").stat().st_mode & 0o777, 0o600)
            protected = root / "retained"
            protected.write_text("preserve")
            (root / "linked.lock").symlink_to(protected)
            with self.assertRaises((OSError, local_session.SessionError)):
                with local_session.worktree_lock(root / "linked.lock"):
                    self.fail("symlink lock was accepted")
            self.assertEqual(protected.read_text(), "preserve")
