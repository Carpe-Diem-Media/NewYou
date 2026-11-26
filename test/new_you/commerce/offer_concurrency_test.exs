defmodule NewYou.Commerce.OfferConcurrencyTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Commerce.{OfferAdmission, OfferCatalogue, Purchase}
  alias NewYou.Proof.P805
  alias NewYou.Repo

  import NewYou.Commerce.OfferFixtures

  test "independent PostgreSQL admissions serialize exact replay and competing payers" do
    P805.with_fixture(fn ->
      payer = verified_party()
      other = verified_party()
      recipient = verified_party()
      establish_clear_eligibility(recipient)
      publish!(:assessment)
      publish!(:bundle)

      authority = parties(payer, recipient)
      offered = quote!(authority, :assessment)
      competitor = parties(other, recipient)
      competing_quote = quote!(competitor, :bundle)

      winner =
        participant(fn -> OfferAdmission.accept(authority, acceptance(offered)) end, :holder)

      replay =
        participant(fn -> OfferAdmission.accept(authority, acceptance(offered)) end, :replay)

      loser =
        participant(
          fn -> OfferAdmission.accept(competitor, acceptance(competing_quote)) end,
          :loser
        )

      assert_unique_connections([winner, replay, loser])

      send(winner.task.pid, :run)
      assert_receive {:holder, :ready_to_commit}, 5_000
      assert payments_and_purchases(offered.operation_id) == {0, 0}

      for worker <- [replay, loser] do
        send(worker.task.pid, :run)
        assert_blocked_on(worker.backend, winner.backend)
      end

      send(winner.task.pid, :commit)
      assert {:ok, {:ok, accepted}} = Task.await(winner.task)
      assert {:ok, {:ok, ^accepted}} = Task.await(replay.task)
      assert {:ok, {:error, :assessment_unavailable}} = Task.await(loser.task)
      assert payments_and_purchases(offered.operation_id) == {0, 1}
      assert payments_and_purchases(competing_quote.operation_id) == {0, 0}

      assert [[1]] =
               Repo.query!(
                 """
                 SELECT count(*) FROM commerce_assessment_admissions
                 WHERE recipient_id = $1 AND state IN ('pending', 'paid')
                 """,
                 [Ecto.UUID.dump!(recipient.account_id)]
               ).rows
    end)
  end

  test "acceptance and quote creation wait for the concurrent catalogue replacement" do
    P805.with_fixture(fn ->
      payer = verified_party()
      other = verified_party()
      publish!(:plan)
      assert {:ok, draft} = draft_offer(:plan, %{amount_minor: 41_500, plan_list_minor: 41_500})
      authority = parties(payer, payer)
      offered = quote!(authority, :plan)
      fresh_authority = parties(other, other)

      publisher = participant(fn -> OfferCatalogue.approve(approval(draft)) end, :holder)

      accepter =
        participant(fn -> OfferAdmission.accept(authority, acceptance(offered)) end, :accepter)

      quoter =
        participant(
          fn -> OfferAdmission.quote(fresh_authority, %{product: :plan, language: :en}) end,
          :quoter
        )

      assert_unique_connections([publisher, accepter, quoter])

      send(publisher.task.pid, :run)
      assert_receive {:holder, :ready_to_commit}, 5_000

      for worker <- [accepter, quoter] do
        send(worker.task.pid, :run)
        assert_blocked_on(worker.backend, publisher.backend)
      end

      send(publisher.task.pid, :commit)
      assert {:ok, {:ok, published}} = Task.await(publisher.task)
      assert {:ok, {:error, :stale_quote}} = Task.await(accepter.task)

      case Task.await(quoter.task) do
        {:ok, {:ok, quote}} -> assert quote.price_version == published.price_version
        {:ok, {:error, :offer_unavailable}} -> :ok
        other_result -> flunk("unexpected quote result #{inspect(other_result)}")
      end

      assert quote!(fresh_authority, :plan).amount_minor == 41_500
      assert payments_and_purchases(offered.operation_id) == {0, 0}
    end)
  end

  test "admission rechecks ordinary credit after a concurrent owner transition commits" do
    P805.with_fixture(fn ->
      participant = verified_party()
      payer = verified_party()
      assert {:ok, previous} = set_credit(participant, :none)
      assert {:ok, _} = set_delivery(participant, :none)
      publish!(:assessment)
      authority = parties(payer, participant)
      offered = quote!(authority, :assessment)

      transition = fn ->
        set_credit(participant, :available_unused, %{
          prior_evidence_id: previous.evidence_id,
          credit_id: uuid()
        })
      end

      owner = participant(transition, :holder)
      buyer = participant(fn -> OfferAdmission.accept(authority, acceptance(offered)) end, :buyer)
      assert_unique_connections([owner, buyer])
      send(owner.task.pid, :run)
      assert_receive {:holder, :ready_to_commit}, 5_000
      send(buyer.task.pid, :run)
      assert_blocked_on(buyer.backend, owner.backend)
      send(owner.task.pid, :commit)
      assert {:ok, {:ok, _}} = Task.await(owner.task)
      assert {:ok, {:error, :assessment_unavailable}} = Task.await(buyer.task)
      assert payments_and_purchases(offered.operation_id) == {0, 0}
    end)
  end

  test "acceptance has a bounded query count and reports pool and query costs without parameters" do
    P805.with_fixture(fn ->
      payer = verified_party()
      recipient = verified_party()
      establish_clear_eligibility(recipient)
      publish!(:bundle)
      authority = parties(payer, recipient)
      offered = quote!(authority, :bundle)
      handler = {__MODULE__, make_ref()}

      :ok =
        :telemetry.attach(handler, [:new_you, :repo, :query], &__MODULE__.record_timing/4, self())

      try do
        assert {:ok, _} = OfferAdmission.accept(authority, acceptance(offered))
        {count, query, queue} = collect_timings(0, 0, 0)
        assert count in 1..45
        assert query > 0
        assert queue >= 0

        IO.puts(
          "WELL-197 uncontended bundle acceptance: #{count} SQL events, #{micros(query)} us query, #{micros(queue)} us pool queue"
        )
      after
        :telemetry.detach(handler)
      end
    end)
  end

  def record_timing(_event, measurements, _metadata, receiver) when receiver == self() do
    send(
      receiver,
      {:timing, Map.get(measurements, :query_time, 0), Map.get(measurements, :queue_time, 0)}
    )
  end

  def record_timing(_, _, _, _), do: :ok

  defp collect_timings(count, query, queue) do
    receive do
      {:timing, sql, pool} -> collect_timings(count + 1, query + sql, queue + pool)
    after
      0 -> {count, query, queue}
    end
  end

  defp micros(native), do: System.convert_time_unit(native, :native, :microsecond)

  defp participant(action, role) do
    parent = self()

    task =
      Task.async(fn ->
        receive do: (:start -> :ok)
        :ok = Sandbox.checkout(Repo, sandbox: false)

        try do
          {:ok, {:outcome, result}} =
            Ash.transact(Purchase, fn ->
              [[backend, transaction]] =
                Repo.query!("SELECT pg_backend_pid(), txid_current()").rows

              send(parent, {role, backend, transaction})
              receive do: (:run -> :ok)
              result = action.()

              if role == :holder do
                send(parent, {role, :ready_to_commit})
                receive do: (:commit -> :ok)
              end

              {:outcome, result}
            end)

          {:ok, result}
        after
          Sandbox.checkin(Repo)
        end
      end)

    :ok = P805.register_cleanup_worker(task.pid)
    send(task.pid, :start)
    assert_receive {^role, backend, transaction}, 5_000
    %{task: task, backend: backend, transaction: transaction}
  end

  defp assert_unique_connections(workers) do
    assert length(Enum.uniq_by(workers, & &1.backend)) == length(workers)
    assert length(Enum.uniq_by(workers, & &1.transaction)) == length(workers)
  end

  defp assert_blocked_on(waiter, holder) do
    assert blocked_on?(waiter, holder, 120),
           "expected a PostgreSQL lock wait on the winning connection"
  end

  defp blocked_on?(_, _, 0), do: false

  defp blocked_on?(waiter, holder, attempts) do
    case Repo.query!("SELECT $2::integer = ANY(pg_blocking_pids($1::integer))", [waiter, holder]).rows do
      [[true]] ->
        true

      [[false]] ->
        Process.sleep(20)
        blocked_on?(waiter, holder, attempts - 1)
    end
  end

  defp payments_and_purchases(operation) do
    [[payments, purchases]] =
      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM commerce_verified_payments p
           JOIN commerce_plan_purchases a ON a.id = p.purchase_id WHERE a.operation_id = $1),
          (SELECT count(*) FROM commerce_plan_purchases WHERE operation_id = $1)
        """,
        [Ecto.UUID.dump!(operation)]
      ).rows

    {payments, purchases}
  end
end
