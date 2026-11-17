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
                if re.search(r'^\s*(?:[-*] )?(?:(?:DEV|TEST):\s*)?`?(?:devcore-project run (?:dev|test) -- )?(?:mix|elixir|iex) ', line):
                    self.fail(f'unpinned local command: {line}')
            # Labels and inline examples must not hide an unpinned DevCore
            # invocation. Plain references to aliases such as `mix check` are
            # prose, so this guard checks concrete profile commands only.
            self.assertNotRegex(document, r'(?<!mise exec -- )devcore-project run (?:dev|test) -- (?:mix|elixir|iex)\b')
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
        self.assertIn('When a broad verification command fails, diagnose the failure before repeating that broad command.', policy)
        self.assertIn('mix check', policy)
        self.assertIn('non-executable documentation', policy)
        self.assertIn('Verification stages and failure diagnosis', self.ticket)
        self.assertIn('Verification stages and failure diagnosis', self.verify)

    def test_architecture_gate_is_included_once_at_final_checkpoint(self):
        self.assertIn('"check.architecture"', (ROOT / 'mix.exs').read_text())
        self.assertIn('satisfies the included architecture obligation', self.verify)
        self.assertNotRegex(self.verify, r'Confirm architecture[^\n]*`mise exec -- devcore-project run test -- mix check.architecture` passes')
        self.assertIn('focused development', self.verify)
        self.assertIn('do not demand a duplicate final invocation', self.verify)

    def test_identity_and_independent_integration_contract_remains_explicit(self):
        for term in ('gh api user --jq .login', 'JC-Agents', 'JCSchoeman96', 'pr-preflight'):
            self.assertIn(term, self.ticket)
        for term in ('Foundation Smoke', 'Foundation Integrity', 'ocr review --from origin/main --to HEAD',
                     'native-candidate', 'native-result', 'Plane Done'):
            self.assertIn(term, self.verify)
        self.assertIn('after applicable local checks pass', self.ticket)
        self.assertIn('Do not self-certify merge authority', self.ticket)
        self.assertIn('Any head change', self.ticket)
        self.assertIn('tools.knowledge_capture check --metadata-json "$GITHUB_EVENT_PATH"', self.ticket)
        self.assertIn('mechanical history-only commit', self.verify)

    def test_reconnaissance_has_distinct_planning_and_implementation_depth(self):
        discovery = self.ticket.split('## 2.', 1)[1].split('## 3.', 1)[0]
        self.assertIn('Feature-level discovery', discovery)
        self.assertIn('Ready-ticket discovery', discovery)
        planning, implementation = discovery.split('### Ready-ticket discovery', 1)
        for term in ('capabilities', 'Domain', 'Resources', 'interfaces', 'mix.exs', 'mix.lock'):
            self.assertIn(term, planning)
        for term in ('functions', 'actions', 'callers', 'consumers', 'constraints', 'migrations',
                     'configuration', 'pinned', 'return types', 'DSL'):
            self.assertIn(term, implementation)
        self.assertIn('Do not restart feature planning', discovery)

    def test_fitness_choices_allow_justified_introduction_and_cohesion(self):
        for choice in ('REUSE', 'EXTEND', 'COMPOSE', 'INTRODUCE', 'REPLACE'):
            self.assertIn(f'`{choice}`', self.ticket)
        for term in ('Reuse first', 'new Resources, modules, dependencies', 'fitness',
                     'single authoritative Domain', 'forwarding wrappers', 'arbitrary line limits'):
            self.assertIn(term, self.ticket)

    def test_material_elixir_work_loads_existing_tracked_tdd(self):
        relative = '.agents/skills/tdd/SKILL.md'
        self.assertIn(f'**REQUIRED SUB-SKILL:** load `{relative}`', self.ticket)
        tdd = ROOT / relative
        self.assertTrue(tdd.is_file())
        for reference in ('tests.md', 'mocking.md'):
            self.assertIn(reference, tdd.read_text())
            self.assertTrue((tdd.parent / reference).is_file())
        self.assertTrue((tdd.parent / 'agents/openai.yaml').is_file())
        for term in ('Behaviour and Proof Matrix', 'existing implementation plan',
                     'RED → GREEN → REFACTOR', 'LOW', 'STANDARD', 'HIGH'):
            self.assertIn(term, self.ticket)
        for term in ('valid fixture', 'intended guard', 'sensitivity', 'restore', 'durable'):
            self.assertIn(term, self.ticket)
        self.assertIn('proven non-executable documentation', self.ticket)
        self.assertIn('do not force database-backed ExUnit', self.ticket)
        # TDD may discuss broad gates, but must never prescribe their execution.
        for document in (tdd.read_text(), (tdd.parent / 'tests.md').read_text(),
                         (tdd.parent / 'mocking.md').read_text()):
            self.assertNotRegex(document, r'(?m)^\s*(?:mise exec -- (?:devcore-project run test -- )?)?mix check(?:\.deep)?\s*$')

    def test_final_verification_has_one_owner_and_preserves_helper_execution(self):
        for document in (self.ticket, self.verify):
            for term in ('TDD', 'focused', 'ticket-implement', 'code-change-verification',
                         'independent Master Gate', 'local verification → local OCR → exact-head hosted CI → independent Master Gate'):
                self.assertIn(term, document)
        for term in ('single owner', 'where installed and applicable', 'handoff.py',
                     'Do not manually run broad gates before invoking', 'local` stage twice',
                     'receipt caching', 'arbitrary evidence adoption', 'environment', 'comparison base'):
            self.assertIn(term, self.verify)
        self.assertIn('does not independently execute final broad gates', self.ticket)
        self.assertIn('Do not automatically rerun already-valid focused proof', self.verify)
        self.assertIn('final committed-candidate proof', self.verify)
        self.assertIn('proven non-executable documentation', self.verify)

    def test_verification_reviews_quality_and_affected_consumers(self):
        for term in ('valid fixture prerequisites', 'intended guard', 'sensitivity', 'JIT',
                     'Domain ownership', 'terminal states', 'concurrency', 'idempotency',
                     'retry', 'recovery', 'constraints', 'security/privacy', 'action allowlists',
                     'proof catalogs', 'security scans', 'capability knowledge maps', 'hosted CI'):
            self.assertIn(term, self.verify)

    def test_helper_final_local_stage_uses_committed_candidate_before_ocr(self):
        preparation = self.ticket.split('## 8.', 1)[1].split('## 9.', 1)[0]
        self.assertIn('After focused development checks pass, commit the stable source', preparation)
        self.assertIn('before its final `local` stage', preparation)
        self.assertIn('clean committed candidate', preparation)
        self.assertIn('Only after applicable final local checks pass', preparation)
        self.assertIn('run the existing OCR checkpoint', preparation)

    def test_smoke_runs_instruction_contract_tests(self):
        self.assertIn('python -m unittest tests.test_agent_instruction_contract -v',
                      (ROOT / '.github/workflows/foundation-integrity.yml').read_text())
