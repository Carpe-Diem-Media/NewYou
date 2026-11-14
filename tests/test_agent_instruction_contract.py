"""Lightweight checks for the canonical agent contract and its procedural links.

These inspect instructions, not DevCore infrastructure. They never provision or
connect to a database. Commands and section boundaries are intentional contracts.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AgentInstructionContractTests(unittest.TestCase):
    def setUp(self):
        self.agents = (ROOT / 'AGENTS.md').read_text()
        self.ticket = (ROOT / '.agents/skills/ticket-implement/SKILL.md').read_text()
        self.verify = (ROOT / '.agents/skills/code-change-verification/SKILL.md').read_text()
        self.devcore = (ROOT / '.devcore/README.md').read_text()

    def test_devcore_recovery_is_conditional_and_does_not_provision(self):
        policy = self.agents.split('Local DevCore credentials', 1)[1]
        self.assertLess(policy.index('devcore-project doctor'), policy.index('devcore-project render'))
        self.assertRegex(policy, r'only reported problem.*missing or stale.*rendered environment file')
        self.assertIn('rerun "devcore-project doctor"', policy)
        self.assertIn('If doctor passes initially, proceed without render', policy)
        for failure in ('authentication', 'role/ownership', 'central credentials', 'PostgreSQL services'):
            self.assertIn(failure, policy)
        self.assertIn('Do not automatically invoke "devcore-project activate"', policy)
        self.assertIn('separately authorised', policy)
        self.assertIn('Redis is not used', policy)
        self.assertIn('NOCREATEDB', policy)
        self.assertIn('only failure is a missing or stale local rendered environment file', self.devcore)
        self.assertIn('shared services fail', self.devcore)
        for skill in (self.ticket, self.verify):
            self.assertNotRegex(skill, r'(?m)^\s*(?:\d+\. |[-*] )?(?:Run |run )?`?devcore-project (?:activate|render)')
            self.assertIn('AGENTS.md', skill)

    def test_pinned_dev_test_commands_and_no_unwrapped_local_mix_examples(self):
        for document in (self.agents, self.ticket, self.verify, self.devcore):
            for line in document.splitlines():
                if re.search(r'^\s*(?:[-*] )?`?(?:devcore-project run (?:dev|test) -- )?mix ', line):
                    self.fail(f'unpinned local command: {line}')
        for profile in ('dev', 'test'):
            self.assertIn(f'mise exec -- devcore-project run {profile} --', self.agents)
        self.assertIn('DEV and TEST', self.agents)

    def test_verification_policy_separates_focused_and_stable_candidate(self):
        policy = self.agents.split('Verification stages and failure diagnosis', 1)[1].split('### Independent OCR', 1)[0]
        for term in ('Focused development proof', 'Final candidate proof', 'unchanged inputs',
                     'implementation defect', 'test defect', 'environment issue', 'dependency issue',
                     'fixture interference', 'suspected nondeterminism', 'source SHA',
                     'narrowest', 'diagnostic reason', 'Do not weaken', 'stable candidate'):
            self.assertIn(term, policy)
        self.assertIn('mix check', policy)
        self.assertIn('non-executable documentation', policy)
        self.assertIn('Verification stages and failure diagnosis', self.ticket)
        self.assertIn('Verification stages and failure diagnosis', self.verify)

    def test_architecture_gate_is_included_once_at_final_checkpoint(self):
        self.assertIn('"check.architecture"', (ROOT / 'mix.exs').read_text())
        self.assertIn('satisfies the included architecture obligation', self.verify)
        self.assertNotRegex(self.verify, r'Confirm architecture[^\n]*`mise exec -- devcore-project run test -- mix check.architecture` passes')
        self.assertIn('focused development', self.verify)

    def test_identity_and_independent_integration_contract_remains_explicit(self):
        for term in ('gh api user --jq .login', 'JC-Agents', 'JCSchoeman96', 'pr-preflight'):
            self.assertIn(term, self.ticket)
        for term in ('Foundation Smoke', 'Foundation Integrity', 'ocr review --from origin/main --to HEAD',
                     'native-candidate', 'native-result', 'Plane Done'):
            self.assertIn(term, self.verify)
        self.assertIn('after applicable local checks pass', self.ticket)
        self.assertIn('Do not self-certify merge authority', self.ticket)
        self.assertIn('Any head change', self.ticket)
        self.assertIn('mechanical history-only commit', self.verify)

    def test_smoke_runs_instruction_contract_tests(self):
        self.assertIn('python -m unittest tests.test_agent_instruction_contract -v',
                      (ROOT / '.github/workflows/foundation-integrity.yml').read_text())
