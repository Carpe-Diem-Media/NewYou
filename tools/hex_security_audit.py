#!/usr/bin/env python3
"""Fresh, unsuppressed Hex audit. Only independently approved evidence can pass.

The temporary project declares every locked Hex package as an exact root. It
never evaluates the application's mix.exs, config, aliases or application code.
No existing Hex/Mix home, environment suppression or registry cache is reused.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import urllib.request

HEX_VERSION = '2.6.0'
APPROVED_SUMMARY = 'Unverified Sign in with Apple callback parameter can override verified ID token claims'
APPROVED_URL = 'https://osv.dev/vulnerability/EEF-CVE-2026-117656'
APPROVAL = 'd9d80575-34d9-41cb-9879-5823873cb68a'
IDS = {'EEF-CVE-2026-117656', 'CVE-2026-117656', 'GHSA-9fr5-g44g-9526'}
# A change requires a new independent disposition, never an author-updated hash alone.
APPROVED_INPUT_DIGEST = '2c4e97e5ca481ed7f436a87d770f56b64162e82722bcffe990f355e023ec21c1'


class AuditError(Exception):
    """Missing, invalid or unacceptable audit evidence. Always fail closed."""


def input_digest(root: Path) -> str:
    """Bind the full lock/toolchain and all production source/config, including additions."""
    paths = [root / p for p in ('mix.exs', 'mix.lock', '.tool-versions',
             'test/new_you_web/security/authentication_reachability_test.exs')]
    for directory in ('lib', 'config'):
        paths.extend(p for p in (root / directory).rglob('*') if p.is_file())
    digest = hashlib.sha256()
    for path in sorted(paths):
        digest.update(path.relative_to(root).as_posix().encode() + b'\0' + path.read_bytes() + b'\0')
    return digest.hexdigest()


def disposition(evidence: dict, status: int, exception: dict, root: Path) -> str:
    """Validate pinned Hex evidence, then apply an exact, bounded disposition."""
    try:
        if evidence['version'] != '2.1.0' or len(evidence['runs']) != 1:
            raise ValueError('SARIF version/run count')
        run = evidence['runs'][0]
        driver = run['tool']['driver']
        if driver['name'] != 'mix hex.audit' or driver['version'] != HEX_VERSION:
            raise ValueError('unexpected scanner/version')
        results, rules = run['results'], driver['rules']
        if not isinstance(results, list) or not isinstance(rules, list):
            raise ValueError('results/rules must be arrays')
        if status != (1 if results else 0):
            raise AuditError(f'Hex audit failed or exit status contradicts evidence: {status}')
        if exception:
            expected = {'state': 'active', 'owner': 'JC', 'package': 'assent', 'version': '0.2.13',
                        'expires_on': '2026-11-18', 'follow_up': 'WELL-91', 'approval_comment': APPROVAL,
                        'input_digest': APPROVED_INPUT_DIGEST}
            if any(exception.get(k) != v for k, v in expected.items()):
                raise AuditError('Unauthorised or inactive exception metadata')
            if input_digest(root) != APPROVED_INPUT_DIGEST:
                raise AuditError('Exception invalidated by changed dependency/source/config inputs')
        if not results:
            if exception:
                raise AuditError('Active exception is unmatched; resolve it through review')
            if rules:
                raise ValueError('rules without findings')
            return 'CLEAN: fresh unsuppressed Hex audit found no advisories or retirements'
        if not exception:
            raise AuditError('Unexpected advisory or retirement without an approved exception')
        if len(results) != 1:
            raise AuditError('Unexpected additional advisory or retirement')
        result = results[0]
        rule_id = result['ruleId']
        if type(result['ruleIndex']) is not int or result['ruleIndex'] != 0 or result.get('suppressions'):
            raise AuditError('Malformed or suppressed finding')
        args = result['message']['arguments']
        if (rule_id not in IDS or rules[result['ruleIndex']]['id'] != rule_id
                or len(rules) != 1 or len(args) != 5 or args[:2] != ['assent', '0.2.13']
                or result['partialFingerprints']['hexAudit/v1'] != f'advisory:hexpm/assent:{rule_id}'):
            raise AuditError('Unexpected advisory/package/version or malformed finding')
        match = re.fullmatch(r'([^ ()]+)(?: \(aka ([^()]+)\))?', args[2])
        aliases = set(match[2].split(', ')) if match and match[2] else set()
        if not match or match[1] != rule_id or ({rule_id} | aliases) != IDS:
            raise AuditError('Unexpected advisory alias evidence')
        rule = rules[0]
        if (args[3:] != [APPROVED_SUMMARY, APPROVED_URL]
                or rule['shortDescription']['text'] != APPROVED_SUMMARY
                or rule['helpUri'] != APPROVED_URL
                or rule['properties'] != {'tags': ['security'], 'security-severity': '9.5'}):
            raise AuditError('Advisory evidence changed; independent revalidation required')
        # Read UTC only after all evidence and input checks, immediately before
        # granting the disposition. A run may cross expiry while Hex is running.
        now = dt.datetime.now(dt.timezone.utc)
        approved_at = dt.datetime(2026, 11, 4, tzinfo=dt.timezone.utc)
        expires_at = dt.datetime.fromisoformat(exception['expires_on']).replace(tzinfo=dt.timezone.utc)
        if now < approved_at or now >= expires_at:
            raise AuditError('Exception expired or not yet valid')
        return ('CONTROLLED DISPOSITION: unsuppressed Hex audit FAILED for assent 0.2.13; '
                f'{rule_id}; JC; WELL-91; approval {APPROVAL}; expires at 2026-11-18T00:00:00Z. '
                'Dependency remains vulnerable. This is not a clean audit.')
    except (KeyError, TypeError, IndexError, ValueError) as error:
        raise AuditError(f'Invalid/malformed Hex audit evidence: {error}') from error


def locked_dependencies(lock: str) -> str:
    """Accept only the repository's canonical hexpm lock shape; reject unknown entries."""
    entries = []
    lines = lock.strip().splitlines()
    if lines[0] != '%{' or lines[-1] != '}':
        raise AuditError('Invalid committed lock')
    for line in lines[1:-1]:
        # Hex does not scan Git dependencies. Preserve their lock entries but
        # never fetch/execute them in this package-registry audit.
        if re.fullmatch(r'  "[a-z0-9_]+": \{:git, "https://github.com/[a-zA-Z0-9_/.-]+", "[a-f0-9]{40}", \[.*\]\},', line):
            continue
        match = re.fullmatch(r'  "([a-z0-9_]+)": \{:hex, :([a-z0-9_]+), "([0-9][a-zA-Z0-9.+-]*)", .*\},', line)
        if not match or '], "hexpm", "' not in line:
            raise AuditError('Unsupported lock entry; review required')
        app, package, version = match.groups()
        entries.append(f'{{:{app}, "== {version}", hex: :{package}}}')
    if not entries:
        raise AuditError('Empty lock cannot establish audit coverage')
    return ',\n'.join(entries)


def latest_authentication_release() -> str:
    """A new stable parent release invalidates the retained compatibility assessment.

    Conservatively require review for any new stable release, even if it still
    excludes patched Assent. Prereleases are never installation authority.
    """
    with urllib.request.urlopen('https://hex.pm/api/packages/ash_authentication', timeout=30) as response:
        value = json.load(response)['latest_stable_version']
    if not isinstance(value, str) or not re.fullmatch(r'\d+\.\d+\.\d+', value):
        raise AuditError('Malformed stable authentication release evidence')
    return value


def latest_supported_assent_release() -> str:
    """Detect stable backports within the approved parent's supported 0.2 range."""
    with urllib.request.urlopen('https://hex.pm/api/packages/assent', timeout=30) as response:
        releases = json.load(response)['releases']
    versions = []
    for release in releases:
        version = release['version']
        if not isinstance(version, str):
            raise AuditError('Malformed Assent release evidence')
        if re.fullmatch(r'0\.2\.\d+', version):
            versions.append(tuple(map(int, version.split('.'))))
    if not versions:
        raise AuditError('Missing supported Assent release evidence')
    return '.'.join(map(str, max(versions)))


def execute(root: Path) -> str:
    """Install pinned Hex, resolve the unchanged lock and run the real CLI once."""
    lock = (root / 'mix.lock').read_text()
    deps = locked_dependencies(lock)
    exception = json.loads((root / 'tools/hex_audit/assent_exception.json').read_text())
    if exception and latest_authentication_release() != '4.15.1':
        raise AuditError('New stable authentication release requires independent revalidation')
    if exception and latest_supported_assent_release() != '0.2.13':
        raise AuditError('Supported Assent release changed; independent revalidation required')
    with tempfile.TemporaryDirectory(prefix='newyou-hex-audit-') as directory:
        work = Path(directory)
        env = {k: v for k, v in os.environ.items()
               if not k.startswith(('HEX_', 'MIX_', 'ERL_', 'ELIXIR_'))}
        env.update(HEX_HOME=str(work / 'hex'), MIX_HOME=str(work / 'mix'), MIX_ENV='prod')
        (work / 'mix.lock').write_text(lock)
        (work / 'mix.exs').write_text('defmodule SecurityAudit.MixProject do\n use Mix.Project\n'
            ' def project, do: [app: :security_audit, version: "0.0.0", deps: [\n' + deps + '\n]]\nend\n')
        commands = [(['mix', 'local.hex', HEX_VERSION, '--force'], 'Pinned Hex installation'),
                    (['mix', 'deps.get', '--check-locked'], 'Committed lock resolution'),
                    (['mix', 'hex.audit', '--format', 'sarif', '--output', 'audit.sarif'], 'Fresh Hex audit')]
        for command, label in commands:
            print(f'{label}: {" ".join(command)}', flush=True)
            result = subprocess.run(command, cwd=work, env=env, check=False, timeout=600)
            if label != 'Fresh Hex audit' and result.returncode != 0:
                raise AuditError(f'{label} failed with status {result.returncode}')
        if (work / 'mix.lock').read_text() != lock:
            raise AuditError('Committed lock changed during audit resolution')
        report = work / 'audit.sarif'
        if not report.is_file():
            raise AuditError(f'Fresh Hex audit failed to produce evidence, status {result.returncode}')
        evidence = json.loads(report.read_text())
        print(report.read_text(), flush=True)
        return disposition(evidence, result.returncode, exception, root)


def main() -> int:
    try:
        print(execute(Path(__file__).resolve().parents[1]))
        return 0
    except (AuditError, OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f'HEX SECURITY AUDIT FAILURE: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
