from dataclasses import replace
import unittest

from evidence_gate import FixtureWitness, grade

URL = "https://checkout.paystack.com/synthetic-url"
REF = "synthetic-reference"
ID = 9007199254740993
OBSERVED = {"reference": REF, "domain": "test", "integration": "synthetic-merchant",
            "amount": 10000, "currency": "ZAR", "id": ID, "status": "pending"}
WITNESS = FixtureWitness(True, 1, URL, str(ID))


class EvidenceGateTest(unittest.TestCase):
    def check(self, witness=None, *, after=OBSERVED, **overrides):
        return grade(URL, REF, OBSERVED, after, witness, **({"observed_url": URL} | overrides))

    def test_matching_url_and_verify_records_without_session_witness_stay_inconclusive(self):
        self.assertEqual(self.check(), "INCONCLUSIVE")
        self.assertEqual(self.check({"form": True, "log_delta": True}), "INCONCLUSIVE")

    def test_synthetic_session_witness_and_lossless_verify_match(self):
        self.assertEqual(self.check(WITNESS), "QUALIFIES_IN_FIXTURE")
        for change in ({"reference": "another"}, {"domain": "live"}, {"id": 42}, {"id": float(ID)},
                       {"amount": 10001}, {"currency": "USD"}, {"status": "success"}):
            with self.subTest(change=change):
                self.assertEqual(self.check(WITNESS, after=OBSERVED | change), "STOP")

    def test_stale_or_fabricated_witness_or_budget_breach_stops(self):
        for witness in (replace(WITNESS, from_provider_observation=False),
                        replace(WITNESS, fresh_navigation=0),
                        replace(WITNESS, capability=URL + "x"),
                        replace(WITNESS, provider_id="42")):
            self.assertEqual(self.check(witness), "STOP")
        for override in ({"initialize_posts": 2}, {"verify_reads": 3}, {"navigations": 2},
                         {"denied_requests": 1}, {"payments": 1}, {"cut_after_commit": False}):
            self.assertEqual(self.check(WITNESS, **override), "STOP")
