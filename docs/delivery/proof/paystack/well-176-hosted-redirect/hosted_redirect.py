"""Provider-neutral control flow, exercised only with a synthetic loopback adapter."""
import http.client
import re

CHECKOUT = re.compile(r"https://checkout[.]paystack[.]com/[A-Za-z0-9_-]{1,256}")
PRIVATE_HEADERS = {"Cache-Control": "no-store", "Referrer-Policy": "no-referrer"}


def valid_checkout_url(value):
    # The proof deliberately admits only an exact ASCII HTTPS host and one opaque
    # token path. A wider form needs provider evidence. Never normalize the stored URL.
    return isinstance(value, str) and CHECKOUT.fullmatch(value) is not None


def redirect(url):
    return 303, PRIVATE_HEADERS | {"Location": url}


class Hosted:
    def __init__(self, ledger):
        self.ledger = ledger

    def owned(self, intent, payer):
        row = self.ledger.find(intent)
        if payer and row is not None and row["payer"] == payer:
            return row

    def start(self, intent, payer, reference, now, send_initialize):
        row = self.owned(intent, payer)
        if row is None:
            return 404, PRIVATE_HEADERS
        if not self.ledger.reserve(intent, payer, reference, now):
            return 202, PRIVATE_HEADERS
        payload = {"reference": reference, "amount": row["amount"], "currency": "ZAR", "channels": ["card"]}
        try:
            reply = send_initialize(payload)
        except (OSError, http.client.HTTPException, ValueError):
            return 202, PRIVATE_HEADERS
        data = reply.get("data") if isinstance(reply, dict) and reply.get("status") is True else None
        if not isinstance(data, dict):
            return 202, PRIVATE_HEADERS
        url = data.get("authorization_url")
        if not valid_checkout_url(url):
            return 202, PRIVATE_HEADERS
        if not self.ledger.retain(intent, data.get("reference"), data.get("access_code"), url):
            return 202, PRIVATE_HEADERS
        return redirect(url)

    def resume(self, intent, payer, *, approved):
        row = self.owned(intent, payer)
        if row is None:
            return 404, PRIVATE_HEADERS
        state, _ = self.ledger.view(intent, payer, resume_enabled=approved)
        if state == "resume_original" and valid_checkout_url(row["authorization_url"]):
            return redirect(row["authorization_url"])
        return 202, PRIVATE_HEADERS

    def browser_return(self, intent, payer, observed_reference):
        row = self.owned(intent, payer)
        if row is None or not observed_reference or row["reference"] != observed_reference:
            return False
        self.ledger.wake(intent)
        return True

    def webhook_hint(self, reference, event_id, *, authenticated):
        # The bool represents an already-authenticated ingress. There is no
        # real Paystack signature implementation or provider call in this proof.
        return bool(authenticated and reference and event_id and self.ledger.webhook_hint(reference, event_id))
