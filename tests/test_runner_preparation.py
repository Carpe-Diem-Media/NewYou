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

    def test_ssh_exit_categories_and_timeout_are_sanitized(self):
        import subprocess
        for code, category in [(255, 'ssh_transport'), (1, 'guest_command'), (127, 'guest_command')]:
            with self.subTest(code=code), patch.object(runner, 'command', return_value=subprocess.CompletedProcess([], code, 'SECRET', 'SECRET')):
                with self.assertRaises(runner.SSHFailure) as caught:
                    runner.ssh({'name': 'owned'}, 'SECRET')
                self.assertEqual(caught.exception.category, category)
                self.assertNotIn('SECRET', str(caught.exception))
        with patch.object(runner, 'command', side_effect=subprocess.TimeoutExpired('SECRET', 1, output='SECRET')):
            with self.assertRaises(runner.SSHFailure) as caught:
                runner.ssh({'name': 'owned'}, 'SECRET')
            self.assertEqual(caught.exception.category, 'timeout')

    def test_each_isolation_failure_blocks_transition_and_retains_only_category(self):
        import subprocess
        stages = ['guest_privilege', 'guest_socket', 'guest_credentials', 'forbidden_connectivity', 'public_https']
        xml = '<domain><devices><interface><filterref filter="owned"/></interface></devices></domain>'
        for index, stage in enumerate(stages):
            with self.subTest(stage=stage), TemporaryDirectory() as directory, patch.object(runner, 'ROOT', Path(directory)), patch.object(runner, 'virsh', return_value=subprocess.CompletedProcess([], 0, xml)), patch.object(runner, 'addresses', return_value=['192.168.123.234']), patch.object(runner, 'ssh', side_effect=[None] * (4 + index) + [runner.SSHFailure('guest_command')]):
                state = {'name': 'owned', 'phase': 'provisioning'}
                with self.assertRaises(RuntimeError):
                    runner.isolate(state)
                self.assertEqual(state['phase'], 'provisioning')
                self.assertEqual(state['preparation'][-1]['stage'], stage)
                self.assertEqual(state['preparation'][-1]['failure'], 'guest_command')
                self.assertNotIn('isolation', state)
                self.assertNotIn('192.168.123.234', json.dumps(state))

    def test_all_isolation_categories_must_pass(self):
        import subprocess
        xml = '<domain><devices><interface><filterref filter="owned"/></interface></devices></domain>'
        with TemporaryDirectory() as directory, patch.object(runner, 'ROOT', Path(directory)), patch.object(runner, 'virsh', return_value=subprocess.CompletedProcess([], 0, xml)), patch.object(runner, 'addresses', return_value=['192.168.123.234']), patch.object(runner, 'ssh'):
            state = {'name': 'owned', 'phase': 'provisioning'}
            runner.isolate(state)
            self.assertEqual(state['phase'], 'isolated')
            self.assertEqual(len(state['preparation']), 9)
            self.assertTrue(all(x['status'] == 'passed' for x in state['preparation']))
            self.assertNotIn('192.168.123.234', json.dumps(state))

    def test_bounded_transport_preserves_exit_code_and_enforces_output_and_deadline(self):
        import subprocess
        import sys
        result = runner.bounded_command([sys.executable, '-c', 'raise SystemExit(255)'], check=False)
        self.assertEqual(result.returncode, 255)
        with self.assertRaisesRegex(RuntimeError, 'output_limit'):
            runner.bounded_command([sys.executable, '-c', 'print("x"*5000)'], max_output=16)
        with self.assertRaises(subprocess.TimeoutExpired) as caught:
            runner.bounded_command([sys.executable, '-c', 'import time; time.sleep(5)'], timeout=.05)
        self.assertIsNone(caught.exception.output)

    def test_preparation_categories_are_bounded_and_do_not_retain_output(self):
        for category in ['ssh_transport', 'timeout', 'guest_command', 'output_limit', 'unknown']:
            with self.subTest(category=category), TemporaryDirectory() as directory, patch.object(runner, 'ROOT', Path(directory)), patch.object(runner, 'ssh', side_effect=runner.SSHFailure(category)):
                state = {'name': 'owned', 'phase': 'provisioning'}
                for _ in range(12):
                    with self.assertRaises(RuntimeError):
                        runner.prepare(state, 'public_https', 'SECRET', 1)
                self.assertEqual(len(state['preparation']), 1)
                self.assertEqual(state['preparation'][0]['failure'], category)
                self.assertNotIn('SECRET', json.dumps(state))
        self.assertEqual(runner.SSHFailure('SECRET').category, 'unknown')

    def test_remote_exit_255_is_normalized_before_ssh(self):
        import subprocess
        def local_remote(args, **kwargs):
            self.assertIn('bash -s;', args[-1])
            result = subprocess.run(['bash', '-c', args[-1]], input=kwargs['data'], text=True, capture_output=True)
            self.assertEqual(result.returncode, 1)
            return result
        with patch.object(runner, 'command', side_effect=local_remote):
            with self.assertRaises(runner.SSHFailure) as caught:
                runner.ssh({'name': 'owned'}, 'exit 255')
            self.assertEqual(caught.exception.category, 'guest_command')

    def test_explicit_sudo_grant_fails_privilege_probe(self):
        import subprocess
        scripts = {}
        def capture(state, stage, script, timeout):
            scripts[stage] = script
            if stage == 'guest_privilege':
                raise RuntimeError('stop')
        xml = '<domain><devices><interface><filterref filter="owned"/></interface></devices></domain>'
        with patch.object(runner, 'prepare', side_effect=capture), patch.object(runner, 'addresses', return_value=[]), patch.object(runner, 'virsh', return_value=subprocess.CompletedProcess([], 0, xml)):
            with self.assertRaises(RuntimeError):
                runner.isolate({'name': 'owned'})
        with TemporaryDirectory() as directory:
            root = Path(directory)
            for name, script in {'id': 'if [ "$1" = -u ]; then echo 1000; else echo runner; fi', 'sudo': 'exit 0', 'visudo': 'exit 0'}.items():
                path = root / name
                path.write_text('#!/bin/sh\n' + script + '\n')
                path.chmod(0o700)
            result = subprocess.run(['bash', '-c', scripts['guest_privilege']], env={'PATH': directory + ':/usr/bin:/bin'}, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            (root / 'sudo').write_text('#!/bin/sh\nexit 1\n')
            result = subprocess.run(['bash', '-c', scripts['guest_privilege']], env={'PATH': directory + ':/usr/bin:/bin'}, capture_output=True)
            self.assertEqual(result.returncode, 0)
            (root / 'visudo').write_text('#!/bin/sh\nexit 1\n')
            result = subprocess.run(['bash', '-c', scripts['guest_privilege']], env={'PATH': directory + ':/usr/bin:/bin'}, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
