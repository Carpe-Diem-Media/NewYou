# Test Doubles and Fault Injection — Elixir, Ash and NewYou

## Default: use the actual owner boundary

Do not mock `Ash.Domain`, Ash Resources/actions/policies, the owning application interface, or the database to claim that their business behaviour was tested. Prefer NewYou's existing fixtures and TEST database with proper SQL Sandbox ownership and cleanup.

Use a test double where the system crosses a **genuine external or nondeterministic boundary** and the double allows deterministic proof of the application's own behaviour:

- external delivery/payment/provider adapter response and ambiguous acknowledgement;
- time, randomness or external I/O where the approved existing test seam can be controlled;
- remote process failure when real integration would be unsafe or expensive.

Don't build an extra Service/Manager interface simply for a test double. Prefer existing provider/adapter interfaces or meaningful Elixir behaviours. Never make a provider mock the authority for a business truth.

## Elixir example: simple explicit test double

The following is **illustrative** and not an existing NewYou API. It demonstrates a meaningful external-adapter seam, not a requirement to introduce a new module in the project.

```elixir
# Educational stand-alone example; this is not an existing NewYou API.
# The real boundary here is an external delivery adapter, not an Ash action.
defmodule Example.DeliveryPolicy do
  @spec deliver(map(), (map() -> term())) ::
          {:ok, :accepted} | {:error, atom()}
  def deliver(message, adapter_send) do
    case adapter_send.(message) do
      :ok -> {:ok, :accepted}
      {:error, :temporary_failure} -> {:error, :retry_required}
      {:error, _other} -> {:error, :delivery_unavailable}
    end
  end
end

defmodule Example.DeliveryPolicyTest do
  use ExUnit.Case, async: true

  test "temporary external failure becomes a retry-required application result" do
    # Fake only the external adapter response, not the application policy.
    provider = fn _message -> {:error, :temporary_failure} end

    assert {:error, :retry_required} =
             Example.DeliveryPolicy.deliver(%{kind: :notification}, provider)
  end
end
```

This example proves **application-owned result classification**, not merely that a fake returns the value it was programmed to return. Real NewYou flows must additionally prove their durable retry obligations, idempotency and reconciliation where required. Do not introduce this sample module into the repository.

## Avoid misleading mocks

- A fake that returns `{:ok, id}` without generating the corresponding durable evidence cannot establish that the business operation succeeded.
- A mock of an internal helper can allow tests to pass while actual integration is broken.
- Exact mock call counts are not a substitute for proving idempotency or absence of duplicate durable effects.
- Globally changing `Application` environment or process registration in `async: true` tests risks cross-test interference. Prefer process-local isolation and restore any shared state under controlled synchronous testing.
- A mocked external response cannot by itself prove a database transaction, unique constraint or cross-Domain ownership guarantee.
- Do not install Mox, Hammox or other dependency automatically. Evaluate a new package only if a real adapter/test requirement justifies it under NewYou's current dependency and authority rules.

## Failure-mode proof

For the selected real interface, cover outcomes that matter: accepted, explicitly rejected, transient failure, ambiguous acknowledgement, interrupted operation, replay, restart and reconciliation **only where the actual contract requires them**. Fault injection must be bounded, isolated and reversible. Keep provider credentials out of test output and never reconfigure shared DEV/TEST infrastructure or reset data to achieve a clean run.
