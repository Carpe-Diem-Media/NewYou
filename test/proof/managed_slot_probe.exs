Code.require_file("managed_slot_control.exs", __DIR__)

defmodule NewYou.ManagedSlotProbe do
  @moduledoc false

  @markers ~w(
    DEVCORE_SLOT_PROJECT DEVCORE_SLOT_LEASE DEVCORE_SLOT_GENERATION
    DEVCORE_SLOT_JOB DEVCORE_SLOT_WORKTREE
  )
  @identifier ~r/\A[0-9a-f]{32}\z/
  @email ~r/\Aslot-proof-[0-9a-f]{32}@example\.test\z/
  @input_limit 2_048
  @barrier_timeout 300_000
  @child_timeout 120_000
  @prefix "MANAGED_SLOT_CHILD="

  def validate_environment(environment) when environment == :test, do: :ok
  def validate_environment(_), do: {:error, :test_environment_required}

  def validate_markers(markers) when is_map(markers) do
    complete? =
      Enum.all?(@markers, fn marker ->
        is_binary(Map.get(markers, marker)) and Map.get(markers, marker) != ""
      end)

    identifiers? =
      Enum.all?(["DEVCORE_SLOT_LEASE", "DEVCORE_SLOT_GENERATION", "DEVCORE_SLOT_JOB"], fn key ->
        Regex.match?(@identifier, Map.get(markers, key, ""))
      end)

    path? = Path.type(Map.get(markers, "DEVCORE_SLOT_WORKTREE", "")) == :absolute

    if complete? and identifiers? and markers["DEVCORE_SLOT_PROJECT"] == "new_you" and path?,
      do: :ok,
      else: {:error, :managed_markers_required}
  end

  def validate_markers(_), do: {:error, :managed_markers_required}

  def validate_input(input) when is_map(input) do
    own = input["own_email"]
    peer = input["peer_email"]
    mode = input["mode"]

    allowed_keys = [
      "own_email",
      "peer_email",
      "mode",
      "browser",
      "fail_after_commit",
      "control_directory"
    ]

    keys_allowed? = Enum.all?(Map.keys(input), &(&1 in allowed_keys))

    seed_mode? =
      mode == "seed" or (input["browser"] != true and input["fail_after_commit"] != true)

    directory = input["control_directory"]
    control? = mode == "child" or (is_binary(directory) and Path.type(directory) == :absolute)

    if control? and keys_allowed? and seed_mode? and valid_email?(own) and valid_email?(peer) and
         own != peer and
         mode in ["seed", "empty", "child"] do
      {:ok,
       %{
         own_email: own,
         peer_email: peer,
         mode: String.to_atom(mode),
         browser?: input["browser"] == true,
         fail_after_commit?: input["fail_after_commit"] == true,
         control_directory: directory
       }}
    else
      {:error, :invalid_probe_input}
    end
  end

  def validate_input(_), do: {:error, :invalid_probe_input}

  def validate_continue(input, own_database) when is_map(input) do
    peer_database = input["peer_database"]

    if Map.keys(input) |> Enum.sort() == ["continue", "peer_database"] and
         input["continue"] == true and valid_slot_database?(peer_database) and
         peer_database != own_database do
      {:ok, peer_database}
    else
      {:error, :invalid_barrier_input}
    end
  end

  def validate_continue(_, _), do: {:error, :invalid_barrier_input}

  def main(args \\ System.argv()) do
    with :ok <- validate_environment(Mix.env()),
         :ok <- validate_markers(managed_markers()),
         {:ok, input} <- read_input(),
         {:ok, probe} <- validate_input(input),
         {:ok, receipt} <- verified_receipt() do
      if probe.mode == :seed, do: configure_probe_crypto()
      execute_with_checkout(args, probe, receipt)
    else
      {:error, :test_environment_required} -> fail(:test_environment_required)
      {:error, :managed_markers_required} -> fail(:managed_markers_required)
      _ -> fail(:preflight_failed)
    end
  rescue
    _ -> fail(:probe_failed)
  end

  defp execute_with_checkout(args, probe, receipt) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

    try do
      execute(args, probe, receipt)
    after
      :ok = Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
    end
  end

  defp execute(args, %{mode: :child} = probe, receipt) do
    ensure_child_args!(args)
    counts = account_counts(probe)
    emit(@prefix, Map.merge(receipt, counts))
    acknowledge!("child", receipt)
    :ok
  end

  defp execute(_args, %{mode: :empty} = probe, receipt) do
    counts = account_counts(probe)
    require_counts!(counts, own: 0, peer: 0)
    publish!(probe, "empty", Map.merge(receipt, counts))
    acknowledge!("empty", receipt)
    :ok
  end

  defp execute(_args, %{mode: :seed} = probe, receipt) do
    adapters = %{
      prepare: &prepare_seed/1,
      finish: &finish_seed/2
    }

    run_seed(probe, receipt, adapters)
  end

  defp prepare_seed(probe) do
    before = account_counts(probe)
    require_counts!(before, own: 0, peer: 0)
    request = seed!(probe)
    after_seed = account_counts(probe)
    require_counts!(after_seed, own: 1, peer: 0)

    if probe.browser?, do: browser_login!(request)

    after_seed
  end

  @doc false
  def run_seed(probe, receipt, adapters, timeout \\ @barrier_timeout) do
    after_seed = adapters.prepare.(probe)
    publish!(probe, "ready", Map.merge(receipt, after_seed))
    acknowledgement = acknowledge!("ready", receipt, timeout)

    {:ok, peer_database} =
      validate_continue(
        %{"continue" => true, "peer_database" => acknowledgement["peer_database"]},
        receipt["database"]
      )

    :ok = adapters.finish.(probe, {receipt, peer_database})
    final = after_seed

    publish!(
      probe,
      "done",
      Map.merge(
        receipt,
        Map.merge(final, %{"cross_slot_denied" => true, "legacy_denied" => true})
      )
    )

    # Both peer databases must survive until each has completed its connection
    # denial checks. A final controller acknowledgement releases this barrier.
    acknowledge!("done", receipt, timeout)

    if probe.fail_after_commit?, do: run_retained_failure_test!()
    :ok
  end

  defp finish_seed(probe, {receipt, peer_database}) do
    final = account_counts(probe)
    require_counts!(final, own: 1, peer: 0)

    children = [
      run_child!(probe, Map.merge(receipt, final)),
      run_child!(probe, Map.merge(receipt, final))
    ]

    unless Enum.all?(children, &(&1 == Map.merge(receipt, final))),
      do: fail(:child_receipt_mismatch)

    verify_cross_slot_denial!(receipt["database"], peer_database, receipt["role"])

    :ok
  end

  defp run_retained_failure_test! do
    ExUnit.start(autorun: false)

    Code.compile_string("""
    defmodule NewYou.ManagedSlotProbe.RetainedFailureTest do
      use ExUnit.Case, async: false

      test "reports the seeded fixture failure for managed lease retention" do
        assert 1 == 0
      end
    end
    """)

    %{failures: failures} = ExUnit.run()
    if failures > 0, do: System.halt(1)
  end

  defp verified_receipt do
    config = NewYou.LocalConfig.repo(:test)

    with {:ok, _version} <- NewYou.Proof.Result.capture_postgresql(),
         true <- safe_config?(config) do
      markers = managed_markers()

      receipt =
        %{
          "lease" => markers["DEVCORE_SLOT_LEASE"],
          "generation" => markers["DEVCORE_SLOT_GENERATION"],
          "job" => markers["DEVCORE_SLOT_JOB"],
          "worktree" => markers["DEVCORE_SLOT_WORKTREE"],
          "database" => Keyword.fetch!(config, :database),
          "role" => Keyword.fetch!(config, :username)
        }

      if NewYou.ManagedSlotControl.valid_identity?(receipt),
        do: {:ok, receipt},
        else: {:error, :database_preflight_failed}
    else
      _ -> {:error, :database_preflight_failed}
    end
  rescue
    _ -> {:error, :database_preflight_failed}
  end

  defp safe_config?(config) do
    repo_config = NewYou.Repo.config()

    Enum.all?([:hostname, :port, :database, :username], fn key ->
      Keyword.get(config, key) == Keyword.get(repo_config, key)
    end) and Keyword.get(config, :database) =~ ~r/\Adc_new_you_s\d{2}_g[0-9a-f]{32}\z/
  end

  defp seed!(probe) do
    request = NewYou.Proof.P805.request(%{email: probe.own_email})

    with {:ok, registration} <- NewYou.Identity.register(request),
         {:ok, :verified} <- NewYou.Identity.verify_email(registration.verification_proof) do
      request
    else
      _ -> fail(:registration_failed)
    end
  end

  defp configure_probe_crypto do
    Application.put_env(:new_you, :identity_registration_binding_keys, %{
      active_version: "managed-slot-proof-v1",
      keys: %{"managed-slot-proof-v1" => :crypto.strong_rand_bytes(32)}
    })

    Application.put_env(:new_you, :identity_token_signing_secret, :crypto.strong_rand_bytes(32))

    Application.put_env(:new_you, :communications_keyring, %{
      active: "managed-slot-proof-v1",
      keys: %{"managed-slot-proof-v1" => :crypto.strong_rand_bytes(32)}
    })
  end

  defp account_counts(probe) do
    %{
      "own_count" => count_accounts(probe.own_email),
      "peer_count" => count_accounts(probe.peer_email)
    }
  rescue
    _ -> fail(:account_read_failed)
  end

  defp count_accounts(email) do
    NewYou.Identity.Account
    |> Ash.Query.filter_input(%{email: %{eq: email}})
    |> Ash.read!(authorize?: false)
    |> length()
  end

  defp browser_login!(request) do
    previous = Application.get_env(:new_you, :p8_08_browser_development_fixtures)
    Application.put_env(:new_you, :p8_08_browser_development_fixtures, true)

    try do
      checks = NewYou.Proof.P805Browser.run_login(request, "en")

      unless Enum.all?(~w(login_form protected_access reloaded_access), fn key ->
               checks[key] == true
             end) do
        fail(:browser_proof_failed)
      end
    after
      if previous == nil,
        do: Application.delete_env(:new_you, :p8_08_browser_development_fixtures),
        else: Application.put_env(:new_you, :p8_08_browser_development_fixtures, previous)
    end
  end

  defp run_child!(probe, expected) do
    executable = System.find_executable("mise") || fail(:child_runtime_unavailable)
    script = Path.expand("managed_slot_probe.exs", __DIR__)

    input =
      Jason.encode!(%{own_email: probe.own_email, peer_email: probe.peer_email, mode: "child"}) <>
        "\n"

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        :use_stdio,
        :hide,
        :stderr_to_stdout,
        args: ["exec", "--", "mix", "run", script, "--child"]
      ])

    true = Port.command(port, input)
    collect_child(port, "", System.monotonic_time(:millisecond) + @child_timeout, expected)
  rescue
    _ -> fail(:child_probe_failed)
  end

  @doc false
  @spec collect_child(port(), binary(), integer(), map()) :: map()
  def collect_child(port, output, deadline, expected) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {^port, {:data, data}} when byte_size(output) + byte_size(data) <= 16_384 ->
        case child_receipt(output <> data) do
          {:ok, receipt} ->
            unless receipt == expected, do: fail(:child_receipt_mismatch)

            true =
              Port.command(
                port,
                Jason.encode!(%{
                  "ack" => "child",
                  "identity" => NewYou.ManagedSlotControl.identity(receipt)
                }) <> "\n"
              )

            await_child_exit(
              port,
              receipt,
              deadline,
              byte_size(output) + byte_size(data)
            )

          :pending ->
            collect_child(port, output <> data, deadline, expected)
        end

      {^port, {:data, _data}} ->
        Port.close(port)
        fail(:child_output_too_large)

      {^port, {:exit_status, 0}} ->
        fail(:child_receipt_missing)

      {^port, {:exit_status, _}} ->
        fail(:child_probe_failed)
    after
      remaining ->
        Port.close(port)
        fail(:child_probe_timeout)
    end
  end

  defp await_child_exit(port, receipt, deadline, bytes) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    if remaining == 0 do
      Port.close(port)
      fail(:child_probe_timeout)
    end

    receive do
      {^port, {:data, data}} when bytes + byte_size(data) <= 16_384 ->
        await_child_exit(port, receipt, deadline, bytes + byte_size(data))

      {^port, {:data, _data}} ->
        Port.close(port)
        fail(:child_output_too_large)

      {^port, {:exit_status, status}} ->
        case NewYou.ManagedSlotControl.child_result(status, receipt) do
          {:ok, value} -> value
          _ -> fail(:child_probe_failed)
        end
    after
      remaining ->
        Port.close(port)
        fail(:child_probe_timeout)
    end
  end

  defp child_receipt(output) do
    case Regex.run(~r/^MANAGED_SLOT_CHILD=(\{[^\n]{1,2048}\})$/m, output, capture: :all_but_first) do
      [json] ->
        case Jason.decode(json) do
          {:ok, receipt} -> {:ok, receipt}
          _ -> :pending
        end

      _ ->
        :pending
    end
  end

  defp publish!(probe, phase, receipt) do
    case NewYou.ManagedSlotControl.publish(probe.control_directory, phase, Jason.encode!(receipt)) do
      :ok -> :ok
      _ -> fail(:control_write_failed)
    end
  end

  defp acknowledge!(phase, receipt, timeout \\ @barrier_timeout) do
    with {:ok, line} <-
           NewYou.ManagedSlotControl.await(
             fn -> NewYou.ManagedSlotControl.read_line() end,
             timeout
           ),
         {:ok, value} <- Jason.decode(line),
         :ok <- NewYou.ManagedSlotControl.acknowledge(value, phase, receipt) do
      value
    else
      _ -> fail(:acknowledgement_failed)
    end
  end

  defp verify_cross_slot_denial!(own_database, peer_database, role) do
    config = NewYou.Repo.config()
    password = Keyword.fetch!(config, :password)
    endpoint = ["--host=127.0.0.1", "--port=55433", "--username=" <> role]

    case psql(endpoint ++ ["--dbname=" <> own_database, "--command=SELECT 1"], password) do
      {"1\n", 0} -> :ok
      _ -> fail(:own_database_psql_failed)
    end

    unless permission_denied?(
             psql(endpoint ++ ["--dbname=" <> peer_database, "--command=SELECT 1"], password)
           ),
           do: fail(:cross_slot_boundary_failed)

    unless permission_denied?(
             psql(endpoint ++ ["--dbname=new_you_test", "--command=SELECT 1"], password)
           ),
           do: fail(:legacy_boundary_failed)
  end

  defp psql(args, password) do
    executable = System.find_executable("psql") || fail(:psql_unavailable)
    psql_probe(executable, args, password)
  end

  @doc false
  def psql_probe(executable, args, password) do
    System.cmd(
      executable,
      ["--no-psqlrc", "--no-password", "--no-align", "--tuples-only"] ++ args,
      env: [
        {"PGPASSWORD", password},
        {"PGCONNECT_TIMEOUT", "5"},
        {"PGOPTIONS", "-c statement_timeout=5000"},
        {"LC_ALL", "C"}
      ],
      stderr_to_stdout: true
    )
  rescue
    _ -> fail(:psql_failed)
  end

  defp permission_denied?({output, 2}),
    do: String.contains?(output, "permission denied for database")

  defp permission_denied?(_), do: false

  defp valid_slot_database?(database),
    do: is_binary(database) and Regex.match?(~r/\Adc_new_you_s\d{2}_g[0-9a-f]{32}\z/, database)

  @doc false
  def read_input(device \\ :stdio, timeout \\ @barrier_timeout) do
    with {:ok, input} <-
           NewYou.ManagedSlotControl.await(
             fn -> NewYou.ManagedSlotControl.bounded_line(device, @input_limit) end,
             timeout
           ),
         do: Jason.decode(input)
  rescue
    _ -> {:error, :invalid_json}
  end

  defp managed_markers, do: Map.new(@markers, &{&1, System.get_env(&1)})

  defp require_counts!(counts, expected) do
    if counts["own_count"] != expected[:own] or counts["peer_count"] != expected[:peer],
      do: fail(:unexpected_account_counts),
      else: :ok
  end

  defp ensure_child_args!(args) do
    unless args == ["--child"], do: fail(:invalid_child_invocation)
  end

  defp valid_email?(email), do: is_binary(email) and Regex.match?(@email, email)

  @doc false
  def emit(prefix, receipt) do
    IO.puts(prefix <> Jason.encode!(receipt))
  end

  defp fail(reason) do
    IO.puts(:stderr, "MANAGED_SLOT_ERROR=#{reason}")
    System.halt(2)
  end
end

unless Process.get(:managed_slot_probe_test_load, false) do
  NewYou.ManagedSlotProbe.main()
end
