from pathlib import Path
import unittest


class Phase8ProofWorkflowTest(unittest.TestCase):
    def test_proof_runner_migrates_fresh_database_before_application_start(self):
        workflow = (Path(__file__).resolve().parents[1] / ".github/workflows/phase8-proof.yml").read_text()
        proof_step = workflow.split("      - name: Run selected proof mode\n", 1)[1].split(
            "      - name: Upload proof result\n", 1
        )[0]
        self.assertIn("TEST_DATABASE_HOST:", proof_step)
        self.assertIn("TEST_DATABASE_NAME:", proof_step)
        self.assertIn("mix ecto.migrate --quiet", proof_step)
        self.assertLess(
            proof_step.index("mix ecto.migrate --quiet"),
            proof_step.index("mix run test/proof/run.exs"),
        )


if __name__ == "__main__":
    unittest.main()
