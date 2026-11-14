"""Conservative local sudo policy proof. No policy text leaves the guest."""
import grp
import os
from pathlib import Path
import pwd
import stat


# Deliberately narrow: unfamiliar valid policy requires review, never inference.
RULES = {
    'root ALL=(ALL:ALL) ALL': None,
    '%sudo ALL=(ALL:ALL) ALL': 'sudo',
    '%admin ALL=(ALL) ALL': 'admin',
}
DEFAULTS = {'Defaults env_reset', 'Defaults mail_badpass',
            'Defaults use_pty',
            'Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"'}


def read_policy(path, owner):
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != owner or info.st_mode & 0o022:
            raise ValueError('unsafe_policy')
        data = stream.read(65537)
    if len(data) > 65536:
        raise ValueError('unsupported_policy')
    return data.decode('utf-8').splitlines()


def verify_policy(root, runner_groups, owner=0):
    # No alternate policy plugins or remote NSS policy sources are supported.
    for line in read_policy(root / 'sudo.conf', owner):
        if line.strip() and not line.lstrip().startswith('#'):
            raise ValueError('unsupported_policy')
    seen = False
    for line in read_policy(root / 'nsswitch.conf', owner):
        line = line.split('#', 1)[0]
        name, separator, sources = line.partition(':')
        if separator and name.strip() == 'sudoers':
            if seen or sources.split() != ['files']:
                raise ValueError('unsupported_policy')
            seen = True
    paths = [root / 'sudoers']
    included = False
    for path in paths:
        for raw in read_policy(path, owner):
            line = ' '.join(raw.split())
            if line in {'@includedir /etc/sudoers.d', '#includedir /etc/sudoers.d'}:
                if included or path != root / 'sudoers':
                    raise ValueError('unsupported_policy')
                directory = root / 'sudoers.d'
                info = directory.lstat()
                if not stat.S_ISDIR(info.st_mode) or info.st_uid != owner or info.st_mode & 0o022:
                    raise ValueError('unsafe_policy')
                entries = sorted(directory.iterdir())
                if len(entries) > 32:
                    raise ValueError('unsupported_policy')
                paths.extend(entries)
                included = True
            elif line.startswith(('#include', '@include')):
                raise ValueError('unsupported_policy')
            elif line.startswith('#') and line[1:2].isdigit():
                # Numeric sudoers UIDs are rules, not comments.
                raise ValueError('unsupported_policy')
            elif not line or line.startswith('#') or line in DEFAULTS:
                continue
            elif line in RULES:
                if RULES[line] in runner_groups:
                    raise ValueError('privilege_grant')
            else:
                # Includes explicit user grants, aliases and unknown Defaults.
                raise ValueError('unsupported_policy')


def main():
    account = pwd.getpwnam('runner')
    if account.pw_uid == 0 or pwd.getpwnam('root').pw_uid != 0:
        raise ValueError('privilege_grant')
    groups = {grp.getgrgid(gid).gr_name for gid in os.getgrouplist('runner', account.pw_gid)}
    verify_policy(Path('/etc'), groups)


if __name__ == '__main__':
    try:
        main()
    except Exception:
        # No file names, policy text, identity data or exception text exported.
        raise SystemExit(1) from None
