# Paystack TEST card fixtures

The catalogue contains Paystack's ten published synthetic card scenarios. The checkout and refund outcomes describe the provider's test scenarios. [Paystack test payments](https://paystack.com/docs/payments/test-payments/#cards)

## Automated use

Use the fixtures in offline ExUnit tests with local doubles. `all/0` returns a map keyed by scenario ID. `fetch!/1` returns one fixture and raises `KeyError` for an unknown ID.

```elixir
alias NewYou.Commerce.Paystack.TestCards

card = TestCards.fetch!(:refund_needs_attention)
assert card.expected == :success
assert card.expected_refund == :needs_attention
```

## Manual use

Obtain explicit authorization for each external Paystack TEST run before opening or submitting a hosted checkout. Select the scenario from the catalogue or the linked Paystack page. Use the card details only in Paystack's hosted TEST checkout and format the fixture's expiry with `Calendar.strftime(card.expiry, "%m/%y")`. Follow the hosted prompts. Paystack publishes no phone value for the phone challenge.

Paystack hosts card entry and retains card custody. Keep card inputs out of NewYou forms, application requests, logs and storage. The catalogue is compiled only in Mix TEST. Keep it out of production code, configuration and releases. Fixture lookup runs offline and leaves provider configuration and activation to a separately authorized workflow.
