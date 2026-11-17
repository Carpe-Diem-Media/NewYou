# ExUnit and Ash: Good and Bad Tests for NewYou

These examples are educational; use current code and contract signatures, not a pasted fixture with assumed behaviour. The Identity example mirrors an **existing test** in `test/new_you/identity/password_session_test.exs`; do not add a duplicate test just because it appears here.

## GOOD: real Domain boundary, rejected path, and permitted control

```elixir
defmodule NewYou.Identity.AuthenticationBoundaryExampleTest do
  use ExUnit.Case, async: false

  alias NewYou.Identity
  alias NewYou.Proof.P805

  test "verification is required before password sign-in" do
    P805.with_fixture(fn ->
      request = P805.request()
      assert {:ok, registration} = Identity.register(request)

      # Rejection is meaningful: the account exists, and the password is valid.
      assert {:error, :authentication_unavailable} =
               Identity.authenticate_password(request.email, request.password)

      # A permitted control isolates email verification as the changed condition.
      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      assert {:ok, credentials} =
               Identity.authenticate_password(request.email, request.password)

      assert {:ok, %{account_id: account_id}} = Identity.authorize_session(credentials)
      assert account_id == registration.account_id
    end)
  end
end
```

**Why:** the rejection cannot be mistaken for a missing account or wrong password, because the same fixture becomes eligible and signs in after verification. For a stronger persistence invariant, use the existing approved read-only persistence observation in the owning test/proof fixture. Never replace the normal business write with direct SQL.

## BAD: negative case fails for an unrelated reason

```elixir
# Does NOT establish that unverified accounts cannot authenticate:
# the email may not exist, and the password may be wrong.
assert {:error, :authentication_unavailable} =
         Identity.authenticate_password("missing@example.invalid", "wrong")
```

For each negative, satisfy every other prerequisite: account state, role/capability, valid approval, supported locale/content, credential, purpose, environment and operation binding as applicable. Vary only the targeted guard, and inspect forbidden effects.

## GOOD: independent expected values for pure logic

```elixir
# Illustrative example; Example.Amount is not a NewYou API.
assert Example.Amount.total([10, 5]) == 15
```

## BAD: tautological expectation

```elixir
items = [10, 5]
expected = Enum.sum(items)  # A second copy of the algorithm, not an independent oracle.
assert Example.Amount.total(items) == expected
```

## Choose the right test level

- **Pure transformations:** `ExUnit.Case`, normally `async: true` only when no shared mutable state is touched; favor concrete boundary examples and property tests only when they attack a meaningful invariant.
- **Ash Domain behaviour:** call the real owning Domain interface. Use `NewYou.DataCase` and existing fixture helpers for database-backed behaviours. Assert authorization, action effects, rejection, constraints and recovery through the appropriate boundary.
- **HTTP and LiveView:** use `NewYouWeb.ConnCase` and current endpoint/LiveView helpers. Exercise CSRF, session, redirects, EN/AF copy, neutral responses, and data exposure when these are part of the actual delivery contract.
- **Concurrency/replay:** reproduce duplicate/reordered requests, atomic state changes and idempotent results with deterministic orchestration. Assert only one authoritative outcome and the required receipt/recovery semantics.
- **Provider/fault/restart:** test the true application adapter and durable recovery obligation; do not replace the entire owning workflow with a mock.
- **Durability:** a read-only query may be the most reliable proof that no forbidden session, receipt or other state was committed, especially when return values are intentionally neutral. The repository's production business-write boundary still prohibits bypassing Ash.

## Useful ExUnit practices

- Name tests for **observable behaviour and context**, not private helpers.
- A test may contain multiple assertions when proving one cohesive behaviour, including before/after state and absence of side effects.
- Prefer exact shapes and explicit errors when these are stable contracts; do not assert implementation timing or call counts unless timing/order **is** the contract.
- Use `setup`/`on_exit` for fixture and process-local state, and existing approved sandbox ownership. Shared application configuration, global process state, restart proofs and fault injection normally require synchronous isolation.
- Verify that every test's RED phase fails because of the missing or broken behaviour, not an unrelated fixture/permission failure.
- Don't weaken error assertions, bypass policies with `authorize?: false`, or modify DB contents merely to force a green result. Existing trusted test-only authority seams are distinct from production authorization.
- Respect locked TEST boundaries. No global database resets, unauthorized startup/provisioning, or blanket async conversion.

## Focused commands

```bash
# Execute one known test line under the pinned runtime and approved TEST profile.
mise exec -- devcore-project run test -- mix test test/new_you/identity/password_session_test.exs:85

# Execute an affected module after the RED/GREEN change.
mise exec -- devcore-project run test -- mix test test/new_you/identity/password_session_test.exs
```

Use the actual line/path from the current checkout. A focused proof is not a substitute for the final canonical local checks and exact-head hosted CI.
