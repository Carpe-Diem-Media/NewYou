"""A failed or unsupported policy inspection is never proof of no grant."""
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase
from tools import runner_guest_privilege as privilege


class PrivilegePolicyTest(TestCase):
    def fixture(self, directory):
        root = Path(directory)
        (root / 'sudoers.d').mkdir()
        (root / 'sudoers').write_text('Defaults env_reset\nroot ALL=(ALL:ALL) ALL\n%sudo ALL=(ALL:ALL) ALL\n%admin ALL=(ALL) ALL\n@includedir /etc/sudoers.d\n')
        (root / 'sudo.conf').write_text('# stock default plugins\n')
        (root / 'nsswitch.conf').write_text('sudoers: files\n')
        for path in root.iterdir():
            path.chmod(0o700 if path.is_dir() else 0o600)
        return root

    def test_supported_policy_affirmatively_has_no_runner_grant(self):
        with TemporaryDirectory() as directory:
            root = self.fixture(directory)
            privilege.verify_policy(root, {'runner'}, owner=root.stat().st_uid)

    def test_grant_unsupported_policy_and_inspection_failure_are_rejected(self):
        for change in ['grant', 'group_grant', 'read_failure', 'plugin', 'ldap', 'unsupported', 'symlink', 'numeric_uid', 'admin_grant']:
            with self.subTest(change=change), TemporaryDirectory() as directory:
                root = self.fixture(directory)
                if change == 'grant':
                    (root / 'sudoers.d' / 'grant').write_text('runner ALL=(ALL) ALL\n')
                    (root / 'sudoers.d' / 'grant').chmod(0o600)
                elif change in {'group_grant', 'admin_grant'}:
                    pass
                elif change == 'read_failure':
                    (root / 'sudoers').unlink()
                elif change == 'plugin':
                    (root / 'sudo.conf').write_text('Plugin custom custom.so\n')
                elif change == 'ldap':
                    (root / 'nsswitch.conf').write_text('sudoers: files ldap\n')
                elif change == 'unsupported':
                    (root / 'sudoers').write_text('Defaults group_plugin="custom.so"\n')
                elif change == 'numeric_uid':
                    (root / 'sudoers').write_text('#1000 ALL=(ALL) ALL\n')
                else:
                    (root / 'sudoers.d' / 'link').symlink_to(root / 'sudoers')
                with self.assertRaises((ValueError, OSError)):
                    privilege.verify_policy(root, {'runner', 'sudo'} if change == 'group_grant' else {'runner', 'admin'} if change == 'admin_grant' else {'runner'}, owner=root.stat().st_uid)

    def test_unsafe_policy_files_and_unknown_includes_fail_closed(self):
        for change in ['writable', 'fifo', 'unknown_include', 'duplicate_sources', 'oversize']:
            with self.subTest(change=change), TemporaryDirectory() as directory:
                root = self.fixture(directory)
                if change == 'writable':
                    (root / 'sudoers').chmod(0o666)
                elif change == 'fifo':
                    import os
                    (root / 'sudoers').unlink()
                    os.mkfifo(root / 'sudoers')
                elif change == 'unknown_include':
                    (root / 'sudoers').write_text('@include /elsewhere\n')
                elif change == 'duplicate_sources':
                    (root / 'nsswitch.conf').write_text('sudoers: files\nsudoers : ldap\n')
                else:
                    (root / 'sudoers').write_text('#' * 65537)
                with self.assertRaises((ValueError, OSError)):
                    privilege.verify_policy(root, {'runner'}, owner=root.stat().st_uid)
