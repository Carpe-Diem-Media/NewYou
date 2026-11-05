"""Preparation failures retain a fixed stage, never guest-controlled text."""
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase
from unittest.mock import patch
from tools import disposable_runner as runner


class PreparationTest(TestCase):
    def test_failure_preserves_stage_without_sensitive_error_text(self):
        with TemporaryDirectory() as directory, patch.object(runner, 'ROOT', Path(directory)), patch.object(runner, 'ssh', side_effect=RuntimeError('SECRET_RAW_GUEST_TEXT')):
            state = {'name': 'newyou-w93-preparation', 'phase': 'provisioning'}
            with self.assertRaisesRegex(RuntimeError, 'guest_preparation_failed:reboot_guard'):
                runner.prepare(state, 'reboot_guard', 'test command', 10)
            self.assertEqual(state['preparation'][-1]['status'], 'failed')
            self.assertNotIn('SECRET_RAW_GUEST_TEXT', json.dumps(state))
            self.assertNotIn('test command', json.dumps(state))

    def test_unknown_stage_cannot_reach_guest_or_journal(self):
        with patch.object(runner, 'ssh') as ssh:
            with self.assertRaisesRegex(RuntimeError, 'unknown_preparation_stage'):
                runner.prepare({}, 'UNTRUSTED', 'x', 10)
            ssh.assert_not_called()

    def test_success_uses_bounded_transport_and_records_passed(self):
        with TemporaryDirectory() as directory, patch.object(runner, 'ROOT', Path(directory)), patch.object(runner, 'ssh') as ssh:
            state = {'name': 'newyou-w93-preparation', 'phase': 'provisioning'}
            runner.prepare(state, 'apt_update', 'x', 30)
            ssh.assert_called_once_with(state, 'x', timeout=30, max_output=4096)
            self.assertEqual(state['preparation'][-1]['status'], 'passed')

    def test_reboot_guard_failure_blocks_later_isolation_work(self):
        with TemporaryDirectory() as directory, patch.object(runner, 'ROOT', Path(directory)), patch.object(runner, 'ssh', side_effect=[None, None, None, RuntimeError('reboot pending')]), patch.object(runner, 'virsh') as virsh:
            state = {'name': 'newyou-w93-preparation', 'phase': 'provisioning'}
            with self.assertRaisesRegex(RuntimeError, 'guest_preparation_failed:reboot_guard'):
                runner.isolate(state)
            virsh.assert_not_called()
            self.assertEqual(state['phase'], 'provisioning')
            self.assertEqual([x['status'] for x in state['preparation']], ['passed', 'passed', 'passed', 'failed'])
