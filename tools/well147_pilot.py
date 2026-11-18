"""Bounded WELL-147 pilot candidate. No operational clearance is implied.

The CLI validates read-only prerequisites by default. Execution is deliberately
blocked until root integrates a reviewed independent live identity/catalog and
retained-failure verifier. `orchestrate` is testable with owned synthetic streams;
it is not a production admission API. No resource reconciliation is performed.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import time

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


def preflight(read, tool, worktrees=WORKTREES, *, expected_source=None):
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
    require(manifest.get('heavy_limit') == 2 and not manifest.get('port_conflicts'), 'capacity contract drift')
    rows = json.loads(read([str(tool), 'slots', 'status'], WORKTREES[0]))
    quarantine_check(rows)
    require(not any(r.get('worktree') in worktrees for r in rows), 'prior pair allocation')
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
    This module supplies no live adapter. On failure, only owned stdin is cancelled;
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
            adapter.pause(.01)

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


def read_command(argv, cwd):
    result = subprocess.run(argv, cwd=cwd, capture_output=True, timeout=10)
    require(result.returncode == 0 and len(result.stdout) <= 1024*1024, 'read-only prerequisite failed')
    return result.stdout.decode()


def main(arguments=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--expected-source', help='Exact independently reviewed candidate SHA; never inferred from a prior run')
    parser.add_argument('--owner-authorization-reference')
    parser.add_argument('--exclusive-window-reference')
    args = parser.parse_args(arguments)
    try:
        if args.execute:
            require(args.owner_authorization_reference and args.exclusive_window_reference, 'owner authorization and exclusive legacy-owner/capacity window references required')
            raise Refused('execution blocked: root must integrate reviewed independent live identity/catalog, bounded redacted output, window and retained-failure adapters; references do not grant authority')
        print(json.dumps(preflight(read_command, Path.home() / '.local/bin/devcore-project', expected_source=args.expected_source)))
        return 0
    except Refused as error:
        print(str(error))
        return 125
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        print('Pilot blocked. Preserve resources. Independent live adapters and current prerequisites require root review.')
        return 125


if __name__ == '__main__':
    raise SystemExit(main())
