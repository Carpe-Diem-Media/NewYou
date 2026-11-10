#!/usr/bin/env python3
"""Detect missing or damaged files in the dependency cache before use."""

import hashlib
import json
import os
import sys
from collections import Counter
from pathlib import Path

MANIFEST = Path("_build/ci-dependency-cache.json")
ROOTS = (Path("deps"), Path("_build/test/lib"))


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
            kind = "mode_changed" if old_digest == new_digest and old_mode != new_mode else "content_changed"
        counts[kind] += 1
        if len(examples) < 10:
            root = "deps" if path.startswith("deps/") else "build" if path.startswith("_build/test/lib/") else "other"
            fingerprint = hashlib.sha256(path.encode("utf-8")).hexdigest()
            examples.append(f"{kind} root={root} path_sha256={fingerprint}")
    summary = " ".join(f"{kind}={counts[kind]}" for kind in sorted(counts))
    print(f"Cache mismatch counts: {summary}", file=sys.stderr)
    for example in examples:
        print(f"Cache mismatch: {example}", file=sys.stderr)


def snapshot():
    entries = {}
    for root in ROOTS:
        if not root.is_dir():
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
