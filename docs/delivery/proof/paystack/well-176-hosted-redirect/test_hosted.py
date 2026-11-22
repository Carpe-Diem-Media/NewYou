"""Synthetic HTTP transport only. The stored HTTPS checkout URL is never visited."""
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from threading import Thread
import unittest

from commerce_model import Commerce
from hosted_redirect import Hosted

PAYER = "synthetic-payer"
REFERENCE = "newyou-synthetic-reference"
CODE = "synthetic-code"
URL = "https://checkout.paystack.com/synthetic-path"
HEADERS = {"X-Fixture-Payer": PAYER}


@contextmanager
def serve(handler):
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    thread = Thread(target=server.serve_forever, kwargs={"poll_interval": .01}, daemon=True)
    thread.start()
    try:
        yield server.server_port
    finally:
        server.shutdown()
        thread.join()
        server.server_close()


def request(port, method, path, headers=None, body=None):
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=2)
    try:
        conn.request(method, path, body=body, headers=headers or {})
        reply = conn.getresponse()
        return reply.status, dict(reply.getheaders()), reply.read()
    finally:
        conn.close()


class HostedTest(unittest.TestCase):
    def setUp(self):
        temp = TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.db = Path(temp.name) / "commerce.sqlite"
        self.calls = []
        self.paystack_reply = {"status": True, "data": {
            "reference": REFERENCE, "authorization_url": URL, "access_code": CODE,
        }}
        self.cut_provider_reply = False
        self.cut_participant_reply = False
        self.resume_approved = True
        self.model = Commerce(self.db)
        self.addCleanup(self.model.close)
        self.model.create("purchase", PAYER, "synthetic-merchant", 10000)
        self.provider_port = self.enterContext(serve(self.provider_handler()))
        self.port = self.enterContext(serve(self.merchant_handler()))

    def provider_handler(self):
        fixture = self
        class Provider(BaseHTTPRequestHandler):
            def do_POST(self):
                payload = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                fixture.calls.append((self.command, self.path, payload))
                if fixture.cut_provider_reply:
                    # Paystack's synthetic receipt exists. The merchant sees EOF.
                    self.close_connection = True
                    return
                response = json.dumps(fixture.paystack_reply).encode()
                self.send_response(200)
                self.end_headers()
                self.wfile.write(response)

            def log_message(self, *_):
                pass
        return Provider

    def merchant_handler(self):
        fixture = self

        class Merchant(BaseHTTPRequestHandler):
            def do_POST(self):
                # Fixture headers stand in for authenticated sessions and a CSRF check.
                payer = self.headers.get("X-Fixture-Payer")
                ledger = Commerce(fixture.db)
                try:
                    hosted = Hosted(ledger)
                    if self.path == "/start":
                        status, headers = hosted.start("purchase", payer, REFERENCE, 100,
                                                       fixture.initialize)
                    elif self.path == "/resume":
                        status, headers = hosted.resume("purchase", payer,
                                                        approved=fixture.resume_approved)
                    else:
                        status, headers = 404, {}
                finally:
                    ledger.close()
                if fixture.cut_participant_reply and self.path == "/start":
                    self.close_connection = True
                    return
                self.send_response(status)
                for key, value in headers.items():
                    self.send_header(key, value)
                self.end_headers()

            def log_message(self, *_):
                pass
        return Merchant

    def initialize(self, payload):
        status, _, response = request(self.provider_port, "POST", "/transaction/initialize",
                                      {"Content-Type": "application/json"}, json.dumps(payload))
        if status != 200:
            raise ConnectionError("fixture provider refused initialize")
        return json.loads(response)

    def post(self, path, headers=HEADERS):
        return request(self.port, "POST", path, headers)

    def test_initial_redirect_is_exact_and_noncacheable(self):
        status, headers, _ = self.post("/start")
        self.assertEqual(status, 303)
        self.assertEqual(headers["Location"], URL)
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertEqual(headers["Referrer-Policy"], "no-referrer")
        self.assertNotIn(CODE, json.dumps(headers))
        self.assertEqual(self.calls, [("POST", "/transaction/initialize", {
            "reference": REFERENCE, "amount": 10000, "currency": "ZAR", "channels": ["card"],
        })])

    def test_lost_participant_reply_restart_and_resume_reuse_retained_url(self):
        self.cut_participant_reply = True
        with self.assertRaises(http.client.RemoteDisconnected):
            self.post("/start")
        restarted = Commerce(self.db)
        self.addCleanup(restarted.close)
        self.assertEqual(restarted.find("purchase")["authorization_url"], URL)
        self.assertEqual(restarted.find("purchase")["code"], CODE)
        status, headers, _ = self.post("/resume")
        self.assertEqual((status, headers["Location"]), (303, URL))
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(restarted.outbox(), [])

    def test_lost_upstream_reply_preserves_reference_and_can_reconcile_late_success(self):
        self.cut_provider_reply = True
        self.assertEqual(self.post("/start")[0], 202)
        self.assertEqual(self.post("/start")[0], 202)
        self.assertNotIn("Location", self.post("/resume")[1])
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(self.model.find("purchase")["reference"], REFERENCE)
        self.assertEqual(self.model.reconcile("purchase", self.verified(), authenticated=True), "paid")

    def test_only_payer_can_admit_or_reopen(self):
        self.assertEqual(self.post("/start", {"X-Fixture-Payer": "other"})[0], 404)
        self.assertEqual(self.calls, [])
        self.assertEqual(self.post("/start")[0], 303)
        self.assertEqual(self.post("/resume", {"X-Fixture-Payer": "other"})[0], 404)
        self.resume_approved = False
        self.assertNotIn("Location", self.post("/resume")[1])

    def test_concurrent_start_emits_one_initialize(self):
        with ThreadPoolExecutor(max_workers=8) as pool:
            statuses = list(pool.map(lambda _: self.post("/start")[0], range(12)))
        self.assertEqual(statuses.count(303), 1)
        self.assertEqual(statuses.count(202), 11)
        self.assertEqual(len(self.calls), 1)

    def test_mismatched_receipt_is_quarantined(self):
        self.paystack_reply["data"]["reference"] = "another-reference"
        self.assertEqual(self.post("/start")[0], 202)
        self.assertIsNone(self.model.find("purchase")["authorization_url"])
        self.assertEqual(self.post("/start")[0], 202)
        self.assertEqual(len(self.calls), 1)

    def test_untrusted_destination_spellings_are_rejected(self):
        from hosted_redirect import valid_checkout_url
        for url in ("http://checkout.paystack.com/abc", "https://checkout.paystack.com@evil.invalid/abc",
                    "https://checkout.paystack.com.evil.invalid/a", "https://checkout.paystack.com:443/a",
                    "https://checkout.paystack.com/%2f%2fevil", "https://checkout.paystack.com/../other",
                    "https://checkout.paystack.com/a?next=evil", "https://checkout.paystack.com/abc\r\nHeader: test",
                    "https://checkout.paystack.com/abc#fragment"):
            with self.subTest(url=url):
                self.assertFalse(valid_checkout_url(url))

    def verified(self, status="success", **changes):
        return {"reference": REFERENCE, "id": 9007199254740993, "integration": "synthetic-merchant",
                "domain": "test", "amount": 10000, "currency": "ZAR", "status": status} | changes

    def test_browser_return_and_duplicate_webhook_are_triggers_only(self):
        self.post("/start")
        hosted = Hosted(self.model)
        self.assertFalse(hosted.browser_return("purchase", "other", REFERENCE))
        self.assertFalse(hosted.browser_return("purchase", PAYER, "mismatch"))
        self.assertTrue(hosted.browser_return("purchase", PAYER, REFERENCE))
        self.assertFalse(hosted.webhook_hint(REFERENCE, "synthetic-event", authenticated=False))
        self.assertTrue(hosted.webhook_hint(REFERENCE, "synthetic-event", authenticated=True))
        self.assertFalse(hosted.webhook_hint(REFERENCE, "synthetic-event", authenticated=True))
        self.assertEqual(self.model.outbox(), [])
        self.assertEqual(self.model.reconcile("purchase", self.verified(), authenticated=True), "paid")
        self.assertEqual(self.model.reconcile("purchase", self.verified(), authenticated=True), "already_paid")
        self.assertTrue(self.model.entitle("purchase"))
        self.assertFalse(self.model.entitle("purchase"))
        self.assertNotIn("Location", self.post("/resume")[1])

    def test_persisted_poll_recovers_without_webhook_or_callback(self):
        self.post("/start")
        for now in (100, 105, 110, 170):
            self.model.reconcile("purchase", None, authenticated=True, now=now)
        restarted = Commerce(self.db)
        self.addCleanup(restarted.close)
        self.assertEqual(restarted.work("purchase"), (1, 230))
        self.assertEqual(self.post("/resume")[0], 202)
        self.assertEqual(restarted.reconcile("purchase", self.verified(), authenticated=True, now=230), "paid")

    def test_expired_or_abandoned_attempt_does_not_admit_replacement(self):
        self.post("/start")
        for outcome in ("expired", "abandoned", "failed", "pending"):
            self.assertEqual(len(self.calls), 1)
            self.assertEqual(self.model.reconcile("purchase", self.verified(outcome), authenticated=True), "unresolved")
            self.assertFalse(self.model.reserve("purchase", PAYER, "forbidden-replacement", now=10000))
            self.assertNotIn("Location", self.post("/resume")[1])
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(self.model.reconcile("purchase", self.verified(), authenticated=True), "paid")
