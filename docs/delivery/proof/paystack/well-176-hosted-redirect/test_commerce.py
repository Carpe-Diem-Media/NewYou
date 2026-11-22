"""Tests of the offline state model. All payment evidence is synthetic."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from commerce_model import Commerce

REF = "synthetic-reference"
ID = "9007199254740993"
PAYER = "synthetic-payer"
OTHER = "different-person"

def verify(status="success", **changes):
    return {"reference": REF, "id": ID, "integration": "synthetic-merchant",
            "domain": "test", "amount": 10000, "currency": "ZAR", "status": status} | changes

class CommerceTests(unittest.TestCase):
    def setUp(self):
        temp = TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.path = Path(temp.name) / "commerce.db"
        self.model = Commerce(self.path)
        self.addCleanup(self.model.close)
        self.model.create("purchase", PAYER, "synthetic-merchant", 10000)

    def reserve(self):
        return self.model.reserve("purchase", PAYER, REF, now=100)

    def receipt(self):
        return self.model.retain("purchase", REF, "synthetic-code")

    def restart(self):
        clone = Commerce(self.path)
        self.addCleanup(clone.close)
        return clone

    def test_lost_provider_reply_keeps_original_reference_and_fence(self):
        self.assertTrue(self.reserve())
        restarted = self.restart()
        self.assertEqual(restarted.view("purchase", PAYER), ("checking_payment", None))
        self.assertFalse(restarted.reserve("purchase", PAYER, "replacement", now=9999))
        self.assertEqual(restarted.reconcile("purchase", verify(), authenticated=True), "paid")
        self.assertEqual(restarted.view("purchase", PAYER), ("paid", None))

    def test_durable_receipt_survives_participant_loss_and_restart(self):
        self.assertTrue(self.reserve())
        self.assertTrue(self.receipt())
        restarted = self.restart()
        self.assertEqual(restarted.view("purchase", PAYER), ("checking_payment", None))
        self.assertEqual(restarted.view("purchase", OTHER, resume_enabled=True), ("unavailable", None))
        self.assertEqual(restarted.view("purchase", PAYER, resume_enabled=True),
                         ("resume_original", "synthetic-code"))
        self.assertFalse(restarted.reserve("purchase", PAYER, "replacement", now=101))

    def test_concurrent_reservations_allow_one_mutation_dispatch(self):
        def reserve(index):
            instance = Commerce(self.path)
            try:
                return instance.reserve("purchase", PAYER, f"ref-{index}", now=100)
            finally:
                instance.close()
        with ThreadPoolExecutor(max_workers=8) as pool:
            self.assertEqual(sum(pool.map(reserve, range(16))), 1)

    def test_receipt_cannot_replace_original_identity_or_rebind_a_capability(self):
        self.assertTrue(self.reserve())
        self.assertFalse(self.model.retain("purchase", "wrong-reference", "wrong-code"))
        self.assertTrue(self.receipt())
        self.assertFalse(self.model.retain("purchase", REF, "wrong-code"))
        self.assertEqual(self.model.view("purchase", PAYER, resume_enabled=True),
                         ("resume_original", "synthetic-code"))

    def test_reconciliation_binds_only_authorized_reference_price_and_integration(self):
        self.reserve()
        self.assertEqual(self.model.reconcile("purchase", verify(), authenticated=False), "ignored")
        for changes in ({"reference":"wrong"}, {"domain":"live"}, {"amount":10001},
                        {"integration":"other-merchant"}, {"currency":"USD"}, {"id":True}):
            self.assertEqual(self.model.reconcile("purchase", verify(**changes), authenticated=True),
                             "mismatch")
        self.assertEqual(self.model.reconcile("purchase", verify("pending"), authenticated=True),
                         "unresolved")
        self.assertEqual(self.model.reconcile("purchase", verify(id="42"), authenticated=True), "mismatch")
        self.assertEqual(self.model.reconcile("purchase", verify(), authenticated=True), "paid")

    def test_bounded_retries_reach_one_operator_case_and_durable_backstop(self):
        self.reserve()
        for now in (100, 101, 105, 109, 115):
            self.model.reconcile("purchase", None, authenticated=True, now=now)
        restarted = self.restart()
        self.assertEqual(restarted.work("purchase"), (1, 175))
        self.assertEqual(restarted.view("purchase", PAYER), ("payment_review", None))
        self.assertFalse(restarted.reserve("purchase", PAYER, "replacement", now=175))
        self.assertEqual(restarted.reconcile("purchase", verify(), authenticated=True, now=175), "paid")

    def test_positive_terminal_observations_do_not_release_the_payment_fence(self):
        self.reserve()
        self.receipt()
        for status in ("abandoned", "expired", "failed", "timeout", "not_found"):
            self.model.reconcile("purchase", verify(status), authenticated=True)
            self.assertFalse(self.model.reserve("purchase", PAYER, "replacement", now=9999))
            self.assertEqual(self.model.work("purchase")[0], 0)
        self.assertEqual(self.model.reconcile("purchase", verify(), authenticated=True), "paid")

    def test_entitlement_delivery_retry_is_idempotent_after_ack_loss(self):
        self.reserve()
        self.model.reconcile("purchase", verify(), authenticated=True)
        self.assertEqual(self.model.outbox(), ["purchase"])
        self.assertTrue(self.model.entitle("purchase"))
        restarted = self.restart()
        self.assertEqual(restarted.outbox(), ["purchase"])
        self.assertFalse(restarted.entitle("purchase"))
        self.assertTrue(restarted.ack("purchase"))
        self.assertEqual(restarted.outbox(), [])
        self.assertEqual(restarted.reconcile("purchase", verify("abandoned"), authenticated=True),
                         "already_paid")
        self.assertEqual(restarted.reconcile("purchase", verify(), authenticated=True), "already_paid")

    def test_reversal_before_entitlement_preserves_evidence_and_fails_closed(self):
        self.reserve()
        self.model.reconcile("purchase", verify(), authenticated=True)
        self.assertEqual(self.model.reconcile("purchase", verify("reversed"), authenticated=True),
                         "reversal_review")
        self.assertFalse(self.model.entitle("purchase"))
        self.assertEqual(self.model.reconcile("purchase", verify(), authenticated=True),
                         "reversal_review")
        self.assertFalse(self.model.reserve("purchase", PAYER, "replacement", now=9999))
