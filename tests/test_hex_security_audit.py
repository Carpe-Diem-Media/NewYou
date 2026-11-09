"""Security boundary tests for the fresh, unsuppressed Hex audit."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools import hex_security_audit as audit

ROOT = Path(__file__).resolve().parents[1]


def report(results=None, rules=None):
    return {
        "version": "2.1.0",
        "runs": [{
            "tool": {"driver": {
                "name": "mix hex.audit",
                "version": audit.HEX_VERSION,
                "rules": [] if rules is None else rules,
            }},
            "results": [] if results is None else results,
        }],
    }


def finding(advisory="EEF-CVE-2026-117656", suppressions=None):
    result = {
        "ruleId": advisory,
        "ruleIndex": 0,
        "message": {"text": "security finding"},
    }
    if suppressions is not None:
        result["suppressions"] = suppressions
    return result


class AuditEvidenceTests(unittest.TestCase):
    def test_clean_unsuppressed_report_passes(self):
        self.assertIn("CLEAN", audit.disposition(report(), 0))

    def test_every_advisory_or_retirement_finding_fails(self):
        evidence = report(
            results=[finding()],
            rules=[{"id": "EEF-CVE-2026-117656"}],
        )
        with self.assertRaisesRegex(audit.AuditError, "EEF-CVE-2026-117656"):
            audit.disposition(evidence, 1)

    def test_suppressed_findings_are_never_accepted(self):
        evidence = report(results=[finding(suppressions=[{"kind": "external"}])])
        with self.assertRaisesRegex(audit.AuditError, "suppression"):
            audit.disposition(evidence, 1)

    def test_status_must_match_report(self):
        for evidence, status in [
            (report(), 1),
            (report(results=[finding()]), 0),
            ({}, 0),
            ({"version": "2.1.0", "runs": []}, 0),
        ]:
            with self.subTest(status=status), self.assertRaises(audit.AuditError):
                audit.disposition(evidence, status)

    def test_locked_graph_contains_rc17_and_patched_assent(self):
        deps = audit.locked_dependencies((ROOT / "mix.lock").read_text())
        self.assertIn('{:ash_authentication, "== 5.0.0-rc.17"', deps)
        self.assertIn('{:assent, "== 0.3.2"', deps)

    def test_old_exception_binding_is_removed_from_audit(self):
        record = json.loads((ROOT / "tools/hex_audit/assent_exception.json").read_text())
        self.assertEqual(record["state"], "retirement_approved")
        self.assertEqual(record["owner_approval"]["approver"], "JC")
        self.assertEqual(record["owner_approval"]["plane_identity"], "jcschoeman123")
        self.assertEqual(record["owner_approval"]["github_identity"], "JCSchoeman96")
        self.assertEqual(
            record["owner_approval"]["decision_comment"],
            "WELL-91:feab6ecf-0a09-4b9c-8240-0d055e700075",
        )
        self.assertEqual(record["approved_candidate"]["ash_authentication"], "5.0.0-rc.17")
        self.assertEqual(record["approved_candidate"]["assent"], "0.3.2")
        self.assertEqual(
            record["approved_candidate"]["base_sha"],
            "f9bf634de80c95d39597e27100f98325356da705",
        )
        self.assertEqual(
            record["approved_candidate"]["approved_head_sha"],
            "2376dda3a530f31b99d633f9061df0ece2d6977b",
        )
        self.assertTrue(record["requires_independent_master_gate"])
        self.assertNotIn("input_digest", record)
        source = (ROOT / "tools/hex_security_audit.py").read_text()
        self.assertNotIn("APPROVED_INPUT_DIGEST", source)
        self.assertNotIn("CONTROLLED DISPOSITION", source)
        self.assertNotIn("assent_exception.json", source)

    def test_runner_uses_a_fresh_home_and_locked_resolution(self):
        calls = []

        def run(command, **kwargs):
            calls.append((command, kwargs))
            if "hex.audit" in command:
                (Path(kwargs["cwd"]) / "audit.sarif").write_text(json.dumps(report()))
            return type("Result", (), {"returncode": 0})()

        with patch.object(audit.subprocess, "run", side_effect=run):
            self.assertIn("CLEAN", audit.execute(ROOT))

        self.assertEqual([call[0][1] for call in calls], ["local.hex", "deps.get", "hex.audit"])
        self.assertIn("--check-locked", calls[1][0])
        self.assertTrue(all(call[1]["cwd"] != str(ROOT) for call in calls))
        self.assertTrue(all(call[1]["env"]["HEX_HOME"] != str(Path.home() / ".hex") for call in calls))
        self.assertNotIn("HEX_IGNORE_ADVISORIES", calls[-1][1]["env"])
        self.assertEqual(calls[-1][1]["env"]["MIX_ENV"], "prod")

    def test_runner_fails_for_any_findings(self):
        calls = []

        def run(command, **kwargs):
            calls.append(command)
            if "hex.audit" in command:
                (Path(kwargs["cwd"]) / "audit.sarif").write_text(
                    json.dumps(report(results=[finding()], rules=[{"id": "EEF-CVE-2026-117656"}]))
                )
                return type("Result", (), {"returncode": 1})()
            return type("Result", (), {"returncode": 0})()

        with patch.object(audit.subprocess, "run", side_effect=run):
            with self.assertRaisesRegex(audit.AuditError, "EEF-CVE-2026-117656"):
                audit.execute(ROOT)

    def test_missing_or_malformed_report_fails(self):
        with patch.object(
            audit.subprocess,
            "run",
            return_value=type("Result", (), {"returncode": 0})(),
        ):
            with self.assertRaisesRegex(audit.AuditError, "evidence"):
                audit.execute(ROOT)

        def malformed(command, **kwargs):
            if "hex.audit" in command:
                (Path(kwargs["cwd"]) / "audit.sarif").write_text("not JSON")
            return type("Result", (), {"returncode": 0})()

        with patch.object(audit.subprocess, "run", side_effect=malformed):
            with self.assertRaises(json.JSONDecodeError):
                audit.execute(ROOT)

    def test_runner_fails_if_lock_changes_during_resolution(self):
        def run(command, **kwargs):
            if command[1] == "deps.get":
                lock = Path(kwargs["cwd"]) / "mix.lock"
                lock.write_text(lock.read_text() + "\n")
            if "hex.audit" in command:
                (Path(kwargs["cwd"]) / "audit.sarif").write_text(json.dumps(report()))
            return type("Result", (), {"returncode": 0})()

        with patch.object(audit.subprocess, "run", side_effect=run):
            with self.assertRaisesRegex(audit.AuditError, "lock changed"):
                audit.execute(ROOT)


class AuditRoutingTests(unittest.TestCase):
    def test_security_sensitive_paths_select_the_audit(self):
        from tools.foundation_integrity_routing import classify_hex_audit_changes

        for path in [
            "mix.exs",
            "mix.lock",
            ".tool-versions",
            "lib/new_caller.ex",
            "config/runtime.exs",
            "tools/hex_security_audit.py",
            "tools/hex_audit/assent_exception.json",
            ".github/workflows/hex-security-audit.yml",
            ".github/workflows/foundation-integrity.yml",
            "tools/foundation_integrity_routing.py",
            "tests/test_hex_security_audit.py",
            "tests/test_foundation_merge_gate.py",
        ]:
            with self.subTest(path=path):
                self.assertTrue(classify_hex_audit_changes([path]))

        self.assertFalse(classify_hex_audit_changes(["docs/development/ordinary.md"]))
        self.assertTrue(classify_hex_audit_changes([]))

    def test_nightly_main_and_required_aggregate(self):
        workflow = (ROOT / ".github/workflows/hex-security-audit.yml").read_text()
        self.assertIn("  schedule:", workflow)
        self.assertIn("github.ref == 'refs/heads/main'", workflow)
        self.assertIn("github.event_name == 'schedule' && 'main' || github.sha", workflow)
        self.assertIn("python3 tools/hex_security_audit.py", workflow)
        self.assertNotIn("actions/cache", workflow)
        self.assertNotIn("continue-on-error", workflow)

        integrity = (ROOT / ".github/workflows/foundation-integrity.yml").read_text()
        self.assertIn("needs: [route, foundation-smoke, application-ci, hex-security-audit]", integrity)
        self.assertIn("AUDIT_RESULT: ${{ needs.hex-security-audit.result }}", integrity)
        self.assertIn("AUDIT_REQUIRED: ${{ needs.route.outputs.hex_audit_changes }}", integrity)


class AggregateExecutionTests(unittest.TestCase):
    def test_required_gate_fails_closed_for_audit_outcomes(self):
        import os
        import subprocess

        workflow = (ROOT / ".github/workflows/foundation-integrity.yml").read_text()
        block = workflow.split("  foundation-integrity:\n", 1)[1].split("        run: |\n", 1)[1]
        script = "\n".join(line[10:] for line in block.splitlines())

        for required, result, success in [
            ("true", "success", True),
            ("true", "failure", False),
            ("true", "skipped", False),
            ("true", "cancelled", False),
            ("false", "skipped", True),
            ("false", "success", False),
            ("", "success", False),
            ("garbage", "success", False),
        ]:
            env = dict(
                os.environ,
                ROUTE_RESULT="success",
                SMOKE_RESULT="success",
                APP_REQUIRED="false",
                APP_RESULT="skipped",
                AUDIT_REQUIRED=required,
                AUDIT_RESULT=result,
            )
            actual = subprocess.run(["bash", "-c", script], env=env, capture_output=True)
            with self.subTest(required=required, result=result):
                self.assertEqual(actual.returncode == 0, success, actual.stdout)


if __name__ == "__main__":
    unittest.main()
