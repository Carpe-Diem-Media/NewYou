defmodule NewYou.Proof.P805 do
  @moduledoc """
  Deterministic WELL-53 callbacks. All business mutations use production owners.
  SQL is limited to observation, scoped fault DDL and synthetic-fixture teardown.
  Accepted cases use unboxed connections so the owner's real COMMIT executes.
  """
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Audit, Communications, Identity, Repo}
  alias NewYou.Proof.{CutPoints, Scenario, SelfTest, RegistrationSeam, P805Fixture}

  require Ash.Query

  @terms "NEWYOU-TERMS-EN-DEV-2026-10-27-001"
  @privacy "NEWYOU-PRIVACY-EN-DEV-2026-10-27-001"
  @tables ~w(accounts tokens registration_operations resend_operations message_intents communications_protected_envelopes communications_envelope_nonces evidence_obligations oban_jobs identity_pmr_reservations identity_grants privacy_purpose_authorities privacy_purpose_events commerce_payment_consequences)
  @environment ~w(fp001_development_entry identity_registration_binding_keys identity_token_signing_secret identity_mfa_keyring communications_keyring p8_05_browser_development_fixtures p8_07_browser_development_fixtures p8_09_browser_development_fixtures p8_08_browser_development_fixtures p8_12_browser_development_fixtures p8_15_browser_development_fixtures identity_pmr_generator)a

  def run(case_id), do: with_fixture(fn -> execute(case_id) end)

  @doc false
  def with_fixture(callback) when is_function(callback, 0) do
    NewYou.Proof.FixtureObservation.with_scope(fn -> fixture(callback) end)
  end

  defp fixture(callback) do
    projection_key = "p817_test_" <> Ecto.UUID.generate()
    previous_projection_key = Process.get({NewYou.Analytics, :p817_test_projection_key}, :missing)
    cleanup_hook = Process.get({__MODULE__, :fixture_cleanup_hook})
    fixture = P805Fixture.acquire(@environment, projection_key, cleanup_hook)
    Process.put({__MODULE__, :fixture}, fixture)

    outcome =
      try do
        Process.put({NewYou.Analytics, :p817_test_projection_key}, projection_key)
        Process.put({__MODULE__, :operations}, [])
        Process.put({__MODULE__, :emails}, [])
        Process.put({__MODULE__, :fault_names}, [])
        SelfTest.cleanup_manifest!(connections_released: false, locks_released: false)
        {guardian, guardian_monitor} = start_fixture_guardian(fixture)
        :ok = P805Fixture.attach(fixture, guardian)

        Process.put({__MODULE__, :guardian}, guardian)
        Process.put({__MODULE__, :guardian_monitor}, guardian_monitor)
        configure()
        fixture_setup_checkpoint(:configured)
        fixture_setup_checkpoint(:guardian_started)
        :ok = NewYou.Proof.Scenario.register_cleanup_guardian(guardian)
        :ok = Sandbox.checkout(Repo, sandbox: false)
        Process.put({__MODULE__, :fixture_checked_out}, true)
        fixture_setup_checkpoint(:sandbox_checked_out)
        Process.put({__MODULE__, :consequence_baseline}, capture_consequence_ids())
        {:returned, callback.()}
      catch
        kind, reason -> {:raised, kind, reason, __STACKTRACE__}
      end

    cleanup_result =
      try do
        finish_fixture(fixture, projection_key, previous_projection_key)
      catch
        _, _ -> :unconfirmed
      end

    case outcome do
      {:returned, value} when cleanup_result == :confirmed ->
        value

      {:returned, _value} ->
        raise "P8-05 fixture cleanup unconfirmed"

      {:raised, kind, reason, stacktrace} when cleanup_result == :confirmed ->
        :erlang.raise(kind, reason, stacktrace)

      {:raised, _, _, _} ->
        raise "P8-05 fixture cleanup unconfirmed after callback failure"
    end
  end

  defp configure do
    Application.put_env(:new_you, :identity_registration_binding_keys, %{
      active_version: "proof-v1",
      keys: %{"proof-v1" => :crypto.strong_rand_bytes(32)}
    })

    Application.put_env(:new_you, :identity_token_signing_secret, :crypto.strong_rand_bytes(32))

    Application.put_env(:new_you, :communications_keyring, %{
      active: "proof-v1",
      keys: %{"proof-v1" => :crypto.strong_rand_bytes(32)}
    })

    Application.put_env(:new_you, :p8_05_browser_development_fixtures, true)
    Application.put_env(:new_you, :p8_07_browser_development_fixtures, "p8-07-temporary-v1")
    Application.put_env(:new_you, :p8_09_browser_development_fixtures, true)
    Application.put_env(:new_you, :p8_08_browser_development_fixtures, true)
    Application.put_env(:new_you, :p8_12_browser_development_fixtures, true)
    Application.put_env(:new_you, :p8_15_browser_development_fixtures, true)
  end

  defp fixture_setup_checkpoint(stage) do
    case Process.get({__MODULE__, :setup_checkpoint}) do
      callback when is_function(callback, 1) -> callback.(stage)
      _ -> :ok
    end
  end

  defp finish_fixture(fixture, projection_key, previous_projection_key) do
    clear_fixture_execution_state()
    checked_out? = fixture_checked_out?()
    guardian = Process.get({__MODULE__, :guardian})
    guardian_monitor = Process.get({__MODULE__, :guardian_monitor})

    cleanup_result =
      attempt_fixture_cleanup(
        checked_out?,
        projection_key,
        guardian,
        guardian_monitor,
        fixture,
        previous_projection_key
      )

    record_fixture_cleanup(checked_out?, cleanup_result)
    cleanup_result
  end

  defp clear_fixture_execution_state do
    Process.delete({__MODULE__, :consequence_baseline})
    Process.delete(RegistrationSeam)
  end

  defp fixture_checked_out?, do: Process.delete({__MODULE__, :fixture_checked_out}) == true

  defp attempt_fixture_cleanup(
         checked_out?,
         projection_key,
         guardian,
         guardian_monitor,
         fixture,
         previous_projection_key
       ) do
    :ok = P805Fixture.settling(fixture)
    workers = await_registered_workers(guardian, guardian_monitor)

    cleanup = fn target ->
      perform_fixture_cleanup(checked_out?, projection_key, target)
      :ok
    end

    if workers == :pending do
      :ok = P805Fixture.quarantine(fixture)
      :unconfirmed
    else
      case P805Fixture.finish(fixture, cleanup) do
        :ok ->
          worker_cleanup_result(workers)

        {:error, :cleanup_failed} ->
          recover_fixture_cleanup(checked_out?, guardian, guardian_monitor)

        {:error, _} ->
          :unconfirmed
      end
    end
  rescue
    _ -> recover_fixture_cleanup(checked_out?, guardian, guardian_monitor)
  catch
    _, _ -> recover_fixture_cleanup(checked_out?, guardian, guardian_monitor)
  after
    restore_fixture_runtime(guardian, guardian_monitor, fixture, previous_projection_key)
  end

  defp worker_cleanup_result(:confirmed), do: :confirmed
  defp worker_cleanup_result(_), do: :unconfirmed

  defp perform_fixture_cleanup(true, projection_key, fixture) do
    # Teardown needs its own live connection if a cancelled worker
    # disconnected the borrowed lease.
    names = Process.get({__MODULE__, :fault_names}, [])

    Sandbox.unboxed_run(Repo, fn ->
      cleanup_fixture_rows(fixture, projection_key)

      Process.delete({__MODULE__, :operations})
      Process.delete({__MODULE__, :emails})
      false = Repo.in_transaction?()
      0 = scalar("SELECT count(*) FROM pg_trigger WHERE tgname = ANY($1::text[])", [names])
    end)
  end

  defp perform_fixture_cleanup(false, _projection_key, _fixture) do
    Process.delete({__MODULE__, :operations})
    Process.delete({__MODULE__, :emails})
  end

  defp recover_fixture_cleanup(true, guardian, monitor)
       when is_pid(guardian) and is_reference(monitor),
       do: recover_fixture_guardian(guardian)

  defp recover_fixture_cleanup(_checked_out?, _guardian, _monitor), do: :unconfirmed

  defp restore_fixture_runtime(guardian, guardian_monitor, fixture, previous_projection_key) do
    if P805Fixture.active?(fixture) do
      :ok = P805Fixture.quarantine(fixture)
      if is_pid(guardian), do: send(guardian, :contain_fixture)
    else
      if is_pid(guardian) and is_reference(guardian_monitor),
        do: stop_fixture_guardian(guardian, guardian_monitor)
    end
  after
    restore_process_value({NewYou.Analytics, :p817_test_projection_key}, previous_projection_key)
    Process.delete({__MODULE__, :fixture})
    Process.delete({__MODULE__, :guardian})
    Process.delete({__MODULE__, :guardian_monitor})
    Process.delete({__MODULE__, :setup_checkpoint})
    Process.delete({__MODULE__, :fault_names})
  end

  defp record_fixture_cleanup(_checked_out?, cleanup_result) do
    confirmed? = cleanup_result == :confirmed
    SelfTest.cleanup_manifest!(connections_released: confirmed?, locks_released: confirmed?)
  end

  defp recover_fixture_guardian(guardian) do
    reference = make_ref()
    send(guardian, {:recover_fixture, self(), reference})

    receive do
      {:fixture_recovered, ^reference, :ok} ->
        :confirmed

      {:fixture_recovered, ^reference, :pending} ->
        :unconfirmed

      {:fixture_recovered, ^reference, _failure} ->
        :unconfirmed
    after
      15_000 ->
        send(guardian, :contain_fixture)
        :unconfirmed
    end
  end

  defp restore_process_value(key, :missing), do: Process.delete(key)
  defp restore_process_value(key, value), do: Process.put(key, value)

  def request(overrides \\ %{}) do
    operation_id = Ecto.UUID.generate()

    request =
      Map.merge(
        %{
          operation_id: operation_id,
          first_name: "Proof",
          surname: "Participant",
          email: "proof-#{operation_id}@example.test",
          password: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false),
          preferred_language: :af,
          confirmed_age_18?: true,
          terms_version_id: @terms,
          privacy_version_id: @privacy
        },
        overrides
      )

    track(request)
    request
  end

  # The worker uses the owner's environment lease but a distinct connection,
  # observation scope and cleanup identities. Record its identities in the
  # lease as a fallback if the worker terminates before its own teardown.
  def independent_fixture_task(callback) when is_function(callback, 0) do
    fixture = Process.get({__MODULE__, :fixture})
    true = P805Fixture.owned?(fixture)
    owner = self()
    reference = make_ref()

    task =
      Task.async(fn ->
        receive do
          {^owner, ^reference} ->
            run_independent_fixture(fixture, callback)
        end
      end)

    :ok = register_cleanup_worker(task.pid)
    send(task.pid, {owner, reference})
    task
  end

  defp run_independent_fixture(fixture, callback) do
    Process.put({__MODULE__, :cleanup_fallback}, fixture)
    projection_key = "p817_test_" <> Ecto.UUID.generate()
    :ok = P805Fixture.track(fixture, :foreign_projection, projection_key)
    Process.put({NewYou.Analytics, :p817_test_projection_key}, projection_key)

    NewYou.Proof.FixtureObservation.with_scope(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        try do
          callback.()
        after
          cleanup(projection_key)
        end
      end)
    end)
  end

  def track_operation(operation), do: track(%{operation_id: operation})

  defp track(request) do
    guardian = Process.get({__MODULE__, :guardian})

    if is_pid(guardian) do
      register_fixture_value(guardian, :operation, request.operation_id)
    end

    if fallback = Process.get({__MODULE__, :cleanup_fallback}) do
      :ok = P805Fixture.track(fallback, :foreign_operation, request.operation_id)

      if request[:email] do
        {:ok, email} = Identity.Email.canonicalize(request.email)
        :ok = P805Fixture.track(fallback, :foreign_email, email)
      end
    end

    Process.put({__MODULE__, :operations}, [
      request.operation_id | Process.get({__MODULE__, :operations}, [])
    ])

    if is_binary(request[:email]) do
      {:ok, email} = Identity.Email.canonicalize(request.email)
      if is_pid(guardian), do: register_fixture_value(guardian, :email, email)
      Process.put({__MODULE__, :emails}, [email | Process.get({__MODULE__, :emails}, [])])
    end
  end

  defp register_fixture_value(guardian, kind, value) do
    reference = make_ref()
    send(guardian, {:track, self(), reference, kind, value})

    receive do
      {:fixture_tracked, ^reference} -> :ok
    after
      5_000 -> raise "P8-05 fixture guardian did not register fixture identity"
    end
  end

  defp start_fixture_guardian(fixture) do
    owner = self()
    launch_checkpoint = Process.get({__MODULE__, :launch_checkpoint})

    spawn_monitor(fn ->
      Process.flag(:trap_exit, true)
      owner_monitor = Process.monitor(owner)

      state = %{
        fixture: fixture,
        owner: owner,
        owner_monitor: owner_monitor,
        monitors: %{},
        failed?: false,
        launch_checkpoint: launch_checkpoint,
        ports: %{}
      }

      fixture_guardian(state)
    end)
  end

  @doc false
  def register_cleanup_worker(worker) when is_pid(worker) do
    guardian = Process.get({__MODULE__, :guardian})

    if is_pid(guardian) do
      reference = make_ref()
      send(guardian, {:track_cleanup_worker, self(), reference, worker})

      receive do
        {:cleanup_worker_tracked, ^reference} -> :ok
      after
        5_000 -> raise "P8-05 fixture guardian did not register cleanup worker"
      end
    else
      :ok
    end
  end

  @doc false
  def open_restart_port(guardian, executable, options) when is_pid(guardian) do
    reference = make_ref()
    send(guardian, {:open_restart_port, self(), reference, executable, options})

    receive do
      {:restart_port, ^reference, result} -> result
    after
      5_000 -> {:error, :unconfirmed}
    end
  end

  @doc "Safe diagnostic view of the current TEST fixture's retained synthetic scope."
  def fixture_status, do: P805Fixture.info()

  @doc "Reconcile the exact quarantined fixture only after recorded workers and OS groups have stopped."
  def reconcile_fixture(reference) when is_reference(reference) do
    guardian =
      case P805Fixture.info() do
        %{reference: ^reference, guardian: guardian} -> guardian
        _ -> nil
      end

    result = P805Fixture.reconcile(reference, &cleanup_retained_fixture/1)
    if result == :ok and is_pid(guardian), do: send(guardian, :fixture_reconciled)
    result
  end

  defp cleanup_retained_fixture(fixture) do
    Sandbox.unboxed_run(Repo, fn ->
      cleanup_fixture_rows(fixture, fixture.projection_key)
      :ok = SelfTest.cleanup_manifest!(connections_released: true, locks_released: true)
    end)
  end

  defp cleanup_fixture_rows(fixture, projection_key) do
    cleanup(
      fixture.operations ++ fixture.foreign_operations,
      fixture.emails ++ fixture.foreign_emails,
      projection_key,
      fixture.cleanup_hook
    )

    Enum.each(fixture.foreign_projections, fn key ->
      :ok = cleanup_test_oban_queue(key)
      :ok = cleanup_test_analytics_projection(key)
    end)
  end

  defp await_registered_workers(guardian, monitor)
       when is_pid(guardian) and is_reference(monitor) do
    reference = make_ref()
    send(guardian, {:await_cleanup_workers, self(), reference})

    receive do
      {:cleanup_workers_finished, ^reference, result} ->
        result

      {:DOWN, ^monitor, :process, ^guardian, _} = event ->
        send(self(), event)
        :unconfirmed
    after
      5_000 -> :pending
    end
  end

  defp await_registered_workers(_, _), do: :confirmed

  defp stop_fixture_guardian(guardian, monitor) do
    send(guardian, :fixture_complete)

    receive do
      {:DOWN, ^monitor, :process, ^guardian, _reason} -> :ok
    after
      10_000 -> raise "P8-05 fixture guardian did not stop"
    end
  end

  defp fixture_guardian(state) do
    receive do
      {:track_cleanup_worker, owner, reference, worker} when owner == state.owner ->
        :ok = P805Fixture.worker(state.fixture, worker)
        monitor = Process.monitor(worker)
        send(owner, {:cleanup_worker_tracked, reference})
        fixture_guardian(%{state | monitors: Map.put(state.monitors, monitor, worker)})

      {:open_restart_port, worker, reference, executable, options} ->
        {result, state} = open_tracked_port(state, worker, executable, options)
        send(worker, {:restart_port, reference, result})
        fixture_guardian(state)

      {:await_cleanup_workers, owner, reference} when owner == state.owner ->
        {result, state} = wait_fixture_workers(state, System.monotonic_time(:millisecond) + 4_000)
        send(owner, {:cleanup_workers_finished, reference, result})
        fixture_guardian(state)

      {:track, owner, reference, kind, value} when owner == state.owner ->
        :ok = P805Fixture.track(state.fixture, kind, value)
        send(owner, {:fixture_tracked, reference})
        fixture_guardian(state)

      {:fixture_values, owner, reference} when owner == state.owner ->
        fixture = P805Fixture.info()
        send(owner, {:fixture_values, reference, fixture.operations, fixture.emails})
        fixture_guardian(state)

      {:recover_fixture, owner, reference} when owner == state.owner ->
        {result, state} = wait_fixture_workers(state, System.monotonic_time(:millisecond) + 4_000)
        recovered = if result == :pending, do: :pending, else: settle_retained_fixture(state)
        send(owner, {:fixture_recovered, reference, recovered})
        fixture_guardian(state)

      :contain_fixture ->
        contain_fixture_workers(state)

      :fixture_reconciled ->
        :ok

      :fixture_complete ->
        if P805Fixture.active?(state.fixture), do: contain_fixture_workers(state), else: :ok

      {:DOWN, monitor, :process, owner, _reason}
      when monitor == state.owner_monitor and owner == state.owner ->
        contain_fixture_workers(state)

      {:DOWN, monitor, :process, _worker, reason} ->
        fixture_guardian(record_fixture_worker_down(state, monitor, reason))

      {port, _event} = event when is_port(port) ->
        if worker = state.ports[port], do: send(worker, event)
        fixture_guardian(state)

      {:EXIT, _port, _reason} ->
        fixture_guardian(state)
    end
  end

  defp open_tracked_port(state, worker, executable, options) do
    with true <- worker in Map.values(state.monitors) and Process.alive?(state.owner),
         {:ok, launch} <- P805Fixture.begin_external(state.fixture) do
      open_reserved_port(state, worker, launch, executable, options)
    else
      _ -> {{:error, :unconfirmed}, state}
    end
  rescue
    _ -> {{:error, :unconfirmed}, state}
  catch
    _, _ -> {{:error, :unconfirmed}, state}
  end

  defp open_reserved_port(state, worker, launch, executable, options) do
    case open_external_port(executable, options) do
      {:ok, port} ->
        :ok = P805Fixture.opened(state.fixture, launch, port)
        launch_checkpoint(state, :opened, port)
        {:os_pid, pid} = Port.info(port, :os_pid)
        :ok = P805Fixture.port(state.fixture, launch, port, pid)
        {:ok, ^port} = transfer_fixture_port(port, worker)
        :ok = P805Fixture.settle_external(state.fixture, launch, :started)
        {{:ok, port}, %{state | ports: Map.put(state.ports, port, worker)}}

      {:error, :not_started} ->
        :ok = P805Fixture.settle_external(state.fixture, launch, :not_started)
        {{:error, :not_started}, state}
    end
  end

  defp open_external_port(executable, options) do
    {:ok, Port.open({:spawn_executable, executable}, options)}
  rescue
    # Synchronous validation and missing/non-executable files prove no child started.
    # Exceptions in later registration/transfer must retain this reservation.
    ArgumentError ->
      {:error, :not_started}

    error in ErlangError ->
      if error.original in [:enoent, :eacces],
        do: {:error, :not_started},
        else: reraise(error, __STACKTRACE__)
  end

  defp launch_checkpoint(state, stage, port) do
    if is_function(state.launch_checkpoint, 2), do: state.launch_checkpoint.(stage, port)
  end

  defp transfer_fixture_port(port, worker) do
    true = Port.connect(port, worker)
    Process.unlink(port)
    {:ok, port}
  rescue
    _ ->
      if Port.info(port), do: Port.close(port)
      :error
  end

  defp record_fixture_worker_down(state, monitor, reason) do
    if Map.has_key?(state.monitors, monitor) do
      %{
        state
        | monitors: Map.delete(state.monitors, monitor),
          failed?: state.failed? or reason != :normal
      }
    else
      state
    end
  end

  defp wait_fixture_workers(state, deadline) do
    if map_size(state.monitors) == 0 do
      {if(state.failed?, do: :unconfirmed, else: :confirmed), state}
    else
      receive do
        {:DOWN, monitor, :process, _worker, reason} when is_map_key(state.monitors, monitor) ->
          wait_fixture_workers(record_fixture_worker_down(state, monitor, reason), deadline)

        {:open_restart_port, worker, reference, _executable, _options} ->
          send(worker, {:restart_port, reference, {:error, :unconfirmed}})
          wait_fixture_workers(state, deadline)
      after
        max(deadline - System.monotonic_time(:millisecond), 0) -> {:pending, state}
      end
    end
  end

  defp settle_retained_fixture(state) do
    case P805Fixture.finish(state.fixture, &cleanup_retained_fixture/1) do
      :ok -> :ok
      {:error, _} -> :unconfirmed
    end
  end

  defp contain_fixture_workers(state) do
    failed_cleanup? = match?(%{quarantine_reason: :cleanup_failed}, P805Fixture.info())

    case P805Fixture.quarantine(state.fixture) do
      :ok -> contain_active_fixture_workers(state, failed_cleanup?)
      {:error, :stale_fixture} -> :ok
    end
  end

  defp contain_active_fixture_workers(state, failed_cleanup?) do
    {result, state} = wait_fixture_workers(state, System.monotonic_time(:millisecond) + 4_000)

    if not failed_cleanup? and result != :pending and settle_retained_fixture(state) == :ok do
      :ok
    else
      # No polling or assertion-based override. A new explicit reconciliation
      # rechecks the retained workers/OS targets and retries this exact scope.
      receive do
        :fixture_reconciled ->
          :ok

        {:DOWN, monitor, :process, _worker, reason} ->
          contain_fixture_workers(record_fixture_worker_down(state, monitor, reason))

        {:open_restart_port, worker, reference, _executable, _options} ->
          send(worker, {:restart_port, reference, {:error, :unconfirmed}})
          contain_fixture_workers(state)
      end
    end
  end

  def check(case_id, assertion, observed, expected \\ true) do
    # Record the fixed assertion label and match only, before expect! raises.
    # Aggregate failures then retain the failing guard without raw values.
    SelfTest.observe_manifest!(case_id <> "." <> assertion, observed === expected)
    SelfTest.expect_manifest!(case_id <> "." <> assertion, observed, expected)
    :ok
  end

  defp execute("p805.accepted" = id) do
    request = request(%{email: " Proof+#{Ecto.UUID.generate()}@EXAMPLE.TEST "})
    before = counts()

    Process.put(
      RegistrationSeam,
      {:observe,
       fn ->
         Process.put({__MODULE__, :transition}, accepted_snapshot(request))
       end}
    )

    {:ok, result} = Identity.register(request)
    Process.delete(RegistrationSeam)
    account = account!(result.account_id)
    snapshot = accepted_snapshot(request)
    check(id, "account_fields", account_fields?(account, request))

    check(
      id,
      "credential_same_transition",
      snapshot == Process.get({__MODULE__, :transition}) and snapshot.credential and
        snapshot.complete
    )

    check(id, "raw_password_absent", raw_password_absent?(request.password))
    check(id, "complete_consequences", delta(before, counts()), [1, 1, 1, 0, 1, 1, 1, 1, 1, 1])
    check(id, "audit_minimum_reference", snapshot.audit_minimum)
    check(id, "zero_communications_jobs", communications_jobs(), 0)
    check(id, "no_execution", no_execution?())
    check(id, "protected_capability_private", capability_private?(result, account, request))
  end

  defp execute("p805.rejected" = id) do
    before = counts()

    groups = [
      {"credential", [%{password: 42}, %{password: ""}, %{password: nil}]},
      {"required_fields",
       Enum.map([:first_name, :surname, :email, :password, :preferred_language], &%{&1 => nil})},
      {"age", [%{confirmed_age_18?: false}, %{confirmed_age_18?: nil}]},
      {"terms", [%{terms_version_id: nil}, %{terms_version_id: "ineligible"}]},
      {"privacy", [%{privacy_version_id: nil}, %{privacy_version_id: "ineligible"}]}
    ]

    for {assertion, inputs} <- groups do
      rejected =
        Enum.all?(inputs, fn overrides ->
          input = request()
          match?({:error, _}, Identity.register(Map.merge(input, overrides)))
        end)

      check(id, assertion, rejected)
    end

    check(id, "no_partial_consequences", counts(), before)
  end

  defp execute(id)
       when id in [
              "p805.envelope_rollback",
              "p805.audit_schedule_rollback",
              "p805.rollback_account",
              "p805.rollback_token",
              "p805.rollback_intent",
              "p805.rollback_nonce",
              "p805.rollback_obligation",
              "p805.rollback_operation"
            ] do
    table =
      Map.fetch!(
        %{
          "p805.envelope_rollback" => "communications_protected_envelopes",
          "p805.audit_schedule_rollback" => "oban_jobs",
          "p805.rollback_account" => "accounts",
          "p805.rollback_token" => "tokens",
          "p805.rollback_intent" => "message_intents",
          "p805.rollback_nonce" => "communications_envelope_nonces",
          "p805.rollback_obligation" => "evidence_obligations",
          "p805.rollback_operation" => "registration_operations"
        },
        id
      )

    before = counts()
    input = request()

    with_rejected_insert(table, fn reached ->
      result = Identity.register(input)
      check(id, "cut_reached", reached.())
      check(id, "unavailable", result, {:error, :registration_unavailable})
      check(id, "no_partial_consequences", counts(), before)
    end)
  end

  defp execute("p805.commit_rollback" = id) do
    input = request()
    before = counts()
    scenario = Scenario.start()

    try do
      :ok = CutPoints.arm(scenario, "transaction.before_commit", :registration, :raise)

      parent = self()
      reference = make_ref()

      {worker, monitor} =
        Scenario.spawn(scenario, :registration, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          try do
            Process.put(
              RegistrationSeam,
              {:observe,
               fn ->
                 Process.put(
                   {__MODULE__, :complete_before_cut},
                   accepted_snapshot(input).complete
                 )

                 CutPoints.hit(scenario, "transaction.before_commit", :registration)
               end}
            )

            unavailable =
              try do
                Identity.register(input) == {:error, :registration_unavailable}
              rescue
                _ in Ash.Error.Unknown -> true
              end

            send(
              parent,
              {reference, unavailable, Process.get({__MODULE__, :complete_before_cut})}
            )
          after
            Process.delete(RegistrationSeam)
            :ok = Sandbox.checkin(Repo)
          end
        end)

      {unavailable, complete} =
        receive do
          {^reference, unavailable, complete} -> {unavailable, complete}
        after
          15_000 -> raise "proof commit cut deadline"
        end

      receive do
        {:DOWN, ^monitor, :process, ^worker, :normal} -> :ok
      after
        5_000 -> raise "proof commit worker cleanup deadline"
      end

      check(id, "cut_reached", CutPoints.verify_consumed(scenario), :ok)
      check(id, "complete_before_cut", complete)
      check(id, "unavailable", unavailable)
      check(id, "no_partial_consequences", counts(), before)
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp execute("p805.replay_neutrality" = id) do
    input = request()
    {:ok, first} = Identity.register(input)
    before = counts()
    {:ok, replay} = Identity.register(input)

    check(
      id,
      "same_operation",
      replay.account_id == first.account_id and is_nil(replay.verification_proof)
    )

    check(
      id,
      "changed_input",
      match?({:error, _}, Identity.register(%{input | surname: "Changed"}))
    )

    duplicate = request(%{email: input.email})
    {:ok, neutral} = Identity.register(duplicate)

    check(
      id,
      "duplicate_neutral",
      neutral.status == first.status and is_nil(neutral.account_id) and
        is_nil(neutral.verification_proof)
    )

    check(id, "no_duplicate_consequences", delta(before, counts()), [0, 0, 1, 0, 0, 0, 0, 0, 0, 0])
  end

  defp execute("p805.pmr_collision" = id) do
    first = request()
    {:ok, result} = Identity.register(first)
    pmr = account!(result.account_id).pmr
    {:ok, fresh} = Identity.PMR.generate()
    Process.put({__MODULE__, :pmr_calls}, 0)

    Application.put_env(:new_you, :identity_pmr_generator, fn ->
      count = Process.get({__MODULE__, :pmr_calls})
      Process.put({__MODULE__, :pmr_calls}, count + 1)
      {:ok, if(count == 0, do: pmr, else: fresh)}
    end)

    {:ok, second} = Identity.register(request())
    check(id, "unique", account!(second.account_id).pmr != pmr)
    check(id, "collision_retried", Process.get({__MODULE__, :pmr_calls}), 2)
    before = counts()
    Process.put({__MODULE__, :pmr_calls}, 0)

    Application.put_env(:new_you, :identity_pmr_generator, fn ->
      Process.put({__MODULE__, :pmr_calls}, Process.get({__MODULE__, :pmr_calls}) + 1)
      {:ok, pmr}
    end)

    result = Identity.register(request())

    check(
      id,
      "bounded_exhaustion",
      result == {:error, :registration_unavailable} and Process.get({__MODULE__, :pmr_calls}) == 5
    )

    check(id, "no_partial_consequences", counts(), before)
  end

  defp execute("p805.retired_pmr" = id) do
    input = request()
    {:ok, accepted} = Identity.register(input)
    retired = account!(accepted.account_id).pmr
    cleanup(analytics_projection_key())

    check(
      id,
      "account_removed",
      scalar("SELECT count(*) FROM accounts WHERE pmr = $1", [retired]),
      0
    )

    check(
      id,
      "reservation_survives",
      scalar("SELECT count(*) FROM identity_pmr_reservations WHERE pmr = $1", [retired]),
      1
    )

    before = counts()
    Process.put({__MODULE__, :retired_pmr_calls}, 0)

    Application.put_env(:new_you, :identity_pmr_generator, fn ->
      calls = Process.get({__MODULE__, :retired_pmr_calls})
      Process.put({__MODULE__, :retired_pmr_calls}, calls + 1)
      {:ok, retired}
    end)

    result = Identity.register(request())

    check(
      id,
      "exhaustion",
      result == {:error, :registration_unavailable} and
        Process.get({__MODULE__, :retired_pmr_calls}) == 5
    )

    check(id, "no_reassignment", counts(), before)
  end

  defp execute("p805.same_email_race" = id), do: NewYou.Proof.P805Race.run(id)
  defp execute("p805.canonical_email_race" = id), do: NewYou.Proof.P805Race.run(id)
  defp execute("p805.same_operation_race" = id), do: NewYou.Proof.P805Race.run(id)
  defp execute("p805.pmr_collision_race" = id), do: NewYou.Proof.P805Race.run(id)

  defp execute("p805.post_commit_recovery" = id) do
    input = request()
    before = counts()
    parent = self()
    ref = make_ref()
    scenario = Scenario.start()

    try do
      :ok = CutPoints.arm(scenario, "transaction.after_commit", :registration, :terminate)

      {worker, worker_monitor} =
        Scenario.spawn(scenario, :registration, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          try do
            backend = scalar("SELECT pg_backend_pid()")
            {:ok, _result} = Identity.register(input)
            send(parent, {ref, :committed, backend})
            CutPoints.hit(scenario, "transaction.after_commit", :registration)
            send(parent, {ref, :acknowledged})
          after
            Sandbox.checkin(Repo)
          end
        end)

      registration_backend =
        receive do
          {^ref, :committed, backend} -> backend
        after
          20_000 -> raise "post-commit deadline"
        end

      receive do
        {:DOWN, ^worker_monitor, :process, ^worker, :proof_terminated} -> :ok
      after
        10_000 -> raise "post-commit termination deadline"
      end

      consumed = CutPoints.verify_consumed(scenario)

      {reader, reader_monitor} =
        Scenario.spawn(scenario, :recovery, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          try do
            backend = scalar("SELECT pg_backend_pid()")
            snapshot = accepted_snapshot(input)
            before_replay = counts([input.operation_id], [input.email])
            {:ok, replay} = Identity.register(input)

            send(
              parent,
              {ref, :recovered, backend, snapshot.complete and snapshot.credential,
               replay.status == :verification_pending and is_binary(replay.account_id) and
                 is_nil(replay.verification_proof),
               counts([input.operation_id], [input.email]) == before_replay}
            )
          after
            :ok = Sandbox.checkin(Repo)
          end
        end)

      {reader_backend, complete, replayed, unchanged} =
        receive do
          {^ref, :recovered, backend, complete, replayed, unchanged} ->
            {backend, complete, replayed, unchanged}
        after
          20_000 -> raise "recovery result deadline"
        end

      receive do
        {:DOWN, ^reader_monitor, :process, ^reader, :normal} -> :ok
      after
        10_000 -> raise "recovery reader cleanup deadline"
      end

      acknowledged =
        receive do
          {^ref, :acknowledged} -> true
        after
          0 -> false
        end

      check(id, "cut_consumed", consumed, :ok)
      check(id, "acknowledgement_lost", not acknowledged)
      check(id, "fresh_connection", registration_backend != reader_backend)
      check(id, "complete_recovery", complete)
      check(id, "replay_converges", replayed and unchanged)
      check(id, "committed_once", delta(before, counts()), [1, 1, 1, 0, 1, 1, 1, 1, 1, 1])
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp execute("p805.browser_en" = id), do: NewYou.Proof.P805Browser.run(id, "en")
  defp execute("p805.browser_af" = id), do: NewYou.Proof.P805Browser.run(id, "af")

  defp execute("p805.resend" = id) do
    input = request()
    {:ok, result} = Identity.register(input)
    original = challenges(result.account_id) |> hd()
    before = counts()
    operation = %{operation_id: Ecto.UUID.generate(), account_id: result.account_id}
    track(operation)
    {:ok, :verification_pending} = Identity.resend_verification(operation)
    [replacement] = challenges(result.account_id)

    check(
      id,
      "separate_binding",
      operation.operation_id != input.operation_id and
        resend_operations(operation.operation_id)
        |> Enum.any?(
          &(&1.operation_id == operation.operation_id and &1.account_id == result.account_id)
        )
    )

    check(
      id,
      "superseded",
      replacement.jti != original.jti and
        Enum.any?(
          tokens(result.account_id),
          &(&1.jti == original.jti and &1.purpose == "revocation")
        )
    )

    intent = intents(operation.operation_id) |> hd()
    check(id, "one_new_intent", length(intents(operation.operation_id)), 1)

    check(
      id,
      "protected_envelope",
      scalar(
        "SELECT count(*) FROM communications_protected_envelopes WHERE message_intent_id = $1 AND source_reference = $2",
        [Ecto.UUID.dump!(intent.id), replacement.jti]
      ),
      1
    )

    check(id, "zero_communications_jobs", communications_jobs(), 0)
    check(id, "no_resend_audit", delta(before, counts()), [0, 1, 0, 1, 1, 1, 1, 0, 0, 0])

    check(
      id,
      "discoverable",
      intent.dispatch_disposition == :open and intent.source_reference == replacement.jti
    )

    after_resend = counts()
    {:ok, :verification_pending} = Identity.resend_verification(operation)

    check(
      id,
      "idempotent",
      counts() == after_resend and hd(challenges(result.account_id)).jti == replacement.jti
    )
  end

  defp execute("p805.resend_binding" = id) do
    input = request()
    unknown = %{operation_id: Ecto.UUID.generate(), email: input.email}
    track(unknown)
    before = counts()
    result = Identity.resend_verification_by_email(unknown)

    check(
      id,
      "unknown_neutral",
      result == {:ok, :verification_pending} and
        delta(before, counts()) == [0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
    )

    known = request()
    {:ok, _} = Identity.register(known)
    before_changed = counts()

    check(
      id,
      "immutable_binding",
      Identity.resend_verification_by_email(%{unknown | email: known.email}) ==
        {:error, :resend_unavailable} and counts() == before_changed
    )

    {:ok, accepted} = Identity.register(input)
    before_replay = counts()

    check(
      id,
      "terminal_replay",
      Identity.resend_verification_by_email(unknown) == {:ok, :verification_pending} and
        counts() == before_replay
    )

    missing_account = %{operation_id: Ecto.UUID.generate(), account_id: Ecto.UUID.generate()}
    track(missing_account)

    check(
      id,
      "ineligible_neutral",
      Identity.resend_verification(missing_account) == {:ok, :verification_pending} and
        length(challenges(accepted.account_id)) == 1
    )
  end

  def account!(id), do: Ash.get!(Identity.Account, id, domain: Identity, authorize?: false)

  @doc false
  def read(resource, domain), do: read(resource, domain, fixture_values())

  # Explicit context lets sandbox tests use the same finite observation rules.
  # Filter before hydration so incompatible foreign enum values stay unread.
  @doc false
  def read(resource, domain, {operations, emails}) when is_list(operations) and is_list(emails) do
    resource
    |> fixture_query(operations, emails)
    |> Ash.read!(domain: domain, authorize?: false)
  end

  defp fixture_query(Identity.RegistrationOperation, operations, _emails) do
    Identity.RegistrationOperation
    |> Ash.Query.filter(operation_id in ^operations)
  end

  defp fixture_query(Identity.Account, _operations, emails),
    do: Ash.Query.filter(Identity.Account, email in ^emails)

  defp fixture_query(Identity.Token, _operations, emails),
    do: Ash.Query.filter(Identity.Token, account.email in ^emails)

  defp fixture_query(Communications.MessageIntent, operations, _emails),
    do: Ash.Query.filter(Communications.MessageIntent, source_operation_id in ^operations)

  defp fixture_query(Communications.DeliveryAttempt, operations, _emails),
    do:
      Ash.Query.filter(
        Communications.DeliveryAttempt,
        message_intent.source_operation_id in ^operations
      )

  defp fixture_query(Communications.ProtectedEnvelope, operations, _emails),
    do:
      Ash.Query.filter(
        Communications.ProtectedEnvelope,
        message_intent.source_operation_id in ^operations
      )

  def registration_operations(operation_id) do
    Identity.RegistrationOperation
    |> Ash.Query.filter(operation_id == ^operation_id)
    |> Ash.read!(domain: Identity, authorize?: false)
  end

  def intents(operation),
    do:
      Communications.MessageIntent
      |> Ash.Query.filter(source_operation_id == ^operation)
      |> Ash.read!(domain: Communications, authorize?: false)

  def challenges(account),
    do:
      Identity.Token
      |> Ash.Query.filter(account_id == ^account and purpose == "email_verification")
      |> Ash.read!(domain: Identity, authorize?: false)

  defp tokens(account),
    do:
      Identity.Token
      |> Ash.Query.filter(account_id == ^account)
      |> Ash.read!(domain: Identity, authorize?: false)

  defp resend_operations(operation),
    do:
      Identity.ResendOperation
      |> Ash.Query.filter(operation_id == ^operation)
      |> Ash.read!(domain: Identity, authorize?: false)

  def counts do
    {operations, emails} = fixture_values()
    scoped_counts(operations, emails)
  end

  def counts(operations, emails), do: scoped_counts(operations, emails)

  def delta(before, after_counts), do: Enum.zip_with(after_counts, before, &(&1 - &2))

  defp fixture_values do
    case Process.get({__MODULE__, :guardian}) do
      guardian when is_pid(guardian) ->
        reference = make_ref()
        send(guardian, {:fixture_values, self(), reference})

        receive do
          {:fixture_values, ^reference, operations, emails} -> {operations, emails}
        after
          5_000 -> raise "P8-05 fixture guardian did not return fixture identities"
        end

      _ ->
        {Process.get({__MODULE__, :operations}, []), Process.get({__MODULE__, :emails}, [])}
    end
  end

  # Child identifiers come from fixture-owned writes, independently of parent
  # associations. Captured IDs select observations and never authorize cleanup.
  @doc false
  def capture_consequence_ids, do: NewYou.Proof.FixtureObservation.snapshot()

  @doc false
  def new_consequence_ids(baseline, kind),
    do: NewYou.Proof.FixtureObservation.new_ids(baseline, kind)

  defp scoped_counts(operations, emails) do
    operations = operations |> Enum.uniq() |> Enum.map(&Ecto.UUID.dump!/1)
    emails = Enum.uniq(emails)
    baseline = Process.get({__MODULE__, :consequence_baseline}) || capture_consequence_ids()
    Process.put({__MODULE__, :consequence_baseline}, baseline)
    new_tokens = new_consequence_ids(baseline, :tokens)
    new_nonces = new_consequence_ids(baseline, :nonces)
    new_jobs = new_consequence_ids(baseline, :jobs)

    queries = [
      {"SELECT count(*) FROM accounts WHERE email = ANY($1::text[])", [emails]},
      {"SELECT count(*) FROM tokens WHERE account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) OR jti = ANY($2::text[])",
       [emails, new_tokens]},
      {"SELECT count(*) FROM registration_operations WHERE operation_id = ANY($2::uuid[]) OR created_account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
       [emails, operations]},
      {"SELECT count(*) FROM resend_operations WHERE operation_id = ANY($2::uuid[]) OR account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
       [emails, operations]},
      {"SELECT count(*) FROM message_intents WHERE source_operation_id = ANY($1::uuid[])",
       [operations]},
      {"SELECT count(*) FROM communications_protected_envelopes e JOIN message_intents i ON i.id = e.message_intent_id WHERE i.source_operation_id = ANY($1::uuid[])",
       [operations]},
      {"SELECT count(*) FROM communications_envelope_nonces n WHERE n.nonce IN (SELECT e.nonce FROM communications_protected_envelopes e JOIN message_intents i ON i.id = e.message_intent_id WHERE i.source_operation_id = ANY($1::uuid[])) OR n.nonce = ANY($2::bytea[])",
       [operations, new_nonces]},
      {"SELECT count(*) FROM evidence_obligations WHERE source_operation_id = ANY($2::uuid[]) OR actor_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) OR target_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
       [emails, operations]},
      {"SELECT count(*) FROM oban_jobs WHERE args->'primary_key'->>'id' IN (SELECT id::text FROM evidence_obligations WHERE source_operation_id = ANY($2::uuid[]) OR actor_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) OR target_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))) OR args->'primary_key'->>'id' IN (SELECT id::text FROM message_intents WHERE source_operation_id = ANY($2::uuid[])) OR id = ANY($3::bigint[])",
       [emails, operations, new_jobs]},
      {"SELECT count(*) FROM identity_pmr_reservations WHERE pmr IN (SELECT pmr FROM accounts WHERE email = ANY($1::text[]))",
       [emails]}
    ]

    Enum.map(queries, fn {query, params} -> scalar(query, params) end)
  end

  def scalar(sql, args \\ []) do
    %{rows: [[value]]} = Repo.query!(sql, args)
    value
  end

  defp accepted_snapshot(input) do
    [operation] =
      Identity.RegistrationOperation
      |> Ash.Query.filter(operation_id == ^input.operation_id)
      |> Ash.read!(domain: Identity, authorize?: false)

    account = account!(operation.created_account_id)
    [token] = challenges(account.id)
    [intent] = intents(input.operation_id)

    [obligation] =
      Audit.EvidenceObligation
      |> Ash.Query.filter(source_operation_id == ^input.operation_id)
      |> Ash.read!(domain: Audit, authorize?: false)

    [job] =
      Repo.all(Oban.Job) |> Enum.filter(&(&1.args["primary_key"] == %{"id" => obligation.id}))

    %{
      credential:
        account.credential_status == :active and is_binary(account.hashed_password) and
          byte_size(account.hashed_password) > 0 and
          account.hashed_password == operation.password_verifier,
      complete:
        account_fields?(account, input) and Identity.PMR.valid?(account.pmr) and
          account.legal_accepted_at == operation.committed_at and
          delivery_bound?(intent, token, input) and audit_bound?(obligation, job, operation),
      audit_minimum:
        job.args == %{
          "primary_key" => %{"id" => obligation.id},
          "metadata" => %{},
          "action_arguments" => %{},
          "tenant" => nil
        }
    }
  end

  defp account_fields?(account, input) do
    {:ok, email} = Identity.Email.canonicalize(input.email)

    fields = [
      :first_name,
      :surname,
      :email,
      :preferred_language,
      :confirmed_age_18?,
      :terms_version_id,
      :privacy_version_id,
      :acceptance_locale,
      :email_verified?
    ]

    expected = %{
      first_name: input.first_name,
      surname: input.surname,
      email: email,
      preferred_language: input.preferred_language,
      confirmed_age_18?: true,
      terms_version_id: @terms,
      privacy_version_id: @privacy,
      acceptance_locale: input.preferred_language,
      email_verified?: false
    }

    Map.take(account, fields) == expected and match?(%DateTime{}, account.legal_accepted_at)
  end

  defp delivery_bound?(intent, token, input) do
    intent.source_reference == token.jti and intent.source_operation_id == input.operation_id and
      scalar(
        "SELECT count(*) FROM communications_protected_envelopes WHERE message_intent_id = $1 AND source_reference = $2",
        [Ecto.UUID.dump!(intent.id), token.jti]
      ) == 1
  end

  defp audit_bound?(obligation, job, operation) do
    obligation.state == :open and obligation.evidence_type == :account_registration_pmr_assignment and
      job.queue == "audit" and operation.state == :bound
  end

  defp raw_password_absent?(password) do
    {operations, emails} = fixture_values()
    operations = Enum.map(operations, &Ecto.UUID.dump!/1)

    scoped_queries = %{
      "accounts" => {"email = ANY($1::text[])", [emails]},
      "tokens" =>
        {"account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))", [emails]},
      "registration_operations" =>
        {"operation_id = ANY($2::uuid[]) OR created_account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
         [emails, operations]},
      "resend_operations" =>
        {"operation_id = ANY($2::uuid[]) OR account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
         [emails, operations]},
      "message_intents" => {"source_operation_id = ANY($1::uuid[])", [operations]},
      "communications_protected_envelopes" =>
        {"message_intent_id IN (SELECT id FROM message_intents WHERE source_operation_id = ANY($1::uuid[]))",
         [operations]},
      "communications_envelope_nonces" =>
        {"nonce IN (SELECT e.nonce FROM communications_protected_envelopes e JOIN message_intents i ON i.id = e.message_intent_id WHERE i.source_operation_id = ANY($1::uuid[]))",
         [operations]},
      "evidence_obligations" =>
        {"source_operation_id = ANY($2::uuid[]) OR actor_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) OR target_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
         [emails, operations]},
      "oban_jobs" =>
        {"args->'primary_key'->>'id' IN (SELECT id::text FROM evidence_obligations WHERE source_operation_id = ANY($2::uuid[]) OR actor_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) OR target_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))) OR args->'primary_key'->>'id' IN (SELECT id::text FROM message_intents WHERE source_operation_id = ANY($2::uuid[]))",
         [emails, operations]},
      "identity_pmr_reservations" =>
        {"pmr IN (SELECT pmr FROM accounts WHERE email = ANY($1::text[]))", [emails]},
      "identity_grants" =>
        {"subject_account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) OR target_account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) OR approver_account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
         [emails]},
      "privacy_purpose_authorities" => {"source_operation_id = ANY($1::uuid[])", [operations]},
      "privacy_purpose_events" => {"source_operation_id = ANY($1::uuid[])", [operations]}
    }

    Enum.all?(@tables, fn table ->
      {scope, parameters} = Map.fetch!(scoped_queries, table)
      password_parameter = length(parameters) + 1

      scalar(
        "SELECT count(*) FROM #{table} AS row WHERE (#{scope}) AND strpos(row_to_json(row)::text, $#{password_parameter}) > 0",
        parameters ++ [password]
      ) == 0
    end)
  end

  defp capability_private?(result, account, input) do
    is_binary(result.verification_proof) and raw_password_absent?(result.verification_proof) and
      account.hashed_password != input.password
  end

  defp no_execution? do
    {operations, emails} = fixture_values()
    primary_keys = fixture_primary_keys(operations, emails)

    scalar(
      "SELECT count(*) FROM oban_jobs WHERE args->'primary_key'->>'id' = ANY($1::text[]) AND (attempted_at IS NOT NULL OR attempt <> 0)",
      [primary_keys]
    ) == 0 and evidence_records(operations, emails) == []
  end

  defp communications_jobs do
    {operations, emails} = fixture_values()
    primary_keys = fixture_primary_keys(operations, emails)

    scalar(
      "SELECT count(*) FROM oban_jobs WHERE queue = 'communications' AND args->'primary_key'->>'id' = ANY($1::text[])",
      [primary_keys]
    )
  end

  defp fixture_primary_keys(operations, emails) do
    operations = Enum.map(operations, &Ecto.UUID.dump!/1)

    %{rows: rows} =
      Repo.query!(
        "SELECT id::text FROM evidence_obligations WHERE source_operation_id = ANY($1::uuid[]) OR actor_id IN (SELECT id FROM accounts WHERE email = ANY($2::text[])) OR target_id IN (SELECT id FROM accounts WHERE email = ANY($2::text[])) UNION SELECT id::text FROM message_intents WHERE source_operation_id = ANY($1::uuid[])",
        [operations, emails]
      )

    Enum.map(rows, &hd/1)
  end

  defp evidence_records(operations, emails) do
    operations = Enum.map(operations, &Ecto.UUID.dump!/1)

    %{rows: rows} =
      Repo.query!(
        "SELECT id FROM evidence_obligations WHERE source_operation_id = ANY($1::uuid[]) OR actor_id IN (SELECT id FROM accounts WHERE email = ANY($2::text[])) OR target_id IN (SELECT id FROM accounts WHERE email = ANY($2::text[]))",
        [operations, emails]
      )

    obligation_ids = Enum.map(rows, &hd/1)

    if obligation_ids == [] do
      []
    else
      Audit.EvidenceRecord
      |> Ash.Query.filter(obligation_id in ^obligation_ids)
      |> Ash.read!(domain: Audit, authorize?: false)
    end
  end

  @doc """
  Reject inserts only on the caller's checked-out proof connection.

  The callback receives a rollback-resistant reached probe. Call outside a
  transaction; the callback may start transactions. Temporary function/sequence
  dependencies also remove the owned trigger if that connection terminates.
  """
  def with_rejected_insert(table, callback) when table in @tables do
    if Repo.in_transaction?(), do: raise("proof insertion cut requires no enclosing transaction")

    # Keep the SQL client checked out throughout the callback. DBConnection's
    # ownership proxy disconnects an active client on abrupt owner death, so
    # PostgreSQL removes its temporary objects and dependent trigger together.
    Repo.checkout(fn ->
      name = "p805_fault_" <> String.replace(Ecto.UUID.generate(), "-", "")
      previous = scalar("SELECT current_setting('newyou.proof_cut', true)")

      if is_pid(Process.get({__MODULE__, :guardian})) do
        Process.put({__MODULE__, :fault_names}, [
          name | Process.get({__MODULE__, :fault_names}, [])
        ])
      end

      try do
        Repo.query!("CREATE TEMP SEQUENCE #{name}")

        Repo.query!("""
        CREATE FUNCTION pg_temp.#{name}() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
          PERFORM nextval('pg_temp.#{name}');
          RAISE EXCEPTION 'bounded proof insertion cut' USING ERRCODE = '23514';
        END; $$
        """)

        Repo.query!("SELECT set_config('newyou.proof_cut', $1, false)", [name])

        Repo.query!(
          "CREATE TRIGGER #{name} BEFORE INSERT ON #{table} FOR EACH ROW WHEN (current_setting('newyou.proof_cut', true) = '#{name}') EXECUTE FUNCTION pg_temp.#{name}()"
        )

        callback.(fn -> scalar("SELECT is_called FROM pg_temp.#{name}") end)
      after
        Repo.query!("DROP TRIGGER IF EXISTS #{name} ON #{table}")
        Repo.query!("DROP FUNCTION IF EXISTS pg_temp.#{name}()")
        Repo.query!("DROP SEQUENCE IF EXISTS pg_temp.#{name}")
        # PostgreSQL retains an empty custom-setting placeholder after RESET.
        # Both missing and empty mean inactive; preserve any actual prior cut.
        Repo.query!("SELECT set_config('newyou.proof_cut', $1, false)", [previous || ""])
      end
    end)
  end

  # Fixture teardown only, never an application mutation interface. PMR
  # reservations deliberately remain permanent, as in existing owner tests.
  defp cleanup(projection_key) do
    operations = Process.get({__MODULE__, :operations}, [])
    emails = Process.get({__MODULE__, :emails}, [])
    cleanup(operations, emails, projection_key, Process.get({__MODULE__, :fixture_cleanup_hook}))
    Process.delete({__MODULE__, :operations})
    Process.delete({__MODULE__, :emails})
  end

  defp cleanup(operations, emails, projection_key, cleanup_hook) do
    if is_function(cleanup_hook, 0), do: cleanup_hook.()
    :ok = cleanup_test_oban_queue(projection_key)
    :ok = cleanup_test_analytics_projection(projection_key)

    operations = Enum.uniq(operations) |> Enum.map(&Ecto.UUID.dump!/1)
    emails = Enum.uniq(emails)

    # Browser IDs are recovered through durable owner provenance even when the
    # browser process dies before it can return its generated operation IDs.
    %{rows: discovered} =
      Repo.query!(
        "SELECT operation_id FROM registration_operations WHERE created_account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) UNION SELECT operation_id FROM resend_operations WHERE account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) UNION SELECT operation_id FROM recovery_cases WHERE account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) UNION SELECT completion_id FROM recovery_cases WHERE completion_id IS NOT NULL AND account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
        [emails]
      )

    operations = Enum.uniq(operations ++ Enum.map(discovered, &hd/1))

    %{rows: nonces} =
      Repo.query!(
        "SELECT e.nonce FROM communications_protected_envelopes e JOIN message_intents i ON i.id = e.message_intent_id WHERE i.source_operation_id = ANY($1::uuid[])",
        [operations]
      )

    Repo.query!(
      "DELETE FROM oban_jobs WHERE args->'primary_key'->>'id' IN (SELECT id::text FROM evidence_obligations WHERE source_operation_id = ANY($1::uuid[]) OR actor_id IN (SELECT id FROM accounts WHERE email = ANY($2::text[])) OR target_id IN (SELECT id FROM accounts WHERE email = ANY($2::text[]))) OR args->'primary_key'->>'id' IN (SELECT id::text FROM message_intents WHERE source_operation_id = ANY($1::uuid[]))",
      [operations, emails]
    )

    # Transactional DDL takes table locks. Only these synthetic fixture rows
    # are removed, and guards are restored before the transaction commits.
    {:ok, :ok} =
      Repo.transaction(fn ->
        Repo.query!(
          "ALTER TABLE reconciliation_cases DISABLE TRIGGER identity_reconciliation_immutable"
        )

        Repo.query!(
          "DELETE FROM reconciliation_cases WHERE detected_by_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
          [emails]
        )

        Repo.query!(
          "ALTER TABLE reconciliation_cases ENABLE TRIGGER identity_reconciliation_immutable"
        )

        Repo.query!("ALTER TABLE evidence_records DISABLE TRIGGER evidence_records_immutable")

        Repo.query!(
          "ALTER TABLE evidence_obligations DISABLE TRIGGER evidence_obligations_no_delete"
        )

        Repo.query!(
          "DELETE FROM evidence_records WHERE obligation_id IN (SELECT id FROM evidence_obligations WHERE source_operation_id = ANY($1::uuid[]) OR actor_id IN (SELECT id FROM accounts WHERE email = ANY($2::text[])) OR target_id IN (SELECT id FROM accounts WHERE email = ANY($2::text[])))",
          [operations, emails]
        )

        Repo.query!(
          "DELETE FROM evidence_obligations WHERE source_operation_id = ANY($1::uuid[]) OR actor_id IN (SELECT id FROM accounts WHERE email = ANY($2::text[])) OR target_id IN (SELECT id FROM accounts WHERE email = ANY($2::text[]))",
          [operations, emails]
        )

        Repo.query!(
          "DELETE FROM evidence_records WHERE actor_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) OR target_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
          [emails]
        )

        Repo.query!("ALTER TABLE evidence_records ENABLE TRIGGER evidence_records_immutable")

        Repo.query!(
          "ALTER TABLE evidence_obligations ENABLE TRIGGER evidence_obligations_no_delete"
        )

        :ok
      end)

    Repo.query!(
      "DELETE FROM communications_protected_envelopes e USING message_intents i WHERE e.message_intent_id = i.id AND i.source_operation_id = ANY($1::uuid[])",
      [operations]
    )

    Enum.each(nonces, fn [nonce] ->
      Repo.query!("DELETE FROM communications_envelope_nonces WHERE nonce = $1", [nonce])
    end)

    Repo.query!("DELETE FROM message_intents WHERE source_operation_id = ANY($1::uuid[])", [
      operations
    ])

    Repo.query!(
      "DELETE FROM sessions WHERE account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
      [emails]
    )

    Repo.query!(
      "DELETE FROM tokens WHERE account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
      [emails]
    )

    Repo.query!("DELETE FROM resend_operations WHERE operation_id = ANY($1::uuid[])", [operations])

    Repo.query!("DELETE FROM registration_operations WHERE operation_id = ANY($1::uuid[])", [
      operations
    ])

    Repo.query!(
      "DELETE FROM identity_grants WHERE subject_account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) OR target_account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[])) OR approver_account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
      [emails]
    )

    {:ok, :ok} =
      Repo.transaction(fn ->
        Repo.query!(
          "ALTER TABLE privacy_purpose_events DISABLE TRIGGER privacy_purpose_events_immutable"
        )

        Repo.query!(
          "ALTER TABLE privacy_purpose_events DISABLE TRIGGER privacy_purpose_events_no_truncate"
        )

        Repo.query!(
          "ALTER TABLE privacy_purpose_authorities DISABLE TRIGGER privacy_purpose_authorities_lifecycle"
        )

        Repo.query!(
          "ALTER TABLE privacy_purpose_authorities DISABLE TRIGGER privacy_purpose_authorities_no_truncate"
        )

        Repo.query!(
          "DELETE FROM privacy_purpose_events WHERE source_operation_id = ANY($1::uuid[])",
          [operations]
        )

        Repo.query!(
          "DELETE FROM privacy_purpose_authorities WHERE source_operation_id = ANY($1::uuid[])",
          [operations]
        )

        Repo.query!(
          "ALTER TABLE privacy_purpose_events ENABLE TRIGGER privacy_purpose_events_immutable"
        )

        Repo.query!(
          "ALTER TABLE privacy_purpose_events ENABLE TRIGGER privacy_purpose_events_no_truncate"
        )

        Repo.query!(
          "ALTER TABLE privacy_purpose_authorities ENABLE TRIGGER privacy_purpose_authorities_lifecycle"
        )

        Repo.query!(
          "ALTER TABLE privacy_purpose_authorities ENABLE TRIGGER privacy_purpose_authorities_no_truncate"
        )

        :ok
      end)

    Repo.query!(
      "DELETE FROM device_assurances WHERE account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
      [emails]
    )

    {:ok, :ok} =
      Repo.transaction(fn ->
        Repo.query!("ALTER TABLE recovery_cases DISABLE TRIGGER identity_recovery_immutable")

        Repo.query!(
          "DELETE FROM recovery_cases WHERE account_id IN (SELECT id FROM accounts WHERE email = ANY($1::text[]))",
          [emails]
        )

        Repo.query!("ALTER TABLE recovery_cases ENABLE TRIGGER identity_recovery_immutable")
        :ok
      end)

    if operations != [] do
      Repo.query!(
        "DELETE FROM oban_jobs WHERE args->'primary_key'->>'id' IN (SELECT c.id::text FROM commerce_payment_consequences c JOIN commerce_plan_purchases p ON p.id = c.purchase_id WHERE p.operation_id = ANY($1::uuid[]))",
        [operations]
      )

      Repo.query!(
        "DELETE FROM entitlements_plan_rights WHERE purchase_id IN (SELECT id FROM commerce_plan_purchases WHERE operation_id = ANY($1::uuid[]))",
        [operations]
      )

      Repo.query!(
        "DELETE FROM commerce_payment_consequences WHERE purchase_id IN (SELECT id FROM commerce_plan_purchases WHERE operation_id = ANY($1::uuid[]))",
        [operations]
      )

      Repo.query!(
        "DELETE FROM commerce_verified_payments WHERE purchase_id IN (SELECT id FROM commerce_plan_purchases WHERE operation_id = ANY($1::uuid[]))",
        [operations]
      )

      Repo.query!("DELETE FROM commerce_plan_purchases WHERE operation_id = ANY($1::uuid[])", [
        operations
      ])
    end

    Repo.query!("DELETE FROM accounts WHERE email = ANY($1::text[])", [emails])
  end

  defp cleanup_test_oban_queue("p817_test_" <> suffix) when suffix != "" do
    queue = "p818_" <> suffix
    Repo.query!("DELETE FROM oban_jobs WHERE queue = $1", [queue])
    :ok
  end

  defp cleanup_test_oban_queue(_projection_key), do: :ok

  @doc false
  @spec analytics_projection_key() :: String.t()
  def analytics_projection_key do
    case Process.get({NewYou.Analytics, :p817_test_projection_key}) do
      "p817_test_" <> _ = projection_key -> projection_key
      _ -> raise "P8-05 fixture Analytics projection key is unavailable"
    end
  end

  @doc false
  @spec cleanup_test_analytics_projection(String.t()) :: :ok
  def cleanup_test_analytics_projection("p817_test_" <> _ = projection_key) do
    Repo.query!("DELETE FROM p817_privacy_projections WHERE projection_key = $1", [projection_key])

    :ok
  end

  def cleanup_test_analytics_projection(_projection_key),
    do: raise(ArgumentError, "invalid P8-05 test Analytics projection key")
end
