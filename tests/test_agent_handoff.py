"""Deterministic handoff proofs. No network, OCR subscription, or database calls."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / '.agents/skills/code-change-verification/scripts/handoff.py'
SPEC = importlib.util.spec_from_file_location('agent_handoff', SCRIPT) if SCRIPT.exists() else None
if SPEC:
    gate = importlib.util.module_from_spec(SPEC)
    SPEC.loader.exec_module(gate)
else:
    gate = None

HEAD, BASE, MERGE = 'a' * 40, 'b' * 40, 'c' * 40
BINDING = dict(head=HEAD, base=BASE, merge_base=MERGE, tree='d' * 40)
PR = dict(number=232, state='open', html_url='https://github.com/Carpe-Diem-Media/NewYou/pull/232',
          head=dict(sha=HEAD, ref='feature/well-17-primary-email-change', repo=dict(full_name='Carpe-Diem-Media/NewYou')),
          base=dict(sha=BASE, ref='main', repo=dict(full_name='Carpe-Diem-Media/NewYou')))
PREVIEW = dict(files=[dict(path='.agents/skills/code-change-verification/scripts/handoff.py', will_review=True),
                      dict(path='assets/page.heex', will_review=False, exclude_reason='unsupported_ext')],
               total_files=2, reviewable_count=1, excluded_count=1)


def result():
    item = dict(item_id='file-1', path='.agents/skills/code-change-verification/scripts/handoff.py', fingerprint='digest')
    return dict(status='complete', session_id='session-1', comments=[],
                summary=dict(files_reviewed=1, comments=0, total_tokens=1200),
                tool_calls=dict(failure=0),
                manifest=dict(schema_version='ocr.run-manifest/v1', operation='review',
                              run_id='session-1', terminal_state='complete',
                              input=dict(mode='range', resolved_base=MERGE, resolved_head=HEAD,
                                         exact_range=f'{MERGE}..{HEAD}'),
                              execution=dict(provider='chatgpt', model='configured-model', configured_concurrency=1),
                              coverage=dict(selected=[item], completed=[copy.deepcopy(item)], reused=[], failed=[], waived=[],
                                            excluded=[dict(item_id='file-2', path='assets/page.heex', exclude_reason='unsupported_ext')])))


class HandoffTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(gate, 'the local handoff gate is not implemented')

    def test_green_manifest_and_explicit_exclusions(self):
        summary = gate.validate_ocr(result(), PREVIEW, BINDING, 100000)
        self.assertEqual(summary['session'], 'session-1')
        self.assertEqual(summary['excluded'][0]['path'], 'assets/page.heex')

    def test_incomplete_zero_exit_and_unknown_coverage_fail_closed(self):
        mutations = [
            lambda r: r.update(status='partial'), lambda r: r.update(status='cancelled'),
            lambda r: r.update(warnings=[dict(type='review_limit_reached')]),
            lambda r: r['summary'].update(budget_exceeded=True),
            lambda r: r['summary'].update(total_tokens=100000),
            lambda r: r['manifest'].update(schema_version='future'),
            lambda r: r['manifest']['input'].update(resolved_head=BASE),
            lambda r: r['manifest']['input'].update(resolved_base=BASE),
            lambda r: r['manifest']['input'].update(exact_range='origin/main..HEAD'),
            lambda r: r['manifest']['coverage'].update(completed=[]),
            lambda r: r['manifest']['coverage'].update(failed=[dict(classification='budget')]),
            lambda r: r['manifest']['coverage'].update(waived=[dict(path='.agents/skills/code-change-verification/scripts/handoff.py')]),
            lambda r: r['manifest']['coverage'].update(reused=[dict(path='.agents/skills/code-change-verification/scripts/handoff.py')]),
            lambda r: r['manifest']['coverage'].update(excluded=[]),
            lambda r: r['manifest']['coverage']['completed'][0].update(fingerprint='changed'),
            lambda r: r['manifest'].update(run_failure=dict(classification='cancelled')),
            lambda r: r['tool_calls'].update(failure=1),
            lambda r: r['manifest']['execution'].update(provider='openai'),
            lambda r: r['manifest']['execution'].update(configured_concurrency=8),
            lambda r: r.pop('manifest'), lambda r: r.update(comments=None),
            lambda r: r['summary'].update(files_reviewed=0),
        ]
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                r = result()
                mutate(r)
                with self.assertRaises(gate.GateError):
                    gate.validate_ocr(r, PREVIEW, BINDING, 100000)

    def test_preview_accounts_for_git_paths_and_rejects_no_eligible_files(self):
        self.assertEqual(gate.validate_preview(PREVIEW, ['.agents/skills/code-change-verification/scripts/handoff.py', 'assets/page.heex']), PREVIEW)
        for preview, paths in [(PREVIEW, ['assets/page.heex']),
                               (dict(files=[], total_files=0, reviewable_count=0, excluded_count=0), []),
                               (dict(files=[dict(path='assets/page.heex', will_review=False, exclude_reason='unsupported_ext')],
                                     total_files=1, reviewable_count=0, excluded_count=1), ['assets/page.heex'])]:
            with self.assertRaises(gate.GateError):
                gate.validate_preview(preview, paths)

    def test_findings_require_exact_head_independent_reviewed_disposition(self):
        r = result()
        r['comments'] = [dict(path='.agents/skills/code-change-verification/scripts/handoff.py', start_line=10, severity='high', content='Check this')]
        r['summary']['comments'] = 1
        summary = gate.validate_ocr(r, PREVIEW, BINDING, 100000)
        with self.assertRaises(gate.GateError):
            gate.validate_findings(summary, None, HEAD)
        review = dict(user=dict(login='JCSchoeman96'), commit_id=HEAD, state='COMMENTED',
                      body='OCR session-1 finding 1: FALSE POSITIVE. The guard rejects that state.')
        gate.validate_findings(summary, review, HEAD)
        for change in [dict(commit_id=BASE), dict(user=dict(login='JC-Agents')), dict(body='Looks good'),
                       dict(state='DISMISSED'), dict(body='OCR session-1 finding 1: NEEDS EVIDENCE. More proof.')]:
            with self.assertRaises(gate.GateError):
                gate.validate_findings(summary, dict(review, **change), HEAD)

    def test_discovery_prefers_worktree_branch_and_exact_remote_sha(self):
        with patch.object(gate, 'api', side_effect=lambda path: [PR] if path.endswith('/pulls?per_page=100') else PR), \
             patch.object(gate, 'command', return_value=json.dumps(dict(number=232))):
            self.assertEqual(gate.discover_pr(HEAD)['number'], 232)

    def test_discovery_detached_or_mismatched_branch_uses_exact_sha(self):
        for branch in [gate.GateError('detached'), json.dumps(dict(number=19))]:
            def cmd(*args, **kwargs):
                if isinstance(branch, Exception):
                    raise branch
                return branch
            with patch.object(gate, 'command', side_effect=cmd), \
                 patch.object(gate, 'api', side_effect=lambda path: [PR] if path.endswith('/pulls?per_page=100') else PR):
                self.assertEqual(gate.discover_pr(HEAD)['head']['sha'], HEAD)

    def test_discovery_absent_ambiguous_stale_and_merged_are_distinct(self):
        cases = [([], 'absent'), ([PR, dict(PR, number=99)], 'ambiguous'),
                 ([dict(PR, head=dict(PR['head'], sha=BASE))], 'stale'),
                 ([dict(PR, state='closed')], 'absent')]
        for prs, message in cases:
            with self.subTest(message=message), patch.object(gate, 'command', side_effect=gate.GateError('detached')), \
                 patch.object(gate, 'api', return_value=prs), self.assertRaisesRegex(gate.GateError, message):
                gate.discover_pr(HEAD)
        with patch.object(gate, 'api', return_value=dict(PR, head=dict(PR['head'], sha=BASE))), \
             self.assertRaisesRegex(gate.GateError, 'stale'):
            gate.discover_pr(HEAD, 232)

    def test_ci_pending_failed_missing_and_stale_binding_stop(self):
        evidence = dict(head=HEAD, base=BASE, premerge_main=BASE, reviewed_head=HEAD,
                        jobs=[dict(name=n, status='completed', conclusion='success') for n in
                              ['Route CI lanes', 'Foundation Smoke', 'Foundation Integrity', 'Application CI / mix check']],
                        candidate_parents=[BASE, HEAD])
        gate.validate_ci(evidence, BINDING, application=True, deep=False)
        for change in [dict(head=BASE), dict(base=HEAD), dict(premerge_main=HEAD), dict(jobs=[]),
                       dict(candidate_parents=[HEAD, BASE])]:
            with self.assertRaises(gate.GateError):
                gate.validate_ci(dict(evidence, **change), BINDING, application=True, deep=False)
        for state, conclusion in [('queued', None), ('in_progress', None), ('completed', 'failure'), ('completed', 'cancelled')]:
            e = copy.deepcopy(evidence)
            e['jobs'][2].update(status=state, conclusion=conclusion)
            with self.assertRaises(gate.GateError):
                gate.validate_ci(e, BINDING, application=True, deep=False)
        e = copy.deepcopy(evidence)
        e['jobs'].pop()
        with self.assertRaises(gate.GateError):
            gate.validate_ci(e, BINDING, application=True, deep=False)

    def test_preview_and_ocr_work_without_pr_or_ci(self):
        state = dict(binding=BINDING, local=[dict(exit_code=0)])
        for remote_context in ['no PR', 'Draft PR with pending CI', 'remote head behind local HEAD']:
            with self.subTest(context=remote_context), \
                 patch.object(gate, 'collect_ci', side_effect=AssertionError('CI must follow OCR')), \
                 patch.object(gate, 'discover_pr', side_effect=AssertionError('PR must be optional')), \
                 patch.object(gate, 'verify_base'), \
                 patch.object(gate, 'command', return_value=json.dumps(PREVIEW)) as cmd:
                prepared = gate.prepare_preview(state, BINDING, ['.agents/skills/code-change-verification/scripts/handoff.py', 'assets/page.heex'])
                self.assertEqual(prepared['preview'], PREVIEW)
                self.assertIn('--preview', cmd.call_args.args)
                self.assertNotIn('gh', cmd.call_args.args)

    def test_paid_scan_precedes_any_pr_or_ci_query(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifacts = root/'evidence'
            artifacts.mkdir()
            state = dict(binding=BINDING, local=[dict(exit_code=0)],
                         prepared=dict(preview=PREVIEW, budget=100000, exclude=gate.HISTORY_EXCLUDE))
            (artifacts/'state.json').write_text(json.dumps(state))
            def command(*args, **kwargs):
                if args[:3] == ('git', 'rev-parse', '--show-toplevel'):
                    return str(root)
                if args[:3] == ('git', 'rev-parse', '--path-format=absolute'):
                    return str(artifacts)
                if args[:3] == ('ocr', 'auth', 'status'):
                    return 'Status: Using ChatGPT plan'
                self.assertEqual(args[0:2], ('ocr', 'review'))
                self.assertIn('--preview', args)
                return json.dumps(PREVIEW)
            def paid(argv, **kwargs):
                self.assertEqual(argv[:2], ['ocr', 'review'])
                self.assertNotIn('--preview', argv)
                kwargs['stdout'].write(json.dumps(result()))
                return SimpleNamespace(returncode=0)
            with patch('sys.argv', ['handoff', 'ocr']), patch.dict('os.environ', {'CI':'false', 'GITHUB_ACTIONS':'false'}), \
                 patch.object(gate, 'ROOT', root), patch.object(gate, 'worktree', return_value=(BINDING, ['.agents/skills/code-change-verification/scripts/handoff.py', 'assets/page.heex'])), \
                 patch.object(gate, 'command', side_effect=command), patch.object(gate, 'verify_base'), \
                 patch.object(gate, 'collect_ci', side_effect=AssertionError('CI must follow OCR')), \
                 patch.object(gate, 'discover_pr', side_effect=AssertionError('PR must be optional')), \
                 patch.object(gate.subprocess, 'run', side_effect=paid) as run, patch('builtins.print'):
                self.assertEqual(gate.main(), 0)
                run.assert_called_once()
                saved = json.loads((artifacts/'state.json').read_text())
                self.assertEqual(saved['ocr']['summary']['session'], 'session-1')
                original_result = Path(saved['attempts'][0]['result'])
                self.assertTrue(original_result.exists())
                with patch('sys.stderr'):
                    self.assertEqual(gate.main(), 1)
                run.assert_called_once()
                self.assertTrue(original_result.exists())

    def test_local_failure_blocks_preview_before_subscription_calls(self):
        with patch.object(gate, 'command') as cmd, self.assertRaises(gate.GateError):
            gate.prepare_preview({}, BINDING, [])
        cmd.assert_not_called()

    def test_evidence_invalidates_on_head_base_tree_or_range_change(self):
        gate.require_local(dict(binding=BINDING, local=[dict(exit_code=0)]), BINDING)
        for key in BINDING:
            with self.assertRaises(gate.GateError):
                gate.require_local(dict(binding=BINDING, local=[dict(exit_code=0)]), dict(BINDING, **{key: 'e'*40}))
        with self.assertRaises(gate.GateError):
            gate.require_local(dict(binding=BINDING, local=[dict(exit_code=1)]), BINDING)

    def test_malformed_nested_json_and_duplicate_keys_fail_closed(self):
        for path in [('manifest', 'coverage'), ('manifest', 'input'), ('manifest', 'execution'),
                     ('summary',), ('tool_calls',), ('retry_report',)]:
            for invalid in [None, [], 'invalid', 42]:
                r = result()
                node = r
                for key in path[:-1]:
                    node = node[key]
                node[path[-1]] = invalid
                with self.subTest(path=path, invalid=invalid), self.assertRaises(gate.GateError):
                    gate.validate_ocr(r, PREVIEW, BINDING, 100000)
        with self.assertRaises(gate.GateError):
            gate.decode('{"status":"partial","status":"complete"}')

    def test_noop_focused_command_cannot_create_local_verification_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'state.json'
            with patch.object(gate, 'ROOT', Path(directory)), \
                 patch.object(gate, 'worktree', return_value=(BINDING, [])), \
                 patch.object(gate.subprocess, 'run', return_value=SimpleNamespace(returncode=0)), \
                 patch('builtins.print'), self.assertRaisesRegex(gate.GateError, 'focused'):
                gate.local(path, BINDING, [], ['true'])
            self.assertFalse(path.exists())

    def test_zero_exit_with_zero_test_report_is_not_regression_proof(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def empty_run(argv, **kwargs):
                kwargs['stdout'].write('Ran 0 tests in 0.000s\nOK\n')
                return SimpleNamespace(returncode=0)
            with patch.object(gate, 'ROOT', root), patch('builtins.print'), \
                 patch.object(gate, 'worktree', return_value=(BINDING, [])), \
                 patch.object(gate.subprocess, 'run', side_effect=empty_run), \
                 self.assertRaisesRegex(gate.GateError, 'no tests'):
                gate.local(root/'state.json', BINDING, [], ['python3 -m unittest tests.test_empty -q'])
            self.assertFalse((root/'state.json').exists())

    def test_external_discovery_cannot_create_local_verification_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'tests').mkdir()
            external = root/'external'
            external.mkdir()
            (external/'test_external.py').write_text(
                'import unittest\nclass External(unittest.TestCase):\n'
                '    def test_passes(self):\n        self.assertTrue(True)\n')
            argv = ['python3', '-m', 'unittest', 'discover', '-s', 'tests',
                    '-s', str(external), '-p', 'test*.py']
            # Reproduce unittest's last-option-wins behavior with a real run.
            run = subprocess.run(argv, cwd=root, capture_output=True, text=True)
            self.assertEqual(run.returncode, 0)
            self.assertIn('Ran 1 test', run.stderr)
            def passed(_argv, **kwargs):
                kwargs['stdout'].write(run.stderr)
                return SimpleNamespace(returncode=0)
            with patch.object(gate, 'ROOT', root), patch('builtins.print'), \
                 patch.object(gate, 'worktree', return_value=(BINDING, [])), \
                 patch.object(gate.subprocess, 'run', side_effect=passed) as invoke, \
                 self.assertRaisesRegex(gate.GateError, 'focused'):
                gate.local(root/'state.json', BINDING, [], [gate.shlex.join(argv)])
            invoke.assert_not_called()
            self.assertFalse((root/'state.json').exists())

    def test_focused_unittest_accepts_only_explicit_repository_targets(self):
        for argv in [
            ['python3', '-m', 'unittest', 'tests.test_agent_handoff', '-q'],
            ['python3', '-m', 'unittest', '-v', 'tests.test_agent_handoff.HandoffTests'],
        ]:
            self.assertEqual(gate.focused_kind(argv), 'python-test')
        for arguments in [
            ['tests.test_empty', 'external.test_passes'],
            ['tests.test_agent_handoff', '-k', 'external'],
            ['discover', '-s', 'tests', '-p', 'test*.py'],
        ]:
            with self.subTest(arguments=arguments), self.assertRaises(gate.GateError):
                gate.focused_kind(['python3', '-m', 'unittest', *arguments])

    def test_unavailable_subscription_does_not_run_paid_review(self):
        for status in ['', 'Status: expired', 'Status: API key']:
            with patch.object(gate, 'command', return_value=status) as cmd, self.assertRaises(gate.GateError):
                gate.require_subscription()
            self.assertEqual(cmd.call_args.args, ('ocr', 'auth', 'status'))

    def test_local_failure_removes_old_evidence_and_stops(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)/'state.json'
            state.write_text(json.dumps(dict(binding=BINDING, local=[dict(exit_code=0)])))
            with patch.object(gate, 'ROOT', Path(directory)), patch('builtins.print'):
                with self.assertRaisesRegex(gate.GateError, 'local verification failed'):
                    gate.local(state, BINDING, [], ['python3 -m unittest tests.test_missing -q'])
            self.assertFalse(state.exists())

    def test_cli_rejects_shared_ci_before_any_tool_call(self):
        with patch.dict('os.environ', {'GITHUB_ACTIONS': 'true'}), \
             patch('sys.argv', ['handoff', 'ocr']), patch.object(gate, 'command') as cmd, \
             patch('sys.stderr'), self.assertRaises(SystemExit) as stopped:
            raise SystemExit(gate.main())
        self.assertEqual(stopped.exception.code, 1)
        cmd.assert_not_called()

    def test_mechanical_history_reuse_requires_identical_source_base_and_selection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.run(['git', '-C', str(root), *args], check=True, capture_output=True, text=True).stdout.strip()
            git('init', '-q')
            git('config', 'user.email', 'test@example.invalid')
            git('config', 'user.name', 'Fixture')
            git('remote', 'add', 'origin', 'git@github.com:Carpe-Diem-Media/NewYou.git')
            (root/'source.py').write_text('base')
            git('add', '.')
            git('commit', '-qm', 'base')
            git('update-ref', 'refs/remotes/origin/main', 'HEAD')
            (root/'source.py').write_text('implementation')
            git('commit', '-qam', 'implementation')
            with patch.object(gate, 'ROOT', root):
                scanned, _ = gate.worktree()
                state = dict(binding=scanned, local=[dict(exit_code=0)])
                history = 'docs/development/knowledge/history/pr-232.json'
                (root/history).parent.mkdir(parents=True)
                (root/history).write_text('{}')
                git('add', '.')
                git('commit', '-qm', 'generated history')
                final, _ = gate.worktree()
                reuse = gate.proof_binding(state, final, 232)
                self.assertEqual(reuse['implementation'], scanned['head'])
                self.assertEqual(reuse['history_only'], history)
                for changed in [dict(final, base=HEAD), dict(final, merge_base=HEAD)]:
                    with self.assertRaises(gate.GateError):
                        gate.proof_binding(state, changed, 232)
                with self.assertRaises(gate.GateError):
                    gate.proof_binding(state, final, 233)
                (root/'source.py').write_text('corrected')
                git('commit', '-qam', 'source correction')
                with self.assertRaises(gate.GateError):
                    gate.proof_binding(state, gate.worktree()[0], 232)

    def test_history_preview_reuse_rejects_new_eligible_files(self):
        history = 'docs/development/knowledge/history/pr-232.json'
        fresh = copy.deepcopy(PREVIEW)
        fresh['files'].append(dict(path=history, will_review=False, exclude_reason='user_exclude'))
        fresh.update(total_files=3, excluded_count=2)
        gate.validate_reuse_preview(PREVIEW, fresh, history)
        fresh['files'][-1] = dict(path=history, will_review=True)
        with self.assertRaises(gate.GateError):
            gate.validate_reuse_preview(PREVIEW, fresh, history)
        fresh['files'][-1] = dict(path='new.py', will_review=True)
        with self.assertRaises(gate.GateError):
            gate.validate_reuse_preview(PREVIEW, fresh, history)

    def test_finish_requires_fresh_final_ci_after_valid_ocr(self):
        evidence = dict(head=HEAD, base=BASE, premerge_main=BASE, reviewed_head=HEAD,
                        jobs=[dict(name=n, status='completed', conclusion='success') for n in
                              ['Route CI lanes', 'Foundation Smoke', 'Foundation Integrity', 'Application CI / mix check']],
                        candidate_parents=[BASE, HEAD])
        for outcome in ['success', 'pending', 'failure', 'missing', 'stale-head', 'stale-base']:
            with self.subTest(ci=outcome), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                artifacts = root/'evidence'
                artifacts.mkdir()
                state = dict(binding=BINDING, local=[dict(exit_code=0)],
                             prepared=dict(preview=PREVIEW, budget=100000, exclude=gate.HISTORY_EXCLUDE),
                             ocr=dict(result=result(), command=['ocr', 'review']))
                (artifacts/'state.json').write_text(json.dumps(state))
                def command(*args, **kwargs):
                    if args[:3] == ('git', 'rev-parse', '--show-toplevel'):
                        return str(root)
                    if args[:3] == ('git', 'rev-parse', '--path-format=absolute'):
                        return str(artifacts)
                    if args[:3] == ('gh', 'pr', 'view'):
                        return json.dumps(dict(number=232))
                    self.assertEqual(args[:2], ('ocr', 'review'))
                    self.assertIn('--preview', args)
                    return json.dumps(PREVIEW)
                def api(path):
                    if path.startswith('commits/'):
                        return [PR]
                    if path == 'pulls/232':
                        return PR
                    run = dict(id=42, status='completed', conclusion='success', pull_requests=[dict(number=232)])
                    if outcome in ['pending', 'failure']:
                        run.update(status='in_progress' if outcome == 'pending' else 'completed', conclusion=None if outcome == 'pending' else 'failure')
                    return dict(total_count=0 if outcome == 'missing' else 1,
                                workflow_runs=[] if outcome == 'missing' else [run])
                e = copy.deepcopy(evidence)
                if outcome.startswith('stale-'):
                    e['head' if outcome == 'stale-head' else 'base'] = MERGE
                with patch('sys.argv', ['handoff', 'finish', '--ticket', 'WELL-125']), \
                     patch.dict('os.environ', {'CI':'false', 'GITHUB_ACTIONS':'false'}), \
                     patch.object(gate, 'ROOT', root), patch.object(gate, 'worktree', return_value=(BINDING, ['.agents/skills/code-change-verification/scripts/handoff.py', 'assets/page.heex'])), \
                     patch.object(gate, 'command', side_effect=command), patch.object(gate, 'api', side_effect=api), \
                     patch.object(gate.ci_attestation, 'collect', return_value=e), \
                     patch.object(gate, 'validate_knowledge', return_value=dict(outcome='PASS')), \
                     patch('builtins.print') as printed, patch('sys.stderr'):
                    self.assertEqual(gate.main(), 0 if outcome == 'success' else 1)
                    if outcome == 'success':
                        summary = json.loads(printed.call_args.args[0])
                        self.assertEqual(summary['status'], 'awaiting independent Master Gate')
                        self.assertEqual(summary['implementation_binding']['head'], HEAD)

    def test_actual_clean_committed_and_detached_git_worktrees(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.run(['git', '-C', str(root), *args], check=True, capture_output=True, text=True).stdout.strip()
            git('init', '-q')
            git('config', 'user.email', 'test@example.invalid')
            git('config', 'user.name', 'Fixture')
            (root/'file').write_text('base')
            git('add', '.')
            git('commit', '-qm', 'base')
            git('update-ref', 'refs/remotes/origin/main', 'HEAD')
            git('remote', 'add', 'origin', 'git@github.com:Carpe-Diem-Media/NewYou.git')
            (root/'file').write_text('head')
            git('commit', '-qam', 'head')
            with patch.object(gate, 'ROOT', root):
                binding, paths = gate.worktree()
                self.assertEqual(binding['head'], git('rev-parse', 'HEAD'))
                self.assertEqual(paths, ['file'])
                git('checkout', '--detach', '-q')
                self.assertEqual(gate.worktree(), (binding, paths))
                (root/'untracked').write_text('dirty')
                with self.assertRaisesRegex(gate.GateError, 'clean'):
                    gate.worktree()


if __name__ == '__main__':
    unittest.main()
