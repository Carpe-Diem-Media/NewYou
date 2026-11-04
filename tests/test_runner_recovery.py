"""Unknown GitHub outcomes must never become successful cleanup by omission."""
import json
import os
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from tools import disposable_runner as runner


class LateRegistrationTest(unittest.TestCase):
    def test_empty_lookup_does_not_discharge_unknown_creation(self):
        state = {'name': 'newyou-w93-late12345678', 'uuid': 'test', 'phase': 'failed',
                 'registration_attempted': True, 'registration_outcome': 'unknown'}
        remote = []
        calls = []
        def github(path, method='GET', body=None):
            calls.append((path, method))
            if path.startswith('actions/runners?'):
                return {'runners': list(remote)}
            if path == 'actions/runners/41' and method == 'DELETE':
                remote.clear()
                return None
            raise AssertionError((path, method))
        def virsh(*args, **kw):
            if args == ('vol-list', runner.POOL):
                return SimpleNamespace(stdout='Name Path\n---\n')
            return SimpleNamespace(stdout='')
        with TemporaryDirectory() as directory, patch.object(runner, 'ROOT', Path(directory)), patch.object(runner, 'github', github), patch.object(runner, 'virsh', virsh):
            with self.assertRaisesRegex(RuntimeError, 'cleanup_incomplete:registration'):
                runner.cleanup(state)
            self.assertEqual(state['phase'], 'cleanup_failed')
            self.assertEqual(json.loads((Path(directory)/(state['name']+'.json')).read_text())['registration_outcome'], 'unknown')
            # The provider creates it only after the first empty reconciliation.
            remote.append({'id': 41, 'name': state['name']})
            runner.cleanup(state)
            self.assertEqual(state['phase'], 'cleaned')
            self.assertEqual(state['registration_outcome'], 'removed')
            self.assertIn(('actions/runners/41', 'DELETE'), calls)
            runner.cleanup(state)
            self.assertEqual(remote, [])

class ReconciliationStatusTest(unittest.TestCase):
    def test_acknowledged_runner_delete_is_idempotent_but_auth_failure_is_not_success(self):
        state = {'name': 'newyou-w93-known123456', 'runner_id': 7,
                 'registration_attempted': True, 'registration_outcome': 'acknowledged'}
        def provider(status):
            def github(path, method='GET', body=None):
                if method == 'DELETE':
                    raise runner.GitHubError(status)
                return {'runners': []}
            return github
        with TemporaryDirectory() as directory, patch.object(runner, 'ROOT', Path(directory)):
            with patch.object(runner, 'github', provider(403)):
                with self.assertRaises(runner.GitHubError):
                    runner.reconcile_registration(state)
                self.assertEqual(state['registration_outcome'], 'acknowledged')
            with patch.object(runner, 'github', provider(404)):
                runner.reconcile_registration(state)
                self.assertEqual(state['registration_outcome'], 'removed')

    def test_startup_cannot_provision_after_an_unsettled_create(self):
        state = {'name': 'newyou-w93-unknown12345', 'uuid': 'test', 'phase': 'failed',
                 'registration_attempted': True, 'registration_outcome': 'unknown'}
        def virsh(*args, **kw):
            return SimpleNamespace(stdout='Name Path\n---\n' if args[0]=='vol-list' else '')
        with TemporaryDirectory() as directory, patch.object(runner, 'ROOT', Path(directory)), patch.object(runner, 'github', return_value={'runners': []}), patch.object(runner, 'virsh', virsh), patch.object(runner, 'provision') as provision, patch.object(sys, 'argv', ['runner', 'probe']), patch.dict(os.environ, {'INVOCATION_ID': 'test'}):
            runner.save(state)
            with self.assertRaisesRegex(RuntimeError, 'cleanup_incomplete:registration'):
                runner.main()
            provision.assert_not_called()

class LostResponseDrillTest(unittest.TestCase):
    def test_drill_creates_once_drops_reply_and_hides_only_the_first_read(self):
        from tools.disposable_runner_drills import LostResponse
        calls = []
        def provider(path, method='GET', body=None):
            calls.append((path, method))
            if method == 'POST':
                return {'encoded_jit_config': 'NOT_FOR_RETENTION'}
            return {'runners': [{'id': 41, 'name': 'newyou-w93-test'}]}
        inject = LostResponse(provider)
        with self.assertRaisesRegex(RuntimeError, 'drill_lost_registration_response'):
            inject('actions/runners/generate-jitconfig', 'POST', {})
        self.assertEqual(inject('actions/runners?per_page=100&page=1'), {'runners': []})
        self.assertEqual(inject('actions/runners?per_page=100&page=1')['runners'][0]['id'], 41)
        self.assertEqual(sum(method == 'POST' for _,method in calls), 1)

class JobConclusionTest(unittest.TestCase):
    def test_cancelled_job_is_explicit_and_never_success(self):
        state = {'name': 'newyou-w93-cancel123456', 'phase': 'executing', 'runner_id': 8}
        with TemporaryDirectory() as directory, patch.object(runner, 'ROOT', Path(directory)):
            with self.assertRaisesRegex(RuntimeError, 'proving_job_cancelled'):
                runner.record_job_result(state, {'conclusion': 'cancelled'}, [{'id': 1, 'runner_id': 8, 'runner_name': state['name'], 'conclusion': 'cancelled'}])
            self.assertEqual(state['result'], 'cancelled')
            self.assertEqual(state['phase'], 'cancelled')
            self.assertTrue(state['job_identity_verified'])

class CancellationRaceTest(unittest.TestCase):
    def test_conflict_is_only_accepted_after_completed_run_is_observed(self):
        responses = iter([{'status': 'in_progress'}, {'status': 'completed'}])
        def provider(path, method='GET', body=None):
            if method == 'POST':
                raise runner.GitHubError(409)
            return next(responses)
        with patch.object(runner, 'github', provider):
            runner.cancel_owned_run({'run_id': 4, 'result': 'unknown'})


if __name__ == '__main__':
    unittest.main()
