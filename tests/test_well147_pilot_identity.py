"""Injected proof only. No workstation services are contacted."""
import copy
import hashlib
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from tools import well147_pilot_identity as m


class Fake:
    def __init__(self):
        self.rows = []
        self.procs = {}
        self.files = {}
        self.commands = []
        self.catalog = {}
        self.fixture = '1|0'

    def status(self):
        return copy.deepcopy(self.rows)

    def processes(self):
        return copy.deepcopy(self.procs)

    def file(self, path, **kw):
        return self.files[str(path)]

    def command(self, argv, cwd, stdin=None, limit=None):
        self.commands.append((argv, stdin, limit))
        if argv[:3] == ['devcore-project', 'slots', 'manifest']:
            return json.dumps({'manifest': {}, 'sha256': m.MANIFEST})
        if '5432/tcp' in argv:
            return '127.0.0.1:55433'
        if '{{.Id}}' in argv:
            return m.CONTAINER
        if '{{.State.Running}}' in argv:
            return 'true'
        assert stdin.startswith('BEGIN READ ONLY;') and stdin.endswith('ROLLBACK;\n')
        if 'json_build_object' in stdin:
            return json.dumps(self.catalog)
        if 'public.accounts' in stdin:
            return self.fixture
        return 'f'


class ObserverTests(unittest.TestCase):
    def setUp(self):
        # Use a real manifest preimage for the hash check, while isolating all I/O.
        self.manifest_patch = patch.object(m, 'MANIFEST', hashlib.sha256(b'{}').hexdigest())
        self.manifest_patch.start()
        self.addCleanup(self.manifest_patch.stop)
        self.read = Fake()
        self.observer = m.IdentityObserver(self.read, ['/a','/b'], '/registry', done_barrier=lambda ids: True)
        self.launched = {'pid': 10, 'start': '1', 'boot': 'boot'}
        self.read.procs = {10: dict(self.launched, ppid=1), 11: dict(pid=11,start='2',boot='boot',ppid=10)}
        self.row = dict(project='new_you', slot=3, lease_id='a'*32, generation='b'*32,
                        worktree='/a', database='dc_new_you_s03_g'+'b'*32,
                        role='dc_new_you_s03_g'+'b'*32+'_r', manifest=m.MANIFEST,
                        test_host='127.0.0.1',test_port=55433,state='in_use',
                        catalog=dict(container_id=m.CONTAINER,database_oid=100,role_oid=101,owner_oid=10),
                        jobs={'c'*32: dict(profile='test',supervisor=self.launched,
                                          session=dict(pid=11,start='2',boot='boot'))})
        self.read.rows = [self.row, {'worktree':'/unrelated','state':'quarantined','jobs':{'unrelated':{}}}]
        self.catalog(self.row)

    def catalog(self, row):
        comment = f"devcore-slot:v1:new_you:{row['lease_id']}:{row['generation']}:{hashlib.sha256(row['worktree'].encode()).hexdigest()}:{m.MANIFEST}"
        self.read.catalog = dict(database_oid=100,role_oid=101,owner_oid=10,admin_oid=10,
                                 database_comment=comment,role_comment=comment,privileged=False,
                                 login=True,memberships=0,other_databases=0,clients=0,
                                 unsafe_acl=False,connect=True,legacy_connect=False)

    def test_identity_and_read_only_commands(self):
        result = self.observer.identity('/a', self.launched)
        self.assertEqual(set(result),set(m.KEYS))
        self.assertEqual(result['job'],'c'*32)
        self.assertTrue(all(limit == 65536 for _,_,limit in self.read.commands))

    def test_not_registered(self):
        self.read.rows = []
        self.assertIsNone(self.observer.identity('/a',self.launched))

    def test_identity_rejections_with_valid_prerequisites(self):
        for field, value in [('generation','stale'),('manifest','wrong'),('test_port',55432),('state','retained'),('slot',1)]:
            with self.subTest(field=field):
                original = self.row[field]
                self.row[field] = value
                with self.assertRaises(m.Refused):
                    self.observer.identity('/a',self.launched)
                self.row[field] = original
        for key,value in [('role_oid',999),('database_comment','forged'),('unsafe_acl',True),('legacy_connect',True),('memberships',1)]:
            self.catalog(self.row)
            self.read.catalog[key] = value
            with self.assertRaises(m.Refused):
                self.observer.identity('/a',self.launched)

    def test_nonowned_or_reused_process(self):
        for change in ({'start':'stale'}, {'ppid':1}):
            self.read.procs[11].update(change)
            with self.assertRaises(m.Refused):
                self.observer.identity('/a',self.launched)

    def prepare_finish(self):
        a = self.observer.identity('/a',self.launched)
        b = copy.deepcopy(self.row)
        b.update(slot=4,worktree='/b',lease_id='d'*32,generation='e'*32,
                 database='dc_new_you_s04_g'+'e'*32,role='dc_new_you_s04_g'+'e'*32+'_r')
        b['jobs'] = {'f'*32: next(iter(b['jobs'].values()))}
        self.read.rows.append(b)
        self.catalog(b)
        second = dict(pid=20,start='3',boot='boot')
        self.read.procs[20] = dict(second,ppid=1)
        self.read.procs[21] = dict(pid=21,start='4',boot='boot',ppid=20)
        b['jobs']['f'*32].update(supervisor=second,session=dict(pid=21,start='4',boot='boot'))
        bid = self.observer.identity('/b',second)
        self.read.procs = {}
        for index,(identity,row) in enumerate(((a,self.row),(bid,b))):
            row.update(jobs={},last_exit=index,state='free' if index == 0 else 'retained')
            row['diagnosis'] = 'exact registered generation removed' if index == 0 else ''
            self.read.files[f"/registry/runs/{identity['job']}/result.json"] = json.dumps(dict(lease_id=identity['lease'],generation=identity['generation'],job=identity['job'],exit=index,children_reaped=True))
        # Distinct job IDs are required in real allocator receipts.
        return [a,bid]

    def test_finish_positive_and_negative_proofs(self):
        ids = self.prepare_finish()
        log_path = '/registry/runs/' + ids[1]['job'] + '/output.log'
        self.read.files[log_path] = ('reports the seeded fixture failure for managed lease retention\n'
                                     'assert 1 == 0\n1 test, 1 failure')
        self.assertTrue(self.observer.finish(ids,[0,1]))
        for fixture in ('0|0','1|1','2|0'):
            self.read.fixture = fixture
            with self.assertRaises(m.Refused):
                self.observer.finish(ids,[0,1])
        self.read.fixture = '1|0'
        self.read.files[log_path] = 'early compilation failure'
        with self.assertRaises(m.Refused):
            self.observer.finish(ids,[0,1])
        self.read.files[log_path] = ('reports the seeded fixture failure for managed lease retention '
                                     'assert 1 == 0 1 test, 1 failure')
        receipt_path = '/registry/runs/' + ids[1]['job'] + '/result.json'
        receipt = json.loads(self.read.files[receipt_path])
        for key,value in [('children_reaped',False),('generation','0'*32),('exit',0)]:
            changed = dict(receipt)
            changed[key] = value
            self.read.files[receipt_path] = json.dumps(changed)
            with self.assertRaises(m.Refused):
                self.observer.finish(ids,[0,1])
        self.read.files[receipt_path] = json.dumps(receipt)
        self.read.rows[-1]['generation'] = '0'*32
        with self.assertRaises(m.Refused):
            self.observer.finish(ids,[0,1])

    def test_finish_rejects_missing_barrier(self):
        ids = self.prepare_finish()
        self.observer.done_barrier = lambda ids: False
        with self.assertRaises(m.Refused):
            self.observer.finish(ids,[0,1])

    def test_manifest_and_endpoint_drift(self):
        command = self.read.command
        for wrong in ('manifest','endpoint'):
            def changed(argv, *args, **kwargs):
                if wrong == 'manifest' and argv[:3] == ['devcore-project','slots','manifest']:
                    return json.dumps({'manifest':{},'sha256':'forged'})
                if wrong == 'endpoint' and '5432/tcp' in argv:
                    return '127.0.0.1:55432'
                return command(argv,*args,**kwargs)
            self.read.command = changed
            with self.assertRaises(m.Refused):
                self.observer.identity('/a',self.launched)
        self.read.command = command

    def test_changed_identity_and_duplicate_job(self):
        self.observer.identity('/a',self.launched)
        self.row['lease_id'] = '1'*32
        self.catalog(self.row)
        with self.assertRaises(m.Refused):
            self.observer.identity('/a',self.launched)
        self.row['lease_id'] = 'a'*32
        self.catalog(self.row)
        self.read.rows.append(dict(worktree='/foreign', jobs=copy.deepcopy(self.row['jobs'])))
        with self.assertRaises(m.Refused):
            self.observer.identity('/a',self.launched)

    def test_status_uses_supported_read_command(self):
        calls = []
        def command(argv,cwd,**kwargs):
            calls.append((argv,cwd,kwargs))
            return '[]'
        adapter = m.ReadAdapters(command,lambda: {},lambda path,**kw: '', '/a')
        self.assertEqual(adapter.status(),[])
        self.assertEqual(calls[0][0],['devcore-project','slots','status'])
        self.assertEqual(calls[0][2],dict(stdin=None,limit=65536))

    def test_errors_do_not_disclose_external_text(self):
        self.read.status = lambda: (_ for _ in ()).throw(RuntimeError('SECRET'))
        with self.assertRaisesRegex(m.Refused, '^pilot read unavailable$'):
            self.observer.identity('/a',self.launched)


if __name__ == '__main__':
    unittest.main()
