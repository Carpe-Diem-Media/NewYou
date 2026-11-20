import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'test/proof/managed_slot_coordinator.py'

def identity(n):
    g = str(n) * 32
    db = f'dc_new_you_s0{n}_g{g}'
    return dict(lease=g, generation=g, job=g, worktree=f'/synthetic/{n}', database=db, role=db+'_r')

class ProtocolTest(unittest.TestCase):
    def test_private_records_and_aliases(self):
        spec = importlib.util.spec_from_file_location('coordinator', HELPER)
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        with tempfile.TemporaryDirectory() as d:
            os.chmod(d, 0o700)
            old = os.umask(0)
            try:
                m.publish(d, 'ready', '{}')
            finally:
                os.umask(old)
            self.assertEqual(os.stat(d+'/ready.json').st_mode & 0o777, 0o600)
            with self.assertRaises(OSError): m.publish(d, 'ready', '{}')
            os.symlink(d, d+'/alias')
            with self.assertRaises(OSError): m.publish(d+'/alias', 'done', '{}')
            os.symlink('/tmp', d+'/done.json')
            with self.assertRaises(OSError): m.publish(d, 'done', '{}')
            with self.assertRaises(OSError): m.private_directory(d, uid=os.getuid()+1)

    def test_coordinator_pair_timeout_cancel_and_wrong_identity(self):
        spec = importlib.util.spec_from_file_location('coordinator', HELPER)
        m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
        with tempfile.TemporaryDirectory() as root:
            dirs=[root+'/one',root+'/two']
            for d in dirs: os.mkdir(d,0o700)
            streams=[io.BytesIO(),io.BytesIO()]
            for n,d in enumerate(dirs):
                for phase in ['ready','done']:
                    m.publish(d,phase,json.dumps(identity(n+1)))
            m.coordinate(dirs,[identity(1),identity(2)],streams,timeout=.2)
            for n,stream in enumerate(streams):
                records=[json.loads(x) for x in stream.getvalue().splitlines()]
                self.assertEqual([r['ack'] for r in records],['ready','done'])
                self.assertEqual(records[0]['peer_database'],identity(2-n)['database'])
            with self.assertRaises(ValueError):
                m.coordinate(dirs,[identity(2),identity(1)],streams,timeout=.1)
            with self.assertRaises(RuntimeError):
                m.coordinate(dirs,[identity(1),identity(2)],streams,cancelled=lambda:True)
            os.unlink(dirs[1]+'/ready.json')
            Path(dirs[1]+'/ready.json').write_bytes(b'{')
            os.chmod(dirs[1]+'/ready.json',0o600)
            with self.assertRaises(TimeoutError):
                m.coordinate(dirs,[identity(1),identity(2)],streams,timeout=.05)
            self.assertTrue(Path(dirs[1]+'/ready.json').exists())

    def test_coordinator_write_deadline(self):
        spec=importlib.util.spec_from_file_location('coordinator', HELPER)
        m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
        read_fd,write_fd=os.pipe()
        with os.fdopen(write_fd,'wb',buffering=0) as stream:
            try:
                os.set_blocking(write_fd,False)
                while True:
                    try: os.write(write_fd,b'x'*4096)
                    except BlockingIOError: break
                with self.assertRaises(TimeoutError):
                    m.send(stream,{'cancel':True},time.monotonic()+.05)
            finally: os.close(read_fd)

    def start(self, d, child_fail=False, initial=False, n=1, timeout=300):
        # OTP JSON supplies only the codec. Production lifecycle and ack calls are real.
        expr = '''defmodule Jason do
          def encode!(v), do: :json.encode(v) |> IO.iodata_to_binary()
          def decode(v) do
            try do {:ok, :json.decode(v)} rescue _ -> {:error, :json} end
          end
        end
        Process.put(:managed_slot_probe_test_load, true)
        Code.require_file("test/proof/managed_slot_probe.exs")
        '''
        if initial:
            expr += 'IO.inspect(NewYou.ManagedSlotProbe.read_input(:stdio, 150)); System.halt(2)'
        else:
            receipt = json.dumps(json.dumps(identity(n)))
            expr = expr.replace('test/proof/managed_slot_probe.exs', os.environ.get('PROBE_SOURCE', 'test/proof/managed_slot_probe.exs'))
            expr += f'''r = :json.decode({receipt})
            p = %{{control_directory: {json.dumps(d)}, browser?: false, fail_after_commit?: false}}
            a = %{{prepare: fn _ -> %{{"own_count" => 1, "peer_count" => 0}} end,
            finish: fn _, _ -> case System.cmd("/bin/sh", ["-c", "exit {1 if child_fail else 0}"]) do {{_, 0}} -> :ok; _ -> :error end end}}
            NewYou.ManagedSlotProbe.run_seed(p, r, a, {timeout})
            '''
        return subprocess.Popen(['mise','exec','--','elixir','-e',expr], cwd=ROOT,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            env={**os.environ, 'ERL_FLAGS': '+S 2:2'})

    def record(self, p, d, phase):
        path = Path(d)/(phase+'.json')
        end = time.monotonic()+5
        while time.monotonic()<end:
            if path.exists():
                data=path.read_bytes()
                if data.endswith(b'\n'): return json.loads(data)
            if p.poll() is not None: self.fail(p.communicate()[1].decode())
            time.sleep(.005)
        self.fail('no complete record')

    def ack(self,p,phase,wrong=False):
        v = dict(ack=phase,identity=identity(2 if wrong else 1))
        if phase=='ready': v['peer_database']=identity(2)['database']
        p.stdin.write(json.dumps(v).encode()+b'\n'); p.stdin.flush()

    def test_lifecycle_each_ack_and_failures(self):
        for phase in ['ready','done']:
            for failure in ['success','eof','cancel','malformed','wrong','timeout','child']:
                if failure=='child' and phase=='done': continue
                with self.subTest(phase=phase,failure=failure), tempfile.TemporaryDirectory() as d:
                    os.chmod(d,0o700)
                    p=self.start(d, failure=='child')
                    try:
                        self.assertEqual({k:v for k,v in self.record(p,d,'ready').items() if k in identity(1)},identity(1))
                        if phase=='done': self.ack(p,'ready'); self.record(p,d,'done')
                        time.sleep(.04)
                        self.assertIsNone(p.poll(), 'exited before required ack')
                        if phase=='ready': self.assertFalse(Path(d,'done.json').exists())
                        if failure in ['success','child']:
                            self.ack(p,phase)
                            if phase=='ready' and failure=='success':
                                self.record(p,d,'done'); time.sleep(.04)
                                self.assertIsNone(p.poll()); self.ack(p,'done')
                        elif failure=='eof': p.stdin.close(); p.stdin=None
                        elif failure=='wrong': self.ack(p,phase,True)
                        elif failure in ['cancel','malformed']:
                            p.stdin.write(b'{"cancel":true}\n' if failure=='cancel' else b'bad\n'); p.stdin.flush()
                        p.wait(timeout=5)
                        self.assertEqual(p.returncode==0, failure=='success')
                    finally:
                        if p.poll() is None: p.kill()
                        p.communicate()

    def test_coordinator_with_two_owned_probe_processes(self):
        spec=importlib.util.spec_from_file_location('coordinator', HELPER)
        m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
        with tempfile.TemporaryDirectory() as root:
            dirs=[root+'/one',root+'/two']
            for d in dirs: os.mkdir(d,0o700)
            processes=[self.start(d,n=n+1,timeout=3000) for n,d in enumerate(dirs)]
            try:
                m.coordinate(dirs,[identity(1),identity(2)],[p.stdin for p in processes],timeout=5)
                for p in processes:
                    p.wait(timeout=5); self.assertEqual(p.returncode,0)
            finally:
                for p in processes:
                    if p.poll() is None: p.kill()
                    p.communicate()

    def test_ack_call_sensitivity(self):
        source=(ROOT/'test/proof/managed_slot_probe.exs').read_text()
        for phase in ['ready','done']:
            with tempfile.TemporaryDirectory() as d:
                for name in ['managed_slot_control.exs','managed_slot_coordinator.py']:
                    Path(d,name).write_bytes((ROOT/'test/proof'/name).read_bytes())
                replacement = '%{"peer_database" => "dc_new_you_s02_g" <> String.duplicate("2", 32)}' if phase=='ready' else ':ok'
                target=f'acknowledge!("{phase}", receipt, timeout)'
                self.assertEqual(source.count(target),1)
                Path(d,'probe.exs').write_text(source.replace(target,replacement))
                result=subprocess.run(['python3','-m','unittest',
                    'tests.test_managed_slot_protocol.ProtocolTest.test_lifecycle_each_ack_and_failures'],
                    cwd=ROOT,env={**os.environ,'PROBE_SOURCE':d+'/probe.exs'},capture_output=True,timeout=45)
                self.assertNotEqual(result.returncode,0)
                self.assertIn(b'exited before required ack',result.stderr)

    def test_initial_bounded_timed_reader(self):
        for data in [b'x'*2049, b'', None]:
            p=self.start('',initial=True)
            try:
                if data is not None:
                    p.stdin.write(data); p.stdin.flush()
                    if not data: p.stdin.close(); p.stdin=None
                p.wait(timeout=4)
                self.assertEqual(p.returncode,2)
                self.assertIn(b':too_large' if data else (b':eof' if data == b'' else b':timeout'),p.stdout.read())
            finally:
                if p.poll() is None: p.kill()
                p.communicate()


class CollectorTest(unittest.TestCase):
    def run_collector(self, mode, source=None):
        child = """import sys,json
mode=sys.argv[1]; receipt=json.loads(sys.argv[2])
if mode=='missing': sys.exit(0)
if mode=='mismatch': receipt['job']='f'*32
if mode=='counts': receipt['own_count']=2
sys.stdout.write('MANAGED_SLOT_CHILD='+json.dumps(receipt)+'\\n'); sys.stdout.flush()
ack=sys.stdin.buffer.readline()
if mode=='failure': sys.exit(7)
if mode=='timeout': sys.stdin.buffer.read(); sys.exit(0)
if mode=='flood': sys.stdout.write('x'*20000); sys.stdout.flush()
if mode=='suffix': sys.stdout.write('diagnostic'); sys.stdout.flush()
"""
        expected={**identity(1), 'own_count':1, 'peer_count':0}
        expression = """defmodule Jason do
          def encode!(v), do: :json.encode(v) |> IO.iodata_to_binary()
          def decode(v) do
            try do {:ok, :json.decode(v)} rescue _ -> {:error, :json} end
          end
        end
        Process.put(:managed_slot_probe_test_load, true)
        """
        expression += 'Code.require_file('+json.dumps(str(source or ROOT/'test/proof/managed_slot_probe.exs'))+')\n'
        expression += 'expected = :json.decode('+json.dumps(json.dumps(expected))+')\n'
        expression += 'p = Port.open({:spawn_executable, System.find_executable("python3")}, [:binary, :exit_status, :use_stdio, :stderr_to_stdout, args: ["-c", '+json.dumps(child)+', '+json.dumps(mode)+', '+json.dumps(json.dumps(expected))+']])\n'
        expression += 'result = NewYou.ManagedSlotProbe.collect_child(p, "", System.monotonic_time(:millisecond)+500, expected)\n'
        expression += 'if result != expected, do: System.halt(3)\n'
        return subprocess.run(['mise','exec','--','elixir','-e',expression], cwd=ROOT,
                              env={**os.environ,'ERL_FLAGS':'+S 2:2'},capture_output=True,timeout=8)

    def test_actual_collector_exit_identity_deadline_and_output_bound(self):
        for mode in ['success','suffix','failure','missing','mismatch','counts','timeout','flood']:
            with self.subTest(mode=mode):
                result=self.run_collector(mode)
                self.assertEqual(result.returncode==0,mode in ['success','suffix'], result.stderr.decode())

    def test_nonzero_exit_guard_sensitivity(self):
        source=(ROOT/'test/proof/managed_slot_probe.exs').read_text()
        target='NewYou.ManagedSlotControl.child_result(status, receipt)'
        self.assertEqual(source.count(target),1)
        with tempfile.TemporaryDirectory() as d:
            for name in ['managed_slot_control.exs','managed_slot_coordinator.py']:
                Path(d,name).write_bytes((ROOT/'test/proof'/name).read_bytes())
            p=Path(d,'probe.exs');p.write_text(source.replace(target,'NewYou.ManagedSlotControl.child_result(0, receipt)'))
            result=self.run_collector('failure',p)
            self.assertEqual(result.returncode,0, 'mutation did not accept receipt followed by nonzero exit')

    def test_output_bound_guard_sensitivity(self):
        source=(ROOT/'test/proof/managed_slot_probe.exs').read_text()
        target='when bytes + byte_size(data) <= 16_384'
        self.assertEqual(source.count(target),1)
        with tempfile.TemporaryDirectory() as d:
            for name in ['managed_slot_control.exs','managed_slot_coordinator.py']:
                Path(d,name).write_bytes((ROOT/'test/proof'/name).read_bytes())
            p=Path(d,'probe.exs');p.write_text(source.replace(target,'when is_binary(data)'))
            result=self.run_collector('flood',p)
            self.assertEqual(result.returncode,0, 'mutation did not remove the post-receipt output bound')

if __name__ == '__main__': unittest.main()
