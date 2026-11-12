"""Validate the versioned capability-map schema and source references (stdlib only).

The schema deliberately uses only $ref, type, const, enum, pattern, minLength,
minItems, required, properties, additionalProperties and items. This is a small
validator for that declared schema, not a general JSON Schema implementation.
Shape and locators cannot prove semantic truth; independent source review does.
"""
import hashlib
import argparse
import copy
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = ROOT / 'docs/development/knowledge/capability.schema.json'


def loads(text):
    def unique(pairs):
        obj = {}
        for key, value in pairs:
            if key in obj:
                raise ValueError('duplicate JSON key: ' + key)
            obj[key] = value
        return obj
    return json.loads(text, object_pairs_hook=unique)


def validate(value, rule, schema, location='$'):
    if '$ref' in rule:
        target = schema
        for part in rule['$ref'].removeprefix('#/').split('/'):
            target = target[part]
        return validate(value, target, schema, location)
    kinds = {'object': dict, 'array': list, 'string': str, 'integer': int, 'boolean': bool}
    if 'type' in rule and type(value) is not kinds[rule['type']]:
        raise ValueError(location + ': wrong type')
    if 'const' in rule and (type(value) is not type(rule['const']) or value != rule['const']):
        raise ValueError(location + ': unsupported version/value')
    if 'enum' in rule and value not in rule['enum']:
        raise ValueError(location + ': invalid choice')
    if isinstance(value, str):
        if len(value.strip()) < rule.get('minLength', 0):
            raise ValueError(location + ': empty text')
        if 'pattern' in rule and not re.search(rule['pattern'], value):
            raise ValueError(location + ': invalid format')
    if isinstance(value, list):
        if len(value) < rule.get('minItems', 0):
            raise ValueError(location + ': empty list')
        for i, item in enumerate(value):
            validate(item, rule['items'], schema, f'{location}[{i}]')
    if isinstance(value, dict):
        if set(rule.get('required', [])) - value.keys():
            raise ValueError(location + ': missing required fields')
        properties = rule.get('properties', {})
        if rule.get('additionalProperties') is False and value.keys() - properties.keys():
            raise ValueError(location + ': unknown fields')
        for name, item in value.items():
            if name in properties:
                validate(item, properties[name], schema, location + '.' + name)


def validate_map(record, root=ROOT):
    schema = loads(SCHEMA.read_text())
    validate(record, schema, schema)
    ids = set()
    for source in record['sources']:
        if source['id'] in ids:
            raise ValueError('duplicate source id')
        ids.add(source['id'])
        relative = PurePosixPath(source['path'])
        if relative.is_absolute() or str(relative) != source['path'] or '..' in relative.parts or '\\' in source['path']:
            raise ValueError('unsafe or aliased source path')
        path = root / source['path']
        if not path.is_file() or path.resolve() != root.resolve().joinpath(relative):
            raise ValueError('missing source or symlink substitution')
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != source['sha256']:
            raise ValueError('source changed; review and update capability map: ' + source['path'])
        if source['symbol'].encode() not in data:
            raise ValueError('source symbol not found: ' + source['path'])
    def references(value):
        if isinstance(value, dict):
            for key, item in value.items():
                if key == 'source_ids' and not set(item) <= ids:
                    raise ValueError('unknown source reference')
                references(item)
        elif isinstance(value, list):
            for item in value:
                references(item)
    references(record)
    by_id = {source['id']: source for source in record['sources']}
    for section, field in (('persistence', 'migration'), ('tests', 'path')):
        for entry in record[section]:
            linked = [by_id[s] for s in entry['source_ids'] if by_id[s]['path'] == entry[field]]
            if not linked:
                raise ValueError('unlinked ' + field)
            if section == 'persistence':
                content = (root / entry[field]).read_text()
                for name in entry['tables'] + entry['constraints']:
                    if name not in content:
                        raise ValueError('persistence locator not found: ' + name)
    states = record['lifecycle']['states']
    if len(set(states)) != len(states):
        raise ValueError('duplicate lifecycle state')
    for transition in record['lifecycle']['transitions']:
        if transition['from_state'] not in states or transition['to_state'] not in states:
            raise ValueError('unknown lifecycle state')


def refresh_sources(record, root=ROOT):
    """Refresh mechanical evidence only; the agent must review semantic claims.

    Require committed source bytes so the recorded revision contains every
    locator. Build and validate a copy before writing any map to disk.
    """
    schema = loads(SCHEMA.read_text())
    validate(record, schema, schema)
    updated = copy.deepcopy(record)
    revision = subprocess.check_output(['git', 'rev-parse', '--verify', 'HEAD'], cwd=root).decode().strip()
    for source in updated['sources']:
        relative = PurePosixPath(source['path'])
        if relative.is_absolute() or str(relative) != source['path'] or '..' in relative.parts or '\\' in source['path']:
            raise ValueError('unsafe or aliased source path')
        path = root / source['path']
        if not path.is_file() or path.resolve() != root.resolve().joinpath(relative):
            raise ValueError('missing source or symlink substitution')
        data = path.read_bytes()
        committed = subprocess.check_output(['git', 'show', revision + ':' + source['path']], cwd=root,
                                            stderr=subprocess.DEVNULL)
        if data != committed:
            raise ValueError('source must be committed before refreshing its evidence')
        source['sha256'] = hashlib.sha256(data).hexdigest()
    updated['implementation_revision']['git_sha'] = revision
    validate_map(updated, root)
    return updated


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--refresh', metavar='CAPABILITY_ID', help='refresh committed source hashes after semantic review')
    args = parser.parse_args()
    if args.refresh:
        if not re.fullmatch(r'[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+', args.refresh):
            raise ValueError('invalid capability ID')
        path = ROOT / 'docs/development/knowledge' / (args.refresh + '.json')
        if path.is_symlink():
            raise ValueError('symlink capability map')
        refreshed = refresh_sources(loads(path.read_text()))
        path.write_text(json.dumps(refreshed, indent=2) + '\n')
    paths = sorted((ROOT / 'docs/development/knowledge').glob('*.json'))
    records = [p for p in paths if p.name != SCHEMA.name]
    if not records:
        raise ValueError('no capability maps')
    ids = set()
    for path in records:
        record = loads(path.read_text())
        validate_map(record)
        if record['capability_id'] in ids or path.stem != record['capability_id']:
            raise ValueError('duplicate or misnamed capability')
        ids.add(record['capability_id'])
    print(json.dumps(dict(status='PASS', maps=len(records), verification='schema and exact source locators; not semantic proof')))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as exc:
        raise SystemExit(str(exc))
