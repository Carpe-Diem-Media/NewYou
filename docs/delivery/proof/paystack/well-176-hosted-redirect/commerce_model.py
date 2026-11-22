"""Offline SQLite state model. It cannot contact Paystack or grant real access."""
from contextlib import contextmanager
import re
import sqlite3

UINT64_MAX = (1 << 64) - 1


def bind_id(value):
    if type(value) is str and re.fullmatch(r"[1-9][0-9]{0,19}", value):
        value = int(value)
    if type(value) is int and 0 < value <= UINT64_MAX:
        return str(value)


class Commerce:
    def __init__(self, path):
        self.db = sqlite3.connect(path, isolation_level=None, timeout=4)
        self.db.row_factory = sqlite3.Row
        self.db.executescript("""
          CREATE TABLE IF NOT EXISTS purchases (
            intent TEXT PRIMARY KEY,
            payer TEXT NOT NULL,
            integration TEXT NOT NULL,
            amount INTEGER NOT NULL CHECK (amount > 0),
            state TEXT NOT NULL DEFAULT 'unstarted',
            reference TEXT UNIQUE,
            code TEXT,
            authorization_url TEXT,
            resume_suppressed INTEGER NOT NULL DEFAULT 0,
            provider_id TEXT,
            review_after INTEGER,
            due INTEGER
          );
          CREATE TABLE IF NOT EXISTS reviews (
            intent TEXT PRIMARY KEY
          );
          CREATE TABLE IF NOT EXISTS webhook_hints (
            event_id TEXT PRIMARY KEY,
            intent TEXT NOT NULL
          );
          CREATE TABLE IF NOT EXISTS outbox (
            intent TEXT PRIMARY KEY,
            acknowledged INTEGER NOT NULL DEFAULT 0
          );
          CREATE TABLE IF NOT EXISTS entitlement_effect (
            intent TEXT PRIMARY KEY
          );
        """)

    def close(self):
        self.db.close()

    @contextmanager
    def transaction(self):
        self.db.execute("BEGIN IMMEDIATE")
        try:
            yield
        except BaseException:
            self.db.rollback()
            raise
        else:
            self.db.commit()

    def create(self, intent, payer, integration, amount):
        self.db.execute("INSERT INTO purchases (intent, payer, integration, amount) VALUES (?, ?, ?, ?)",
                        (intent, payer, integration, amount))

    def find(self, intent):
        return self.db.execute("SELECT * FROM purchases WHERE intent = ?", (intent,)).fetchone()

    def reserve(self, intent, payer, reference, now):
        # The dispatcher may only send after this single update committed.
        # A crash after reservation conservatively keeps the fence.
        with self.transaction():
            return self.db.execute("""
                UPDATE purchases SET state = 'unresolved', reference = ?, review_after = ?, due = ?
                WHERE intent = ? AND payer = ? AND state = 'unstarted'
            """, (reference, now + 10, now, intent, payer)).rowcount == 1

    def retain(self, intent, reference, code, authorization_url=None):
        # Caller is the authenticated response-journal boundary in this model.
        # It writes before serving the participant. It cannot replace a retained code.
        if not isinstance(code, str) or not code:
            return False
        with self.transaction():
            return self.db.execute("""
                UPDATE purchases SET code = ?, authorization_url = ?
                WHERE intent = ? AND state = 'unresolved' AND reference = ? AND code IS NULL
            """, (code, authorization_url, intent, reference)).rowcount == 1

    def view(self, intent, payer, *, resume_enabled=False):
        row = self.find(intent)
        if row is None or row["payer"] != payer:
            return "unavailable", None
        if row["state"] == "paid":
            return "paid", None
        if row["state"] == "reversal_review" or self.work(intent)[0]:
            return "payment_review", None
        if row["state"] == "unresolved" and row["code"] and resume_enabled and not row["resume_suppressed"]:
            return "resume_original", row["code"]
        return "checking_payment", None

    def schedule(self, row, now):
        if now is None or row["state"] != "unresolved" or now < row["due"]:
            return
        if now >= row["review_after"]:
            self.db.execute("INSERT OR IGNORE INTO reviews VALUES (?)", (row["intent"],))
            delay = 60
        else:
            delay = 5
        self.db.execute("UPDATE purchases SET due = ? WHERE intent = ?",
                        (now + delay, row["intent"]))

    def reconcile(self, intent, observation, *, authenticated, now=None):
        with self.transaction():
            row = self.find(intent)
            if not authenticated or row is None or row["reference"] is None:
                return "ignored"
            if observation is None:
                self.schedule(row, now)
                return "unresolved"
            provider_id = bind_id(observation.get("id"))
            if (not provider_id or row["provider_id"] not in (None, provider_id)
                    or observation.get("reference") != row["reference"]
                    or observation.get("integration") != row["integration"]
                    or observation.get("domain") != "test" or observation.get("currency") != "ZAR"
                    or type(observation.get("amount")) is not int
                    or observation["amount"] != row["amount"]):
                return "mismatch"
            self.db.execute("UPDATE purchases SET provider_id = ? WHERE intent = ?", (provider_id, intent))
            status = observation.get("status")
            if status == "reversed" or row["state"] == "reversal_review":
                self.db.execute("UPDATE purchases SET state = 'reversal_review', due = NULL WHERE intent = ?", (intent,))
                self.db.execute("INSERT OR IGNORE INTO reviews VALUES (?)", (intent,))
                return "reversal_review"
            if row["state"] == "paid":
                return "already_paid"
            if status == "success":
                self.db.execute("UPDATE purchases SET state = 'paid', due = NULL WHERE intent = ?", (intent,))
                self.db.execute("INSERT INTO outbox (intent) VALUES (?)", (intent,))
                return "paid"
            if status == "expired":
                # Suppress presentation without asserting final financial status.
                self.db.execute("UPDATE purchases SET resume_suppressed = 1 WHERE intent = ?", (intent,))
            self.schedule(row, now)
            return "unresolved"

    def wake(self, intent):
        self.db.execute("UPDATE purchases SET due = 0 WHERE intent = ? AND state = 'unresolved'", (intent,))

    def webhook_hint(self, reference, event_id):
        with self.transaction():
            row = self.db.execute("SELECT intent FROM purchases WHERE reference = ?", (reference,)).fetchone()
            if row is None:
                return False
            inserted = self.db.execute("INSERT OR IGNORE INTO webhook_hints VALUES (?, ?)",
                                       (event_id, row["intent"])).rowcount == 1
            if inserted:
                self.wake(row["intent"])
            return inserted

    def work(self, intent):
        cases = self.db.execute("SELECT count(*) FROM reviews WHERE intent = ?", (intent,)).fetchone()[0]
        return cases, self.find(intent)["due"]

    def outbox(self):
        return [row[0] for row in self.db.execute("""
            SELECT outbox.intent FROM outbox JOIN purchases USING (intent)
            WHERE acknowledged = 0 AND state = 'paid' ORDER BY outbox.intent
        """)]

    def entitle(self, intent):
        # A stand-in for Entitlements' separately idempotent governed write.
        with self.transaction():
            return self.db.execute("""
                INSERT OR IGNORE INTO entitlement_effect SELECT intent FROM purchases
                WHERE intent = ? AND state = 'paid'
            """, (intent,)).rowcount == 1

    def ack(self, intent):
        with self.transaction():
            return self.db.execute("""
                UPDATE outbox SET acknowledged = 1 WHERE intent = ? AND acknowledged = 0
                AND EXISTS (SELECT 1 FROM entitlement_effect WHERE intent = ?)
            """, (intent, intent)).rowcount == 1
