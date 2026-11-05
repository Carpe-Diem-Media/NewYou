"""Security boundary tests. Fixtures model the pinned Hex SARIF contract."""
import copy
import datetime as dt
import json
import shutil
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools import hex_security_audit as audit

ROOT = Path(__file__).resolve().parents[1]
DATETIME = dt.datetime


def report(package='assent', version='0.2.13', advisory='EEF-CVE-2026-117656'):
    return {'version': '2.1.0', 'runs': [{'tool': {'driver': {
        'name': 'mix hex.audit', 'version': '2.6.0', 'rules': [{'id': advisory, 'shortDescription': {'text': audit.APPROVED_SUMMARY}, 'helpUri': audit.APPROVED_URL, 'properties': {'tags': ['security'], 'security-severity': '9.5'}}]}},
        'results': [{'ruleId': advisory, 'ruleIndex': 0,
                     'message': {'arguments': [package, version, advisory + ' (aka ' + ', '.join(sorted(audit.IDS - {advisory})) + ')', audit.APPROVED_SUMMARY, audit.APPROVED_URL]},
                     'partialFingerprints': {'hexAudit/v1': f'advisory:hexpm/{package}:{advisory}'}}]}]}


class AuditEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.exception = json.loads((ROOT / 'tools/hex_audit/assent_exception.json').read_text())
        self.today = dt.date(2026, 11, 4)
        clock_patch = patch.object(audit.dt, 'datetime', wraps=DATETIME)
        self.clock = clock_patch.start()
        self.addCleanup(clock_patch.stop)
        self.clock.now.return_value = DATETIME(2026, 11, 4, tzinfo=dt.timezone.utc)

    def decide(self, evidence=None, status=1, exception=None, today=None):
        self.clock.now.return_value = DATETIME.combine(today or self.today, dt.time(), dt.timezone.utc)
        return audit.disposition(report() if evidence is None else evidence, status,
                                 self.exception if exception is None else exception, ROOT)

    def test_exact_approved_finding_is_controlled_not_clean(self):
        self.assertIn('CONTROLLED DISPOSITION', self.decide())

    def test_owner_reauthorization_is_bound_to_exact_inputs(self):
        self.assertEqual(audit.APPROVAL, 'f1705f90-2e2f-48e5-8df0-e3e1e4b2321f')
        self.assertEqual(audit.APPROVED_INPUT_DIGEST,
                         'b080e9cfcfa6c73e7d8cfd54ede395c13447fca45a904d0bd575661a245d1718')
        self.assertEqual(audit.input_digest(ROOT), audit.APPROVED_INPUT_DIGEST)
        self.assertEqual(self.exception['approval_comment'],
                         'f1705f90-2e2f-48e5-8df0-e3e1e4b2321f')
        self.assertEqual(self.exception['input_digest'],
                         'b080e9cfcfa6c73e7d8cfd54ede395c13447fca45a904d0bd575661a245d1718')
        self.assertEqual(self.exception['owner'], 'JC')
        self.assertEqual(self.exception['package'], 'assent')
        self.assertEqual(self.exception['version'], '0.2.13')
        self.assertEqual(self.exception['expires_on'], '2026-11-18')

    def test_superseded_approval_and_binding_are_rejected(self):
        for field, value in [
                ('approval_comment', '2804a409-64f4-4571-8df3-0da8c37da9ca'),
                ('input_digest', '09dd14cb9d31fc9441767f8219224f9474e09eb6721291285d1e40dec16424a9'),
                ('approval_comment', 'b8ac8764-c2c8-4dd9-b13e-802039e34790'),
                ('input_digest', '59114f8ee39c86dc3642e992e1119e747cf85c9d4465a2ca54875d4a4253836b')]:
            exception = dict(self.exception, **{field: value})
            with self.subTest(field=field), self.assertRaisesRegex(audit.AuditError, 'Unauthorised'):
                self.decide(exception=exception)

    def test_old_baseline_inputs_cannot_use_new_approval(self):
        with patch.object(audit, 'input_digest', return_value=
                          '09dd14cb9d31fc9441767f8219224f9474e09eb6721291285d1e40dec16424a9'):
            with self.assertRaisesRegex(audit.AuditError, 'invalidated'):
                self.decide()

    def test_real_changed_inputs_invalidate_reauthorized_disposition(self):
        for changed in ['mix.lock', 'mix.exs', '.tool-versions', 'lib/new_callback.ex',
                        'config/new_oauth.exs',
                        'test/new_you_web/security/authentication_reachability_test.exs']:
            with self.subTest(changed=changed), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                for name in ['mix.exs', 'mix.lock', '.tool-versions',
                             'test/new_you_web/security/authentication_reachability_test.exs']:
                    target = root / name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(ROOT / name, target)
                for name in ['lib', 'config']:
                    shutil.copytree(ROOT / name, root / name)
                self.assertEqual(audit.input_digest(root), audit.APPROVED_INPUT_DIGEST)
                target = root / changed
                target.write_bytes((target.read_bytes() if target.exists() else b'') + b'\n# changed\n')
                with self.assertRaisesRegex(audit.AuditError, 'invalidated'):
                    audit.disposition(report(), 1, self.exception, root)

    def test_unexpected_second_finding_fails(self):
        evidence = report()
        other = report('other', '1.0', 'CVE-2026-9999')
        evidence['runs'][0]['tool']['driver']['rules'] += other['runs'][0]['tool']['driver']['rules']
        other['runs'][0]['results'][0]['ruleIndex'] = 1
        evidence['runs'][0]['results'] += other['runs'][0]['results']
        with self.assertRaisesRegex(audit.AuditError, 'Unexpected'):
            self.decide(evidence)

    def test_wrong_package_version_and_alias_fail(self):
        for evidence in [report('other'), report(version='0.2.12'), report(advisory='CVE-2026-9999')]:
            with self.subTest(evidence=evidence), self.assertRaises(audit.AuditError):
                self.decide(evidence)

    def test_known_primary_aliases_match(self):
        for alias in ['EEF-CVE-2026-117656', 'CVE-2026-117656', 'GHSA-9fr5-g44g-9526']:
            self.assertIn('CONTROLLED', self.decide(report(advisory=alias)))

    def test_unmatched_exception_and_clean_without_exception(self):
        evidence = report()
        evidence['runs'][0]['results'] = []
        evidence['runs'][0]['tool']['driver']['rules'] = []
        with self.assertRaisesRegex(audit.AuditError, 'unmatched'):
            self.decide(evidence, 0)
        self.assertIn('CLEAN', self.decide(evidence, 0, {}))

    def test_expiry_is_exclusive_at_start_of_deadline(self):
        self.assertIn('CONTROLLED', self.decide(today=dt.date(2026, 11, 17)))
        for day in [18, 19, 30]:
            with self.assertRaisesRegex(audit.AuditError, 'expired'):
                self.decide(today=dt.date(2026, 11, day))

    def test_lifecycle_and_unauthorised_metadata_fail(self):
        for field, value in [('state', 'proposed'), ('state', 'invalidated'), ('state', 'resolved'),
                             ('state', 'superseded'), ('expires_on', '2026-11-19'),
                             ('owner', 'someone'), ('approval_comment', 'fabricated')]:
            exception = copy.deepcopy(self.exception)
            exception[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(audit.AuditError):
                self.decide(exception=exception)

    def test_status_and_malformed_evidence_fail(self):
        for evidence, status in [(report(), 0), (report(), 2), ({}, 1),
                                 ({'version': '2.1.0', 'runs': []}, 0)]:
            with self.subTest(status=status), self.assertRaises(audit.AuditError):
                self.decide(evidence, status)

    def test_negative_boolean_and_noninteger_rule_indexes_fail(self):
        for index in [-1, True, '0', 1]:
            evidence = report()
            evidence['runs'][0]['results'][0]['ruleIndex'] = index
            with self.subTest(index=index), self.assertRaises(audit.AuditError):
                self.decide(evidence)

    def test_changed_severity_or_missing_alias_is_invalid(self):
        for field in ['severity', 'alias']:
            evidence = report()
            if field == 'severity':
                evidence['runs'][0]['tool']['driver']['rules'][0]['properties']['security-severity'] = '10.0'
            else:
                evidence['runs'][0]['results'][0]['message']['arguments'][2] = 'EEF-CVE-2026-117656'
            with self.subTest(field=field), self.assertRaises(audit.AuditError):
                self.decide(evidence)

    def test_changed_advisory_details_invalidate(self):
        evidence = report()
        evidence['runs'][0]['results'][0]['message']['arguments'][3] = 'new exploit details'
        with self.assertRaisesRegex(audit.AuditError, 'changed'):
            self.decide(evidence)

    def test_supported_assent_backport_requires_revalidation(self):
        with patch.object(audit, 'latest_authentication_release', return_value='4.15.1'), patch.object(audit, 'latest_supported_assent_release', return_value='0.2.14'):
            with self.assertRaisesRegex(audit.AuditError, 'revalidation'):
                audit.execute(ROOT)

    def test_retirement_cannot_use_advisory_exception(self):
        evidence = report(advisory='HEX0003')
        evidence['runs'][0]['results'][0]['partialFingerprints']['hexAudit/v1'] = 'retired:hexpm/assent'
        with self.assertRaises(audit.AuditError):
            self.decide(evidence)

    def test_new_stable_auth_release_requires_revalidation(self):
        with patch.object(audit, 'latest_authentication_release', return_value='4.15.2'):
            with self.assertRaisesRegex(audit.AuditError, 'revalidation'):
                audit.execute(ROOT)

    def test_real_new_production_file_changes_digest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ['mix.exs', 'mix.lock', '.tool-versions',
                         'test/new_you_web/security/authentication_reachability_test.exs']:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / name).read_bytes())
            before = audit.input_digest(root)
            (root / 'lib').mkdir()
            (root / 'lib/new_apple_callback.ex').write_text('new caller')
            self.assertNotEqual(before, audit.input_digest(root))

    def test_changed_dependency_graph_or_new_caller_invalidates(self):
        with patch.object(audit, 'input_digest', return_value='changed'):
            with self.assertRaisesRegex(audit.AuditError, 'invalidated'):
                self.decide()

    def test_runner_must_execute_audit_in_fresh_home_before_disposition(self):
        calls = []
        def run(command, **kwargs):
            calls.append((command, kwargs))
            if 'hex.audit' in command:
                (Path(kwargs['cwd']) / 'audit.sarif').write_text(json.dumps(report()))
                return type('Result', (), {'returncode': 1})()
            return type('Result', (), {'returncode': 0})()
        with patch.object(audit, 'latest_supported_assent_release', return_value='0.2.13'), patch.object(audit, 'latest_authentication_release', return_value='4.15.1'), patch.object(audit.subprocess, 'run', side_effect=run):
            self.assertIn('CONTROLLED', audit.execute(ROOT))
        self.assertEqual([c[0][1] for c in calls], ['local.hex', 'deps.get', 'hex.audit'])
        self.assertIn('--check-locked', calls[1][0])
        self.assertTrue(all(c[1]['cwd'] != ROOT for c in calls))
        self.assertTrue(all(c[1]['env']['HEX_HOME'] != str(Path.home() / '.hex') for c in calls))
        self.assertNotIn('HEX_IGNORE_ADVISORIES', calls[-1][1]['env'])

    def test_missing_report_cannot_be_fabricated_clean(self):
        with patch.object(audit, 'latest_supported_assent_release', return_value='0.2.13'), patch.object(audit, 'latest_authentication_release', return_value='4.15.1'), patch.object(audit.subprocess, 'run', return_value=type('Result', (), {'returncode': 0})()):
            with self.assertRaises(audit.AuditError):
                audit.execute(ROOT)

    def test_advisory_service_failure_or_malformed_report_fails(self):
        for payload in [None, 'not JSON']:
            def run(command, **kwargs):
                if 'hex.audit' in command and payload is not None:
                    (Path(kwargs['cwd']) / 'audit.sarif').write_text(payload)
                return type('Result', (), {'returncode': 1 if 'hex.audit' in command else 0})()
            with patch.object(audit, 'latest_supported_assent_release', return_value='0.2.13'), patch.object(audit, 'latest_authentication_release', return_value='4.15.1'), patch.object(audit.subprocess, 'run', side_effect=run):
                with self.subTest(payload=payload), self.assertRaises((audit.AuditError, ValueError)):
                    audit.execute(ROOT)

    def test_run_crossing_expiry_fails_at_final_decision(self):
        started = dt.datetime(2026, 11, 17, 23, 59, 58, tzinfo=dt.timezone.utc)
        for finished in [dt.datetime(2026, 11, 18, tzinfo=dt.timezone.utc),
                         dt.datetime(2026, 11, 18, 0, 0, 10, tzinfo=dt.timezone.utc)]:
            clock = [started]
            class Clock(DATETIME):
                @classmethod
                def now(cls, tz=None):
                    self.assertEqual(tz, dt.timezone.utc)
                    return clock[0]
            def run(command, **kwargs):
                if 'hex.audit' in command:
                    (Path(kwargs['cwd']) / 'audit.sarif').write_text(json.dumps(report()))
                    clock[0] = finished
                return type('Result', (), {'returncode': 1 if 'hex.audit' in command else 0})()
            with self.subTest(finished=finished), patch.object(audit.dt, 'datetime', Clock), \
                    patch.object(audit, 'latest_supported_assent_release', return_value='0.2.13'), \
                    patch.object(audit, 'latest_authentication_release', return_value='4.15.1'), \
                    patch.object(audit.subprocess, 'run', side_effect=run), \
                    patch('builtins.print') as output:
                self.assertEqual(audit.main(), 1)
                self.assertTrue(any('expired' in str(call) for call in output.call_args_list))
                self.assertFalse(any('CONTROLLED DISPOSITION' in str(call) for call in output.call_args_list))

    def test_network_failure_is_visible(self):
        with patch.object(audit, 'latest_supported_assent_release', return_value='0.2.13'), patch.object(audit, 'latest_authentication_release', return_value='4.15.1'), patch.object(audit.subprocess, 'run', return_value=type('Result', (), {'returncode': 1})()):
            with self.assertRaisesRegex(audit.AuditError, 'failed'):
                audit.execute(ROOT)

class AuditRoutingTests(unittest.TestCase):
    def test_sensitive_inputs_and_bypass_attempts_select_audit(self):
        from tools.foundation_integrity_routing import classify_hex_audit_changes
        for path in ['mix.exs', 'mix.lock', '.tool-versions', 'lib/new_caller.ex',
                     'config/runtime.exs', 'tools/hex_security_audit.py',
                     'tools/hex_audit/assent_exception.json', '.github/workflows/hex-security-audit.yml',
                     '.github/workflows/foundation-integrity.yml', 'tools/foundation_integrity_routing.py',
                     'tests/test_hex_security_audit.py', 'tests/test_foundation_merge_gate.py']:
            with self.subTest(path=path):
                self.assertTrue(classify_hex_audit_changes([path]))
        self.assertFalse(classify_hex_audit_changes(['docs/development/ordinary.md']))
        self.assertTrue(classify_hex_audit_changes([]))

    def test_nightly_main_and_required_aggregate(self):
        workflow = (ROOT / '.github/workflows/hex-security-audit.yml').read_text()
        self.assertIn('  schedule:', workflow)
        self.assertIn("github.ref == 'refs/heads/main'", workflow)
        self.assertIn("github.event_name == 'schedule' && 'main' || github.sha", workflow)
        self.assertIn('python3 tools/hex_security_audit.py', workflow)
        self.assertNotIn('actions/cache', workflow)
        self.assertNotIn('continue-on-error', workflow)
        integrity = (ROOT / '.github/workflows/foundation-integrity.yml').read_text()
        self.assertIn('needs: [route, foundation-smoke, application-ci, hex-security-audit]', integrity)
        self.assertIn('AUDIT_RESULT: ${{ needs.hex-security-audit.result }}', integrity)
        self.assertIn('AUDIT_REQUIRED: ${{ needs.route.outputs.hex_audit_changes }}', integrity)


class AggregateExecutionTests(unittest.TestCase):
    def test_required_gate_executes_fail_closed_for_audit_outcomes(self):
        import os
        import subprocess
        workflow = (ROOT / '.github/workflows/foundation-integrity.yml').read_text()
        block = workflow.split('  foundation-integrity:\n', 1)[1].split('        run: |\n', 1)[1]
        script = '\n'.join(line[10:] for line in block.splitlines())
        for required, result, success in [('true', 'success', True), ('true', 'failure', False),
                ('true', 'skipped', False), ('true', 'cancelled', False), ('false', 'skipped', True),
                ('false', 'success', False), ('', 'success', False), ('garbage', 'success', False)]:
            env = dict(os.environ, ROUTE_RESULT='success', SMOKE_RESULT='success', APP_REQUIRED='false',
                       APP_RESULT='skipped', AUDIT_REQUIRED=required, AUDIT_RESULT=result)
            actual = subprocess.run(['bash', '-c', script], env=env, capture_output=True)
            with self.subTest(required=required, result=result):
                self.assertEqual(actual.returncode == 0, success, actual.stdout)


if __name__ == '__main__':
    unittest.main()
