"""Bounded WELL-147 pilot candidate. No operational clearance is implied.

Dry run is the default. Execute requires externally approved references and a
private receipt bound to trusted CLI expectations. No reconciliation is performed.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import time
import copy
import re
import stat
import threading
import tempfile
import sys

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools import well147_pilot_identity as observer_module
from tools import well147_pilot_runtime as runtime

MANIFEST = '3fb71d0ed24dfc4ab8ef75226916da624f5ca4a18343695a154733eb2a93e556'
CHECKSUM = '2ed9f8bba9abd3775b578bf159bb1c01787dac33cbbc668d71849752171916b7'
WORKTREES = tuple('/home/jcschoeman96/.t3/worktrees/NewYou/' + p for p in (
    't3-856f7154-3e77f19f90c298dd', 'well-4225608f-f2321ab12394cc96'))
QUARANTINES = (
    (1, '8cc90b5589204c89a5928c7b41bc446a', '81b50e14dc024b308b420ef58e2ac679', '6a0907f0922642099553c69613967507', 5012651, 5012650),
    (2, '7b031a3f06e546578436ad5f01a67df7', '3d5284ee0b1945f6b36d6b166f7c41f6', 'a0b836f0a37246b292b436bf1f8535c6', 5013573, 5013572),
)
ARGV = ('mise', 'exec', '--', 'tools/newyou-local', 'test', '--heavy', '--',
        'mix', 'do', 'ecto.migrate,', 'run', 'test/proof/managed_slot_probe.exs')
ROOT = str(Path(__file__).resolve().parents[1])
KEYS = ('lease', 'generation', 'job', 'worktree', 'database', 'role')


class Refused(RuntimeError):
    """Fixed non-secret diagnosis; never include captured process output."""


def require(condition, diagnosis):
    if not condition:
        raise Refused(diagnosis)


def quarantine_check(rows):
    for slot, lease, generation, job, database_oid, role_oid in QUARANTINES:
        matches = [r for r in rows if r.get('slot') == slot]
        require(len(matches) == 1, 'quarantine missing or duplicated')
        row = matches[0]
        require(row.get('state') == 'quarantined' and row.get('lease_id') == lease
                and row.get('generation') == generation and set(row.get('jobs', {})) == {job}
                and row.get('catalog', {}).get('database_oid') == database_oid
                and row.get('catalog', {}).get('role_oid') == role_oid
                and row.get('manifest') == MANIFEST, 'quarantine drift')


def preflight(read, tool, worktrees=WORKTREES, *, expected_source=None, owned_jobs=None, pending_jobs=None, listener_check=None):
    """Read adapter returns bounded stdout for explicit argv/cwd. No launch calls."""
    require(isinstance(expected_source, str) and len(expected_source) == 40
            and all(c in '0123456789abcdef' for c in expected_source), 'explicit expected source required')
    require(tuple(worktrees) == WORKTREES, 'exact pair required')
    require(hashlib.sha256(Path(tool).read_bytes()).hexdigest() == CHECKSUM, 'tool drift')
    require(read([str(tool), '--version'], WORKTREES[0]).strip() == 'devcore-project 1.2.1', 'version drift')
    for worktree in worktrees:
        require(str(Path(worktree).resolve()) == worktree, 'worktree alias')
        require(read(['git', 'rev-parse', '--show-toplevel'], worktree).strip() == worktree, 'worktree mismatch')
        require(read(['git', 'rev-parse', 'HEAD'], worktree).strip() == expected_source, 'source drift')
        require(not read(['git', 'status', '--porcelain'], worktree).strip(), 'dirty source')
    manifest = json.loads(read([str(tool), 'slots', 'manifest'], WORKTREES[0]))
    digest = hashlib.sha256(json.dumps(manifest['manifest'], sort_keys=True).encode()).hexdigest()
    require(manifest.get('sha256') == MANIFEST and digest == MANIFEST, 'manifest drift')
    require(manifest.get('heavy_limit') == 2 and isinstance(manifest.get('port_conflicts'), list), 'capacity contract drift')
    rows = json.loads(read([str(tool), 'slots', 'status'], WORKTREES[0]))
    quarantine_check(rows)
    for row in rows:
        if row.get('worktree') in worktrees:
            expected = (owned_jobs or {}).get(row['worktree'])
            pending = (pending_jobs or {}).get(row['worktree'])
            if row.get('state') == 'free' and expected is None and pending is None:
                require(row.get('jobs') == {} and row.get('diagnosis') ==
                        'exact registered generation removed', 'unsettled pair history')
                continue
            if pending is not None and not row.get('jobs') and row.get('state') in ('preparing', 'ready'):
                require(row.get('lease_id') == pending['lease']
                        and row.get('generation') == pending['generation']
                        and row.get('preparer') == pending['preparer'], 'pending pair allocation drift')
            else:
                require(expected is not None and row.get('lease_id') == expected['lease']
                        and row.get('generation') == expected['generation']
                        and set(row.get('jobs', {})) == {expected['job']}, 'prior pair allocation')
    for port in manifest['port_conflicts']:
        require(type(port) is int and 4221 <= port <= 4240, 'invalid conflict port')
        matches = [row for row in rows if row.get('port') == port and row.get('worktree') in worktrees]
        require(len(matches) == 1 and listener_check is not None, 'foreign port conflict')
        row = matches[0]
        expected = (owned_jobs or {}).get(row['worktree'])
        pending = (pending_jobs or {}).get(row['worktree'])
        if expected is not None:
            process = row['jobs'][expected['job']]['supervisor']
        else:
            require(pending is not None and row.get('state') == 'ready', 'unproven port owner')
            process = pending['preparer']
        require(listener_check(process, port) is True, 'foreign port conflict')
    return {'mode': 'dryrun', 'source': expected_source, 'manifest': MANIFEST,
            'worktrees': list(worktrees), 'argv': list(ARGV), 'max_jobs': 2,
            'execution_clearance': False}


def load_coordinator():
    path = Path(__file__).resolve().parents[1] / 'test/proof/managed_slot_coordinator.py'
    spec = importlib.util.spec_from_file_location('well147_pair', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check_record(record, identity, phase):
    require({k: record.get(k) for k in KEYS} == identity, 'independent identity mismatch')
    require(type(record.get('own_count')) is int and type(record.get('peer_count')) is int
            and record['own_count'] == 1 and record['peer_count'] == 0, 'fixture counts')
    if phase == 'done':
        require(record.get('cross_slot_denied') is True and record.get('legacy_denied') is True, 'denial proof missing')


def orchestrate(adapter, directories, coordinator=None, timeout=280):
    """Synthetic/embedding seam. Adapter must independently verify identities.

    Adapter launch owns the process and must bound/redact output; identity must
    verify live supervisor, in_use job/test profile and catalog binding independently
    of control files. finish must prove deliberate failure and retained diagnosis.
    The composed adapter binds these checks to owned process metadata. On failure, only owned stdin is cancelled;
    surviving processes and all evidence remain the caller's responsibility.
    """
    require(len(directories) == 2 and len(set(directories)) == 2, 'exact control pair required')
    require(0 < timeout <= 280, 'bounded deadline required')
    c = coordinator or load_coordinator()
    for directory in directories:
        fd = c.private_directory(directory)
        os.close(fd)
        require(not list(Path(directory).iterdir()), 'fresh controls required')
    deadline = adapter.now() + timeout
    processes, identities = [], []

    def remaining():
        value = deadline - adapter.now()
        require(value > 0, 'pilot deadline')
        return value

    def wait_phase(index, phase):
        while True:
            remaining()
            require(processes[index].poll() is None, 'early child exit')
            identity = adapter.identity(WORKTREES[index], processes[index])
            if identity is not None:
                require(identity.get('worktree') == WORKTREES[index] and set(identity) == set(KEYS), 'independent worktree mismatch')
                record = c.read_record(directories[index], phase, identity)
                if record:
                    check_record(record, identity, phase)
                    return identity
            adapter.revalidate()
            adapter.pause(.2)

    try:
        for index in range(2):
            remaining()
            adapter.revalidate()  # Sources, manifest, quarantines and window.
            process = adapter.launch(ARGV, WORKTREES[index], index)
            processes.append(process)
            own, peer = ('a', 'b') if index == 0 else ('b', 'a')
            c.send(process.stdin, dict(mode='seed', own_email='slot-proof-147' + '0'*28 + own + '@example.test',
                   peer_email='slot-proof-147' + '0'*28 + peer + '@example.test', browser=True,
                   fail_after_commit=index == 1, control_directory=str(directories[index])), time.monotonic() + remaining())
            identities.append(wait_phase(index, 'ready'))
        require(identities[0]['database'] != identities[1]['database'], 'same database')

        def cancelled():
            remaining()
            adapter.revalidate()
            for index, process in enumerate(processes):
                require(process.poll() is None, 'early child exit')
                require(adapter.identity(WORKTREES[index], process) == identities[index], 'identity changed')
                for phase in ('ready', 'done'):
                    record = c.read_record(directories[index], phase, identities[index])
                    if record:
                        check_record(record, identities[index], phase)
            return False

        c.coordinate(directories, identities, [p.stdin for p in processes], timeout=remaining(), cancelled=cancelled)
        if hasattr(adapter, 'completed'):
            adapter.completed(identities)
        exits = [p.wait(timeout=remaining()) for p in processes]
        require(exits == [0, 1], 'unexpected process exits')
        require(adapter.finish(identities, exits) is True, 'deliberate failure or retained diagnosis unproved')
        return {'pair_protocol': 'verified', 'exits': exits, 'live_acceptance': False}
    except BaseException:
        for process in processes:
            try:
                c.send(process.stdin, {'cancel': True}, time.monotonic() + .05)
            except (OSError, ValueError, TimeoutError):
                pass
        for process in processes:
            try:
                process.wait(timeout=.1)
            except subprocess.TimeoutExpired:
                pass
        raise


def process_metadata():
    """Read kernel identities only, without command lines or environments."""
    boot = Path('/proc/sys/kernel/random/boot_id').read_text().strip()
    result = {}
    for path in Path('/proc').iterdir():
        if not path.name.isdigit():
            continue
        try:
            fields = (path / 'stat').read_text().rsplit(')', 1)[1].split()
            pid = int(path.name)
            result[pid] = dict(pid=pid, start=fields[19], boot=boot, ppid=int(fields[1]))
        except (FileNotFoundError, ProcessLookupError):
            continue
    return result


def owned_listener(identity, port):
    """Bind the TEST reservation to the exact captured supervisor and loopback."""
    try:
        pid = identity['pid']
        def current():
            fields = Path('/proc', str(pid), 'stat').read_text().rsplit(')', 1)[1].split()
            return dict(pid=pid, start=fields[19], boot=Path('/proc/sys/kernel/random/boot_id').read_text().strip())
        require(current() == identity, 'listener process drift')
        inodes = set()
        for table in ('tcp', 'tcp6'):
            for line in Path('/proc/net', table).read_text().splitlines()[1:]:
                fields = line.split()
                address, number = fields[1].split(':')
                if int(number, 16) == port and fields[3] == '0A':
                    require(table == 'tcp' and address == '0100007F', 'nonloopback listener')
                    inodes.add(fields[9])
        require(bool(inodes), 'listener missing')
        owned = set()
        for path in Path('/proc', str(pid), 'fd').iterdir():
            try:
                target = os.readlink(path)
                match = re.fullmatch(r'socket:\[(\d+)\]', target)
                if match:
                    owned.add(match[1])
            except FileNotFoundError:
                continue
        require(inodes <= owned and current() == identity, 'foreign listener')
        return True
    except Exception:
        raise Refused('listener ownership unavailable') from None


class PilotReads:
    """Finite read admission. SQL is accepted only during an observer call.

    The observer is the sole SQL producer. Exact generated bytes are registered
    for one synchronous call, never accepted as operator input.
    """
    def __init__(self, tool, runner, registry, processes=process_metadata):
        self.tool, self.runner = str(tool), runner
        self.registry = Path(registry)
        self.processes = processes
        self.observer = None
        self.sql_admission = None
        self.cache = {}
        self.calls = 0

    def invalidate(self):
        self.cache.clear()

    def command(self, argv, cwd, stdin=None, limit=65536):
        require(cwd in (*WORKTREES, ROOT) and 0 < limit <= runtime.LIMIT, 'read scope refused')
        argv = tuple(argv)
        if argv[0] == 'devcore-project':
            argv = (self.tool, *argv[1:])
        fixed = {(self.tool, '--version'), (self.tool, 'slots', 'manifest'),
                 (self.tool, 'slots', 'status')}
        fixed.update(('git', *tail) for tail in (
            ('rev-parse', '--show-toplevel'), ('rev-parse', 'HEAD'), ('status', '--porcelain')))
        container = observer_module.CONTAINER
        fixed.update({('docker', 'inspect', '-f', '{{.Id}}', container),
                      ('docker', 'inspect', '-f', '{{.State.Running}}', container),
                      ('docker', 'port', container, '5432/tcp')})
        is_sql = self.sql_admission == (argv, stdin) and stdin is not None
        require((cwd in WORKTREES or argv[0] == 'git') and (is_sql or argv in fixed and stdin is None), 'read command refused')
        key = (argv, cwd, stdin)
        cached = self.cache.get(key)
        if cached and time.monotonic() - cached[0] < 5:
            return cached[1]
        # 280 seconds / 5-second refresh, at most 18 fixed/catalog reads per
        # interval for two jobs, plus phase transitions. Exhaustion refuses.
        require(self.calls < 1024, 'read lifetime budget exhausted')
        self.calls += 1
        value = self.runner(argv, cwd, input=stdin.encode() if stdin else None)
        require(isinstance(value, str) and len(value.encode()) <= limit, 'read capture exceeded')
        self.cache[key] = (time.monotonic(), value)
        return value

    def file(self, path, *, limit):
        path = Path(path)
        jobs = {record[0]['job'] for record in self.observer.observed.values()}
        require(path.parent.parent == self.registry / 'runs' and path.parent.name in jobs
                and path.name in ('result.json', 'output.log'), 'result path refused')
        parent = os.open(self.registry, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            for part in ('runs', path.parent.name):
                child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
                os.close(parent)
                parent = child
            fd = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
            with os.fdopen(fd, 'rb') as stream:
                info = os.fstat(stream.fileno())
                require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
                        and stat.S_IMODE(info.st_mode) == 0o600 and info.st_nlink == 1, 'unsafe result file')
                offset = 0
                if path.name == 'output.log':
                    # Cold migrations exceed the record limit. Keep the full
                    # private log and inspect only its bounded final lines.
                    require(info.st_size <= runtime.LIMIT, 'result too large')
                    offset = max(0, info.st_size - limit)
                    stream.seek(offset)
                value = stream.read(limit + 1)
                if offset:
                    value = value.partition(b'\n')[2]
            require(len(value) <= limit, 'result too large')
            return value.decode()
        finally:
            os.close(parent)


class ComposedObserver(observer_module.IdentityObserver):
    def _sql(self, sql, database='postgres'):
        if database != 'postgres':
            require(any(database == record[0]['database'] for record in self.observed.values()), 'unobserved database')
            require(re.fullmatch(r'dc_new_you_s(?:0[3-9]|1[0-9]|20)_g[0-9a-f]{32}', database), 'invalid generation')
        argv = ('docker', 'exec', '-i', observer_module.CONTAINER, 'psql', '-X', '-qAt',
                '-v', 'ON_ERROR_STOP=1', '-U', 'devcore_admin', '-d', database)
        self._endpoint()
        reads = self.read._pilot_reads
        reads.sql_admission = (argv, 'BEGIN READ ONLY;\n' + sql + '\nROLLBACK;\n')
        try:
            return self._command(list(argv), reads.sql_admission[1])
        finally:
            reads.sql_admission = None


class ComposedAdapter:
    """Bind launch ownership, kernel identity, window and observer completion."""
    now = staticmethod(time.monotonic)
    pause = staticmethod(time.sleep)

    def __init__(self, owner, reads, window, source):
        self.owner, self.reads, self.window, self.source = owner, reads, window, source
        self.captured = {}
        self.barrier = None
        self.last_check = float('-inf')
        self.failure = threading.Event()
        adapters = observer_module.ReadAdapters(reads.command, reads.processes, reads.file, WORKTREES[0])
        adapters._pilot_reads = reads
        self.foreign = None
        self.observer = ComposedObserver(adapters, WORKTREES, reads.registry,
                                        done_barrier=lambda identities: self.barrier == identities)
        reads.observer = self.observer

    def revalidate(self, force=False):
        require(not self.failure.is_set(), 'owned output failed')
        if force or self.now() - self.last_check >= 5:
            self.reads.invalidate()
            verify_driver_source(self.reads.command, self.source)
            require(hashlib.sha256(Path(self.reads.tool).read_bytes()).hexdigest() == CHECKSUM, 'tool drift')
            for record in self.owner.records:
                process = record.get('_process')
                if record['kind'] == 'job' and process and process.poll() is None:
                    self.identity(WORKTREES[record['index']], process)
            owned = {root: record[0] for root, record in self.observer.observed.items()}
            preflight(self.reads.command, self.reads.tool, expected_source=self.source,
                      owned_jobs=owned, pending_jobs=self.observer.pending, listener_check=owned_listener)
            rows = json.loads(self.reads.command(['devcore-project', 'slots', 'status'], WORKTREES[0]))
            foreign = [row for row in rows if row.get('worktree') not in WORKTREES]
            require(self.foreign is None or foreign == self.foreign, 'foreign allocation drift')
            self.foreign = copy.deepcopy(foreign)
            self.window.revalidate()
            self.last_check = self.now()

    def launch(self, argv, cwd, index):
        self.revalidate(force=True)
        process = self.owner.launch(argv, cwd, index)
        metadata = self.reads.processes().get(process.pid)
        require(metadata is not None, 'launched identity unavailable')
        self.captured[process.pid] = {k: metadata[k] for k in ('pid', 'start', 'boot')}
        self.owner.records[-1]['identity'] = self.captured[process.pid]
        self.reads.invalidate()
        return process

    def identity(self, worktree, process):
        captured = self.captured[process.pid]
        current = self.reads.processes().get(process.pid, {})
        require(all(current.get(k) == v for k, v in captured.items()), 'launched identity drift')
        return self.observer.identity(worktree, captured)

    def completed(self, identities):
        require(self.barrier is None, 'duplicate barrier')
        self.barrier = copy.deepcopy(identities)
        self.reads.invalidate()

    def finish(self, identities, exits):
        self.reads.invalidate()
        require(not self.failure.is_set(), 'owned output failed')
        for record in self.owner.records:
            record['_thread'].join(2)
            require(record['drained'] and not record['error'], 'owned drains incomplete')
        return self.observer.finish(identities, exits)


def verify_driver_source(read, source):
    require(read(['git', 'rev-parse', '--show-toplevel'], ROOT).strip() == ROOT,
            'driver root drift')
    require(read(['git', 'rev-parse', 'HEAD'], ROOT).strip() == source, 'driver source drift')
    require(not read(['git', 'status', '--porcelain'], ROOT).strip(), 'dirty driver source')


def bounded_read(argv, cwd, input=None, *, source=None, timeout=10):
    """Preserve bounded private evidence for prerequisite reads and survivors.

    These calls have passed PilotReads' finite read-only admission. The fallback
    zero source denotes an unbound standalone read, never candidate proof.
    """
    directory = Path(tempfile.mkdtemp(prefix='well147-prerequisite-')) / 'read'
    owner = runtime.OwnedProcesses(directory, argv=ARGV, worktrees=WORKTREES,
            cancel_callback=lambda diagnosis: None, read_specs=((argv, cwd),),
            sources=dict(source_sha=source or '0' * 40, manifest=MANIFEST,
                         tool_checksum=CHECKSUM))
    try:
        return owner.read_command(argv, cwd, input=input, timeout=timeout)
    finally:
        owner.finalize(timeout=.1)


def capacity_check(references, registry, owned=()):
    """Conservative pilot headroom only; external clearance covers unknown owners."""
    require(all(references.values()), 'clearance references missing')
    memory = dict(line.split(':', 1) for line in Path('/proc/meminfo').read_text().splitlines())
    require(int(memory['MemAvailable'].split()[0]) >= 12 * 1024 * 1024, 'insufficient current headroom')
    pressure = Path('/proc/pressure/memory').read_text().splitlines()
    require(len(pressure) == 2 and all(float(field.split('=')[1]) == 0
            for line in pressure for field in line.split()[1:4]), 'memory pressure')
    heavy = Path(registry) / 'heavy'
    # Unknown receipt ownership is never waived by a reference.
    require(not heavy.is_symlink(), 'unsafe heavy receipts')
    if heavy.exists():
        for path in heavy.iterdir():
            require(path.name in ('0', '1', '0.json', '1.json'), 'unknown heavy receipt')
            fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
            with os.fdopen(fd, 'rb') as stream:
                info = os.fstat(stream.fileno())
                require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
                        and stat.S_IMODE(info.st_mode) == 0o600, 'unsafe heavy receipt')
                raw = stream.read(4097)
            require(len(raw) <= 4096, 'heavy receipt oversized')
            if path.suffix != '.json':
                require(not raw, 'unexpected permit contents')
                continue
            receipt = json.loads(raw)
            require(receipt.get('state') == 'free' or any(
                receipt.get('state') == 'active' and receipt.get('lease_id') == row['lease']
                and receipt.get('generation') == row['generation']
                and receipt.get('supervisor') == row['supervisor'] for row in owned),
                'unreviewed heavy receipts')
    return True


def _main(arguments=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--expected-source')
    for name in runtime.WindowGuard.REFERENCES:
        parser.add_argument('--' + name.replace('_', '-'))
    parser.add_argument('--window-receipt')
    parser.add_argument('--evidence-root')
    args = parser.parse_args(arguments)
    owner = None
    try:
        tool = Path.home() / '.local/bin/devcore-project'
        registry = Path.home() / '.config/dev-core/slots/new_you'
        reads = PilotReads(tool, lambda argv, cwd, input=None: bounded_read(
            argv, cwd, input, source=args.expected_source), registry)
        if not args.execute:
            print(json.dumps(preflight(reads.command, tool, expected_source=args.expected_source)))
            return 0
        require(args.window_receipt and args.evidence_root and all(getattr(args, k)
                for k in runtime.WindowGuard.REFERENCES), 'execution references and private paths required')
        preflight(reads.command, tool, expected_source=args.expected_source)
        verify_driver_source(reads.command, args.expected_source)
        expected = dict(source_sha=args.expected_source, manifest=MANIFEST, worktrees=list(WORKTREES),
                        tool_checksum=CHECKSUM, coordinator_pid=os.getpid())
        expected.update({k: getattr(args, k) for k in runtime.WindowGuard.REFERENCES})
        adapter = None
        window = runtime.WindowGuard(args.window_receipt, expected=expected,
                identity_reader=lambda: dict(
                    source_sha=reads.command(['git', 'rev-parse', 'HEAD'], ROOT).strip(),
                    manifest=json.loads(reads.command(['devcore-project', 'slots', 'manifest'], WORKTREES[0]))['sha256'],
                    worktrees=[reads.command(['git', 'rev-parse', '--show-toplevel'], root).strip() for root in WORKTREES],
                    tool_checksum=hashlib.sha256(tool.read_bytes()).hexdigest(), coordinator_pid=os.getpid()),
                capacity_reader=lambda refs: capacity_check(refs, registry,
                    [dict(r[0], supervisor=r[1]['jobs'][r[0]['job']]['supervisor'])
                     for r in adapter.observer.observed.values()] if adapter else ()))
        window.revalidate()
        failure = threading.Event()
        require(Path(args.evidence_root).is_absolute() and str(Path(args.evidence_root).resolve()) == args.evidence_root, 'canonical evidence root required')
        owner = runtime.OwnedProcesses(args.evidence_root, argv=ARGV, worktrees=WORKTREES,
                cancel_callback=lambda diagnosis: failure.set(), sources=expected)
        adapter = ComposedAdapter(owner, reads, window, args.expected_source)
        adapter.failure = failure
        def owned_read(argv, cwd, input=None):
            owner.read_specs.add((tuple(argv), str(cwd)))
            return owner.read_command(argv, cwd, input=input)
        reads.runner = owned_read
        directories = [owner.root / name for name in ('a', 'b')]
        for directory in directories:
            directory.mkdir(mode=0o700)
        print(json.dumps(orchestrate(adapter, directories)))
        return 0
    except Exception:
        print('Pilot refused. Preserve resources and private evidence for independent review.')
        return 125
    finally:
        if owner is not None:
            # Only the main thread writes protocol cancellation, including a
            # launch whose immediate metadata capture failed before admission.
            for record in owner.records:
                process = record.get('_process')
                if record['kind'] == 'job' and process and process.poll() is None:
                    try:
                        load_coordinator().send(process.stdin, {'cancel': True}, time.monotonic() + .1)
                        process.wait(timeout=.2)
                    except (OSError, ValueError, TimeoutError, subprocess.TimeoutExpired):
                        pass
            try:
                owner.finalize(timeout=2)
            except Exception:
                print('Private receipt finalization failed. Preserve the evidence root and owned survivors.')
                raise Refused('private receipt finalization failed') from None


def main(arguments=None):
    try:
        return _main(arguments)
    except Refused:
        return 125


if __name__ == '__main__':
    raise SystemExit(main())
