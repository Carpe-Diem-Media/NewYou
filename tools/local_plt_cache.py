"""Integrity checked, worktree private Dialyxir core PLT preparation."""

import fcntl
import hashlib
import json
import os
import subprocess
import sys
import shutil
import tempfile
from pathlib import Path

FORMAT_REVISION = 1
OWNER_MARKER = ".newyou-local-plt-owner"


def cache_key(value):
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


class Cache:
    def __init__(self, cache_root, work_root, key, plt_names):
        self.cache_root = Path(cache_root)
        self.work_root = Path(work_root)
        self.key = key
        self.plt_names = tuple(plt_names)
        if len(self.plt_names) != 2 or any(Path(name).name != name for name in self.plt_names):
            raise ValueError("exactly two safe Dialyxir core PLT basenames are required")
        self.namespace = self.cache_root / cache_key(key)
        self.manifest = self.namespace / "complete.json"

    def validate_baseline(self):
        try:
            if self.manifest.is_symlink():
                raise ValueError("manifest cannot be a symlink")
            manifest = json.loads(self.manifest.read_text())
            if manifest["key"] != self.key or manifest["format"] != FORMAT_REVISION:
                raise ValueError("cache key or format mismatch")
            if set(manifest["files"]) != set(self.plt_names):
                raise ValueError("manifest PLT set mismatch")
            if {path.name for path in self.namespace.iterdir()} != set(self.plt_names) | {"complete.json"}:
                raise ValueError("baseline contains an unexpected file")
            for name in self.plt_names:
                path = self.namespace / name
                if path.is_symlink() or not path.is_file() or _digest(path) != manifest["files"][name]:
                    raise ValueError("missing or modified core PLT")
        except (OSError, KeyError, ValueError, TypeError, json.JSONDecodeError) as error:
            raise RuntimeError("local core PLT baseline is incomplete or invalid") from error

    def prepare(self, producer, destination):
        self.cache_root.mkdir(parents=True, exist_ok=True)
        if self.cache_root.is_symlink():
            raise RuntimeError("local PLT cache root cannot be a symlink")
        lock_path = self.cache_root / (self.namespace.name + ".lock")
        lock_fd = os.open(lock_path, os.O_CREAT | os.O_RDWR | getattr(os, "O_NOFOLLOW", 0), 0o600)
        with os.fdopen(lock_fd, "a+b") as lock_file:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
            if self.namespace.is_symlink():
                raise RuntimeError("local PLT cache namespace cannot be a symlink")
            if self.namespace.exists():
                self.validate_baseline()
            else:
                staging = Path(tempfile.mkdtemp(prefix=".plt-stage-", dir=self.cache_root))
                try:
                    producer(staging)
                    for name in self.plt_names:
                        if (staging / name).is_symlink() or not (staging / name).is_file():
                            raise RuntimeError("core PLT producer did not create both files")
                        _fsync_file(staging / name)
                    manifest = {
                        "format": FORMAT_REVISION,
                        "key": self.key,
                        "files": {name: _digest(staging / name) for name in self.plt_names},
                    }
                    _durable_write(staging / "complete.json", (json.dumps(manifest, sort_keys=True) + "\n").encode())
                    _fsync_directory(staging)
                    os.replace(staging, self.namespace)
                    _fsync_directory(self.cache_root)
                finally:
                    if staging.exists():
                        shutil.rmtree(staging)
                self.validate_baseline()
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)

        destination = Path(destination)
        if destination.is_symlink():
            raise RuntimeError("private core PLT destination cannot be a symlink")
        work_root = self.work_root.absolute()
        destination = destination.absolute()
        try:
            relative_destination = destination.relative_to(work_root)
        except ValueError as error:
            raise RuntimeError("private core PLT destination escaped its worktree root") from error
        work_root.mkdir(parents=True, exist_ok=True)
        if work_root.is_symlink():
            raise RuntimeError("private core PLT worktree root cannot be a symlink")
        cursor = work_root
        for component in relative_destination.parts[:-1]:
            cursor = cursor / component
            if cursor.is_symlink():
                raise RuntimeError("private core PLT destination path cannot contain symlinks")
        if not destination.parent.resolve().is_relative_to(work_root.resolve()):
            raise RuntimeError("private core PLT destination escaped its worktree root")
        destination.parent.mkdir(parents=True, exist_ok=True)
        key_id = cache_key(self.key)
        if destination.exists():
            if not _owned_private_directory(destination):
                raise RuntimeError("refusing to replace an unmanaged local core PLT directory")
            if _owned_private_directory(destination, self.plt_names, key_id):
                return destination

        staging_copy = Path(tempfile.mkdtemp(prefix=".core-copy-", dir=destination.parent))
        try:
            for name in self.plt_names:
                shutil.copyfile(self.namespace / name, staging_copy / name)
                _fsync_file(staging_copy / name)
            _durable_write(staging_copy / OWNER_MARKER, f"newyou-local-core-v1\n{key_id}\n".encode())
            _fsync_directory(staging_copy)
            if destination.exists():
                previous = destination.with_name(destination.name + ".previous")
                if previous.exists():
                    if not _owned_private_directory(previous):
                        raise RuntimeError("refusing to replace an unmanaged backup directory")
                    shutil.rmtree(previous)
                os.replace(destination, previous)
                try:
                    os.replace(staging_copy, destination)
                    _fsync_directory(destination.parent)
                except BaseException:
                    os.replace(previous, destination)
                    raise
                shutil.rmtree(previous)
                _fsync_directory(destination.parent)
            else:
                os.replace(staging_copy, destination)
                _fsync_directory(destination.parent)
        finally:
            if staging_copy.exists():
                shutil.rmtree(staging_copy)
        return destination


def _digest(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _fsync_file(path):
    with Path(path).open("rb") as file_handle:
        os.fsync(file_handle.fileno())


def _durable_write(path, content):
    with Path(path).open("wb") as file_handle:
        file_handle.write(content)
        file_handle.flush()
        os.fsync(file_handle.fileno())


def _fsync_directory(path):
    descriptor = os.open(path, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def _owned_private_directory(path, plt_names=None, expected_key=None):
    path = Path(path)
    if path.is_symlink() or not path.is_dir():
        return False
    try:
        entries = {entry.name for entry in path.iterdir()}
        core_files = entries - {OWNER_MARKER}
        if not core_files or any(not name.startswith("dialyxir_") or not name.endswith(".plt") for name in core_files):
            return False
        if plt_names is not None and core_files != set(plt_names):
            return False
        if any((path / name).is_symlink() or not (path / name).is_file() for name in entries):
            return False
        marker = (path / OWNER_MARKER).read_text().splitlines()
        if len(marker) != 2 or marker[0] != "newyou-local-core-v1":
            return False
        return marker[1] == expected_key if expected_key else True
    except OSError:
        return False


def write_request(path, contents):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "wb", closefd=False) as request_file:
            request_file.write(contents)
            request_file.flush()
            os.fsync(request_file.fileno())
    finally:
        os.close(descriptor)


def main(request_path):
    request = json.loads(Path(request_path).read_text())
    cache = Cache(request["cache_root"], request["work_root"], request["key"], request["plt_names"])

    def produce(staging):
        env = {
            name: os.environ[name]
            for name in (
                "HOME",
                "PATH",
                "MISE_CACHE_DIR",
                "MISE_CONFIG_DIR",
                "MISE_DATA_DIR",
                "MISE_STATE_DIR",
                "MISE_TRUSTED_CONFIG_PATHS",
                "XDG_CACHE_HOME",
                "XDG_CONFIG_HOME",
                "XDG_DATA_HOME",
                "LANG",
                "LC_ALL",
                "TERM",
            )
            if name in os.environ
        }
        env["NEWYOU_PLT_STAGING"] = str(staging.resolve())
        env["NEWYOU_PLT_PLAN"] = request["producer_plan"]
        subprocess.run(request["producer"], check=True, env=env)

    cache.prepare(produce, request["destination"])


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--request-json":
        request_path = sys.argv[2]
        write_request(request_path, os.environ.pop("NEWYOU_PLT_REQUEST").encode())
        main(request_path)
    elif len(sys.argv) == 2:
        main(sys.argv[1])
    else:
        raise SystemExit("usage: local_plt_cache.py REQUEST.json | --request-json REQUEST.json")
