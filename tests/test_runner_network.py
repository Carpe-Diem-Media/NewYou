"""Refusal and other ambiguous socket failures cannot prove silent drop."""
import errno
import json
import socket
from unittest import TestCase
from unittest.mock import patch
from tools import runner_guest_network as network


class NetworkProofTest(TestCase):
    def test_explicit_outcomes(self):
        for error, expected in [(None, 'connected'), (ConnectionRefusedError(errno.ECONNREFUSED, 'SECRET'), 'refused'), (TimeoutError(), 'timeout'), (OSError(errno.ETIMEDOUT, 'SECRET'), 'timeout'), (OSError(errno.ENETUNREACH, 'SECRET'), 'route_denied'), (OSError(errno.EHOSTUNREACH, 'SECRET'), 'route_denied'), (PermissionError(errno.EACCES, 'SECRET'), 'permission_denied'), (OSError(errno.EIO, 'SECRET'), 'probe_error'), (RuntimeError('SECRET'), 'probe_error')]:
            with self.subTest(expected=expected), patch.object(network.socket, 'socket') as factory:
                factory.return_value.connect.side_effect = error
                self.assertEqual(network.connect_outcome('127.0.0.1', 1), expected)
                factory.return_value.close.assert_called_once()

    def test_real_closed_and_open_loopback_ports(self):
        with socket.socket() as server:
            server.bind(('127.0.0.1', 0))
            port = server.getsockname()[1]
            self.assertEqual(network.connect_outcome('127.0.0.1', port), 'refused')
            server.listen(1)
            self.assertEqual(network.connect_outcome('127.0.0.1', port), 'connected')

    def test_only_timeouts_complete_negative_observation(self):
        for outcome in network.OUTCOMES:
            with self.subTest(outcome=outcome), patch.object(network, 'connect_outcome', return_value=outcome):
                report = network.probe({'host': ['SECRET_ADDRESS']})
                self.assertEqual(report['status'], 'timeouts_only' if outcome == 'timeout' else 'failed')
                self.assertEqual(report['observations'], [{'target_class': 'host', 'outcome': outcome}])
                self.assertNotIn('SECRET_ADDRESS', json.dumps(report))

    def test_host_rejects_unbounded_or_unknown_diagnostics(self):
        from tools import disposable_runner as runner
        for report in [{'status': 'passed', 'observations': []}, {'status': 'failed', 'observations': [{'target_class': 'SECRET', 'outcome': 'timeout'}]}, {'status': 'failed', 'observations': [{'target_class': 'host', 'outcome': 'refused', 'address': 'SECRET'}]}]:
            with self.assertRaises(ValueError):
                runner.validate_network_report(report)

    def test_failed_outcome_is_retained_without_raw_output(self):
        import subprocess
        from pathlib import Path
        from tempfile import TemporaryDirectory
        from tools import disposable_runner as runner
        report = {'status': 'failed', 'observations': [{'target_class': 'metadata', 'outcome': 'refused'}]}
        with TemporaryDirectory() as directory, patch.object(runner, 'ROOT', Path(directory)), patch.object(runner, 'ssh', return_value=subprocess.CompletedProcess([], 0, json.dumps(report))):
            state = {'name': 'owned', 'phase': 'provisioning'}
            with self.assertRaisesRegex(RuntimeError, 'guest_preparation_failed:forbidden_connectivity'):
                runner.prepare(state, 'forbidden_connectivity', 'SECRET', 1, network_classes={'metadata'})
            self.assertEqual(state['network_diagnostics'], report)
            self.assertNotIn('SECRET', json.dumps(state))
            self.assertEqual(state['preparation'][-1]['status'], 'failed')

    def test_socket_setup_failure_cannot_be_classified_as_connect_timeout(self):
        with patch.object(network.socket, 'socket', side_effect=TimeoutError('SECRET')):
            self.assertEqual(network.connect_outcome('127.0.0.1', 1), 'probe_error')

    def test_invalid_or_incomplete_timeout_report_cannot_pass(self):
        from tools import disposable_runner as runner
        report = {'status': 'timeouts_only', 'observations': [{'target_class': 'host', 'outcome': 'timeout'}]}
        with self.assertRaises(ValueError):
            runner.validate_network_report(report, {'host', 'metadata'})
        report['observations'] *= 7
        with self.assertRaises(ValueError):
            runner.validate_network_report(report)
