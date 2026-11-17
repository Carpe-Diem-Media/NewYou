"""Admit one managed command per worktree without changing database ownership.

DevCore owns leases, descendants, credentials and cleanup. This wrapper owns only
the worktree build lock and checks for unresolved prior work before admission.
"""

import contextlib
import fcntl
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path


class SessionError(RuntimeError):
    """A non-secret, fail-closed admission diagnosis."""


@contextlib.contextmanager
def worktree_lock(path):
    descriptor = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid() or info.st_nlink != 1:
            raise SessionError("worktree lock ownership is invalid")
        os.fchmod(descriptor, 0o600)
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        # DevCore uses fd 3 for its embedded Python source heredoc.
        # Keep the lock on a separate descriptor through that handoff.
        inherited_descriptor = fcntl.fcntl(descriptor, fcntl.F_DUPFD, 10)
        os.close(descriptor)
        descriptor = inherited_descriptor
        os.set_inheritable(descriptor, True)
        yield descriptor
    finally:
        os.close(descriptor)


def check_version(tool, probe=subprocess.run):
    result = probe([str(tool), "--version"], capture_output=True, text=True, timeout=10)
    version = re.fullmatch(r"devcore-project 1\.(\d+)\.(\d+)\s*", result.stdout)
    if result.returncode or not version or tuple(map(int, version.groups())) < (2, 0):
        raise SessionError("DevCore managed-slot capability requires reviewed installation of version 1.2 or compatible 1.x")


def check_jobs(root, rows):
    if not isinstance(rows, list):
        raise SessionError("worktree allocation status is unavailable")
    for row in rows:
        if not isinstance(row, dict):
            raise SessionError("worktree allocation status is invalid")
        if row.get("worktree") != str(root):
            continue
        if row.get("jobs") != {} or row.get("state") not in ("free", "ready", "retained"):
            raise SessionError("worktree has unresolved managed jobs; inspect devcore-project slots status and preserve their resources")


def main(arguments=None):
    arguments = list(sys.argv[1:] if arguments is None else arguments)
    if len(arguments) < 3 or arguments[0] not in ("dev", "test") or arguments[1] != "--":
        print("Usage: mise exec -- tools/newyou-local dev|test -- <command>", file=sys.stderr)
        return 2

    try:
        if any(key.startswith("DEVCORE_SLOT_") for key in os.environ):
            raise SessionError("inside a managed job, use the compatible devcore-project run command to reuse its lease")
        if os.environ.get("NEW_YOU_DATABASE_MODE"):
            raise SessionError("the local entry point requires automatic managed allocation")

        root = Path(__file__).resolve().parent.parent
        actual = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True,
                                text=True, check=True).stdout.strip()
        if Path(actual).resolve() != root:
            raise SessionError("run this worktree's local entry point from its repository")
        declaration = (root / ".devcore/project.conf").read_text()
        if not re.search(r"^PROJECT_KEY=new_you$", declaration, re.M) or not re.search(
                r"^SLOT_POOL=\.devcore/slots\.json$", declaration, re.M):
            raise SessionError("worktree has no managed NewYou declaration; no legacy fallback")

        tool = Path.home() / ".local/bin/devcore-project"
        check_version(tool)
        git_directory = subprocess.run(
            ["git", "rev-parse", "--path-format=absolute", "--git-dir"],
            capture_output=True, text=True, check=True).stdout.strip()

        with worktree_lock(Path(git_directory) / "newyou-build.lock"):
            status = subprocess.run([str(tool), "slots", "status"], cwd=root,
                                    capture_output=True, text=True, timeout=10)
            if status.returncode:
                raise SessionError("worktree allocation status is unavailable; no command launched")
            check_jobs(root, json.loads(status.stdout))
            os.chdir(root)
            os.execvp("mise", ["mise", "exec", "--", str(tool), "run", arguments[0], "--", *arguments[2:]])
    except KeyboardInterrupt:
        return 130
    except SessionError as error:
        print(str(error), file=sys.stderr)
        return 125
    except (OSError, ValueError, subprocess.SubprocessError):
        # Never forward captured command output, environment or credentials.
        print("NewYou local admission failed. Preserve jobs and inspect the reviewed DevCore installation and slot status.", file=sys.stderr)
        return 125


if __name__ == "__main__":
    raise SystemExit(main())
