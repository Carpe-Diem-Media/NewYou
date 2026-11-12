import copy
import json
from pathlib import Path
import tempfile
import unittest

class CapabilityKnowledgeTests(unittest.TestCase):
    def setUp(self):
        from tools import capability_knowledge as knowledge
        self.knowledge=knowledge
        self.root=Path(__file__).resolve().parents[1]
        self.sample=json.loads((self.root/'docs/development/knowledge/identity.registration.json').read_text())

    def test_source_verified_registration_map(self):
        self.knowledge.validate_map(self.sample,self.root)

    def test_missing_contract_unknown_field_wrong_type_and_revision_refuse(self):
        for change in [dict(capability_id='bad id'),dict(schema_version=2),dict(unknown=True),dict(interfaces='prose')]:
            with self.subTest(change=change),self.assertRaises(ValueError):
                self.knowledge.validate_map(dict(self.sample,**change),self.root)
        changed=copy.deepcopy(self.sample);del changed['lifecycle']
        with self.assertRaises(ValueError):self.knowledge.validate_map(changed,self.root)

    def test_missing_traversal_alias_symbol_and_changed_source_refuse(self):
        for change in [dict(path='../AGENTS.md'),dict(path='/etc/passwd'),dict(path='lib/../AGENTS.md'),
                       dict(path='lib/not_real.ex'),dict(symbol='invented_public_api'),dict(sha256='0'*64)]:
            changed=copy.deepcopy(self.sample);changed['sources'][0].update(change)
            with self.subTest(change=change),self.assertRaises(ValueError):self.knowledge.validate_map(changed,self.root)

    def test_unknown_source_reference_refuses(self):
        changed=copy.deepcopy(self.sample);changed['interfaces'][0]['source_ids']=['invented']
        with self.assertRaises(ValueError):self.knowledge.validate_map(changed,self.root)

    def test_invented_table_or_unlinked_migration_refuses(self):
        changed=copy.deepcopy(self.sample);changed['persistence'][1]['tables']=['invented_table']
        with self.assertRaises(ValueError):self.knowledge.validate_map(changed,self.root)
        changed=copy.deepcopy(self.sample);changed['persistence'][1]['migration']='priv/repo/not_a_migration.exs'
        with self.assertRaises(ValueError):self.knowledge.validate_map(changed,self.root)

    def test_duplicate_json_keys_refuse(self):
        with self.assertRaises(ValueError):self.knowledge.loads('{"schema_version":1,"schema_version":2}')

if __name__=='__main__':unittest.main()
