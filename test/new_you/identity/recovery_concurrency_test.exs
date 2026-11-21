defmodule NewYou.Identity.RecoveryConcurrencyTest do
  use ExUnit.Case, async: false

  alias NewYou.Proof.P815

  test "duplicate requests serialize on PostgreSQL and retain one recovery case" do
    assert P815.duplicate_request_race()
  end

  test "parallel zero-assurance requests cannot impose an Account restriction" do
    assert P815.duplicate_request_race(false)
  end

  test "parallel proof acceptance imposes one justified hold and one E2 consequence" do
    assert P815.assurance_race()
  end

  test "zero-assurance recovery survives restart without restricting the Account" do
    assert P815.unverified_restart_proof() == :ok
  end

  test "restart fixture requires a committed case after a neutral request rolls back" do
    failure = :atomics.new(1, [])

    NewYou.Proof.RecoverySeam.observe(fn stage ->
      if stage == :transaction_entered and :atomics.add_get(failure, 1, 1) == 1 do
        raise "TEST-only recovery fixture transaction interruption"
      end
    end)

    try do
      assert P815.unverified_restart_proof() == :ok
      assert :atomics.get(failure, 1) in 2..3
    after
      Process.delete({NewYou.Proof.RecoverySeam, :observer})
    end
  end

  test "restart fixture fails closed when no bounded setup request commits" do
    attempts = :atomics.new(1, [])

    NewYou.Proof.RecoverySeam.observe(fn stage ->
      if stage == :transaction_entered do
        :atomics.add_get(attempts, 1, 1)
        raise "TEST-only recovery fixture transaction interruption"
      end
    end)

    try do
      assert_raise ExUnit.AssertionError, ~r/did not commit after 3 bounded attempts/, fn ->
        P815.unverified_restart_proof()
      end

      assert :atomics.get(attempts, 1) == 3
    after
      Process.delete({NewYou.Proof.RecoverySeam, :observer})
    end
  end

  test "fresh resume retries a proven pre-commit rollback with one final proof and intent" do
    assert P815.unverified_restart_proof(rollback_resume_once?: true) == :ok
  end

  test "a real initial request timeout cannot remove the fixture owner lease" do
    attempts = :atomics.new(1, [])
    parent = self()
    reference = make_ref()

    NewYou.Proof.RecoverySeam.observe(fn stage ->
      if stage == :transaction_entered and :atomics.add_get(attempts, 1, 1) == 1 do
        await_initial_lease_loss(parent, reference, System.monotonic_time(:millisecond) + 2_000)
      end
    end)

    try do
      assert P815.unverified_restart_proof() == :ok
      assert_received {^reference, :initial_lease_expired}
      assert :atomics.get(attempts, 1) in 2..3
    after
      Process.delete({NewYou.Proof.RecoverySeam, :observer})
    end
  end

  test "a real lease timeout before Account lookup leaves no partial change" do
    assert P815.pre_checkpoint_timeout_proof(:transaction_entered) == :ok
  end

  test "a real lease timeout after Account lock leaves the case safe for manual retry" do
    assert P815.pre_checkpoint_timeout_proof(:account_locked) == :ok
  end

  test "a real lease timeout after partial proof work rolls back before manual retry" do
    assert P815.pre_checkpoint_timeout_proof(:await_proof) == :ok
  end

  test "a committed request without lease expiry cannot count as a timeout proof" do
    assert_raise ExUnit.AssertionError, ~r/timeout not proven: transaction committed/, fn ->
      P815.pre_checkpoint_timeout_proof(:await_proof, skip_timeout?: true)
    end
  end

  test "restarted recovery rolls back an observed checkpoint cut before retrying the same case" do
    assert P815.unverified_restart_proof(interrupt_resume?: true) == :ok
  end

  test "restart proof rejects a retry when the interruption checkpoint was not reached" do
    owner = self()

    Process.put({NewYou.Proof.P805, :fixture_cleanup_hook}, fn ->
      send(
        owner,
        {:cleanup_identifiers, Process.get({NewYou.Proof.P805, :emails}, []),
         Process.get({NewYou.Proof.P805, :operations}, [])}
      )
    end)

    try do
      error =
        assert_raise ExUnit.AssertionError, ~r/interruption_not_proven/, fn ->
          P815.unverified_restart_proof(interrupt_resume?: true, skip_interrupt?: true)
        end

      assert Exception.message(error) =~ "operation?: true"
      assert Exception.message(error) =~ "checkpoint?: false"
      assert Exception.message(error) =~ "connection_lost?: false"

      assert_receive {:cleanup_identifiers, [_ | _] = emails, [_ | _] = operations}

      Ecto.Adapters.SQL.Sandbox.unboxed_run(NewYou.Repo, fn ->
        %{rows: [[count]]} =
          NewYou.Repo.query!("SELECT count(*) FROM accounts WHERE email = ANY($1::text[])", [
            emails
          ])

        assert count == 0
        ids = Enum.map(operations, &Ecto.UUID.dump!/1)

        %{rows: [[cases, intents]]} =
          NewYou.Repo.query!(
            "SELECT (SELECT count(*) FROM recovery_cases WHERE operation_id = ANY($1::uuid[])), (SELECT count(*) FROM message_intents WHERE source_operation_id = ANY($1::uuid[]))",
            [ids]
          )

        assert cases == 0
        assert intents == 0
      end)
    after
      Process.delete({NewYou.Proof.P805, :fixture_cleanup_hook})
    end
  end

  test "fixture guardian waits for the restart child after owner death" do
    parent = self()

    path =
      Path.join(
        System.tmp_dir!(),
        "p815-fixture-#{Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)}"
      )

    on_exit(fn ->
      case File.read(path) do
        {:ok, pid} -> System.cmd("kill", ["-KILL", String.trim(pid)], stderr_to_stdout: true)
        _ -> :ok
      end

      File.rm(path)
    end)

    scenario = NewYou.Proof.Scenario.start()

    {owner, monitor} =
      NewYou.Proof.Scenario.spawn(scenario, :restart_owner, fn ->
        Process.put({NewYou.Proof.P805, :fixture_cleanup_hook}, fn ->
          send(parent, :fixture_cleanup_started)
        end)

        NewYou.Proof.P805.with_fixture(fn ->
          request = NewYou.Proof.P805.request()
          {:ok, _} = NewYou.Identity.register(request)
          send(parent, {:fixture_email, request.email})

          NewYou.Proof.P815Port.run(
            System.find_executable("sh"),
            ["-c", "trap '' TERM; echo $$ > \"$1\"; exec sleep 5", "sh", path],
            "",
            5_000
          )
        end)
      end)

    try do
      assert_receive {:fixture_email, email}, 5_000
      assert wait_for_restart_file(path, System.monotonic_time(:millisecond) + 3_000)
      pid = path |> File.read!() |> String.trim()
      Process.exit(owner, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}, 1_000
      assert_receive :fixture_cleanup_started, 3_000
      assert {_, 1} = System.cmd("kill", ["-0", pid], stderr_to_stdout: true)
      assert {:error, [:worker_failed]} = NewYou.Proof.Scenario.stop(scenario)

      Ecto.Adapters.SQL.Sandbox.unboxed_run(NewYou.Repo, fn ->
        assert %{rows: [[0]]} =
                 NewYou.Repo.query!("SELECT count(*) FROM accounts WHERE email = $1", [email])
      end)

      File.rm!(path)
    after
      if Process.alive?(scenario.controller), do: NewYou.Proof.Scenario.stop(scenario)
    end
  end

  test "fixture cleanup fails closed when a registered worker exits unconfirmed" do
    previous = Application.fetch_env(:new_you, :p8_15_browser_development_fixtures)

    assert_raise RuntimeError, "P8-05 fixture cleanup unconfirmed", fn ->
      NewYou.Proof.P805.with_fixture(fn ->
        {worker, monitor} =
          spawn_monitor(fn -> receive do: (:stop -> exit(:cleanup_unconfirmed)) end)

        :ok = NewYou.Proof.P805.register_cleanup_worker(worker)
        send(worker, :stop)
        assert_receive {:DOWN, ^monitor, :process, ^worker, :cleanup_unconfirmed}, 1_000
      end)
    end

    assert Application.fetch_env(:new_you, :p8_15_browser_development_fixtures) == previous

    Ecto.Adapters.SQL.Sandbox.unboxed_run(NewYou.Repo, fn ->
      assert %{rows: [[1]]} = NewYou.Repo.query!("SELECT 1")
    end)
  end

  test "abnormal worker exit does not strand synthetic account records" do
    operation_id = Ecto.UUID.generate()
    email = "proof-#{operation_id}@example.test"
    recovery_operation = Ecto.UUID.generate()

    on_exit(fn ->
      NewYou.Proof.P805.with_fixture(fn ->
        NewYou.Proof.P805.track_operation(recovery_operation)
        NewYou.Proof.P805.request(%{operation_id: operation_id, email: email})
      end)
    end)

    assert_raise RuntimeError, "P8-05 fixture cleanup unconfirmed", fn ->
      NewYou.Proof.P805.with_fixture(fn ->
        request = NewYou.Proof.P805.request(%{operation_id: operation_id, email: email})
        {:ok, registration} = NewYou.Identity.register(request)
        {:ok, :verified} = NewYou.Identity.verify_email(registration.verification_proof)
        NewYou.Proof.P805.track_operation(recovery_operation)
        :ok = NewYou.Identity.request_recovery(email, "af", recovery_operation)

        assert NewYou.Proof.P805.scalar(
                 "SELECT count(*) FROM recovery_cases WHERE account_id = $1",
                 [Ecto.UUID.dump!(registration.account_id)]
               ) == 1

        {worker, monitor} =
          spawn_monitor(fn -> receive do: (:fail -> exit(:cleanup_unconfirmed)) end)

        :ok = NewYou.Proof.P805.register_cleanup_worker(worker)
        send(worker, :fail)
        assert_receive {:DOWN, ^monitor, :process, ^worker, :cleanup_unconfirmed}, 1_000
      end)
    end

    Ecto.Adapters.SQL.Sandbox.unboxed_run(NewYou.Repo, fn ->
      assert %{rows: [[0]]} =
               NewYou.Repo.query!("SELECT count(*) FROM accounts WHERE email = $1", [email])

      assert %{rows: [[0]]} =
               NewYou.Repo.query!(
                 "SELECT count(*) FROM message_intents WHERE source_operation_id = $1",
                 [Ecto.UUID.dump!(operation_id)]
               )

      assert %{rows: [[0]]} =
               NewYou.Repo.query!("SELECT count(*) FROM recovery_cases WHERE operation_id = $1", [
                 Ecto.UUID.dump!(recovery_operation)
               ])

      assert %{rows: [[0]]} =
               NewYou.Repo.query!(
                 "SELECT count(*) FROM message_intents WHERE source_operation_id = $1",
                 [Ecto.UUID.dump!(recovery_operation)]
               )
    end)
  end

  test "a failed fixture worker does not release the guardian while another worker is live" do
    parent = self()

    {owner, owner_monitor} =
      spawn_monitor(fn ->
        try do
          NewYou.Proof.P805.with_fixture(fn ->
            guardian = Process.get({NewYou.Proof.P805, :guardian})
            failed = spawn(fn -> receive do: (:fail -> exit(:cleanup_unconfirmed)) end)
            live = spawn(fn -> receive do: (:finish -> :ok) end)
            :ok = NewYou.Proof.P805.register_cleanup_worker(failed)
            :ok = NewYou.Proof.P805.register_cleanup_worker(live)
            failed_monitor = Process.monitor(failed)
            send(failed, :fail)
            receive do: ({:DOWN, ^failed_monitor, :process, ^failed, _} -> :ok)
            send(parent, {:fixture_workers, guardian, live})
          end)
        rescue
          error -> send(parent, {:fixture_result, Exception.message(error)})
        end
      end)

    assert_receive {:fixture_workers, guardian, live}, 5_000
    on_exit(fn -> Process.exit(live, :kill) end)
    refute_receive {:fixture_result, _}, 300
    assert Process.alive?(guardian)
    assert Process.alive?(live)
    send(live, :finish)
    assert_receive {:fixture_result, "P8-05 fixture cleanup unconfirmed"}, 5_000
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :normal}, 1_000
  end

  test "fixture worker timeout retains guardian and environment until the worker stops" do
    parent = self()
    previous = Application.fetch_env(:new_you, :p8_15_browser_development_fixtures)
    Application.put_env(:new_you, :p8_15_browser_development_fixtures, :before_fixture)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:new_you, :p8_15_browser_development_fixtures, value)
        :error -> Application.delete_env(:new_you, :p8_15_browser_development_fixtures)
      end
    end)

    spawn(fn ->
      try do
        NewYou.Proof.P805.with_fixture(fn ->
          guardian = Process.get({NewYou.Proof.P805, :guardian})
          worker = spawn(fn -> receive do: (:finish -> :ok) end)
          :ok = NewYou.Proof.P805.register_cleanup_worker(worker)
          send(parent, {:timeout_worker, guardian, worker})
        end)
      rescue
        error -> send(parent, {:timeout_result, Exception.message(error)})
      end
    end)

    assert_receive {:timeout_worker, guardian, worker}, 5_000
    on_exit(fn -> Process.exit(worker, :kill) end)
    guardian_monitor = Process.monitor(guardian)
    assert_receive {:timeout_result, "P8-05 fixture cleanup unconfirmed"}, 6_000
    assert Process.alive?(guardian)
    assert Process.alive?(worker)
    assert Application.get_env(:new_you, :p8_15_browser_development_fixtures) == true

    assert_raise RuntimeError, ~r/fixture.*(active|quarantin)/i, fn ->
      NewYou.Proof.P805.with_fixture(fn -> :unexpected end)
    end

    send(worker, :finish)
    assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, _}, 5_000
    assert Application.get_env(:new_you, :p8_15_browser_development_fixtures) == :before_fixture
  end

  test "fixture cleanup uncertainty is not hidden by a callback failure" do
    assert_raise RuntimeError, "P8-05 fixture cleanup unconfirmed after callback failure", fn ->
      NewYou.Proof.P805.with_fixture(fn ->
        {worker, monitor} =
          spawn_monitor(fn -> receive do: (:stop -> exit(:cleanup_unconfirmed)) end)

        :ok = NewYou.Proof.P805.register_cleanup_worker(worker)
        send(worker, :stop)
        assert_receive {:DOWN, ^monitor, :process, ^worker, :cleanup_unconfirmed}, 1_000
        raise "synthetic callback failure"
      end)
    end
  end

  if System.get_env("P815_CHARACTERIZE_BUDGET") == "1" do
    for scenario <- [:known, :unknown, :malformed, :replay, :contended], replicate <- 1..3 do
      test "hosted budget #{scenario} pair #{replicate}" do
        P815.characterize_budget(unquote(scenario), unquote(replicate))
      end
    end
  end

  # These additional fault controls require the per-job provisioner marker.
  # Existing interruption and skip-cut proofs run in every environment.
  if System.get_env("GITHUB_ACTIONS") == "true" do
    test "fresh timing-only resume commits" do
      P815.calibrate_recovery_lease(:baseline)
    end

    test "fresh monitored resume commits" do
      P815.calibrate_recovery_lease(:observe)
    end

    test "fresh child attributes its deliberately expired client lease" do
      P815.calibrate_recovery_lease(:expiry)
    end

    test "fresh child distinguishes explicit check-in from deadline expiry" do
      P815.calibrate_recovery_lease(:checkin)
    end
  end

  defp wait_for_restart_file(path, deadline) do
    cond do
      File.exists?(path) ->
        true

      System.monotonic_time(:millisecond) >= deadline ->
        false

      true ->
        receive do
        after
          10 -> wait_for_restart_file(path, deadline)
        end
    end
  end

  test "recovery waits for an earlier email fixture commit and rejects its stale binding" do
    assert P815.prior_email_commit_race()
  end

  test "competing completions serialize and only one credential change commits" do
    assert P815.completion_race()
  end

  test "completion commits before competing cancellation without reopening recovery" do
    assert P815.terminal_race(:complete)
  end

  test "cancellation commits before competing completion without changing credentials" do
    assert P815.terminal_race(:cancel)
  end

  test "old password login waits for completion and cannot create a session" do
    assert P815.stale_login_race()
  end

  test "stale password reset proof cannot race past recovery completion with an unrelated proof retained" do
    assert P815.reset_vs_recovery_race()
  end

  test "stale-reset recovery race preserves a valid independent owner's reset proof" do
    assert P815.reset_vs_recovery_race(fn race ->
             parent = self()
             reference = make_ref()

             foreign =
               NewYou.Proof.P805.independent_fixture_task(fn ->
                 {request, registration} = NewYou.Proof.ResetCases.account()
                 {proof, _bearer} = NewYou.Proof.ResetCases.issue(request, registration)
                 before = NewYou.Proof.ResetCases.reset_security_snapshot(registration.account_id)
                 valid? = match?({:ok, _}, NewYou.Proof.ResetCases.delivery(proof, request.email))
                 send(parent, {reference, :ready, valid?})

                 receive do
                   {^reference, :verify} ->
                     preserved? =
                       NewYou.Proof.ResetCases.reset_security_snapshot(registration.account_id) ==
                         before

                     valid? =
                       match?({:ok, _}, NewYou.Proof.ResetCases.delivery(proof, request.email))

                     send(parent, {reference, :preserved, preserved? and valid?})
                     receive do: ({^reference, :release} -> :ok)

                   {^reference, :release} ->
                     :ok
                 after
                   15_000 -> raise "foreign reset fixture release deadline"
                 end
               end)

             try do
               assert_receive {^reference, :ready, true}, 5_000
               assert race.()
               send(foreign.pid, {reference, :verify})
               assert_receive {^reference, :preserved, true}, 5_000
               true
             after
               send(foreign.pid, {reference, :release})
               assert :ok = Task.await(foreign, 10_000)
             end
           end)
  end

  test "proof acceptance rolls back when its transaction worker terminates" do
    assert P815.interrupted_acceptance()
  end

  test "pre-commit request termination rolls back before a new worker resumes the same case" do
    assert P815.interrupted_request() == :ok
  end

  test "an already aborted request cannot prove rollback by terminating its worker" do
    assert_raise ExUnit.AssertionError,
                 ~r/exact transaction was no longer in progress at the cut/,
                 fn ->
                   P815.interrupted_request(expire_before_cut?: true)
                 end
  end

  test "recovery delivery and completion receipts survive fresh BEAM processes" do
    assert P815.restart_proof() == :ok
  end

  defp await_initial_lease_loss(parent, reference, deadline) do
    assert System.monotonic_time(:millisecond) < deadline

    try do
      NewYou.Repo.query!("SELECT 1")
    rescue
      error in DBConnection.ConnectionError ->
        send(parent, {reference, :initial_lease_expired})
        reraise error, __STACKTRACE__
    end

    receive do
    after
      5 -> await_initial_lease_loss(parent, reference, deadline)
    end
  end
end
