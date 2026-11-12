"""Live founder approval guards. Fixtures replace GitHub, never approve real PRs."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from tools import founder_gate as gate
from tools.ci_attestation import AttestationError
from tests.test_ci_attestation import evidence

HEAD, BASE = 'a'*40, 'b'*40

def pull():
    return dict(number=42, user=dict(id=355419376, login='JC-Agents'),
                head=dict(sha=HEAD), base=dict(sha=BASE, ref='main'))

def review():
    return dict(id=7, user=dict(id=216185530, login='JCSchoeman96'), state='APPROVED',
                commit_id=HEAD, html_url='https://github.com/Carpe-Diem-Media/NewYou/pull/42#pullrequestreview-7',
                body='Full technical review passed.\nFounder-development base: '+BASE)

class FounderApprovalTests(unittest.TestCase):
    def select(self, reviews=None, pr=None, paths=None):
        return gate.select_review([review()] if reviews is None else reviews,
                                  pr or pull(), paths or ['test/example_test.exs'])

    def test_valid_founder_approval_needs_no_json_or_second_comment(self):
        self.assertEqual(self.select()['id'], 7)

    def test_missing_wrong_reviewer_and_self_review_refuse(self):
        for reviews, pr in [([],pull()),([dict(review(),user=dict(id=2,login='JCSchoeman96'))],pull()),
                            ([review()],dict(pull(),user=dict(id=216185530,login='JCSchoeman96')))]:
            with self.subTest(reviews=reviews), self.assertRaises(AttestationError): self.select(reviews,pr)

    def test_stale_head_base_dismissed_or_changes_requested_refuse(self):
        for changes in [dict(commit_id='e'*40),dict(body='Founder-development base: '+'e'*40),
                        dict(state='DISMISSED'),dict(state='CHANGES_REQUESTED'),dict(state='PENDING')]:
            with self.subTest(changes=changes), self.assertRaises(AttestationError): self.select([dict(review(),**changes)])

    def test_later_comments_do_not_erase_approval_but_changes_do(self):
        self.select([review(),dict(review(),id=8,state='COMMENTED')])
        with self.assertRaises(AttestationError): self.select([review(),dict(review(),id=8,state='CHANGES_REQUESTED')])
        with self.assertRaises(AttestationError):
            self.select([review(),dict(review(),id=8,state='CHANGES_REQUESTED',user=dict(id=9,login='specialist'))])

    def test_higher_risk_authority_paths_and_missing_scope_refuse(self):
        for path in ['tools/founder_gate.py','tools/ci_attestation.py','AGENTS.md',
                     '.github/workflows/ci.yml','docs/governance/law.md',
                     '.agents/skills/ticket-implement/SKILL.md','tools/foundation_integrity_routing.py',
                     'tools/foundation_integrity_audit.py']:
            with self.subTest(path=path), self.assertRaises(AttestationError): self.select(paths=[path])
        with self.assertRaises(AttestationError): self.select([dict(review(),body='Approved')])

    def test_security_ci_implementations_cannot_use_routine_review(self):
        # Real control implementations and their entrypoints, not all tools.
        root = Path(__file__).resolve().parents[1]
        paths = (
            'tools/hex_security_audit.py',
            'tools/ci/cache_manifest.py',
            'tools/ci/prepare_cached_dependencies.sh',
            'tools/architecture/check_ash_writes.exs',
            'tools/architecture/ash_write_boundary.ex',
            'tools/run_foundation_full_tests.py',
            'tools/check_magic_login_evidence.py',
            'tools/check_password_reset_message_evidence.py',
            'tools/__init__.py',
            'mix.exs',
            'lib/mix/tasks/design.check.ex',
        )
        for path in paths:
            with self.subTest(path=path):
                self.assertTrue((root / path).is_file(), 'test must cover a real control')
                with self.assertRaisesRegex(AttestationError, 'requires strict review'):
                    self.select(paths=[path])

    def test_ordinary_tool_changes_remain_eligible(self):
        for path in ('tools/capability_knowledge.py',
                     'docs/development/knowledge/identity.registration.json'):
            with self.subTest(path=path):
                self.assertEqual(7, self.select(paths=[path])['id'])

    def test_approval_rule_missing_stale_protection_or_approval_refuses(self):
        rules=[dict(type='pull_request',parameters=dict(required_approving_review_count=1,
            dismiss_stale_reviews_on_push=True,require_last_push_approval=True,
            required_review_thread_resolution=True,allowed_merge_methods=['merge']))]
        gate.approval_rules(rules)
        for key,value in [('required_approving_review_count',0),('dismiss_stale_reviews_on_push',False),
                          ('require_last_push_approval',False),('allowed_merge_methods',['squash'])]:
            changed=copy.deepcopy(rules);changed[0]['parameters'][key]=value
            with self.subTest(key=key),self.assertRaises(AttestationError): gate.approval_rules(changed)

    def test_failed_missing_or_wrong_candidate_evidence_refuses(self):
        for key,value in [('required_check',None),('candidate_parents',[BASE,'e'*40]),
                          ('current_base','e'*40),('checkout_shas',['e'*40])]:
            changed=evidence();changed[key]=value
            with self.subTest(key=key),self.assertRaises(AttestationError):gate.ci.verify_candidate(changed)

    def test_postmerge_identity_mismatch_refuses(self):
        before={'candidate':evidence()}
        result=dict(method='merge',merge_sha='f'*40,main='f'*40,parents=[BASE,HEAD],tree='d'*40)
        gate.verify_result(before,result)
        for key,value in [('main','e'*40),('parents',[BASE,'e'*40]),('tree','e'*40)]:
            with self.subTest(key=key),self.assertRaises(AttestationError): gate.verify_result(before,dict(result,**{key:value}))

    def test_regular_merge_is_bound_to_head_and_never_bypasses(self):
        with patch.object(gate,'api_write',return_value={'merged':True}) as call:
            gate.merge_request(42,{'candidate':evidence()})
        self.assertEqual(call.call_args.args,(f'repos/{gate.REPO}/pulls/42/merge',dict(sha=HEAD,merge_method='merge'),'PUT'))


class AutomaticMergeLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.before={'candidate':evidence(),'review':{'id':7,'html_url':'review'},'paths':['test/example_test.exs']}
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state=__import__('pathlib').Path(self.temp.name)
        self.stack=__import__('contextlib').ExitStack();self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.object(gate,'trusted_execution'))
        self.stack.enter_context(patch.object(gate,'current_pr',return_value=pull()))
        self.snap=self.stack.enter_context(patch.object(gate,'snapshot',return_value=self.before))
        self.reconcile=self.stack.enter_context(patch.object(gate,'reconcile',return_value={'status':'VERIFIED'}))

    def test_check_is_read_only_and_merge_saves_intent_before_network(self):
        with patch.object(gate,'merge_request') as mutation:
            self.assertEqual('READY_TO_MERGE',gate.execute('check',42,self.state)['status'])
            mutation.assert_not_called()
        def assert_intent(pr,before):
            files=list(self.state.rglob('intent.json'))
            self.assertEqual(1,len(files));self.assertEqual(before,json.loads(files[0].read_text()))
            return {'merged':True}
        with patch.object(gate,'merge_request',side_effect=assert_intent):
            self.assertEqual('VERIFIED',gate.execute('merge',42,self.state)['status'])

    def test_changed_second_snapshot_prevents_merge(self):
        self.snap.side_effect=[self.before,dict(self.before,review={'id':8})]
        with patch.object(gate,'merge_request') as mutation,self.assertRaises(AttestationError):
            gate.execute('merge',42,self.state)
        mutation.assert_not_called()

    def test_lost_response_refuses_second_merge_and_allows_reconciliation(self):
        with patch.object(gate,'merge_request',side_effect=AttestationError('lost reply')) as mutation:
            with self.assertRaises(AttestationError):gate.execute('merge',42,self.state)
            with self.assertRaises(AttestationError):gate.execute('merge',42,self.state)
            self.assertEqual(1,mutation.call_count)
        self.assertEqual('VERIFIED',gate.execute('reconcile',42,self.state)['status'])

    def test_failed_reconciliation_retains_intent(self):
        self.reconcile.side_effect=AttestationError('wrong resulting main')
        with patch.object(gate,'merge_request',return_value={'merged':True}):
            with self.assertRaises(AttestationError):gate.execute('merge',42,self.state)
        self.assertEqual(1,len(list(self.state.rglob('intent.json'))))
        with patch.object(gate,'merge_request') as mutation,self.assertRaises(AttestationError):
            gate.execute('merge',42,self.state)
        mutation.assert_not_called()

class TrustedCheckoutTests(unittest.TestCase):
    def test_dirty_stale_or_wrong_root_checkout_refuses(self):
        for sha,status,root in [('e'*40,b'',str(gate.ROOT)),(BASE,b' M tools/founder_gate.py',str(gate.ROOT)),
                                (BASE,b'','/other/checkout')]:
            def git(*args):
                if args == ('rev-parse','--verify','HEAD'):return sha.encode()
                if args[0] == 'status':return status
                return root.encode()
            with self.subTest(sha=sha,status=status,root=root),patch.object(gate.legacy,'_git',side_effect=git),self.assertRaises(AttestationError):
                gate.trusted_execution(BASE)

    def test_founder_credentials_cannot_execute_implementation_merge(self):
        with patch.object(gate.ci,'_api',return_value=dict(id=216185530,login='JCSchoeman96')),self.assertRaises(AttestationError):
            gate.operator()

    def test_wrong_org_role_cannot_execute_implementation_merge(self):
        with patch.object(gate.ci,'_api',return_value=dict(permission='admin',role_name='admin')),self.assertRaises(AttestationError):
            gate.implementation_permissions()

class SnapshotCollectionTests(unittest.TestCase):
    def setUp(self):
        self.stack=__import__('contextlib').ExitStack();self.addCleanup(self.stack.close)
        self.pr=dict(pull(),state='open',merged=False,draft=False,merge_commit_sha='c'*40)
        self.proof=evidence()
        rule=dict(type='pull_request',parameters=dict(required_approving_review_count=1,
            dismiss_stale_reviews_on_push=True,require_last_push_approval=True,
            required_review_thread_resolution=True,allowed_merge_methods=['merge']))
        self.proof.update(ruleset={'rules':[rule]},effective_rules=[dict(rule,ruleset_id=24191860)])
        self.run=dict(id=100,status='completed',conclusion='success',pull_requests=[dict(number=42)])
        self.api=self.stack.enter_context(patch.object(gate.ci,'_api',return_value=dict(total_count=1,workflow_runs=[self.run])))
        self.stack.enter_context(patch.object(gate.legacy,'founder_account_id'))
        self.stack.enter_context(patch.object(gate,'implementation_permissions'))
        self.stack.enter_context(patch.object(gate,'threads_resolved'))
        self.stack.enter_context(patch.object(gate,'current_pr',return_value=self.pr))
        self.stack.enter_context(patch.object(gate,'canonical_diff',return_value=('e'*64,['test/example_test.exs'])))
        self.reviews=self.stack.enter_context(patch.object(gate.legacy,'_github_list',return_value=[review()]))
        self.stack.enter_context(patch.object(gate.ci,'collect',return_value=self.proof))

    def test_live_snapshot_binds_current_review_candidate_and_ci(self):
        result=gate.snapshot(42)
        self.assertEqual(self.proof,result['candidate']);self.assertEqual(7,result['review']['id'])

    def test_missing_failed_pending_and_wrong_pr_ci_refuse(self):
        for value in [dict(total_count=0,workflow_runs=[]),dict(total_count=1,workflow_runs=[dict(self.run,conclusion='failure')]),
                      dict(total_count=1,workflow_runs=[dict(self.run,status='in_progress')]),
                      dict(total_count=1,workflow_runs=[dict(self.run,pull_requests=[dict(number=43)])])]:
            self.api.return_value=value
            with self.subTest(value=value),self.assertRaises(AttestationError):gate.snapshot(42)

    def test_candidate_or_approval_changes_during_collection_refuse(self):
        self.pr['merge_commit_sha']='f'*40
        with self.assertRaises(AttestationError):gate.snapshot(42)
        self.pr['merge_commit_sha']='c'*40
        self.reviews.side_effect=[[review()],[dict(review(),state='DISMISSED')]]
        with self.assertRaises(AttestationError):gate.snapshot(42)

if __name__=='__main__':unittest.main()
