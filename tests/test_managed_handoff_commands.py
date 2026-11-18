"""Pure command-selection proofs; never start DevCore or Mix."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tests.test_agent_handoff import gate, BINDING
from types import SimpleNamespace

LEGACY = ['mise', 'exec', '--', 'devcore-project', 'run', 'test', '--']
MANAGED = ['mise', 'exec', '--', 'tools/newyou-local', 'test', '--']

class ManagedCommandsTests(unittest.TestCase):
    def test_selection_and_nested_reuse(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(gate, 'ROOT', Path(directory)), patch.dict(os.environ, {}, clear=True):
            root = Path(directory)
            self.assertEqual(gate.test_prefix(), LEGACY)
            (root/'.devcore').mkdir()
            (root/'.devcore/project.conf').write_text('SLOT_POOL=.devcore/slots.json\n')
            self.assertEqual(gate.test_prefix(), MANAGED)
            markers = dict(DEVCORE_SLOT_JOB='job', DEVCORE_SLOT_LEASE='lease', DEVCORE_SLOT_GENERATION='gen', DEVCORE_SLOT_PROJECT='new_you', DEVCORE_SLOT_WORKTREE=str(root))
            with patch.dict(os.environ, markers):
                self.assertEqual(gate.test_prefix(), LEGACY)
            with patch.dict(os.environ, {'DEVCORE_SLOT_JOB':'secret-sentinel'}):
                with self.assertRaises(gate.GateError) as error:
                    gate.test_prefix()
                self.assertNotIn('secret-sentinel', str(error.exception))
            (root/'.devcore/project.conf').write_text('SLOT_POOL=unsupported\n')
            with self.assertRaises(gate.GateError):
                gate.test_prefix()

    def test_normalization_preserves_target_and_rejects_unsafe(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(gate, 'ROOT', Path(directory)), patch.dict(os.environ, {}, clear=True):
            root = Path(directory)
            (root/'test').mkdir()
            (root/'test/example_test.exs').touch()
            (root/'.devcore').mkdir()
            (root/'.devcore/project.conf').write_text('SLOT_POOL=.devcore/slots.json\n')
            target = ['mix', 'test', 'test/example_test.exs:2']
            for prefix in (LEGACY, MANAGED):
                self.assertEqual(gate.focused_kind(prefix+target), 'mix-test')
                self.assertEqual(gate.select_test_command(prefix+target), MANAGED+target)
                for bad in (['mix','test','--dry-run'], ['mix','test','test/example_test.exs',';','env'], ['mix','test']):
                    with self.assertRaises(gate.GateError):
                        gate.focused_kind(prefix+bad)
            for bad in (['true'], ['env'], []):
                with self.assertRaises(gate.GateError):
                    gate.focused_kind(bad)

    def test_non_opt_in_rejects_managed_markers(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(gate, 'ROOT', Path(directory)), patch.dict(os.environ, {'DEVCORE_SLOT_JOB':'private'}, clear=True):
            with self.assertRaises(gate.GateError):
                gate.test_prefix()

    def test_broad_gates_and_admission_failure_never_fall_back(self):
        for nested in (False, True):
            for failure in (False, True):
                with self.subTest(nested=nested, failure=failure), tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    (root/'.devcore').mkdir()
                    (root/'.devcore/project.conf').write_text('SLOT_POOL=.devcore/slots.json\n')
                    env = {('DEVCORE_SLOT_'+k): 'assigned' for k in ('JOB','LEASE','GENERATION','PROJECT','WORKTREE')} if nested else {}
                    calls = []
                    def run(argv, **kwargs):
                        calls.append(argv)
                        kwargs['stdout'].write('Ran 1 test in 0.001s\n\nOK\n')
                        return SimpleNamespace(returncode=1 if failure and len(calls)==2 else 0)
                    with patch.object(gate, 'ROOT', root), patch.dict(os.environ, env, clear=True), patch.object(gate, 'worktree', return_value=(BINDING, [])), patch.object(gate.subprocess, 'run', side_effect=run), patch('builtins.print'):
                        if failure:
                            with self.assertRaises(gate.GateError):
                                gate.local(root/'state.json', BINDING, [], ['python3 -m unittest tests.test_example'], deep=True)
                            self.assertFalse((root/'state.json').exists())
                        else:
                            gate.local(root/'state.json', BINDING, [], ['python3 -m unittest tests.test_example'], deep=True)
                    prefix = LEGACY if nested else MANAGED
                    self.assertEqual(calls[1], prefix+['mix','check'])
                    self.assertEqual(len(calls), 2 if failure else 3)
                    if not failure:
                        self.assertEqual(calls[2], prefix+['mix','check.deep'])
