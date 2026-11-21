defmodule NewYou.Proof.RecoverySeam do
  @moduledoc "Test-only recovery clock and fixed transaction diagnostics; RegistrationSeam supplies pre-commit cuts."

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}
  alias NewYou.Proof.{P805, Scenario}

  @stages [
    :transaction_entered,
    :account_locked,
    :resume_verified_channel,
    :await_proof,
    :await_proof_rejected,
    :checkpoint,
    :transaction_returned,
    :transaction_error,
    :transaction_exception
  ]

  def now, do: Process.get({__MODULE__, :now}, DateTime.utc_now())

  def observe(callback) when is_function(callback, 1),
    do: Process.put({__MODULE__, :observer}, callback)

  @doc "Capture fixed database failure categories for queries issued by this process."
  def capture_database_failures(callback) do
    ref = make_ref()
    event = Keyword.fetch!(Repo.config(), :telemetry_prefix) ++ [:query]
    :ok = :telemetry.attach(ref, event, &__MODULE__.record_database_failure/4, {self(), ref})

    try do
      {callback.(), Enum.sort(Process.get(ref, MapSet.new()))}
    after
      :telemetry.detach(ref)
      Process.delete(ref)
    end
  end

  @doc false
  def record_database_failure(_, measurements, %{result: {:error, error}}, {owner, ref})
      when owner == self() do
    category = database_failure(error)
    NewYou.Proof.RecoveryLease.failure(category, measurements)

    case category do
      nil -> :ok
      category -> Process.put(ref, MapSet.put(Process.get(ref, MapSet.new()), category))
    end
  end

  def record_database_failure(_, measurements, %{result: {:ok, _}}, {owner, _})
      when owner == self(),
      do: NewYou.Proof.RecoveryBudget.successful_query(measurements)

  def record_database_failure(_, _, _, _), do: :ok

  # DBConnection reports closed handles separately from queue failures. A closed
  # handle proves loss of the lease but does not identify why it closed.
  defp database_failure(%DBConnection.ConnectionError{
         message: "connection is closed because of an error, disconnect or timeout"
       }),
       do: :lease_lost

  defp database_failure(%DBConnection.ConnectionError{reason: :queue_timeout}),
    do: :checkout_failed

  defp database_failure(%DBConnection.OwnershipError{}), do: :checkout_failed
  defp database_failure(%DBConnection.ConnectionError{}), do: :connection_error

  defp database_failure(%Postgrex.Error{postgres: %{code: code}})
       when code in [:lock_not_available, :deadlock_detected, :serialization_failure],
       do: :database_conflict

  defp database_failure(%Postgrex.Error{postgres: %{code: code}})
       when code in [:unique_violation, :foreign_key_violation, :check_violation],
       do: :constraint_error

  defp database_failure(%Postgrex.Error{}), do: :database_error
  defp database_failure(_), do: nil

  @doc "Run one recovery request on its own unboxed checkout and wait for worker cleanup."
  @spec isolated_fixture_request(binary(), Ecto.UUID.t()) :: :ok
  def isolated_fixture_request(email, operation_id) do
    owner = self()
    reference = make_ref()
    observer = Process.get({__MODULE__, :observer})
    scenario = Scenario.start()

    try do
      {worker, monitor} =
        Scenario.spawn(scenario, :fixture_request, fn ->
          receive do
            {^reference, :run} ->
              if is_function(observer, 1), do: observe(observer)
              :ok = Sandbox.checkout(Repo, sandbox: false)

              try do
                :ok = Identity.request_recovery(email, "af", operation_id)
              after
                Sandbox.checkin(Repo)
              end

              send(owner, {reference, :request_finished})
          end
        end)

      # Register before the checkout so fixture teardown can account for the worker.
      :ok = P805.register_cleanup_worker(worker)
      send(worker, {reference, :run})

      receive do
        {^reference, :request_finished} -> :ok
        {:DOWN, ^monitor, :process, ^worker, reason} -> exit(reason)
      after
        15_000 -> raise "recovery fixture request deadline"
      end

      receive do
        {:DOWN, ^monitor, :process, ^worker, :normal} -> :ok
        {:DOWN, ^monitor, :process, ^worker, reason} -> exit(reason)
      after
        15_000 -> raise "recovery fixture worker cleanup deadline"
      end

      :ok = Scenario.request(scenario, {:await_owned_down, [worker], 5_000})
    after
      :ok = Scenario.stop(scenario)
    end
  end

  # Stage names are the whole diagnostic. No request data or exception details
  # enter this callback, including on neutral public-request failures.
  def trace(stage) when stage in @stages do
    case Process.get({__MODULE__, :observer}) do
      callback when is_function(callback, 1) -> callback.(stage)
      _ -> :ok
    end

    :ok
  end
end
