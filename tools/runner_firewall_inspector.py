#!/usr/bin/python3 -I
"""Root-installed read-only discovery. Never authorizes a runner or guest."""
import json
import os
from pathlib import Path
import re
import selectors
import stat
import subprocess
import sys
import time

COMMANDS = {
    'nft': ('/usr/sbin/nft', '-j', 'list', 'ruleset'),
    'iptables': ('/usr/sbin/iptables-save', '-c', '-t', 'filter'),
    'ebtables': ('/usr/sbin/ebtables-save',),
}
LIMIT = 8 * 1024 * 1024
DEADLINE = 8


def trusted_executable(path):
    # Fixed system commands must not resolve through a writable executable or
    # parent. No caller-supplied paths, arguments or environment are accepted.
    source = Path(path)
    remaining = [32]
    def check_chain(candidate):
        remaining[0] -= 1
        if remaining[0] < 0:
            raise ValueError('untrusted_executable')
        for item in [*reversed(candidate.parents), candidate]:
            info = item.lstat()
            if info.st_uid != 0:
                raise ValueError('untrusted_executable')
            if stat.S_ISLNK(info.st_mode):
                target = Path(os.readlink(item))
                check_chain(target if target.is_absolute() else item.parent / target)
            elif info.st_mode & 0o022:
                raise ValueError('untrusted_executable')
    check_chain(source)
    resolved = source.resolve(strict=True)
    if not stat.S_ISREG(resolved.stat().st_mode):
        raise ValueError('untrusted_executable')
    return resolved


def frontend(path):
    try:
        name = trusted_executable(path).name
        if name == 'xtables-nft-multi':
            return 'nft_compat'
        if name == 'xtables-legacy-multi':
            return 'legacy'
    except Exception:
        pass
    return 'unknown'


def read_backend(backend):
    if backend not in COMMANDS:
        raise ValueError('unsupported_backend')
    args = COMMANDS[backend]
    trusted_executable(args[0])
    environment = {'PATH': '/usr/sbin:/usr/bin:/sbin:/bin', 'LC_ALL': 'C', 'HOME': '/root'}
    proc = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, env=environment, close_fds=True)
    output = bytearray()
    deadline = time.monotonic() + DEADLINE
    try:
        os.set_blocking(proc.stdout.fileno(), False)
        with selectors.DefaultSelector() as selector:
            selector.register(proc.stdout, selectors.EVENT_READ)
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not selector.select(remaining):
                    raise RuntimeError('inspection_timeout')
                chunk = os.read(proc.stdout.fileno(), 65536)
                if not chunk:
                    break
                output.extend(chunk)
                if len(output) > LIMIT:
                    raise RuntimeError('inspection_limit')
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError('inspection_timeout')
        proc.wait(timeout=remaining)
        if proc.returncode:
            raise RuntimeError('inspection_failed')
        return output.decode('utf-8')
    finally:
        if proc.poll() is None:
            proc.kill()
        proc.wait()
        proc.stdout.close()


def project_nft(data):
    if not isinstance(data, dict) or not isinstance(data.get('nftables'), list):
        raise ValueError('unsupported_ruleset')
    report = dict.fromkeys(['ip_filter_table', 'bridge_filter_table',
                           'nwfilter_chain_candidates', 'counter_statements'], 'absent')
    for item in data['nftables']:
        if not isinstance(item, dict):
            raise ValueError('unsupported_ruleset')
        table = item.get('table', {})
        if table.get('name') == 'filter' and table.get('family') == 'ip':
            report['ip_filter_table'] = 'present'
        if table.get('name') == 'filter' and table.get('family') == 'bridge':
            report['bridge_filter_table'] = 'present'
        chain = item.get('chain', {})
        name = chain.get('name', '')
        if isinstance(name, str) and re.fullmatch(r'(?:FI|FO|HI)-vnet[0-9]+|libvirt-[IO]-vnet[0-9]+', name):
            report['nwfilter_chain_candidates'] = 'present'
        for expression in item.get('rule', {}).get('expr', []):
            if isinstance(expression, dict) and 'counter' in expression:
                report['counter_statements'] = 'present'
    return report


def inspect():
    report = {'schema': 1, 'enforcement': 'unverified',
              'frontends': {'iptables': frontend(COMMANDS['iptables'][0]),
                            'ebtables': frontend(COMMANDS['ebtables'][0])},
              'reads': {}, 'kernel_metadata': 'unavailable'}
    for backend in COMMANDS:
        try:
            raw = read_backend(backend)
            if backend == 'nft':
                report['kernel_metadata'] = project_nft(json.loads(raw))
            report['reads'][backend] = 'observed'
        except Exception:
            report['reads'][backend] = 'unavailable'
        # Raw rules are never printed, spooled or returned to the caller.
    return report


def main():
    if len(sys.argv) != 1 or os.geteuid() != 0:
        return 1
    print(json.dumps(inspect(), sort_keys=True))
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception:
        # Root paths, rule text, error messages and caller input never escape.
        raise SystemExit(1) from None
