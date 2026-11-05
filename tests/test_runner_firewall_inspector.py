"""Privileged discovery exports fixed metadata, never raw firewall data."""
import json
from unittest import TestCase
from unittest.mock import patch
from tools import runner_firewall_inspector as inspector


class FirewallInspectorTest(TestCase):
    def test_projection_omits_sensitive_rule_data_and_never_certifies(self):
        rules = {'nftables': [
            {'table': {'family': 'ip', 'name': 'filter'}},
            {'table': {'family': 'bridge', 'name': 'filter'}},
            {'chain': {'name': 'libvirt-in', 'table': 'filter', 'family': 'ip'}},
            {'chain': {'name': 'FI-vnet9', 'table': 'filter', 'family': 'ip'}},
            {'rule': {'expr': [{'counter': {'packets': 7, 'bytes': 42}}, {'SECRET_ADDRESS': 'SECRET'}]}}
        ]}
        report = inspector.project_nft(rules)
        self.assertEqual(report['nwfilter_chain_candidates'], 'present')
        self.assertEqual(report['counter_statements'], 'present')
        self.assertNotIn('SECRET', json.dumps(report))
        self.assertNotIn('vnet9', json.dumps(report))

    def test_read_failure_is_unavailable_not_certified(self):
        with patch.object(inspector, 'read_backend', side_effect=RuntimeError('SECRET')), patch.object(inspector, 'frontend', return_value='unknown'):
            report = inspector.inspect()
        self.assertEqual(report['enforcement'], 'unverified')
        self.assertTrue(all(x == 'unavailable' for x in report['reads'].values()))
        self.assertNotIn('SECRET', json.dumps(report))

    def test_only_fixed_read_commands_are_allowed(self):
        with self.assertRaises(ValueError):
            inspector.read_backend('SECRET')

    def test_arguments_and_nonroot_callers_are_rejected_before_inspection(self):
        for argv, uid in [(['inspector', 'anything'], 0), (['inspector'], 1000)]:
            with patch.object(inspector.sys, 'argv', argv), patch.object(inspector.os, 'geteuid', return_value=uid), patch.object(inspector, 'inspect') as inspect:
                self.assertEqual(inspector.main(), 1)
                inspect.assert_not_called()

    def test_output_and_deadline_are_bounded_without_root_commands(self):
        import sys
        from pathlib import Path
        with patch.dict(inspector.COMMANDS, {'nft': (sys.executable, '-I', '-c', 'print("SECRET" * 1000)')}), patch.object(inspector, 'trusted_executable', return_value=Path(sys.executable)), patch.object(inspector, 'LIMIT', 32):
            with self.assertRaisesRegex(RuntimeError, 'inspection_limit'):
                inspector.read_backend('nft')
        with patch.dict(inspector.COMMANDS, {'nft': (sys.executable, '-I', '-c', 'import time; time.sleep(1)')}), patch.object(inspector, 'trusted_executable', return_value=Path(sys.executable)), patch.object(inspector, 'DEADLINE', .05):
            with self.assertRaisesRegex(RuntimeError, 'inspection_timeout'):
                inspector.read_backend('nft')

    def test_malformed_rules_fail_closed(self):
        with self.assertRaises(ValueError):
            inspector.project_nft({'nftables': 'SECRET'})
        with patch.object(inspector, 'frontend', return_value='nft_compat'), patch.object(inspector, 'read_backend', return_value='SECRET'):
            report = inspector.inspect()
        self.assertEqual(report['reads']['nft'], 'unavailable')
        self.assertEqual(report['kernel_metadata'], 'unavailable')
        self.assertEqual(report['enforcement'], 'unverified')

    def test_writable_intermediate_symlink_path_is_rejected(self):
        import stat
        from pathlib import Path
        from types import SimpleNamespace
        original_lstat = Path.lstat
        original_readlink = inspector.os.readlink
        def lstat(path, *args, **kwargs):
            if str(path) == '/home/unsafe':
                return SimpleNamespace(st_uid=1000, st_mode=stat.S_IFDIR | 0o755)
            if str(path) == '/home/unsafe/proxy':
                return SimpleNamespace(st_uid=0, st_mode=stat.S_IFLNK | 0o777)
            return original_lstat(path, *args, **kwargs)
        def readlink(path, *args, **kwargs):
            if str(path) == '/usr/sbin/iptables-save':
                return '/home/unsafe/proxy'
            if str(path) == '/home/unsafe/proxy':
                return '/usr/sbin/xtables-nft-multi'
            return original_readlink(path, *args, **kwargs)
        with patch.object(Path, 'lstat', lstat), patch.object(inspector.os, 'readlink', readlink), patch.object(Path, 'resolve', return_value=Path('/usr/sbin/xtables-nft-multi')):
            with self.assertRaises(ValueError):
                inspector.trusted_executable('/usr/sbin/iptables-save')
