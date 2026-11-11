"""Founder-development attestation; GitHub identity does not prove human authorship."""
from __future__ import annotations

import json
import re

from tools.ci_attestation import AttestationError, require

REPOSITORY = 'JCSchoeman96/NewYou'


def approval_message(binding: dict) -> str:
    """Return the exact text the owner account must independently publish."""
    return ('NEWYOU FOUNDER DEVELOPMENT REVIEW V1\n'
            + json.dumps(binding, sort_keys=True, separators=(',', ':'))
            + '\nI adopt the independent technical review of the full diff, accept the '
              'founder-development scope and findings, and attest the bound CI evidence. '
              'This review is not merge authorization.')


def merge_authorization_message(binding: dict) -> str:
    return ('NEWYOU FOUNDER DEVELOPMENT MERGE AUTHORIZATION V1\n'
            + json.dumps(binding, sort_keys=True, separators=(',', ':'))
            + '\nI separately authorize a regular merge of this exact candidate.')


def verify_approval(comment: dict, binding: dict, owner_id: int) -> dict:
    """Authenticate a complete, unedited owner-account comment and its exact binding."""
    require(isinstance(comment, dict) and isinstance(owner_id, int) and owner_id > 0,
            'owner approval is missing')
    identifier = comment.get('id')
    require(isinstance(identifier, int) and not isinstance(identifier, bool) and identifier > 0,
            'invalid approval id')
    require(isinstance(comment.get('user'), dict) and comment['user'].get('id') == owner_id
            and comment.get('author_association') == 'OWNER', 'approval is not from owner account')
    require(isinstance(comment['user'].get('login'), str) and bool(comment['user']['login']),
            'owner login is missing')
    created = comment.get('created_at')
    require(isinstance(created, str) and re.fullmatch(r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ', created)
            and comment.get('updated_at') == created, 'approval is edited or lacks timestamp')
    expected_url = f'https://github.com/{REPOSITORY}/pull/{binding["pr"]}#issuecomment-{identifier}'
    require(comment.get('html_url') == expected_url, 'approval URL does not bind the PR')
    require(comment.get('body') == approval_message(binding), 'approval does not bind current evidence')
    return {key: comment[key] for key in ('id', 'user', 'author_association', 'created_at', 'updated_at', 'html_url', 'body')}


class Custody:
    """Private append-only attempts protected by a per-PR/head process lock."""

    def __init__(self, state_home, pr: int, head: str):
        import pathlib
        self.state_home = pathlib.Path(state_home)
        require(self.state_home.is_absolute() and '..' not in self.state_home.parts,
                'state directory must be an absolute safe path')
        require(isinstance(pr, int) and not isinstance(pr, bool) and pr > 0, 'invalid PR')
        require(isinstance(head, str) and re.fullmatch(r'[0-9a-f]{40}', head), 'invalid head')
        self.parts = ('newyou', 'attestations', f'pr-{pr}', head, 'attempts')
        self.fds = []
        self.lock_fd = None

    @staticmethod
    def _directory(parent, name, create, private):
        import os
        import stat
        if create:
            try:
                os.mkdir(name, 0o700, dir_fd=parent)
            except FileExistsError:
                pass
        fd = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
        info = os.fstat(fd)
        if private and (info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o700):
            os.close(fd)
            raise AttestationError('private directory ownership or permissions are unsafe')
        return fd

    @staticmethod
    def _regular(fd):
        import os
        import stat
        info = os.fstat(fd)
        require(stat.S_ISREG(info.st_mode) and info.st_uid == os.geteuid()
                and stat.S_IMODE(info.st_mode) == 0o600 and info.st_nlink == 1,
                'evidence file ownership, type or permissions are unsafe')

    def __enter__(self):
        import fcntl
        import os
        try:
            current = os.open('/', os.O_RDONLY | os.O_DIRECTORY)
            self.fds.append(current)
            # Walk every component without following symlinks, including XDG_STATE_HOME.
            for component in self.state_home.parts[1:]:
                current = self._directory(current, component, True, False)
                self.fds.append(current)
            info = os.fstat(current)
            require(info.st_uid == os.geteuid() and not (info.st_mode & 0o022),
                    'state directory is not controlled by the current user')
            for component in self.parts[:-1]:
                current = self._directory(current, component, True, True)
                self.fds.append(current)
            self.lock_fd = os.open('lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600, dir_fd=current)
            self._regular(self.lock_fd)
            try:
                fcntl.flock(self.lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as exc:
                raise AttestationError('another attestation is already running') from exc
            self.attempts_fd = self._directory(current, 'attempts', True, True)
            self.fds.append(self.attempts_fd)
            return self
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def __exit__(self, *_):
        import os
        if self.lock_fd is not None:
            os.close(self.lock_fd)
            self.lock_fd = None
        while self.fds:
            os.close(self.fds.pop())

    @staticmethod
    def _write(fd, name, data):
        import os
        require(isinstance(data, bytes) and len(data) <= 10_000_000, 'invalid evidence data')
        out = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=fd)
        try:
            with os.fdopen(out, 'wb') as file:
                file.write(data)
                file.flush()
                os.fsync(file.fileno())
        except BaseException:
            raise

    def save_attempt(self, files: dict[str, bytes], name: str | None = None) -> str:
        import hashlib
        import os
        import uuid
        require(bool(files) and all(re.fullmatch(r'[a-z][a-z0-9_.-]{0,63}', n)
                                    and n != 'manifest.json' for n in files), 'invalid evidence filename')
        name = name or uuid.uuid4().hex
        require(isinstance(name, str) and re.fullmatch(r'[0-9a-f]{32}', name), 'invalid attempt')
        os.mkdir(name, 0o700, dir_fd=self.attempts_fd)
        fd = self._directory(self.attempts_fd, name, False, True)
        try:
            manifest = {}
            for filename, data in sorted(files.items()):
                self._write(fd, filename, data)
                manifest[filename] = hashlib.sha256(data).hexdigest()
            sums = ''.join(f'{digest}  {filename}\n' for filename, digest in sorted(manifest.items())).encode()
            self._write(fd, 'SHA256SUMS', sums)
            # This last exclusive creation is the commit marker for a complete attempt.
            self._write(fd, 'manifest.json', (json.dumps(manifest, sort_keys=True) + '\n').encode())
            os.fsync(fd)
            os.fsync(self.attempts_fd)
            return name
        finally:
            os.close(fd)

    def read_attempt(self, name: str) -> dict[str, bytes]:
        import hashlib
        import os
        require(isinstance(name, str) and re.fullmatch(r'[0-9a-f]{32}', name), 'invalid attempt')
        fd = self._directory(self.attempts_fd, name, False, True)
        try:
            def read(filename):
                file = os.open(filename, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=fd)
                try:
                    self._regular(file)
                    with os.fdopen(file, 'rb', closefd=False) as stream:
                        data = stream.read(10_000_001)
                    require(len(data) <= 10_000_000, 'evidence is too large')
                    return data
                finally:
                    os.close(file)
            manifest = json.loads(read('manifest.json'))
            require(isinstance(manifest, dict) and bool(manifest), 'invalid evidence manifest')
            require(set(os.listdir(fd)) == set(manifest) | {'manifest.json', 'SHA256SUMS'}, 'incomplete evidence manifest')
            sums = ''.join(f'{digest}  {filename}\n' for filename, digest in sorted(manifest.items())).encode()
            require(read('SHA256SUMS') == sums, 'SHA256SUMS differs from manifest')
            result = {}
            for filename, digest in manifest.items():
                require(isinstance(filename, str) and re.fullmatch(r'[a-z][a-z0-9_.-]{0,63}', filename)
                        and filename != 'manifest.json' and isinstance(digest, str)
                        and re.fullmatch(r'[0-9a-f]{64}', digest), 'invalid evidence manifest entry')
                data = read(filename)
                require(hashlib.sha256(data).hexdigest() == digest, 'evidence digest mismatch')
                result[filename] = data
            return result
        finally:
            os.close(fd)


def select_approval(comments: list, binding: dict, owner_id: int) -> dict | None:
    """Select the latest owner marker; a later withdrawal or stale marker supersedes it."""
    require(isinstance(comments, list), 'comment list is unavailable')
    candidates = []
    for comment in comments:
        require(isinstance(comment, dict), 'malformed comment list')
        user = comment.get('user')
        if (isinstance(user, dict) and user.get('id') == owner_id
                and isinstance(comment.get('body'), str)
                and comment['body'].startswith('NEWYOU FOUNDER DEVELOPMENT REVIEW V1')):
            require(isinstance(comment.get('id'), int) and comment['id'] > 0, 'invalid comment id')
            candidates.append(comment)
    if not candidates:
        return None
    require(len({c['id'] for c in candidates}) == len(candidates), 'duplicate approval id')
    return verify_approval(max(candidates, key=lambda c: c['id']), binding, owner_id)


def _github_list(path: str) -> list:
    """Fetch every API page; partial or oversized responses are not evidence."""
    import subprocess
    try:
        result = subprocess.run(['gh', 'api', '--paginate', '--slurp', path], check=True,
                                capture_output=True, text=True, timeout=60)
        pages = json.loads(result.stdout)
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        raise AttestationError('cannot retrieve complete GitHub comment list') from exc
    require(isinstance(pages, list) and all(isinstance(page, list) for page in pages),
            'invalid GitHub comment pages')
    comments = [comment for page in pages for comment in page]
    require(len(comments) <= 10_000, 'too many comments to establish approval')
    return comments


def owner_comments(pr: int) -> list:
    return _github_list(f'repos/{REPOSITORY}/issues/{pr}/comments?per_page=100')


def _git(*args: str) -> bytes:
    import os
    import subprocess
    environment = dict(os.environ, GIT_NO_REPLACE_OBJECTS='1', GIT_TERMINAL_PROMPT='0')
    try:
        return subprocess.run(['git', *args], check=True, capture_output=True,
                              env=environment, timeout=120).stdout
    except (OSError, subprocess.SubprocessError) as exc:
        raise AttestationError('cannot verify trusted Git objects') from exc


def git_diff_digest(base: str, head: str) -> str:
    import hashlib
    for value in (base, head):
        require(isinstance(value, str) and re.fullmatch(r'[0-9a-f]{40}', value), 'invalid Git object id')
    # Fetch immutable objects from the canonical repository, not a caller-selected URL.
    _git('fetch', '--no-tags', '--no-write-fetch-head', 'https://github.com/JCSchoeman96/NewYou.git', base, head)
    patch = _git('diff', '--binary', '--no-ext-diff', '--no-textconv', base, head)
    return hashlib.sha256(patch).hexdigest()


def gather_before(pr: int) -> tuple[dict, dict, int]:
    from tools import ci_attestation as ci
    require(isinstance(pr, int) and not isinstance(pr, bool) and pr > 0, 'invalid PR number')
    info = ci._api(f'repos/{REPOSITORY}/pulls/{pr}')
    head, base = info['head']['sha'], info['base']['sha']
    runs = ci._api(f'repos/{REPOSITORY}/actions/workflows/foundation-integrity.yml/runs?event=pull_request&head_sha={head}&per_page=100')
    require(isinstance(runs.get('workflow_runs'), list) and runs.get('total_count', 101) <= 100,
            'cannot establish latest CI run')
    candidates = [run for run in runs['workflow_runs']
                  if any(p.get('number') == pr for p in run.get('pull_requests', []))]
    require(bool(candidates) and isinstance(candidates[0].get('id'), int), 'no associated CI run')
    run_id = candidates[0]['id']
    run = ci._api(f'repos/{REPOSITORY}/actions/runs/{run_id}')
    require(run.get('status') == 'completed' and run.get('conclusion') == 'success'
            and isinstance(run.get('updated_at'), str), 'CI run is not complete and successful')
    require(run.get('html_url') == f'https://github.com/{REPOSITORY}/actions/runs/{run_id}',
            'CI run URL is inconsistent')
    proof = ci.collect(pr, head, run_id, trust_mode='public-protected')
    require(ci._api(f'repos/{REPOSITORY}/actions/runs/{run_id}') == run, 'CI run changed during collection')
    require(proof['base'] == base and proof['head'] == head, 'PR changed during collection')
    repository = ci._api(f'repos/{REPOSITORY}')
    owner = repository.get('owner', {})
    require(repository.get('full_name') == REPOSITORY and isinstance(owner.get('id'), int)
            and owner.get('login') == REPOSITORY.split('/')[0], 'repository owner is unverifiable')
    binding = {'pr': pr, 'base': base, 'head': head, 'candidate': proof['candidate'], 'tree': proof['tree'],
               'diff_sha256': git_diff_digest(base, head), 'run_id': run_id,
               'run_attempt': proof['run_attempt'], 'check_id': proof['required_check']['id'],
               'ci_completed_at': run['updated_at'], 'ci_url': run['html_url']}
    return binding, proof, owner['id']


def gather_after(pr: int, binding: dict, before: dict) -> dict:
    from tools import ci_attestation as ci
    run = ci._api(f'repos/{REPOSITORY}/actions/runs/{binding["run_id"]}')
    require(run.get('updated_at') == binding['ci_completed_at'] and run.get('html_url') == binding['ci_url']
            and run.get('status') == 'completed' and run.get('conclusion') == 'success', 'CI identity changed')
    require(git_diff_digest(binding['base'], binding['head']) == binding['diff_sha256'],
            'reviewed diff digest changed')
    return ci.collect(pr, binding['head'], binding['run_id'], candidate_sha=before['candidate'],
                      after_merge=True, trust_mode='public-protected')


def _json_bytes(value) -> bytes:
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def source_urls(binding: dict) -> dict:
    api = f'https://api.github.com/repos/{REPOSITORY}'
    return {'pull_request': f'{api}/pulls/{binding["pr"]}',
            'run': f'{api}/actions/runs/{binding["run_id"]}',
            'check': f'{api}/check-runs/{binding["check_id"]}',
            'candidate': f'{api}/git/commits/{binding["candidate"]}',
            'ruleset': f'{api}/rulesets/24191860',
            'comments': f'{api}/issues/{binding["pr"]}/comments'}


def prepare(pr: int, state_home) -> dict:
    """Collect CI, request owner-account adoption, then persist a pre-merge proof."""
    import copy
    import uuid
    from tools import ci_attestation as ci
    binding, proof, owner_id = gather_before(pr)
    ci.verify_candidate(proof)
    with Custody(state_home, pr, binding['head']) as custody:
        approval = select_approval(owner_comments(pr), binding, owner_id)
        if approval is None:
            result = {'status': 'AWAITING_OWNER_REVIEW', 'binding': binding,
                      'approval_text': approval_message(binding)}
            custody.save_attempt({'status.json': _json_bytes(result), 'ci.json': _json_bytes(proof),
                                  'sources.json': _json_bytes(source_urls(binding)), 'exit.json': _json_bytes({'exit': 2}),
                                  'stdout.txt': _json_bytes(result), 'stderr.txt': b''})
            return result
        verify_approval_freshness(approval, binding['ci_completed_at'], utc_now())
        # Re-collect exact candidate and owner comment immediately before saving.
        fresh_binding, fresh_proof, fresh_owner = gather_before(pr)
        require((fresh_binding, fresh_proof, fresh_owner) == (binding, proof, owner_id),
                'candidate or CI changed while verifying approval')
        require(select_approval(owner_comments(pr), binding, owner_id) == approval,
                'owner approval changed while collecting evidence')
        review = {'reviewed_head': binding['head'], 'reviewer': approval['user']['login'],
                  'review_reference': approval['html_url'], 'diff_sha256': binding['diff_sha256'],
                  'mode': 'founder-development', 'owner_account_id': owner_id,
                  'approval_id': approval['id']}
        ci.validate_review_record(review, binding['head'])
        before = copy.deepcopy(proof)
        before['review_record'] = review
        verify_evidence_binding(before, binding, review, approval, owner_id)
        record = {'status': 'PREMERGE_VERIFIED', 'binding': binding, 'owner_id': owner_id,
                  'approval': approval}
        attempt = uuid.uuid4().hex
        outcome = {'status': 'PREMERGE_VERIFIED', 'attempt': attempt, 'binding': binding,
                   'message': 'Separate owner merge authorization remains required.',
                   'merge_authorization_text': merge_authorization_message(binding)}
        custody.save_attempt({'status.json': _json_bytes(record), 'review.json': _json_bytes(review),
                                        'before.json': _json_bytes(before), 'sources.json': _json_bytes(source_urls(binding)),
                                        'exit.json': _json_bytes({'exit': 0}),
                                        'stdout.txt': _json_bytes(outcome), 'stderr.txt': b''}, name=attempt)
        stored = custody.read_attempt(attempt)
        require(json.loads(stored['before.json']) == before, 'saved pre-merge evidence differs')
        return outcome


def verify_after(pr: int, head: str, state_home) -> dict:
    """Recheck the original owner adoption, candidate and resulting-main tree."""
    import copy
    import os
    import uuid
    from tools import ci_attestation as ci
    with Custody(state_home, pr, head) as custody:
        choices = []
        for name in sorted(os.listdir(custody.attempts_fd)):
            if not re.fullmatch(r'[0-9a-f]{32}', name):
                raise AttestationError('unsafe attempt directory')
            attempt_fd = custody._directory(custody.attempts_fd, name, False, True)
            try:
                try:
                    os.stat('manifest.json', dir_fd=attempt_fd, follow_symlinks=False)
                except FileNotFoundError:
                    # Incomplete attempts have no commit marker and cannot be reused.
                    continue
            finally:
                os.close(attempt_fd)
            # A missing file in a committed attempt is corruption, not an interruption.
            files = custody.read_attempt(name)
            status = json.loads(files['status.json'])
            if status.get('status') == 'PREMERGE_VERIFIED':
                require(set(files) == {'status.json', 'review.json', 'before.json', 'sources.json', 'exit.json', 'stdout.txt', 'stderr.txt'},
                        'invalid pre-merge evidence package')
                require(json.loads(files['exit.json']) == {'exit': 0}, 'pre-merge collection failed')
                require(json.loads(files['sources.json']) == source_urls(status['binding']), 'source URLs changed')
                choices.append((name, status, json.loads(files['review.json']), json.loads(files['before.json'])))
        require(bool(choices), 'no valid pre-merge evidence exists for this PR and head')
        repository = ci._api(f'repos/{REPOSITORY}')
        owner_id = repository.get('owner', {}).get('id')
        require(repository.get('full_name') == REPOSITORY and isinstance(owner_id, int),
                'repository owner changed')
        comments = owner_comments(pr)
        markers = [c for c in comments if isinstance(c, dict) and isinstance(c.get('user'), dict)
                   and c['user'].get('id') == owner_id and isinstance(c.get('id'), int)
                   and isinstance(c.get('body'), str)
                   and c['body'].startswith('NEWYOU FOUNDER DEVELOPMENT REVIEW V1')]
        require(bool(markers), 'owner approval was removed')
        latest_id = max(c['id'] for c in markers)
        require(latest_id >= max(s['approval']['id'] for _, s, _, _ in choices),
                'latest recorded owner approval was removed')
        eligible = [(n, s, r, b) for n, s, r, b in choices
                    if s['owner_id'] == owner_id and s['approval']['id'] == latest_id]
        require(bool(eligible), 'latest owner approval has no matching pre-merge proof')
        name, status, review, before = eligible[0]
        require(all((s, r, b) == (status, review, before) for _, s, r, b in eligible),
                'conflicting pre-merge attempts')
        binding = status['binding']
        require(binding['pr'] == pr and binding['head'] == head, 'stored evidence is for another PR or head')
        require(select_approval(comments, binding, owner_id) == status['approval'],
                'owner approval was removed, edited or superseded')
        verify_evidence_binding(before, binding, review, status['approval'], owner_id)
        merged = ci._api(f'repos/{REPOSITORY}/pulls/{pr}')
        require(merged.get('merged') is True, 'PR has not been merged')
        verify_approval_freshness(status['approval'], binding['ci_completed_at'], merged.get('merged_at'))
        authorizations = [c for c in comments if isinstance(c, dict) and isinstance(c.get('user'), dict)
                          and c['user'].get('id') == owner_id and isinstance(c.get('body'), str)
                          and c['body'].startswith('NEWYOU FOUNDER DEVELOPMENT MERGE AUTHORIZATION V1')]
        require(bool(authorizations), 'separate merge authorization is missing')
        authorization = max(authorizations, key=lambda c: c.get('id', 0))
        require(isinstance(authorization.get('id'), int)
                and authorization['id'] > status['approval']['id'],
                'merge authorization must follow owner adoption')
        require(authorization.get('body') == merge_authorization_message(binding),
                'merge authorization differs or has been superseded')
        # Apply the same account, PR URL and unedited-comment checks.
        equivalent = dict(authorization, body=approval_message(binding))
        verify_approval(equivalent, binding, owner_id)
        verify_approval_freshness(authorization, status['approval']['created_at'], merged.get('merged_at'))
        result = gather_after(pr, binding, before)
        candidate = copy.deepcopy(result['candidate'])
        candidate['review_record'] = review
        require(candidate == before, 'live candidate differs from saved pre-merge proof')
        ci.verify_result(before, result['result'])
        require(select_approval(owner_comments(pr), binding, status['owner_id']) == status['approval'],
                'owner approval changed during reconciliation')
        require(authorization in owner_comments(pr), 'merge authorization changed during reconciliation')
        after = {'status': 'POSTMERGE_VERIFIED', 'premerge_attempt': name, 'result': result,
                 'merge_authorization': authorization}
        attempt = uuid.uuid4().hex
        outcome = {'status': 'POSTMERGE_VERIFIED', 'attempt': attempt, 'merge_sha': result['result']['merge_sha'],
                   'message': 'Independent resulting-main certification and Plane reconciliation remain required.'}
        custody.save_attempt({'status.json': _json_bytes({'status': 'POSTMERGE_VERIFIED', 'premerge_attempt': name}),
                                        'after.json': _json_bytes(after), 'exit.json': _json_bytes({'exit': 0}),
                                        'stdout.txt': _json_bytes(outcome), 'stderr.txt': b''}, name=attempt)
        custody.read_attempt(attempt)
        return outcome


def verify_approval_freshness(approval: dict, ci_completed_at: str, as_of: str) -> None:
    """Approvals expire after seven days and must follow the bound completed run."""
    from datetime import datetime, timedelta, timezone
    def parse(value):
        require(isinstance(value, str) and re.fullmatch(r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ', value),
                'invalid approval or CI timestamp')
        try:
            return datetime.strptime(value, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
        except ValueError as exc:
            raise AttestationError('invalid approval or CI timestamp') from exc
    approved, completed, current = parse(approval.get('created_at')), parse(ci_completed_at), parse(as_of)
    require(completed <= approved <= current < approved + timedelta(days=7),
            'approval is stale, precedes CI or is dated in the future')


def utc_now() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def require_integrated_mode() -> None:
    """Do not activate proposed founder-mode code from an unmerged PR checkout."""
    from tools import ci_attestation as ci
    remote = ci._api(f'repos/{REPOSITORY}/commits/main').get('sha')
    head = _git('rev-parse', '--verify', 'HEAD').decode().strip()
    require(isinstance(remote, str) and re.fullmatch(r'[0-9a-f]{40}', remote) and head == remote,
            'founder mode requires a trusted checkout of current integrated main')
    _git('diff', '--quiet', '--')
    _git('diff', '--cached', '--quiet', '--')
    _git('ls-files', '--error-unmatch', 'tools/newyou_attest.py')


def verify_evidence_binding(before: dict, binding: dict, review: dict, approval: dict, owner_id: int) -> None:
    """Reject saved records that do not describe the same candidate and adoption."""
    from tools import ci_attestation as ci
    ci.verify_candidate(before)
    for field in ('pr', 'head', 'base', 'candidate', 'tree', 'run_id', 'run_attempt'):
        require(before.get(field) == binding.get(field), 'stored candidate binding differs')
    require(before['required_check']['id'] == binding.get('check_id'), 'stored check binding differs')
    expected = {'reviewed_head': binding['head'], 'reviewer': approval['user']['login'],
                'review_reference': approval['html_url'], 'diff_sha256': binding['diff_sha256'],
                'mode': 'founder-development', 'owner_account_id': owner_id, 'approval_id': approval['id']}
    require(review == expected and before.get('review_record') == review, 'stored review binding differs')
    ci.validate_review_record(review, binding['head'])


def main(argv=None) -> int:
    import argparse
    import os
    from pathlib import Path
    from tools import ci_attestation as ci
    parser = argparse.ArgumentParser(description='Founder-development evidence collection; never merges.')
    parser.add_argument('operation', choices=('prepare', 'verify-after'))
    parser.add_argument('--pr', type=int, required=True, help='pull request number')
    args = parser.parse_args(argv)
    if args.pr <= 0:
        print('ATTESTATION_FAILED: PR number must be positive')
        return 1
    state = Path(os.environ.get('XDG_STATE_HOME') or (Path.home() / '.local' / 'state'))
    try:
        require_integrated_mode()
    except (AttestationError, OSError, ValueError, KeyError, TypeError):
        print('ATTESTATION_FAILED: use a clean trusted checkout of current integrated main with GitHub access')
        return 1
    try:
        if args.operation == 'prepare':
            outcome = prepare(args.pr, state)
        else:
            pr = ci._api(f'repos/{REPOSITORY}/pulls/{args.pr}')
            require(pr.get('merged') is True, 'PR has not been merged')
            outcome = verify_after(args.pr, pr['head']['sha'], state)
        print(json.dumps(outcome, sort_keys=True, indent=2))
        return 2 if outcome['status'] == 'AWAITING_OWNER_REVIEW' else 0
    except (AttestationError, OSError, ValueError, KeyError, TypeError):
        # Never print subprocess stderr, untrusted review text, tokens or private evidence.
        # Retain a sanitized failed attempt when the live PR head remains available.
        message = 'ATTESTATION_FAILED: evidence is missing, changed or invalid; verify PR, owner comment, CI and private custody'
        try:
            pr = ci._api(f'repos/{REPOSITORY}/pulls/{args.pr}')
            head = pr['head']['sha']
            with Custody(state, args.pr, head) as custody:
                custody.save_attempt({'status.json': _json_bytes({'status': 'FAILED', 'phase': args.operation}),
                                      'exit.json': _json_bytes({'exit': 1}), 'stdout.txt': (message + '\n').encode(),
                                      'stderr.txt': b''})
        except (AttestationError, OSError, ValueError, KeyError, TypeError):
            pass
        print(message)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
