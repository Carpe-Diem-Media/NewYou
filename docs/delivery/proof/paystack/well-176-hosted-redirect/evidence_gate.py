"""Synthetic EV-001B predicate model. There is no real provider witness decoder."""
from dataclasses import dataclass

from commerce_model import bind_id
from hosted_redirect import valid_checkout_url


@dataclass(frozen=True)
class FixtureWitness:
    # The fixture controls this flag. Live admission would require independent
    # evidence of the Paystack-issued mechanism and its fresh navigation linkage.
    from_provider_observation: bool
    fresh_navigation: int
    capability: str
    provider_id: str


def grade(retained_url, reference, before, after, witness, *, observed_url,
          cut_after_commit=True, initialize_posts=1, verify_reads=2,
          navigations=1, denied_requests=0, payments=0):
    if (not cut_after_commit or not valid_checkout_url(retained_url)
            or observed_url != retained_url
            or (initialize_posts, verify_reads, navigations, denied_requests, payments) != (1, 2, 1, 0, 0)):
        return "STOP"

    expected_id = bind_id(before.get("id"))
    for row in (before, after):
        if (not expected_id or bind_id(row.get("id")) != expected_id
                or row.get("reference") != reference or row.get("domain") != "test"
                or row.get("integration") != "synthetic-merchant"
                or row.get("currency") != "ZAR" or type(row.get("amount")) is not int
                or row.get("amount") != 10000 or row.get("status") not in ("pending", "abandoned")):
            return "STOP"

    if not isinstance(witness, FixtureWitness):
        return "INCONCLUSIVE"
    if (not witness.from_provider_observation or witness.fresh_navigation != 1
            or witness.capability != retained_url or bind_id(witness.provider_id) != expected_id):
        return "STOP"
    return "QUALIFIES_IN_FIXTURE"
