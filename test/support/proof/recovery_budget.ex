defmodule NewYou.Proof.RecoveryBudget do
  @moduledoc false

  # Store elapsed time against the stage that just ended. An interrupted stage
  # includes error propagation until the next observed boundary.
  @stages ~w(prepare before_transact account case_lookup resume_verified_channel issue_proof token communications binding transition commit finished padding)a
  @limit 9_999_999

  def measure(callback) do
    started = System.monotonic_time(:microsecond)
    Process.put(__MODULE__, {:prepare, started, %{}})

    try do
      result = callback.()
      stopped = System.monotonic_time(:microsecond)
      {stage, time, durations} = Process.get(__MODULE__)
      durations = Map.put(durations, stage, stopped - time)
      values = [stopped - started | Enum.map(@stages, &Map.get(durations, &1, -1))]
      IO.puts("P815_BUDGET " <> Enum.map_join(values, " ", &min(&1, @limit)))
      result
    after
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

  # Called inside the child after RecoveryLease verified the parent's committed
  # fixture and this disposable database. Hold one fixture row on another lease.
  def with_account_lock(case_id, callback) do
    parent = self()
    ref = make_ref()

    holder = Task.async(fn -> hold_account(case_id, parent, ref) end)

    try do
      receive do
        {^ref, :locked} -> callback.()
      after
        5_000 -> raise "Recovery budget lock acquisition deadline"
      end
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

  def parse("P815_BUDGET " <> values) do
    fields = [:public | @stages]
    parts = String.split(values, " ")

    if length(parts) == length(fields) and
         Enum.all?(parts, &Regex.match?(~r/\A(?:-1|[0-9]{1,7})\z/, &1)) do
      [Map.new(Enum.zip(fields, Enum.map(parts, &String.to_integer/1)))]
    else
      []
    end
  end

  def parse(_), do: []
end
