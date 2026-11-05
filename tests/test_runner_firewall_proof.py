"""Offline packet-path regressions. Fixtures are synthetic, never host attestation."""
import copy
import unittest
from tools import runner_firewall_proof as proof


def fixture():
    def rule(handle, expr):
        return {'rule': {'family': 'ip', 'table': 'filter', 'chain': 'FI-vnet7',
                         'handle': handle, 'expr': expr}}
    counter = {'counter': {'packets': 10, 'bytes': 600}}
    return {'nftables': [
        {'chain': {'family': 'ip', 'table': 'filter', 'name': 'FORWARD',
                   'type': 'filter', 'hook': 'forward', 'prio': 0, 'policy': 'accept'}},
        {'chain': {'family': 'ip', 'table': 'filter', 'name': 'FI-vnet7'}},
        {'rule': {'family': 'ip', 'table': 'filter', 'chain': 'FORWARD', 'handle': 1,
                  'expr': [{'match': {'op': '==', 'left': {'meta': {'key': 'iifname'}}, 'right': 'vnet7'}},
                           {'jump': {'target': 'FI-vnet7'}}]}},
        rule(2, [{'match': {'op': '==', 'left': {'payload': {'protocol': 'ip', 'field': 'daddr'}},
                           'right': {'prefix': {'addr': '10.0.0.0', 'len': 8}}}}, counter, {'drop': None}]),
        rule(3, [{'accept': None}])
    ]}


class FirewallProofTest(unittest.TestCase):
    packet = {'iifname': 'vnet7', 'ip.daddr': '10.1.2.3'}

    def test_drop_is_bound_to_traversed_owned_chain_and_counter(self):
        result = proof.trace(fixture(), ('ip', 'filter', 'FORWARD'), self.packet,
                             {('ip', 'filter', 'FI-vnet7')})
        self.assertEqual(result['verdict'], 'drop')
        self.assertEqual(result['counter'], ('ip', 'filter', 'FI-vnet7', 2, 10, 600))

    def test_accept_before_deny_is_not_isolation(self):
        data = fixture()
        data['nftables'].insert(2, {'rule': {'family': 'ip', 'table': 'filter', 'chain': 'FORWARD',
            'handle': 9, 'expr': [{'accept': None}]}})
        self.assertEqual(proof.trace(data, ('ip', 'filter', 'FORWARD'), self.packet,
                                    {('ip', 'filter', 'FI-vnet7')})['verdict'], 'accept')

    def test_unrelated_interface_and_unowned_drop_do_not_certify(self):
        self.assertEqual(proof.trace(fixture(), ('ip', 'filter', 'FORWARD'),
            {'iifname': 'vnet8', 'ip.daddr': '10.1.2.3'}, {('ip', 'filter', 'FI-vnet7')})['verdict'], 'accept')
        self.assertIsNone(proof.trace(fixture(), ('ip', 'filter', 'FORWARD'),
                                     self.packet, {('ip', 'filter', 'FI-vnet8')})['counter'])

    def test_unknown_and_opaque_matches_fail_closed_even_before_known_mismatch(self):
        for expression in [{'xt': {'type': 'match', 'name': 'physdev'}},
                           {'match': {'op': '==', 'left': {'unknown': {}}, 'right': 1}}]:
            data = fixture()
            data['nftables'][2]['rule']['expr'].insert(0, expression)
            with self.assertRaises(proof.ProofError):
                proof.trace(data, ('ip', 'filter', 'FORWARD'), self.packet, {('ip', 'filter', 'FI-vnet7')})

    def test_missing_counter_duplicate_handle_and_cycle_fail_closed(self):
        for mutation in ['counter', 'handle', 'cycle']:
            data = fixture()
            if mutation == 'counter':
                del data['nftables'][3]['rule']['expr'][1]
                self.assertIsNone(proof.trace(data, ('ip', 'filter', 'FORWARD'), self.packet,
                                             {('ip', 'filter', 'FI-vnet7')})['counter'])
                continue
            if mutation == 'handle':
                data['nftables'][4]['rule']['handle'] = 2
            if mutation == 'cycle':
                data['nftables'][3]['rule']['expr'] = [{'jump': {'target': 'FORWARD'}}]
            with self.assertRaises(proof.ProofError):
                proof.trace(data, ('ip', 'filter', 'FORWARD'), self.packet, {('ip', 'filter', 'FI-vnet7')})

    def test_pair_rejects_stale_changed_reset_and_unattributable_counters(self):
        before = proof.observation(fixture(), ('ip', 'filter', 'FORWARD'), self.packet,
                                   {('ip', 'filter', 'FI-vnet7')}, 'a' * 64, 100)
        data = fixture()
        data['nftables'][3]['rule']['expr'][1]['counter'] = {'packets': 11, 'bytes': 660}
        after = proof.observation(data, ('ip', 'filter', 'FORWARD'), self.packet,
                                  {('ip', 'filter', 'FI-vnet7')}, 'a' * 64, 102)
        self.assertEqual(proof.reconcile(before, after, 1, 103)['status'], 'candidate_consistent')
        for field, value in [('at', 80), ('binding', 'b' * 64), ('graph', 'b' * 64),
                             ('packets', 9), ('packets', 12), ('bytes', 590)]:
            changed = copy.deepcopy(after)
            changed[field] = value
            with self.assertRaises(proof.ProofError):
                proof.reconcile(before, changed, 1, 103)
        with self.assertRaises(proof.ProofError):
            proof.reconcile(before, after, 1, 500)

    def test_binding_rejects_wrong_uuid_interface_network_filter_and_attachments(self):
        domain = '''<domain type="kvm"><name>newyou-w93-123456781234</name>
        <uuid>12345678-1234-4234-8234-123456789abc</uuid><devices>
        <interface type="network"><mac address="52:54:00:12:34:56"/><source network="ci-nat"/><target dev="vnet7"/>
        <filterref filter="newyou-w93-123456781234"><parameter name="IP" value="10.77.77.150"/></filterref>
        </interface></devices></domain>'''
        expected = {'name': 'newyou-w93-123456781234', 'uuid': '12345678-1234-4234-8234-123456789abc', 'mac': '52:54:00:12:34:56'}
        self.assertRegex(proof.binding(domain, expected)['digest'], '^[a-f0-9]{64}$')
        for old, new in [('vnet7', 'eth0'), ('ci-nat', 'default'), ('type="kvm"', 'type="qemu"'),
                         ('<devices>', '<devices><filesystem/>'), ('value="10.77.77.150"', 'value="10.0.0.1"')]:
            with self.assertRaises(proof.ProofError):
                proof.binding(domain.replace(old, new), expected)
        with self.assertRaises(proof.ProofError):
            proof.binding(domain, dict(expected, uuid='00000000-0000-4000-8000-000000000000'))

    def test_report_contains_no_raw_topology_and_never_authorizes_registration(self):
        before = proof.observation(fixture(), ('ip', 'filter', 'FORWARD'), self.packet,
                                   {('ip', 'filter', 'FI-vnet7')}, 'a' * 64, 100)
        after = dict(before, at=102, packets=11, bytes=660)
        report = proof.reconcile(before, after, 1, 103)
        self.assertEqual(set(report), {'status', 'enforcement', 'packet_delta'})
        self.assertEqual(report['enforcement'], 'unverified')

    def test_counter_before_predicate_and_wrong_table_ownership_are_rejected(self):
        data = fixture()
        expressions = data['nftables'][3]['rule']['expr']
        expressions[0], expressions[1] = expressions[1], expressions[0]
        with self.assertRaises(proof.ProofError):
            proof.trace(data, ('ip', 'filter', 'FORWARD'), self.packet,
                        {('ip', 'filter', 'FI-vnet7')})
        self.assertIsNone(proof.trace(fixture(), ('ip', 'filter', 'FORWARD'), self.packet,
                                     {('bridge', 'nat', 'FI-vnet7')})['counter'])

    def test_native_physdev_adapter_requires_interface_and_bridged_predicate(self):
        data = proof.native_save("""*filter
:FORWARD ACCEPT [0:0]
:FI-vnet7 - [0:0]
[1:60] -A FORWARD -m physdev --physdev-in vnet7 -g FI-vnet7
[1:60] -A FI-vnet7 -d 10.0.0.0/8 -j DROP
COMMIT
""", 'ip', 'filter')
        # goto is supported only by the native-save adapter, with its actual
        # return-to-caller semantics, not silently rewritten as jump.
        with self.assertRaises(proof.ProofError):
            proof.trace(data, ('ip', 'filter', 'FORWARD'), self.packet,
                        {('ip', 'filter', 'FI-vnet7')})
        self.assertEqual(proof.trace(data, ('ip', 'filter', 'FORWARD'),
                                    dict(self.packet, **{'physdev.in': 'vnet7'}),
                                    {('ip', 'filter', 'FI-vnet7')})['verdict'], 'drop')
        for rule in ['-m physdev --physdev-in vnet+ -j DROP',
                     '-m unknown --whatever value -j DROP', '-j REJECT',
                     '-m physdev --physdev-is-bridged -j DROP',
                     '--physdev-in vnet7 -j DROP']:
            with self.assertRaises(proof.ProofError):
                data = proof.native_save('*filter\n:FORWARD ACCEPT [0:0]\n[0:0] -A FORWARD ' + rule + '\nCOMMIT\n', 'ip', 'filter')
                proof.trace(data, ('ip', 'filter', 'FORWARD'), self.packet, set())
