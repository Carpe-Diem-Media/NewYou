"""Synthetic CLI composition proof. No external command may execute."""
import contextlib
import copy
from datetime import datetime, timedelta, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools import well147_pilot as p
from tools import well147_pilot_identity as identity
from tools import well147_pilot_runtime as runtime

SOURCE = 'a' * 40
FAILURE_LOG = ('reports the seeded fixture failure for managed lease retention\n'
               'assert 1 == 0\nResult: 0/1 passed\nFailed: 1 test\n')


def private_json(path, value):
    path.write_text(json.dumps(value))
    path.chmod(0o600)


class Input(io.BytesIO):
    def __init__(self, process):
        super().__init__()
        self.process = process

    def write(self, data):
        self.process.receive(json.loads(data))
        return super().write(data)


class Child:
    def __init__(self, fixture, index):
        self.fixture, self.index = fixture, index
        self.pid = 9000 + index * 10
        self.returncode = None
        self.stdin = Input(self)
        self.stdout = io.BytesIO(b'synthetic redacted output\n')
        self.messages = []
        self.directory = None
        for offset in (0, 1, 2):
            pid = self.pid + offset
            fixture.procs[pid] = dict(pid=pid, start=str(pid), boot='synthetic-boot',
                                      ppid=self.pid + offset - 1)
        row = fixture.rows[index]
        row.update(state='in_use', jobs={fixture.ids[index]['job']: dict(
            profile='test', supervisor=self.metadata(1), session=self.metadata(2))})
        fixture.active.append(row)

    def metadata(self, offset):
        return {k: self.fixture.procs[self.pid + offset][k] for k in ('pid', 'start', 'boot')}

    def receive(self, message):
        self.messages.append(message)
        f, i = self.fixture, self.index
        if message.get('mode') == 'seed':
            assert message['fail_after_commit'] is (i == 1)
            assert message['browser'] is True
            assert message['own_email'] == 'slot-proof-147' + '0' * 28 + 'ab'[i] + '@example.test'
            assert message['peer_email'] == 'slot-proof-147' + '0' * 28 + 'ba'[i] + '@example.test'
            self.directory = Path(message['control_directory'])
            assert self.directory == f.evidence / 'ab'[i]
            f.c.publish(self.directory, 'ready', json.dumps(dict(f.ids[i], own_count=1, peer_count=0)))
        elif message.get('ack') == 'ready':
            assert message['identity'] == f.ids[i]
            assert message['peer_database'] == f.ids[1-i]['database']
            f.c.publish(self.directory, 'done', json.dumps(dict(f.ids[i], own_count=1,
                        peer_count=0, cross_slot_denied=True, legacy_denied=True)))
        elif message.get('ack') == 'done':
            assert message['identity'] == f.ids[i]
            row = f.rows[i]
            row.update(state='free' if i == 0 else 'retained', jobs={}, last_exit=i)
            if i == 0:
                row['diagnosis'] = 'exact registered generation removed'
            if f.fault == 'retention' and i == 1:
                row['state'] = 'free'
            directory = f.registry / 'runs' / f.ids[i]['job']
            directory.mkdir(parents=True, mode=0o700)
            private_json(directory / 'result.json', dict(lease_id=f.ids[i]['lease'],
                generation=f.ids[i]['generation'], job=f.ids[i]['job'], exit=i, children_reaped=True))
            (directory / 'output.log').write_text(FAILURE_LOG)
            (directory / 'output.log').chmod(0o600)
            for offset in (0, 1, 2):
                del f.procs[self.pid + offset]
            self.returncode = i
        elif message.get('cancel') is True:
            if self.returncode is None:
                self.returncode = 125
        else:
            raise AssertionError(message)

    def poll(self):
        return self.returncode

    def wait(self, timeout):
        assert 0 < timeout <= 280
        if self.returncode is None:
            raise subprocess.TimeoutExpired('synthetic', timeout)
        return self.returncode


class Fixture:
    def __init__(self, root, fault=None):
        self.root, self.fault = root, fault
        self.home = root / 'home'
        self.tool = self.home / '.local/bin/devcore-project'
        self.tool.parent.mkdir(parents=True)
        self.tool.write_bytes(b'synthetic tool checksum preimage')
        self.checksum = hashlib.sha256(self.tool.read_bytes()).hexdigest()
        self.manifest = hashlib.sha256(b'{}').hexdigest()
        self.registry = self.home / '.config/dev-core/slots/new_you'
        self.evidence = root / 'evidence'
        self.worktrees = tuple(str(root / name) for name in ('wt-a', 'wt-b'))
        for directory in self.worktrees:
            Path(directory).mkdir()
        self.active, self.rows, self.ids, self.procs = [], [], [], {}
        self.children, self.calls, self.sql = [], [], []
        self.c = p.load_coordinator()
        for i in range(2):
            generation = str(i + 3) * 32
            database = f'dc_new_you_s0{i+3}_g{generation}'
            ident = dict(lease=str(i+5)*32, generation=generation, job=str(i+7)*32,
                         database=database, role=database+'_r', worktree=self.worktrees[i])
            self.ids.append(ident)
            self.rows.append(dict(project='new_you', slot=i+3, lease_id=ident['lease'],
                generation=generation, worktree=self.worktrees[i], database=database,
                role=ident['role'], manifest=self.manifest, test_host='127.0.0.1',
                test_port=55433, catalog=dict(container_id=identity.CONTAINER,
                database_oid=100+i*2, role_oid=101+i*2, owner_oid=10)))
        self.quarantines = [dict(slot=s, state='quarantined', lease_id=l, generation=g,
            jobs={j: {}}, catalog=dict(database_oid=d, role_oid=r), manifest=self.manifest)
            for s,l,g,j,d,r in p.QUARANTINES]
        self.refs = {k: 'synthetic-approved-' + k for k in runtime.WindowGuard.REFERENCES}
        self.receipt = root / 'window.json'
        private_json(self.receipt, dict(self.refs, source_sha=SOURCE, manifest=self.manifest,
            tool_checksum=self.checksum, coordinator_pid=os.getpid(), worktrees=list(self.worktrees),
            max_jobs=2, expires_utc=(datetime.now(timezone.utc)+timedelta(minutes=10)).isoformat()))

    def argv(self):
        result = ['--execute', '--expected-source', SOURCE, '--window-receipt', str(self.receipt),
                  '--evidence-root', str(self.evidence)]
        for key, value in self.refs.items():
            result += ['--'+key.replace('_', '-'), value]
        return result

    def processes(self):
        result = copy.deepcopy(self.procs)
        if self.fault == 'identity' and result:
            result[min(result)]['start'] = 'drift' if self.children[0].directory else str(min(result))
        return result

    def read(self, argv, cwd, input=None, *, source=None):
        assert source in (None, SOURCE)
        argv = tuple(argv)
        self.calls.append((argv, cwd))
        assert cwd in (*self.worktrees, str(self.root))
        fixed = {
            (str(self.tool), '--version'): 'devcore-project 1.2.1',
            (str(self.tool), 'slots', 'manifest'): json.dumps(dict(manifest={}, sha256=self.manifest, heavy_limit=2, port_conflicts=[])),
            (str(self.tool), 'slots', 'status'): json.dumps(self.quarantines + self.active),
            ('git', 'rev-parse', '--show-toplevel'): cwd,
            ('git', 'rev-parse', 'HEAD'): SOURCE,
            ('git', 'status', '--porcelain'): '',
            ('docker', 'inspect', '-f', '{{.Id}}', identity.CONTAINER): identity.CONTAINER,
            ('docker', 'inspect', '-f', '{{.State.Running}}', identity.CONTAINER): 'true',
            ('docker', 'port', identity.CONTAINER, '5432/tcp'): '127.0.0.1:55433',
        }
        if argv in fixed:
            assert input is None
            return fixed[argv]
        assert argv[:-1] == ('docker', 'exec', '-i', identity.CONTAINER, 'psql', '-X', '-qAt',
                            '-v', 'ON_ERROR_STOP=1', '-U', 'devcore_admin', '-d')
        sql = input.decode()
        assert sql.startswith('BEGIN READ ONLY;\n') and sql.endswith('\nROLLBACK;\n')
        self.sql.append((argv[-1], sql))
        if 'json_build_object' in sql:
            assert argv[-1] == 'postgres'
            matches = [r for r in self.rows if "d.datname='" + r['database'] + "'" in sql]
            assert len(matches) == 1
            row = matches[0]
            comment = ('devcore-slot:v1:new_you:' + row['lease_id'] + ':' + row['generation'] + ':'
                       + hashlib.sha256(row['worktree'].encode()).hexdigest() + ':' + self.manifest)
            return json.dumps(dict(row['catalog'], admin_oid=10, database_comment=comment,
                role_comment=comment, privileged=self.fault == 'catalog', login=True,
                memberships=0, other_databases=0, clients=0, unsafe_acl=False, connect=True, legacy_connect=False))
        if 'public.accounts' in sql:
            assert argv[-1] == self.ids[1]['database']
            assert all(email in sql for email in ('slot-proof-147'+'0'*28+c+'@example.test' for c in 'ab'))
            return '0|0' if self.fault == 'counts' else '1|0'
        assert sql.startswith('BEGIN READ ONLY;\nSELECT EXISTS(SELECT FROM pg_database')
        assert self.ids[0]['database'] in sql and self.ids[0]['role'] in sql
        return 't' if self.fault == 'absence' else 'f'

    def popen(self, argv, *, cwd, stdin, stdout, stderr):
        assert tuple(argv) == p.ARGV
        assert len(self.children) < 2
        assert cwd == self.worktrees[len(self.children)]
        assert (stdin, stdout, stderr) == (subprocess.PIPE, subprocess.PIPE, subprocess.STDOUT)
        child = Child(self, len(self.children))
        self.children.append(child)
        if self.fault == 'output':
            child.stdout = io.BytesIO(b'x' * (runtime.LIMIT + 1))
        return child

    @contextlib.contextmanager
    def installed(self):
        original_read_text = Path.read_text
        def read_text(path, *args, **kwargs):
            if str(path) == '/proc/meminfo':
                return 'MemAvailable: 16777216 kB\n'
            if str(path) == '/proc/pressure/memory':
                return 'some avg10=0 avg60=0 avg300=0 total=0\nfull avg10=0 avg60=0 avg300=0 total=0\n'
            return original_read_text(path, *args, **kwargs)
        with contextlib.ExitStack() as stack:
            for target, name, value in ((p, 'ROOT', str(self.root)), (p, 'WORKTREES', self.worktrees),
                    (p, 'MANIFEST', self.manifest), (identity, 'MANIFEST', self.manifest),
                    (p, 'CHECKSUM', self.checksum), (Path, 'home', lambda: self.home),
                    (p, 'bounded_read', self.read), (subprocess, 'Popen', self.popen),
                    (Path, 'read_text', read_text)):
                stack.enter_context(patch.object(target, name, value))
            stack.enter_context(patch.object(p.preflight, '__defaults__', (self.worktrees,)))
            stack.enter_context(patch.object(p.PilotReads.__init__, '__defaults__', (self.processes,)))
            defaults = dict(runtime.WindowGuard.__init__.__kwdefaults__, lock_reader=lambda: False)
            stack.enter_context(patch.object(runtime.WindowGuard.__init__, '__kwdefaults__', defaults))
            stack.enter_context(patch.object(runtime.OwnedProcesses, 'read_command',
                lambda owner, argv, cwd, input=None: self.read(argv, cwd, input)))
            if self.fault == 'finalize':
                stack.enter_context(patch.object(runtime.OwnedProcesses, 'finalize', side_effect=OSError('synthetic receipt failure')))
            yield


class CliCompositionTests(unittest.TestCase):
    def run_fixture(self, fault=None, execute=True):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        f = Fixture(Path(temporary.name), fault)
        output = io.StringIO()
        with f.installed(), contextlib.redirect_stdout(output):
            result = p.main(f.argv() if execute else ['--expected-source', SOURCE])
        return f, result, output.getvalue()

    def test_execute_verifies_real_composition_and_pinned_failure_log(self):
        f, result, output = self.run_fixture()
        self.assertEqual(result, 0, output)
        self.assertEqual(json.loads(output)['exits'], [0, 1])
        self.assertEqual(len(f.children), 2)
        self.assertTrue(any('public.accounts' in sql for _, sql in f.sql))
        for child in f.children:
            self.assertEqual([m.get('ack') for m in child.messages], [None, 'ready', 'done'])
            self.assertFalse(any(m.get('cancel') for m in child.messages))
        self.assertEqual(f.procs, {})
        receipt = json.loads((f.evidence / 'receipt.json').read_text())
        self.assertEqual(receipt['surviving_pids'], [])
        self.assertEqual([r['returncode'] for r in receipt['processes']], [0, 1])
        self.assertTrue(all(r['drained'] and not r['error'] for r in receipt['processes']))
        self.assertEqual((f.evidence.stat().st_mode & 0o777), 0o700)
        self.assertEqual((f.evidence / 'receipt.json').stat().st_mode & 0o777, 0o600)

    def test_default_dry_run_never_launches(self):
        f, result, output = self.run_fixture(execute=False)
        self.assertEqual(result, 0, output)
        self.assertEqual(f.children, [])
        self.assertFalse(f.evidence.exists())
        self.assertFalse(json.loads(output)['execution_clearance'])

    def test_missing_refs_or_window_refuses_before_launch(self):
        for missing in ('refs', 'window'):
            with self.subTest(missing=missing), tempfile.TemporaryDirectory() as directory:
                f = Fixture(Path(directory))
                args = f.argv()
                if missing == 'window':
                    f.receipt.unlink()
                else:
                    del args[-2:]
                with f.installed(), contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(p.main(args), 125)
                self.assertEqual(f.children, [])

    def test_failures_preserve_private_evidence_and_cancel_only_owned_streams(self):
        for fault in ('identity', 'catalog', 'retention', 'counts', 'absence', 'output', 'finalize'):
            with self.subTest(fault=fault):
                f, result, output = self.run_fixture(fault)
                self.assertEqual(result, 125, output)
                self.assertTrue(f.evidence.is_dir())
                self.assertTrue(list(f.evidence.glob('output-*.log')))
                self.assertTrue(f.receipt.exists())
                if fault in ('counts', 'finalize'):
                    self.assertTrue(any('public.accounts' in sql for _, sql in f.sql),
                                    'retention count proof was not reached')
                if fault != 'finalize':
                    self.assertTrue((f.evidence / 'receipt.json').exists())
                if fault in ('identity', 'catalog', 'output'):
                    self.assertTrue(any(m.get('cancel') for c in f.children for m in c.messages))
                for child in f.children:
                    if child.directory:
                        self.assertTrue((child.directory / 'ready.json').exists())


if __name__ == '__main__':
    unittest.main()
