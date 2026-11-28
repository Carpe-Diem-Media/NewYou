"""Fixed-category observations only. Timeouts are not host firewall proof."""
import errno
import json
import socket

CLASSES = {'host', 'gateway', 'lan', 'metadata', 'container', 'overlay'}
OUTCOMES = {'connected', 'refused', 'timeout', 'route_denied', 'permission_denied', 'probe_error'}
PORTS = (22, 80, 443, 2375, 55432, 55433)


def connect_outcome(host, port):
    sock = None
    try:
        sock = socket.socket()
        sock.settimeout(.3)
    except Exception:
        if sock is not None:
            try:
                sock.close()
            except Exception:
                pass
        return 'probe_error'
    try:
        sock.connect((host, port))
        outcome = 'connected'
    except TimeoutError:
        outcome = 'timeout'
    except OSError as exc:
        outcome = {errno.ECONNREFUSED: 'refused', errno.ETIMEDOUT: 'timeout',
                   errno.ENETUNREACH: 'route_denied', errno.EHOSTUNREACH: 'route_denied',
                   errno.EACCES: 'permission_denied', errno.EPERM: 'permission_denied'}.get(exc.errno, 'probe_error')
    except Exception:
        outcome = 'probe_error'
    finally:
        try:
            sock.close()
        except Exception:
            outcome = 'probe_error'
    return outcome


def probe(groups):
    observations = []
    for target_class, hosts in groups.items():
        if target_class not in CLASSES or not hosts:
            raise ValueError('invalid_probe_configuration')
        for host in hosts:
            for port in PORTS:
                outcome = connect_outcome(host, port)
                if outcome != 'timeout':
                    observations.append({'target_class': target_class, 'outcome': outcome})
                    return {'status': 'failed', 'observations': observations}
        observations.append({'target_class': target_class, 'outcome': 'timeout'})
    if not observations:
        raise ValueError('invalid_probe_configuration')
    return {'status': 'timeouts_only', 'observations': observations}


if __name__ == '__main__':
    # TARGET_GROUPS is supplied by trusted controller source over SSH stdin.
    print(json.dumps(probe(TARGET_GROUPS)))
