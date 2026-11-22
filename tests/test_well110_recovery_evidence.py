import hashlib
import json
import re
import shutil
import tempfile
import unittest
from pathlib import Path

from tools import check_magic_login_evidence as magic
from tools import check_password_reset_message_evidence as reset

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / 'docs/delivery/content-evidence/content_media/recovery_messages'


def sha(data):
    return hashlib.sha256(data).hexdigest()


class RecoveryEvidenceTest(unittest.TestCase):
    def test_existing_auditors_reject_changed_current_route_and_proposal(self):
        magic_packet = json.loads((ROOT / magic.PACKET_PATH.with_name(magic.PACKET_PATH.name.replace('v0.1.0', 'v0.2.0'))).read_text())
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            shutil.copytree(ROOT / 'docs', root / 'docs')
            self.assertEqual([], magic.validate_development(root, magic_packet))
            self.assertEqual([], reset.validate_development(root)['findings'])
            proposal = root / 'docs/delivery/content-evidence/content_media/recovery_messages/PRODUCT_CLASSIFICATION_PROPOSALS_v0.1.0.md'
            original = proposal.read_bytes()
            proposal.write_bytes(original + b'\n')
            self.assertTrue(magic.validate_development(root, magic_packet))
            self.assertTrue(reset.validate_development(root)['findings'])
            proposal.write_bytes(original)
            router_path = root / 'docs/governance/CURRENT_GOVERNANCE_ROUTER.json'
            router = json.loads(router_path.read_text())
            duplicate = next(x for x in router['governing_documents'] if x['document_id'] == 'PLATFORM_PRODUCT_LAW')
            router['governing_documents'].append(duplicate)
            router_path.write_text(json.dumps(router))
            self.assertTrue(magic.validate_development(root, magic_packet))
            self.assertTrue(reset.validate_development(root)['findings'])

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

    def test_phase9_packet_preserves_exact_approved_subjects_and_receipts(self):
        new_path = DIR / 'WELL175_PHASE9_APPLICABILITY_EVIDENCE_v0.1.0.json'
        new_bytes = new_path.read_bytes()
        packet = json.loads(new_bytes)
        delivery = json.loads((ROOT / 'docs/delivery/CURRENT_DELIVERY_ROUTER.json').read_bytes())
        routes = [row for row in delivery['delivery_contracts']
                  if row['document_id'] == 'WELL175_RECOVERY_PHASE9_APPLICABILITY_EVIDENCE']
        self.assertEqual([(new_path.relative_to(ROOT).as_posix(), sha(new_bytes))],
                         [(row['repository_path'], row['sha256']) for row in routes])

        sources = {**packet['approved_subjects']}
        sources.pop('draft_head')
        for reference in [*sources.values(), packet['historical_packet'], *packet['predecessor_authority']]:
            self.assertEqual(reference['sha256'], sha((ROOT / reference['path']).read_bytes()))

        original = json.loads((ROOT / sources['exact_bindings']['path']).read_bytes())
        self.assertEqual(original['support_contact'], packet['support_contact'])
        self.assertIs(packet['support_contact']['operational_mailbox_verified'], False)
        self.assertIs(packet['support_contact']['provider_admission_enabled'], False)
        self.assertTrue(all(value is False for value in packet['eligibility'].values()))
        self.assertEqual(['superseded', 'withdrawn'], packet['lifecycle']['terminal_for_new_use'])
        self.assertTrue(packet['lifecycle']['recheck_before_new_and_queued_use'])

        receipts = packet['approval_receipts']
        self.assertEqual([
            '84b93616-76d0-4103-bb14-dbf117c024a9',
            '90b4fa76-b68c-424f-94bd-35d03b727d95',
            'c550b9aa-a681-4cff-9e07-7937ee0560a2',
            '4d89259b-8d70-4e40-a959-8551a4da321e',
            '2731c139-27e1-48d6-82b6-09165cbf6a5c',
        ], [receipt['id'] for receipt in receipts])
        self.assertEqual(receipts[0]['id'], packet['exact_product_applicability_decision'])
        self.assertEqual(['Product owner'] + ['Content & Media owner'] * 4,
                         [receipt['role'] for receipt in receipts])
        for receipt in receipts:
            self.assertEqual(packet['scope_receipt']['actor'], receipt['actor'])
            self.assertIsNone(receipt['edited_at'])
            for value in [packet['context'], packet['approved_subjects']['draft_head'],
                          sources['proposal']['sha256'], sources['exact_bindings']['sha256']]:
                self.assertIn(value, receipt['comment_stripped'])

        content_receipts = iter(receipts[1:])
        for message, original_message in zip(packet['messages'], original['messages'], strict=True):
            for actual, expected in zip(message['locale_versions'], original_message['locale_versions'], strict=True):
                receipt = next(content_receipts)
                self.assertEqual(receipt['id'], actual['phase_9_content_applicability_decision'])
                expected['phase_9_content_applicability_decision'] = receipt['id']
                for required in [actual['content_translation_version_id'], actual['artifact']['sha256'],
                                 message['token_contract_sha256'], actual['language_approval_event_id']]:
                    self.assertIn(required, receipt['comment_stripped'])
            self.assertEqual(original_message, message)

    def test_phase9_authority_appends_only_exact_approved_clauses(self):
        governance = json.loads((ROOT / 'docs/governance/CURRENT_GOVERNANCE_ROUTER.json').read_bytes())
        packet = json.loads((DIR / 'WELL175_PHASE9_APPLICABILITY_EVIDENCE_v0.1.0.json').read_bytes())
        proposal = (ROOT / packet['approved_subjects']['proposal']['path']).read_text()
        product, decisions = proposal.split('## Proposed Product successor clause\n\n')[1].split(
            '\n## Proposed Decision successor clause\n\n'
        )
        product = product.replace('(EXACT_BINDINGS_v0.1.0.json)',
                                  '(proposals/well-175/EXACT_BINDINGS_v0.1.0.json)')
        for record, clause in zip(packet['current_governing_authority'], (product, decisions), strict=True):
            old = (ROOT / record['predecessor']['path']).read_text()
            new = (ROOT / record['path']).read_text()
            old_body = old.split('\n\n', 2)[2]
            new_body = new.split('\n\n', 2)[2]
            self.assertEqual(old_body.rstrip() + '\n\n' + clause.strip().replace('### ', '## ', 1) + '\n',
                             new_body)
            self.assertEqual(record['sha256'], sha(new.encode()))
            routes = [row for row in governance['governing_documents']
                      if row['document_id'] == record['document_id']]
            self.assertEqual([(record['path'], record['sha256'], '1.20.0')],
                             [(row['repository_path'], row['sha256'], row['semver']) for row in routes])


if __name__ == '__main__':
    unittest.main()
