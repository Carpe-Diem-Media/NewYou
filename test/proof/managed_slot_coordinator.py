"""Bounded barriers for already-owned probe streams. Never manages jobs or databases.

Call coordinate with two directories, their independently obtained exact identities,
and two existing writable stdin streams. Failure preserves all control evidence;
the caller retains responsibility for owned processes and lease diagnosis.
"""
import io
import select
import json
import os
import re
from pathlib import Path
import stat
import time

LIMIT = 4096
KEYS = {'lease', 'generation', 'job', 'worktree', 'database', 'role'}

def private_directory(directory, uid=None):
    uid = os.getuid() if uid is None else uid
    path = Path(directory)
    if not path.is_absolute() or '..' in path.parts:
        raise OSError('absolute canonical directory required')
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in path.parts[1:]:
            nxt = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = nxt
        info = os.fstat(fd)
        if info.st_uid != uid or stat.S_IMODE(info.st_mode) != 0o700:
            raise OSError('private owner directory required')
        return fd
    except BaseException:
        os.close(fd)
        raise

def publish(directory, phase, payload):
    if phase not in ('ready','done','empty','child') or len(payload.encode()) > LIMIT:
        raise OSError('invalid record')
    directory_fd = private_directory(directory)
    try:
        fd = os.open(phase+'.json', os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                     0o600, dir_fd=directory_fd)
        with os.fdopen(fd, 'wb') as f:
            os.fchmod(f.fileno(), 0o600)
            f.write(payload.encode()+b'\n')
            f.flush()
            os.fsync(f.fileno())
    finally:
        os.close(directory_fd)

def read_record(directory, phase, expected):
    fd = private_directory(directory)
    try:
        try:
            record = os.open(phase+'.json', os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
        except FileNotFoundError:
            return None
        with os.fdopen(record,'rb') as f:
            info = os.fstat(f.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode)!=0o600 or info.st_nlink != 1:
                raise OSError('unsafe record')
            data = f.read(LIMIT+2)
            after = os.stat(phase+'.json',dir_fd=fd,follow_symlinks=False)
            if (info.st_dev,info.st_ino)!=(after.st_dev,after.st_ino):
                raise OSError('replaced record')
        if len(data)>LIMIT+1: raise ValueError('oversize record')
        if not data.endswith(b'\n'): return None
        value=json.loads(data)
        if {k:value.get(k) for k in KEYS}!=expected:
            raise ValueError('record identity or phase mismatch')
        return value
    finally:
        os.close(fd)

def send(stream, value, deadline):
    data = json.dumps(value).encode()+b'\n'
    if isinstance(stream, io.BytesIO):
        stream.write(data)
        return
    fd = stream.fileno()
    blocking = os.get_blocking(fd)
    os.set_blocking(fd, False)
    try:
        while data:
            remaining = deadline-time.monotonic()
            if remaining <= 0 or not select.select([], [fd], [], remaining)[1]:
                raise TimeoutError('ack write timed out; retain evidence')
            try:
                data = data[os.write(fd, data):]
            except BlockingIOError:
                continue
    finally:
        os.set_blocking(fd, blocking)

def coordinate(directories, identities, inputs, timeout=30, cancelled=lambda: False):
    if len(directories)!=2 or len(identities)!=2 or len(inputs)!=2 or not 0<timeout<=300:
        raise ValueError('bounded pair required')
    for identity in identities:
        if (set(identity)!=KEYS or
            any(not isinstance(identity[k],str) for k in KEYS) or
            any(not re.fullmatch('[0-9a-f]{32}',identity[k]) for k in ('lease','generation','job')) or
            not re.fullmatch(r'dc_new_you_s\d{2}_g'+identity['generation'],identity['database']) or
            identity['role']!=identity['database']+'_r' or
            not os.path.isabs(identity['worktree'])):
            raise ValueError('complete exact identity required')
    if identities[0]['database']==identities[1]['database']:
        raise ValueError('distinct databases required')
    deadline=time.monotonic()+timeout
    try:
        for phase in ('ready','done'):
            while True:
                if cancelled(): raise RuntimeError('cancelled; retain evidence')
                if time.monotonic()>=deadline: raise TimeoutError('retain evidence')
                records=[read_record(d,phase,i) for d,i in zip(directories,identities)]
                if all(records): break
                time.sleep(.01)
            for n, stream in enumerate(inputs):
                value=dict(ack=phase,identity=identities[n])
                if phase=='ready': value['peer_database']=identities[1-n]['database']
                send(stream, value, deadline)
    except BaseException:
        for stream in inputs:
            try: send(stream, {'cancel': True}, time.monotonic()+.05)
            except (OSError,ValueError): pass
        raise

if __name__=='__main__':
    import sys
    if len(sys.argv)!=5 or sys.argv[1]!='publish': raise SystemExit(2)
    publish(*sys.argv[2:])
