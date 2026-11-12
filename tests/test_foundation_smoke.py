from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from tools.foundation_integrity_smoke import run_smoke_audit


ROOT = Path(__file__).resolve().parents[1]
GOVERNANCE_ROUTER = Path("docs/governance/CURRENT_GOVERNANCE_ROUTER.json")
DELIVERY_ROUTER = Path("docs/delivery/CURRENT_DELIVERY_ROUTER.json")


class FoundationSmokeTests(unittest.TestCase):
    def _fixture(self, directory: str) -> Path:
        root = Path(directory)
        shutil.copy2(ROOT / "AGENTS.md", root / "AGENTS.md")
        shutil.copy2(ROOT / "DESIGN.md", root / "DESIGN.md")
        for relative in ("docs/governance", "docs/delivery", "docs/history"):
            shutil.copytree(ROOT / relative, root / relative)
        shutil.copytree(ROOT / "docs/superpowers", root / "docs/superpowers")
        (root / "docs").mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "docs/README.md", root / "docs/README.md")
        shutil.copytree(ROOT / "docs/development", root / "docs/development")
        # Capability JSON is active documentation with exact source references.
        knowledge = json.loads((ROOT / "docs/development/knowledge/identity.registration.json").read_text())
        for source in knowledge["sources"]:
            target = root / source["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / source["path"], target)
        shutil.copytree(ROOT / "tools/hex_audit", root / "tools/hex_audit")
        shutil.copytree(ROOT / "priv/resource_snapshots", root / "priv/resource_snapshots")
        shutil.copytree(ROOT / ".agents/skills", root / ".agents/skills")
        (root / ".github/workflows").mkdir(parents=True, exist_ok=True)
        shutil.copy2(
            ROOT / ".github/workflows/foundation-integrity.yml",
            root / ".github/workflows/foundation-integrity.yml",
        )
        for workflow in ("foundation-full.yml", "nightly-hardening.yml"):
            shutil.copy2(
                ROOT / ".github/workflows" / workflow,
                root / ".github/workflows" / workflow,
            )
        return root

    def _mutate_router(self, root: Path, relative: Path, mutate) -> None:
        path = root / relative
        router = json.loads(path.read_text(encoding="utf-8"))
        mutate(router)
        path.write_text(json.dumps(router, indent=2) + "\n", encoding="utf-8")

    def test_smoke_passes_both_current_routers(self):
        report = run_smoke_audit(ROOT)
        self.assertEqual("PASS", report["status"], report["findings"])
        self.assertGreater(report["assertion_count"], 0)

    def test_smoke_rejects_missing_delivery_router(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self._fixture(directory)
            (root / DELIVERY_ROUTER).unlink()

            report = run_smoke_audit(root)
            self.assertEqual("FAIL", report["status"])
            self.assertTrue(any("delivery router" in item["message"].lower() for item in report["findings"]))

    def test_smoke_rejects_unresolved_rooted_document_reference(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self._fixture(directory)
            readme = root / "docs/delivery/README.md"
            readme.write_text(
                readme.read_text(encoding="utf-8")
                + "\nBroken current link: `docs/history/missing-evidence.md`.\n",
                encoding="utf-8",
            )

            report = run_smoke_audit(root)
            self.assertEqual("FAIL", report["status"])
            self.assertTrue(
                any(item["check"] == "smoke_active_document_references" for item in report["findings"])
            )

    def test_smoke_rejects_prefixed_repository_document_reference(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self._fixture(directory)
            readme = root / "docs/delivery/README.md"
            readme.write_text(
                readme.read_text(encoding="utf-8")
                + "\nMalformed migration path: `deep/docs/history/example.md`.\n",
                encoding="utf-8",
            )

            report = run_smoke_audit(root)
            self.assertEqual("FAIL", report["status"])
            self.assertTrue(
                any(item["check"] == "smoke_active_document_references" for item in report["findings"])
            )

    def test_smoke_rejects_unresolved_relative_markdown_link(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self._fixture(directory)
            readme = root / "docs/delivery/README.md"
            readme.write_text(
                readme.read_text(encoding="utf-8")
                + "\nBroken relative link: [missing evidence](deep/missing-evidence.md).\n",
                encoding="utf-8",
            )

            report = run_smoke_audit(root)
            self.assertEqual("FAIL", report["status"])
            self.assertTrue(
                any(item["check"] == "smoke_active_document_references" for item in report["findings"])
            )

    def test_smoke_rejects_document_reference_path_escape(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self._fixture(directory)
            readme = root / "docs/delivery/README.md"
            readme.write_text(
                readme.read_text(encoding="utf-8")
                + "\nEscaping path: `docs/delivery/../history/02_OPEN_WORK_v1.2.90.md`.\n",
                encoding="utf-8",
            )

            report = run_smoke_audit(root)
            self.assertEqual("FAIL", report["status"])
            self.assertTrue(
                any(item["check"] == "smoke_active_document_references" for item in report["findings"])
            )

    def test_governance_router_cannot_route_into_delivery_or_history(self):
        for forbidden in ("docs/delivery/feature-contracts/example.md", "docs/history/example.md"):
            with self.subTest(path=forbidden), tempfile.TemporaryDirectory() as directory:
                root = self._fixture(directory)
                self._mutate_router(
                    root,
                    GOVERNANCE_ROUTER,
                    lambda router: router["governing_documents"].append(
                        {
                            "document_id": "CROSS_ROOT",
                            "canonical_filename": Path(forbidden).name,
                            "semver": "1.0.0",
                            "repository_path": forbidden,
                            "sha256": "0" * 64,
                        }
                    ),
                )

                report = run_smoke_audit(root)
                self.assertEqual("FAIL", report["status"])
                self.assertTrue(any("governance" in item["message"].lower() for item in report["findings"]))

    def test_delivery_router_cannot_route_into_governance_or_history(self):
        for forbidden in (
            "docs/governance/product/00_PLATFORM_v1.13.0.md",
            "docs/history/02_OPEN_WORK_v1.2.90.md",
        ):
            with self.subTest(path=forbidden), tempfile.TemporaryDirectory() as directory:
                root = self._fixture(directory)
                self._mutate_router(
                    root,
                    DELIVERY_ROUTER,
                    lambda router: router["delivery_contracts"].append(
                        {
                            "document_id": "CROSS_ROOT",
                            "contract_type": "jit",
                            "repository_path": forbidden,
                            "sha256": "0" * 64,
                        }
                    ),
                )

                report = run_smoke_audit(root)
                self.assertEqual("FAIL", report["status"])
                self.assertTrue(any("delivery" in item["message"].lower() for item in report["findings"]))

    def test_delivery_router_change_does_not_change_governance_routing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self._fixture(directory)
            governance_path = root / GOVERNANCE_ROUTER
            before = governance_path.read_bytes()

            def add_delivery_route(router):
                added = dict(router["delivery_contracts"][0])
                added["document_id"] = "ADDITIONAL_DELIVERY_ROUTE"
                router["delivery_contracts"].append(added)

            self._mutate_router(root, DELIVERY_ROUTER, add_delivery_route)

            report = run_smoke_audit(root)
            self.assertEqual("PASS", report["status"], report["findings"])
            self.assertEqual(before, governance_path.read_bytes())

    def test_governance_router_excludes_delivery_and_plane_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self._fixture(directory)
            self._mutate_router(
                root,
                GOVERNANCE_ROUTER,
                lambda router: router.update(
                    {"delivery_contracts": [], "execution_authority": {"provider": "Plane"}}
                ),
            )

            report = run_smoke_audit(root)
            self.assertEqual("FAIL", report["status"])
            self.assertTrue(any("boundary" in item["message"].lower() for item in report["findings"]))

    def test_smoke_requires_semantic_roots_and_plane_entrypoint(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self._fixture(directory)
            readme = root / "docs/README.md"
            readme.write_text("Old path only: docs/00_platform/README.md\n", encoding="utf-8")

            report = run_smoke_audit(root)
            self.assertEqual("FAIL", report["status"])
            self.assertTrue(any("documentation entrypoint" in item["message"].lower() for item in report["findings"]))

    def test_smoke_rejects_stale_current_readme_prose_but_ignores_historical_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self._fixture(directory)
            readme = root / "docs/README.md"
            readme.write_text(
                readme.read_text(encoding="utf-8")
                + "\nProof classification remains NOT FINALISED.\n",
                encoding="utf-8",
            )

            report = run_smoke_audit(root)
            self.assertEqual("FAIL", report["status"])
            self.assertTrue(
                any(item["check"] == "smoke_documentation_entrypoint_current_prose" for item in report["findings"])
            )

        with tempfile.TemporaryDirectory() as directory:
            root = self._fixture(directory)
            historical = root / "docs/history/platform/README_PRE_SEMANTIC_ROOTS_2026-11-01.md"
            historical.write_text(
                historical.read_text(encoding="utf-8")
                + "\nProof classification remains NOT FINALISED in this frozen snapshot.\n",
                encoding="utf-8",
            )

            report = run_smoke_audit(root)
            self.assertEqual("PASS", report["status"], report["findings"])

    def test_smoke_rejects_stale_router_instructions_and_delivery_standard(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self._fixture(directory)
            agents = root / "AGENTS.md"
            agents.write_text(
                agents.read_text(encoding="utf-8").replace(
                    "architecture_references", "deep_reference_documents"
                ),
                encoding="utf-8",
            )

            report = run_smoke_audit(root)
            self.assertEqual("FAIL", report["status"])
            self.assertTrue(
                any(item["check"] == "smoke_agents_architecture_references" for item in report["findings"])
            )

        with tempfile.TemporaryDirectory() as directory:
            root = self._fixture(directory)
            router = json.loads((root / GOVERNANCE_ROUTER).read_text(encoding="utf-8"))
            standard = root / next(item["repository_path"] for item in router["supporting_documents"]
                                   if item["document_id"] == "DELIVERY_GOVERNANCE_STANDARD")
            standard.write_text(
                standard.read_text(encoding="utf-8").replace(
                    "docs/delivery/CURRENT_DELIVERY_ROUTER.json", "docs/governance/CURRENT_GOVERNANCE_ROUTER.json"
                ),
                encoding="utf-8",
            )

            report = run_smoke_audit(root)
            self.assertEqual("FAIL", report["status"])
            self.assertTrue(
                any(item["check"] == "smoke_delivery_governance_router_model" for item in report["findings"])
            )

    def test_smoke_rejects_broken_current_identity_history_references(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self._fixture(directory)
            router = json.loads((root / DELIVERY_ROUTER).read_text(encoding="utf-8"))
            identity_route = next(
                entry for entry in router["delivery_contracts"]
                if entry["document_id"] == "FP001_IDENTITY_ACCESS_JIT"
            )
            identity = root / identity_route["repository_path"]
            identity.write_text(
                identity.read_text(encoding="utf-8").replace(
                    "docs/history/platform/archive/identity_promotions/",
                    "archive/identity_promotions/",
                ),
                encoding="utf-8",
            )

            report = run_smoke_audit(root)
            self.assertEqual("FAIL", report["status"])
            self.assertTrue(
                any(item["check"] == "smoke_identity_historical_routes" for item in report["findings"])
            )


if __name__ == "__main__":
    unittest.main()
