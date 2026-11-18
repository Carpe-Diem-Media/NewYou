"""Synthetic-only tests. No DevCore, Docker, database or live pilot calls."""
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from tools.well147_pilot_runtime import (LIMIT, OwnedProcesses, Refused,
                                        WindowGuard, legacy_lock_present, read_command)


class WindowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'window.json'
        self.now = datetime.now(timezone.utc)
        self.expected = dict(source_sha='a'*40, manifest='b'*64, tool_checksum='c'*64,
                             coordinator_pid=os.getpid(), worktrees=['/exact/a', '/exact/b'],
                             owner_authorization_reference='external-owner-proof',
                             exclusive_window_reference='external-window-proof',
                             legacy_owner_clearance_reference='external-clearance-proof',
                             capacity_reference='external-capacity-proof')
        self.receipt = dict(self.expected, max_jobs=2,
                            expires_utc=(self.now + timedelta(minutes=20)).isoformat())
        self.write()

    def write(self):
        self.path.write_text(json.dumps(self.receipt))
        self.path.chmod(0o600)

    def guard(self, **kwargs):
        options = dict(expected=self.expected, identity_reader=lambda: {
            k: self.expected[k] for k in WindowGuard.IDENTITY},
            capacity_reader=lambda refs: True, lock_reader=lambda: False,
            now=lambda: self.now)
        options.update(kwargs)
        return WindowGuard(self.path, **options)

    def test_read_only_validation(self):
        before = self.path.read_bytes()
        with patch('subprocess.Popen', side_effect=AssertionError('no actions')):
            self.guard().revalidate()
        self.assertEqual(before, self.path.read_bytes())
        self.assertEqual(list(Path(self.temp.name).iterdir()), [self.path])

    def test_owner_mode_symlink_and_duplicate(self):
        self.path.chmod(0o644)
        with self.assertRaises(Refused): self.guard().revalidate()
        self.write()
        original = os.fstat
        def wrong_owner(fd):
            fields = list(original(fd))
            fields[4] = os.getuid() + 1
            return os.stat_result(fields)
        with patch('os.fstat', side_effect=wrong_owner):
            with self.assertRaises(Refused): self.guard().revalidate()
        target = self.path.with_suffix('.target')
        self.path.rename(target)
        self.path.symlink_to(target)
        with self.assertRaises(Refused): self.guard().revalidate()
        self.path.unlink()
        self.path.write_text('{"max_jobs":2,"max_jobs":2}')
        self.path.chmod(0o600)
        with self.assertRaisesRegex(Refused, 'duplicate'): self.guard().revalidate()

    def test_stale_future_identity_and_missing_clearance(self):
        for delta in (-1, 1801):
            self.receipt['expires_utc'] = (self.now + timedelta(seconds=delta)).isoformat()
            self.write()
            with self.assertRaises(Refused): self.guard().revalidate()
        self.receipt['expires_utc'] = (self.now + timedelta(minutes=10)).isoformat()
        self.write()
        with self.assertRaises(Refused): self.guard(identity_reader=lambda: {}).revalidate()
        for key in WindowGuard.REFERENCES:
            receipt = self.receipt.copy()
            self.receipt[key] = ''
            self.write()
            with self.assertRaises(Refused): self.guard().revalidate()
            self.receipt = receipt
        self.write()
        guard = self.guard()
        guard.revalidate()
        self.receipt['expires_utc'] = (self.now + timedelta(minutes=11)).isoformat()
        self.write()
        with self.assertRaisesRegex(Refused, 'drift'): guard.revalidate()

    def test_conflict_and_unknown_fail_closed(self):
        for value in (True, None):
            with self.assertRaises(Refused): self.guard(lock_reader=lambda: value).revalidate()
        for value in (False, None, 1):
            with self.assertRaises(Refused): self.guard(capacity_reader=lambda r: value).revalidate()
        with self.assertRaises(Refused):
            self.guard(lock_reader=lambda: (_ for _ in ()).throw(OSError('private'))).revalidate()

    def test_lock_inode_only_readers(self):
        info = self.path.stat()
        token = '%x:%x:%d' % (os.major(info.st_dev), os.minor(info.st_dev), info.st_ino)
        self.assertTrue(legacy_lock_present(self.path, locks_reader=lambda:
                        '1: FLOCK ADVISORY WRITE 123 %s 0 EOF\n' % token))
        self.assertFalse(legacy_lock_present(self.path, locks_reader=lambda: ''))
        self.assertFalse(legacy_lock_present(self.path.with_suffix('.absent')))
        with self.assertRaises(Refused):
            legacy_lock_present(self.path, locks_reader=lambda: 'unknown')


class ProcessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.events = []
        self.owners = []
        self.addCleanup(self.cleanup_owned)

    def cleanup_owned(self):
        # Synthetic children have finite normal lifecycles. Never signal any PID.
        for owner in self.owners:
            for record in owner.records:
                process = record.get('_process')
                if process:
                    if not process.stdin.closed: process.stdin.close()
                    process.wait(timeout=5)
            owner.close(timeout=2)

    def owner(self, script, reads=()):
        argv = (sys.executable, '-c', script)
        owner = OwnedProcesses(Path(self.temp.name) / str(len(self.owners)), argv=argv,
                               worktrees=(self.temp.name, '/tmp'),
                               cancel_callback=self.events.append, read_specs=reads,
                               sources=dict(source_sha='a'*40, manifest='b'*64, tool_checksum='c'*64))
        self.owners.append(owner)
        return owner, argv

    def test_exact_launch_and_two_bound(self):
        owner, argv = self.owner('print("diagnosis")')
        with self.assertRaises(Refused): owner.launch(('arbitrary',), self.temp.name, 0)
        with self.assertRaises(Refused): owner.launch(argv, '/wrong', 0)
        for index, cwd in enumerate((self.temp.name, '/tmp')):
            process = owner.launch(argv, cwd, index)
            process.wait(timeout=3)
        with self.assertRaises(Refused): owner.launch(argv, self.temp.name, 0)
        result = owner.close()
        self.assertEqual(len(result['processes']), 2)
        self.assertFalse(result['surviving_pids'])
        self.assertEqual(stat.S_IMODE(owner.root.stat().st_mode), 0o700)
        for path in owner.root.iterdir(): self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)

    def test_cap_continues_draining_retains_diagnostics_no_kill(self):
        owner, argv = self.owner('import sys; sys.stdout.buffer.write(b"diagnosis\\n" + b"x" * (4*1024*1024)); sys.exit(1)')
        with patch.object(subprocess.Popen, 'kill', side_effect=AssertionError('kill forbidden')), \
             patch.object(subprocess.Popen, 'terminate', side_effect=AssertionError('terminate forbidden')):
            process = owner.launch(argv, self.temp.name, 0)
            self.assertEqual(process.wait(timeout=5), 1)
            receipt = owner.close(timeout=2)
        row = receipt['processes'][0]
        self.assertTrue(row['truncated'])
        self.assertTrue(row['drained'])
        self.assertEqual(row['bytes_retained'], LIMIT)
        self.assertEqual(row['returncode'], 1)
        self.assertTrue((owner.root / row['log']).read_bytes().startswith(b'diagnosis\n'))
        self.assertIn('output limit exceeded', self.events)
        self.assertNotIn('argv', json.dumps(receipt))

    def test_live_pid_receipt_and_close_deadline(self):
        owner, argv = self.owner('import time; time.sleep(.4)')
        process = owner.launch(argv, self.temp.name, 0)
        start = time.monotonic()
        receipt = owner.close(timeout=.01)
        self.assertLess(time.monotonic() - start, .3)
        self.assertEqual(receipt['surviving_pids'], [process.pid])
        with self.assertRaises(Refused): owner.launch(argv, '/tmp', 1)
        process.wait(timeout=3)
        self.assertFalse(owner.finalize()['surviving_pids'])

    def test_read_allowlist_input_and_failure_diagnostics(self):
        argv = (sys.executable, '-c', 'import sys; print(sys.stdin.read()); print("diagnosis"); sys.exit(1)')
        owner, _ = self.owner('pass', reads=((argv, self.temp.name),))
        with self.assertRaisesRegex(Refused, '^read command not allowed$'):
            read_command(('unknown',), self.temp.name, owner=owner)
        with self.assertRaisesRegex(Refused, '^read command failed$'):
            read_command(argv, self.temp.name, b'protocol', owner=owner)
        receipt = owner.close()
        self.assertIn(b'diagnosis', (owner.root / receipt['processes'][0]['log']).read_bytes())
        self.assertNotIn('protocol', json.dumps(receipt))

    def test_read_success_timeout_and_default_deadline(self):
        argv = (sys.executable, '-c', 'print("status")')
        slow = (sys.executable, '-c', 'import time; time.sleep(.3)')
        owner, _ = self.owner('pass', reads=((argv, self.temp.name), (slow, self.temp.name)))
        self.assertEqual(read_command(argv, self.temp.name, owner=owner), 'status\n')
        with self.assertRaises(Refused): owner.read_command(argv, self.temp.name, timeout=11)
        with self.assertRaisesRegex(Refused, '^read command failed$'):
            owner.read_command(slow, self.temp.name, timeout=.01)
        self.assertTrue(owner.close(timeout=0)['surviving_pids'])

    def test_launch_error_is_fixed_and_retained(self):
        owner, argv = self.owner('pass')
        with patch('subprocess.Popen', side_effect=OSError('secret detail')):
            with self.assertRaisesRegex(Refused, '^process launch failed$'):
                owner.launch(argv, self.temp.name, 0)
        result = owner.close()
        self.assertEqual(result['processes'][0]['error'], 'process launch failed')
        self.assertNotIn('secret detail', json.dumps(result))


if __name__ == '__main__':
    unittest.main()
