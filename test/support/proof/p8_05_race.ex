defmodule NewYou.Proof.P805Race do
  @moduledoc false
  alias NewYou.{Identity, Repo}
  alias NewYou.Proof.{Concurrent, P805, RegistrationSeam, Scenario}

  def run(id) do
    input = P805.request()
    duplicate = P805.request(%{email: input.email})
    before = P805.counts()
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()

    try do
      {coordinator, monitor} =
        Scenario.spawn(scenario, :coordinator, fn ->
          nested = Scenario.start()

          result =
            Concurrent.run(
              nested,
              %{
                first: fn -> worker(parent, reference, :first, input) end,
                second: fn -> worker(parent, reference, :second, duplicate) end
              },
              timeout: 30_000
            )

          :ok = Scenario.stop(nested)
          send(parent, {reference, :outcomes, result})
        end)

      {first, backend_a, transaction_a} = await_first(reference)
      {second, backend_b} = await_second(reference)
      P805.check(id, "independent_connections", backend_a != backend_b)
      send(second, {reference, :contend})

      transaction_b =
        await_contention(backend_a, backend_b, System.monotonic_time(:millisecond) + 15_000)

      P805.check(
        id,
        "independent_transactions",
        transaction_a != transaction_b
      )

      P805.check(id, "contention", is_binary(transaction_b))
      send(first, {reference, :release})

      outcomes =
        receive do
          {^reference, :outcomes, {:ok, results}} -> results
        after
          30_000 -> raise "proof race completion deadline"
        end

      receive do
        {:DOWN, ^monitor, :process, ^coordinator, :normal} -> :ok
      after
        5_000 -> raise "proof race coordinator cleanup deadline"
      end

      results = Enum.map(Map.values(outcomes.outcomes), & &1.outcome)

      P805.check(
        id,
        "one_account",
        Enum.count(results, &(&1 == [:verification_pending, :created])),
        1
      )

      P805.check(
        id,
        "neutral_results",
        Enum.all?(
          results,
          &(&1 in [[:verification_pending, :created], [:verification_pending, :neutral]])
        )
      )

      P805.check(id, "no_duplicate_consequences", P805.delta(before, P805.counts()), [
        1,
        1,
        2,
        0,
        1,
        1,
        1,
        1,
        1,
        1
      ])

      [operation] =
        P805.read(Identity.RegistrationOperation, Identity)
        |> Enum.filter(
          &(&1.operation_id in [input.operation_id, duplicate.operation_id] and
              is_binary(&1.created_account_id))
        )

      account = P805.account!(operation.created_account_id)

      P805.check(
        id,
        "fresh_owner_read",
        Identity.PMR.valid?(account.pmr) and account.credential_status == :active and
          length(P805.intents(input.operation_id)) + length(P805.intents(duplicate.operation_id)) ==
            1
      )
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp worker(parent, reference, label, input) do
    if label == :first do
      Process.put(RegistrationSeam, {:pause, parent, reference})
    else
      backend = P805.scalar("SELECT pg_backend_pid()")
      send(parent, {reference, :second_ready, self(), backend})

      receive do
        {^reference, :contend} -> :ok
      after
        20_000 -> raise "proof race start deadline"
      end
    end

    case Identity.register(input) do
      {:ok, result} ->
        {result.status, if(is_binary(result.account_id), do: :created, else: :neutral)}

      {:error, _} ->
        :rejected
    end
  after
    Process.delete(RegistrationSeam)
  end

  defp await_first(reference) do
    receive do
      {^reference, :before_commit, worker, backend, transaction} -> {worker, backend, transaction}
    after
      20_000 -> raise "proof first transaction deadline"
    end
  end

  defp await_second(reference) do
    receive do
      {^reference, :second_ready, worker, backend} -> {worker, backend}
    after
      5_000 -> raise "proof second connection deadline"
    end
  end

  defp await_contention(first, second, deadline) do
    # Query actual PostgreSQL lock state. There is no sleep, substitute lock,
    # or enclosing harness transaction around either owning registration action.
    %{rows: rows} =
      Repo.query!(
        "SELECT backend_xid::text FROM pg_stat_activity WHERE pid = $1 AND $2 = ANY(pg_blocking_pids(pid))",
        [second, first]
      )

    case rows do
      [[transaction]] when is_binary(transaction) ->
        transaction

      _ ->
        if System.monotonic_time(:millisecond) < deadline,
          do: await_contention(first, second, deadline),
          else: raise("proof actual contention not observed")
    end
  end
end
