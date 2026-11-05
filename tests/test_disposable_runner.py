"""Security boundaries for the local, proving-only VM controller."""
import unittest
from tools import disposable_runner as runner


class SafetyTest(unittest.TestCase):
    def test_capacity_reserves_host_memory_and_rejects_swap_pressure(self):
        self.assertEqual(runner.capacity_error(11000, 2500, 2048, 90000), None)
        self.assertIsNotNone(runner.capacity_error(5000, 2500, 2048, 90000))
        self.assertIsNotNone(runner.capacity_error(11000, 500, 2048, 90000))
        self.assertIsNotNone(runner.capacity_error(11000, 2500, 2048, 1000))

    def test_filter_blocks_private_ipv4_ipv6_and_unsolicited_inbound(self):
        xml = runner.network_filter('newyou-w93-test', ['192.168.68.54', '8.8.4.4'])
        import xml.etree.ElementTree as ET
        root = ET.fromstring(xml)
        self.assertTrue(root.findall("./rule[@action='drop']/all[@dstipaddr='10.0.0.0']"))
        self.assertTrue(root.findall("./rule[@action='drop']/all[@dstipaddr='8.8.4.4']"))
        self.assertTrue(root.findall("./rule[@action='drop']/ipv6"))
        self.assertEqual(root.findall('rule')[-1].attrib['action'], 'drop')
        self.assertFalse(root.findall("./rule[@action='accept']/all"))

    def test_cleanup_retries_all_resources_and_never_marks_failed_cleanup_complete(self):
        attempted = []
        def remove(kind):
            attempted.append(kind)
            if kind == 'registration':
                raise RuntimeError('unavailable')
        self.assertEqual(runner.cleanup_steps(remove), ['registration'])
        self.assertEqual(attempted, ['domain', 'registration', 'volumes', 'filter', 'keys'])

    def test_state_machine_cannot_register_before_isolation_or_reuse_terminal_guest(self):
        self.assertTrue(runner.can_transition('isolated', 'registered'))
        self.assertFalse(runner.can_transition('provisioning', 'registered'))
        self.assertFalse(runner.can_transition('cleaned', 'registered'))
        for state in ['provisioning', 'isolated', 'registered', 'executing', 'failed', 'cancelled']:
            self.assertTrue(runner.can_transition(state, 'teardown'))

class SupervisionTest(unittest.TestCase):
    def test_supervisor_has_independent_cleanup_and_deadline(self):
        args = runner.supervisor_command(['probe'])
        self.assertIn('--property=RuntimeMaxSec=1200', args)
        self.assertTrue(any(a.startswith('--property=ExecStopPost=') and a.endswith(' recover') for a in args))
        self.assertIn('--property=KillMode=mixed', args)

    def test_capacity_rejects_active_memory_pressure(self):
        self.assertIsNotNone(runner.capacity_error(11000, 2500, 2048, 90000, full_pressure=2.0))
        self.assertIsNone(runner.capacity_error(11000, 1500, 2048, 90000, full_pressure=0.0))

class RoutedNetworkTest(unittest.TestCase):
    def test_filter_denies_publicly_numbered_local_routes(self):
        import xml.etree.ElementTree as ET
        root = ET.fromstring(runner.network_filter('test', [], ['11.2.0.0/16']))
        deny = root.find("./rule[@action='drop']/all[@dstipaddr='11.2.0.0']")
        self.assertIsNotNone(deny)
        self.assertEqual(deny.attrib['dstipmask'], '16')

class EthernetLayerTest(unittest.TestCase):
    def test_ipv4_reaches_ip_filter_before_ethernet_default_drop(self):
        import xml.etree.ElementTree as ET
        root = ET.fromstring(runner.network_filter('test', []))
        self.assertIsNotNone(root.find("./rule[@action='accept']/mac[@protocolid='ipv4']"))
        self.assertIsNotNone(root.find("./rule[@action='drop']/all"))

class LibvirtSchemaTest(unittest.TestCase):
    def test_dense_host_routes_never_overflow_libvirt_rule_priority(self):
        import xml.etree.ElementTree as ET
        routes = [f'11.1.{i}.0/24' for i in range(200)]
        root = ET.fromstring(runner.network_filter('test', [], routes))
        for rule in root.findall('rule'):
            self.assertLessEqual(int(rule.attrib['priority']), 1000)
        self.assertIsNotNone(root.find("./rule/arp[@arpdstipaddr='10.77.77.1']"))
        self.assertIsNotNone(root.find("./rule/arp[@arpsrcipaddr='10.77.77.1']"))

class CleanupIntegrationTest(unittest.TestCase):
    def test_owned_volumes_are_deleted_and_repeated_cleanup_is_safe(self):
        from pathlib import Path
        from tempfile import TemporaryDirectory
        from types import SimpleNamespace
        from unittest.mock import patch
        name = 'newyou-w93-123456789abc'
        volumes = {name + '-disk.qcow2', name + '-seed.iso', 'unrelated.qcow2'}
        def virsh(*args):
            if args == ('list', '--all', '--name'):
                return SimpleNamespace(stdout='')
            if args == ('vol-list', runner.POOL):
                return SimpleNamespace(stdout='Name Path\n--------\n' + '\n'.join(v + ' /pool/' + v for v in volumes))
            if args[0] == 'vol-delete':
                volumes.remove(args[-1])
                return SimpleNamespace(stdout='')
            if args == ('nwfilter-list',):
                return SimpleNamespace(stdout='')
            raise AssertionError('Unsupported virsh call: ' + repr(args))
        with TemporaryDirectory() as directory:
            state = {'name': name, 'uuid': 'test', 'phase': 'failed'}
            with patch.object(runner, 'ROOT', Path(directory)), patch.object(runner, 'virsh', virsh), patch.object(runner, 'github', return_value={'runners': []}):
                runner.cleanup(state)
                runner.cleanup(state)
                self.assertEqual(state['phase'], 'cleaned')
                self.assertEqual(volumes, {'unrelated.qcow2'})
                state['phase'] = 'teardown'
                runner.cleanup(state)
                self.assertEqual(state['phase'], 'cleaned')

class CancellationTest(unittest.TestCase):
    def test_unsuccessful_owned_run_is_cancelled_before_teardown(self):
        calls = []
        def github(path, method='GET', body=None):
            calls.append((path, method))
            return {'status': 'completed' if len(calls) > 2 else 'in_progress'}
        from unittest.mock import patch
        with patch.object(runner, 'github', github):
            runner.cancel_owned_run({'run_id': 123, 'result': 'failed'})
        self.assertEqual(calls, [('actions/runs/123', 'GET'), ('actions/runs/123/cancel', 'POST'), ('actions/runs/123', 'GET')])
        with patch.object(runner, 'github', side_effect=AssertionError('must not cancel successful run')):
            runner.cancel_owned_run({'run_id': 123, 'result': 'success'})

    def test_silently_changed_libvirt_attributes_fail_closed(self):
        expected = runner.network_filter('test', [])
        altered = expected.replace('arpdstipaddr=', 'discarded_attribute=')
        with self.assertRaisesRegex(RuntimeError, 'libvirt_filter_changed_rules'):
            runner.verify_filter(expected, altered)

class FilterStructureTest(unittest.TestCase):
    """Full filter identity/includes must survive libvirt's XML round trip."""
    def setUp(self):
        import xml.etree.ElementTree as ET
        self.ET = ET
        self.expected = runner.network_filter('newyou-w93-test', [])

    def reject(self, mutate):
        root = self.ET.fromstring(self.expected)
        mutate(root)
        with self.assertRaisesRegex(RuntimeError, '^libvirt_filter_changed_rules$'):
            runner.verify_filter(self.expected, self.ET.tostring(root, encoding='unicode'))

    def test_each_spoofing_reference_is_required_exactly_once_and_unchanged(self):
        for index in range(3):
            for mutation in ('missing', 'duplicate', 'name', 'attribute', 'parameter'):
                with self.subTest(index=index, mutation=mutation):
                    def mutate(root):
                        reference = root.findall('filterref')[index]
                        if mutation == 'missing':
                            root.remove(reference)
                        elif mutation == 'duplicate':
                            import copy
                            root.insert(index, copy.deepcopy(reference))
                        elif mutation == 'name':
                            reference.set('filter', 'unexpected-filter')
                        elif mutation == 'attribute':
                            reference.set('unexpected', 'value')
                        else:
                            self.ET.SubElement(reference, 'parameter', name='IP', value='unexpected')
                    self.reject(mutate)

    def test_root_identity_attributes_and_all_child_order_are_checked(self):
        for field in ('name', 'chain', 'priority'):
            with self.subTest(field=field):
                self.reject(lambda root: root.set(field, 'unexpected'))
        self.reject(lambda root: setattr(root, 'tag', 'unexpected'))
        self.reject(lambda root: root.set('unexpected', 'value'))
        self.reject(self.swap_references)
        def move_reference(root):
            reference = root[0]
            root.remove(reference)
            root.append(reference)
        self.reject(move_reference)
        def swap_rules(root):
            index = list(root).index(root.find('rule'))
            left, right = root[index], root[index + 1]
            root[index], root[index + 1] = right, left
        self.reject(swap_rules)

    @staticmethod
    def swap_references(root):
        root[0], root[1] = root[1], root[0]

    def test_unexpected_semantic_elements_text_and_nested_attributes_are_rejected(self):
        self.reject(lambda root: self.ET.SubElement(root, 'filterref', filter='unexpected'))
        self.reject(lambda root: self.ET.SubElement(root, 'unexpected'))
        self.reject(lambda root: self.ET.SubElement(root.find('rule')[0], 'unexpected', value='secret'))
        self.reject(lambda root: setattr(root.find('filterref'), 'text', 'unexpected'))
        self.reject(lambda root: setattr(root.find('filterref'), 'tail', 'unexpected'))
        # Even equal outer parameter tags must not conceal changed descendants.
        expected = self.ET.fromstring(self.expected)
        parameter = self.ET.SubElement(expected[0], 'parameter', name='IP', value='fixed')
        self.ET.SubElement(parameter, 'nested', value='original')
        actual = self.ET.fromstring(self.ET.tostring(expected))
        actual[0][0][0].set('value', 'changed')
        with self.assertRaisesRegex(RuntimeError, 'libvirt_filter_changed_rules'):
            runner.verify_filter(self.ET.tostring(expected), self.ET.tostring(actual))

    def test_generated_uuid_and_xml_formatting_are_the_only_ignored_differences(self):
        # libvirt v12 virNWFilterDefParseXML generates absent UUIDs, and
        # virNWFilterDefFormat emits one first, before ordered filter entries.
        root = self.ET.fromstring(self.expected)
        identity = self.ET.Element('uuid')
        identity.text = '12345678-1234-4234-8234-123456789abc'
        root.insert(0, identity)
        for element in root.iter():
            element.attrib = dict(reversed(list(element.attrib.items())))
        self.ET.indent(root)
        runner.verify_filter(self.expected, self.ET.tostring(root, encoding='unicode'))
        runner.verify_filter(self.expected, self.expected)

    def test_uuid_exception_rejects_malformed_duplicate_nested_or_misplaced_metadata(self):
        for xml in ('<uuid>invalid</uuid>', '<uuid/>',
                    '<uuid extra="value">12345678-1234-4234-8234-123456789abc</uuid>',
                    '<uuid><nested/></uuid>',
                    '<uuid>12345678-1234-4234-8234-123456789abc</uuid>unexpected'):
            with self.subTest(xml=xml):
                # Parse a wrapper to preserve unexpected tail text.
                self.reject(lambda root: root.insert(0, self.ET.fromstring('<wrapper>' + xml + '</wrapper>')[0]))
        identity = '<uuid>12345678-1234-4234-8234-123456789abc</uuid>'
        self.reject(lambda root: (root.insert(0, self.ET.fromstring(identity)), root.insert(0, self.ET.fromstring(identity))))
        self.reject(lambda root: root.append(self.ET.fromstring(identity)))
        self.reject(lambda root: root[0].append(self.ET.fromstring(identity)))

    def test_explicit_expected_uuid_is_not_ignored_and_parse_errors_are_sanitized(self):
        expected = self.expected.replace('><filterref', '><uuid>12345678-1234-4234-8234-123456789abc</uuid><filterref', 1)
        runner.verify_filter(expected, expected)
        with self.assertRaisesRegex(RuntimeError, '^libvirt_filter_changed_rules$'):
            runner.verify_filter(expected, expected.replace('<uuid>', '<uuid> '))
        actual = expected.replace('12345678-1234-4234-8234-123456789abc', 'aaaaaaaa-1234-4234-8234-123456789abc')
        with self.assertRaisesRegex(RuntimeError, '^libvirt_filter_changed_rules$'):
            runner.verify_filter(expected, actual)
        with self.assertRaisesRegex(RuntimeError, '^libvirt_filter_changed_rules$'):
            runner.verify_filter(self.expected, '<filter SECRET')


class RegistrationGuardTest(unittest.TestCase):
    def test_no_provider_call_before_isolation(self):
        from unittest.mock import patch
        with patch.object(runner, 'github', side_effect=AssertionError('provider must not be called')):
            with self.assertRaisesRegex(RuntimeError, 'isolation_not_proven'):
                runner.execute({'phase': 'provisioning'}, 1, 'a' * 40)


class OutputBoundaryTest(unittest.TestCase):
    def test_untrusted_runner_output_is_not_buffered_in_host_memory(self):
        from unittest.mock import patch
        from types import SimpleNamespace
        import subprocess
        with patch.object(runner.subprocess, 'run', return_value=SimpleNamespace(returncode=0)) as run:
            runner.command(['ssh', 'guest'], data='one-use-credential', discard_output=True)
            self.assertEqual(run.call_args.kwargs['stdout'], subprocess.DEVNULL)
            self.assertEqual(run.call_args.kwargs['stderr'], subprocess.DEVNULL)
            self.assertNotIn('one-use-credential', run.call_args.args[0])


if __name__ == '__main__':
    unittest.main()
