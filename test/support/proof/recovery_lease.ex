defmodule NewYou.Proof.RecoveryLease do
  @moduledoc false
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Identity.Recovery
  alias NewYou.Repo

  @closures ~w(checkout_deadline owner_checkin none unknown unobserved)a
  @operations ~w(none unknown request_locked resume_verified_channel issue_proof binding transition)a
  @errors ~w(unobserved none unknown lease_lost checkout_failed connection_error database_conflict constraint_error database_error)a
  @maximum 9_999_999

  def hosted?, do: System.get_env("GITHUB_ACTIONS") == "true"

  # The provisioner installs the random marker on its newly created database.
  # Both processes must see it and the same committed case/operation pair.
  def verify_fixture!(case_id, operation_id) do
    marker = System.get_env("P815_JOB_DATABASE")

    unless valid_job?(marker) and expected_endpoint?(Repo.config()),
      do: raise("Recovery disposable job context unavailable")

    verified =
      match?(
        %{rows: [[true]]},
        Repo.query!(
          """
          SELECT current_database() = 'new_you_test' AND current_user = 'new_you_test'
            AND current_setting('newyou.p815_job', true) = $1
            AND EXISTS (SELECT 1 FROM recovery_cases WHERE id = $2 AND operation_id = $3)
          """,
          [marker, Ecto.UUID.dump!(case_id), Ecto.UUID.dump!(operation_id)],
          log: false
        )
      )

    unless verified, do: raise("Recovery disposable job database verification failed")
    :ok
  end

  defp valid_job?(marker) do
    hosted?() and System.get_env("GITHUB_EVENT_NAME") == "pull_request" and
      disposable_runner?() and
      is_binary(marker) and Regex.match?(~r/\A[0-9a-f]{32}\z/, marker)
  end

  defp disposable_runner? do
    case System.get_env("RUNNER_ENVIRONMENT") do
      "github-hosted" ->
        true

      "self-hosted" ->
        System.get_env("P815_BLACKSMITH_RUNNER") == "true" and
          String.starts_with?(System.get_env("RUNNER_NAME", ""), "blacksmith-")

      _ ->
        false
    end
  end

  defp expected_endpoint?(config) do
    config[:hostname] == "127.0.0.1" and config[:port] == 55433 and
      config[:database] == "new_you_test" and config[:username] == "new_you_test"
  end

  def observe(input, callback) do
    ordinal = Map.get(input, "ordinal", 0)
    mode = Map.get(input, "lease_probe", "observe")
    verify_fixture!(input["case_id"], input["operation_id"])
    true = mode in ~w(observe baseline expiry checkin)
    probe = if mode != "baseline", do: monitor_proxy()
    if mode in ~w(expiry checkin) and is_nil(probe), do: raise("Recovery proxy unavailable")
    Process.put(__MODULE__, %{mode: mode, probe: probe, operation: :unknown, first: nil})

    try do
      result = callback.()
      state = Process.get(__MODULE__)
      closure = closure(state)
      {operation, error, query_us} = first_failure(state)
      pre = duration(state, :before_transact, :transaction_entered)
      post = duration(state, :transaction_entered, :finished)
      IO.puts("P815_LEASE #{ordinal} #{closure} #{operation} #{error} #{pre} #{post} #{query_us}")
      result
    after
      if probe, do: Process.demonitor(elem(probe, 1), [:flush])
      Process.delete(__MODULE__)
    end
  end

  defp monitor_proxy do
    %{pid: pool} = Ecto.Adapter.lookup_meta(Repo)
    {:monitored_by, owners} = Process.info(self(), :monitored_by)

    proxies =
      for %{source: {:proxy, pid}} <-
            DBConnection.get_connection_metrics(pool, pool: DBConnection.Ownership),
          pid in owners,
          do: pid

    case proxies do
      [proxy] -> {proxy, Process.monitor(proxy), DBConnection.Util.inspect_pid(self())}
      _ -> nil
    end
  end

  def stage(stage) do
    NewYou.Proof.RecoveryBudget.stage(if stage == :request_locked, do: :account, else: stage)

    if state = Process.get(__MODULE__) do
      state =
        case stage do
          clock when clock in [:before_transact, :transaction_entered, :finished] ->
            Map.put(state, clock, System.monotonic_time(:microsecond))

          op when op in @operations ->
            %{state | operation: op}

          _ ->
            state
        end

      Process.put(__MODULE__, state)
    end

    :ok
  end

  defp first_failure(%{mode: "baseline"}), do: {:none, :unobserved, -1}
  defp first_failure(state), do: state.first || {:none, :none, -1}

  # Inject before the first Account query so a natural issuance timeout cannot
  # preempt the intended non-timeout control.
  def calibrate_at_entry, do: inject(Process.get(__MODULE__))

  # Only the calibration child deliberately holds or checks in its own lease.
  defp inject(%{mode: "expiry"}),
    do: Process.sleep(Recovery.request_transaction_timeout_ms() + 50)

  defp inject(%{mode: "checkin", probe: {pid, _, _}}) do
    ref = Process.monitor(pid)

    try do
      :ok = Sandbox.checkin(Repo)

      receive do
        {:DOWN, ^ref, :process, ^pid, _} -> :ok
      after
        500 -> raise "Recovery owner check-in unconfirmed"
      end
    after
      Process.demonitor(ref, [:flush])
    end
  end

  defp inject(_), do: :ok

  def failure(category, measurements) do
    case Process.get(__MODULE__) do
      %{first: nil, mode: mode} = state when mode != "baseline" ->
        us =
          case measurements[:total_time] do
            n when is_integer(n) and n >= 0 ->
              min(System.convert_time_unit(n, :native, :microsecond), @maximum)

            _ ->
              -1
          end

        Process.put(__MODULE__, %{state | first: {state.operation, category || :unknown, us}})

      _ ->
        :ok
    end
  end

  defp duration(state, first, last) do
    case state do
      %{^first => a, ^last => b} -> min(max(b - a, 0), @maximum)
      _ -> -1
    end
  end

  defp closure(%{mode: "baseline"}), do: :unobserved
  defp closure(%{probe: nil}), do: :unknown

  defp closure(%{probe: {pid, ref, client}, first: first}) do
    receive do
      {:DOWN, ^ref, :process, ^pid, reason} -> classify(reason, client)
    after
      0 -> if(first == nil and Process.alive?(pid), do: :none, else: :unknown)
    end
  end

  def classify({:shutdown, %DBConnection.ConnectionError{message: msg}}, client) do
    deadline = Recovery.request_transaction_timeout_ms()

    timeout_line =
      "client #{client} timed out because it queued and checked out the connection for longer than #{deadline}ms"

    case :binary.split(msg, "\n") |> hd() do
      ^timeout_line ->
        :checkout_deadline

      line when line == client <> " checked in the connection owned by " <> client ->
        :owner_checkin

      _ ->
        :unknown
    end
  end

  def classify(_, _), do: :unknown

  def parse("P815_LEASE " <> fields) when byte_size(fields) < 120 do
    with [ordinal, c, op, err, pre, post, query] <- :binary.split(fields, " ", [:global]),
         true <- Regex.match?(~r/\A[0-9]\z/, ordinal),
         closure when not is_nil(closure) <- allowed(c, @closures),
         operation when not is_nil(operation) <- allowed(op, @operations),
         error when not is_nil(error) <- allowed(err, @errors),
         [a, b, d] <-
           for(
             value <- [pre, post, query],
             {n, ""} <- [Integer.parse(value)],
             n in -1..@maximum,
             do: n
           ) do
      [
        %{
          ordinal: String.to_integer(ordinal),
          closure: closure,
          operation: operation,
          error: error,
          pre_callback_us: a,
          callback_to_result_us: b,
          query_total_us: d
        }
      ]
    else
      _ -> []
    end
  end

  def parse(_), do: []
  defp allowed(value, atoms), do: Enum.find(atoms, &(Atom.to_string(&1) == value))
end
