#!/usr/bin/env python3
"""Detect missing or damaged files in the dependency cache before use."""

import hashlib
import json
import os
import re
import stat
import sys
from collections import Counter
from pathlib import Path

MANIFEST = Path("_build/ci-dependency-cache.json")
ROOTS = (Path("deps"), Path("_build/test/lib"))


def normalize_file_modes():
    """Make producer files stable under the hosted runner's 0022 extraction umask."""
    for root in ROOTS:
        if root.is_symlink() or not root.is_dir():
            raise ValueError(f"missing cache directory: {root}")
        for directory, _, files in os.walk(root, followlinks=False):
            for name in files:
                path = Path(directory) / name
                if not stat.S_ISREG(path.lstat().st_mode):
                    continue
                # The trusted writer must never chmod through a symlink.
                fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
                try:
                    current = os.fstat(fd).st_mode
                    if not stat.S_ISREG(current):
                        raise ValueError("cache entry changed during mode normalization")
                    mode = stat.S_IMODE(current)
                    normalized = mode & ~0o022
                    if mode != normalized:
                        os.fchmod(fd, normalized)
                finally:
                    os.close(fd)


def describe_mismatch(expected, actual):
    """Report bounded metadata without exposing cached paths or file contents."""
    if not isinstance(expected, dict) or not all(
        isinstance(key, str) and isinstance(value, str) for key, value in expected.items()
    ):
        raise ValueError("invalid cache manifest format")
    counts = Counter()
    examples = []
    for path in sorted(expected.keys() | actual.keys()):
        before, after = expected.get(path), actual.get(path)
        details = ""
        if before == after:
            continue
        if before is None:
            kind = "unexpected"
        elif after is None:
            kind = "missing"
        elif before.startswith("link:") or after.startswith("link:"):
            kind = "link_changed"
        else:
            old_mode, _, old_digest = before.partition(":")
            new_mode, _, new_digest = after.partition(":")
            mode_changed = old_digest == new_digest and old_mode != new_mode
            kind = "mode_changed" if mode_changed else "content_changed"
            if (mode_changed and re.fullmatch(r"[0-7]{1,4}", old_mode)
                    and re.fullmatch(r"[0-7]{1,4}", new_mode)):
                details = f" mode={old_mode}->{new_mode}"
        counts[kind] += 1
        if len(examples) < 10:
            if path.startswith("deps/"):
                root = "deps"
            elif path.startswith("_build/test/lib/"):
                root = "build"
            else:
                root = "other"
            fingerprint = hashlib.sha256(path.encode("utf-8")).hexdigest()
            examples.append(f"{kind} root={root} path_sha256={fingerprint}{details}")
    summary = " ".join(f"{kind}={counts[kind]}" for kind in sorted(counts))
    print(f"Cache mismatch counts: {summary}", file=sys.stderr)
    for example in examples:
        print(f"Cache mismatch: {example}", file=sys.stderr)


def snapshot():
    entries = {}
    for root in ROOTS:
        if root.is_symlink() or not root.is_dir():
            raise ValueError(f"missing cache directory: {root}")
        for directory, dirs, files in os.walk(root, followlinks=False):
            for name in sorted(dirs + files):
                path = Path(directory) / name
                if path.is_symlink():
                    entries[str(path)] = "link:" + os.readlink(path)
                elif path.is_file():
                    digest = hashlib.sha256()
                    with path.open("rb") as source:
                        for chunk in iter(lambda: source.read(1024 * 1024), b""):
                            digest.update(chunk)
                    entries[str(path)] = f"{path.stat().st_mode & 0o777:o}:{digest.hexdigest()}"
    return entries


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in {"write", "check"}:
        return 2
    try:
        if sys.argv[1] == "write":
            normalize_file_modes()
        actual = snapshot()
        if sys.argv[1] == "write":
            MANIFEST.write_text(json.dumps(actual, sort_keys=True), encoding="utf-8")
        else:
            expected = json.loads(MANIFEST.read_text(encoding="utf-8"))
            if actual != expected:
                describe_mismatch(expected, actual)
                raise ValueError("cache contents do not match manifest")
    except (OSError, ValueError) as error:
        print(f"Dependency cache validation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
