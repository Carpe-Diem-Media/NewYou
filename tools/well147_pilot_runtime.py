"""Source-only process and window adapters for the partial WELL-147 driver.

References are externally approved evidence, not authorization established here.
Root must supply identity/capacity readers, exact read commands and cancellation.
No integration, environment construction, resource operations or termination occurs.
"""
import copy
import json
import os
from pathlib import Path
import stat
import subprocess
import threading
import time
from datetime import datetime, timezone

LIMIT = 1024 * 1024


class Refused(RuntimeError):
    """Fixed diagnosis only. Owned process details remain in the receipt."""


def require(ok, message):
    if not ok:
        raise Refused(message)


def _pairs(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'duplicate receipt key')
        result[key] = value
    return result


def legacy_lock_present(path='/tmp/newyou-shared-test-plt.lock', *,
                        stat_reader=os.lstat, locks_reader=None):
    """Inspect known inode locks only. Absence cannot prove workstation clearance."""
    try:
        info = stat_reader(path)
    except FileNotFoundError:
        return False
    except OSError:
        raise Refused('legacy lock metadata unavailable') from None
    require(stat.S_ISREG(info.st_mode), 'unsafe legacy lock metadata')
    try:
        if locks_reader is None:
            with open('/proc/locks', 'r', encoding='ascii') as stream:
                data = stream.read(LIMIT + 1)
        else:
            data = locks_reader()
        require(isinstance(data, str) and len(data) <= LIMIT, 'lock table unavailable')
        for line in data.splitlines():
            fields = line.split()
            offset = 1 if len(fields) > 1 and fields[1] == '->' else 0
            require(len(fields) >= 8 + offset, 'lock table malformed')
            major, minor, inode = fields[5 + offset].split(':')
            if (int(major, 16), int(minor, 16), int(inode)) == (
                    os.major(info.st_dev), os.minor(info.st_dev), info.st_ino):
                return True
        return False
    except (OSError, ValueError, TypeError):
        raise Refused('lock table unavailable') from None


class WindowGuard:
    """Validate structure/freshness, then recheck externally supplied observations.

    identity_reader returns exactly the expected identity mapping. capacity_reader
    returns True only after root's current capacity checks. Neither callback may
    perform actions. Receipt references must already have external approval.
    """
    REFERENCES = ('owner_authorization_reference', 'exclusive_window_reference',
                  'legacy_owner_clearance_reference', 'capacity_reference')
    IDENTITY = ('source_sha', 'manifest', 'worktrees', 'tool_checksum', 'coordinator_pid')

    def __init__(self, receipt, *, expected, identity_reader, capacity_reader,
                 lock_reader=legacy_lock_present, now=None):
        self.path = Path(receipt)
        self.expected = copy.deepcopy(expected)
        self.identity_reader = identity_reader
        self.capacity_reader = capacity_reader
        self.lock_reader = lock_reader
        self.now = now or (lambda: datetime.now(timezone.utc))
        self.original = None

    def revalidate(self):
        try:
            fd = os.open(self.path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
            with os.fdopen(fd, 'rb') as stream:
                info = os.fstat(stream.fileno())
                require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
                        and stat.S_IMODE(info.st_mode) == 0o600, 'unsafe window receipt')
                raw = stream.read(16385)
            require(len(raw) <= 16384, 'window receipt too large')
            receipt = json.loads(raw, object_pairs_hook=_pairs)
            keys = set(self.IDENTITY + self.REFERENCES + ('expires_utc', 'max_jobs'))
            require(isinstance(receipt, dict) and set(receipt) == keys, 'window schema mismatch')
            require(set(self.expected) == set(self.IDENTITY + self.REFERENCES), 'window expectations missing')
            require(all(receipt[k] == self.expected[k] for k in self.expected), 'window identity drift')
            require(all(isinstance(receipt[k], str) and 0 < len(receipt[k]) <= 1024
                        and receipt[k].strip() == receipt[k] for k in self.REFERENCES), 'window references missing')
            require(type(receipt['max_jobs']) is int and receipt['max_jobs'] == 2, 'unsafe capacity')
            require(type(receipt['coordinator_pid']) is int and receipt['coordinator_pid'] == os.getpid(), 'coordinator mismatch')
            require(isinstance(receipt['worktrees'], list) and len(receipt['worktrees']) == 2
                    and len(set(receipt['worktrees'])) == 2
                    and all(isinstance(p, str) and Path(p).is_absolute() for p in receipt['worktrees']), 'exact worktrees required')
            require(all(isinstance(receipt[k], str) and len(receipt[k]) == n
                        and all(c in '0123456789abcdef' for c in receipt[k])
                        for k, n in (('source_sha', 40), ('manifest', 64), ('tool_checksum', 64))), 'invalid source identity')
            expiry = datetime.fromisoformat(receipt['expires_utc'].replace('Z', '+00:00'))
            require(expiry.utcoffset() is not None and expiry.utcoffset().total_seconds() == 0,
                    'UTC expiry required')
            require(0 < (expiry - self.now()).total_seconds() <= 1800, 'stale or excessive window')
            require(self.original is None or receipt == self.original, 'window receipt drift')
            require(self.identity_reader() == {k: self.expected[k] for k in self.IDENTITY}, 'current identity drift')
            require(self.lock_reader() is False, 'legacy TEST lock conflict or unknown')
            require(self.capacity_reader({k: receipt[k] for k in self.REFERENCES}) is True,
                    'current capacity unsafe or unknown')
            self.original = receipt
            return copy.deepcopy(receipt)
        except Refused:
            raise
        except Exception:
            raise Refused('window validation unavailable') from None


class OwnedProcesses:
    """Own up to two exact launches and bounded redactor-output drainers.

    cancel_callback receives a fixed diagnosis and must only request protocol
    cancellation. Root owns bounded process waits. This class never terminates.
    Evidence must already be redacted by DevCore; no secret values are loaded.
    read_specs is an explicit allowlist of (argv, cwd) read-only commands supplied
    by root. This class cannot establish that supplied commands are read-only.
    """
    def __init__(self, evidence_root, *, argv, worktrees, cancel_callback,
                 read_specs=(), sources):
        require(isinstance(argv, (tuple, list)) and argv and all(isinstance(a, str) for a in argv), 'exact argv required')
        require(len(worktrees) == 2 and len(set(worktrees)) == 2, 'exact worktrees required')
        self.argv, self.worktrees = tuple(argv), tuple(map(str, worktrees))
        self.read_specs = {(tuple(a), str(c)) for a, c in read_specs}
        self.cancel_callback = cancel_callback
        self.sources = {k: sources[k] for k in ('source_sha', 'manifest', 'tool_checksum')}
        require(all(isinstance(v, str) and len(v) in (40, 64) and all(c in '0123456789abcdef' for c in v)
                    for v in self.sources.values()), 'invalid source receipt')
        self.root = Path(evidence_root)
        self.root.mkdir(mode=0o700)  # Exist, aliases and reused roots fail closed.
        require(stat.S_IMODE(self.root.stat().st_mode) == 0o700, 'unsafe evidence root')
        self.records = []
        self.closed = False
        self._mutex = threading.Lock()
        self._admission = threading.Lock()

    def _failure(self, record, diagnosis):
        with self._mutex:
            record['error'] = diagnosis
        try:
            self.cancel_callback(diagnosis)
        except Exception:
            with self._mutex:
                record['error'] = 'cancel callback failed'

    def _start(self, argv, cwd, kind, index):
        require(not self.closed, 'process owner closed')
        name = 'output-%d.log' % len(self.records)
        fd = os.open(self.root / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        record = dict(kind=kind, index=index, pid=None, returncode=None, log=name,
                      bytes_retained=0, truncated=False, error=None, drained=False)
        self.records.append(record)
        try:
            process = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.PIPE,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        except Exception:
            os.close(fd)
            self._failure(record, 'process launch failed')
            raise Refused('process launch failed') from None
        record['_process'] = process
        record['pid'] = process.pid

        def drain():
            failed = False
            try:
                with os.fdopen(fd, 'wb', buffering=0) as log:
                    while True:
                        chunk = process.stdout.read(65536)
                        if not chunk:
                            break
                        available = LIMIT - record['bytes_retained']
                        if available and not failed:
                            try:
                                retained = memoryview(chunk[:available])
                                while retained:
                                    written = log.write(retained)
                                    if not written:
                                        raise OSError('short output write')
                                    record['bytes_retained'] += written
                                    retained = retained[written:]
                            except OSError:
                                failed = True
                                self._failure(record, 'output write failed')
                        if len(chunk) > available and not record['truncated']:
                            record['truncated'] = True
                            self._failure(record, 'output limit exceeded')
                record['drained'] = True
            except Exception:
                self._failure(record, 'output drain failed')
            finally:
                process.stdout.close()
        thread = threading.Thread(target=drain, daemon=True)
        record['_thread'] = thread
        thread.start()
        return process, record

    def launch(self, argv, cwd, index):
        with self._admission:
            require(type(index) is int and index in (0, 1), 'invalid launch index')
            require(tuple(argv) == self.argv and str(cwd) == self.worktrees[index], 'launch command mismatch')
            require(not any(r['kind'] == 'job' and r['index'] == index for r in self.records), 'duplicate launch')
            return self._start(argv, cwd, 'job', index)[0]

    def read_command(self, argv, cwd, input=None, *, timeout=10):
        require((tuple(argv), str(cwd)) in self.read_specs, 'read command not allowed')
        require(type(timeout) in (int, float) and 0 < timeout <= 10, 'bounded read deadline required')
        require(input is None or isinstance(input, bytes) and len(input) <= 4096, 'bounded read input required')
        require(sum(r['kind'] == 'read' for r in self.records) < 64, 'read command bound exceeded')
        process, record = self._start(argv, cwd, 'read', None)
        deadline = time.monotonic() + timeout
        def feed():
            try:
                if input:
                    process.stdin.write(input)
                process.stdin.close()
            except (OSError, ValueError):
                self._failure(record, 'read input failed')
        writer = threading.Thread(target=feed, daemon=True)
        record['_writer'] = writer
        writer.start()
        try:
            process.wait(timeout=max(.001, deadline - time.monotonic()))
            record['_thread'].join(max(0, deadline - time.monotonic()))
            writer.join(max(0, deadline - time.monotonic()))
            require(record['drained'] and not writer.is_alive() and not record['error']
                    and process.returncode == 0, 'read command failed')
            return (self.root / record['log']).read_bytes().decode('utf-8', errors='strict')
        except Exception:
            self._failure(record, 'read command failed')
            raise Refused('read command failed') from None

    def close(self, *, timeout=1):
        """Join drainers within one total deadline; preserve live PIDs, never kill.

        Call after root has sent protocol cancellation and boundedly waited.
        A later close refreshes the receipt after surviving children exit.
        """
        require(type(timeout) in (int, float) and 0 <= timeout <= 10, 'bounded close deadline required')
        self.closed = True
        deadline = time.monotonic() + timeout
        rows = []
        for record in self.records:
            for key in ('_thread', '_writer'):
                if key in record:
                    record[key].join(max(0, deadline - time.monotonic()))
            process = record.get('_process')
            record['returncode'] = process.poll() if process else None
            if process and process.poll() is not None and not process.stdin.closed:
                process.stdin.close()
            rows.append({k: v for k, v in record.items() if not k.startswith('_')})
        receipt = dict(schema='well147-owned-processes/v1', sources=self.sources,
                       processes=rows, surviving_pids=[r['pid'] for r in rows
                       if r['pid'] is not None and r['returncode'] is None])
        # Separate private temporary inode; never follow an existing receipt link.
        fd = os.open(self.root / 'receipt.tmp', os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'w') as stream:
            json.dump(receipt, stream, sort_keys=True)
        os.replace(self.root / 'receipt.tmp', self.root / 'receipt.json')
        return receipt

    finalize = close


def read_command(argv, cwd, input=None, *, owner, timeout=10):
    """Root-bound callback. No default command admission or unowned subprocess."""
    return owner.read_command(argv, cwd, input, timeout=timeout)
