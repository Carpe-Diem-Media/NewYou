"""Capture exact PR source changes and query current capability knowledge."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HELPER = Path(__file__).with_name('knowledge_symbols.exs')
HISTORY = 'docs/development/knowledge/history'


def _run(repo, *args, input=None):
    result = subprocess.run(['git', *args], cwd=repo, input=input, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, check=False)
    if result.returncode:
        raise ValueError(result.stderr.decode(errors='replace').strip())
    return result.stdout


def _resolve(repo, revision):
    return _run(repo, 'rev-parse', '--verify', revision + '^{commit}').decode().strip()


def _tree(repo, revision):
    entries = {}
    for item in _run(repo, 'ls-tree', '-r', '-z', revision).split(b'\0'):
        if not item:
            continue
        meta, path = item.split(b'\t', 1)
        mode, kind, blob = meta.decode().split()
        if kind == 'blob':
            entries[path.decode('utf-8', 'surrogateescape')] = {'mode': mode, 'blob': blob}
    return entries


def _diff(repo, base, head):
    raw = _run(repo, 'diff', '--name-status', '-M', '-z', base, head).split(b'\0')
    result = []
    i = 0
    while i < len(raw) and raw[i]:
        status = raw[i].decode()
        i += 1
        if status.startswith('R') or status.startswith('C'):
            old_path, new_path = (x.decode('utf-8', 'surrogateescape') for x in raw[i:i + 2])
            i += 2
            result.append((('renamed' if status.startswith('R') else 'copied'), old_path, new_path))
        else:
            path = raw[i].decode('utf-8', 'surrogateescape')
            i += 1
            result.append(({'A': 'added', 'M': 'modified', 'D': 'deleted', 'T': 'type-changed'}.get(status[0], 'changed'),
                           None if status[0] == 'A' else path, None if status[0] == 'D' else path))
    return result


def _blob(repo, revision, path):
    return _run(repo, 'show', revision + ':' + path)


def _elixir_result(old, new):
    executable = shutil.which('elixir')
    if not executable:
        mise = shutil.which('mise')
        if not mise:
            raise ValueError('Elixir is required to parse changed .ex/.exs files')
        command = [mise, 'exec', '--', 'elixir', str(HELPER)]
    else:
        command = [executable, str(HELPER)]
    with tempfile.TemporaryDirectory(prefix='knowledge-capture-') as directory:
        old_path, new_path = Path(directory) / 'old.ex', Path(directory) / 'new.ex'
        old_path.write_bytes(old or b'')
        new_path.write_bytes(new or b'')
        try:
            output = subprocess.run(command + [str(old_path), str(new_path)], cwd=ROOT,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        except (OSError, subprocess.CalledProcessError) as exc:
            detail = getattr(exc, 'stderr', b'') or b''
            raise ValueError('Elixir symbol helper failed: ' + detail.decode(errors='replace')) from exc
    return json.loads(output.stdout)


def _symbols(repo, old_revision, new_revision, old_path, new_path):
    old = _blob(repo, old_revision, old_path) if old_path else b''
    new = _blob(repo, new_revision, new_path) if new_path and new_path in _tree(repo, new_revision) else b''
    parsed = _elixir_result(old, new)
    old_parse, new_parse = parsed['old'], parsed['new']
    if old_parse['status'] != 'parsed' or new_parse['status'] != 'parsed':
        reasons = old_parse['unknown'] + new_parse['unknown']
        return [{'status': 'unknown', 'change': 'unknown', 'module': None, 'name': None,
                 'arity': None, 'reason': '; '.join(sorted({r['reason'] for r in reasons}))}]
    before = {(s['module'], s['name'], s['arity']): s['sha256'] for s in old_parse['functions']}
    after = {(s['module'], s['name'], s['arity']): s['sha256'] for s in new_parse['functions']}
    records = []
    old_modules, new_modules = set(old_parse['modules']), set(new_parse['modules'])
    for module in sorted(old_modules | new_modules):
        if module not in old_modules or module not in new_modules:
            records.append({'status': 'parsed', 'kind': 'module',
                            'change': 'added' if module not in old_modules else 'removed',
                            'module': module, 'name': None, 'arity': None})
    for key in sorted(before.keys() | after.keys()):
        if before.get(key) == after.get(key):
            if key in before:
                continue
        records.append({'status': 'parsed', 'kind': 'function', 'change': 'added' if key not in before else
                        ('removed' if key not in after else 'changed'), 'module': key[0], 'name': key[1],
                        'arity': key[2], 'old_sha256': before.get(key), 'sha256': after.get(key)})
    for unknown in old_parse['unknown'] + new_parse['unknown']:
        records.append({'status': 'unknown', 'kind': 'unknown', 'change': 'unknown', 'module': None, 'name': None,
                        'arity': None, 'reason': unknown['reason']})
    return records


def _metadata(metadata, pr, base, head, tickets):
    if not metadata:
        return {'url': None, 'source': 'unknown'}
    if 'pull_request' in metadata:
        obj = metadata['pull_request']
        number = metadata.get('number') or obj.get('number')
        base_oid = (obj.get('base') or {}).get('sha')
        head_oid = (obj.get('head') or {}).get('sha')
        url = obj.get('html_url')
        title_body = ((obj.get('title') or '') + '\n' + (obj.get('body') or ''))
        repository = (metadata.get('repository') or {}).get('full_name') or (obj.get('base') or {}).get('repo', {}).get('full_name')
    else:
        obj = metadata
        number = obj.get('number')
        base_part, head_part = obj.get('base') or {}, obj.get('head') or {}
        base_oid = obj.get('baseRefOid') or (base_part.get('sha') or base_part.get('refOid') if isinstance(base_part, dict) else None)
        head_oid = obj.get('headRefOid') or (head_part.get('sha') or head_part.get('refOid') if isinstance(head_part, dict) else None)
        url = obj.get('html_url') or obj.get('url')
        title_body = (obj.get('title') or '') + '\n' + (obj.get('body') or '')
        repository = (obj.get('repository') or {}).get('full_name') or (base_part.get('repo') or {}).get('full_name') if isinstance(base_part, dict) else None
        if isinstance(head_part, str):
            head_oid = head_oid or head_part
    if type(number) not in (int, str) or not str(number).isdigit() or int(number) < 1 or int(number) != pr:
        raise ValueError('metadata PR number does not match --pr')
    if not base_oid or not head_oid:
        raise ValueError('metadata must include exact base and head SHAs')
    if base_oid != base:
        raise ValueError('metadata base SHA does not match extracted base')
    if head_oid != head:
        raise ValueError('metadata head SHA does not match extracted head')
    if repository and repository != 'Carpe-Diem-Media/NewYou':
        raise ValueError('metadata repository does not match Carpe-Diem-Media/NewYou')
    expected_url = f'https://github.com/Carpe-Diem-Media/NewYou/pull/{pr}'
    if not url or url.rstrip('/') != expected_url:
        raise ValueError('metadata PR URL does not match canonical repository and number')
    discovered = sorted(set(re.findall(r'\bWELL-[1-9][0-9]*\b', title_body)))
    if metadata and not discovered:
        raise ValueError('PR metadata has no WELL ticket reference')
    if tickets and sorted(set(tickets)) != discovered:
        raise ValueError('ticket IDs do not match PR title/body metadata')
    return {'url': url or (expected_url if repository else None), 'source': 'github', 'number': pr,
            'metadata_base': base_oid, 'metadata_head': head_oid,
            'ticket_ids': discovered or sorted(set(tickets))}


def extract(repo=ROOT, base='HEAD^', head='HEAD', pr=0, tickets=(), metadata=None):
    repo = Path(repo).resolve()
    base_sha, head_sha = _resolve(repo, base), _resolve(repo, head)
    link = _metadata(metadata, pr, base_sha, head_sha, tickets)
    old_tree, new_tree = _tree(repo, base_sha), _tree(repo, head_sha)
    changes = []
    symbol_records = []
    test_paths, migration_paths = set(), set()
    excluded = f'{HISTORY}/pr-{pr}.json' if pr else None
    for status, old_path, new_path in _diff(repo, base_sha, head_sha):
        path = new_path or old_path
        if excluded and status not in ('renamed', 'copied') and path == excluded:
            continue
        if path is None:
            continue
        if not _safe_path(path):
            raise ValueError('unsafe changed path: ' + path)
        before, after = old_tree.get(old_path), new_tree.get(new_path)
        new_bytes = _blob(repo, head_sha, new_path) if after else b''
        change = {'status': status, 'path': path, 'old_path': old_path,
                  'old_mode': before['mode'] if before else None, 'old_blob': before['blob'] if before else None,
                  'mode': after['mode'] if after else None, 'blob': after['blob'] if after else None,
                  'old_sha256': hashlib.sha256(_blob(repo, base_sha, old_path)).hexdigest() if before else None,
                  'sha256': hashlib.sha256(new_bytes).hexdigest() if after else None}
        changes.append(change)
        for changed_path in {old_path, new_path} - {None}:
            if changed_path.startswith(('test/', 'tests/')) or '/test/' in changed_path or '/tests/' in changed_path:
                test_paths.add(changed_path)
            if re.search(r'(^|/)migrations?/', changed_path):
                migration_paths.add(changed_path)
        if path.endswith(('.ex', '.exs')):
            symbol_records.extend([dict(item, path=path) for item in
                                   _symbols(repo, base_sha, head_sha, old_path, new_path)])
    return {'schema_version': 1, 'pr': pr, 'pr_url': link.get('url'), 'tickets': link.get('ticket_ids', sorted(set(tickets))),
            'base_sha': base_sha, 'files': changes,
            'tests': sorted(test_paths), 'migrations': sorted(migration_paths), 'symbols': symbol_records,
            'ci': {'source': 'external GitHub checks', 'status': 'unknown'}}


def _safe_path(path):
    relative = PurePosixPath(path)
    return not relative.is_absolute() and str(relative) == path and '..' not in relative.parts and '\\' not in path


def _loads(text):
    def unique(pairs):
        values = {}
        for key, value in pairs:
            if key in values:
                raise ValueError('duplicate JSON key: ' + key)
            values[key] = value
        return values
    return json.loads(text, object_pairs_hook=unique)


def record_path(repo, pr):
    root = Path(repo).resolve()
    relative = Path(HISTORY) / f'pr-{pr}.json'
    path = root / relative
    if path.resolve() != root / relative:
        raise ValueError('history path resolves outside repository')
    return path


def check_record(repo, record, expected=None):
    if record.get('schema_version') != 1:
        raise ValueError('unsupported history schema version')
    for file in record.get('files', []):
        if not _safe_path(file['path']) or (file.get('old_path') and not _safe_path(file['old_path'])):
            raise ValueError('unsafe history path')
        if file.get('sha256') and not re.fullmatch(r'[0-9a-f]{64}', file['sha256']):
            raise ValueError('invalid source SHA-256')
    if expected is not None:
        canonical = lambda value: json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False)
        if canonical(record) != canonical(expected):
            keys = sorted(set(record) | set(expected))
            field = next((key for key in keys if record.get(key) != expected.get(key)), 'record')
            raise ValueError('history record differs from exact regeneration: ' + field)
    return True


def generate(repo, base, head, pr, tickets, metadata=None, check=False):
    expected = extract(repo, base, head, pr, tickets, metadata)
    path = record_path(repo, pr)
    if check:
        head_tree = _tree(repo, _resolve(repo, head))
        relative = path.relative_to(Path(repo).resolve()).as_posix()
        if relative not in head_tree:
            raise ValueError('missing PR history record: ' + str(path))
        check_record(repo, _loads(_blob(repo, _resolve(repo, head), relative).decode()), expected)
        return {'status': 'PASS', 'path': str(path), 'base_sha': expected['base_sha'], 'head_sha': _resolve(repo, head)}
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.resolve() != Path(repo).resolve() / Path(HISTORY) / f'pr-{pr}.json':
        raise ValueError('history path resolves outside repository')
    path.write_text(json.dumps(expected, indent=2, sort_keys=True) + '\n')
    return {'status': 'WRITTEN', 'path': str(path), 'base_sha': expected['base_sha'], 'head_sha': _resolve(repo, head)}


def query_index(repo, query, revision='HEAD'):
    repo = Path(repo).resolve()
    revision = _resolve(repo, revision)
    needles = query.lower()
    tree = _tree(repo, revision)
    rows = []
    map_count = history_count = 0
    for path in sorted(tree):
        if path.startswith('docs/development/knowledge/') and path.endswith('.json') and '/history/' not in path and not path.endswith('capability.schema.json'):
            map_count += 1
            doc = _loads(_blob(repo, revision, path).decode())
            for source in doc.get('sources', []):
                source_path = source.get('path', '')
                if source_path not in tree:
                    continue
                if tree[source_path]['mode'] == '120000':
                    raise ValueError('capability map source is a symlink: ' + source_path)
                digest = hashlib.sha256(_blob(repo, revision, source_path)).hexdigest()
                if source.get('sha256') != digest:
                    raise ValueError(f'capability map source drift at {revision}: {source_path}')
                haystack = ' '.join((path, source_path, source.get('symbol', ''), doc.get('capability_id', ''),
                                    *doc.get('implementing_tickets', []))).lower()
                if needles in haystack:
                    rows.append({'map': path, 'path': source_path, 'symbol': source.get('symbol'),
                                 'capability_id': doc.get('capability_id'), 'source_sha256': digest,
                                 'revision': revision, 'historical': False})
        elif path.startswith(HISTORY + '/') and path.endswith('.json'):
            history_count += 1
            doc = _loads(_blob(repo, revision, path).decode())
            ticket_match = any(needles in ticket.lower() for ticket in doc.get('tickets', []))
            files = {entry['path']: entry for entry in doc.get('files', [])}
            for source_path, entry in files.items():
                present = source_path in tree
                current_digest = hashlib.sha256(_blob(repo, revision, source_path)).hexdigest() if present else None
                terms = ' '.join((source_path, entry.get('old_path') or '', doc.get('pr_url') or '')).lower()
                if ticket_match or needles in terms:
                    rows.append({'path': source_path, 'status': entry['status'],
                                 'ticket_ids': doc.get('tickets', []), 'pr': doc.get('pr'),
                                 'revision': revision, 'historical': True, 'exists_at_revision': present,
                                 'blob': entry.get('blob'), 'sha256': entry.get('sha256'),
                                 'source_matches_snapshot': bool(current_digest and entry.get('sha256') and current_digest == entry.get('sha256'))})
            for symbol in doc.get('symbols', []):
                source_path = symbol.get('path')
                file_record = files.get(source_path, {})
                present = source_path in tree
                digest = hashlib.sha256(_blob(repo, revision, source_path)).hexdigest() if present else None
                source_matches = bool(digest and digest == file_record.get('sha256'))
                terms = ' '.join(str(symbol.get(key, '')) for key in ('module', 'name', 'path', 'reason')).lower()
                if not ticket_match and needles not in terms:
                    continue
                rows.append({'path': source_path, 'symbol': symbol.get('name') or symbol.get('module'),
                             'module': symbol.get('module'), 'change': symbol.get('change'),
                             'ticket_ids': doc.get('tickets', []), 'pr': doc.get('pr'),
                             'revision': revision, 'historical': True, 'exists_at_revision': present,
                             'source_matches_snapshot': source_matches})
    return {'revision': revision, 'maps': map_count, 'history_records': history_count, 'results': rows}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', default='.')
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('generate', 'check'):
        cmd = sub.add_parser(name)
        cmd.add_argument('--base')
        cmd.add_argument('--head')
        cmd.add_argument('--pr', type=int)
        cmd.add_argument('--ticket', action='append', default=[])
        cmd.add_argument('--metadata-json')
    index = sub.add_parser('index')
    index.add_argument('--revision', default='HEAD')
    query = sub.add_parser('query')
    query.add_argument('--query', required=True)
    query.add_argument('--revision', default='HEAD')
    args = parser.parse_args()
    if args.command in ('generate', 'check'):
        metadata = _loads(Path(args.metadata_json).read_text()) if args.metadata_json else None
        pr = args.pr or (metadata.get('number') if metadata else None)
        if metadata and 'pull_request' in metadata:
            pr = pr or metadata['pull_request'].get('number')
        if not pr:
            raise ValueError('--pr or PR metadata is required')
        base = args.base or ((metadata.get('pull_request') or {}).get('base', {}).get('sha') if metadata else None)
        if not base and metadata:
            base_part = metadata.get('base') or {}
            base = metadata.get('baseRefOid') or ((base_part.get('sha') or base_part.get('refOid')) if isinstance(base_part, dict) else None)
        if not base:
            raise ValueError('--base or PR metadata is required')
        head = args.head or ((metadata.get('pull_request') or {}).get('head', {}).get('sha') if metadata else None)
        if not head and metadata:
            head_part = metadata.get('head') or {}
            head = metadata.get('headRefOid') or ((head_part.get('sha') or head_part.get('refOid')) if isinstance(head_part, dict) else None)
        result = generate(args.repo, base, head or 'HEAD', pr, args.ticket, metadata, args.command == 'check')
    elif args.command == 'index':
        result = query_index(args.repo, '', args.revision)
        result = {'status': 'PASS', 'revision': result['revision'], 'maps': result['maps'],
                  'history_records': result['history_records'], 'references': len(result['results'])}
    else:
        result = query_index(args.repo, args.query, args.revision)
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError, json.JSONDecodeError) as exc:
        raise SystemExit(str(exc))
