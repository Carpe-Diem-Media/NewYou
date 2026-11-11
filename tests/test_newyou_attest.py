from __future__ import annotations

import copy
import unittest

from tools import newyou_attest as attest


def merge_comment(approval, binding, identifier=8):
    return dict(approval, id=identifier,
                html_url=f'https://github.com/{attest.REPOSITORY}/pull/{binding["pr"]}#issuecomment-{identifier}',
                body=attest.merge_authorization_message(binding))


class FounderApprovalTests(unittest.TestCase):
    def setUp(self):
        self.binding = {"pr": 42, "base": "a" * 40, "head": "b" * 40,
                        "diff_sha256": "c" * 64, "run_id": 101,
                        "run_attempt": 1, "check_id": 33}
        self.comment = {"id": 7, "user": {"id": 12, "login": "owner"},
                        "author_association": "OWNER", "created_at": "2026-01-01T00:00:00Z",
                        "updated_at": "2026-01-01T00:00:00Z",
                        "html_url": "https://github.com/JCSchoeman96/NewYou/pull/42#issuecomment-7",
                        "body": attest.approval_message(self.binding)}

    def test_exact_owner_approval_is_accepted(self):
        self.assertEqual(7, attest.verify_approval(self.comment, self.binding, 12)["id"])

    def test_forged_edited_or_stale_approval_fails(self):
        mutations = [
            {"user": {"id": 13}}, {"author_association": "MEMBER"},
            {"updated_at": "2026-01-02T00:00:00Z"}, {"body": "go ahead"},
            {"html_url": "https://example.test/issuecomment-7"}, {"id": None},
        ]
        for change in mutations:
            with self.subTest(change=change), self.assertRaises(attest.AttestationError):
                attest.verify_approval(dict(self.comment, **change), self.binding, 12)
        for field, value in [("pr", 43), ("head", "d" * 40), ("base", "d" * 40),
                             ("diff_sha256", "d" * 64), ("run_id", 102),
                             ("run_attempt", 2), ("check_id", 34)]:
            changed = copy.deepcopy(self.binding)
            changed[field] = value
            with self.subTest(field=field), self.assertRaises(attest.AttestationError):
                attest.verify_approval(self.comment, changed, 12)


class CustodyTests(unittest.TestCase):
    def setUp(self):
        import tempfile
        from pathlib import Path
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name)

    def test_atomic_attempt_and_manifest_detects_tampering(self):
        with attest.Custody(self.state, 42, 'a' * 40) as custody:
            name = custody.save_attempt({'review.json': b'{}\n', 'before.json': b'{"ok":true}\n'})
            self.assertEqual(b'{}\n', custody.read_attempt(name)['review.json'])
            path = self.state / 'newyou' / 'attestations' / 'pr-42' / ('a' * 40) / 'attempts' / name / 'review.json'
            self.assertEqual(0o600, path.stat().st_mode & 0o777)
            self.assertTrue((path.parent / 'SHA256SUMS').is_file())
            path.write_bytes(b'changed')
            with self.assertRaises(attest.AttestationError):
                custody.read_attempt(name)

    def test_rejects_symlink_bad_ids_and_unsafe_mode(self):
        import os
        (self.state / 'newyou').symlink_to(self.state, target_is_directory=True)
        with self.assertRaises((attest.AttestationError, OSError)):
            with attest.Custody(self.state, 42, 'a' * 40): pass
        (self.state / 'newyou').unlink()
        for pr, head in [(-1, 'a' * 40), (42, '../etc'), (0, 'a' * 40)]:
            with self.subTest(pr=pr, head=head), self.assertRaises(attest.AttestationError):
                with attest.Custody(self.state, pr, head): pass
        os.mkdir(self.state / 'newyou', 0o755)
        with self.assertRaises(attest.AttestationError):
            with attest.Custody(self.state, 42, 'a' * 40): pass

    def test_rejects_concurrent_lock(self):
        with attest.Custody(self.state, 42, 'a' * 40):
            with self.assertRaises(attest.AttestationError):
                with attest.Custody(self.state, 42, 'a' * 40): pass

    def test_incomplete_attempt_cannot_be_loaded_and_retries_preserve_history(self):
        from unittest.mock import patch
        with attest.Custody(self.state, 42, 'a' * 40) as custody:
            first = custody.save_attempt({'before.json': b'one'})
            second = custody.save_attempt({'before.json': b'one'})
            self.assertNotEqual(first, second)
            self.assertEqual(custody.read_attempt(first), custody.read_attempt(second))
            with patch.object(custody, '_write', side_effect=OSError('interrupted')):
                with self.assertRaises(OSError): custody.save_attempt({'before.json': b'two'})
            self.assertEqual(b'one', custody.read_attempt(first)['before.json'])

    def test_missing_or_extra_manifest_entries_fail(self):
        with attest.Custody(self.state, 42, 'a' * 40) as custody:
            name = custody.save_attempt({'before.json': b'one'})
            path = self.state / 'newyou' / 'attestations' / 'pr-42' / ('a' * 40) / 'attempts' / name
            (path / 'manifest.json').unlink()
            with self.assertRaises(OSError): custody.read_attempt(name)


class ApprovalSelectionTests(FounderApprovalTests):
    def test_missing_untrusted_or_superseded_approval_fails(self):
        other = dict(self.comment, id=8, user={'id': 13, 'login': 'other'}, body='go ahead')
        self.assertIsNone(attest.select_approval([other], self.binding, 12))
        self.assertEqual(self.comment['id'], attest.select_approval([other, self.comment], self.binding, 12)['id'])
        revoked = dict(self.comment, id=9, body='NEWYOU FOUNDER DEVELOPMENT REVIEW V1\nwithdrawn')
        with self.assertRaises(attest.AttestationError):
            attest.select_approval([self.comment, revoked], self.binding, 12)


class SyntheticWorkflowTests(unittest.TestCase):
    def test_deleted_newer_authorization_cannot_replay_older_attempt(self):
        import tempfile
        from tests.test_ci_attestation import evidence
        from unittest.mock import patch
        data = evidence(); data.update(run_id=101, run_attempt=1)
        binding = {'pr': 42, 'base': data['base'], 'head': data['head'],
                   'candidate': data['candidate'], 'tree': data['tree'], 'diff_sha256': 'f' * 64,
                   'run_id': 101, 'run_attempt': 1, 'check_id': 12, 'ci_completed_at': '2025-12-31T00:00:00Z'}
        review = {'id': 7, 'user': {'id': 12, 'login': 'owner'}, 'author_association': 'OWNER',
                  'created_at': '2026-01-01T00:00:00Z', 'updated_at': '2026-01-01T00:00:00Z',
                  'html_url': f'https://github.com/{attest.REPOSITORY}/pull/42#issuecomment-7',
                  'body': attest.approval_message(binding)}
        older, newer = merge_comment(review, binding, 8), merge_comment(review, binding, 9)
        result = {'method': 'merge', 'merge_sha': 'e' * 40, 'main': 'e' * 40,
                  'parents': [data['base'], data['head']], 'tree': data['tree']}
        with tempfile.TemporaryDirectory() as state, \
             patch.object(attest, 'gather_before', return_value=(binding, data, 12)), \
             patch.object(attest, 'gather_after', return_value={'candidate': data, 'result': result}), \
             patch.object(attest, 'utc_now', return_value='2026-01-02T00:00:00Z'), \
             patch('tools.ci_attestation._api', side_effect=lambda path: {'full_name': attest.REPOSITORY, 'owner': {'id': 12}}
                   if path == f'repos/{attest.REPOSITORY}' else {'merged': True, 'merged_at': '2026-01-02T00:00:00Z'}):
            with patch.object(attest, 'owner_comments', return_value=[review, older]):
                attest.prepare(42, state)
            with patch.object(attest, 'owner_comments', return_value=[review, older, newer]):
                attest.prepare(42, state)
            with patch.object(attest, 'owner_comments', return_value=[review, older]):
                with self.assertRaises(attest.AttestationError):
                    attest.verify_after(42, data['head'], state)
            with patch.object(attest, 'owner_comments', return_value=[review, older, newer]):
                self.assertEqual('POSTMERGE_VERIFIED', attest.verify_after(42, data['head'], state)['status'])

    def test_full_synthetic_workflow_uses_actual_collector(self):
        import tempfile
        from tests.test_ci_attestation import PublicProtectedCollectionTest
        from unittest.mock import patch
        fixture = PublicProtectedCollectionTest(methodName='test_public_collection_binds_current_ruleset_and_effective_rules')
        fixture.setUp()
        fixture.repository['owner'] = {'id': 12, 'login': 'JCSchoeman96'}
        fixture.run.update(conclusion='success', updated_at='2026-01-01T00:00:00Z',
                           html_url='https://github.com/JCSchoeman96/NewYou/actions/runs/100')
        comments = []
        merged_sha = 'f' * 40
        def api(path):
            if fixture.pr['merged'] and path.endswith('commits/main'):
                return {'sha': merged_sha}
            if fixture.pr['merged'] and path.endswith('git/commits/' + merged_sha):
                return {'tree': {'sha': fixture.e['tree']}, 'parents': [
                    {'sha': fixture.e['base']}, {'sha': fixture.e['head']}]}
            return copy.deepcopy(fixture.api(path))
        with tempfile.TemporaryDirectory() as state, \
             patch('tools.ci_attestation._api', side_effect=api), \
             patch('tools.ci_attestation._api_rules', side_effect=api), \
             patch('tools.ci_attestation._command', side_effect=fixture.log), \
             patch.object(attest, 'git_diff_digest', return_value='c' * 64), \
             patch.object(attest, 'owner_comments', side_effect=lambda pr: copy.deepcopy(comments)), \
             patch.object(attest, 'utc_now', return_value='2026-01-02T00:00:00Z'):
            waiting = attest.prepare(42, state)
            self.assertEqual('AWAITING_OWNER_REVIEW', waiting['status'])
            comments.append({'id': 7, 'user': {'id': 12, 'login': 'JCSchoeman96'},
                'author_association': 'OWNER', 'created_at': '2026-01-01T01:00:00Z',
                'updated_at': '2026-01-01T01:00:00Z',
                'html_url': 'https://github.com/JCSchoeman96/NewYou/pull/42#issuecomment-7',
                'body': waiting['approval_text']})
            prepared = attest.prepare(42, state)
            self.assertEqual('PREMERGE_VERIFIED', prepared['status'])
            authorization = merge_comment(comments[0], prepared['binding'])
            comments.append(authorization)
            fixture.pr.update(merged=True, state='closed', merge_commit_sha=merged_sha,
                              merged_at='2026-01-02T00:00:00Z')
            fixture.run['pull_requests'] = []
            with self.assertRaises(attest.AttestationError):
                attest.verify_after(42, fixture.e['head'], state)
            fixture.pr.update(merged=False, state='open', merge_commit_sha=fixture.e['candidate'])
            fixture.run['pull_requests'] = [{'number': 42}]
            original_write = attest.Custody._write
            def interrupted(fd, name, data):
                if name == 'authorization.json':
                    raise OSError('interrupted authorization write')
                return original_write(fd, name, data)
            with patch.object(attest.Custody, '_write', side_effect=interrupted):
                with self.assertRaises(OSError):
                    attest.prepare(42, state)
            fixture.pr.update(merged=True, state='closed', merge_commit_sha=merged_sha)
            fixture.run['pull_requests'] = []
            with self.assertRaises(attest.AttestationError):
                attest.verify_after(42, fixture.e['head'], state)
            fixture.pr.update(merged=False, state='open', merge_commit_sha=fixture.e['candidate'])
            fixture.run['pull_requests'] = [{'number': 42}]
            comments.pop()
            for mutation in ({'updated_at': '2026-01-01T02:00:00Z'},
                             {'body': attest.merge_authorization_message(dict(prepared['binding'], run_id=101))},
                             {'created_at': '2025-12-30T00:00:00Z', 'updated_at': '2025-12-30T00:00:00Z'}):
                comments.append(dict(authorization, **mutation))
                with self.subTest(mutation=mutation), self.assertRaises(attest.AttestationError):
                    attest.prepare(42, state)
                comments.pop()
            comments.append(authorization)
            self.assertEqual('MERGE_AUTHORISED', attest.prepare(42, state)['status'])
            with patch.object(attest, 'owner_comments', side_effect=[copy.deepcopy(comments),
                    copy.deepcopy(comments), [copy.deepcopy(comments[0])]]):
                with self.assertRaises(attest.AttestationError):
                    attest.prepare(42, state)
            superseded = dict(authorization, id=9,
                html_url='https://github.com/JCSchoeman96/NewYou/pull/42#issuecomment-9',
                body='NEWYOU FOUNDER DEVELOPMENT MERGE AUTHORIZATION V1\nwithdrawn')
            comments.append(superseded)
            with self.assertRaises(attest.AttestationError):
                attest.prepare(42, state)
            comments.pop()
            comments.pop()
            self.assertEqual('PREMERGE_VERIFIED', attest.prepare(42, state)['status'])
            comments.append(dict(authorization, user={'id': 99, 'login': 'other'}))
            self.assertEqual('PREMERGE_VERIFIED', attest.prepare(42, state)['status'])
            comments.pop()
            fixture.pr.update(merged=True, state='closed', merge_commit_sha=merged_sha,
                              merged_at='2026-01-02T00:00:00Z')
            fixture.run['pull_requests'] = []
            with self.assertRaises(attest.AttestationError):
                attest.verify_after(42, fixture.e['head'], state)
            for mutation in ({'body': 'go ahead'}, {'user': {'id': 99, 'login': 'agent'}},
                             {'updated_at': '2026-01-01T02:00:00Z'},
                             {'body': attest.merge_authorization_message(dict(prepared['binding'], run_id=101))}):
                comments.append(dict(authorization, **mutation))
                with self.subTest(mutation=mutation), self.assertRaises(attest.AttestationError):
                    attest.verify_after(42, fixture.e['head'], state)
                comments.pop()
            comments.append(authorization)
            from pathlib import Path
            attempts = Path(state, 'newyou', 'attestations', 'pr-42', fixture.e['head'], 'attempts')
            saved_auth = next(path for path in attempts.glob('*/authorization.json')
                              if (path.parent / 'manifest.json').exists())
            manifest = saved_auth.parent / 'manifest.json'
            original_manifest = manifest.read_bytes()
            with attest.Custody(state, 42, fixture.e['head']) as custody:
                package = custody.read_attempt(saved_auth.parent.name)
                wrong_auth = dict(package)
                wrong_auth['authorization.json'] = attest._json_bytes(dict(authorization, body='different'))
                custody.save_attempt(wrong_auth)
                package['status.json'] = attest._json_bytes({'status': 'MERGE_AUTHORISED',
                                                               'premerge_attempt': 'f' * 32})
                custody.save_attempt(package)
            manifest.unlink()
            with self.assertRaises(attest.AttestationError):
                attest.verify_after(42, fixture.e['head'], state)
            manifest.write_bytes(original_manifest)
            manifest.chmod(0o600)
            original_auth = saved_auth.read_bytes()
            saved_auth.write_bytes(b'{}')
            with self.assertRaises(attest.AttestationError):
                attest.verify_after(42, fixture.e['head'], state)
            saved_auth.write_bytes(original_auth)
            self.assertEqual('POSTMERGE_VERIFIED', attest.verify_after(42, fixture.e['head'], state)['status'])

    def test_prepare_then_after_and_tamper_rejection(self):
        import tempfile
        from tests.test_ci_attestation import evidence
        from unittest.mock import patch
        data = evidence()
        data.update(run_id=101, run_attempt=1)
        binding = {'pr': 42, 'base': data['base'], 'head': data['head'],
                   'candidate': data['candidate'], 'tree': data['tree'],
                   'diff_sha256': 'f' * 64, 'run_id': 101, 'run_attempt': 1, 'check_id': 12, 'ci_completed_at': '2025-12-31T00:00:00Z'}
        comment = {'id': 7, 'user': {'id': 12, 'login': 'owner'}, 'author_association': 'OWNER',
                   'created_at': '2026-01-01T00:00:00Z', 'updated_at': '2026-01-01T00:00:00Z',
                   'html_url': 'https://github.com/JCSchoeman96/NewYou/pull/42#issuecomment-7',
                   'body': attest.approval_message(binding)}
        result = {'method': 'merge', 'merge_sha': 'e' * 40, 'main': 'e' * 40,
                  'parents': [data['base'], data['head']], 'tree': data['tree']}
        with tempfile.TemporaryDirectory() as state:
            with patch.object(attest, 'gather_before', return_value=(binding, data, 12)), \
                 patch.object(attest, 'owner_comments', return_value=[comment, merge_comment(comment, binding)]), \
                 patch.object(attest, 'gather_after', return_value={'candidate': data, 'result': result}), \
                 patch.object(attest, 'utc_now', return_value='2026-01-02T00:00:00Z'), \
                 patch('tools.ci_attestation._api', side_effect=lambda path: {'full_name':attest.REPOSITORY,'owner':{'id':12}} if path == f'repos/{attest.REPOSITORY}' else {'merged':True,'merged_at':'2026-01-02T00:00:00Z'}):
                self.assertEqual('MERGE_AUTHORISED', attest.prepare(42, state)['status'])
                self.assertEqual('POSTMERGE_VERIFIED', attest.verify_after(42, data['head'], state)['status'])
                with patch.object(attest, 'owner_comments', return_value=[]):
                    with self.assertRaises(attest.AttestationError):
                        attest.verify_after(42, data['head'], state)

    def test_missing_approval_and_after_without_before(self):
        import tempfile
        from tests.test_ci_attestation import evidence
        from unittest.mock import patch
        data = evidence(); data.update(run_id=101, run_attempt=1)
        binding = {'pr':42, 'head':data['head'], 'candidate':data['candidate'],
                   'run_id':101, 'check_id':12}
        with tempfile.TemporaryDirectory() as state:
            with patch.object(attest, 'gather_before', return_value=(binding, data, 12)), \
                 patch.object(attest, 'owner_comments', return_value=[]):
                self.assertEqual('AWAITING_OWNER_REVIEW', attest.prepare(42, state)['status'])
                with self.assertRaises(attest.AttestationError):
                    attest.verify_after(42, data['head'], state)
            stale = {'id':7, 'user':{'id':12, 'login':'owner'}, 'author_association':'OWNER',
                     'created_at':'2026-01-01T00:00:00Z', 'updated_at':'2026-01-01T00:00:00Z',
                     'html_url':'https://github.com/JCSchoeman96/NewYou/pull/42#issuecomment-7',
                     'body':attest.approval_message(dict(binding, head='d'*40))}
            with patch.object(attest, 'gather_before', return_value=(binding, data, 12)), \
                 patch.object(attest, 'owner_comments', return_value=[stale]):
                self.assertEqual('AWAITING_OWNER_REVIEW', attest.prepare(42, state)['status'])


class ApprovalFreshnessTests(unittest.TestCase):
    def test_approval_must_follow_ci_and_expire(self):
        approval = {'created_at': '2026-01-02T00:00:00Z'}
        self.assertIsNone(attest.verify_approval_freshness(approval, '2026-01-01T12:00:00Z', '2026-01-03T00:00:00Z'))
        for ci_time, now in [('2026-01-03T00:00:00Z', '2026-01-03T00:00:00Z'),
                             ('2026-01-01T12:00:00Z', '2026-01-10T00:00:00Z'),
                             ('2026-01-01T12:00:00Z', '2026-01-01T00:00:00Z')]:
            with self.subTest(ci_time=ci_time, now=now), self.assertRaises(attest.AttestationError):
                attest.verify_approval_freshness(approval, ci_time, now)


class DiffTests(unittest.TestCase):
    def test_hashes_complete_binary_patch_from_git_objects(self):
        import hashlib
        import os
        import subprocess
        import tempfile
        from pathlib import Path
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as directory:
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=directory, stderr=subprocess.DEVNULL)
            git('init', '-q')
            git('config', 'user.email', 'test@example.invalid')
            git('config', 'user.name', 'Test')
            Path(directory, 'binary.dat').write_bytes(b'\x00before')
            git('add', 'binary.dat')
            git('commit', '-qm', 'base')
            base = git('rev-parse', 'HEAD').decode().strip()
            Path(directory, 'binary.dat').write_bytes(b'\x00after')
            git('commit', '-qam', 'head')
            head = git('rev-parse', 'HEAD').decode().strip()
            patch_bytes = git('diff', '--binary', '--no-ext-diff', '--no-textconv', base, head)
            self.assertIn(b'GIT binary patch', patch_bytes)
            real_git = attest._git
            def local_git(*args):
                return b'' if args[0] == 'fetch' else real_git(*args)
            original = os.getcwd()
            try:
                os.chdir(directory)
                with patch.object(attest, '_git', side_effect=local_git):
                    self.assertEqual(hashlib.sha256(patch_bytes).hexdigest(), attest.git_diff_digest(base, head))
            finally:
                os.chdir(original)


class ActivationTests(unittest.TestCase):
    def test_collector_timeout_fails_closed(self):
        import subprocess
        from unittest.mock import patch
        from tools import ci_attestation
        with patch('subprocess.run', side_effect=subprocess.TimeoutExpired('gh', 60)):
            with self.assertRaises(attest.AttestationError):
                ci_attestation._command('gh', 'api', 'example')

    def test_current_main_and_clean_checkout_required(self):
        from unittest.mock import patch
        current = 'a' * 40
        with patch('tools.ci_attestation._api', return_value={'sha':current}), \
             patch.object(attest, '_git', side_effect=[current.encode() + b'\n', b'', b'', b'tools/newyou_attest.py\n']):
            attest.require_integrated_mode()
        with patch('tools.ci_attestation._api', return_value={'sha':current}), \
             patch.object(attest, '_git', side_effect=[b'b' * 40 + b'\n']):
            with self.assertRaises(attest.AttestationError): attest.require_integrated_mode()


class EvidenceBindingTests(unittest.TestCase):
    def test_premerge_evidence_must_match_all_bindings(self):
        from tests.test_ci_attestation import evidence
        data = evidence(); data.update(run_id=101, run_attempt=1)
        binding = {'pr':42, 'head':data['head'], 'base':data['base'], 'candidate':data['candidate'],
                   'tree':data['tree'], 'run_id':101, 'run_attempt':1, 'check_id':12,
                   'diff_sha256':'f'*64}
        review = {'reviewed_head':data['head'], 'reviewer':'owner',
                  'review_reference':'https://example.test/review', 'diff_sha256':'f'*64,
                  'mode':'founder-development', 'owner_account_id':12, 'approval_id':7}
        data['review_record'] = review
        attest.verify_evidence_binding(data, binding, review, {'id':7,'user':{'login':'owner'},
                                       'html_url':'https://example.test/review'}, 12)
        for key, value in [('base','e'*40),('head','e'*40),('candidate','e'*40),('tree','e'*40),
                           ('run_id',102),('run_attempt',2),('check_id',13),('diff_sha256','e'*64)]:
            with self.subTest(key=key), self.assertRaises(attest.AttestationError):
                attest.verify_evidence_binding(data, dict(binding, **{key:value}), review,
                                               {'id':7,'user':{'login':'owner'},
                                                'html_url':'https://example.test/review'}, 12)

    def test_new_run_supersedes_older_successful_evidence(self):
        import tempfile
        from tests.test_ci_attestation import evidence
        from unittest.mock import patch
        first = evidence(); first.update(run_id=101, run_attempt=1)
        second = copy.deepcopy(first); second['run_id'] = 102
        def binding(proof):
            return {'pr':42,'head':proof['head'],'base':proof['base'],'candidate':proof['candidate'],
                    'tree':proof['tree'],'diff_sha256':'f'*64,'run_id':proof['run_id'],
                    'run_attempt':1,'check_id':12,'ci_completed_at':'2025-12-31T00:00:00Z'}
        def comment(proof, ident):
            return {'id':ident,'user':{'id':12,'login':'owner'},'author_association':'OWNER',
                    'created_at':'2026-01-01T00:00:00Z','updated_at':'2026-01-01T00:00:00Z',
                    'html_url':f'https://github.com/{attest.REPOSITORY}/pull/42#issuecomment-{ident}',
                    'body':attest.approval_message(binding(proof))}
        result={'method':'merge','merge_sha':'e'*40,'main':'e'*40,'parents':[second['base'],second['head']], 'tree':second['tree']}
        with tempfile.TemporaryDirectory() as state, \
             patch.object(attest,'utc_now',return_value='2026-01-02T00:00:00Z'), \
             patch('tools.ci_attestation._api',side_effect=lambda path: {'full_name':attest.REPOSITORY,'owner':{'id':12}} if path == f'repos/{attest.REPOSITORY}' else {'merged':True,'merged_at':'2026-01-02T00:00:00Z'}):
            with patch.object(attest,'gather_before',return_value=(binding(first),first,12)), patch.object(attest,'owner_comments',return_value=[comment(first,7)]):
                attest.prepare(42,state)
            with patch.object(attest,'gather_before',return_value=(binding(second),second,12)), patch.object(attest,'owner_comments',return_value=[comment(first,7),comment(second,8)]):
                attest.prepare(42,state)
            with patch.object(attest,'gather_before',return_value=(binding(second),second,12)), patch.object(attest,'owner_comments',return_value=[comment(first,7),comment(second,8),merge_comment(comment(second,8),binding(second),9)]):
                attest.prepare(42,state)
            with patch.object(attest,'gather_after',return_value={'candidate':second,'result':result}), patch.object(attest,'owner_comments',return_value=[comment(first,7),comment(second,8),merge_comment(comment(second,8),binding(second),9)]):
                self.assertEqual('POSTMERGE_VERIFIED',attest.verify_after(42,second['head'],state)['status'])
