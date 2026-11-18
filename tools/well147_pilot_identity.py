"""Read-only WELL-147 observer. No command is executed by importing this module.

Injected read.command(argv, cwd, stdin=..., limit=...) must bound capture while
reading, discard stderr and raise without including external output. read.status
returns the supported slots-status list. read.processes returns {pid: metadata}
with pid/start/boot/ppid only, captured without arguments or environments.
read.file(path, limit=...) must reject links and bound reads. Root supplies these
adapters and owns admission, launch, cancellation, and completed-barrier evidence.
"""
import copy
import hashlib
import json
from pathlib import Path
import re

CONTAINER = '62c8f3a0f390dd2185e96dcb2525a00c60f1b62a25f02a9fea533dcbc55afc95'
MANIFEST = '3fb71d0ed24dfc4ab8ef75226916da624f5ca4a18343695a154733eb2a93e556'
KEYS = ('lease', 'generation', 'job', 'worktree', 'database', 'role')
HEX = re.compile(r'[0-9a-f]{32}\Z')
EMAIL = re.compile(r'slot-proof-[0-9a-f]{32}@example\.test\Z')


class Refused(RuntimeError):
    """Fixed, non-secret observer diagnosis."""


def require(condition):
    if not condition:
        raise Refused('pilot identity or retention proof refused')


def literal(value):
    return "'" + value.replace("'", "''") + "'"


class IdentityObserver:
    """Identity and finish API for the root composed pilot adapter.

    roots is the ordered A/B pair. done_barrier is a root-owned callback taking
    exact identities, returning True only after successful coordinate completion.
    It must never derive success from a ready record or stdout.
    """

    def __init__(self, read, roots, registry_root, *, done_barrier=None,
                 emails=None):
        self.read = read
        self.roots = tuple(str(Path(p)) for p in roots)
        require(len(self.roots) == 2 and len(set(self.roots)) == 2)
        require(all(Path(p).is_absolute() and str(Path(p)) == p for p in self.roots))
        self.registry = Path(registry_root)
        require(self.registry.is_absolute())
        self.done_barrier = done_barrier or (lambda identities: False)
        self.emails = emails or tuple('slot-proof-147' + '0'*28 + c + '@example.test' for c in 'ab')
        require(len(self.emails) == 2 and len(set(self.emails)) == 2)
        require(all(EMAIL.fullmatch(e) for e in self.emails))
        self.observed = {}

    def _call(self, method, *args, **kwargs):
        try:
            return getattr(self.read, method)(*args, **kwargs)
        except Exception:
            raise Refused('pilot read unavailable') from None

    def _command(self, argv, stdin=None):
        value = self._call('command', argv, self.roots[0], stdin=stdin, limit=65536)
        require(isinstance(value, str) and len(value.encode()) <= 65536)
        return value.strip()

    def _file(self, path):
        value = self._call('file', path, limit=65536)
        require(isinstance(value, str) and len(value.encode()) <= 65536)
        return value

    def _endpoint(self):
        for argv, expected in ((['docker', 'inspect', '-f', '{{.Id}}', CONTAINER], CONTAINER),
                               (['docker', 'port', CONTAINER, '5432/tcp'], '127.0.0.1:55433'),
                               (['docker', 'inspect', '-f', '{{.State.Running}}', CONTAINER], 'true')):
            require(self._command(argv) == expected)
        manifest = json.loads(self._command(['devcore-project', 'slots', 'manifest']))
        require(manifest.get('sha256') == MANIFEST)
        require(hashlib.sha256(json.dumps(manifest['manifest'], sort_keys=True).encode()).hexdigest() == MANIFEST)

    def _sql(self, sql, database='postgres'):
        self._endpoint()
        return self._command(['docker', 'exec', '-i', CONTAINER, 'psql', '-X', '-qAt',
                              '-v', 'ON_ERROR_STOP=1', '-U', 'devcore_admin', '-d', database],
                             'BEGIN READ ONLY;\n' + sql + '\nROLLBACK;\n')

    def _status(self):
        rows = self._call('status')
        require(isinstance(rows, list))
        return rows

    def _row(self, row):
        require(row.get('project') == 'new_you' and type(row.get('slot')) is int)
        require(row['slot'] in range(3, 21))
        require(all(isinstance(row.get(k), str) and HEX.fullmatch(row[k]) for k in ('lease_id', 'generation')))
        name = f"dc_new_you_s{row['slot']:02d}_g{row['generation']}"
        require(row.get('database') == name and row.get('role') == name + '_r')
        require(row.get('manifest') == MANIFEST and row.get('test_host') == '127.0.0.1' and row.get('test_port') == 55433)
        require(row.get('catalog', {}).get('container_id') == CONTAINER)

    def _catalog(self, row, idle=False):
        d, r = literal(row['database']), literal(row['role'])
        sql = f"""SELECT json_build_object(
'database_oid',d.oid::bigint,'role_oid',r.oid::bigint,'owner_oid',d.datdba::bigint,'admin_oid',a.oid::bigint,
'database_comment',shobj_description(d.oid,'pg_database'),'role_comment',shobj_description(r.oid,'pg_authid'),
'privileged',r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolreplication OR r.rolbypassrls,
'login',r.rolcanlogin,'memberships',(SELECT count(*) FROM pg_auth_members WHERE roleid=r.oid OR member=r.oid),
'other_databases',(SELECT count(*) FROM pg_database WHERE datdba=r.oid),
'clients',(SELECT count(*) FROM pg_stat_activity WHERE datid=d.oid),
'unsafe_acl',EXISTS(SELECT FROM aclexplode(COALESCE(d.datacl,acldefault('d',d.datdba))) x
 WHERE x.grantee NOT IN (d.datdba,r.oid) OR (x.grantee=r.oid AND (x.is_grantable OR x.privilege_type NOT IN ('CONNECT','TEMPORARY')))),
'connect',has_database_privilege(r.oid,d.oid,'CONNECT'),
'legacy_connect',has_database_privilege(r.oid,'new_you_test','CONNECT'))
FROM pg_database d JOIN pg_roles r ON r.rolname={r} JOIN pg_roles a ON a.rolname='devcore_admin' WHERE d.datname={d};"""
        c = json.loads(self._sql(sql))
        comment = 'devcore-slot:v1:new_you:' + row['lease_id'] + ':' + row['generation'] + ':' + hashlib.sha256(row['worktree'].encode()).hexdigest() + ':' + MANIFEST
        require(all(type(c.get(k)) is int and c[k] > 0 for k in ('database_oid','role_oid','owner_oid','admin_oid')))
        require(all(c[k] == row['catalog'][k] for k in ('database_oid','role_oid','owner_oid')))
        require(c['owner_oid'] == c['admin_oid'] != c['role_oid'])
        require(c['database_comment'] == c['role_comment'] == comment)
        require(c['privileged'] is False and c['login'] is True and c['memberships'] == c['other_databases'] == 0)
        require(c['unsafe_acl'] is False and c['connect'] is True and c['legacy_connect'] is False)
        require(not idle or c['clients'] == 0)

    @staticmethod
    def _owned(processes, identity, ancestor):
        require(isinstance(identity, dict) and set(identity) == {'pid','start','boot'})
        current = processes.get(identity['pid'], {})
        require(all(current.get(k) == v for k, v in identity.items()))
        seen = set()
        while current.get('pid') != ancestor['pid']:
            require(current.get('pid') not in seen and current.get('ppid') in processes)
            seen.add(current['pid'])
            current = processes[current['ppid']]
        require(all(current.get(k) == v for k, v in ancestor.items()))

    def identity(self, worktree, launched_process):
        try:
            require(worktree in self.roots)
            matches = [r for r in self._status() if r.get('worktree') == worktree and r.get('state') != 'free']
            if not matches:
                require(worktree not in self.observed)
                return None
            require(len(matches) == 1)
            row = matches[0]
            self._row(row)
            if not row.get('jobs') and row.get('state') in ('preparing','ready'):
                return None
            require(row.get('state') == 'in_use' and len(row.get('jobs', {})) == 1)
            job, metadata = next(iter(row['jobs'].items()))
            require(HEX.fullmatch(job) and metadata.get('profile') == 'test')
            require(sum(job in r.get('jobs', {}) for r in self._status()) == 1)
            processes = self._call('processes')
            # Root passes a captured pid/start/boot identity, not a bare Popen PID.
            self._owned(processes, metadata['supervisor'], launched_process)
            self._owned(processes, metadata['session'], metadata['supervisor'])
            self._catalog(row)
            result = dict(zip(KEYS, (row['lease_id'],row['generation'],job,worktree,row['database'],row['role'])))
            require(all(other == worktree or record[2] != launched_process for other, record in self.observed.items()))
            previous = self.observed.get(worktree)
            require(previous is None or previous[0] == result)
            self.observed[worktree] = (copy.deepcopy(result), copy.deepcopy(row), copy.deepcopy(launched_process))
            return result
        except Refused:
            raise
        except Exception:
            raise Refused('pilot identity proof refused') from None

    def finish(self, identities, exits):
        try:
            require(exits == [0, 1] and all(type(e) is int for e in exits) and len(identities) == 2)
            require(all(len({i[k] for i in identities}) == 2 for k in KEYS))
            require(self.done_barrier(copy.deepcopy(identities)) is True)
            rows = self._status()
            processes = self._call('processes')
            for index, root in enumerate(self.roots):
                identity, original, launched = self.observed[root]
                require(identities[index] == identity)
                # Completed supervisors reap all children; no tracked boot/start
                # identity may still exist, including the root-owned launcher.
                for p in (launched, *[original['jobs'][identity['job']][k] for k in ('supervisor','session')]):
                    require(not all(processes.get(p['pid'], {}).get(k) == v for k,v in p.items()))
                receipt = json.loads(self._file(self.registry / 'runs' / identity['job'] / 'result.json'))
                require(type(receipt.get('exit')) is int and receipt.get('children_reaped') is True)
                require(receipt == dict(lease_id=identity['lease'], generation=identity['generation'], job=identity['job'], exit=exits[index], children_reaped=True))
                matches = [r for r in rows if r.get('lease_id') == identity['lease']]
                require(len(matches) == 1)
                row = matches[0]
                self._row(row)
                require(all(row[k] == original[k] for k in ('generation','worktree','database','role','catalog','manifest')) and row['jobs'] == {})
                require(row.get('last_exit') == exits[index])
                if index == 0:
                    require(row['state'] == 'free' and row.get('diagnosis') == 'exact registered generation removed')
                    require(self._sql(f"SELECT EXISTS(SELECT FROM pg_database WHERE datname={literal(identity['database'])}) OR EXISTS(SELECT FROM pg_roles WHERE rolname={literal(identity['role'])});") == 'f')
                else:
                    require(row['state'] == 'retained')
                    self._catalog(row, idle=True)
                    log = self._file(self.registry / 'runs' / identity['job'] / 'output.log')
                    require('reports the seeded fixture failure for managed lease retention' in log and 'assert 1 == 0' in log and '1 test, 1 failure' in log)
                    require(self._sql(f"SELECT count(*) FILTER (WHERE email::text={literal(self.emails[1])}) || '|' || count(*) FILTER (WHERE email::text={literal(self.emails[0])}) FROM public.accounts WHERE email::text IN ({literal(self.emails[0])},{literal(self.emails[1])});", identity['database']) == '1|0')
            return True
        except Exception:
            raise Refused('pilot completion proof refused') from None


class ReadAdapters:
    """Concrete supported status API with root-supplied bounded I/O adapters.

    command has the same keyword contract as IdentityObserver._command. The
    root owns bounded capture, safe file opening and process metadata collection.
    No default subprocess runner or secret-bearing file reader is provided.
    """

    def __init__(self, command, processes, file, cwd):
        self.command, self.processes, self.file, self.cwd = command, processes, file, cwd

    def status(self):
        try:
            text = self.command(['devcore-project', 'slots', 'status'], self.cwd,
                                stdin=None, limit=65536)
            require(isinstance(text, str) and len(text.encode()) <= 65536)
            rows = json.loads(text)
            require(isinstance(rows, list))
            return rows
        except Exception:
            raise Refused('pilot status unavailable') from None
