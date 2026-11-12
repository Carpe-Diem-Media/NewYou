import copy
import json
import unittest
from pathlib import Path

from tools import check_email_change_message_evidence as evidence


ROOT = Path(__file__).resolve().parents[1]


class EmailChangeEvidenceTest(unittest.TestCase):
    def test_owner_approved_versions_validate_as_development_eligible(self):
        self.assertEqual([], evidence.validate(ROOT))

    def test_any_byte_change_fails_closed(self):
        packet = json.loads((ROOT / evidence.PACKET_PATH).read_text())
        changed = copy.deepcopy(packet)
        changed['messages'][0]['sha256'] = '0' * 64
        self.assertTrue(evidence.validate_packet(ROOT, changed))

    def test_support_contact_remains_unbound_and_blocks_delivery(self):
        packet = json.loads((ROOT / evidence.PACKET_PATH).read_text())
        packet['delivery_authorized'] = True
        self.assertTrue(evidence.validate_packet(ROOT, packet))

    def test_role_evidence_must_bind_the_exact_locale_digest(self):
        packet = json.loads((ROOT / evidence.PACKET_PATH).read_text())
        packet['messages'][0]['role_evidence']['content_media_owner']['binding']['sha256'] = '0' * 64
        self.assertTrue(evidence.validate_packet(ROOT, packet))

    def test_coordinated_path_and_token_type_substitution_fail_closed(self):
        packet = json.loads((ROOT / evidence.PACKET_PATH).read_text())
        changed_path = copy.deepcopy(packet)
        changed_path['messages'][0]['path'] = 'docs/delivery/content-evidence/other.txt'
        self.assertTrue(evidence.validate_packet(ROOT, changed_path))

        changed_token = copy.deepcopy(packet)
        changed_token['messages'][0]['tokens'][1]['type'] = 'generic_url'
        changed_token['messages'][0]['token_contract_sha256'] = evidence.sha256(
            json.dumps(
                changed_token['messages'][0]['tokens'],
                sort_keys=True,
                separators=(',', ':'),
                ensure_ascii=False,
            ).encode()
        )
        self.assertTrue(evidence.validate_packet(ROOT, changed_token))

    def test_product_content_and_each_language_role_are_bound_to_exact_versions(self):
        packet = json.loads((ROOT / evidence.PACKET_PATH).read_text())
        for message in packet['messages']:
            roles = message['role_evidence']
            self.assertEqual(
                {'product_owner', 'content_media_owner', f"{message['locale']}_language_reviewer"},
                set(roles),
            )
            for role in roles.values():
                binding = role['binding']
                self.assertEqual(message['locale'], binding['locale'])
                self.assertEqual(message['translation_version_id'], binding['translation_version_id'])
                self.assertEqual(message['sha256'], binding['sha256'])
                self.assertEqual(message['token_contract_sha256'], binding['token_contract_sha256'])
            language_role = roles[f"{message['locale']}_language_reviewer"]
            expected_records = (
                [evidence.PRODUCT_RECORD, evidence.AF_BODY_RECORD]
                if message['locale'] == 'af'
                else [evidence.PRODUCT_RECORD]
            )
            self.assertEqual(expected_records, language_role['recording_comment_ids'])

        forged = copy.deepcopy(packet)
        forged['messages'][1]['role_evidence']['af_language_reviewer']['recording_comment_ids'] = [evidence.PRODUCT_RECORD]
        self.assertTrue(evidence.validate_packet(ROOT, forged))

    def test_withdrawn_or_superseded_versions_are_terminal_for_new_use(self):
        packet = json.loads((ROOT / evidence.PACKET_PATH).read_text())
        packet['messages'][0]['state'] = 'withdrawn'
        self.assertTrue(evidence.validate_packet(ROOT, packet))


if __name__ == '__main__':
    unittest.main()
