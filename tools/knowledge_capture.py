"""Capture exact PR source changes and query current capability knowledge."""
import argparse
import hashlib
import json
import os
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


def _merge_base(repo, base, head):
    return _run(repo, 'merge-base', base, head).decode().strip()


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


def _elixir_current(sources):
    if not sources:
        return {}
    executable = shutil.which('elixir')
    if not executable:
        mise = shutil.which('mise')
        if not mise:
            raise ValueError('Elixir is required to parse current .ex/.exs sources')
        command = [mise, 'exec', '--', 'elixir', str(HELPER)]
    else:
        command = [executable, str(HELPER)]
    with tempfile.TemporaryDirectory(prefix='knowledge-index-') as directory:
        root = Path(directory)
        paths = []
        names = []
        for index, (name, source) in enumerate(sorted(sources.items())):
            path = root / f'{index}.ex'
            path.write_bytes(source)
            paths.append(str(path))
            names.append(name)
        manifest = root / 'manifest.json'
        manifest.write_text(json.dumps(paths))
        try:
            output = subprocess.run(command + ['--current', str(manifest)], cwd=ROOT,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        except (OSError, subprocess.CalledProcessError) as exc:
            detail = getattr(exc, 'stderr', b'') or b''
            raise ValueError('Elixir symbol helper failed: ' + detail.decode(errors='replace')) from exc
        parsed = json.loads(output.stdout)
        return {name: parsed[path] for name, path in zip(names, paths)}


def _symbols(repo, old_revision, new_revision, old_path, new_path):
    old = _blob(repo, old_revision, old_path) if old_path and old_path.endswith(('.ex', '.exs')) else b''
    new = _blob(repo, new_revision, new_path) if new_path and new_path.endswith(('.ex', '.exs')) else b''
    parsed = _elixir_result(old, new)
    old_parse, new_parse = parsed['old'], parsed['new']
    if old_parse['status'] != 'parsed' or new_parse['status'] != 'parsed':
        reasons = old_parse['unknown'] + new_parse['unknown']
        return [{'status': 'unknown', 'change': 'unknown', 'module': None, 'name': None,
                 'arity': None, 'reason': '; '.join(sorted({r['reason'] for r in reasons}))}]
    before = {(s['module'], s['name'], s['arity'], s['visibility'], s['declaration']): s['sha256'] for s in old_parse['functions']}
    after = {(s['module'], s['name'], s['arity'], s['visibility'], s['declaration']): s['sha256'] for s in new_parse['functions']}
    records = []
    old_modules, new_modules = set(old_parse['modules']), set(new_parse['modules'])
    for module in sorted(old_modules | new_modules):
        old_hash = old_parse.get('module_hashes', {}).get(module)
        new_hash = new_parse.get('module_hashes', {}).get(module)
        if module not in old_modules or module not in new_modules or old_hash != new_hash:
            records.append({'status': 'parsed', 'kind': 'module',
                            'change': 'added' if module not in old_modules else
                                      ('removed' if module not in new_modules else 'changed'),
                            'module': module, 'name': None, 'arity': None,
                            'old_sha256': old_hash, 'sha256': new_hash})
    for key in sorted(before.keys() | after.keys()):
        if before.get(key) == after.get(key):
            if key in before:
                continue
        records.append({'status': 'parsed', 'kind': 'function', 'change': 'added' if key not in before else
                        ('removed' if key not in after else 'changed'), 'module': key[0], 'name': key[1],
                        'arity': key[2], 'visibility': key[3], 'declaration': key[4],
                        'old_sha256': before.get(key), 'sha256': after.get(key)})
    for reason in sorted({unknown['reason'] for unknown in old_parse['unknown'] + new_parse['unknown']}):
        records.append({'status': 'unknown', 'kind': 'unknown', 'change': 'unknown', 'module': None, 'name': None,
                        'arity': None, 'reason': reason})
    return records


def _metadata(metadata, pr, base, head):
    if not metadata:
        return {'url': f'https://github.com/Carpe-Diem-Media/NewYou/pull/{pr}' if pr else None,
                'source': 'unknown'}
    if 'pull_request' in metadata:
        obj = metadata['pull_request']
        number = metadata.get('number') or obj.get('number')
        base_oid = (obj.get('base') or {}).get('sha')
        head_oid = (obj.get('head') or {}).get('sha')
        url = obj.get('html_url')
        repository = (metadata.get('repository') or {}).get('full_name') or (obj.get('base') or {}).get('repo', {}).get('full_name')
        if obj.get('number') is not None and str(obj['number']) != str(pr):
            raise ValueError('metadata nested PR number does not match --pr')
    else:
        obj = metadata
        number = obj.get('number')
        base_part, head_part = obj.get('base') or {}, obj.get('head') or {}
        base_oid = obj.get('baseRefOid') or (base_part.get('sha') or base_part.get('refOid') if isinstance(base_part, dict) else None)
        head_oid = obj.get('headRefOid') or (head_part.get('sha') or head_part.get('refOid') if isinstance(head_part, dict) else None)
        url = obj.get('html_url') or obj.get('url')
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
    base_repository = (obj.get('base') or {}).get('repo', {}).get('full_name') if isinstance(obj.get('base'), dict) else None
    if base_repository and base_repository != 'Carpe-Diem-Media/NewYou':
        raise ValueError('metadata base repository does not match Carpe-Diem-Media/NewYou')
    return {'url': url, 'source': 'github'}


def _tickets(tickets):
    if not isinstance(tickets, (list, tuple)) or any(
            not isinstance(ticket, str) or not re.fullmatch(r'WELL-[1-9][0-9]*', ticket)
            for ticket in tickets):
        raise ValueError('invalid ticket references; supply --ticket WELL-N from implementation context')
    return sorted(set(tickets))


def parser_needed(repo, metadata):
    changed = metadata.get('changed_files', metadata.get('files', []))
    if not isinstance(changed, list):
        changed = []
    if not changed:
        pr_event = metadata.get('pull_request') or metadata
        base_sha = (pr_event.get('base') or {}).get('sha')
        head_sha = (pr_event.get('head') or {}).get('sha')
        if base_sha and head_sha:
            try:
                merge_base = _merge_base(repo, base_sha, head_sha)
                changed = [path for _, old, new in _diff(repo, merge_base, head_sha) for path in (old, new) if path]
            except ValueError:
                return True
    paths = [entry if isinstance(entry, str) else entry.get('filename', '') for entry in changed]
    return any(path.endswith(('.ex', '.exs')) for path in paths) or any(
        path in ('tools/knowledge_capture.py', 'tools/knowledge_symbols.exs',
                 'tests/test_knowledge_capture.py', '.tool-versions') for path in paths)


def extract(repo=ROOT, base='HEAD^', head='HEAD', pr=0, tickets=(), metadata=None):
    repo = Path(repo).resolve()
    base_sha, head_sha = _resolve(repo, base), _resolve(repo, head)
    range_base_sha = _merge_base(repo, base_sha, head_sha)
    link = _metadata(metadata, pr, base_sha, head_sha)
    linked_tickets = _tickets(tickets)
    old_tree, new_tree = _tree(repo, range_base_sha), _tree(repo, head_sha)
    changes = []
    symbol_records = []
    test_paths, migration_paths = set(), set()
    excluded = f'{HISTORY}/pr-{pr}.json' if pr else None
    for status, old_path, new_path in _diff(repo, range_base_sha, head_sha):
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
                  'old_sha256': hashlib.sha256(_blob(repo, range_base_sha, old_path)).hexdigest() if before else None,
                  'sha256': hashlib.sha256(new_bytes).hexdigest() if after else None}
        changes.append(change)
        for changed_path in {old_path, new_path} - {None}:
            if changed_path.startswith(('test/', 'tests/')) or '/test/' in changed_path or '/tests/' in changed_path:
                test_paths.add(changed_path)
            if re.search(r'(^|/)migrations?/', changed_path):
                migration_paths.add(changed_path)
        elixir_side = any(changed_path and changed_path.endswith(('.ex', '.exs'))
                          for changed_path in (old_path, new_path))
        if elixir_side:
            old_entry, new_entry = old_tree.get(old_path), new_tree.get(new_path)
            if any(entry and entry['mode'] == '120000'
                   for entry, changed_path in ((old_entry, old_path), (new_entry, new_path))
                   if changed_path and changed_path.endswith(('.ex', '.exs'))):
                symbol_records.append({'status': 'unknown', 'kind': 'unknown', 'change': 'unknown',
                                       'module': None, 'name': None, 'arity': None,
                                       'path': new_path if new_path and new_path.endswith(('.ex', '.exs')) else old_path,
                                       'reason': 'Elixir symlink source is not parsed'})
            else:
                symbol_path = (new_path if new_path and new_path.endswith(('.ex', '.exs'))
                               else old_path)
                symbol_records.extend([dict(item, path=symbol_path) for item in
                                       _symbols(repo, range_base_sha, head_sha, old_path, new_path)])
    return {'schema_version': 1, 'pr': pr, 'pr_url': link.get('url'), 'tickets': linked_tickets,
            'base_sha': base_sha, 'range_base_sha': range_base_sha,
            'commits_url': f'https://github.com/Carpe-Diem-Media/NewYou/pull/{pr}/commits' if pr else None,
            'checks_url': f'https://github.com/Carpe-Diem-Media/NewYou/pull/{pr}/checks' if pr else None,
            'files': changes,
            'tests': sorted(test_paths), 'migrations': sorted(migration_paths), 'symbols': symbol_records}


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
    if type(record.get('schema_version')) is not int or record['schema_version'] != 1:
        raise ValueError('unsupported history schema version')
    for file in record.get('files', []):
        if not _safe_path(file['path']) or (file.get('old_path') and not _safe_path(file['old_path'])):
            raise ValueError('unsafe history path')
        if file.get('sha256') and not re.fullmatch(r'[0-9a-f]{64}', file['sha256']):
            raise ValueError('invalid source SHA-256')
    if expected is not None:
        # Older records retain their administrative snapshots. They are not
        # current evidence and are excluded from mechanical source comparison.
        mechanical = {key: value for key, value in record.items() if key not in ('intent', 'plane', 'ci')}
        if 'ci' in record and record['ci'] != {'source': 'external GitHub checks', 'status': 'unknown'}:
            raise ValueError('history cannot claim a CI result')
        canonical = lambda value: json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False)
        if canonical(mechanical) != canonical(expected):
            keys = sorted(set(mechanical) | set(expected))
            field = next((key for key in keys if mechanical.get(key) != expected.get(key)), 'record')
            raise ValueError('history record differs from exact regeneration: ' + field)
    return True


def generate(repo, base, head, pr, tickets, metadata=None, check=False):
    path = record_path(repo, pr)
    if check:
        relative = path.relative_to(Path(repo).resolve()).as_posix()
        head_commit = _resolve(repo, head)
        head_tree = _tree(repo, head_commit)
        if relative not in head_tree:
            raise ValueError('missing PR history record: ' + str(path))
        existing = _loads(_blob(repo, head_commit, relative).decode())
        committed_tickets = _tickets(existing.get('tickets'))
        if tickets and _tickets(tickets) != committed_tickets:
            raise ValueError('ticket references differ from committed implementation context')
        tickets = committed_tickets
    if not _tickets(tickets):
        raise ValueError('at least one explicit --ticket WELL-N is required')
    expected = extract(repo, base, head, pr, tickets, metadata)
    if check:
        check_record(repo, existing, expected)
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
    capability_maps = []
    for map_path in sorted(tree):
        if (map_path.startswith('docs/development/knowledge/') and map_path.endswith('.json')
                and '/history/' not in map_path and not map_path.endswith('capability.schema.json')):
            capability_maps.append((map_path, _loads(_blob(repo, revision, map_path).decode())))
    elixir_sources = {path: _blob(repo, revision, path) for path in tree
                      if path.endswith(('.ex', '.exs')) and tree[path]['mode'] != '120000'}
    parsed_sources = _elixir_current(elixir_sources)
    current_symbols = set()
    uncertain_modules = {module for parsed in parsed_sources.values() if parsed.get('status') != 'parsed'
                         for module in parsed.get('modules', [])}
    uncertain_without_module = any(parsed.get('status') != 'parsed' and not parsed.get('modules')
                                   for parsed in parsed_sources.values())
    def references_for(source_path, module=None, function=None):
        references = []
        for map_path, document in capability_maps:
            source_ids = {source.get('id') for source in document.get('sources', [])
                          if source.get('path') == source_path}
            interface_matches = [interface for interface in document.get('interfaces', [])
                                 if interface.get('module') == module
                                 and (function is None or interface.get('function') == function)]
            if not source_ids and not interface_matches:
                continue
            referenced_ids = source_ids | {source_id for interface in interface_matches
                                           for source_id in interface.get('source_ids', [])}
            references.append({
                'map': map_path,
                'capability_id': document.get('capability_id'),
                'authoritative_domain': document.get('authoritative_domain'),
                'source_ids': sorted(source_ids),
                'interfaces': interface_matches,
                'safe_extensions': document.get('safe_extensions', []),
                'reuse': document.get('reuse', []),
                'prohibited_shortcuts': document.get('prohibited_shortcuts', []),
                'tests': document.get('tests', []),
                'persistence': document.get('persistence', []),
                'semantic_map_refs': sorted(referenced_ids),
            })
        return references

    for source_path, parsed in parsed_sources.items():
        if parsed.get('status') != 'parsed':
            for unknown in parsed.get('unknown', []):
                if needles in (source_path + ' ' + unknown.get('reason', '')).lower():
                    rows.append({'path': source_path, 'symbol': None, 'status': 'unknown',
                                 'reason': unknown.get('reason'),
                                 'source_sha256': hashlib.sha256(elixir_sources[source_path]).hexdigest(),
                                 'revision': revision, 'historical': False, 'exists_at_revision': None})
        for symbol in parsed.get('functions', []):
            key = (symbol['module'], symbol['name'], symbol['arity'])
            current_symbols.add(key)
            qualified = f"{symbol['module']}.{symbol['name']}/{symbol['arity']}"
            haystack = ' '.join((source_path, *map(str, key), qualified, symbol['visibility'], symbol['declaration'])).lower()
            if needles in haystack:
                references = references_for(source_path, symbol['module'], symbol['name'])
                rows.append({'path': source_path, 'module': symbol['module'], 'symbol': symbol['name'],
                             'arity': symbol['arity'], 'visibility': symbol['visibility'],
                             'declaration': symbol['declaration'], 'symbol_sha256': symbol['sha256'],
                             'source_sha256': hashlib.sha256(elixir_sources[source_path]).hexdigest(),
                             'capability_refs': references,
                             'revision': revision, 'historical': False, 'exists_at_revision': True})
        for module in parsed.get('modules', []):
            haystack = f'{source_path} {module}'.lower()
            if needles in haystack:
                references = references_for(source_path, module)
                rows.append({'path': source_path, 'module': module, 'symbol': module, 'kind': 'module',
                             'module_sha256': parsed.get('module_hashes', {}).get(module),
                             'source_sha256': hashlib.sha256(elixir_sources[source_path]).hexdigest(),
                             'capability_refs': references,
                             'revision': revision, 'historical': False, 'exists_at_revision': True})
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
                interfaces = [interface for interface in doc.get('interfaces', []) if isinstance(interface, dict)]
                interface_terms = [str(interface.get(key, '')) for interface in interfaces for key in ('module', 'function')]
                haystack = ' '.join((path, source_path, source.get('symbol', ''), doc.get('capability_id', ''),
                                    doc.get('authoritative_domain', ''), *interface_terms,
                                    *doc.get('implementing_tickets', []))).lower()
                if needles in haystack:
                    rows.append({'map': path, 'path': source_path, 'symbol': source.get('symbol'),
                                 'capability_id': doc.get('capability_id'), 'source_sha256': digest,
                                 'authoritative_domain': doc.get('authoritative_domain'),
                                 'interfaces': [(interface.get('module') or '') + '.' + (interface.get('function') or '')
                                                for interface in interfaces],
                                 'ash': doc.get('ash', []),
                                 'safe_extensions': doc.get('safe_extensions', []),
                                 'reuse': doc.get('reuse', []),
                                 'prohibited_shortcuts': doc.get('prohibited_shortcuts', []),
                                 'tests': doc.get('tests', []),
                                 'persistence': doc.get('persistence', []),
                                 'semantic_map_refs': [source.get('id') for source in doc.get('sources', [])],
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
                    rows.append({'path': source_path, 'old_path': entry.get('old_path'), 'status': entry['status'],
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
                key = (symbol.get('module'), symbol.get('name'), symbol.get('arity'))
                if symbol.get('kind') == 'function':
                    symbol_exists = (True if key in current_symbols else
                                     None if symbol.get('module') in uncertain_modules or uncertain_without_module else False)
                elif symbol.get('kind') == 'module':
                    current_modules = {module for source in parsed_sources.values() for module in source.get('modules', [])}
                    symbol_exists = (True if symbol.get('module') in current_modules else
                                     None if symbol.get('module') in uncertain_modules or uncertain_without_module else False)
                else:
                    symbol_exists = False
                qualified = f"{symbol.get('module')}.{symbol.get('name')}/{symbol.get('arity')}"
                terms = (' '.join(str(symbol.get(key, '')) for key in ('module', 'name', 'path', 'reason'))
                         + ' ' + qualified).lower()
                if not ticket_match and needles not in terms:
                    continue
                rows.append({'path': source_path, 'symbol': symbol.get('name') or symbol.get('module'),
                             'module': symbol.get('module'), 'arity': symbol.get('arity'),
                             'visibility': symbol.get('visibility'), 'declaration': symbol.get('declaration'),
                             'old_sha256': symbol.get('old_sha256'), 'sha256': symbol.get('sha256'),
                             'change': symbol.get('change'),
                             'ticket_ids': doc.get('tickets', []), 'pr': doc.get('pr'),
                             'revision': revision, 'historical': True, 'exists_at_revision': symbol_exists,
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
    needs = sub.add_parser('needs-parser')
    needs.add_argument('--metadata-json', required=True)
    needs.add_argument('--github-output')
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
    elif args.command == 'needs-parser':
        metadata = _loads(Path(args.metadata_json).read_text())
        parser_required = parser_needed(args.repo, metadata)
        line = f'parser_required={str(parser_required).lower()}\n'
        github_output = args.github_output or os.environ.get('GITHUB_OUTPUT')
        if github_output:
            with open(github_output, 'a') as output:
                output.write(line)
        else:
            print(line, end='')
        return
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
