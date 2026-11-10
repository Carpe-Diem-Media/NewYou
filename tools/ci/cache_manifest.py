#!/usr/bin/env python3
"""Detect missing or damaged files in the dependency cache before use."""

import hashlib
import json
import os
import sys
from pathlib import Path

MANIFEST = Path("_build/ci-dependency-cache.json")
ROOTS = (Path("deps"), Path("_build/test/lib"))


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
        elif actual != json.loads(MANIFEST.read_text(encoding="utf-8")):
            raise ValueError("cache contents do not match manifest")
    except (OSError, ValueError) as error:
        print(f"Dependency cache validation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
