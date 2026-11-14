"""Offline verifier primitives, not a privileged collector or authorization gate.

Inputs are transient trusted-host observations. No raw rules/topology are logged.
This deliberately supports only explicit nft predicates. Opaque xt compatibility
matches, including physdev, require a separately reviewed native-save adapter.
A consistent trace is not certification of all hooks or effective isolation.
"""
import copy
import hashlib
import ipaddress
import json
import re
import shlex
import uuid
import xml.etree.ElementTree as ET


class ProofError(ValueError):
    def __init__(self):
        super().__init__('firewall_evidence_unverified')


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def binding(domain_xml, expected):
    """Bind the sole interface to an exact journal UUID/name without exporting it."""
    try:
        domain = ET.fromstring(domain_xml)
        identity = str(uuid.UUID(expected['uuid']))
        name = 'newyou-w93-' + uuid.UUID(identity).hex[:12]
        if (expected['name'] != name or domain.tag != 'domain' or domain.get('type') != 'kvm'
                or domain.findtext('name') != name or domain.findtext('uuid') != identity
                or any(domain.findall('.//' + tag) for tag in ('filesystem', 'hostdev', 'channel'))):
            raise ProofError()
        interfaces = domain.findall('./devices/interface')
        if len(interfaces) != 1:
            raise ProofError()
        interface = interfaces[0]
        tap = interface.find('target').get('dev')
        reference = interface.find('filterref')
        if (interface.get('type') != 'network' or not re.fullmatch(r'vnet[0-9]{1,8}', tap)
                or interface.find('source').attrib != {'network': 'ci-nat'}
                or interface.find('mac').attrib != {'address': expected['mac']}
                or not re.fullmatch(r'52:54:00:(?:[0-9a-f]{2}:){2}[0-9a-f]{2}', expected['mac'])
                or reference.attrib != {'filter': name}
                or [x.attrib for x in reference] != [{'name': 'IP', 'value': '10.77.77.150'}]):
            raise ProofError()
        # Interface data is returned only to the transient evaluator. Persist
        # only digest, never the XML, interface or host topology.
        return {'interface': tap, 'digest': digest([identity, ET.tostring(interface, encoding='unicode')])}
    except Exception:
        raise ProofError() from None


def _integer(value):
    if type(value) is not int or not 0 <= value < 2 ** 64:
        raise ProofError()
    return value


def _predicate(expression, packet):
    if not isinstance(expression, dict) or set(expression) != {'match'}:
        raise ProofError()
    match = expression['match']
    if not isinstance(match, dict) or set(match) != {'op', 'left', 'right'} or match['op'] not in {'==', '!='}:
        raise ProofError()
    left, right = match['left'], match['right']
    if left in ({'meta': {'key': 'iifname'}}, {'meta': {'key': 'oifname'}}, {'meta': {'key': 'l4proto'}}, {'meta': {'key': 'bridged'}}):
        key = left['meta']['key']
    elif left in ({'physdev': {'key': 'in'}}, {'physdev': {'key': 'out'}}):
        # Native-save normalized predicates. These are bridge-port facts,
        # never aliases for the packet's logical iifname/oifname.
        key = 'physdev.' + left['physdev']['key']
    elif isinstance(left, dict) and set(left) == {'payload'}:
        payload = left['payload']
        if not isinstance(payload, dict) or set(payload) != {'protocol', 'field'}:
            raise ProofError()
        key = payload['protocol'] + '.' + payload['field']
        if key not in {'ip.saddr', 'ip.daddr', 'tcp.sport', 'tcp.dport', 'ether.type'}:
            raise ProofError()
    else:
        raise ProofError()
    if key not in packet:
        raise ProofError()
    actual = packet[key]
    if isinstance(right, dict) and set(right) == {'prefix'} and key in {'ip.saddr', 'ip.daddr'}:
        prefix = right['prefix']
        if not isinstance(prefix, dict) or set(prefix) != {'addr', 'len'} or type(prefix['len']) is not int:
            raise ProofError()
        network = ipaddress.IPv4Network((prefix['addr'], prefix['len']), strict=True)
        result = ipaddress.IPv4Address(actual) in network
    elif type(right) in (str, int, bool) and type(actual) is type(right):
        result = actual == right
    else:
        raise ProofError()
    return result if match['op'] == '==' else not result


def trace(ruleset, entry, packet, owned_chains):
    """Trace one packet through an explicit supported graph, preserving order.

    A DROP is attributable only when its own rule has an explicit counter and
    lives in the caller's independently bound owned-chain set. No chain-name
    substring or generic counter presence establishes ownership.
    """
    try:
        items = ruleset['nftables']
        if not isinstance(items, list) or len(items) > 20000:
            raise ProofError()
        chains, rules, handles = {}, {}, set()
        for item in items:
            if not isinstance(item, dict):
                raise ProofError()
            if 'chain' in item:
                chain = item['chain']
                key = (chain['family'], chain['table'], chain['name'])
                if key in chains:
                    raise ProofError()
                chains[key], rules[key] = chain, []
        for item in items:
            if 'rule' not in item:
                continue
            rule = item['rule']
            key = (rule['family'], rule['table'], rule['chain'])
            handle = _integer(rule['handle'])
            identity = (*key, handle)
            if key not in chains or identity in handles:
                raise ProofError()
            handles.add(identity)
            rules[key].append(rule)
        visited = set()
        def walk(key, depth=0):
            if key not in chains or key in visited or depth > 16:
                raise ProofError()
            visited.add(key)
            try:
                for rule in rules[key]:
                    expressions = rule['expr']
                    if not isinstance(expressions, list) or not 1 <= len(expressions) <= 32:
                        raise ProofError()
                    matches, counter, verdict = [], None, None
                    for index, expression in enumerate(expressions):
                        if not isinstance(expression, dict) or len(expression) != 1 or verdict is not None:
                            raise ProofError()
                        kind = next(iter(expression))
                        if kind == 'match':
                            if counter is not None:
                                raise ProofError()
                            # Parse all predicates even if an earlier one did
                            # not match; an opaque operation is never ignored.
                            matches.append(_predicate(expression, packet))
                        elif kind == 'counter':
                            value = expression[kind]
                            if counter is not None or set(value) != {'packets', 'bytes'}:
                                raise ProofError()
                            counter = (*key, rule['handle'], _integer(value['packets']), _integer(value['bytes']))
                        elif kind in {'drop', 'accept', 'return'} and expression[kind] is None:
                            verdict = kind
                        elif kind in {'jump', 'goto'} and isinstance(expression[kind], dict) and set(expression[kind]) == {'target'}:
                            verdict = (kind, expression[kind]['target'])
                        else:
                            raise ProofError()
                    if not all(matches):
                        continue
                    if isinstance(verdict, tuple):
                        result = walk((key[0], key[1], verdict[1]), depth + 1)
                        if result['verdict'] != 'return':
                            return result
                        if verdict[0] == 'goto':
                            return {'verdict': chains[key].get('policy', 'return'), 'counter': None}
                    elif verdict:
                        return {'verdict': verdict, 'counter': counter if verdict == 'drop' and key in owned_chains else None}
                policy = chains[key].get('policy', 'return')
                if policy not in {'accept', 'drop', 'return'}:
                    raise ProofError()
                return {'verdict': policy, 'counter': None}
            finally:
                visited.remove(key)
        return walk(entry)
    except Exception:
        raise ProofError() from None


def observation(ruleset, entry, packet, owned_chains, binding_digest, at):
    """Project one transient trace to bounded, opaque comparison evidence."""
    result = trace(ruleset, entry, packet, owned_chains)
    if result['verdict'] != 'drop' or result['counter'] is None:
        raise ProofError()
    graph = copy.deepcopy(ruleset)
    for item in graph['nftables']:
        for expression in item.get('rule', {}).get('expr', []):
            if 'counter' in expression:
                expression['counter'] = {'packets': 0, 'bytes': 0}
    identity = result['counter'][:4]
    return {'binding': binding_digest, 'graph': digest(graph), 'rule': digest(identity),
            'probe': digest([entry, packet, sorted(owned_chains)]), 'at': at,
            'packets': result['counter'][4], 'bytes': result['counter'][5]}


def reconcile(before, after, expected_packets, now):
    """Strict correlation, never standalone isolation certification.

    Exact increments reject obvious background traffic. They cannot distinguish
    a controlled packet from concurrent traffic with the same counter outcome.
    A future collector must establish probe exclusivity and verify every hook.
    """
    try:
        fields = {'binding', 'graph', 'rule', 'probe', 'at', 'packets', 'bytes'}
        if set(before) != fields or set(after) != fields:
            raise ProofError()
        for value in (before, after):
            for key in ('binding', 'graph', 'rule', 'probe'):
                if not isinstance(value[key], str) or not re.fullmatch('[a-f0-9]{64}', value[key]):
                    raise ProofError()
            for key in ('at', 'packets', 'bytes'):
                _integer(value[key])
        if any(before[key] != after[key] for key in ('binding', 'graph', 'rule', 'probe')):
            raise ProofError()
        _integer(now)
        if type(expected_packets) is not int or not 1 <= expected_packets <= 128:
            raise ProofError()
        if not before['at'] < after['at'] <= now or now - before['at'] > 120:
            raise ProofError()
        delta = after['packets'] - before['packets']
        if delta != expected_packets or after['bytes'] <= before['bytes']:
            raise ProofError()
        return {'status': 'candidate_consistent', 'enforcement': 'unverified', 'packet_delta': delta}
    except Exception:
        raise ProofError() from None


def native_save(raw, family, table):
    """Parse a narrow native-save grammar without interpreting opaque xt JSON.

    This is an offline adapter, not a root command. Only the trusted collector
    may supply effective save output. Unsupported match modules and targets
    stop evaluation. Correspondence to kernel hooks is a separate obligation.
    """
    try:
        if (family, table) not in {('ip', 'filter'), ('bridge', 'nat')} or len(raw) > 8 * 1024 * 1024:
            raise ProofError()
        items, active, complete, handle = [], False, False, 0
        def match(left, right):
            return {'match': {'op': '==', 'left': left, 'right': right}}
        for line in raw.splitlines():
            if not line or line.startswith('#'):
                continue
            if line == '*' + table and not active and not complete:
                active = True
                continue
            if line == 'COMMIT' and active:
                active, complete = False, True
                continue
            if not active:
                raise ProofError()
            if line.startswith(':'):
                declaration = re.fullmatch(r':([A-Za-z0-9_.-]+) (ACCEPT|DROP|-) \[([0-9]+):([0-9]+)\]', line)
                if not declaration:
                    raise ProofError()
                name, policy = declaration.group(1, 2)
                chain = {'family': family, 'table': table, 'name': name}
                if policy != '-':
                    chain['policy'] = policy.lower()
                items.append({'chain': chain})
                continue
            count = re.match(r'^\[([0-9]+):([0-9]+)\] ', line)
            if not count:
                raise ProofError()
            tokens = shlex.split(line[count.end():])
            if len(tokens) < 4 or tokens[0] != '-A':
                raise ProofError()
            name, expressions, index = tokens[1], [], 2
            modules = {tokens[n + 1] for n in range(len(tokens) - 1) if tokens[n] == '-m'}
            if any(x.startswith('--physdev-') for x in tokens) and 'physdev' not in modules:
                raise ProofError()
            terminal = None
            while index < len(tokens):
                option = tokens[index]
                index += 1
                if option == '--physdev-is-bridged':
                    expressions.append(match({'meta': {'key': 'bridged'}}, True))
                    continue
                if index >= len(tokens):
                    raise ProofError()
                value = tokens[index]
                index += 1
                if option == '-m':
                    if value not in {'physdev', 'tcp', 'udp'}:
                        raise ProofError()
                elif option in {'--physdev-in', '--physdev-out', '-i', '-o'}:
                    if not re.fullmatch(r'[A-Za-z0-9_.:-]{1,15}', value):
                        raise ProofError()
                    if option.startswith('--physdev-'):
                        left = {'physdev': {'key': 'in' if option == '--physdev-in' else 'out'}}
                    else:
                        left = {'meta': {'key': 'iifname' if option == '-i' else 'oifname'}}
                    expressions.append(match(left, value))
                elif option in {'-s', '-d'} and family == 'ip':
                    network = ipaddress.IPv4Network(value, strict=False)
                    expressions.append(match({'payload': {'protocol': 'ip', 'field': 'saddr' if option == '-s' else 'daddr'}},
                        {'prefix': {'addr': str(network.network_address), 'len': network.prefixlen}}))
                elif option == '-p' and value in {'tcp', 'udp'}:
                    expressions.append(match({'meta': {'key': 'l4proto'}}, value))
                elif option in {'--sport', '--dport'} and value.isdecimal() and 1 <= int(value) <= 65535:
                    # Port interpretation requires an explicit TCP predicate.
                    if match({'meta': {'key': 'l4proto'}}, 'tcp') not in expressions:
                        raise ProofError()
                    expressions.append(match({'payload': {'protocol': 'tcp', 'field': option[2:]}}, int(value)))
                elif option in {'-j', '-g'} and index == len(tokens):
                    if value in {'DROP', 'ACCEPT', 'RETURN'} and option == '-j':
                        terminal = {value.lower(): None}
                    elif re.fullmatch(r'[A-Za-z0-9_.-]+', value) and value not in {'DROP', 'ACCEPT', 'RETURN', 'REJECT', 'QUEUE', 'NFQUEUE', 'LOG'}:
                        terminal = {'jump' if option == '-j' else 'goto': {'target': value}}
                    else:
                        raise ProofError()
                else:
                    raise ProofError()
            if terminal is None:
                raise ProofError()
            expressions += [{'counter': {'packets': _integer(int(count[1])), 'bytes': _integer(int(count[2]))}}, terminal]
            handle += 1
            items.append({'rule': {'family': family, 'table': table, 'chain': name,
                                   'handle': handle, 'expr': expressions}})
        if active or not complete:
            raise ProofError()
        return {'nftables': items}
    except Exception:
        raise ProofError() from None
