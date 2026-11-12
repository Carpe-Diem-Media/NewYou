"""Live founder-development merge checks, run only from clean integrated main.

GitHub reviews authenticate the founder account, not a physical second person.
Higher-risk work keeps the strict review route. This module never reads approval
assertions from PR files and never executes the candidate's code.
"""
from __future__ import annotations
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import hashlib
from tools import ci_attestation as ci
from tools import newyou_attest as legacy
from tools.ci_attestation import AttestationError, require

REPO = legacy.REPOSITORY
AGENT_ID = 355419376
ROOT = Path(__file__).resolve().parent.parent
PROTECTED = {'AGENTS.md', 'tools/founder_gate.py', 'tools/ci_attestation.py',
             'tools/newyou_attest.py', 'tools/newyou-attest',
             '.agents/skills/code-change-verification/SKILL.md',
             'docs/development/foundation-integrity-merge-gate.md',
             'docs/development/github-branch-governance.md',
             'docs/development/chatgpt-project-master-gate-instructions.md',
             'docs/development/solo-founder-merge-handoff.md'}


def encode(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()


def select_review(reviews, pr, paths):
    """The single authenticated review also declares eligible scope and base.

    The plain-text line is part of the technical review, not a second approval
    comment or an attestation file. Higher-risk consequences must never receive
    this declaration; protected authority changes always use strict review.
    """
    require(pr.get('user', {}).get('id') == AGENT_ID
            and pr['user'].get('login') == 'JC-Agents', 'PR author must be JC-Agents')
    require(not any(p in PROTECTED or p.startswith(('.github/', '.agents/', 'docs/governance/', 'tools/foundation_integrity_'))
                    for p in paths), 'higher-risk authority change requires strict review')
    opinions = {}
    for r in sorted(reviews, key=lambda r: r['id']):
        if r.get('state') in ('APPROVED', 'CHANGES_REQUESTED', 'DISMISSED'):
            opinions[r['user']['id']] = r
    require(not any(r['state'] == 'CHANGES_REQUESTED' for r in opinions.values()),
            'unresolved change request')
    r = opinions.get(legacy.FOUNDER_ID, {})
    require(r.get('user', {}).get('login') == legacy.FOUNDER_LOGIN
            and r.get('state') == 'APPROVED', 'valid founder approval is missing')
    require(r.get('commit_id') == pr['head']['sha'], 'founder approval is stale')
    require(re.findall(r'^Founder-development base: ([0-9a-f]{40})$', r.get('body') or '', re.M)
            == [pr['base']['sha']], 'eligible scope or exact reviewed base is missing or stale')
    require(r.get('html_url') == f'https://github.com/{REPO}/pull/{pr["number"]}#pullrequestreview-{r["id"]}',
            'review belongs to another PR')
    return {k: r[k] for k in ('id', 'commit_id', 'html_url')}


def approval_rules(rules):
    """Require server-enforced approval and stale-review protection, no new App."""
    p = next((r.get('parameters', {}) for r in rules if r.get('type') == 'pull_request'), {})
    require(type(p.get('required_approving_review_count')) is int
            and p['required_approving_review_count'] >= 1
            and all(p.get(k) is True for k in ('dismiss_stale_reviews_on_push',
                      'require_last_push_approval', 'required_review_thread_resolution'))
            and p.get('allowed_merge_methods') == ['merge'],
            'native approval/stale-review/regular-merge protection is not configured')


def current_pr(pr):
    require(type(pr) is int and pr > 0, 'invalid PR number')
    return ci._api(f'repos/{REPO}/pulls/{pr}')

def canonical_diff(base, head):
    """Fetch canonical immutable objects into a new bare store; never run PR code."""
    require(all(isinstance(s, str) and re.fullmatch('[0-9a-f]{40}', s) for s in (base, head)), 'invalid Git SHA')
    env = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
    env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='/dev/null', GIT_NO_REPLACE_OBJECTS='1',
               GIT_TERMINAL_PROMPT='0')
    with tempfile.TemporaryDirectory(prefix='newyou-canonical-') as directory:
        def git(*args):
            try:
                return subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', *args], cwd=directory,
                                      env=env, capture_output=True, check=True, timeout=120).stdout
            except (OSError, subprocess.SubprocessError) as exc:
                raise AttestationError('canonical Git collection failed') from exc
        git('init', '--bare', '--quiet')
        git('fetch', '--quiet', '--no-tags', f'https://github.com/{REPO}.git', base, head)
        patch = git('diff', '--binary', '--no-ext-diff', '--no-textconv', base, head)
        paths = git('diff', '--no-renames', '--name-only', '-z', base, head)
        return hashlib.sha256(patch).hexdigest(), [p.decode('utf-8', errors='strict') for p in paths.split(b'\0') if p]


def threads_resolved(pr):
    query = '''query($endCursor:String){repository(owner:"Carpe-Diem-Media",name:"NewYou"){
      pullRequest(number:PR_NUMBER){reviewThreads(first:100,after:$endCursor){
      nodes{isResolved} pageInfo{hasNextPage endCursor}}}}}'''.replace('PR_NUMBER', str(pr))
    result = json.loads(ci._command('gh', 'api', 'graphql', '--paginate', '--slurp', '-f', 'query=' + query))
    require(isinstance(result, list) and bool(result), 'review thread list unavailable')
    for page in result:
        require(not page.get('errors'), 'review threads could not be verified')
        threads = page['data']['repository']['pullRequest']['reviewThreads']
        require(all(t.get('isResolved') is True for t in threads['nodes']), 'CHANGES_REQUIRED: unresolved review threads')
    require(result[-1]['data']['repository']['pullRequest']['reviewThreads']['pageInfo']['hasNextPage'] is False,
            'review thread list incomplete')


def implementation_permissions():
    response = ci._api(f'repos/{REPO}/collaborators/JC-Agents/permission')
    require(response.get('permission') == 'write' and response.get('role_name') == 'write',
            'BLOCKED_BY_POLICY: implementation identity retains elevated repository authority')
    member = ci._api('orgs/Carpe-Diem-Media/memberships/JC-Agents')
    require(member.get('state') == 'active' and member.get('role') == 'member'
            and member.get('user', {}).get('id') == AGENT_ID, 'BLOCKED_BY_POLICY: agent organization role is unsafe')


def api_write(path, payload, method='POST'):
    """Transmit JSON on stdin; never expose tokens or untrusted stderr."""
    try:
        result = subprocess.run(['gh', 'api', '--method', method, path, '--input', '-'], input=encode(payload),
                                capture_output=True, check=True, timeout=60)
        return json.loads(result.stdout) if result.stdout.strip() else {}
    except (OSError, subprocess.SubprocessError, ValueError) as exc:
        raise AttestationError('GitHub mutation failed; inspect live state before retry') from exc


def trusted_execution(base=None):
    expected = base or ci._api(f'repos/{REPO}/commits/main')['sha']
    head = legacy._git('rev-parse', '--verify', 'HEAD').decode().strip()
    require(head == expected and not legacy._git('status', '--porcelain', '--untracked-files=all'),
            'BLOCKED_BY_POLICY: use a clean trusted integrated-main checkout')
    require(legacy._git('rev-parse', '--show-toplevel').decode().strip() == str(ROOT),
            'BLOCKED_BY_POLICY: command directory differs from trusted code')


def operator():
    identity = ci._api('user')
    require(identity.get('id') == AGENT_ID and identity.get('login') == 'JC-Agents',
            'BLOCKED_BY_POLICY: operation requires JC-Agents credentials')


def merge_request(pr, before):
    return api_write(f'repos/{REPO}/pulls/{pr}/merge', dict(sha=before['candidate']['head'], merge_method='merge'), 'PUT')


def snapshot(pr_number):
    """Read authoritative GitHub state; reuse existing exact CI/candidate checks."""
    legacy.founder_account_id(ci._api(f'repos/{REPO}'))
    implementation_permissions()
    pr = current_pr(pr_number)
    require(pr.get('state') == 'open' and pr.get('merged') is False and pr.get('draft') is False
            and pr.get('base', {}).get('ref') == 'main', 'PR is not ready against main')
    diff, paths = canonical_diff(pr['base']['sha'], pr['head']['sha'])
    selected = select_review(legacy._github_list(f'repos/{REPO}/pulls/{pr_number}/reviews?per_page=100'), pr, paths)
    threads_resolved(pr_number)
    runs = ci._api(f'repos/{REPO}/actions/workflows/foundation-integrity.yml/runs?event=pull_request&head_sha={pr["head"]["sha"]}&per_page=100')
    require(runs.get('total_count', 0) <= 100, 'CI listing incomplete')
    relevant = [r for r in runs.get('workflow_runs', [])
                if any(p.get('number') == pr_number for p in r.get('pull_requests', []))]
    require(bool(relevant), 'required CI is missing')
    run = relevant[0]
    require(run.get('status') == 'completed' and run.get('conclusion') == 'success', 'required CI failed or pending')
    proof = ci.collect(pr_number, pr['head']['sha'], run['id'], trust_mode='public-protected')
    approval_rules(proof['ruleset']['rules'])
    approval_rules([r for r in proof['effective_rules'] if r.get('ruleset_id') == 24191860])
    require(proof['base'] == pr['base']['sha'] and proof['candidate'] == pr['merge_commit_sha'], 'candidate changed')
    require(selected == select_review(legacy._github_list(f'repos/{REPO}/pulls/{pr_number}/reviews?per_page=100'),
                                      current_pr(pr_number), paths), 'approval changed during collection')
    return dict(candidate=proof, review=selected, diff_sha256=diff, paths=paths)


def verify_result(before, result):
    ci.verify_result(before['candidate'], result)


def reconcile(pr, before):
    candidate = before['candidate']
    # This reads GitHub and original hosted job logs; it runs no tests or candidate code.
    live = ci.collect(pr, candidate['head'], candidate['run_id'], candidate_sha=candidate['candidate'],
                      after_merge=True, trust_mode='public-protected')
    require(live['candidate'] == candidate, 'candidate/check evidence changed after merge')
    verify_result(before, live['result'])
    return dict(status='VERIFIED', main=live['result']['main'], tree=live['result']['tree'],
                parents=live['result']['parents'], review=before['review']['html_url'])


def latest_intent(custody):
    intents = []
    for name in sorted(os.listdir(custody.attempts_fd)):
        files = custody.read_attempt(name)
        if 'intent.json' in files:
            intents.append(json.loads(files['intent.json']))
    require(len(intents) <= 1, 'conflicting merge intents')
    return intents[0] if intents else None


def execute(operation, pr, state):
    """One automatic intent, existing locked custody, no manual evidence inputs.

    A lost response never causes an automatic second merge. Reconcile is read-only
    and retryable; an unmerged uncertain request needs an explicit recovery decision.
    """
    pull = current_pr(pr)
    with legacy.Custody(state, pr, pull['head']['sha']) as custody:
        intent = latest_intent(custody)
        if operation == 'reconcile':
            require(intent is not None, 'saved merge intent is missing')
            trusted_execution(intent['candidate']['base'])
            result = reconcile(pr, intent)
            custody.save_attempt({'result.json': encode(result)})
            return result
        trusted_execution()
        require(intent is None, 'previous merge outcome needs reconciliation; no automatic retry')
        before = snapshot(pr)
        if operation == 'check':
            p = before['candidate']
            return dict(status='READY_TO_MERGE', head=p['head'], base=p['base'],
                        candidate=p['candidate'], tree=p['tree'], review=before['review']['html_url'])
        require(snapshot(pr) == before, 'live approval, base, candidate, rules or CI changed')
        # save_attempt fsyncs files/directories and commits a manifest before network mutation.
        custody.save_attempt({'intent.json': encode(before)})
        response = merge_request(pr, before)
        require(response.get('merged') is True, 'merge rejected or uncertain; reconcile before retry')
        result = reconcile(pr, before)
        custody.save_attempt({'result.json': encode(result)})
        return result


def main(argv=None):
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('check', 'merge', 'reconcile'))
    parser.add_argument('--pr', type=int, required=True)
    args = parser.parse_args(argv)
    try:
        operator()
        state = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state')
        result = execute(args.operation, args.pr, state)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (AttestationError, OSError, ValueError, KeyError, TypeError):
        # API and subprocess diagnostics may contain sensitive values. Do not echo them.
        print(json.dumps(dict(status='BLOCKED', next='Inspect live GitHub state; do not retry an uncertain merge.')))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
