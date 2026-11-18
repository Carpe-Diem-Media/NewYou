"""Local command admission tests use temporary metadata, never PostgreSQL."""

import fcntl
import multiprocessing
import os
import select
import signal
import subprocess
import sys
import tempfile
import time
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
    def admission_adapters(self, directory, status="[]"):
        root = Path(local_session.__file__).resolve().parent.parent

        def probe(arguments, **_kwargs):
            if arguments[0] == "git":
                value = str(root) if "--show-toplevel" in arguments else directory
                return SimpleNamespace(returncode=0, stdout=value)
            self.assertEqual(arguments[-2:], ["slots", "status"])
            self.assertFalse(lock_available(Path(directory) / "newyou-build.lock"))
            return SimpleNamespace(returncode=0, stdout=status)
        return probe

    def test_normal_and_explicit_heavy_routes_retain_the_same_build_lock(self):
        for prefix, route in (
            (["test", "--"], ["run", "test", "--"]),
            (["dev", "--"], ["run", "dev", "--"]),
            (["test", "--heavy", "--"], ["slots", "run", "--heavy", "test", "--"]),
        ):
            with self.subTest(prefix=prefix), tempfile.TemporaryDirectory() as directory:
                command = ["mix", "do", "ecto.migrate,", "run", "probe.exs", "--heavy"]
                lock = Path(directory) / "newyou-build.lock"

                def execute(program, arguments):
                    self.assertEqual(program, "mise")
                    self.assertEqual(arguments, ["mise", "exec", "--",
                                                str(Path.home() / ".local/bin/devcore-project"),
                                                *route, *command])
                    self.assertFalse(lock_available(lock))
                    # An exec child must retain the actual inherited lock descriptor.
                    child = subprocess.Popen(
                        [sys.executable, "-c",
                         "import fcntl, os, sys; "
                         "from pathlib import Path; "
                         "target = os.stat(sys.argv[1]); "
                         "fds = [int(p.name) for p in Path('/proc/self/fd').iterdir() "
                         "if int(p.name) >= 10]; "
                         "assert any(os.fstat(fd).st_ino == target.st_ino and "
                         "os.fstat(fd).st_dev == target.st_dev for fd in fds); "
                         "fd = os.open(sys.argv[1], os.O_RDWR); "
                         "\ntry: fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)"
                         "\nexcept BlockingIOError: sys.exit(0)"
                         "\nraise SystemExit(1)", str(lock)],
                        close_fds=False)
                    child.wait(timeout=5)
                    self.assertEqual(child.returncode, 0)

                with patch.dict(os.environ, {}, clear=True), \
                        patch.object(local_session.subprocess, "run", self.admission_adapters(directory)), \
                        patch.object(local_session, "check_version") as version, \
                        patch.object(local_session.os, "chdir"), \
                        patch.object(local_session.os, "execvp", side_effect=execute) as launch:
                    local_session.main([*prefix, *command])
                    version.assert_called_once()
                    launch.assert_called_once()
                self.assertTrue(lock_available(lock))

    def test_malformed_or_unsupported_wrapper_options_launch_nothing(self):
        cases = [
            [], ["test"], ["test", "--"], ["test", "--heavy"],
            ["test", "--heavy", "--"], ["dev", "--heavy", "--", "true"],
            ["--heavy", "test", "--", "true"],
            ["test", "--heavy=true", "--", "true"],
            ["test", "--heavy", "--heavy", "--", "true"],
            ["test", "--retain", "--", "true"],
            ["test", "--heavy", "--wait", "1", "--", "true"],
            ["test", "mix", "test"],
        ]
        for arguments in cases:
            with self.subTest(arguments=arguments), \
                    patch.object(local_session.subprocess, "run") as probe, \
                    patch.object(local_session.os, "execvp") as execute, redirect_stderr(StringIO()):
                self.assertEqual(local_session.main(arguments), 2)
                probe.assert_not_called()
                execute.assert_not_called()

    def test_explicit_heavy_rejects_nested_and_legacy_markers_before_admission(self):
        for environment in ({"DEVCORE_SLOT_LEASE": "synthetic"},
                            {"DEVCORE_SLOT_PARTIAL": ""},
                            {"NEW_YOU_DATABASE_MODE": "legacy"}):
            with self.subTest(environment=environment), patch.dict(os.environ, environment, clear=True), \
                    patch.object(local_session.subprocess, "run") as probe, \
                    patch.object(local_session.os, "execvp") as execute, redirect_stderr(StringIO()):
                self.assertEqual(local_session.main(["test", "--heavy", "--", "true"]), 125)
                probe.assert_not_called()
                execute.assert_not_called()

    def test_explicit_heavy_admission_failures_never_fall_back(self):
        for failure in ("version", "declaration", "status", "exec"):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as directory:
                probe = self.admission_adapters(directory)
                calls = []

                def run(arguments, **kwargs):
                    if failure == "status" and arguments[-2:] == ["slots", "status"]:
                        return SimpleNamespace(returncode=1, stdout="private-placeholder")
                    return probe(arguments, **kwargs)

                def execute(*arguments):
                    calls.append(arguments)
                    raise OSError("private-placeholder")

                output = StringIO()
                with patch.dict(os.environ, {}, clear=True), \
                        patch.object(local_session.subprocess, "run", run), \
                        patch.object(local_session, "check_version",
                                     side_effect=local_session.SessionError("unsupported version")
                                     if failure == "version" else None), \
                        patch.object(local_session.os, "chdir"), \
                        patch.object(local_session.os, "execvp", execute), \
                        patch.object(Path, "read_text", return_value="PROJECT_KEY=other"
                                     if failure == "declaration" else
                                     "PROJECT_KEY=new_you\nSLOT_POOL=.devcore/slots.json\n"), \
                        redirect_stderr(output):
                    self.assertEqual(local_session.main(["test", "--heavy", "--", "true"]), 125)
                self.assertEqual(len(calls), 1 if failure == "exec" else 0)
                self.assertNotIn("private-placeholder", output.getvalue())

    def test_explicit_heavy_status_and_prior_jobs_fail_closed(self):
        root = Path(local_session.__file__).resolve().parent.parent
        for status in ('invalid json', '{}', '[null]',
                       '[{"worktree": "' + str(root) + '", "state": "in_use", "jobs": {}}]'):
            with self.subTest(status=status), tempfile.TemporaryDirectory() as directory, \
                    patch.dict(os.environ, {}, clear=True), \
                    patch.object(local_session.subprocess, "run", self.admission_adapters(directory, status)), \
                    patch.object(local_session, "check_version"), \
                    patch.object(local_session.os, "execvp") as execute, redirect_stderr(StringIO()):
                self.assertEqual(local_session.main(["test", "--heavy", "--", "true"]), 125)
                execute.assert_not_called()

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

    def test_lock_survives_devcore_fd3_heredoc_and_launcher_exit(self):
        root = Path(local_session.__file__).resolve().parent.parent
        installed = Path.home() / ".local/bin/devcore-project"
        if installed.is_file():
            source = installed.read_text()
            self.assertIn("python3 /dev/fd/3 \"$0\"", source,
                          "installed DevCore handoff no longer matches this regression")
            self.assertIn("3<<'DEVCORE_SLOTS_PYTHON'", source,
                          "installed DevCore fd 3 heredoc no longer matches this regression")
        # DevCore's installed slots_main sends its embedded Python on fd 3.
        # Keep that reviewed handoff shape, while the synthetic supervisor
        # waits before registering any job or starting a command.
        shell = """#!/bin/sh
echo $$ > "$3"
python3 /dev/fd/3 "$1" "$2" 3<<'DEVCORE_SLOTS_PYTHON'
import os, sys, time
from pathlib import Path
Path(sys.argv[1]).write_text(str(os.getpid()))
while not Path(sys.argv[2]).exists(): time.sleep(.01)
DEVCORE_SLOTS_PYTHON
"""
        launcher = """import os, sys
from pathlib import Path
from tools.local_session import worktree_lock
context = worktree_lock(Path(sys.argv[1]))
context.__enter__()
os.execvp('mise', ['mise', 'exec', '--', 'bash', '-c', sys.argv[2],
                   'slots_main', sys.argv[3], sys.argv[4], sys.argv[5]])
"""
        with tempfile.TemporaryDirectory() as directory:
            root_dir = Path(directory)
            lock = root_dir / "build.lock"
            ready, finish, launcher_pid_file = (root_dir / "ready", root_dir / "finish",
                                                 root_dir / "launcher-pid")
            process = subprocess.Popen([sys.executable, "-c", launcher, str(lock), shell,
                                        str(ready), str(finish), str(launcher_pid_file)], cwd=root,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                       start_new_session=True)
            try:
                deadline = time.monotonic() + 5
                while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertTrue(ready.exists(), "installed handoff shape did not start")
                supervisor_pid = int(ready.read_text())
                launcher_pid = int(launcher_pid_file.read_text())
                self.assertTrue(Path("/proc", str(supervisor_pid), "stat").exists(),
                                "supervisor exited before the lock check")
                self.assertFalse(lock_available(lock),
                                 "lock must remain held before launcher exit")
                os.kill(launcher_pid, signal.SIGTERM)
                process.wait(timeout=5)
                self.assertTrue(Path("/proc", str(supervisor_pid), "stat").exists(),
                                "supervisor must remain alive after launcher exit")
                self.assertFalse(lock_available(lock),
                                 "DevCore supervisor must retain the lock after launcher exit")
            finally:
                finish.touch()
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
                deadline = time.monotonic() + 5
                while ready.exists() and Path("/proc", ready.read_text(), "stat").exists() \
                        and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertTrue(select.select([process.stdout], [], [], 5)[0],
                                "handoff child retained the output pipe")
                self.assertEqual(process.stdout.read(), b"")
                process.stdout.close()
                process.stderr.close()

    def test_installed_devcore_status_retains_lock_while_registry_is_blocked(self):
        installed = Path.home() / ".local/bin/devcore-project"
        if not installed.is_file():
            self.skipTest("installed DevCore is unavailable")

        root = Path(local_session.__file__).resolve().parent.parent
        launcher = """import os, sys
from pathlib import Path
from tools.local_session import worktree_lock
context = worktree_lock(Path(sys.argv[1]))
context.__enter__()
os.execvp('mise', ['mise', 'exec', '--', str(Path.home() / '.local/bin/devcore-project'),
                   'slots', 'status'])
"""

        def proc_info(pid):
            try:
                stat_fields = Path("/proc", str(pid), "stat").read_text().rsplit(")", 1)[1].split()
                return int(stat_fields[1]), Path("/proc", str(pid), "comm").read_text().strip()
            except (OSError, ValueError, IndexError):
                return None

        def descendant_pids(root_pid):
            children = {}
            for entry in Path("/proc").iterdir():
                if not entry.name.isdecimal():
                    continue
                info = proc_info(int(entry.name))
                if info is not None:
                    children.setdefault(info[0], []).append(int(entry.name))
            pending, found = [root_pid], set()
            while pending:
                current = pending.pop()
                for child_pid in children.get(current, []):
                    if child_pid not in found:
                        found.add(child_pid)
                        pending.append(child_pid)
            return found

        with tempfile.TemporaryDirectory() as directory:
            temp_root = Path(directory)
            central = temp_root / "central"
            slots_root = central / "slots"
            pool_root = slots_root / "new_you"
            pool_root.mkdir(mode=0o700, parents=True)
            os.chmod(central, 0o700)
            os.chmod(slots_root, 0o700)
            os.chmod(pool_root, 0o700)
            project_conf = temp_root / "project.conf"
            project_conf.write_text("\n".join(
                line for line in (root / ".devcore/project.conf").read_text().splitlines()
                if not line.startswith("SLOT_POOL=")
            ) + "\n")
            global_conf, secrets = temp_root / "global.conf", temp_root / "secrets.env"
            global_conf.touch(mode=0o600)
            secrets.touch(mode=0o600)
            registry = pool_root / "registry.lock"
            registry.touch(mode=0o600)
            registry_fd = os.open(registry, os.O_RDWR | os.O_NOFOLLOW)
            fcntl.flock(registry_fd, fcntl.LOCK_EX)
            lock, sibling_lock = temp_root / "build.lock", temp_root / "sibling.lock"
            environment = {key: value for key, value in os.environ.items()
                           if not key.startswith("DEVCORE_")}
            environment.update(
                DEVCORE_CONFIG_DIR=str(central),
                DEVCORE_SECRETS_FILE=str(secrets),
                DEVCORE_GLOBAL_CONF=str(global_conf),
                DEVCORE_PROJECT_CONF=str(project_conf),
            )
            process = subprocess.Popen([sys.executable, "-c", launcher, str(lock)], cwd=root,
                                       env=environment, stdout=subprocess.PIPE,
                                       stderr=subprocess.PIPE, start_new_session=True)
            try:
                deadline = time.monotonic() + 10
                python_pid, bash_pid = None, None
                while time.monotonic() < deadline and process.poll() is None:
                    for pid in descendant_pids(process.pid):
                        info = proc_info(pid)
                        if info is None or info[1] not in ("python3", "python"):
                            continue
                        parent_info = proc_info(info[0])
                        if parent_info is not None and parent_info[1] == "bash":
                            python_pid, bash_pid = pid, info[0]
                            break
                    if python_pid is not None:
                        break
                    time.sleep(0.01)
                self.assertIsNotNone(python_pid,
                                     "installed slots status did not reach its blocked Python registry read; "
                                     f"launcher exit={process.poll()}, "
                                     f"stderr={process.stderr.peek(4096).decode(errors='replace') if process.poll() is not None else ''}")
                self.assertIsNotNone(bash_pid)
                self.assertTrue(Path("/proc", str(python_pid), "stat").exists())
                self.assertFalse(lock_available(lock), "same-worktree lock must be held before launcher exit")
                self.assertTrue(lock_available(sibling_lock), "a sibling worktree lock must remain independent")
                os.kill(bash_pid, signal.SIGTERM)
                process.wait(timeout=5)
                self.assertTrue(Path("/proc", str(python_pid), "stat").exists(),
                                "installed DevCore Python must survive Bash launcher termination")
                self.assertFalse(lock_available(lock),
                                 "installed DevCore Python must retain the build lock while blocked")
            finally:
                fcntl.flock(registry_fd, fcntl.LOCK_UN)
                os.close(registry_fd)
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
                stdout, stderr = process.communicate(timeout=5)
                self.assertEqual(stdout, b"[]\n")
                self.assertEqual(stderr, b"")
                self.assertTrue(lock_available(lock), "status completion must release the build lock")

    def test_old_or_unknown_devcore_is_rejected_before_status_or_launch(self):
        for output in ("devcore-project 1.1.0", "devcore-project 1.2.0", "unknown", "devcore-project 2.0.0"):
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
