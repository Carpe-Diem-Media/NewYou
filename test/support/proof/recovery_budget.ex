defmodule NewYou.Proof.RecoveryBudget do
  @moduledoc false

  # Store elapsed time against the stage that just ended. An interrupted stage
  # includes error propagation until the next observed boundary.
  @stages ~w(prepare before_transact account case_lookup resume_verified_channel issue_proof token communications binding transition commit finished padding)a
  @outcomes ~w(unobserved transaction_returned transaction_error transaction_exception)a
  @limit 9_999_999

  # The ordinal joins this report to the lease and task reports of one request.
  # Concurrent tasks print in completion order, so the ordinal is the only key.
  def measure(ordinal, callback) when ordinal in 0..9 do
    started = System.monotonic_time(:microsecond)
    Process.put({__MODULE__, :account_queries}, {0, 0, 0})
    Process.put({__MODULE__, :outcome}, :unobserved)
    Process.put(__MODULE__, {:prepare, started, %{}})

    try do
      result = callback.()
      stopped = System.monotonic_time(:microsecond)
      {stage, time, durations} = Process.get(__MODULE__)
      durations = Map.put(durations, stage, stopped - time)
      values = [stopped - started | Enum.map(@stages, &Map.get(durations, &1, -1))]
      {count, total, query} = Process.get({__MODULE__, :account_queries})
      values = values ++ [count, total, query]
      outcome = Process.get({__MODULE__, :outcome})

      IO.puts(
        "P815_BUDGET #{outcome} #{ordinal} " <> Enum.map_join(values, " ", &min(&1, @limit))
      )

      result
    after
      Process.delete({__MODULE__, :account_queries})
      Process.delete({__MODULE__, :outcome})
      Process.delete(__MODULE__)
    end
  end

  def stage(next) when next in @stages do
    if state = Process.get(__MODULE__) do
      {previous, time, durations} = state
      now = System.monotonic_time(:microsecond)
      Process.put(__MODULE__, {next, now, Map.put(durations, previous, now - time)})
    end

    :ok
  end

  def stage(_), do: :ok

  # Ecto total_time includes available queue, query and decode times, excluding
  # idle time. Missing measurements make the corresponding sum unknown.
  def successful_query(measurements) do
    if match?({:account, _, _}, Process.get(__MODULE__)) do
      key = {__MODULE__, :account_queries}
      {count, total, query} = Process.get(key)

      Process.put(
        key,
        {min(count + 1, @limit), add_time(total, measurements[:total_time]),
         add_time(query, measurements[:query_time])}
      )
    end

    :ok
  end

  defp add_time(sum, native) when sum >= 0 and is_integer(native) and native >= 0,
    do: min(sum + System.convert_time_unit(native, :native, :microsecond), @limit)

  defp add_time(_, _), do: -1

  # Called inside the child after RecoveryLease verified the parent's committed
  # fixture and this disposable database. Hold one fixture row on another lease.
  # Returns the callback result with the monotonic times of lock acquisition and
  # of release. The release time is taken before the holder is released.
  def with_account_lock(case_id, callback) do
    parent = self()
    ref = make_ref()

    holder = Task.async(fn -> hold_account(case_id, parent, ref) end)

    try do
      receive do
        {^ref, :locked} -> :ok
      after
        5_000 -> raise "Recovery budget lock acquisition deadline"
      end

      acquired = System.monotonic_time(:microsecond)
      result = callback.()
      released = System.monotonic_time(:microsecond)
      {result, %{acquired: acquired, released: released}}
    after
      send(holder.pid, {ref, :release})
      {:ok, :ok} = Task.await(holder, 6_000)
    end
  end

  defp hold_account(case_id, parent, ref) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(NewYou.Repo, fn ->
      NewYou.Repo.transaction(fn -> park_lock(case_id, parent, ref) end)
    end)
  end

  defp park_lock(case_id, parent, ref) do
    %{num_rows: 1} =
      NewYou.Repo.query!(
        "SELECT a.id FROM accounts a JOIN recovery_cases c ON c.account_id = a.id WHERE c.id = $1 FOR UPDATE OF a",
        [Ecto.UUID.dump!(case_id)],
        log: false
      )

    send(parent, {ref, :locked})

    receive do
      {^ref, :release} -> :ok
    after
      5_000 -> raise "Recovery budget lock release deadline"
    end
  end

  def observe_outcome(stage) when stage in @outcomes do
    Process.put({__MODULE__, :outcome}, stage)
    :ok
  end

  def observe_outcome(_), do: :ok

  def replay_effect(:transaction_returned, %{closure: :none, error: :none}), do: :replayed

  def replay_effect(stage, _) when stage in [:transaction_error, :transaction_exception],
    do: :failed_replay

  def replay_effect(_, _), do: :unconfirmed_replay

  def parse("P815_BUDGET " <> payload) do
    [label | parts] = String.split(payload, " ")
    outcome = Enum.find(@outcomes, &(Atom.to_string(&1) == label))

    fields =
      [:ordinal, :public | @stages] ++
        [:account_success_count, :account_adapter_total, :account_query]

    if outcome != nil and length(parts) == length(fields) and
         Enum.all?(parts, &Regex.match?(~r/\A(?:-1|[0-9]{1,7})\z/, &1)) and
         Regex.match?(~r/\A[0-9]\z/, hd(parts)) do
      [
        Map.put(
          Map.new(Enum.zip(fields, Enum.map(parts, &String.to_integer/1))),
          :transaction,
          outcome
        )
      ]
    else
      []
    end
  end

  def parse(_), do: []
end
