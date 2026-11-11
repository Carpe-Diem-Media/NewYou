import hashlib
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / 'docs/delivery/content-evidence/content_media/recovery_messages'


def sha(data):
    return hashlib.sha256(data).hexdigest()


class RecoveryEvidenceTest(unittest.TestCase):
    def test_approved_subjects_and_tokens_are_exact_and_scoped(self):
        packet = json.loads((DIR / 'RECOVERY_MESSAGE_DEVELOPMENT_EVIDENCE_PACKET_v0.2.0.json').read_text())
        candidate = DIR / 'RECOVERY_MESSAGE_CANDIDATE_EVIDENCE_PACKET_v0.1.0.json'
        approvals = DIR / 'OWNER_APPROVALS_v1.json'
        self.assertEqual(packet['candidate_predecessor']['sha256'], sha(candidate.read_bytes()))
        self.assertEqual(packet['approval_source']['sha256'], sha(approvals.read_bytes()))
        events = packet['approval_events']
        self.assertEqual(len(events), 9)
        self.assertEqual(len({event['comment_id'] for event in events}), 9)
        self.assertTrue(all(event['decision'] == 'approve' for event in events))
        event_ids = {event['comment_id'] for event in events}
        self.assertEqual(event_ids, {decision['comment_id'] for decision in json.loads(approvals.read_text())['decisions']})
        self.assertTrue(packet['eligibility']['bounded_p8_15_proof'])
        for key in ['runtime_release', 'publication', 'production', 'public_release', 'paid_pilot', 'real_participant_delivery', 'phase_9']:
            self.assertFalse(packet['eligibility'][key], key)
        self.assertFalse(packet['binding']['latest_alias'])
        self.assertFalse(packet['binding']['silent_locale_fallback'])
        self.assertFalse(packet['binding']['provider_admission_enabled'])
        self.assertFalse(packet['support_contact']['operational_mailbox_verified'])
        self.assertFalse(packet['support_contact']['provider_admission_enabled'])
        for message in packet['messages']:
            self.assertIn(message['product_approval_event_id'], event_ids)
            contract = json.dumps(message['token_allowlist'], sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()
            self.assertEqual(sha(contract), message['token_contract_sha256'])
            self.assertEqual({x['locale'] for x in message['locale_versions']}, {'en', 'af'})
            for version in message['locale_versions']:
                self.assertIn(version['content_approval_event_id'], event_ids)
                self.assertIn(version['language_approval_event_id'], event_ids)
                self.assertNotEqual(version['content_approval_event_id'], version['language_approval_event_id'])
                data = (ROOT / version['artifact']['path']).read_bytes()
                self.assertEqual(len(data), version['artifact']['bytes'])
                self.assertEqual(sha(data), version['artifact']['sha256'])
                self.assertTrue(data.startswith(b'subject: '))
                self.assertTrue(data.endswith(b'\n') and not data.endswith(b'\n\n'))
                self.assertNotIn(b'\r', data)
                subject, body = data.split(b'\n\n', 1)
                self.assertEqual(sha(subject[len(b'subject: '):]), version['subject']['sha256'])
                self.assertEqual(sha(body), version['body']['sha256'])
                self.assertEqual(set(re.findall(rb'\{\{[^{}]+\}\}', data)), {x['literal'].encode() for x in message['token_allowlist']})
                for rule in message['token_allowlist']:
                    literal = rule['literal'].encode()
                    if literal in subject:
                        self.assertIn('subject', rule['allowed_fields'])
                    if literal in body:
                        self.assertIn('body', rule['allowed_fields'])
                self.assertNotIn(packet['support_contact']['value'].encode(), data)


if __name__ == '__main__':
    unittest.main()
