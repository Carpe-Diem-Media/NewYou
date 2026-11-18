"""Pure pilot tests. Never invokes DevCore, Mix or a database."""
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools import well147_pilot as pilot


class Stream(io.BytesIO):
    def __init__(self, owner, index):
        super().__init__()
        self.owner, self.index = owner, index

    def write(self, data):
        value = json.loads(data)
        self.owner.events.append((self.index, value))
        identity = self.owner.identities[self.index]
        directory = self.owner.directories[self.index]
        if value.get('mode') == 'seed':
            self.owner.c.publish(directory, 'ready', json.dumps(dict(identity, own_count=1, peer_count=self.owner.peer_count)))
        elif value.get('ack') == 'ready':
            self.owner.c.publish(directory, 'done', json.dumps(dict(identity, own_count=1, peer_count=0, cross_slot_denied=True, legacy_denied=True)))
        return super().write(data)


class Process:
    def __init__(self, adapter, index):
        self.stdin = Stream(adapter, index)
        self.adapter, self.index = adapter, index

    def poll(self):
        return 2 if self.adapter.early else None

    def wait(self, timeout):
        if self.adapter.survives:
            raise subprocess.TimeoutExpired('synthetic', timeout)
        return self.index


class Adapter:
    def __init__(self, directories):
        self.directories = directories
        self.c = pilot.load_coordinator()
        self.events = []
        self.launched = []
        self.peer_count = 0
        self.early = False
        self.survives = False
        self.deliberate = True
        self.tick = 0
        self.identities = []
        for index in range(2):
            generation = str(index+3)*32
            database = 'dc_new_you_s0' + str(index+3) + '_g' + generation
            self.identities.append(dict(lease='a'*32, generation=generation, job=str(index+1)*32,
                                       worktree=pilot.WORKTREES[index], database=database, role=database+'_r'))

    def now(self):
        return self.tick

    def pause(self, duration):
        self.tick += duration

    def revalidate(self):
        pass

    def launch(self, argv, cwd, index):
        if index == 1:
            assert (Path(self.directories[0]) / 'ready.json').exists()
        self.launched.append((argv, cwd))
        return Process(self, index)

    def identity(self, cwd, process):
        return self.identities[process.index]

    def finish(self, identities, exits):
        return self.deliberate


class PilotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directories = [Path(self.temp.name)/name for name in ('a', 'b')]
        for directory in self.directories:
            directory.mkdir(mode=0o700)
        self.adapter = Adapter(self.directories)

    def run_pair(self):
        return pilot.orchestrate(self.adapter, self.directories)

    def test_exact_heavy_argv_and_sequential_pair(self):
        result = self.run_pair()
        self.assertEqual(result['exits'], [0, 1])
        self.assertFalse(result['live_acceptance'])
        self.assertEqual(len(self.adapter.launched), 2)
        self.assertEqual(list(pilot.ARGV), ['mise', 'exec', '--', 'tools/newyou-local', 'test', '--heavy', '--', 'mix', 'do', 'ecto.migrate,', 'run', 'test/proof/managed_slot_probe.exs'])
        self.assertEqual([v['mode'] for _, v in self.adapter.events[:2]], ['seed', 'seed'])
        for directory in self.directories:
            self.assertEqual((directory/'ready.json').stat().st_mode & 0o777, 0o600)

    def test_wrong_counts_cancel_without_second_launch(self):
        self.adapter.peer_count = 1
        with self.assertRaisesRegex(pilot.Refused, 'counts'):
            self.run_pair()
        self.assertEqual(len(self.adapter.launched), 1)
        self.assertEqual(self.adapter.events[-1][1], {'cancel': True})

    def test_independent_identity_mismatch(self):
        self.adapter.identities[0]['worktree'] = '/wrong'
        with self.assertRaisesRegex(pilot.Refused, 'worktree'):
            self.run_pair()

    def test_early_failure_is_not_deliberate_failure(self):
        self.adapter.early = True
        with self.assertRaisesRegex(pilot.Refused, 'early'):
            self.run_pair()
        self.assertEqual(len(self.adapter.launched), 1)

    def test_exit_one_requires_independent_deliberate_proof(self):
        self.adapter.deliberate = False
        with self.assertRaisesRegex(pilot.Refused, 'unproved'):
            self.run_pair()
        self.assertEqual(len(self.adapter.launched), 2)

    def test_timeout_preserves_survivor_and_cancels(self):
        self.adapter.identity = lambda *args: None
        self.adapter.survives = True
        with self.assertRaisesRegex(pilot.Refused, 'deadline'):
            pilot.orchestrate(self.adapter, self.directories, timeout=.02)
        self.assertEqual(len(self.adapter.launched), 1)
        self.assertTrue((self.directories[0]/'ready.json').exists())
        self.assertEqual(self.adapter.events[-1][1], {'cancel': True})

    def test_rejects_unbounded_pair_and_deadline(self):
        for directories, timeout in [(self.directories*2, 20), (self.directories, 301)]:
            with self.assertRaises(pilot.Refused):
                pilot.orchestrate(self.adapter, directories, timeout=timeout)
        self.assertEqual(self.adapter.launched, [])

    def test_record_phase_requirements(self):
        identity = self.adapter.identities[0]
        for change in ({'peer_count': 1}, {'legacy_denied': False}, {'job': 'f'*32}):
            record = dict(identity, own_count=1, peer_count=0, cross_slot_denied=True, legacy_denied=True)
            record.update(change)
            with self.assertRaises(pilot.Refused):
                pilot.check_record(record, identity, 'done')

    def test_boolean_fixture_counts_are_not_integer_proof(self):
        identity = self.adapter.identities[0]
        for change in ({'own_count': True}, {'peer_count': False}):
            record = dict(identity, own_count=1, peer_count=0)
            record.update(change)
            with self.assertRaisesRegex(pilot.Refused, 'fixture counts'):
                pilot.check_record(record, identity, 'ready')

    def test_execute_never_launches_even_with_references(self):
        with patch.object(pilot.subprocess, 'run', side_effect=AssertionError('no actions')):
            self.assertEqual(pilot.main(['--execute']), 125)
            self.assertEqual(pilot.main(['--execute', '--owner-authorization-reference', 'owner', '--exclusive-window-reference', 'window']), 125)

    def test_preflight_requires_explicit_reviewed_source_before_reads(self):
        for source in (None, '', 'old-head', 'A'*40):
            with self.subTest(source=source), patch.object(Path, 'read_bytes', side_effect=AssertionError('no reads')):
                with self.assertRaisesRegex(pilot.Refused, 'explicit expected source'):
                    pilot.preflight(lambda *args: self.fail('external read'), '/fake/tool', expected_source=source)

    def test_dryrun_never_calls_orchestration(self):
        with patch.object(pilot, 'preflight', return_value={'mode': 'dryrun'}) as preflight, patch.object(pilot, 'orchestrate', side_effect=AssertionError('no launch')):
            self.assertEqual(pilot.main([]), 0)
            preflight.assert_called_once()

    def test_source_drift_stops_read_only_preflight(self):
        calls = []
        def read(argv, cwd):
            calls.append(argv)
            if '--version' in argv:
                return 'devcore-project 1.2.1'
            if '--show-toplevel' in argv:
                return cwd
            return 'wrong source'
        with patch.object(pilot.hashlib, 'sha256') as digest, patch.object(Path, 'read_bytes', return_value=b'fake'):
            digest.return_value.hexdigest.return_value = pilot.CHECKSUM
            with self.assertRaisesRegex(pilot.Refused, 'source drift'):
                pilot.preflight(read, '/fake/tool', expected_source='a'*40)
        self.assertFalse(any('slots' in call for call in calls))

    def test_quarantine_drift(self):
        with self.assertRaisesRegex(pilot.Refused, 'quarantine'):
            pilot.quarantine_check([])

    def test_manifest_drift_stops_before_status(self):
        calls = []
        def read(argv, cwd):
            calls.append(argv)
            if '--version' in argv:
                return 'devcore-project 1.2.1'
            if '--show-toplevel' in argv:
                return cwd
            if 'HEAD' in argv:
                return 'a'*40
            if 'status' in argv:
                return ''
            return json.dumps({'manifest': {}, 'sha256': 'wrong'})
        with patch.object(pilot.hashlib, 'sha256') as digest, patch.object(Path, 'read_bytes', return_value=b'fake'):
            digest.return_value.hexdigest.return_value = pilot.CHECKSUM
            with self.assertRaisesRegex(pilot.Refused, 'manifest drift'):
                pilot.preflight(read, '/fake/tool', expected_source='a'*40)
        self.assertNotIn(['/fake/tool', 'slots', 'status'], calls)

    def test_exact_quarantines_and_generation_drift(self):
        rows = []
        for slot, lease, generation, job, database_oid, role_oid in pilot.QUARANTINES:
            rows.append(dict(slot=slot, lease_id=lease, generation=generation,
                             jobs={job: {}}, state='quarantined', manifest=pilot.MANIFEST,
                             catalog=dict(database_oid=database_oid, role_oid=role_oid)))
        pilot.quarantine_check(rows)
        rows[1]['generation'] = 'f'*32
        with self.assertRaisesRegex(pilot.Refused, 'quarantine drift'):
            pilot.quarantine_check(rows)

    def test_real_owned_pipe_initial_input(self):
        read_fd, write_fd = os.pipe()
        with os.fdopen(write_fd, 'wb', buffering=0) as stream:
            self.adapter.c.send(stream, {'mode': 'seed'}, pilot.time.monotonic()+1)
        with os.fdopen(read_fd, 'rb') as stream:
            self.assertEqual(json.loads(stream.readline()), {'mode': 'seed'})


if __name__ == '__main__':
    unittest.main()

class CompositionTests(unittest.TestCase):
    def test_command_admission_cache_and_budget(self):
        calls = []
        def runner(argv, cwd, input=None):
            calls.append((argv, input))
            return '[]'
        reads = pilot.PilotReads('/fixed/tool', runner, '/registry')
        for _ in range(100):
            self.assertEqual(reads.command(['devcore-project', 'slots', 'status'], pilot.WORKTREES[0]), '[]')
        self.assertEqual(len(calls), 1)
        for argv, stdin in [(['docker', 'exec', 'arbitrary'], None),
                            (['git', 'reset', '--hard'], None),
                            (['devcore-project', 'slots', 'enable'], None),
                            (['git', 'status', '--porcelain'], 'SELECT 1')]:
            with self.assertRaises(pilot.Refused):
                reads.command(argv, pilot.WORKTREES[0], stdin=stdin)
        reads.invalidate()
        reads.calls = 1024
        with self.assertRaisesRegex(pilot.Refused, 'budget'):
            reads.command(['git', 'status', '--porcelain'], pilot.WORKTREES[0])

    def test_private_result_file_scope(self):
        with tempfile.TemporaryDirectory() as root:
            registry = Path(root)
            job = 'a'*32
            directory = registry/'runs'/job
            directory.mkdir(parents=True)
            path = directory/'result.json'
            path.write_text('{}')
            path.chmod(0o600)
            reads = pilot.PilotReads('/tool', None, registry)
            class Observed:
                observed = {'a': ({'job': job}, {}, {})}
            reads.observer = Observed()
            self.assertEqual(reads.file(path, limit=20), '{}')
            path.chmod(0o644)
            with self.assertRaises(pilot.Refused):
                reads.file(path, limit=20)
            path.unlink()
            path.symlink_to('/dev/null')
            with self.assertRaises(OSError):
                reads.file(path, limit=20)
            with self.assertRaises(pilot.Refused):
                reads.file(directory/'secret', limit=20)

    def test_composed_identity_and_finish_use_real_observer(self):
        import copy
        import hashlib
        from tools import well147_pilot_identity as identity
        from tests.test_well147_pilot_identity import ObserverTests
        fixture = ObserverTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        manifest = identity.MANIFEST
        with patch.object(pilot, 'MANIFEST', manifest):
            reads = pilot.PilotReads('/tool', None, '/registry', processes=fixture.read.processes)
            rows = []
            catalogs = {}
            for index, root in enumerate(pilot.WORKTREES):
                row = copy.deepcopy(fixture.row)
                row.update(slot=index+3, worktree=root, lease_id=str(index+1)*32,
                           generation=str(index+3)*32)
                row['database'] = f"dc_new_you_s{index+3:02d}_g" + row['generation']
                row['role'] = row['database'] + '_r'
                launched = dict(pid=10+index*10, start='1', boot='boot')
                session = dict(pid=11+index*10, start='2', boot='boot')
                row['jobs'] = {str(index+5)*32: dict(profile='test', supervisor=launched, session=session)}
                fixture.read.procs[launched['pid']] = dict(launched, ppid=1)
                fixture.read.procs[session['pid']] = dict(session, ppid=launched['pid'])
                fixture.catalog(row)
                catalogs[row['database']] = copy.deepcopy(fixture.read.catalog)
                rows.append(row)
            fixture.read.rows = rows
            def runner(argv, cwd, input=None):
                if argv == ('/tool', 'slots', 'status'):
                    return json.dumps(fixture.read.rows)
                if argv == ('/tool', 'slots', 'manifest'):
                    return json.dumps({'manifest': {}, 'sha256': manifest})
                if input and b'json_build_object' in input:
                    return json.dumps(next(c for name,c in catalogs.items() if name.encode() in input))
                return fixture.read.command(list(argv), cwd, stdin=input.decode() if input else None)
            reads.runner = runner
            class Window:
                def revalidate(self):
                    return True
            class Owner:
                records = []
            adapter = pilot.ComposedAdapter(Owner(), reads, Window(), 'a'*40)
            identities = []
            for index, root in enumerate(pilot.WORKTREES):
                class P:
                    pid = 10+index*10
                adapter.captured[P.pid] = dict(pid=P.pid, start='1', boot='boot')
                identities.append(adapter.identity(root, P()))
            self.assertEqual(len(identities), 2)
            self.assertEqual(len({i['database'] for i in identities}), 2)
            # Real finish refuses even valid identities until coordinate returns.
            with self.assertRaises(identity.Refused):
                adapter.finish(identities, [0,1])
            adapter.completed(identities)
            fixture.read.procs = {}
            for index, row in enumerate(rows):
                job = identities[index]['job']
                fixture.read.files[f'/registry/runs/{job}/result.json'] = json.dumps(dict(
                    lease_id=row['lease_id'], generation=row['generation'], job=job,
                    exit=index, children_reaped=True))
                row.update(jobs={}, last_exit=index, state='free' if index == 0 else 'retained')
                if index == 0:
                    row['diagnosis'] = 'exact registered generation removed'
                else:
                    fixture.read.files[f'/registry/runs/{job}/output.log'] = 'reports the seeded fixture failure for managed lease retention\nassert 1 == 0\n1 test, 1 failure'
            reads.file = fixture.read.file
            adapter.observer.read.file = reads.file
            self.assertTrue(adapter.finish(identities, [0,1]))
            fixture.read.fixture = '0|0'
            with self.assertRaises(identity.Refused):
                adapter.finish(identities, [0,1])

    def test_execute_missing_each_required_input_has_no_launch(self):
        full = ['--execute', '--expected-source', 'a'*40, '--window-receipt', '/receipt',
                '--evidence-root', '/fresh']
        for reference in pilot.runtime.WindowGuard.REFERENCES:
            full += ['--'+reference.replace('_','-'), 'external-reference']
        for flag in ['--window-receipt', '--evidence-root'] + [
                '--'+r.replace('_','-') for r in pilot.runtime.WindowGuard.REFERENCES]:
            args = full.copy()
            index = args.index(flag)
            del args[index:index+2]
            with patch.object(pilot, 'preflight', side_effect=AssertionError('no reads')):
                self.assertEqual(pilot.main(args), 125)

    def test_kernel_start_matches_installed_devcore_string_contract(self):
        metadata = pilot.process_metadata()[os.getpid()]
        self.assertEqual(metadata['pid'], os.getpid())
        self.assertIsInstance(metadata['start'], str)
        self.assertEqual(set(metadata), {'pid', 'start', 'boot', 'ppid'})

    def test_only_observer_call_admits_exact_readonly_sql(self):
        reads = pilot.PilotReads('/tool', lambda *a, **kw: self.fail('external call'), '/registry')
        argv = ['docker', 'exec', '-i', pilot.observer_module.CONTAINER, 'psql',
                '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-U', 'devcore_admin', '-d', 'postgres']
        with self.assertRaisesRegex(pilot.Refused, 'command refused'):
            reads.command(argv, pilot.WORKTREES[0], stdin='BEGIN READ ONLY;\nSELECT 1;\nROLLBACK;\n')
