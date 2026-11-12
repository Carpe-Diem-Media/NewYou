import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from tools import knowledge_capture as capture


class KnowledgeCaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'user.name', 'Test')
        (self.repo / 'lib').mkdir()
        (self.repo / 'test').mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.repo, check=True, text=True,
                              stdout=subprocess.PIPE).stdout.strip()

    def commit(self, message):
        self.git('add', '-A')
        self.git('commit', '-qm', message)
        return self.git('rev-parse', 'HEAD')

    def test_changed_functions_only_with_clauses_default_arity_and_nested_module(self):
        source = '''defmodule Demo do
  def keep(x), do: x
  def change(x \\\\ 1), do: x
  def change(x) when is_integer(x), do: x + 1
  def change(_), do: :other
  defmodule Inner do
    def nested(x), do: x
  end
end
'''
        (self.repo / 'lib/demo.ex').write_text(source)
        base = self.commit('base')
        (self.repo / 'lib/demo.ex').write_text(source.replace('x + 1', 'x + 2'))
        (self.repo / 'test/demo_test.exs').write_text('assert true\n')
        head = self.commit('change')

        result = capture.extract(self.repo, base, head, 224, ['WELL-121'])
        self.assertEqual(result['files'][0]['path'], 'lib/demo.ex')
        symbols = result['symbols']
        self.assertEqual([(s['module'], s['name'], s['arity'], s['change']) for s in symbols
                          if s.get('kind') == 'function'], [('Demo', 'change', 1, 'changed')])
        self.assertEqual(result['tests'], ['test/demo_test.exs'])

    def test_renamed_and_deleted_files_record_modes_blobs_and_removed_symbols(self):
        (self.repo / 'lib/old.ex').write_text('defmodule Old do\n def gone, do: :ok\nend\n')
        base = self.commit('base')
        self.git('mv', 'lib/old.ex', 'lib/new.ex')
        head = self.commit('rename')
        record = capture.extract(self.repo, base, head, 224, [])
        self.assertEqual(record['files'][0]['status'], 'renamed')
        self.assertEqual(record['files'][0]['old_path'], 'lib/old.ex')
        self.assertEqual(record['files'][0]['path'], 'lib/new.ex')
        self.assertEqual(record['files'][0]['old_mode'], '100644')
        self.assertTrue(record['files'][0]['old_blob'])
        self.assertTrue(record['files'][0]['sha256'])
        self.assertFalse(record['symbols'])

        (self.repo / 'lib/new.ex').unlink()
        deleted = self.commit('delete')
        deleted_record = capture.extract(self.repo, head, deleted, 224, [])
        self.assertEqual(deleted_record['files'][0]['status'], 'deleted')
        self.assertTrue(any(s['change'] == 'removed' and s['name'] == 'gone'
                            for s in deleted_record['symbols']))

    def test_unparseable_source_is_unknown_with_reason(self):
        (self.repo / 'lib/bad.ex').write_text('defmodule Bad do\n def x( do: 1\n')
        base = self.commit('base')
        (self.repo / 'lib/bad.ex').write_text('defmodule Bad do\n def x( do: 2\n')
        head = self.commit('broken')
        record = capture.extract(self.repo, base, head, 224, [])
        self.assertTrue(any(symbol['status'] == 'unknown' and symbol['reason'] for symbol in record['symbols']))

    def test_alias_affected_namespace_is_unknown_and_atom_modules_are_absolute(self):
        parsed = capture._elixir_result(b'', b'alias Example, as: X\ndefmodule X.Inner do\n def f, do: :ok\nend\n')['new']
        self.assertEqual('unknown', parsed['status'])
        self.assertTrue(parsed['unknown'])
        atoms = capture._elixir_result(b'', b'defmodule Parent do\n defmodule :child do\n def f, do: :ok\nend\nend\n')['new']
        self.assertEqual('child', atoms['functions'][0]['module'])

    def test_metadata_and_record_tampering_are_rejected(self):
        (self.repo / 'lib/a.ex').write_text('defmodule A do\n def x, do: 1\nend\n')
        base = self.commit('base')
        (self.repo / 'lib/a.ex').write_text('defmodule A do\n def x, do: 2\nend\n')
        head = self.commit('head')
        with self.assertRaises(ValueError):
            capture.extract(self.repo, base, head, 225, ['WELL-999'], metadata={'number': 224})
        with self.assertRaises(ValueError):
            capture.extract(self.repo, base, head, 224, ['WELL-999'], metadata={
                'number': 224, 'base': {'sha': base}, 'head': {'sha': '0' * 40},
                'html_url': 'https://github.com/Carpe-Diem-Media/NewYou/pull/224',
                'title': 'WELL-121 test', 'body': ''})
        record = capture.extract(self.repo, base, head, 224, ['WELL-121'])
        record['files'][0]['sha256'] = '0' * 64
        with self.assertRaises(ValueError):
            capture.check_record(self.repo, record, capture.extract(self.repo, base, head, 224, ['WELL-121']))

    def test_raw_github_metadata_and_event_regenerate_identically_and_refuse_false_evidence(self):
        (self.repo / 'lib/a.py').write_text('value = 1\n')
        base = self.commit('base')
        (self.repo / 'lib/a.py').write_text('value = 2\n')
        head = self.commit('head')
        pr = dict(number=224, base={'sha': base}, head={'sha': head}, title='WELL-121 capture', body=None,
                  html_url='https://github.com/Carpe-Diem-Media/NewYou/pull/224',
                  url='https://api.github.com/repos/Carpe-Diem-Media/NewYou/pulls/224')
        expected = capture.extract(self.repo, base, head, 224, ['WELL-121'], metadata=pr)
        event = dict(number=224, pull_request=pr, repository={'full_name': 'Carpe-Diem-Media/NewYou'})
        self.assertEqual(expected, capture.extract(self.repo, base, head, 224, ['WELL-121'], metadata=event))
        for change in (dict(title='WELL-999 mismatch'), dict(base={'sha': '0' * 40}),
                       dict(head={'sha': '0' * 40}), dict(html_url='https://github.com/other/repo/pull/224')):
            with self.subTest(change=change), self.assertRaises(ValueError):
                capture.extract(self.repo, base, head, 224, ['WELL-121'], metadata=dict(pr, **change))
        for change in (dict(ci={'status': 'PASS'}), dict(pr_url='https://example.invalid'),
                       dict(schema_version=True), dict(unknown='false evidence')):
            with self.subTest(change=change), self.assertRaises(ValueError):
                capture.check_record(self.repo, dict(expected, **change), expected)
        with self.assertRaisesRegex(ValueError, 'duplicate JSON key'):
            capture._loads('{"schema_version":1,"schema_version":true}')

        pristine = capture.extract(self.repo, base, head, 224, ['WELL-121'])
        pristine['ci']['status'] = 'PASS'
        with self.assertRaises(ValueError):
            capture.check_record(self.repo, pristine, capture.extract(self.repo, base, head, 224, ['WELL-121']))

        metadata = {'number': 224, 'base': {'sha': base, 'repo': {'full_name': 'Carpe-Diem-Media/NewYou'}},
                    'head': {'sha': head}, 'html_url': 'https://github.com/Carpe-Diem-Media/NewYou/pull/224',
                    'title': 'WELL-121 capture', 'body': None}
        linked = capture.extract(self.repo, base, head, 224, [], metadata=metadata)
        self.assertEqual(linked['tickets'], ['WELL-121'])
        event = {'number': 224, 'repository': {'full_name': 'Carpe-Diem-Media/NewYou'},
                 'pull_request': {'number': 224, 'base': {'sha': base}, 'head': {'sha': head},
                                  'html_url': metadata['html_url'], 'title': 'WELL-121 capture', 'body': ''}}
        self.assertEqual(capture.extract(self.repo, base, head, 224, [], metadata=event)['tickets'], ['WELL-121'])

    def test_clause_order_default_arity_empty_module_and_dynamic_declaration(self):
        original = '''defmodule Demo do
  def pick(x) when is_integer(x), do: :integer
  def pick(_), do: :other
end
'''
        (self.repo / 'lib/demo.ex').write_text(original)
        base = self.commit('base')
        reordered = original.replace('  def pick(x) when is_integer(x), do: :integer\n  def pick(_), do: :other',
                                     '  def pick(_), do: :other\n  def pick(x) when is_integer(x), do: :integer')
        (self.repo / 'lib/demo.ex').write_text(reordered)
        head = self.commit('reorder')
        reordered_record = capture.extract(self.repo, base, head, 224, [])
        self.assertTrue(any(s.get('name') == 'pick' and s['change'] == 'changed'
                            for s in reordered_record['symbols']))

        (self.repo / 'lib/demo.ex').write_text('defmodule Empty do\nend\n')
        base = self.commit('empty base')
        (self.repo / 'lib/demo.ex').write_text('defmodule Empty do\n def run(a, b \\\\ 1), do: a + b\nend\n')
        head = self.commit('default arity')
        record = capture.extract(self.repo, base, head, 224, [])
        self.assertEqual({1, 2}, {s['arity'] for s in record['symbols'] if s.get('name') == 'run'})

        (self.repo / 'lib/demo.ex').write_text('defmodule unquote(name) do\nend\n')
        base = self.commit('dynamic base')
        (self.repo / 'lib/demo.ex').write_text('defmodule unquote(other) do\nend\n')
        head = self.commit('dynamic change')
        record = capture.extract(self.repo, base, head, 224, [])
        self.assertTrue(any(s['status'] == 'unknown' and s['reason'] for s in record['symbols']))

    def test_history_change_is_captured_except_exact_record(self):
        path = self.repo / 'docs/development/knowledge/history/pr-224.json'
        path.parent.mkdir(parents=True)
        path.write_text('{}\n')
        base = self.commit('base')
        path.write_text('{"old":true}\n')
        other = path.parent / 'pr-225.json'
        other.write_text('{}\n')
        head = self.commit('records')
        record = capture.extract(self.repo, base, head, 224, [])
        paths = [file['path'] for file in record['files']]
        self.assertNotIn('docs/development/knowledge/history/pr-224.json', paths)
        self.assertIn('docs/development/knowledge/history/pr-225.json', paths)

    def test_index_query_shows_only_current_tracked_sources_and_map_drift(self):
        (self.repo / 'lib/a.ex').write_text('defmodule A do\n def x, do: 1\nend\n')
        (self.repo / 'docs/development/knowledge').mkdir(parents=True)
        base = self.commit('base')
        import hashlib
        data = {'implementing_tickets': ['WELL-6'], 'sources': [{'path': 'lib/a.ex', 'symbol': 'def x',
                             'sha256': hashlib.sha256((self.repo / 'lib/a.ex').read_bytes()).hexdigest()}]}
        (self.repo / 'docs/development/knowledge/sample.json').write_text(json.dumps(data))
        head = self.commit('map')
        results = capture.query_index(self.repo, 'A')['results']
        self.assertTrue(any(row['path'] == 'lib/a.ex' for row in results))
        self.assertTrue(capture.query_index(self.repo, 'WELL-6')['results'])
        (self.repo / 'lib/a.ex').write_text('defmodule A do\n def y, do: 2\nend\n')
        rows = capture.query_index(self.repo, 'A', revision=head)
        self.assertTrue(any(row['path'] == 'lib/a.ex' for row in rows['results']))
        self.commit('source changed without map update')
        with self.assertRaisesRegex(ValueError, 'source drift'):
            capture.query_index(self.repo, 'A')

    def test_rename_out_of_test_or_migration_keeps_old_classification_and_lookup(self):
        old_test = self.repo / 'test/old_test.exs'
        old_test.write_text('defmodule ExampleTest do\nend\n')
        old_migration = self.repo / 'priv/repo/migrations/001_old.exs'
        old_migration.parent.mkdir(parents=True)
        old_migration.write_text('defmodule ExampleMigration do\nend\n')
        base = self.commit('base')
        self.git('mv', 'test/old_test.exs', 'lib/moved.exs')
        self.git('mv', 'priv/repo/migrations/001_old.exs', 'lib/migration.exs')
        head = self.commit('move')
        record = capture.extract(self.repo, base, head, 224, ['WELL-121'])
        self.assertIn('test/old_test.exs', record['tests'])
        self.assertIn('priv/repo/migrations/001_old.exs', record['migrations'])
        path = capture.record_path(self.repo, 224)
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps(record))
        self.commit('history')
        self.assertTrue(capture.query_index(self.repo, 'test/old_test.exs')['results'])

    def test_history_query_finds_python_file_by_ticket(self):
        (self.repo / 'lib/a.py').write_text('value = 1\n')
        base = self.commit('base')
        (self.repo / 'lib/a.py').write_text('value = 2\n')
        head = self.commit('head')
        record = capture.extract(self.repo, base, head, 224, ['WELL-121'])
        history = capture.record_path(self.repo, 224)
        history.parent.mkdir(parents=True)
        history.write_text(json.dumps(record))
        self.commit('history')
        result = capture.query_index(self.repo, 'WELL-121')
        self.assertTrue(any(row['path'] == 'lib/a.py' and row['historical'] for row in result['results']))

    def test_history_directory_symlink_cannot_escape_repository(self):
        (self.repo / 'docs/development/knowledge').mkdir(parents=True)
        outside = Path('/tmp')
        history = self.repo / 'docs/development/knowledge/history'
        history.symlink_to(outside, target_is_directory=True)
        with self.assertRaises(ValueError):
            capture.record_path(self.repo, 224)


if __name__ == '__main__':
    unittest.main()
