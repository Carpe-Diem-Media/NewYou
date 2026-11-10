from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools/ci/prepare_cached_dependencies.sh"


class CacheRecoveryTests(unittest.TestCase):
    def archived_preparation(self, *, tamper=False, fail_first=False, hit="true", restore="success"):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            producer = root / "producer"
            consumer = root / "consumer"
            (producer / "deps/pkg").mkdir(parents=True)
            (producer / "_build/test/lib/pkg").mkdir(parents=True)
            consumer.mkdir()
            (producer / "deps/pkg/source").write_text("dependency source")
            (producer / "deps/pkg/source").chmod(0o664)
            (producer / "deps/pkg/executable").write_text("executable dependency")
            (producer / "deps/pkg/executable").chmod(0o775)
            (producer / "deps/pkg/link").symlink_to("source")
            (producer / "_build/test/lib/pkg/beam").write_text("compiled dependency")
            manifest_script = ROOT / "tools/ci/cache_manifest.py"
            subprocess.run(["python3", str(manifest_script), "write"], cwd=producer, check=True)
            if tamper:
                (producer / "deps/pkg/source").write_text("tampered")
            file_list = root / "manifest.txt"
            file_list.write_text("deps\n_build/test/lib\n_build/ci-dependency-cache.json\n")
            archive = root / "cache.tar"
            subprocess.run(["tar", "--posix", "-cf", str(archive), "-P", "-C", str(producer),
                            "--files-from", str(file_list)], check=True)
            subprocess.run(["tar", "-xf", str(archive), "-P", "-C", str(consumer)], check=True,
                           preexec_fn=lambda: os.umask(0o022))
            self.assertEqual(0o644, (consumer / "deps/pkg/source").stat().st_mode & 0o777)
            self.assertEqual(0o755, (consumer / "deps/pkg/executable").stat().st_mode & 0o777)
            (consumer / "tools/ci").mkdir(parents=True)
            shutil.copy(manifest_script, consumer / "tools/ci/cache_manifest.py")
            bin_dir = consumer / "bin"
            bin_dir.mkdir()
            mix = bin_dir / "mix"
            mix.write_text('''#!/bin/sh
if [ -e deps/pkg/source ]; then state=cached; else state=clean; fi
echo "$*:$state" >> calls
if [ "$FAIL_ONCE" = 1 ] && [ ! -e retried ]; then touch retried; exit 1; fi
exit 0
''')
            mix.chmod(0o755)
            env = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}",
                       CACHE_RESTORE_OUTCOME=restore, CACHE_HIT=hit,
                       FAIL_ONCE="1" if fail_first else "0")
            result = subprocess.run(["bash", str(SCRIPT)], cwd=consumer, env=env,
                                    capture_output=True, text=True)
            return (result, (consumer / "calls").read_text().splitlines(),
                    (consumer / "deps/pkg/link").is_symlink(),
                    (consumer / "deps/pkg/source").exists())

    def test_real_tar_roundtrip_reuses_valid_cache_with_symlink_and_modes(self):
        result, calls, link, source = self.archived_preparation()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(["deps.get --check-locked:cached", "deps.compile --warnings-as-errors:cached"], calls)
        self.assertTrue(link)
        self.assertTrue(source)

    def test_real_tar_roundtrip_tamper_is_discarded_before_mix(self):
        result, calls, link, source = self.archived_preparation(tamper=True)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(["deps.get --check-locked:clean", "deps.compile --warnings-as-errors:clean"], calls)
        self.assertFalse(link)
        self.assertFalse(source)

    def test_real_tar_roundtrip_retry_discards_valid_cache_after_mix_failure(self):
        result, calls, link, source = self.archived_preparation(fail_first=True)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(["deps.get --check-locked:cached", "deps.get --check-locked:clean",
                          "deps.compile --warnings-as-errors:clean"], calls)
        self.assertFalse(link)
        self.assertFalse(source)

    def test_real_tar_roundtrip_rejects_partial_key_and_failed_restore(self):
        for options in ({"hit": "false"}, {"restore": "failure"}):
            with self.subTest(**options):
                result, calls, link, source = self.archived_preparation(**options)
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertEqual(["deps.get --check-locked:clean", "deps.compile --warnings-as-errors:clean"], calls)
                self.assertFalse(link)
                self.assertFalse(source)

    def run_preparation(self, failure: str, restore: str = "success", hit: str = "false", valid_manifest: bool = False):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "deps").mkdir()
            (root / "_build/test").mkdir(parents=True)
            (root / "_build/test/lib").mkdir()
            (root / "deps/stale").touch()
            (root / "_build/test/stale").touch()
            bin_dir = root / "bin"
            bin_dir.mkdir()
            (root / "tools/ci").mkdir(parents=True)
            shutil.copy(ROOT / "tools/ci/cache_manifest.py", root / "tools/ci/cache_manifest.py")
            if valid_manifest:
                subprocess.run(["python3", str(root / "tools/ci/cache_manifest.py"), "write"], cwd=root, check=True)
            mix = bin_dir / "mix"
            mix.write_text('''#!/bin/sh
echo "$*" >> calls
if [ "$FAILURE" = always ] || { [ "$FAILURE" = once ] && [ ! -e retried ]; }; then
  touch retried
  exit 1
fi
exit 0
''')
            mix.chmod(0o755)
            env = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}", FAILURE=failure,
                       CACHE_RESTORE_OUTCOME=restore, CACHE_HIT=hit)
            result = subprocess.run(["bash", str(SCRIPT)], cwd=root, env=env, capture_output=True, text=True)
            calls = root / "calls"
            return result.returncode, calls.read_text().splitlines() if calls.exists() else [], (root / "deps/stale").exists()

    def test_non_exact_match_discards_restored_files_before_locked_preparation(self):
        # Even an internally consistent manifest cannot make a partial key compatible.
        code, calls, stale = self.run_preparation("none", valid_manifest=True)
        self.assertEqual((0, ["deps.get --check-locked", "deps.compile --warnings-as-errors"], False), (code, calls, stale))

    def test_empty_hit_output_discards_any_partial_files(self):
        code, calls, stale = self.run_preparation("none", hit="")
        self.assertEqual((0, ["deps.get --check-locked", "deps.compile --warnings-as-errors"], False), (code, calls, stale))

    def test_failed_restore_discards_partial_contents(self):
        code, calls, stale = self.run_preparation("none", "failure")
        self.assertEqual((0, ["deps.get --check-locked", "deps.compile --warnings-as-errors"], False), (code, calls, stale))

    def test_exact_valid_cache_is_retained(self):
        code, calls, stale = self.run_preparation("none", hit="true", valid_manifest=True)
        self.assertEqual((0, ["deps.get --check-locked", "deps.compile --warnings-as-errors"], True), (code, calls, stale))

    def test_invalid_cache_rebuilds_once_from_clean_state(self):
        code, calls, stale = self.run_preparation("once")
        self.assertEqual((0, ["deps.get --check-locked", "deps.get --check-locked", "deps.compile --warnings-as-errors"], False), (code, calls, stale))

    def test_cache_hit_without_manifest_discards_cache_before_mix(self):
        code, calls, stale = self.run_preparation("none", hit="true")
        self.assertEqual((0, ["deps.get --check-locked", "deps.compile --warnings-as-errors"], False), (code, calls, stale))

    def test_failure_after_clean_rebuild_fails_closed(self):
        code, calls, stale = self.run_preparation("always")
        self.assertNotEqual(code, 0)
        self.assertEqual(["deps.get --check-locked", "deps.get --check-locked"], calls)
        self.assertFalse(stale)

    def test_missing_or_corrupt_manifest_rejects_cache(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "deps").mkdir()
            (root / "_build/test/lib").mkdir(parents=True)
            (root / "deps/package").write_text("valid")
            manifest = ROOT / "tools/ci/cache_manifest.py"
            def run(action):
                return subprocess.run(["python3", str(manifest), action], cwd=root, capture_output=True).returncode
            self.assertNotEqual(0, run("check"))
            self.assertEqual(0, run("write"))
            self.assertEqual(0, run("check"))
            (root / "deps/package").write_text("corrupt")
            self.assertNotEqual(0, run("check"))

    def test_mismatch_diagnostics_are_bounded_and_do_not_disclose_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "deps").mkdir()
            (root / "_build/test/lib").mkdir(parents=True)
            for index in range(25):
                (root / "deps" / f"sensitive-name-{index}").write_text("original")
            manifest = ROOT / "tools/ci/cache_manifest.py"
            subprocess.run(["python3", str(manifest), "write"], cwd=root, check=True)
            for path in (root / "deps").iterdir():
                path.write_text("changed")
            result = subprocess.run(["python3", str(manifest), "check"], cwd=root, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("content_changed=25", result.stderr)
            self.assertNotIn("sensitive-name", result.stderr)
            self.assertLessEqual(result.stderr.count("path_sha256="), 10)

    def test_mismatch_diagnostics_distinguish_modes_links_missing_and_extra_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "deps").mkdir()
            (root / "_build/test/lib").mkdir(parents=True)
            mode = root / "deps/mode"
            mode.write_text("unchanged")
            mode.chmod(0o644)
            (root / "deps/missing").write_text("original")
            link = root / "deps/link"
            link.symlink_to("mode")
            manifest = ROOT / "tools/ci/cache_manifest.py"
            subprocess.run(["python3", str(manifest), "write"], cwd=root, check=True)
            mode.chmod(0o755)
            (root / "deps/missing").unlink()
            (root / "deps/extra").write_text("new")
            link.unlink()
            link.symlink_to("elsewhere")
            result = subprocess.run(["python3", str(manifest), "check"], cwd=root, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            for category in ("mode_changed=1", "link_changed=1", "missing=1", "unexpected=1"):
                self.assertIn(category, result.stderr)
            self.assertIn("mode=644->755", result.stderr)

    def test_write_normalizes_regular_files_without_following_symlinks(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "deps").mkdir()
            (root / "_build/test/lib").mkdir(parents=True)
            regular = root / "deps/file"
            regular.write_text("content")
            regular.chmod(0o664)
            outside = root / "outside"
            outside.write_text("outside")
            outside.chmod(0o664)
            (root / "deps/link").symlink_to(outside)
            manifest = ROOT / "tools/ci/cache_manifest.py"
            subprocess.run(["python3", str(manifest), "write"], cwd=root, check=True)
            self.assertEqual(0o644, regular.stat().st_mode & 0o777)
            self.assertEqual(0o664, outside.stat().st_mode & 0o777)
            regular.chmod(0o664)
            result = subprocess.run(["python3", str(manifest), "check"], cwd=root, capture_output=True)
            self.assertNotEqual(0, result.returncode)

    def test_symlink_cache_root_is_rejected_without_touching_target(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "_build/test/lib").mkdir(parents=True)
            target = root / "outside"
            target.mkdir()
            protected = target / "file"
            protected.write_text("content")
            protected.chmod(0o664)
            (root / "deps").symlink_to(target, target_is_directory=True)
            manifest = ROOT / "tools/ci/cache_manifest.py"
            for action in ("write", "check"):
                result = subprocess.run(["python3", str(manifest), action], cwd=root, capture_output=True)
                self.assertNotEqual(0, result.returncode)
            self.assertEqual(0o664, protected.stat().st_mode & 0o777)


if __name__ == "__main__":
    unittest.main()
