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


if __name__ == "__main__":
    unittest.main()
