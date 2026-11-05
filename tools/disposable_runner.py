"""Bounded, repository-only KVM proving runner controller.

Run on the trusted workstation, never inside CI. Credentials are obtained by gh
on the host; only a single-use JIT configuration enters the guest. State contains
resource identities and bounded evidence, never registration payloads or logs.
"""
import argparse
import fcntl
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import signal
import selectors
import threading
import subprocess
import sys
import time
import uuid
import xml.etree.ElementTree as ET

try:
    from tools import runner_diagnostics as diagnostics
except ModuleNotFoundError:
    import runner_diagnostics as diagnostics

REPO = 'JCSchoeman96/NewYou'
URI = 'qemu:///system'
POOL = 'ci'
GUEST_IP = '10.77.77.150'
GATEWAY = '10.77.77.1'
LABEL = 'newyou-well93-proving'
ROOT = Path.home() / '.local/state/newyou-ci'
IMAGE = Path.home() / '.local/share/newyou-ci/images/ubuntu-24.04-server-cloudimg-amd64.img'
IMAGE_SHA = '04e8f2461a16a44e78a370284471f29616cdd9baf1893df25807b71f985b6c94'
TRANSITIONS = {
    'provisioning': {'isolated', 'failed', 'cancelled', 'teardown'},
    'isolated': {'registered', 'failed', 'cancelled', 'teardown'},
    'registered': {'executing', 'failed', 'cancelled', 'teardown'},
    'executing': {'succeeded', 'failed', 'cancelled', 'teardown'},
    'succeeded': {'teardown'}, 'failed': {'teardown'}, 'cancelled': {'teardown'},
    'teardown': {'cleaned', 'cleanup_failed'}, 'cleanup_failed': {'teardown'},
    'cleaned': set(),
}


def can_transition(before, after):
    return after in TRANSITIONS.get(before, set())


def execution_policy(profile):
    if profile == 'proof':
        return {'workflow': '.github/workflows/disposable-runner-proof.yml',
                'branch': 'well-93-proving-run', 'label': LABEL, 'job_seconds': 600, 'memory': 2048}
    if profile == 'application':
        return {'workflow': '.github/workflows/disposable-runner-application.yml',
                'branch': 'well-93-application-run', 'label': 'newyou-well93-application', 'job_seconds': 3600, 'memory': 4096}
    raise RuntimeError('unknown_execution_profile')


def capacity_error(available_mb, swap_free_mb, guest_mb, disk_free_mb, full_pressure=0.0):
    if guest_mb < 2048 or guest_mb > 4096:
        return 'guest_memory_out_of_bounds'
    if available_mb < guest_mb + 6144:
        return 'host_memory_reserve'
    if full_pressure >= 1.0:
        return 'host_memory_pressure'
    if swap_free_mb < 1024:
        return 'host_swap_reserve'
    if disk_free_mb < 32768:
        return 'host_disk_reserve'
    return None


def network_filter(name, host_addresses, host_routes=()):
    """Enforced outside guest. IPv4 public web/DNS only; no guest lateral access.

    Established SSH replies permit host administration. New connections to the
    host, LAN, DevCore, CGNAT, metadata and non-public ranges are dropped first.
    No guest IPv6, VLAN or other Ethernet protocols are allowed.
    """
    root = ET.Element('filter', name=name, chain='root')
    ET.SubElement(root, 'filterref', filter='no-mac-spoofing')
    ET.SubElement(root, 'filterref', filter='no-arp-spoofing')
    ET.SubElement(root, 'filterref', filter='no-ip-spoofing')
    def rule(action, direction, protocol, **attrs):
        item = ET.SubElement(root, 'rule', action=action, direction=direction,
                             priority=str(len(root) * 5))
        ET.SubElement(item, protocol, **attrs)
    rule('drop', 'inout', 'ipv6')
    rule('accept', 'out', 'arp', arpdstipaddr=GATEWAY)
    rule('accept', 'in', 'arp', arpsrcipaddr=GATEWAY)
    rule('accept', 'in', 'tcp', srcipaddr=GATEWAY, dstportstart='22', state='NEW,ESTABLISHED')
    rule('accept', 'out', 'tcp', dstipaddr=GATEWAY, srcportstart='22', state='ESTABLISHED')
    denied = ['0.0.0.0/8', '10.0.0.0/8', '100.64.0.0/10', '127.0.0.0/8',
              '169.254.0.0/16', '172.16.0.0/12', '192.0.0.0/24', '192.0.2.0/24',
              '192.168.0.0/16', '198.18.0.0/15', '198.51.100.0/24',
              '203.0.113.0/24', '224.0.0.0/4', '240.0.0.0/4']
    denied += [str(ipaddress.ip_network(addr + '/32')) for addr in host_addresses
               if ipaddress.ip_address(addr).version == 4]
    denied += list(host_routes)
    networks = list(ipaddress.collapse_addresses(ipaddress.ip_network(cidr) for cidr in denied))
    if len(networks) > 150:
        raise RuntimeError('too_many_routes_for_filter')
    for net in networks:
        rule('drop', 'out', 'all', dstipaddr=str(net.network_address), dstipmask=str(net.prefixlen))
    rule('accept', 'out', 'udp', dstipaddr='1.1.1.1', dstportstart='53')
    rule('accept', 'in', 'udp', srcipaddr='1.1.1.1', srcportstart='53', state='ESTABLISHED')
    for port in ['80', '443']:
        rule('accept', 'out', 'tcp', dstportstart=port)
    rule('accept', 'in', 'tcp', state='ESTABLISHED')
    rule('drop', 'inout', 'all')
    # Ethernet rules run before IP rules. Permit IPv4 to reach the IP filter;
    # the default IP drop above still rejects every unspecified flow.
    rule('accept', 'inout', 'mac', protocolid='ipv4')
    rule('drop', 'inout', 'mac')
    return ET.tostring(root, encoding='unicode')


def verify_filter(expected, actual):
    # Libvirt can silently discard unknown attributes or replace out-of-range
    # priorities. Compare its stored rules before attaching any guest.
    def rules(xml):
        root = ET.fromstring(xml)
        return [(dict(rule.attrib), [(item.tag, dict(item.attrib)) for item in rule])
                for rule in root.findall('rule')]
    if rules(expected) != rules(actual):
        raise RuntimeError('libvirt_filter_changed_rules')


def cleanup_steps(remove):
    """Continue after errors, retain failure state for explicit reconciliation."""
    errors = []
    for kind in ['domain', 'registration', 'volumes', 'filter', 'keys']:
        try:
            remove(kind)
        except Exception:
            errors.append(kind)
    return errors


def command(args, *, data=None, timeout=120, check=True, discard_output=False, max_output=None):
    # Never interpolate guest output or credentials into host commands. Do not
    # include subprocess output in errors: gh/ssh failures may contain secrets.
    if max_output is not None:
        return bounded_command(args, data=data, timeout=timeout, max_output=max_output, check=check)
    output = subprocess.DEVNULL if discard_output else subprocess.PIPE
    proc = subprocess.run(args, input=data, stdout=output, stderr=output, text=True, timeout=timeout)
    if check and proc.returncode:
        raise RuntimeError('command_failed:' + Path(args[0]).name)
    return proc


def bounded_command(args, *, data=None, timeout=20, max_output=16384, check=True):
    """Bound hostile guest output in memory; never write an unvalidated spool."""
    proc = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    output = bytearray()
    deadline = time.monotonic() + timeout
    try:
        pending = memoryview((data or '').encode())
        os.set_blocking(proc.stdin.fileno(), False)
        os.set_blocking(proc.stdout.fileno(), False)
        with selectors.DefaultSelector() as selector:
            selector.register(proc.stdout, selectors.EVENT_READ)
            if pending:
                selector.register(proc.stdin, selectors.EVENT_WRITE)
            else:
                proc.stdin.close()
            while selector.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise subprocess.TimeoutExpired('bounded_command', timeout)
                events = selector.select(remaining)
                if not events:
                    raise subprocess.TimeoutExpired('bounded_command', timeout)
                for key, _ in events:
                    if key.fileobj is proc.stdin:
                        try:
                            sent = os.write(proc.stdin.fileno(), pending[:4096])
                            pending = pending[sent:]
                        except BrokenPipeError:
                            raise RuntimeError('input_delivery_failed') from None
                        if not pending:
                            selector.unregister(proc.stdin)
                            proc.stdin.close()
                    else:
                        chunk = os.read(proc.stdout.fileno(), 4096)
                        if not chunk:
                            selector.unregister(proc.stdout)
                        else:
                            output.extend(chunk)
                            if len(output) > max_output:
                                raise RuntimeError('output_limit')
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise subprocess.TimeoutExpired('bounded_command', timeout)
        proc.wait(timeout=remaining)
        if check and proc.returncode:
            raise RuntimeError('bounded_command_failed')
        return subprocess.CompletedProcess(args, proc.returncode, output.decode(), '')
    finally:
        if proc.poll() is None:
            proc.kill()
        proc.wait()
        proc.stdout.close()
        proc.stdin.close()


def virsh(*args, **kw):
    return command(['virsh', '-c', URI, *args], **kw)


class GitHubError(RuntimeError):
    """HTTP status only. Never retain response text or request credentials."""
    def __init__(self, status):
        self.status = status
        super().__init__('github_http_' + str(status))


def github(path, method='GET', body=None):
    args = ['gh', 'api', '--method', method, f'repos/{REPO}/{path}']
    if body is not None:
        args += ['--input', '-']
    result = command(args, data=json.dumps(body) if body else None, check=False)
    if result.returncode:
        match = re.search(r'HTTP (\d{3})', result.stderr)
        if match:
            raise GitHubError(int(match.group(1)))
        raise RuntimeError('github_request_failed')
    return json.loads(result.stdout) if result.stdout.strip() else None


def save(state):
    state['updated_at'] = int(time.time())
    path = ROOT / (state['name'] + '.json')
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(state, indent=2) + '\n')
    os.chmod(temp, 0o600)
    with temp.open() as stream:
        os.fsync(stream.fileno())
    temp.replace(path)
    fd = os.open(ROOT, os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def transition(state, after):
    if not can_transition(state['phase'], after):
        raise RuntimeError('invalid_transition')
    state['phase'] = after
    state.setdefault('history', []).append({'phase': after, 'at': int(time.time())})
    save(state)


def addresses():
    data = json.loads(command(['ip', '-j', 'address']).stdout)
    return [a['local'] for interface in data for a in interface['addr_info']]


def preflight(memory):
    mem = {}
    for line in Path('/proc/meminfo').read_text().splitlines():
        key, value = line.split(':', 1)
        mem[key] = int(value.strip().split()[0]) // 1024
    free = shutil.disk_usage('/var/lib/libvirt/images/ci').free // 1048576
    pressure = dict(field.split('=') for field in Path('/proc/pressure/memory').read_text().splitlines()[1].split()[1:])
    error = capacity_error(mem['MemAvailable'], mem['SwapFree'], memory, free, float(pressure['avg10']))
    if error:
        raise RuntimeError(error)
    if not os.access('/dev/kvm', os.R_OK | os.W_OK):
        raise RuntimeError('kvm_unavailable')
    if hashlib.file_digest(IMAGE.open('rb'), 'sha256').hexdigest() != IMAGE_SHA:
        raise RuntimeError('unverified_image')
    info = json.loads(command(['qemu-img', 'info', '--output=json', str(IMAGE)]).stdout)
    if 'backing-filename' in info or info.get('format') != 'qcow2':
        raise RuntimeError('unexpected_image_chain')
    network = ET.fromstring(virsh('net-dumpxml', 'ci-nat').stdout)
    if (network.find('forward').get('mode') != 'nat'
            or network.find('bridge').get('name') != 'virbr-ci'
            or network.find('ip').get('address') != GATEWAY):
        raise RuntimeError('network_drift')
    return {'available_mb': mem['MemAvailable'], 'swap_free_mb': mem['SwapFree'],
            'disk_free_mb': free, 'guest_mb': memory, 'memory_full_avg10': float(pressure['avg10']), 'image_sha256': IMAGE_SHA}


class SSHFailure(RuntimeError):
    """Only fixed categories may cross the guest transport boundary."""
    def __init__(self, category):
        self.category = category if category in {'ssh_transport', 'timeout', 'guest_command', 'output_limit', 'unknown'} else 'unknown'
        super().__init__(self.category)


def ssh(state, script, timeout=120, max_output=None):
    directory = ROOT / state['name']
    try:
        result = command(['ssh', '-F', '/dev/null', '-i', str(directory / 'control'),
                    '-o', 'IdentitiesOnly=yes', '-o', 'BatchMode=yes',
                    '-o', 'ForwardAgent=no', '-o', 'ClearAllForwardings=yes',
                    '-o', 'StrictHostKeyChecking=yes', '-o', 'ConnectTimeout=5',
                    '-o', f'UserKnownHostsFile={directory / "known_hosts"}',
                    f'root@{GUEST_IP}', 'bash -s; result=$?; if [ "$result" -eq 0 ]; then exit 0; else exit 1; fi'], data=script, timeout=timeout, max_output=max_output, check=False)
    except subprocess.TimeoutExpired:
        raise SSHFailure('timeout') from None
    except OSError:
        raise SSHFailure('ssh_transport') from None
    except RuntimeError as exc:
        raise SSHFailure('output_limit' if str(exc) == 'output_limit' else 'unknown') from None
    if result.returncode:
        raise SSHFailure('ssh_transport' if result.returncode == 255 or result.returncode < 0 else 'guest_command')
    return result


def provision(state, memory):
    directory = ROOT / state['name']
    directory.mkdir(mode=0o700)
    command(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(directory / 'control')])
    command(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(directory / 'host')])
    pub = (directory / 'control.pub').read_text().strip()
    host = (directory / 'host').read_text()
    hostpub = (directory / 'host.pub').read_text().strip()
    (directory / 'known_hosts').write_text(f'{GUEST_IP} {hostpub}\n')
    user_data = {
        'hostname': state['name'], 'disable_root': False, 'ssh_pwauth': False,
        'users': [{'name': 'root', 'ssh_authorized_keys': [pub]},
                  {'name': 'runner', 'shell': '/bin/bash', 'lock_passwd': True}],
        'ssh_keys': {'ed25519_private': host, 'ed25519_public': hostpub},
        'write_files': [{'path': '/etc/ssh/sshd_config.d/01-newyou.conf',
                         'content': 'PasswordAuthentication no\nAllowAgentForwarding no\nAllowTcpForwarding no\nX11Forwarding no\n'}],
        'runcmd': [['touch', '/root/newyou-bootstrap-ready']],
    }
    (directory / 'user-data').write_text('#cloud-config\n' + json.dumps(user_data))
    (directory / 'meta-data').write_text(json.dumps({'instance-id': state['uuid'], 'local-hostname': state['name']}))
    net = {'version': 2, 'ethernets': {'enp1s0': {'match': {'macaddress': state['mac']},
           'set-name': 'enp1s0', 'dhcp4': False, 'dhcp6': False, 'accept-ra': False,
           'addresses': [GUEST_IP + '/24'], 'routes': [{'to': 'default', 'via': GATEWAY}],
           'nameservers': {'addresses': ['1.1.1.1']}}}}
    (directory / 'network').write_text(json.dumps(net))
    command(['cloud-localds', '--network-config=' + str(directory / 'network'),
             str(directory / 'seed.iso'), str(directory / 'user-data'), str(directory / 'meta-data')])
    # Upload a private standalone copy. Never reuse the unproven existing base.
    command(['cp', '--reflink=auto', str(IMAGE), str(directory / 'disk.qcow2')])
    command(['qemu-img', 'resize', str(directory / 'disk.qcow2'), '24G' if state.get('profile') == 'application' else '12G'])
    for suffix, filename, fmt in [('disk.qcow2', 'disk.qcow2', 'qcow2'), ('seed.iso', 'seed.iso', 'raw')]:
        vol = state['name'] + '-' + suffix
        virsh('vol-create-as', POOL, vol, str((directory / filename).stat().st_size), '--format', fmt)
        virsh('vol-upload', '--pool', POOL, vol, str(directory / filename))
    filter_file = directory / 'filter.xml'
    routes = json.loads(command(['ip', '-j', '-4', 'route', 'show', 'table', 'all']).stdout)
    denied_routes = sorted({r['dst'] for r in routes if r.get('dst', 'default') != 'default'})
    state['denied_routes'] = denied_routes
    save(state)
    filter_file.write_text(network_filter(state['name'], addresses(), denied_routes))
    virsh('nwfilter-define', str(filter_file))
    verify_filter(filter_file.read_text(), virsh('nwfilter-dumpxml', state['name']).stdout)
    disk_path = virsh('vol-path', '--pool', POOL, state['name'] + '-disk.qcow2').stdout.strip()
    seed_path = virsh('vol-path', '--pool', POOL, state['name'] + '-seed.iso').stdout.strip()
    xml = f'''<domain type="kvm"><name>{state['name']}</name><uuid>{state['uuid']}</uuid>
<memory unit="MiB">{memory}</memory><vcpu>2</vcpu><os><type arch="x86_64" machine="q35">hvm</type><boot dev="hd"/></os>
<features><acpi/><apic/></features><cpu mode="host-passthrough"/><clock offset="utc"/>
<on_poweroff>destroy</on_poweroff><on_reboot>destroy</on_reboot><on_crash>destroy</on_crash>
<devices><disk type="file" device="disk"><driver name="qemu" type="qcow2"/><source file="{disk_path}"/><target dev="vda" bus="virtio"/></disk>
<disk type="file" device="cdrom"><driver name="qemu" type="raw"/><source file="{seed_path}"/><target dev="sda" bus="sata"/><readonly/></disk>
<interface type="network"><mac address="{state['mac']}"/><source network="ci-nat"/><model type="virtio"/>
<filterref filter="{state['name']}"><parameter name="IP" value="{GUEST_IP}"/></filterref></interface>
<serial type="pty"><target port="0"/></serial><console type="pty"><target type="serial" port="0"/></console>
<memballoon model="none"/></devices></domain>'''
    (directory / 'domain.xml').write_text(xml)
    virsh('define', str(directory / 'domain.xml'))
    virsh('start', state['name'])
    deadline = time.monotonic() + 240
    while time.monotonic() < deadline:
        try:
            ssh(state, 'test -f /root/newyou-bootstrap-ready', timeout=10)
            return
        except (RuntimeError, subprocess.TimeoutExpired):
            time.sleep(3)
    raise RuntimeError('guest_boot_timeout')


def validate_network_report(report, expected_classes=None):
    classes = {'host', 'gateway', 'lan', 'metadata', 'container', 'overlay'}
    outcomes = {'connected', 'refused', 'timeout', 'route_denied', 'permission_denied', 'probe_error'}
    if not isinstance(report, dict) or set(report) != {'status', 'observations'}:
        raise ValueError('invalid_network_projection')
    observations = report['observations']
    if not isinstance(report['status'], str) or report['status'] not in {'failed', 'timeouts_only'} or not isinstance(observations, list) or not 1 <= len(observations) <= 6:
        raise ValueError('invalid_network_projection')
    seen = set()
    for item in observations:
        if (not isinstance(item, dict) or set(item) != {'target_class', 'outcome'}
                or not isinstance(item['target_class'], str) or item['target_class'] not in classes
                or item['target_class'] in seen or not isinstance(item['outcome'], str) or item['outcome'] not in outcomes):
            raise ValueError('invalid_network_projection')
        seen.add(item['target_class'])
    if report['status'] == 'timeouts_only':
        if any(x['outcome'] != 'timeout' for x in observations) or (expected_classes is not None and seen != set(expected_classes)):
            raise ValueError('invalid_network_projection')
    elif observations[-1]['outcome'] == 'timeout' or any(x['outcome'] != 'timeout' for x in observations[:-1]):
        raise ValueError('invalid_network_projection')
    if expected_classes is not None and not seen.issubset(set(expected_classes)):
        raise ValueError('invalid_network_projection')
    return report


def prepare(state, stage, script, timeout, network_classes=None):
    if stage not in {'apt_update', 'apt_upgrade', 'runner_libraries', 'reboot_guard',
                     'guest_privilege', 'guest_socket', 'guest_credentials',
                     'forbidden_connectivity', 'public_https', 'application_bootstrap'}:
        raise RuntimeError('unknown_preparation_stage')
    item = {'stage': stage, 'status': 'running', 'at': int(time.time())}
    if network_classes is not None:
        state.pop('network_diagnostics', None)
    # Replace earlier observations for a stage to keep this projection bounded.
    state['preparation'] = [x for x in state.get('preparation', []) if x.get('stage') != stage][-9:] + [item]
    save(state)
    try:
        result = ssh(state, script, timeout=timeout, max_output=4096)
        if network_classes is not None:
            report = validate_network_report(json.loads(result.stdout), network_classes)
            state['network_diagnostics'] = report
            if report['status'] != 'timeouts_only':
                raise SSHFailure('guest_command')
    except Exception as exc:
        item['failure'] = exc.category if isinstance(exc, SSHFailure) else 'unknown'
        item['status'] = 'failed'
        save(state)
        raise RuntimeError('guest_preparation_failed:' + stage) from None
    item['status'] = 'passed'
    save(state)


def isolate(state):
    # Retain only fixed stage/status enums; package and guest output stay private
    # inside the disposable guest and are never copied into the host journal.
    commands = [
        ('apt_update', 'apt-get -qq -o APT::Update::Error-Mode=any -o Acquire::Retries=0 -o Acquire::http::Timeout=20 update >/root/update.log 2>&1'),
        ('apt_upgrade', 'apt-get -y -qq upgrade >/root/patch.log 2>&1'),
        ('runner_libraries', 'apt-get -y -qq install curl ca-certificates libicu74 python3 >/root/deps.log 2>&1'),
        ('reboot_guard', 'test ! -f /var/run/reboot-required'),
    ]
    for stage, command_text in commands:
        prepare(state, stage, 'set -eu\nexport DEBIAN_FRONTEND=noninteractive\n' + command_text, 600)
    # Control-plane inspection is independent of guest assertions.
    xml = ET.fromstring(virsh('dumpxml', state['name']).stdout)
    if xml.findall('.//filesystem') or xml.findall('.//hostdev') or xml.findall('.//channel'):
        raise RuntimeError('unexpected_host_attachment')
    if len(xml.findall('.//interface')) != 1 or xml.find('.//filterref').get('filter') != state['name']:
        raise RuntimeError('filter_missing')
    hosts = addresses()
    groups = {'gateway': [GATEWAY], 'lan': ['192.168.68.1'],
              'metadata': ['169.254.169.254'], 'overlay': ['100.100.100.100'],
              'container': ['172.17.0.1', '172.18.0.1'],
              'host': sorted({a for a in hosts if ':' not in a and a not in {'127.0.0.1', GATEWAY}})}
    groups = {key: value for key, value in groups.items() if value}
    prepare(state, 'guest_privilege', '''set -eu
test "$(id -u runner)" -ne 0
groups=$(id -nG runner)
if printf '%s\n' "$groups" | grep -Eq '(^| )(sudo|docker|libvirt)( |$)'; then exit 1; fi
python3 - <<'POLICY'
''' + Path(__file__).with_name('runner_guest_privilege.py').read_text() + '''
POLICY
''', 20)
    prepare(state, 'guest_socket', 'set -eu\ntest ! -S /var/run/docker.sock\n', 20)
    prepare(state, 'guest_credentials', 'set -eu\ntest ! -e /home/runner/.config/gh\ntest ! -e /home/runner/.config/dev-core\ntest ! -e /root/.config/dev-core\n', 20)
    probe = ("set -eu\npython3 - <<'CHECK'\nTARGET_GROUPS = " + repr(groups) + '\n'
             + Path(__file__).with_name('runner_guest_network.py').read_text() + '\nCHECK\n')
    prepare(state, 'forbidden_connectivity', probe, 90, network_classes=groups)
    prepare(state, 'public_https', 'curl --fail --silent --max-time 20 https://api.github.com/zen >/dev/null', 30)
    # Guest timeouts do not establish effective host DROP enforcement. This
    # interlock remains until interface-bound host rule/order/counter evidence
    # can be independently obtained and implemented. No user bypass exists.
    state['network_proof'] = 'effective_firewall_unverified'
    save(state)
    raise RuntimeError('effective_firewall_proof_required')


def export_diagnostics(state):
    directory = ROOT / 'evidence' / state['name']
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        raw = ssh(state, 'python3 /root/newyou-export-diagnostics.py', timeout=12, max_output=16384).stdout
        report = json.loads(raw)
        diagnostics.validate_snapshot(report)
        record = {'at': int(time.time()), 'status': 'exported', 'projection': report}
    except Exception:
        # Preserve earlier snapshots after a crashed guest becomes unreachable.
        record = {'at': int(time.time()), 'status': 'unavailable', 'reason': 'guest_unreachable_or_invalid'}
    path = directory / 'diagnostics.jsonl'
    with path.open('a') as stream:
        stream.write(json.dumps(record) + '\n')
        stream.flush()
        os.fsync(stream.fileno())
    os.chmod(path, 0o600)
    return {'status': record['status'], 'path': str(path)}


class DiagnosticStream:
    """Bounded periodic export survives guest loss via prior host snapshots."""
    def __init__(self, state):
        self.state = state
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self.run, daemon=True)

    def run(self):
        for _ in range(execution_policy(self.state.get('profile', 'proof'))['job_seconds'] // 5 + 1):
            try:
                export_diagnostics(self.state)
            except Exception:
                break
            if self.stop.wait(5):
                break

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *args):
        self.stop.set()
        self.thread.join(timeout=15)


def cancel_owned_run(state):
    if not state.get('run_id') or state.get('result') == 'success':
        return
    path = 'actions/runs/' + str(state['run_id'])
    if github(path)['status'] == 'completed':
        return
    for endpoint in ['/cancel', '/force-cancel']:
        try:
            github(path + endpoint, 'POST')
        except GitHubError as exc:
            if exc.status != 409:
                raise
        # An offline guest cannot acknowledge cancellation. GitHub documents
        # force-cancel for runs that do not respond to ordinary cancellation.
        # Never delete a busy registration or claim cleanup on a POST alone.
        for _ in range(3):
            if github(path)['status'] == 'completed':
                return
            time.sleep(2)
    raise RuntimeError('run_cancellation_unresolved')


def reconcile_registration(state):
    """Preserve unknown creations until a concrete registration is reclaimed.

    One empty lookup cannot settle a timed-out POST. A durable unresolved journal
    blocks the next provision; recovery must find and delete the late runner.
    Never reissue a registration POST for the same request.
    """
    if not state.get('registration_attempted'):
        return
    ids = set(state.get('observed_runner_ids', []))
    if state.get('runner_id') is not None:
        ids.add(state['runner_id'])
    page = 1
    while True:
        items = github(f'actions/runners?per_page=100&page={page}')['runners']
        ids.update(item['id'] for item in items if item['name'] == state['name'])
        if len(items) < 100:
            break
        page += 1
    state['observed_runner_ids'] = sorted(ids)
    save(state)
    if not ids and state.get('registration_outcome') != 'removed':
        raise RuntimeError('registration_creation_unresolved')
    for runner_id in sorted(ids):
        try:
            github('actions/runners/' + str(runner_id), 'DELETE')
        except GitHubError as exc:
            if exc.status != 404:
                raise
    state['registration_outcome'] = 'removed'
    save(state)


def cleanup(state):
    if state['phase'] == 'cleaned':
        return
    state.setdefault('result', 'unknown')
    journal_failed = False
    if state['phase'] != 'teardown':
        try:
            transition(state, 'teardown')
        except OSError:
            journal_failed = True
    if state.get('diagnostics_installed'):
        try:
            state['diagnostics'] = export_diagnostics(state)
        except Exception:
            state['diagnostics'] = {'status': 'unavailable', 'reason': 'host_storage_failure'}
        try:
            save(state)
        except OSError:
            journal_failed = True
    def remove(kind):
        if kind == 'domain':
            domains = virsh('list', '--all', '--name').stdout.split()
            if state['name'] in domains:
                xml = ET.fromstring(virsh('dumpxml', state['name']).stdout)
                if xml.findtext('uuid') != state['uuid']:
                    raise RuntimeError('domain_identity_mismatch')
                if virsh('domstate', state['name']).stdout.strip() != 'shut off':
                    virsh('destroy', state['name'])
                virsh('undefine', state['name'])
        elif kind == 'registration':
            # Name is persisted before creating JIT configuration, so response
            # loss cannot orphan a registration whose numeric id was not saved.
            cancel_owned_run(state)
            reconcile_registration(state)
        elif kind == 'volumes':
            if state['name'] in virsh('list', '--all', '--name').stdout.split():
                raise RuntimeError('domain_still_exists')
            existing = [line.split()[0] for line in virsh('vol-list', POOL).stdout.splitlines()[2:] if line.strip()]
            for suffix in ['disk.qcow2', 'seed.iso']:
                name = state['name'] + '-' + suffix
                if name in existing:
                    virsh('vol-delete', '--pool', POOL, name)
        elif kind == 'filter':
            existing = virsh('nwfilter-list').stdout
            if state['name'] in existing.split():
                virsh('nwfilter-undefine', state['name'])
        elif kind == 'keys':
            shutil.rmtree(ROOT / state['name'], ignore_errors=False) if (ROOT / state['name']).exists() else None
    errors = cleanup_steps(remove)
    if journal_failed:
        errors.append('journal')
    state['cleanup_errors'] = errors
    try:
        transition(state, 'cleanup_failed' if errors else 'cleaned')
    except OSError:
        if 'journal' not in errors:
            errors.append('journal')
        state['phase'] = 'cleanup_failed'
    if errors:
        raise RuntimeError('cleanup_incomplete:' + ','.join(errors))


def execute(state, run_id, expected_sha):
    if state.get('phase') != 'isolated':
        raise RuntimeError('isolation_not_proven')
    policy = execution_policy(state.get('profile', 'proof'))
    run = github('actions/runs/' + str(run_id))
    if (run['head_sha'] != expected_sha or run['event'] != 'push'
            or run['head_branch'] != policy['branch']
            or run['path'] != policy['workflow']
            or run['status'] != 'queued'):
        raise RuntimeError('unapproved_proving_run')
    state['run_id'] = run_id
    state['sha'] = expected_sha
    save(state)
    if state.get('profile') == 'application':
        bootstrap = Path(__file__).with_name('runner_guest_application.sh').read_text()
        prepare(state, 'application_bootstrap', bootstrap, 600)
        state['rootless_docker_verified'] = True
        save(state)
    applications = github('actions/runners/downloads')
    app = next(a for a in applications if a['os'] == 'linux' and a['architecture'] == 'x64')
    if not re.fullmatch(r'[a-f0-9]{64}', app.get('sha256_checksum', '')):
        raise RuntimeError('runner_checksum_unavailable')
    # URL/checksum are GitHub control-plane data, validated before shell use.
    url = app['download_url']
    if not re.fullmatch(r'https://github.com/actions/runner/releases/download/[A-Za-z0-9./_-]+', url):
        raise RuntimeError('unexpected_runner_source')
    ssh(state, f'''set -eu
install -d -o runner -g runner /opt/actions-runner
curl -fLsS '{url}' -o /tmp/runner.tar.gz
printf '%s  /tmp/runner.tar.gz\\n' '{app['sha256_checksum']}' | sha256sum -c - >/dev/null
tar -xzf /tmp/runner.tar.gz -C /opt/actions-runner
chown -R runner:runner /opt/actions-runner
rm /tmp/runner.tar.gz
''', timeout=180)
    reducer = Path(diagnostics.__file__).read_text()
    ssh(state, "cat > /root/newyou-export-diagnostics.py <<'NEWYOU_DIAG'\n" + reducer + '\nNEWYOU_DIAG\nchmod 700 /root/newyou-export-diagnostics.py\n')
    state['diagnostics_installed'] = True
    state['runner_artifact'] = {'url': url, 'sha256': app['sha256_checksum']}
    state['registration_attempted'] = True
    state['registration_outcome'] = 'unknown'
    save(state)
    jit = github('actions/runners/generate-jitconfig', 'POST', {
        'name': state['name'], 'runner_group_id': 1,
        'labels': [policy['label']], 'work_folder': '_work'})
    state['runner_id'] = jit['runner']['id']
    state['registration_outcome'] = 'acknowledged'
    transition(state, 'registered')
    transition(state, 'executing')
    # Read the one-use payload into the guest shell, then run unprivileged. Its
    # credential never enters host argv, disk, state or diagnostic output.
    script = '''set -eu
IFS= read -r jit
cd /opt/actions-runner
if [ -S "/run/user/$(id -u runner)/docker.sock" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u runner)"
    export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/docker.sock"
    exec runuser -u runner -- env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DOCKER_HOST="$DOCKER_HOST" ./run.sh --jitconfig "$jit"
fi
exec runuser -u runner -- ./run.sh --jitconfig "$jit"
'''
    # ssh executes a constant command, payload goes only through stdin.
    directory = ROOT / state['name']
    # Shell reads the program before stdin is used for the one-use payload.
    ssh(state, "cat > /root/launch-runner <<'SCRIPT'\n" + script + '\nSCRIPT\nchmod 700 /root/launch-runner\n')
    args = ['ssh', '-F', '/dev/null', '-i', str(directory / 'control'),
            '-o', 'BatchMode=yes', '-o', 'IdentitiesOnly=yes', '-o', 'ForwardAgent=no',
            '-o', 'ClearAllForwardings=yes', '-o', 'StrictHostKeyChecking=yes',
            '-o', f'UserKnownHostsFile={directory / "known_hosts"}',
            f'root@{GUEST_IP}', '/root/launch-runner']
    with DiagnosticStream(state):
        command(args, data=jit['encoded_jit_config'] + '\n', timeout=policy['job_seconds'], discard_output=True)
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        run = github('actions/runs/' + str(run_id))
        if run['status'] == 'completed':
            break
        time.sleep(3)
    jobs = github(f'actions/runs/{run_id}/jobs')['jobs']
    record_job_result(state, run, jobs)


def record_job_result(state, run, jobs):
    matches = (len(jobs) == 1 and jobs[0]['runner_id'] == state['runner_id']
               and jobs[0]['runner_name'] == state['name'])
    state['job_identity_verified'] = matches
    if matches:
        state['job_id'] = jobs[0]['id']
    if run.get('conclusion') == 'cancelled':
        state['result'] = 'cancelled'
        transition(state, 'cancelled')
        raise RuntimeError('proving_job_cancelled')
    if run.get('conclusion') != 'success' or not matches or jobs[0]['conclusion'] != 'success':
        raise RuntimeError('job_result_not_bound_to_vm')
    state['result'] = 'success'
    transition(state, 'succeeded')


def supervisor_command(arguments):
    script = str(Path(__file__).resolve())
    deadline = 4800 if '--profile' in arguments and arguments[arguments.index('--profile') + 1] == 'application' else 1200
    return ['systemd-run', '--user', '--unit=newyou-w93-controller', '--collect', '--wait',
            f'--property=RuntimeMaxSec={deadline}', '--property=TimeoutStopSec=60',
            '--property=KillMode=mixed',
            '--property=ExecStopPost=/usr/bin/python3 ' + script + ' recover',
            '/usr/bin/python3', script, *arguments]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['supervise', 'probe', 'prove', 'recover'])
    parser.add_argument('--run-id', type=int)
    parser.add_argument('--sha')
    parser.add_argument('--memory', type=int)
    parser.add_argument('--profile', choices=['proof', 'application'], default='proof')
    args = parser.parse_args()
    policy = execution_policy(args.profile)
    args.memory = policy['memory'] if args.memory is None else args.memory
    if args.profile == 'application' and (not args.run_id or args.memory != 4096):
        parser.error('application trials require --run-id and 4096 MiB')
    if args.action == 'supervise':
        forwarded = ['prove', '--run-id', str(args.run_id), '--sha', args.sha] if args.run_id else ['probe']
        if args.run_id and not args.sha:
            parser.error('--run-id requires --sha')
        forwarded += ['--memory', str(args.memory), '--profile', args.profile]
        result = subprocess.run(supervisor_command(forwarded))
        sys.exit(result.returncode)
    if args.action in ['probe', 'prove'] and not os.environ.get('INVOCATION_ID'):
        raise RuntimeError('use_supervise_for_independent_deadline_and_cleanup')
    os.umask(0o077)
    ROOT.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (ROOT / 'controller.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('controller_already_running')
        pending = [json.loads(p.read_text()) for p in ROOT.glob('newyou-w93-*.json')]
        for state in pending:
            if state['phase'] != 'cleaned':
                cleanup(state)
        if args.action == 'recover':
            print('Owned resources reconciled. No new guest registered.')
            return
        if args.action == 'prove' and (not args.run_id or not re.fullmatch(r'[a-f0-9]{40}', args.sha or '')):
            parser.error('prove requires --run-id and --sha')
        capacity = preflight(args.memory)
        identity = uuid.uuid4()
        state = {'name': 'newyou-w93-' + identity.hex[:12], 'uuid': str(identity),
                 'mac': '52:54:00:' + ':'.join(f'{n:02x}' for n in identity.bytes[:3]),
                 'phase': 'provisioning', 'created_at': int(time.time()), 'capacity': capacity, 'profile': args.profile}
        save(state)
        def interrupted(signum, frame):
            raise KeyboardInterrupt()
        signal.signal(signal.SIGTERM, interrupted)
        try:
            provision(state, args.memory)
            isolate(state)
            if args.action == 'prove':
                execute(state, args.run_id, args.sha)
            else:
                state['result'] = 'isolation_only'
                save(state)
        except KeyboardInterrupt:
            transition(state, 'cancelled')
            raise
        except Exception:
            if can_transition(state['phase'], 'failed'):
                transition(state, 'failed')
            raise
        finally:
            cleanup(state)
        print(json.dumps(state, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired) as exc:
        print(str(exc) if isinstance(exc, RuntimeError) else 'command_timeout', file=sys.stderr)
        sys.exit(1)
