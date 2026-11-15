"""Local-only, fail-closed implementation handoff for WELL-125.

Private evidence lives in this worktree's Git directory. It is an execution
receipt, not approval or durable business authority. GitHub evidence collection
reuses ci_attestation; this module never changes GitHub state or runs in CI.
OCR v1 schema verified against alibaba/open-code-review 7e5ce06, v1.13.10.
"""
from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
from uuid import uuid4

# Make repository modules importable when this skill script is run by path.
sys.path.insert(0, str(Path(__file__).resolve().parents[4]))

from tools import ci_attestation
from tools.foundation_integrity_routing import classify_changed_paths, classify_deep_application_changes

REPO = 'Carpe-Diem-Media/NewYou'
ROOT = Path.cwd()
DEFAULT_BUDGET = 100000
HISTORY_EXCLUDE = 'docs/development/knowledge/history/pr-*.json'
EXCLUDE_REASONS = {'user_exclude', 'unsupported_ext', 'default_path', 'secret_exclude',
                   'provider_directory', 'deleted', 'binary', 'too_large'}


class GateError(ValueError):
    """Required evidence is missing, stale, failed, or cannot be interpreted."""


def require(condition, message):
    if not condition:
        raise GateError(message)


def command(*args, timeout=60):
    """Execute argv without a shell. Never include captured diagnostics in errors."""
    try:
        return subprocess.run(args, cwd=ROOT, check=True, capture_output=True,
                              text=True, timeout=timeout).stdout.strip()
    except (OSError, subprocess.SubprocessError) as exc:
        raise GateError(f'{args[0]} failed or unavailable; no evidence accepted') from exc


def decode(text):
    """Reject duplicate JSON keys rather than letting a later value hide a failure."""
    def unique(pairs):
        value = {}
        for key, item in pairs:
            require(key not in value, 'duplicate JSON key')
            value[key] = item
        return value
    return json.loads(text, object_pairs_hook=unique)


def api(path):
    return decode(command('gh', 'api', f'repos/{REPO}/{path}'))


def worktree():
    """Resolve the actual cwd, including detached linked worktrees, without writes."""
    require(not command('git', 'status', '--porcelain'), 'a clean committed worktree is required')
    origin = command('git', 'remote', 'get-url', 'origin')
    require(origin in (f'git@github.com:{REPO}.git', f'https://github.com/{REPO}.git',
                       f'https://github.com/{REPO}'), 'origin is not the canonical NewYou repository')
    head = command('git', 'rev-parse', 'HEAD')
    base = command('git', 'rev-parse', 'origin/main')
    binding = dict(head=head, base=base, merge_base=command('git', 'merge-base', base, head),
                   tree=command('git', 'rev-parse', 'HEAD^{tree}'))
    require(all(re.fullmatch('[0-9a-f]{40}', sha) for sha in binding.values()), 'unresolved Git identity')
    paths = command('git', 'diff', '--name-only', '-z', f'{binding["merge_base"]}..{head}').strip('\0').split('\0')
    return binding, [p for p in paths if p]


def validate_pr(pr, head):
    require(isinstance(pr, dict), 'invalid PR association')
    require(pr.get('state') == 'open', 'absent open PR association')
    require(pr.get('head', {}).get('sha') == head, 'stale PR head association')
    require(pr.get('base', {}).get('ref') == 'main'
            and pr['base'].get('repo', {}).get('full_name') == REPO
            and pr['head'].get('repo', {}).get('full_name') == REPO, 'PR repository/base mismatch')
    return pr


def discover_pr(head, override=None):
    """Use branch context then exact remote head association, never T3 UI metadata.

    The commit endpoint is bounded deliberately. A full page fails closed rather
    than guessing whether a later page could contain another exact association.
    """
    if override is not None:
        return validate_pr(api(f'pulls/{override}'), head)
    branch_number = None
    try:
        branch_number = decode(command('gh', 'pr', 'view', '--json', 'number')).get('number')
    except (GateError, ValueError):
        pass
    prs = api(f'commits/{head}/pulls?per_page=100')
    require(isinstance(prs, list) and len(prs) < 100, 'PR associations unavailable or truncated')
    opened = [p for p in prs if p.get('state') == 'open']
    exact = [p for p in opened if p.get('head', {}).get('sha') == head]
    require(len(exact) < 2, 'ambiguous exact-head PR associations; use --pr after investigation')
    require(exact, 'stale PR association' if opened else 'absent open PR association')
    number = exact[0]['number']
    if branch_number == number:
        return validate_pr(api(f'pulls/{branch_number}'), head)
    return validate_pr(api(f'pulls/{number}'), head)


def require_local(state, binding):
    require(state.get('binding') == binding, 'stale or missing local verification binding')
    results = state.get('local')
    require(isinstance(results, list) and results and all(r.get('exit_code') == 0 for r in results),
            'local verification failed or is missing')


def validate_ci(evidence, binding, *, application, deep):
    require(evidence.get('head') == binding['head'] == evidence.get('reviewed_head')
            and evidence.get('base') == binding['base'] == evidence.get('premerge_main'), 'stale CI head/base')
    require(evidence.get('candidate_parents') == [binding['base'], binding['head']], 'stale CI candidate/base')
    jobs = evidence.get('jobs', [])
    names = [j.get('name') for j in jobs]
    require(len(names) == len(set(names)), 'duplicate CI jobs')
    expected = ['Route CI lanes', 'Foundation Smoke', 'Foundation Integrity']
    if application:
        expected.append('Application CI / mix check')
    if deep:
        expected.append('Application CI / mix check.deep')
    for name in expected:
        matching = [j for j in jobs if j.get('name') == name]
        require(len(matching) == 1 and matching[0].get('status') == 'completed'
                and matching[0].get('conclusion') == 'success', f'missing or unsuccessful required check: {name}')


def collect_ci(binding, paths, override):
    """Read hosted exact-head proof. ci_attestation checks logs and candidate tree.

    collect does not require or create approval. The reviewed_head argument only
    binds the candidate being inspected, before independent Master Gate review.
    """
    pr = discover_pr(binding['head'], override)
    require(pr['base']['sha'] == binding['base'], 'stale local origin/main or PR base')
    runs = api(f'actions/workflows/foundation-integrity.yml/runs?event=pull_request&head_sha={binding["head"]}&per_page=100')
    require(runs.get('total_count', 101) <= 100, 'workflow list unavailable or truncated')
    matching = [r for r in runs.get('workflow_runs', [])
                if any(p.get('number') == pr['number'] for p in r.get('pull_requests', []))]
    require(matching, 'missing required exact-head Foundation Integrity run')
    run = matching[0]
    require(run.get('status') == 'completed' and run.get('conclusion') == 'success',
            'exact-head CI pending, failed, or cancelled; final handoff blocked')
    try:
        evidence = ci_attestation.collect(pr['number'], binding['head'], run['id'], trust_mode='public-protected')
    except ci_attestation.AttestationError as exc:
        raise GateError(f'hosted candidate verification failed: {exc}') from exc
    route = classify_changed_paths(paths, pr_number=pr['number'])
    validate_ci(evidence, binding, application=route['application_changes'],
                deep=classify_deep_application_changes(paths))
    return dict(pr=pr['number'], url=pr['html_url'], evidence=evidence)


def path_map(items, label):
    require(isinstance(items, list), f'{label} must be an array')
    result = {}
    for item in items:
        require(isinstance(item, dict) and isinstance(item.get('path'), str) and item['path'], f'invalid {label} item')
        require(item['path'] not in result, f'duplicate {label} path')
        result[item['path']] = item
    return result


def validate_preview(preview, paths):
    require(isinstance(preview, dict), 'invalid OCR preview')
    files = path_map(preview.get('files'), 'preview')
    require(set(files) == set(paths) and preview.get('total_files') == len(paths), 'unknown or missing preview coverage')
    require(all(type(i.get('will_review')) is bool for i in files.values()), 'unknown preview selection')
    selected = [i for i in files.values() if i['will_review']]
    excluded = [i for i in files.values() if not i['will_review']]
    require(selected, 'no eligible files; explicit manual exemption/review required, no OCR pass')
    require(preview.get('reviewable_count') == len(selected) and preview.get('excluded_count') == len(excluded),
            'inconsistent preview counts')
    require(all(not i.get('exclude_reason') for i in selected)
            and all(i.get('exclude_reason') in EXCLUDE_REASONS for i in excluded), 'unknown exclusion reason')
    return preview


def ocr_args(binding, budget, exclude):
    require(type(budget) is int and budget > 0, 'a positive soft token budget is required')
    args = ['ocr', 'review', '--from', binding['merge_base'], '--to', binding['head'],
            '--provider', 'chatgpt', '--effort', 'low', '--concurrency', '1',
            '--max-tokens-budget', str(budget), '--format', 'json', '--audience', 'agent']
    if exclude:
        args += ['--exclude', exclude]
    return args


def verify_base(binding):
    remote = command('git', 'ls-remote', 'origin', 'refs/heads/main')
    require(remote.split() == [binding['base'], 'refs/heads/main'],
            'stale origin/main; fetch and refresh affected local/OCR proof')


def prepare_preview(state, binding, paths, *, budget=DEFAULT_BUDGET, exclude=HISTORY_EXCLUDE):
    # Local verification is the only prerequisite. No PR or CI calls here.
    require_local(state, binding)
    verify_base(binding)
    preview = validate_preview(decode(command(*ocr_args(binding, budget, exclude), '--preview')), paths)
    return dict(preview=preview, budget=budget, exclude=exclude)


def proof_binding(state, final, pr_number):
    """Allow only generated history commits after the scanned implementation.

    Check every intervening commit and the complete tree diff. A source change
    followed by a revert is not a mechanical history chain. Knowledge capture
    separately validates the history contents against live final PR metadata.
    """
    scanned = state.get('binding', {})
    require_local(state, scanned)
    require(scanned.get('base') == final['base'] and scanned.get('merge_base') == final['merge_base'],
            'comparison base changed; fresh local/OCR proof required')
    if scanned == final:
        return dict(implementation=scanned['head'], history_only=None)
    command('git', 'merge-base', '--is-ancestor', scanned['head'], final['head'])
    history = f'docs/development/knowledge/history/pr-{pr_number}.json'
    changed = command('git', 'diff', '--name-only', '-z', scanned['head'], final['head']).strip('\0').split('\0')
    require(changed == [history], 'source changed after local/OCR proof; only generated history may reuse it')
    commits = command('git', 'rev-list', '--parents', f'{scanned["head"]}..{final["head"]}').splitlines()
    require(commits, 'missing history-only commit chain')
    for line in commits:
        commit = line.split()
        require(len(commit) == 2, 'merge commits cannot reuse local/OCR evidence')
        changed = command('git', 'diff-tree', '--no-commit-id', '--name-only', '-r', '-z', commit[0]).strip('\0').split('\0')
        require(changed == [history], 'non-mechanical commit invalidates local/OCR evidence')
    return dict(implementation=scanned['head'], history_only=history)


def validate_reuse_preview(scanned, final, history):
    previous = path_map(scanned.get('files'), 'scanned preview')
    current = path_map(final.get('files'), 'final preview')
    if history:
        require(current.get(history, {}).get('will_review') is False
                and current[history].get('exclude_reason') == 'user_exclude',
                'newly eligible history file cannot reuse OCR evidence')
        current.pop(history)
        previous.pop(history, None)
    require(previous == current, 'selected inputs/exclusions changed; fresh OCR required')


def validate_knowledge(pr_number, directory):
    metadata = api(f'pulls/{pr_number}')
    path = directory / 'pr-metadata.json'
    path.write_text(json.dumps(metadata))
    path.chmod(0o600)
    output = command('mise', 'exec', '--', 'python3', '-m', 'tools.knowledge_capture',
                     'check', '--metadata-json', str(path), timeout=180)
    require(decode(output).get('status') == 'PASS', 'final PR history validation did not pass')
    return dict(command='mise exec -- python3 -m tools.knowledge_capture check --metadata-json ' + str(path),
                outcome='PASS')


def object_field(parent, key):
    value = parent.get(key)
    require(isinstance(value, dict), f'invalid/missing OCR {key} object')
    return value


def require_subscription():
    # Capture status without publishing account identity or credentials.
    require('Status: Using ChatGPT plan' in command('ocr', 'auth', 'status'),
            'ChatGPT subscription unavailable')


def validate_ocr(result, preview, binding, budget):
    """Accept only fresh, complete v1 range coverage matching the paid-run preview."""
    require(isinstance(result, dict) and result.get('status') == 'complete', 'OCR status is not complete')
    manifest = result.get('manifest')
    require(isinstance(manifest, dict) and manifest.get('schema_version') == 'ocr.run-manifest/v1', 'unknown/missing OCR manifest version')
    require(manifest.get('operation') == 'review' and manifest.get('terminal_state') == 'complete'
            and not manifest.get('run_failure'), 'OCR manifest incomplete or failed')
    frozen = object_field(manifest, 'input')
    require(frozen.get('mode') == 'range' and frozen.get('resolved_head') == binding['head']
            and frozen.get('resolved_base') == binding['merge_base']
            and frozen.get('exact_range') == f'{binding["merge_base"]}..{binding["head"]}', 'stale OCR resolved head/range')
    require(isinstance(result.get('session_id'), str) and result['session_id']
            and manifest.get('run_id') == result['session_id'] and not manifest.get('parent_run_id'), 'unknown/resumed OCR session')
    execution = object_field(manifest, 'execution')
    require(execution.get('provider') == 'chatgpt' and execution.get('model')
            and execution.get('configured_concurrency') == 1, 'OCR provider/model/concurrency mismatch')
    require(not result.get('warnings'), 'unresolved OCR warnings, including review/token limits')
    summary = object_field(result, 'summary')
    used = summary.get('total_tokens')
    require(type(used) is int and 0 < used < budget and not summary.get('budget_exceeded'), 'OCR soft budget exhausted or unknown usage')
    require(object_field(result, 'tool_calls').get('failure') == 0, 'unresolved/unknown OCR tool failures')
    if 'retry_report' in result:
        retry = object_field(result, 'retry_report')
        require(retry.get('schema_version') == 'ocr.llm-retry-report/v1', 'unknown OCR retry report')
        requests = retry.get('requests')
        require(isinstance(requests, list) and all(isinstance(r, dict) and r.get('outcome') in ('recovered', 'succeeded') for r in requests), 'unresolved OCR request failures')
    coverage = object_field(manifest, 'coverage')
    selected = path_map(coverage.get('selected'), 'selected')
    completed = path_map(coverage.get('completed'), 'completed')
    excluded = path_map(coverage.get('excluded'), 'excluded')
    for name in ('failed', 'waived', 'reused'):
        require(coverage.get(name) == [], f'OCR {name} selected files cannot attest fresh complete coverage')
    require(selected and selected == completed and all(i.get('fingerprint') for i in selected.values()),
            'selected file did not complete with exact identity')
    identities = [i.get('item_id') for i in [*selected.values(), *excluded.values()]]
    require(all(isinstance(i, str) and i for i in identities) and len(identities) == len(set(identities)), 'invalid OCR item identities')
    files = path_map(preview.get('files'), 'preview')
    require(set(selected) == {p for p, i in files.items() if i['will_review']}
            and set(excluded) == {p for p, i in files.items() if not i['will_review']}, 'preview/result coverage mismatch')
    require(all(i.get('exclude_reason') == files[p].get('exclude_reason') for p, i in excluded.items()), 'OCR exclusion reason changed')
    require(summary.get('files_reviewed') == len(completed), 'OCR file count mismatch')
    findings = result.get('comments')
    require(isinstance(findings, list) and summary.get('comments') == len(findings), 'unknown OCR findings/count')
    require(all(isinstance(f, dict) and f.get('path') in selected and f.get('content')
                and type(f.get('start_line')) is int for f in findings), 'malformed OCR finding')
    return dict(session=result['session_id'], manifest=manifest['schema_version'], model=execution['model'],
                tool_version=execution.get('ocr_version', 'unknown'), effort='low', concurrency=1, selected=list(selected),
                budget=budget, tokens=used, findings=findings, excluded=list(excluded.values()))


def validate_findings(summary, review, head):
    """Use an existing authenticated independent PR review, not author waivers.

    This triage disposition is not final approval. Master Gate still reviews the
    entire diff and required evidence. Corrections need a new full sequence.
    """
    if not summary['findings']:
        return
    require(isinstance(review, dict) and review.get('user', {}).get('login') == 'JCSchoeman96'
            and review.get('commit_id') == head and review.get('state') in ('COMMENTED', 'APPROVED'),
            'OCR findings require exact-head independent reviewed disposition or verified repair; keep Draft')
    for index, _finding in enumerate(summary['findings'], 1):
        pattern = rf'(?m)^OCR {re.escape(summary["session"])} finding {index}: (NON-BLOCKING|FALSE POSITIVE)\. [^\n]+$'
        require(re.search(pattern, review.get('body', '')), f'OCR finding {index} unresolved; keep Draft')


def write_state(path, state):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(state, indent=2) + '\n')
    temporary.chmod(0o600)
    temporary.replace(path)


def local(state_path, binding, paths, focused, deep=False):
    """Invalidate old receipts first; record only observed successful local runs."""
    state_path.unlink(missing_ok=True)
    require(focused, 'at least one ticket-scoped --focused command is required')
    commands = [shlex.split(c) for c in focused]
    require(all(c and c[0] != 'ocr' for c in commands), 'invalid focused command')
    commands.append(['mise', 'exec', '--', 'devcore-project', 'run', 'test', '--', 'mix', 'check'])
    if deep or classify_deep_application_changes(paths):
        commands.append(['mise', 'exec', '--', 'devcore-project', 'run', 'test', '--', 'mix', 'check.deep'])
    results = []
    for index, argv in enumerate(commands):
        log = state_path.parent / f'local-{index}.log'
        print(f'Running {shlex.join(argv)}; log {log}', flush=True)
        with log.open('w') as output:
            output_path_mode(log)
            process = subprocess.run(argv, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
        require(process.returncode == 0, f'local verification failed; inspect {log}; stop before hosted CI/OCR')
        require(worktree()[0] == binding, 'worktree changed during local verification')
        results.append(dict(command=argv, exit_code=0, log=str(log)))
    state = dict(binding=binding, local=results)
    write_state(state_path, state)
    return state


def output_path_mode(path):
    path.chmod(0o600)


def main():
    global ROOT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=['discover', 'discover-pr', 'local', 'preview', 'ocr', 'finish'])
    parser.add_argument('--focused', action='append', default=[], help='argv string, no shell, for ticket-scoped proof')
    parser.add_argument('--deep', action='store_true', help='also run check.deep for locally applicable scope')
    parser.add_argument('--pr', type=int, help='optional disambiguation; ordinarily discovered from the worktree')
    parser.add_argument('--budget', type=int, default=DEFAULT_BUDGET, help='soft aggregate OCR token budget')
    parser.add_argument('--exclude', default='', help='explicit OCR gitignore patterns; disclose each reason in PR')
    parser.add_argument('--ticket', help='WELL identifier for the final evidence summary')
    parser.add_argument('--retry-reason', help='explicit reason for another paid attempt on the same local receipt')
    parser.add_argument('--disposition-review', type=int, help='existing independent exact-head GitHub PR review ID')
    args = parser.parse_args()
    try:
        require(not any(os.environ.get(k, '').lower() not in ('', '0', 'false') for k in ('CI', 'GITHUB_ACTIONS')),
                'local developer machine only; subscription-backed OCR is forbidden in CI')
        ROOT = Path(command('git', 'rev-parse', '--show-toplevel'))
        binding, paths = worktree()
        if args.stage in ('discover', 'discover-pr'):
            # Local discovery always works without a PR. Ask for remote association
            # explicitly with --pr or at the final handoff checkpoint.
            result = dict(worktree=str(ROOT), binding=binding, paths=paths, evidence='local candidate only')
            if args.stage == 'discover-pr' or args.pr is not None:
                result['pr'] = discover_pr(binding['head'], args.pr)
            print(json.dumps(result, indent=2))
            return 0
        directory = Path(command('git', 'rev-parse', '--path-format=absolute', '--git-path', 'agent-handoff'))
        directory.mkdir(mode=0o700, exist_ok=True)
        with (directory / 'lock').open('w') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as exc:
                raise GateError('another handoff command owns this worktree') from exc
            state_path = directory / 'state.json'
            if args.stage == 'local':
                verify_base(binding)
                local(state_path, binding, paths, args.focused, args.deep)
                return 0
            state = decode(state_path.read_text()) if state_path.exists() else {}
            if args.stage == 'preview':
                state.pop('ocr', None)
                state.pop('prepared', None)
                write_state(state_path, state)
                exclusions = ','.join(filter(None, (HISTORY_EXCLUDE, args.exclude)))
                state['prepared'] = prepare_preview(state, binding, paths, budget=args.budget, exclude=exclusions)
                write_state(state_path, state)
                print(json.dumps(state['prepared'], indent=2))
                return 0
            prepared = state.get('prepared')
            require(isinstance(prepared, dict), 'run preview after local verification first')
            if args.stage == 'ocr':
                require(not state.get('attempts') or (args.retry_reason and args.retry_reason.strip()),
                        'paid OCR already attempted; inspect preserved evidence and supply --retry-reason for a deliberate rerun')
                state.pop('ocr', None)
                write_state(state_path, state)
                fresh = prepare_preview(state, binding, paths, budget=prepared['budget'], exclude=prepared['exclude'])
                require(fresh['preview'] == prepared['preview'], 'OCR selection changed; inspect a new preview first')
                # auth status is captured, never printed or written to evidence.
                require_subscription()
                require(worktree()[0] == binding, 'source changed before OCR')
                attempt = str(uuid4())
                result_path = directory / f'ocr-{attempt}.json'
                log_path = directory / f'ocr-{attempt}.log'
                state.setdefault('attempts', []).append(dict(result=str(result_path), log=str(log_path),
                                                            reason=args.retry_reason or 'first paid scan'))
                write_state(state_path, state)
                argv = ocr_args(binding, prepared['budget'], prepared['exclude'])
                print(f'Running {shlex.join(argv)}; result {result_path}', flush=True)
                with result_path.open('w') as output, log_path.open('w') as errors:
                    output_path_mode(result_path)
                    output_path_mode(log_path)
                    process = subprocess.run(argv, cwd=ROOT, stdout=output, stderr=errors)
                require(process.returncode == 0, f'OCR CLI failed; inspect private result/log at {directory}')
                require(worktree()[0] == binding, 'source changed during OCR')
                result = decode(result_path.read_text())
                summary = validate_ocr(result, prepared['preview'], binding, prepared['budget'])
                state['ocr'] = dict(summary=summary, result=result, command=argv)
                write_state(state_path, state)
                print(json.dumps(summary, indent=2))
                if summary['findings']:
                    raise GateError('OCR findings require independent disposition or verified repair; keep Draft')
                return 0
            require(args.ticket and re.fullmatch(r'WELL-[1-9][0-9]*', args.ticket), 'finish requires the execution ticket')
            require('ocr' in state, 'missing complete OCR evidence')
            pr = discover_pr(binding['head'], args.pr)
            reuse = proof_binding(state, binding, pr['number'])
            summary = validate_ocr(state['ocr']['result'], prepared['preview'], state['binding'], prepared['budget'])
            # Preview costs no tokens. This catches changed selection/configuration
            # and newly eligible files before reusing an earlier OCR session.
            fresh_preview = validate_preview(decode(command(*ocr_args(binding, prepared['budget'], prepared['exclude']), '--preview')), paths)
            validate_reuse_preview(prepared['preview'], fresh_preview, reuse['history_only'])
            knowledge = validate_knowledge(pr['number'], directory)
            fresh_ci = collect_ci(binding, paths, pr['number'])
            review = api(f'pulls/{pr["number"]}/reviews/{args.disposition_review}') if args.disposition_review else None
            validate_findings(summary, review, binding['head'])
            require(worktree()[0] == binding, 'source changed while finishing')
            print(json.dumps(dict(ticket=args.ticket, binding=binding, local=state['local'], ci=fresh_ci,
                                  implementation_binding=state['binding'], proof_reuse=reuse, knowledge=knowledge,
                                  ocr=summary, command=state['ocr']['command'],
                                  disposition_review=args.disposition_review,
                                  risks='Excluded paths and generated history require independent full-diff review. OCR is advisory.',
                                  status='awaiting independent Master Gate'), indent=2))
            return 0
    except (GateError, OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        print(f'BLOCKED: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
