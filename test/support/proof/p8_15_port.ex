defmodule NewYou.Proof.P815Port do
  @moduledoc false

  @limit 8_192
  @markers %{
    "P815_REQUESTED" => :requested,
    "P815_REQUEST_RETRIED" => :request_retried,
    "P815_INTERRUPTION_NOT_PROVEN" => :interruption_not_proven,
    "P815_DELIVERY_MATCHES" => :delivery_matches,
    "P815_ACCEPTED" => :accepted,
    "P815_COMPLETED" => :completed,
    "P815_ALREADY_COMPLETED" => :already_completed,
    "P1_COMPLETED" => :p1_completed,
    "S1_COMPLETED" => :s1_completed,
    "E1AF_COMPLETED" => :e1af_completed,
    "E2A_COMPLETED" => :e2a_completed,
    "P814_RECONSTRUCTED" => :p814_reconstructed,
    "P814_CONFLICT_DENIED" => :p814_conflict_denied,
    "P814_REVIEW_RECOVERED" => :p814_review_recovered
  }

  def run(executable, args, payload, timeout \\ 30_000)

  def run(nil, _args, _payload, _timeout) do
    result(:startup_failure, "", System.monotonic_time(:millisecond), :not_started, nil)
  end

  def run(executable, args, payload, timeout) when is_binary(executable) do
    started = System.monotonic_time(:millisecond)
    owner = self()
    reference = make_ref()
    fixture_guardian = Process.get({NewYou.Proof.P805, :guardian})

    {worker, monitor} =
      spawn_monitor(fn ->
        Process.put({__MODULE__, :fixture_guardian}, fixture_guardian)
        owner_monitor = Process.monitor(owner)
        Process.put({__MODULE__, :owner_monitor}, owner_monitor)

        receive do
          {^reference, :start} ->
            diagnostic = run_child(executable, args, payload, timeout, started)
            send(owner, {reference, diagnostic})
            if diagnostic.cleanup == :unconfirmed, do: exit(:cleanup_unconfirmed)

          {:DOWN, ^owner_monitor, :process, ^owner, _} ->
            :ok
        end
      end)

    try do
      if Process.get({NewYou.Proof.P805, :fixture_checked_out}) == true,
        do: NewYou.Proof.P805.register_cleanup_worker(worker)

      send(worker, {reference, :start})
    rescue
      error ->
        Process.exit(worker, :kill)
        receive do: ({:DOWN, ^monitor, :process, ^worker, _} -> :ok)
        reraise error, __STACKTRACE__
    end

    receive do
      {^reference, diagnostic} ->
        receive do
          {:DOWN, ^monitor, :process, ^worker, :normal} ->
            diagnostic

          {:DOWN, ^monitor, :process, ^worker, _} ->
            diagnostic
        end

      {:DOWN, ^monitor, :process, ^worker, _} ->
        result(:harness_failure, "", started, :unconfirmed, nil)
    end
  end

  defp run_child(executable, args, payload, timeout, started) do
    shell = System.find_executable("sh")
    ps = System.find_executable("ps")
    kill = System.find_executable("kill")

    cond do
      System.monotonic_time(:millisecond) >= started + timeout ->
        result(:timeout, "", started, :not_started, nil)

      shell && ps && kill ->
        launch(shell, ps, executable, args, payload, timeout, started)

      true ->
        result(:startup_failure, "", started, :not_started, nil)
    end
  end

  defp launch(shell, ps, executable, args, payload, timeout, started) do
    # The shell waits for permission before exec. This lets the parent verify
    # that the Port owns its process group before the proof can spawn workers.
    options = [
      :binary,
      :exit_status,
      :stderr_to_stdout,
      args: [
        "-c",
        "printf 'P815_GROUP=%s\\n' \"$$\"; IFS= read -r go || exit 125; [ \"$go\" = GO ] || exit 125; printf 'P815_READY\\n'; exec \"$@\"",
        "p815",
        executable | args
      ],
      env: [{~c"MIX_ENV", ~c"test"}, {~c"ERL_FLAGS", ~c"+S 2:2"}]
    ]

    opened =
      try do
        case Process.get({__MODULE__, :fixture_guardian}) do
          guardian when is_pid(guardian) ->
            NewYou.Proof.P805.open_restart_port(guardian, shell, options)

          _ ->
            {:ok, Port.open({:spawn_executable, shell}, options)}
        end
      rescue
        _ -> {:error, :unconfirmed}
      end

    case opened do
      {:ok, port} -> run_port(port, ps, payload, timeout, started)
      {:error, :not_started} -> result(:startup_failure, "", started, :not_started, nil)
      _ -> result(:harness_failure, "", started, :unconfirmed, nil)
    end
  end

  defp run_port(port, ps, payload, timeout, started) do
    supervisor_pid =
      case Port.info(port, :os_pid) do
        {:os_pid, pid} -> pid
        nil -> nil
      end

    try do
      start(port, supervisor_pid, ps, "", payload, started, started + timeout)
    rescue
      _ -> result(:harness_failure, "", started, :unconfirmed, nil)
    after
      group_pid = Process.delete({__MODULE__, port})
      if Port.info(port), do: terminate(port, supervisor_pid, group_pid)
    end
  end

  defp start(port, supervisor_pid, ps, output, payload, started, deadline) do
    owner_monitor = Process.get({__MODULE__, :owner_monitor})

    receive do
      {:DOWN, ^owner_monitor, :process, _, _} ->
        cancel_owner(port, supervisor_pid, nil)

      {^port, {:data, bytes}} ->
        output = output <> bytes

        cond do
          System.monotonic_time(:millisecond) >= deadline ->
            {cleanup, exit_status} = terminate(port, supervisor_pid, nil)
            result(:timeout, prefix(output), started, cleanup, exit_status)

          byte_size(output) >= @limit ->
            {cleanup, exit_status} = terminate(port, supervisor_pid, nil)
            result(:output_overflow, prefix(output), started, cleanup, exit_status)

          group_pid = group(output) ->
            start_group(port, supervisor_pid, ps, group_pid, output, payload, started, deadline)

          :binary.match(output, "\n") != :nomatch ->
            {cleanup, exit_status} = terminate(port, supervisor_pid, nil)
            result(:startup_failure, "", started, cleanup, exit_status)

          true ->
            start(port, supervisor_pid, ps, output, payload, started, deadline)
        end

      {^port, {:exit_status, code}} ->
        drain(port)

        status =
          if System.monotonic_time(:millisecond) >= deadline, do: :timeout, else: {:exit, code}

        result(status, output, started, :unconfirmed, code)
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        {cleanup, exit_status} = terminate(port, supervisor_pid, nil)
        result(:timeout, output, started, cleanup, exit_status)
    end
  end

  defp start_group(port, supervisor_pid, ps, group_pid, output, payload, started, deadline) do
    if group_pid != supervisor_pid or not isolated_group?(ps, group_pid) do
      {cleanup, exit_status} = terminate(port, supervisor_pid, nil)
      result(:startup_failure, output, started, cleanup, exit_status)
    else
      Process.put({__MODULE__, port}, group_pid)

      if System.monotonic_time(:millisecond) >= deadline do
        {cleanup, exit_status} = terminate(port, supervisor_pid, group_pid)
        result(:timeout, output, started, cleanup, exit_status)
      else
        true = Port.command(port, "GO\n")
        ready(port, supervisor_pid, output, payload, started, deadline)
      end
    end
  end

  defp isolated_group?(ps, pid) do
    case System.cmd(ps, ["-o", "pgid=", "-p", Integer.to_string(pid)], stderr_to_stdout: true) do
      {output, 0} -> String.trim(output) == Integer.to_string(pid)
      _ -> false
    end
  end

  defp ready(port, pid, output, payload, started, deadline) do
    owner_monitor = Process.get({__MODULE__, :owner_monitor})

    receive do
      {:DOWN, ^owner_monitor, :process, _, _} ->
        cancel_owner(port, pid, group(output))

      {^port, {:data, bytes}} ->
        output = output <> bytes

        cond do
          System.monotonic_time(:millisecond) >= deadline ->
            {cleanup, status} = terminate(port, pid, group(output))
            result(:timeout, prefix(output), started, cleanup, status)

          byte_size(output) >= @limit ->
            {cleanup, status} = terminate(port, pid, group(output))
            result(:output_overflow, prefix(output), started, cleanup, status)

          "P815_READY" in :binary.split(output, "\n", [:global]) ->
            if payload != "", do: true = Port.command(port, payload <> "\n")
            # The READY chunk can already contain the entire checkpoint.
            read_buffer(port, pid, output, started, deadline)

          true ->
            ready(port, pid, output, payload, started, deadline)
        end

      {^port, {:exit_status, code}} ->
        drain(port)

        status =
          if System.monotonic_time(:millisecond) >= deadline, do: :timeout, else: {:exit, code}

        result(status, output, started, cleanup_group(group(output)), code)
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        {cleanup, status} = terminate(port, pid, group(output))
        result(:timeout, output, started, cleanup, status)
    end
  end

  defp read(port, pid, output, started, deadline) do
    owner_monitor = Process.get({__MODULE__, :owner_monitor})

    receive do
      {:DOWN, ^owner_monitor, :process, _, _} ->
        cancel_owner(port, pid, group(output))

      {^port, {:data, bytes}} ->
        read_buffer(port, pid, output <> bytes, started, deadline)

      {^port, {:exit_status, code}} ->
        drain(port)
        marker = marker(output)

        status =
          cond do
            System.monotonic_time(:millisecond) >= deadline -> :timeout
            code != 0 -> {:exit, code}
            marker -> :ok
            true -> :missing_marker
          end

        result(status, output, started, cleanup_group(group(output)), code)
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        {cleanup, exit_status} = terminate(port, pid, group(output))
        result(:timeout, output, started, cleanup, exit_status)
    end
  end

  defp read_buffer(port, pid, output, started, deadline) do
    cond do
      System.monotonic_time(:millisecond) >= deadline ->
        {cleanup, exit_status} = terminate(port, pid, group(output))
        result(:timeout, prefix(output), started, cleanup, exit_status)

      byte_size(output) >= @limit ->
        {cleanup, exit_status} = terminate(port, pid, group(output))
        result(:output_overflow, prefix(output), started, cleanup, exit_status)

      interrupt_ready?(port, output) ->
        # Only an explicit, complete checkpoint handshake permits a cut.
        # Cleanup targets the process group verified before stdin delivery.
        {cleanup, exit_status} = terminate(port, pid, group(output))
        result(:interrupted, output, started, cleanup, exit_status)

      true ->
        read(port, pid, output, started, deadline)
    end
  end

  defp interrupt_ready?(port, output) do
    complete_lines = output |> :binary.split("\n", [:global]) |> Enum.drop(-1)

    Port.info(port) != nil and
      Enum.all?(
        ["P815_STARTED", "P815_OPERATION", "P815_CHECKPOINT", "P815_INTERRUPT_READY"],
        &(&1 in complete_lines)
      )
  end

  defp terminate(port, supervisor_pid, group_pid) do
    signal_target(supervisor_pid, group_pid, "TERM")

    case await_exit(port, System.monotonic_time(:millisecond) + 1_000) do
      {:ok, code} -> {cleanup_group(group_pid), code}
      :timeout -> force_terminate(port, supervisor_pid, group_pid)
    end
  end

  defp cancel_owner(port, supervisor_pid, group_pid) do
    {cleanup, exit_status} = terminate(port, supervisor_pid, group_pid)

    if cleanup == :confirmed or (is_nil(group_pid) and is_integer(exit_status)),
      do: exit(:normal),
      else: exit(:cleanup_unconfirmed)
  end

  defp force_terminate(port, supervisor_pid, group_pid) do
    signal_target(supervisor_pid, group_pid, "KILL")

    case await_exit(port, System.monotonic_time(:millisecond) + 1_000) do
      {:ok, code} ->
        {cleanup_group(group_pid), code}

      :timeout ->
        if Port.info(port), do: Port.close(port)
        drain(port)
        {:unconfirmed, nil}
    end
  end

  defp signal_target(supervisor_pid, group_pid, signal_name) do
    if group_pid || supervisor_pid,
      do: signal(group_pid || supervisor_pid, signal_name, group_pid != nil)
  end

  defp signal(pid, signal, group?) do
    kill = System.find_executable("kill") || raise "kill unavailable"
    target = if group?, do: "-#{pid}", else: Integer.to_string(pid)
    System.cmd(kill, ["-s", signal, "--", target], stderr_to_stdout: true, env: [{"LC_ALL", "C"}])
  end

  defp cleanup_group(nil), do: :unconfirmed

  defp cleanup_group(pid) do
    case group_state(pid) do
      :absent ->
        :confirmed

      :unknown ->
        :unconfirmed

      :present ->
        stop_group(pid)
    end
  end

  defp stop_group(pid) do
    signal(pid, "TERM", true)

    if await_group(pid, System.monotonic_time(:millisecond) + 250) do
      :confirmed
    else
      signal(pid, "KILL", true)

      if await_group(pid, System.monotonic_time(:millisecond) + 1_000),
        do: :confirmed,
        else: :unconfirmed
    end
  end

  defp group_state(pid) do
    case signal(pid, "0", true) do
      {_, 0} -> :present
      {message, 1} -> if String.contains?(message, "No such process"), do: :absent, else: :unknown
      _ -> :unknown
    end
  end

  @doc false
  def external_stopped?(pid) when is_integer(pid) and pid > 1 do
    kill = System.find_executable("kill")

    if kill do
      case System.cmd(kill, ["-s", "0", "--", Integer.to_string(pid)],
             stderr_to_stdout: true,
             env: [{"LC_ALL", "C"}]
           ) do
        {message, 1} ->
          String.contains?(message, "No such process") and group_state(pid) == :absent

        _ ->
          false
      end
    else
      false
    end
  end

  defp await_group(pid, deadline) do
    cond do
      group_state(pid) == :absent ->
        true

      System.monotonic_time(:millisecond) >= deadline ->
        false

      true ->
        receive do
        after
          10 -> await_group(pid, deadline)
        end
    end
  end

  defp await_exit(port, deadline) do
    if System.monotonic_time(:millisecond) >= deadline do
      :timeout
    else
      receive do
        {^port, {:exit_status, code}} ->
          drain(port)
          {:ok, code}

        {^port, {:data, _}} ->
          await_exit(port, deadline)
      after
        max(deadline - System.monotonic_time(:millisecond), 0) -> :timeout
      end
    end
  end

  defp group(output) do
    case :binary.split(output, "\n") do
      ["P815_GROUP=" <> digits, _] ->
        case Integer.parse(digits) do
          {pid, ""} when pid > 1 -> pid
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp drain(port) do
    receive do
      {^port, _} -> drain(port)
    after
      0 -> :ok
    end
  end

  defp result(status, output, started, cleanup, exit_status) do
    lines = :binary.split(output, "\n", [:global])
    database_failures = database_failures(lines)

    %{
      status: status,
      marker: marker(output),
      elapsed_ms: System.monotonic_time(:millisecond) - started,
      exit_status: exit_status,
      cleanup: cleanup,
      started?: "P815_STARTED" in lines,
      operation?: "P815_OPERATION" in lines,
      checkpoint?: "P815_CHECKPOINT" in lines,
      connection_lost?: :lease_lost in database_failures or "P815_CONNECTION_LOST" in lines,
      database_failures: database_failures,
      budget_reports: Enum.flat_map(lines, &NewYou.Proof.RecoveryBudget.parse/1),
      lease_reports: Enum.flat_map(lines, &NewYou.Proof.RecoveryLease.parse/1),
      load_reports: Enum.flat_map(lines, &NewYou.Proof.RecoveryLoad.parse/1),
      rollback_checkpoint?: "P815_ROLLBACK_CHECKPOINT" in lines,
      failure_class: failure_class(lines),
      phases: phases(lines)
    }
  end

  defp phases(lines) do
    # Never return arbitrary child output, identifiers or exception messages.
    allowed = %{
      "P815_PHASE_TRANSACTION_ENTERED" => :transaction_entered,
      "P815_PHASE_ACCOUNT_LOCKED" => :account_locked,
      "P815_PHASE_RESUME_VERIFIED_CHANNEL" => :resume_verified_channel,
      "P815_PHASE_AWAIT_PROOF" => :await_proof,
      "P815_PHASE_AWAIT_PROOF_REJECTED" => :await_proof_rejected,
      "P815_PHASE_CHECKPOINT" => :checkpoint,
      "P815_PHASE_TRANSACTION_RETURNED" => :transaction_returned,
      "P815_PHASE_TRANSACTION_ERROR" => :transaction_error,
      "P815_PHASE_TRANSACTION_EXCEPTION" => :transaction_exception
    }

    Enum.flat_map(lines, fn line ->
      case Map.fetch(allowed, line) do
        {:ok, phase} -> [phase]
        :error -> []
      end
    end)
  end

  defp database_failures(lines) do
    allowed = %{
      "P815_DB_LEASE_LOST" => :lease_lost,
      "P815_DB_CHECKOUT_FAILED" => :checkout_failed,
      "P815_DB_CONNECTION_ERROR" => :connection_error,
      "P815_DB_DATABASE_CONFLICT" => :database_conflict,
      "P815_DB_CONSTRAINT_ERROR" => :constraint_error,
      "P815_DB_DATABASE_ERROR" => :database_error
    }

    for line <- lines, {:ok, category} <- [Map.fetch(allowed, line)], uniq: true, do: category
  end

  defp failure_class(lines) do
    cond do
      "P815_FAILURE_CLASS_DBConnection.ConnectionError" in lines -> :connection
      Enum.any?(lines, &String.starts_with?(&1, "P815_FAILURE_CLASS_")) -> :other
      true -> nil
    end
  end

  defp marker(output) do
    output |> :binary.split("\n", [:global]) |> Enum.find_value(&Map.get(@markers, &1))
  end

  defp prefix(output), do: binary_part(output, 0, min(byte_size(output), @limit - 1))
end
