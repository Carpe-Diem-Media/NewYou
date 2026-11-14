"""Application trials cannot silently broaden the harmless proving route."""
import unittest
from tools import disposable_runner as runner


class ApplicationPolicyTest(unittest.TestCase):
    def test_application_requires_distinct_route_and_long_bounded_deadline(self):
        policy = runner.execution_policy('application')
        self.assertEqual(policy['workflow'], '.github/workflows/disposable-runner-application.yml')
        self.assertNotEqual(policy['label'], runner.LABEL)
        self.assertEqual(policy['job_seconds'], 3600)
        self.assertEqual(policy['memory'], 4096)

    def test_unknown_profile_fails_closed(self):
        with self.assertRaisesRegex(RuntimeError, 'unknown_execution_profile'):
            runner.execution_policy('production')

    def test_application_supervisor_keeps_independent_cleanup_and_deadline(self):
        args = runner.supervisor_command(['prove', '--profile', 'application'])
        self.assertIn('--property=RuntimeMaxSec=4800', args)
        self.assertTrue(any(a.startswith('--property=ExecStopPost=') for a in args))


    def test_application_cannot_run_the_harmless_workflow(self):
        from unittest.mock import patch
        run = dict(head_sha='a' * 40, event='push', head_branch='well-93-proving-run', path='.github/workflows/disposable-runner-proof.yml', status='queued')
        with patch.object(runner, 'github', return_value=run), patch.object(runner, 'ssh') as ssh:
            with self.assertRaisesRegex(RuntimeError, 'unapproved_proving_run'):
                runner.execute({'phase': 'isolated', 'profile': 'application'}, 1, 'a' * 40)
            ssh.assert_not_called()

    def test_application_rejects_another_branch_even_with_the_right_workflow(self):
        from unittest.mock import patch
        run = dict(head_sha='a' * 40, event='push', head_branch='well-93-unapproved', path='.github/workflows/disposable-runner-application.yml', status='queued')
        with patch.object(runner, 'github', side_effect=[run, AssertionError('must reject before provider setup')]), patch.object(runner, 'save'), patch.object(runner, 'ssh') as ssh:
            with self.assertRaisesRegex(RuntimeError, 'unapproved_proving_run'):
                runner.execute({'phase': 'isolated', 'profile': 'application'}, 1, 'a' * 40)
            ssh.assert_not_called()
