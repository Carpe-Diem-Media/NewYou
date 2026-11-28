"""Export bounded diagnostic counts, never raw messages, paths or credentials.

This same dependency-free reducer runs inside the guest. The host validates its
JSON again. Diagnostics are untrusted observations, never job-result authority.
"""
from itertools import islice
import json
import os
from pathlib import Path
import re
import stat

LEVELS = {'INFO', 'WARN', 'ERR', 'ERROR', 'CRIT', 'VERB'}
COMPONENTS = {'Runner', 'RunnerProcess', 'JobRunner', 'Worker', 'HostContext',
              'MessageListener', 'JobDispatcher', 'ConfigurationManager', 'Terminal'}
ERRORS = {'System.TimeoutException', 'System.Net.Http.HttpRequestException',
          'System.IO.IOException', 'System.OperationCanceledException'}
EVENTS = {'listening', 'job_started', 'job_completed', 'connection_failed'}


def empty():
    return {'schema': 1, 'files': 0, 'lines': 0, 'levels': {}, 'components': {},
            'errors': {}, 'events': {}, 'truncated': False}


def increment(result, group, key):
    result[group][key] = result[group].get(key, 0) + 1


def summarize_text(text):
    result = empty()
    lines = text.splitlines()
    result['truncated'] = len(lines) > 8192
    for line in lines[:8192]:
        result['lines'] += 1
        match = re.match(r'^\[[0-9TZ .:+-]+ ([A-Z]+) ([A-Za-z.]+)\]', line)
        if match:
            level, component = match.groups()
            if level in LEVELS:
                increment(result, 'levels', level)
            if component in COMPONENTS:
                increment(result, 'components', component)
        for error in ERRORS:
            if error in line:
                increment(result, 'errors', error)
        for marker, event in [('Listening for Jobs', 'listening'), ('Running job:', 'job_started'),
                              ('completed with result:', 'job_completed'), ('Failed to connect', 'connection_failed')]:
            if marker in line:
                increment(result, 'events', event)
    return result


def validate_snapshot(result):
    if not isinstance(result, dict) or set(result) != set(empty()):
        raise ValueError('invalid_diagnostic_shape')
    for key, maximum in [('schema', 1), ('files', 8), ('lines', 65536)]:
        if type(result[key]) is not int or not 0 <= result[key] <= maximum:
            raise ValueError('invalid_diagnostic_count')
    if result['schema'] != 1 or type(result['truncated']) is not bool:
        raise ValueError('invalid_diagnostic_schema')
    for group, allowed in [('levels', LEVELS), ('components', COMPONENTS), ('errors', ERRORS), ('events', EVENTS)]:
        values = result[group]
        if not isinstance(values, dict) or not set(values) <= allowed:
            raise ValueError('invalid_diagnostic_key')
        if any(type(value) is not int or not 0 <= value <= 65536 for value in values.values()):
            raise ValueError('invalid_diagnostic_count')


def collect(directory):
    try:
        directory_fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except OSError:
        return empty()
    try:
        return collect_fd(directory_fd)
    finally:
        os.close(directory_fd)


def collect_fd(directory_fd):
    result = empty()
    try:
        with os.scandir(directory_fd) as entries:
            candidates = list(islice(entries, 128))
    except FileNotFoundError:
        return result
    for entry in sorted(candidates, key=lambda item: item.name, reverse=True):
        if result['files'] >= 8:
            result['truncated'] = True
            break
        if not re.fullmatch(r'(Runner|Worker)_[0-9A-Za-z_-]+\.log', entry.name):
            continue
        try:
            fd = os.open(entry.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory_fd)
            with os.fdopen(fd, 'rb') as stream:
                if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                    continue
                # Read a tail to retain the newest events, with bounded memory.
                size = stream.seek(0, 2)
                stream.seek(max(0, size - 1048576))
                text = stream.read(1048576).decode('utf-8', errors='replace')
            part = summarize_text(text)
            result['files'] += 1
            result['lines'] += part['lines']
            result['truncated'] |= part['truncated'] or size > 1048576
            for group in ['levels', 'components', 'errors', 'events']:
                for key, value in part[group].items():
                    result[group][key] = result[group].get(key, 0) + value
        except OSError:
            continue
    validate_snapshot(result)
    return result


if __name__ == '__main__':
    print(json.dumps(collect(Path('/opt/actions-runner/_diag'))))
