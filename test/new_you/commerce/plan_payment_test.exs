defmodule NewYou.Commerce.PlanPaymentTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Commerce, Entitlements, Identity, Repo}
  alias NewYou.Commerce.{PaymentConsequence, Purchase}
  alias NewYou.Proof.PlanPaymentObservation
  alias NewYou.Proof.{FreshMix, P805}

  use AshOban.Test, repo: Repo
  require Ash.Query

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
      assert durable_counts(purchase.id) == {1, 1, 0, 0, 0}

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

  test "a consequence insertion failure rolls back Commerce payment and permits retry" do
    P805.with_fixture(fn ->
      payer = verified_session()
      purchase = accept!(payer)
      evidence = observation(purchase)

      P805.with_rejected_insert("commerce_payment_consequences", fn reached? ->
        assert {:error, :payment_unavailable} = Commerce.apply_payment_observation(evidence)
        assert reached?.()
      end)

      assert counts(purchase.id) == {0, 0}
      assert durable_counts(purchase.id) == {1, 1, 0, 0, 0}
      assert {:ok, []} == Commerce.open_plan_payment_consequences(purchase.id)
      assert {:ok, []} == Entitlements.plan_rights(payer.credentials)
      assert Ash.get!(Purchase, purchase.id, authorize?: false).attempt_id == purchase.attempt_id
      assert {:ok, payment} = Commerce.apply_payment_observation(evidence)
      assert payment.purchase_id == purchase.id
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

  test "overlapping consequence deliveries preserve one right and the first acknowledgement" do
    P805.with_fixture(fn ->
      payer = verified_session()
      purchase = accept!(payer)
      assert {:ok, payment} = Commerce.apply_payment_observation(observation(purchase))
      assert {:ok, [consequence_id]} = Commerce.open_plan_payment_consequences(purchase.id)
      parent = self()

      locker =
        tracked_task(fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          Ash.transact(PaymentConsequence, fn ->
            query =
              PaymentConsequence
              |> Ash.Query.filter(id == ^consequence_id)
              |> Ash.Query.lock(:for_update)

            assert %PaymentConsequence{} = Ash.read_one!(query, authorize?: false)
            [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
            send(parent, {:locked, backend})
            await_checkpoint(:release)
            :ok
          end)
        end)

      assert_receive {:locked, blocker}, 5_000

      deliveries =
        for role <- [:delivery_one, :delivery_two] do
          tracked_task(fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            Repo.checkout(fn ->
              [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
              send(parent, {role, backend})
              await_checkpoint(:deliver)
              Commerce.deliver_plan_payment_consequence(consequence_id)
            end)
          end)
        end

      results =
        try do
          assert_receive {:delivery_one, first_backend}, 5_000
          assert_receive {:delivery_two, second_backend}, 5_000
          refute first_backend == second_backend
          Enum.each(deliveries, &send(&1.pid, :deliver))
          assert_any_blocked_by(blocker, 150)
          assert_waiting(first_backend, 150)
          assert_waiting(second_backend, 150)
          assert Task.yield(Enum.at(deliveries, 0), 100) == nil
          assert Task.yield(Enum.at(deliveries, 1), 100) == nil
          send(locker.pid, :release)
          assert {:ok, :ok} = Task.await(locker)
          Enum.map(deliveries, &Task.await(&1, 10_000))
        after
          send(locker.pid, :release)
          Enum.each(deliveries, &send(&1.pid, :deliver))

          [locker | deliveries]
          |> Enum.filter(&Process.alive?(&1.pid))
          |> Task.yield_many(10_000)
        end

      [{:ok, first}, {:ok, second}] = results
      assert first.id == second.id
      assert first.purchase_id == purchase.id
      assert first.payment_id == payment.id
      assert first.recipient_id == payer.account_id
      assert first.state == :held_unconsumed
      assert durable_counts(purchase.id) == {1, 1, 1, 1, 1}
      acknowledged = Ash.get!(PaymentConsequence, consequence_id, authorize?: false)
      assert acknowledged.fulfilled_at
      assert {:ok, replay} = Commerce.deliver_plan_payment_consequence(consequence_id)
      assert replay.id == first.id

      assert Ash.get!(PaymentConsequence, consequence_id, authorize?: false).fulfilled_at ==
               acknowledged.fulfilled_at

      assert Ash.get!(Purchase, purchase.id, authorize?: false).attempt_id == purchase.attempt_id
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
          await_checkpoint(:start)
          :ok = Sandbox.checkout(Repo, sandbox: false)
          {:ok, payment} = Commerce.apply_payment_observation(observation(purchase))
          send(parent, {:payment_committed, payment.id})
        end)

      :ok = P805.register_cleanup_worker(worker)
      send(worker, :start)

      assert_receive {:payment_committed, payment_id}, 5_000
      assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, 5_000
      assert {:ok, []} = Entitlements.plan_rights(payer.credentials)
      {:ok, [consequence]} = Commerce.open_plan_payment_consequences(purchase.id)
      open = Ash.get!(PaymentConsequence, consequence, authorize?: false)
      assert_would_schedule(open, :deliver_plan_payment)

      assert {:error, :grant_unavailable} = Entitlements.grant_paid_plan(Ecto.UUID.generate())
      fresh_vm!("grant", purchase.id)
      assert {:ok, [right]} = Entitlements.plan_rights(payer.credentials)
      assert right.purchase_id == purchase.id
      assert right.recipient_id == payer.account_id
      assert right.state == :held_unconsumed
      assert right.component == :plan
      assert right.payment_id == payment_id
      assert {:ok, [consequence]} == Commerce.open_plan_payment_consequences(purchase.id)

      fresh_vm!("recover", purchase.id)
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

  test "fixture cleanup removes its scheduled job and financial effects" do
    {purchase_id, job_id} =
      P805.with_fixture(fn ->
        payer = verified_session()
        purchase = accept!(payer)
        assert {:ok, _} = Commerce.apply_payment_observation(observation(purchase))
        assert {:ok, [id]} = Commerce.open_plan_payment_consequences(purchase.id)
        consequence = Ash.get!(PaymentConsequence, id, authorize?: false)
        job = AshOban.run_trigger(consequence, :deliver_plan_payment)
        assert job.id

        assert %{status: :timeout, cleanup: :confirmed} =
                 NewYou.Proof.P815Port.run(
                   System.find_executable("sh"),
                   ["-c", "sleep 30"],
                   "",
                   500
                 )

        {purchase.id, job.id}
      end)

    :ok = Sandbox.checkout(Repo, sandbox: false)

    try do
      assert durable_counts(purchase_id) == {0, 0, 0, 0, 0}
      assert [[0]] = Repo.query!("SELECT count(*) FROM oban_jobs WHERE id = $1", [job_id]).rows
    after
      Sandbox.checkin(Repo)
    end
  end

  for stage <- [:before_grant, :after_grant] do
    test "scheduler rediscovers an open consequence #{stage} without its id" do
      P805.with_fixture(fn ->
        payer = verified_session()
        purchase = accept!(payer)
        assert {:ok, payment} = Commerce.apply_payment_observation(observation(purchase))
        assert {:ok, [consequence_id]} = Commerce.open_plan_payment_consequences(purchase.id)

        existing_right =
          if unquote(stage) == :after_grant do
            assert {:ok, right} = Entitlements.grant_paid_plan(consequence_id)
            right.id
          end

        assert [[0]] =
                 Repo.query!(
                   "SELECT count(*) FROM oban_jobs WHERE args->'primary_key'->>'id' = $1",
                   [consequence_id]
                 ).rows

        {executable, arguments} =
          FreshMix.command([
            "run",
            "test/proof/well189_scheduler_restart.exs",
            purchase.operation_id
          ])

        assert %{status: :ok, marker: :p1_completed, cleanup: :confirmed} =
                 NewYou.Proof.P815Port.run(executable, arguments, "", 60_000)

        assert [[job_id]] =
                 Repo.query!(
                   "SELECT id FROM oban_jobs WHERE args->'primary_key'->>'id' = $1 AND worker = $2",
                   [consequence_id, "NewYou.Commerce.Workers.DeliverPlanPayment"]
                 ).rows

        # perform_job accepts a persisted job; supply the claim timestamp that
        # Oban's queue normally sets before handing it to its executor.
        job = %{Repo.get!(Oban.Job, job_id) | attempted_at: DateTime.utc_now()}
        assert :ok = Oban.Testing.perform_job(job, repo: Repo)
        assert {:ok, []} = Commerce.open_plan_payment_consequences(purchase.id)
        assert {:ok, [right]} = Entitlements.plan_rights(payer.credentials)
        if existing_right, do: assert(right.id == existing_right)
        assert right.payment_id == payment.id
        assert right.state == :held_unconsumed
        assert durable_counts(purchase.id) == {1, 1, 1, 1, 1}
      end)
    end
  end

  test "the scheduler replaces an exhausted delivery job for the original open consequence" do
    P805.with_fixture(fn ->
      payer = verified_session()
      purchase = accept!(payer)
      assert {:ok, payment} = Commerce.apply_payment_observation(observation(purchase))
      assert {:ok, [consequence_id]} = Commerce.open_plan_payment_consequences(purchase.id)
      consequence = Ash.get!(PaymentConsequence, consequence_id, authorize?: false)
      original_job = AshOban.run_trigger(consequence, :deliver_plan_payment)
      assert original_job.queue == "commerce"
      assert original_job.max_attempts == 1

      # The initial available job must suppress a duplicate scheduler insertion.
      schedule_fixture!(purchase.operation_id)

      assert [[1]] =
               Repo.query!(
                 "SELECT count(*) FROM oban_jobs WHERE args->'primary_key'->>'id' = $1",
                 [consequence_id]
               ).rows

      P805.with_rejected_insert("entitlements_plan_rights", fn reached? ->
        # Claim only this fixture's job for its single configured attempt; the
        # real Oban executor runs and persists its terminal result below.
        assert %{num_rows: 1} =
                 Repo.query!(
                   "UPDATE oban_jobs SET state = 'executing', attempt = 1, attempted_at = now() WHERE id = $1 AND state = 'available' AND attempt = 0",
                   [original_job.id]
                 )

        job = Repo.get!(Oban.Job, original_job.id)
        executor = Oban.Queues.Executor.new(Oban.config(), job) |> Oban.Queues.Executor.call()
        assert executor.state == :exhausted
        assert reached?.()
      end)

      exhausted = Repo.get!(Oban.Job, original_job.id)
      assert exhausted.state == "discarded"
      assert exhausted.attempt == exhausted.max_attempts
      assert {:ok, [^consequence_id]} = Commerce.open_plan_payment_consequences(purchase.id)
      assert durable_counts(purchase.id) == {1, 1, 1, 1, 0}

      schedule_fixture!(purchase.operation_id)

      assert [[new_job_id]] =
               Repo.query!(
                 "SELECT id FROM oban_jobs WHERE args->'primary_key'->>'id' = $1 AND id <> $2 AND state = 'available'",
                 [consequence_id, original_job.id]
               ).rows

      replacement = Repo.get!(Oban.Job, new_job_id)
      assert replacement.queue == original_job.queue
      assert replacement.worker == original_job.worker
      assert replacement.args == exhausted.args
      job = %{replacement | attempted_at: DateTime.utc_now()}
      assert :ok = Oban.Testing.perform_job(job, repo: Repo)
      assert {:ok, []} = Commerce.open_plan_payment_consequences(purchase.id)
      assert {:ok, [right]} = Entitlements.plan_rights(payer.credentials)
      assert right.payment_id == payment.id
      assert right.purchase_id == purchase.id
      assert right.state == :held_unconsumed
      assert durable_counts(purchase.id) == {1, 1, 1, 1, 1}
      assert Repo.get!(Oban.Job, original_job.id).state == "discarded"

      assert [[2]] =
               Repo.query!(
                 "SELECT count(*) FROM oban_jobs WHERE args->'primary_key'->>'id' = $1",
                 [consequence_id]
               ).rows
    end)
  end

  defp schedule_fixture!(operation_id) do
    {executable, arguments} =
      FreshMix.command(["run", "test/proof/well189_scheduler_restart.exs", operation_id])

    assert %{status: :ok, marker: :p1_completed, cleanup: :confirmed} =
             NewYou.Proof.P815Port.run(executable, arguments, "", 60_000)
  end

  defp accept!(payer) do
    request = %{operation_id: operation_id(), price_version: "synthetic-plan-v1"}
    {:ok, purchase} = Commerce.accept_plan_purchase(payer.credentials, request)
    purchase
  end

  defp payment_transaction(purchase, parent, role) do
    task =
      Task.async(fn ->
        await_checkpoint(:start)
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

    :ok = P805.register_cleanup_worker(task.pid)
    send(task.pid, :start)
    task
  end

  defp tracked_task(callback) do
    task =
      Task.async(fn ->
        await_checkpoint(:start)
        callback.()
      end)

    :ok = P805.register_cleanup_worker(task.pid)
    send(task.pid, :start)
    task
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

  defp assert_waiting(_, 0), do: flunk("delivery connection did not wait")

  defp assert_waiting(backend, attempts) do
    case Repo.query!("SELECT cardinality(pg_blocking_pids($1)) > 0", [backend]).rows do
      [[true]] ->
        :ok

      [[false]] ->
        Process.sleep(20)
        assert_waiting(backend, attempts - 1)
    end
  end

  defp assert_any_blocked_by(_, 0), do: flunk("delivery never waited on the consequence lock")

  defp assert_any_blocked_by(blocker, attempts) do
    case Repo.query!(
           "SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE $1::integer = ANY(pg_blocking_pids(pid)))",
           [blocker]
         ).rows do
      [[true]] ->
        :ok

      [[false]] ->
        Process.sleep(20)
        assert_any_blocked_by(blocker, attempts - 1)
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

    result = NewYou.Proof.P815Port.run(executable, arguments, "", 60_000)
    assert %{status: :ok, marker: :p1_completed, cleanup: :confirmed} = result
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

  defp durable_counts(purchase_id) do
    [[purchases, attempts, payments, consequences, rights]] =
      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM commerce_plan_purchases WHERE id = $1),
          (SELECT count(attempt_id) FROM commerce_plan_purchases WHERE id = $1),
          (SELECT count(*) FROM commerce_verified_payments WHERE purchase_id = $1),
          (SELECT count(*) FROM commerce_payment_consequences WHERE purchase_id = $1),
          (SELECT count(*) FROM entitlements_plan_rights WHERE purchase_id = $1)
        """,
        [Ecto.UUID.dump!(purchase_id)]
      ).rows

    {purchases, attempts, payments, consequences, rights}
  end

  defp verified_session do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
    %{account_id: registration.account_id, credentials: credentials}
  end
end
