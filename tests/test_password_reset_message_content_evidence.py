"""Password-reset content candidates remain exact, reviewable, and ineligible."""

import json
import hashlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHECKER = ROOT / "tools/check_password_reset_message_evidence.py"
PACKET_REL = Path(
    "docs/delivery/content-evidence/content_media/password_reset_messages/"
    "PASSWORD_RESET_MESSAGE_EVIDENCE_PACKET_v0.1.0.json"
)
EN_REL = Path(
    "docs/delivery/content-evidence/content_media/password_reset_messages/"
    "NEWYOU-PASSWORD-RESET-MESSAGE-EMAIL-EN-V1.txt"
)
AF_REL = Path(
    "docs/delivery/content-evidence/content_media/password_reset_messages/"
    "NEWYOU-PASSWORD-RESET-MESSAGE-EMAIL-AF-V1.txt"
)
ROUTER_REL = Path("docs/delivery/CURRENT_DELIVERY_ROUTER.json")
REGISTRY_REL = Path("docs/delivery/content-evidence/copy/COPY_REGISTRY.json")
CHECKSUMS_REL = Path("docs/delivery/content-evidence/copy/WORKSPACE_CHECKSUMS.tsv")


class PasswordResetMessageEvidenceTests(unittest.TestCase):
    def run_checker(self, root):
        return subprocess.run(
            [sys.executable, str(CHECKER), "--root", str(root)],
            capture_output=True,
            text=True,
            check=False,
        )

    def copy_evidence(self):
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        paths = [
            Path("docs/governance/CURRENT_GOVERNANCE_ROUTER.json"),
            Path("docs/governance/product/00_PLATFORM_v1.14.0.md"),
            Path("docs/governance/product/01_DECISIONS_v1.14.0.md"),
            Path("docs/governance/product/proposals/well-98"),
            ROUTER_REL,
            PACKET_REL.parent,
            Path("docs/delivery/content-evidence/copy/COPY_INVENTORY.md"),
            REGISTRY_REL,
            Path("docs/delivery/content-evidence/copy/REVIEW_REPORT.md"),
            CHECKSUMS_REL,
        ]
        for relative in paths:
            source = ROOT / relative
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            if source.is_dir():
                shutil.copytree(source, destination, dirs_exist_ok=True)
            else:
                shutil.copy2(source, destination)
        return temporary, root

    def read_packet(self, root):
        return json.loads((root / PACKET_REL).read_text(encoding="utf-8"))

    def write_json(self, path, value):
        path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    def write_packet(self, root, packet):
        packet_path = root / PACKET_REL
        self.write_json(packet_path, packet)
        raw = packet_path.read_bytes()
        router_path = root / ROUTER_REL
        router = json.loads(router_path.read_text(encoding="utf-8"))
        route = next(
            entry for entry in router["delivery_contracts"]
            if entry["document_id"] == "PASSWORD_RESET_MESSAGE_CANDIDATE_EVIDENCE"
        )
        route["sha256"] = hashlib.sha256(raw).hexdigest()
        self.write_json(router_path, router)

    def refresh_locale_binding(self, root, packet, locale_version, raw):
        first_line, body = raw.split(b"\n\n", 1)
        subject = first_line[len(b"subject: "):]
        locale_version["artifact"].update(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
        locale_version["subject"] = {
            "offset": len(b"subject: "),
            "bytes": len(subject),
            "sha256": hashlib.sha256(subject).hexdigest(),
        }
        locale_version["body"] = {
            "offset": len(first_line) + 2,
            "bytes": len(body),
            "sha256": hashlib.sha256(body).hexdigest(),
        }
        compact = raw.replace(b"\n\n", b"\n")
        locale_version["contiguous_rendering"] = {
            "bytes": len(compact),
            "sha256": hashlib.sha256(compact).hexdigest(),
        }
        decision = next(
            item for item in packet["owner_decisions"]
            if item.get("owner") == "Content & Media" and item.get("locale") == locale_version["locale"]
        )
        decision["subjects"][0].update(
            artifact=locale_version["artifact"],
            subject=locale_version["subject"],
            body=locale_version["body"],
        )

    def assert_rejected(self, root, expected_finding=None):
        result = self.run_checker(root)
        self.assertEqual(1, result.returncode, result.stderr or result.stdout)
        evidence = json.loads(result.stdout)
        self.assertEqual("FAIL", evidence["integrity"])
        self.assertFalse(evidence["candidate_eligible"])
        self.assertFalse(evidence["development_eligible"])
        if expected_finding:
            self.assertIn(expected_finding, " ".join(evidence["findings"]))

    def test_candidate_evidence_is_valid_but_never_eligible(self):
        result = self.run_checker(ROOT)

        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        evidence = json.loads(result.stdout)
        self.assertEqual("PASS", evidence["integrity"])
        self.assertFalse(evidence["candidate_eligible"])
        self.assertFalse(evidence["development_eligible"])
        self.assertFalse(evidence["runtime_release_eligible"])

        packet = self.read_packet(ROOT)
        for version in packet["locale_versions"]:
            raw = (ROOT / version["artifact"]["path"]).read_bytes()
            self.assertEqual(version["artifact"]["bytes"], len(raw))
            self.assertEqual(version["artifact"]["sha256"], hashlib.sha256(raw).hexdigest())
            self.assertEqual(["en", "af"], [item["locale"] for item in packet["locale_versions"]])
            self.assertEqual(
                {
                    "subject": "identity.password_reset.email.subject",
                    "body": "identity.password_reset.email.body",
                },
                version["proposed_copy_keys"],
            )
            subject_line, body = raw.split(b"\n\n", 1)
            subject = subject_line[len(b"subject: "):].decode("utf-8")
            self.assertTrue(subject.startswith("Reset " if version["locale"] == "en" else "Stel jou "))
            self.assertIn(b"{{password_reset_link}}", body)

    def test_changed_bytes_wrong_digest_and_wrong_locale_fail_closed(self):
        for mutation, finding in (
            ("changed_bytes", "artifact digest mismatch"),
            ("wrong_digest", "artifact digest mismatch"),
            ("wrong_locale", "EN and AF locale binding"),
        ):
            temporary, root = self.copy_evidence()
            with temporary:
                packet = self.read_packet(root)
                if mutation == "changed_bytes":
                    path = root / EN_REL
                    path.write_bytes(path.read_bytes() + b"changed\n")
                elif mutation == "wrong_digest":
                    packet["locale_versions"][0]["artifact"]["sha256"] = "0" * 64
                    self.write_packet(root, packet)
                else:
                    packet["locale_versions"][0]["locale"] = "af"
                    self.write_packet(root, packet)
                self.assert_rejected(root, finding)

    def test_unknown_template_token_is_rejected_after_exact_digests_are_recomputed(self):
        temporary, root = self.copy_evidence()
        with temporary:
            packet = self.read_packet(root)
            version = packet["locale_versions"][0]
            artifact_path = root / version["artifact"]["path"]
            raw = artifact_path.read_bytes().replace(b"{{password_reset_link}}", b"{{unknown_link_token}}")
            artifact_path.write_bytes(raw)
            self.refresh_locale_binding(root, packet, version, raw)

            self.write_packet(root, packet)
            self.assert_rejected(root, "unknown or missing template token")

    def test_missing_or_mismatched_owner_decisions_cannot_claim_eligibility(self):
        temporary, root = self.copy_evidence()
        with temporary:
            packet = self.read_packet(root)
            packet["lifecycle"]["state"] = "development_approved"
            packet["eligibility"]["development"] = True
            packet["authorization"]["development_use"]["status"] = "APPROVED"
            self.write_packet(root, packet)
            self.assert_rejected(root, "candidate must remain ineligible")

        temporary, root = self.copy_evidence()
        with temporary:
            packet = self.read_packet(root)
            packet["owner_decisions"].pop()
            self.write_packet(root, packet)
            self.assert_rejected(root, "separate pending Product and locale owner decisions required")

        temporary, root = self.copy_evidence()
        with temporary:
            packet = self.read_packet(root)
            packet["owner_decisions"] = []
            self.write_packet(root, packet)
            self.assert_rejected(root, "separate pending Product and locale owner decisions required")

        temporary, root = self.copy_evidence()
        with temporary:
            packet = self.read_packet(root)
            packet["owner_decisions"][0]["status"] = "approved"
            packet["owner_decisions"][0]["actor_identity"] = None
            self.write_packet(root, packet)
            self.assert_rejected(root, "candidate owner decisions must remain pending")

    def test_conflicting_reuse_of_a_decision_identity_fails_closed(self):
        temporary, root = self.copy_evidence()
        with temporary:
            packet = self.read_packet(root)
            packet["approval_events"] = [
                {"decision_id": "WELL-98-CONTENT-EN-1", "decision": "approve", "sha256": "1" * 64},
                {"decision_id": "WELL-98-CONTENT-EN-1", "decision": "approve", "sha256": "2" * 64},
            ]
            self.write_packet(root, packet)
            self.assert_rejected(root, "candidate cannot contain approval events")

    def test_conflicting_reuse_of_a_content_translation_identity_fails_closed(self):
        temporary, root = self.copy_evidence()
        with temporary:
            packet = self.read_packet(root)
            packet["locale_versions"][1]["id"] = packet["locale_versions"][0]["id"]
            self.write_packet(root, packet)
            self.assert_rejected(root, "content translation version identities must be unique")

    def test_content_owner_decision_with_mismatched_locale_digest_fails_closed(self):
        temporary, root = self.copy_evidence()
        with temporary:
            packet = self.read_packet(root)
            packet["owner_decisions"][1]["subjects"][0]["artifact"]["sha256"] = "0" * 64
            self.write_packet(root, packet)
            self.assert_rejected(root, "Content & Media decision binding mismatch: en")

    def test_stale_owner_decision_identity_cannot_claim_current_approval(self):
        temporary, root = self.copy_evidence()
        with temporary:
            packet = self.read_packet(root)
            packet["owner_decisions"][0]["decision_id"] = "WELL-98-OLD-PRODUCT-DECISION"
            self.write_packet(root, packet)
            self.assert_rejected(root, "candidate owner decisions must remain pending")

    def test_stale_superseded_withdrawn_and_production_metadata_cannot_be_eligible(self):
        for state in ("development_approved", "superseded", "withdrawn"):
            temporary, root = self.copy_evidence()
            with temporary:
                packet = self.read_packet(root)
                packet["lifecycle"]["state"] = state
                packet["eligibility"]["development"] = state == "development_approved"
                packet["eligibility"]["production"] = True
                self.write_packet(root, packet)
                self.assert_rejected(root, "candidate lifecycle state required")

    def test_latest_alias_locale_fallback_and_production_scope_are_rejected(self):
        for mutation in ("latest", "fallback", "production"):
            temporary, root = self.copy_evidence()
            with temporary:
                packet = self.read_packet(root)
                if mutation == "latest":
                    packet["locale_versions"][0]["id"] = "latest"
                elif mutation == "fallback":
                    packet["binding"]["silent_locale_fallback"] = True
                else:
                    packet["scope"]["allowed"].append("production")
                    packet["eligibility"]["production"] = True
                self.write_packet(root, packet)
                self.assert_rejected(root)

    def test_source_artifacts_contain_no_rendered_bearer_url_or_personal_identifier(self):
        packet = self.read_packet(ROOT)
        for version in packet["locale_versions"]:
            raw = (ROOT / version["artifact"]["path"]).read_bytes()
            text = raw.decode("utf-8")
            self.assertNotRegex(text, r"(?i)https?://|www\.|Bearer\s+\S+|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}")
            self.assertNotRegex(text, r"\b(?:account|user)[-_ ]?(?:id|number)\s*[:=]")

    def test_bearer_credentials_and_personal_identifiers_are_rejected_in_source_files(self):
        temporary, root = self.copy_evidence()
        with temporary:
            packet = self.read_packet(root)
            version = packet["locale_versions"][0]
            artifact_path = root / version["artifact"]["path"]
            raw = artifact_path.read_bytes() + (
                b"\npassword=synthetic-secret\n"
                b"Bearer synthetic-bearer\n"
                b"https://example.invalid/reset\n"
                b"user_id=synthetic-user\n"
                b"person@example.invalid\n"
            )
            artifact_path.write_bytes(raw)
            self.refresh_locale_binding(root, packet, version, raw)
            self.write_packet(root, packet)

            result = self.run_checker(root)
            self.assertEqual(1, result.returncode, result.stderr or result.stdout)
            findings = json.loads(result.stdout)["findings"]
            self.assertTrue(any("rendered URL, bearer value or email address" in item for item in findings))
            self.assertTrue(any("credential value in source" in item for item in findings))
            self.assertTrue(any("personal identifier in source" in item for item in findings))

    def test_copy_registry_separates_governed_email_from_jit_recovery_ui(self):
        registry = json.loads((ROOT / REGISTRY_REL).read_text(encoding="utf-8"))
        entries = {entry["key"]: entry for entry in registry["entries"]}
        recovery = entries["identity.recovery.family"]
        self.assertEqual("JIT", recovery["readiness"])
        self.assertFalse(recovery["development_eligible"])
        self.assertEqual(
            "744f1a34ad80c0158c86395f3f66227622714969526f5e9d69ee62314fd48635",
            hashlib.sha256((ROOT / REGISTRY_REL).read_bytes()).hexdigest(),
        )
        self.assertNotIn("identity.password_reset.email.subject", entries)
        self.assertNotIn("identity.password_reset.email.body", entries)


if __name__ == "__main__":
    unittest.main()
