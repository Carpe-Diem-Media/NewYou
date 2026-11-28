import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from tools import disposable_runner as runner
from tools import runner_diagnostics as diagnostics


class DiagnosticTest(unittest.TestCase):
    def test_messages_secrets_paths_and_unknown_components_are_dropped(self):
        raw = ('[2026-11-04 14:00:00Z INFO Runner] token=NEVER_RETAIN_ME job secret\n'
               '[2026-11-04 14:00:01Z ERR JobRunner] System.TimeoutException password=NEVER_RETAIN_ME\n'
               '[2026-11-04 14:00:02Z INFO NEVER_RETAIN_ME] /home/private/file\n')
        result = diagnostics.summarize_text(raw)
        encoded = json.dumps(result)
        self.assertNotIn('NEVER_RETAIN_ME', encoded)
        self.assertNotIn('/home/private', encoded)
        self.assertEqual(result['levels']['ERR'], 1)
        self.assertEqual(result['errors']['System.TimeoutException'], 1)
        self.assertEqual(result['components']['Runner'], 1)

    def test_snapshot_rejects_free_text_and_out_of_bounds_counts(self):
        result = diagnostics.summarize_text('')
        diagnostics.validate_snapshot(result)
        with self.assertRaises(ValueError):
            diagnostics.validate_snapshot({**result, 'message': 'secret'})
        with self.assertRaises(ValueError):
            diagnostics.validate_snapshot({**result, 'lines': 1000000000})

    def test_collector_refuses_symlink_logs(self):
        with TemporaryDirectory() as root:
            p = Path(root)
            (p/'private').write_text('SECRET_PRIVATE_FILE')
            (p/'Runner_20261104.log').symlink_to(p/'private')
            result = diagnostics.collect(p)
            self.assertEqual(result['files'], 0)
            self.assertNotIn('SECRET_PRIVATE_FILE', json.dumps(result))

    def test_oversized_guest_output_is_killed_without_retention(self):
        with self.assertRaisesRegex(RuntimeError, 'output_limit'):
            runner.command([sys.executable, '-c', 'print("x"*100000)'], max_output=1024)

class DiagnosticFailureTest(unittest.TestCase):
    def test_symlinked_diagnostic_directory_is_not_traversed(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'private').mkdir()
            (root/'private'/'Runner_20261104.log').write_text('[2026-11-04 INFO Runner] secret\n')
            (root/'_diag').symlink_to(root/'private', target_is_directory=True)
            self.assertEqual(diagnostics.collect(root/'_diag')['files'], 0)

    def test_diagnostic_or_journal_write_failure_cannot_skip_resource_cleanup(self):
        from types import SimpleNamespace
        from unittest.mock import patch
        def run_failure(journal_failure):
            state = {'name': 'newyou-w93-writefailure', 'phase': 'executing', 'uuid': 'owned', 'diagnostics_installed': True}
            calls = []
            present = [True]
            def virsh(*args, **kw):
                calls.append(args[0])
                if args[0] == 'list': return SimpleNamespace(stdout=state['name'] if present[0] else '')
                if args[0] == 'dumpxml': return SimpleNamespace(stdout='<domain><uuid>owned</uuid></domain>')
                if args[0] == 'domstate': return SimpleNamespace(stdout='running')
                if args[0] == 'undefine': present[0] = False
                return SimpleNamespace(stdout='Name Path\n---\n' if args[0]=='vol-list' else '')
            with TemporaryDirectory() as root, patch.object(runner, 'ROOT', Path(root)), patch.object(runner, 'virsh', virsh), patch.object(runner, 'export_diagnostics', side_effect=OSError('full')):
                if journal_failure:
                    with patch.object(runner, 'save', side_effect=OSError('full')):
                        with self.assertRaises(RuntimeError): runner.cleanup(state)
                else:
                    runner.cleanup(state)
                    self.assertEqual(state['diagnostics']['status'], 'unavailable')
                self.assertIn('destroy', calls)
                self.assertIn('undefine', calls)
        run_failure(False)
        run_failure(True)


if __name__ == '__main__':
    unittest.main()
