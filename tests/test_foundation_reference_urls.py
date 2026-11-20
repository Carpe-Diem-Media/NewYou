"""Focused reference-scanner regressions without repository-wide fixtures."""
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.foundation_integrity_smoke import (
    _check_active_document_references,
    _document_reference_resolves,
)


DEVCORE_BASE = (
    "https://github.com/Carpe-Diem-Media/devcore-project/blob/"
    "1a46dcc54d3ac37fa554955e20c45555c0e08f5b/docs/activation/"
)


class FoundationReferenceUrlTests(unittest.TestCase):
    def scan(self, text, files=()):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("governance", "delivery", "development"):
                (root / "docs" / name).mkdir(parents=True)
            for relative in files:
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("", encoding="utf-8")
            (root / "docs/development/guide.md").write_text(text, encoding="utf-8")
            report = {"checks": [], "findings": []}
            _check_active_document_references(root, report)
            return report["checks"][0]

    def test_actual_devcore_external_markdown_destinations(self):
        for name in ("newyou-verification.md", "newyou-legacy-connect-proposal.md",
                     "newyou-workstation-manifest.json"):
            with self.subTest(name=name):
                check = self.scan(f"[procedure]({DEVCORE_BASE}{name})")
                self.assertEqual("PASS", check["status"], check)

    def test_external_urls_in_supported_text_contexts(self):
        url = DEVCORE_BASE + "newyou-verification.md"
        for text in (url, f"`{url}`", f"<{url}>", f"[procedure](<{url}>)",
                     f"[procedure](\n{url}\n)", url.replace("https://", "http://"),
                     url.replace("https://", "HTTPS://")):
            with self.subTest(text=text):
                self.assertEqual("PASS", self.scan(text)["status"])

    def test_external_url_does_not_hide_missing_local_reference(self):
        url = DEVCORE_BASE + "newyou-verification.md"
        for reference in ("docs/development/missing.md", "missing.md", "./missing.md",
                          "../missing.md", "/docs/development/missing.md"):
            for local in (f"[local]({reference})", f"[local](\n{reference}\n)"):
                with self.subTest(local=local):
                    check = self.scan(f"[external]({url}) {local}")
                    self.assertEqual("FAIL", check["status"], check)
                    self.assertIn(reference, check["message"])
        check = self.scan(f"`{url}`\n`docs/development/missing.md`")
        self.assertEqual("FAIL", check["status"])
        self.assertIn("docs/development/missing.md", check["message"])

    def test_existing_relative_and_repository_rooted_references(self):
        check = self.scan(
            "[relative](peer.md) [parent](../peer.md) "
            "`docs/development/peer.md` [rooted](docs/development/peer.md)",
            files=("docs/development/peer.md", "docs/peer.md"),
        )
        self.assertEqual("PASS", check["status"], check)

    def test_repository_traversal_and_absolute_paths_remain_rejected(self):
        for reference in ("docs/../development/peer.md", "../../outside.md",
                          "/docs/development/peer.md"):
            with self.subTest(reference=reference):
                check = self.scan(
                    f"[external]({DEVCORE_BASE}newyou-verification.md) [local]({reference})",
                    files=("docs/development/peer.md",),
                )
                self.assertEqual("FAIL", check["status"], check)
                self.assertIn(reference, check["message"])

    def test_external_looking_local_paths_are_not_exempt(self):
        for reference in ("https:///docs/missing.md", "github.com/docs/missing.md",
                          "docs/https/missing.md"):
            with self.subTest(reference=reference):
                check = self.scan(f"[local]({reference})")
                self.assertEqual("FAIL", check["status"], check)

    def test_existing_outside_files_and_rooted_symlinks_remain_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            outer = Path(directory)
            root = outer / "repository"
            source = root / "docs/development/guide.md"
            source.parent.mkdir(parents=True)
            outside = outer / "outside.md"
            outside.write_text("exists", encoding="utf-8")
            (root / "docs/development/link.md").symlink_to(outside)
            for reference in ("../../../outside.md", "docs/development/link.md"):
                with self.subTest(reference=reference):
                    self.assertFalse(_document_reference_resolves(root, source, reference))

    def test_local_link_label_is_still_checked(self):
        check = self.scan(f"[docs/development/missing.md]({DEVCORE_BASE}newyou-verification.md)")
        self.assertEqual("FAIL", check["status"])
        self.assertIn("docs/development/missing.md", check["message"])


if __name__ == "__main__":
    unittest.main()
