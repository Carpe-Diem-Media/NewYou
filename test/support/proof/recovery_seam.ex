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
    :checkpoint,
    :transaction_returned,
    :transaction_error,
    :transaction_exception
  ]

  def now, do: Process.get({__MODULE__, :now}, DateTime.utc_now())

  def observe(callback) when is_function(callback, 1),
    do: Process.put({__MODULE__, :observer}, callback)

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
