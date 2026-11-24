defmodule NewYou.Commerce.PlanPaymentTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Commerce, Entitlements, Identity, Repo}
  alias NewYou.Commerce.{PaymentConsequence, Purchase}
  alias NewYou.Proof.PlanPaymentObservation
  alias NewYou.Proof.{FreshMix, P805}

  use AshOban.Test, repo: Repo

  test "a verified payer accepts exactly one immutable standalone Plan purchase" do
    P805.with_fixture(fn ->
      payer = verified_session()
      foreign = verified_session()
      operation_id = operation_id()
      request = %{operation_id: operation_id, price_version: "synthetic-plan-v1"}

      assert {:ok, purchase} = Commerce.accept_plan_purchase(payer.credentials, request)
      assert purchase.payer_id == payer.account_id
      assert purchase.recipient_id == payer.account_id
      assert purchase.amount_minor == 39_900
      assert purchase.currency == "ZAR"
      assert purchase.price_version == request.price_version
      assert purchase.attempt_id

      assert {:ok, replay} = Commerce.accept_plan_purchase(payer.credentials, request)
      assert replay.id == purchase.id
      assert replay.attempt_id == purchase.attempt_id

      assert {:error, :purchase_unavailable} =
               Commerce.accept_plan_purchase(foreign.credentials, request)

      assert {:error, :purchase_unavailable} =
               Commerce.accept_plan_purchase(payer.credentials, %{
                 request
                 | price_version: "other"
               })

      assert {:error, :purchase_unavailable} =
               Commerce.accept_plan_purchase(
                 payer.credentials,
                 Map.put(request, :amount_minor, 1)
               )
    end)
  end

  test "invalid observations leave the accepted attempt unpaid and a qualified match applies once" do
    P805.with_fixture(fn ->
      payer = verified_session()
      request = %{operation_id: operation_id(), price_version: "synthetic-plan-v1"}
      assert {:ok, purchase} = Commerce.accept_plan_purchase(payer.credentials, request)

      matching = %{
        attempt_id: purchase.attempt_id,
        purchase_id: purchase.id,
        amount_minor: 39_900,
        currency: "ZAR",
        environment: :test,
        integration: :synthetic,
        status: :succeeded
      }

      assert Commerce.apply_payment_observation(matching) == {:error, :payment_unavailable}

      for {field, value} <- [
            attempt_id: Ecto.UUID.generate(),
            purchase_id: Ecto.UUID.generate(),
            amount_minor: 1,
            currency: "USD",
            environment: :production,
            integration: :provider,
            status: :pending
          ] do
        evidence = PlanPaymentObservation.produce(Map.put(matching, field, value))
        assert Commerce.apply_payment_observation(evidence) == {:error, :payment_unavailable}
      end

      assert counts(purchase.id) == {0, 0}

      evidence = PlanPaymentObservation.produce(matching)
      altered = %{evidence | fields: Map.put(matching, :attempt_id, Ecto.UUID.generate())}
      assert PlanPaymentObservation.verify(altered) == {:error, :unqualified}
      assert Commerce.apply_payment_observation(altered) == {:error, :payment_unavailable}
      assert {:ok, payment} = Commerce.apply_payment_observation(evidence)
      assert {:ok, replay} = Commerce.apply_payment_observation(evidence)
      assert payment.id == replay.id
      assert counts(purchase.id) == {1, 1}
    end)
  end

  test "rolling back the Commerce transaction leaves the accepted attempt with no payment or right" do
    P805.with_fixture(fn ->
      payer = verified_session()
      purchase = accept!(payer)
      evidence = observation(purchase)

      assert {:error, _} =
               Ash.transact(Purchase, fn ->
                 assert {:ok, _} = Commerce.apply_payment_observation(evidence)
                 assert counts(purchase.id) == {1, 1}
                 {:error, :proof_rollback}
               end)

      assert counts(purchase.id) == {0, 0}
      assert {:ok, []} == Commerce.open_plan_payment_consequences(purchase.id)
      assert {:ok, []} == Entitlements.plan_rights(payer.credentials)
      assert {:ok, _} = Commerce.apply_payment_observation(evidence)
      assert counts(purchase.id) == {1, 1}
    end)
  end

  test "independent PostgreSQL transactions converge on one payment, consequence and right" do
    P805.with_fixture(fn ->
      payer = verified_session()
      purchase = accept!(payer)
      parent = self()

      first = payment_transaction(purchase, parent, :first)
      second = payment_transaction(purchase, parent, :second)

      assert_receive {:first, first_backend, first_transaction}, 5_000
      assert_receive {:second, second_backend, second_transaction}, 5_000
      refute first_backend == second_backend
      refute first_transaction == second_transaction

      send(first.pid, :apply)
      assert_receive {:first, :applied}, 5_000
      assert counts(purchase.id) == {0, 0}

      send(second.pid, :apply)
      assert_blocked_by(second_backend, first_backend, 100)
      send(first.pid, :commit)

      assert {:ok, first_payment} = Task.await(first)
      assert {:ok, second_payment} = Task.await(second)
      assert first_payment.id == second_payment.id
      assert counts(purchase.id) == {1, 1}

      assert {:ok, [consequence]} = Commerce.open_plan_payment_consequences(purchase.id)
      assert {:ok, right} = Commerce.deliver_plan_payment_consequence(consequence)
      assert {:ok, replay} = Commerce.deliver_plan_payment_consequence(consequence)
      assert right.id == replay.id
      assert {:ok, [%{state: :held_unconsumed}]} = Entitlements.plan_rights(payer.credentials)
    end)
  end

  test "a committed payment can be recovered after a separate grant commits without acknowledgement" do
    P805.with_fixture(fn ->
      payer = verified_session()
      foreign = verified_session()
      purchase = accept!(payer)
      parent = self()

      {worker, monitor} =
        spawn_monitor(fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)
          {:ok, payment} = Commerce.apply_payment_observation(observation(purchase))
          send(parent, {:payment_committed, payment.id})
          exit(:lost_before_grant)
        end)

      assert_receive {:payment_committed, payment_id}, 5_000
      assert_receive {:DOWN, ^monitor, :process, ^worker, :lost_before_grant}, 5_000
      assert {:ok, []} = Entitlements.plan_rights(payer.credentials)
      {:ok, [consequence]} = Commerce.open_plan_payment_consequences(purchase.id)
      open = Ash.get!(PaymentConsequence, consequence, authorize?: false)
      assert_would_schedule(open, :deliver_plan_payment)

      assert {:error, :grant_unavailable} = Entitlements.grant_paid_plan(Ecto.UUID.generate())
      right_id = fresh_vm!("grant", purchase.id)
      assert {:ok, [right]} = Entitlements.plan_rights(payer.credentials)
      assert right.id == right_id
      assert right.purchase_id == purchase.id
      assert right.recipient_id == payer.account_id
      assert right.state == :held_unconsumed
      assert right.component == :plan
      assert right.payment_id == payment_id
      assert {:ok, [consequence]} == Commerce.open_plan_payment_consequences(purchase.id)

      assert fresh_vm!("recover", purchase.id) == right.id
      fulfilled = Ash.get!(PaymentConsequence, consequence, authorize?: false)
      refute_would_schedule(fulfilled, :deliver_plan_payment)
      assert {:ok, []} == Commerce.open_plan_payment_consequences(purchase.id)
      assert {:ok, [%{id: id}]} = Entitlements.plan_rights(payer.credentials)
      assert id == right.id
      assert {:ok, []} = Entitlements.plan_rights(foreign.credentials)
      assert {:error, _} = Ash.get(Entitlements.PlanRight, right.id)

      assert {:error, :entitlements_scope_unavailable} =
               Entitlements.review_identity_reconciliation(foreign.account_id, payer.account_id)

      assert {:error, _} =
               Ash.create(
                 Entitlements.PlanRight,
                 %{
                   purchase_id: purchase.id,
                   payment_id: payment_id,
                   recipient_id: foreign.account_id
                 },
                 action: :grant
               )
    end)
  end

  defp accept!(payer) do
    request = %{operation_id: operation_id(), price_version: "synthetic-plan-v1"}
    {:ok, purchase} = Commerce.accept_plan_purchase(payer.credentials, request)
    purchase
  end

  defp payment_transaction(purchase, parent, role) do
    Task.async(fn ->
      :ok = Sandbox.checkout(Repo, sandbox: false)

      Ash.transact(Purchase, fn ->
        [[backend_id, transaction_id]] =
          Repo.query!("SELECT pg_backend_pid(), txid_current()").rows

        send(parent, {role, backend_id, transaction_id})

        await_checkpoint(:apply)
        {:ok, payment} = Commerce.apply_payment_observation(observation(purchase))
        pause_before_commit(role, parent)
        payment
      end)
    end)
  end

  defp pause_before_commit(:second, _parent), do: :ok

  defp pause_before_commit(:first, parent) do
    send(parent, {:first, :applied})
    await_checkpoint(:commit)
  end

  defp await_checkpoint(checkpoint) do
    receive do
      ^checkpoint -> :ok
    after
      10_000 -> flunk("payment #{checkpoint} checkpoint timed out")
    end
  end

  defp assert_blocked_by(_, _, 0), do: flunk("second transaction never waited on the first")

  defp assert_blocked_by(waiter, blocker, attempts) do
    case Repo.query!("SELECT $2::integer = ANY(pg_blocking_pids($1))", [waiter, blocker]).rows do
      [[true]] ->
        :ok

      [[false]] ->
        Process.sleep(20)
        assert_blocked_by(waiter, blocker, attempts - 1)
    end
  end

  defp fresh_vm!(stage, purchase_id) do
    {executable, arguments} =
      FreshMix.command(["run", "test/proof/well189_plan_payment_restart.exs", stage, purchase_id])

    {output, status} =
      System.cmd(executable, arguments,
        env: [{"MIX_ENV", "test"}, {"ERL_FLAGS", "+S 2:2"}],
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert [_, right_id] = Regex.run(~r/^P1_RIGHT=([a-f0-9-]+)$/m, output)
    right_id
  end

  defp observation(purchase) do
    PlanPaymentObservation.produce(%{
      attempt_id: purchase.attempt_id,
      purchase_id: purchase.id,
      amount_minor: 39_900,
      currency: "ZAR",
      environment: :test,
      integration: :synthetic,
      status: :succeeded
    })
  end

  defp operation_id do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  defp counts(purchase_id) do
    [[payments, consequences]] =
      NewYou.Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM commerce_verified_payments WHERE purchase_id = $1),
          (SELECT count(*) FROM commerce_payment_consequences WHERE purchase_id = $1)
        """,
        [Ecto.UUID.dump!(purchase_id)]
      ).rows

    {payments, consequences}
  end

  defp verified_session do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
    %{account_id: registration.account_id, credentials: credentials}
  end
end
