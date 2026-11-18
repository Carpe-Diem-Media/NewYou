defmodule NewYou.Proof.FixtureLifecycleTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Proof.{P805, P805Fixture, P815Port}

  test "a proven Port opening failure permits fixture cleanup and sequential reuse" do
    parent = self()
    prior = Application.fetch_env(:new_you, :p8_15_browser_development_fixtures)

    {owner, monitor} =
      spawn_monitor(fn ->
        result =
          try do
            value =
              P805.with_fixture(fn ->
                guardian = Process.get({P805, :guardian})

                for {executable, options} <- [
                      {System.find_executable("sh"), [:invalid_p815_option]},
                      {"/definitely-missing-p815-launcher", [:binary, :exit_status]}
                    ] do
                  worker =
                    spawn(fn ->
                      receive do
                        :launch ->
                          result = P805.open_restart_port(guardian, executable, options)
                          send(parent, {:opening_failure, result})
                      end
                    end)

                  :ok = P805.register_cleanup_worker(worker)
                  worker_monitor = Process.monitor(worker)
                  send(worker, :launch)

                  receive do
                    {:DOWN, ^worker_monitor, :process, ^worker, reason} ->
                      assert reason == :normal
                  after
                    5_000 -> flunk("failed launch worker did not stop")
                  end
                end

                :completed
              end)

            {:ok, value}
          rescue
            error -> {:error, Exception.message(error)}
          end

        send(parent, {:fixture_result, result})
      end)

    assert_receive {:opening_failure, {:error, :not_started}}, 5_000
    assert_receive {:opening_failure, {:error, :not_started}}, 5_000
    assert_receive {:fixture_result, result}, 5_000
    assert_receive {:DOWN, ^monitor, :process, ^owner, :normal}, 1_000
    assert result == {:ok, :completed}
    assert P805.fixture_status() == :available
    assert Application.fetch_env(:new_you, :p8_15_browser_development_fixtures) == prior
    assert :next = P805.with_fixture(fn -> :next end)
  end

  test "only the current launch reservation can settle and admit its successor" do
    fixture = P805Fixture.acquire([], "p815-launch-reservations", nil)

    try do
      assert {:ok, first} = P805Fixture.begin_external(fixture)
      snapshot = P805.fixture_status()
      assert {:error, :launch_unavailable} = P805Fixture.begin_external(fixture)

      assert {:error, :stale_launch} =
               P805Fixture.settle_external(fixture, make_ref(), :not_started)

      assert P805.fixture_status() == snapshot
      assert :ok = P805Fixture.settle_external(fixture, first, :not_started)

      assert {:ok, second} = P805Fixture.begin_external(fixture)
      refute first == second
      snapshot = P805.fixture_status()
      assert {:error, :stale_launch} = P805Fixture.settle_external(fixture, first, :not_started)

      assert {:error, :invalid_launch_transition} =
               P805Fixture.settle_external(fixture, second, :started)

      assert P805.fixture_status() == snapshot
      assert :ok = P805Fixture.settle_external(fixture, second, :not_started)
      assert :ok = P805Fixture.settling(fixture)
      assert {:error, :launch_unavailable} = P805Fixture.begin_external(fixture)
    after
      # No Port is opened in this transition test. Settle only its actual current reservation.
      case P805.fixture_status() do
        %{reference: ^fixture, external_launch: %{reference: launch, port: nil}} ->
          P805Fixture.settle_external(fixture, launch, :not_started)

        _ ->
          :ok
      end

      assert :ok = P805Fixture.finish(fixture, fn _ -> :ok end)
    end
  end

  test "successful sequential launches reuse one fixture without losing earlier targets" do
    prior = Application.fetch_env(:new_you, :p8_15_browser_development_fixtures)

    P805.with_fixture(fn ->
      for count <- 1..3 do
        assert %{status: :ok, marker: :requested, cleanup: :confirmed} =
                 P815Port.run(
                   System.find_executable("sh"),
                   ["-c", "printf 'P815_REQUESTED\\n'"],
                   ""
                 )

        assert %{external_launch: nil, ports: ports} = P805.fixture_status()
        assert map_size(ports) == count
      end
    end)

    assert P805.fixture_status() == :available
    assert Application.fetch_env(:new_you, :p8_15_browser_development_fixtures) == prior
  end

  test "an admission orphaned before guardian attachment has an explicit recovery path" do
    parent = self()
    prior = Application.fetch_env(:new_you, :p8_15_browser_development_fixtures)

    {owner, monitor} =
      spawn_monitor(fn ->
        reference =
          NewYou.Proof.P805Fixture.acquire(
            [:p8_15_browser_development_fixtures],
            "p817_test_" <> Ecto.UUID.generate(),
            nil
          )

        send(parent, {:admission, reference})
        receive do: (:finish -> :ok)
      end)

    assert_receive {:admission, reference}, 1_000
    assert {:error, :not_quarantined} = P805.reconcile_fixture(reference)

    assert_raise RuntimeError, "P8-05 fixture already active or quarantined", fn ->
      P805.with_fixture(fn -> :unexpected end)
    end

    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}, 1_000
    assert :ok = P805.reconcile_fixture(reference)
    assert P805.fixture_status() == :available
    assert Application.fetch_env(:new_you, :p8_15_browser_development_fixtures) == prior
  end

  test "an interrupted post-open launch is never classified as not started" do
    assert_launch_failure_proof("classification")
  end

  test "a second launch cannot overwrite an unidentified opened launch" do
    assert_launch_failure_proof("second_launch")
  end

  defp assert_launch_failure_proof(scenario) do
    diagnostic =
      P815Port.run(
        System.find_executable("mix"),
        ["run", "test/support/proof/p8_15_launch_failure.exs", scenario],
        ""
      )

    assert %{status: :ok, marker: :accepted, cleanup: :confirmed} = diagnostic
  end

  test "simultaneous contenders admit exactly one fixture owner" do
    parent = self()

    contenders =
      for _ <- 1..2 do
        spawn_monitor(fn ->
          receive do: (:attempt -> :ok)

          try do
            P805.with_fixture(fn ->
              send(parent, {:admitted, self()})
              receive do: (:finish -> :ok)
            end)
          rescue
            error -> send(parent, {:rejected, self(), Exception.message(error)})
          end
        end)
      end

    try do
      Enum.each(contenders, fn {pid, _} -> send(pid, :attempt) end)
      assert_receive {:admitted, owner}, 5_000
      assert_receive {:rejected, loser, "P8-05 fixture already active or quarantined"}, 5_000
      refute owner == loser
      refute_receive {:admitted, _}, 50
      send(owner, :finish)

      Enum.each(contenders, fn {pid, monitor} ->
        assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, 5_000
      end)

      assert P805.fixture_status() == :available
    after
      Enum.each(contenders, fn {pid, _} -> send(pid, :finish) end)
    end
  end

  test "admission precedes the environment snapshot and remains held throughout cleanup" do
    parent = self()
    prior = Application.fetch_env(:new_you, :p8_15_browser_development_fixtures)

    {owner, monitor} =
      spawn_monitor(fn ->
        Process.put({P805, :fixture_cleanup_hook}, fn ->
          send(parent, {:cleanup_paused, self()})
          receive do: (:continue_cleanup -> :ok)
        end)

        P805.with_fixture(fn -> :ok end)
      end)

    assert_receive {:cleanup_paused, ^owner}, 5_000

    {contender, contender_monitor} =
      spawn_monitor(fn ->
        receive do: (:attempt -> :ok)

        assert_raise RuntimeError, "P8-05 fixture already active or quarantined", fn ->
          P805.with_fixture(fn -> flunk("second fixture was admitted") end)
        end
      end)

    # Trace calls only, never return values. No environment secrets enter the trace.
    :erlang.trace_pattern({Application, :fetch_env, 2}, true, [:local])
    :erlang.trace(contender, true, [:call])

    try do
      send(contender, :attempt)
      assert_receive {:DOWN, ^contender_monitor, :process, ^contender, :normal}, 1_000
      refute_receive {:trace, ^contender, :call, {Application, :fetch_env, _}}, 50
      assert Process.alive?(owner)
      assert Application.get_env(:new_you, :p8_15_browser_development_fixtures) == true
    after
      :erlang.trace_pattern({Application, :fetch_env, 2}, false, [:local])
      send(owner, :continue_cleanup)
    end

    assert_receive {:DOWN, ^monitor, :process, ^owner, :normal}, 5_000
    assert P805.fixture_status() == :available
    assert Application.fetch_env(:new_you, :p8_15_browser_development_fixtures) == prior
    assert :next_fixture = P805.with_fixture(fn -> :next_fixture end)
    assert Application.fetch_env(:new_you, :p8_15_browser_development_fixtures) == prior
  end

  test "an external child surviving worker death quarantines the exact scope until verified reconciliation" do
    parent = self()
    prior = Application.fetch_env(:new_you, :p8_15_browser_development_fixtures)
    path = Path.join(System.tmp_dir!(), "p805-quarantine-#{Ecto.UUID.generate()}")

    {owner, monitor} =
      spawn_monitor(fn ->
        try do
          P805.with_fixture(fn ->
            request = P805.request()
            {:ok, registration} = NewYou.Identity.register(request)
            {:ok, :verified} = NewYou.Identity.verify_email(registration.verification_proof)
            recovery_operation = Ecto.UUID.generate()
            P805.track_operation(recovery_operation)
            :ok = NewYou.Identity.request_recovery(request.email, "af", recovery_operation)

            send(parent, {:synthetic_scope, request.email, recovery_operation})

            P815Port.run(
              System.find_executable("sh"),
              ["-c", "trap '' HUP TERM; echo $$ > \"$1\"; exec sleep 60", "sh", path],
              ""
            )
          end)
        rescue
          error -> send(parent, {:fixture_failed, Exception.message(error)})
        end
      end)

    assert_receive {:synthetic_scope, email, recovery_operation}, 5_000

    try do
      assert wait_until(fn -> File.exists?(path) end)
      pid = path |> File.read!() |> String.trim() |> String.to_integer()
      fixture = P805.fixture_status()
      assert fixture.emails == [email]
      assert recovery_operation in fixture.operations
      assert pid in Map.values(fixture.ports)
      [worker] = fixture.workers
      Process.exit(worker, :kill)

      assert_receive {:fixture_failed, "P8-05 fixture cleanup unconfirmed"}, 5_000
      assert_receive {:DOWN, ^monitor, :process, ^owner, :normal}, 1_000
      refute P815Port.external_stopped?(pid)
      assert P805.fixture_status().phase == :quarantined
      assert_scope(email, recovery_operation, 1)
      assert {:error, :processes_unconfirmed} = P805.reconcile_fixture(fixture.reference)

      assert_raise RuntimeError, "P8-05 fixture already active or quarantined", fn ->
        P805.with_fixture(fn -> flunk("quarantined fixture admitted another owner") end)
      end

      assert Application.get_env(:new_you, :p8_15_browser_development_fixtures) == true
      # The ownership record survives guardian death and keeps the exact scope.
      guardian_monitor = Process.monitor(fixture.guardian)
      Process.exit(fixture.guardian, :kill)
      assert_receive {:DOWN, ^guardian_monitor, :process, _, :killed}, 1_000
      assert P805.fixture_status().reference == fixture.reference
      assert {:error, :processes_unconfirmed} = P805.reconcile_fixture(fixture.reference)

      stop_group(pid)
      assert wait_until(fn -> P815Port.external_stopped?(pid) end)
      assert :ok = P805.reconcile_fixture(fixture.reference)
      assert P805.fixture_status() == :available
      assert_scope(email, recovery_operation, 0)
      assert Application.fetch_env(:new_you, :p8_15_browser_development_fixtures) == prior

      assert :next_fixture =
               P805.with_fixture(fn ->
                 current = P805.fixture_status().reference
                 assert {:error, :not_quarantined} = P805.reconcile_fixture(fixture.reference)
                 assert P805.fixture_status().reference == current
                 :next_fixture
               end)
    after
      # Exact PID/group created by this test only. Never reset shared TEST.
      case File.read(path) do
        {:ok, value} ->
          pid = value |> String.trim() |> String.to_integer()
          stop_group(pid)
          wait_until(fn -> P815Port.external_stopped?(pid) end)

        _ ->
          :ok
      end

      Process.exit(owner, :kill)

      case P805.fixture_status() do
        %{owner: ^owner, reference: reference} -> P805.reconcile_fixture(reference)
        _ -> :ok
      end

      File.rm(path)
    end
  end

  defp assert_scope(email, operation, count) do
    Sandbox.unboxed_run(NewYou.Repo, fn ->
      assert %{rows: [[^count]]} =
               NewYou.Repo.query!("SELECT count(*) FROM accounts WHERE email = $1", [email])

      assert %{rows: [[^count]]} =
               NewYou.Repo.query!("SELECT count(*) FROM recovery_cases WHERE operation_id = $1", [
                 Ecto.UUID.dump!(operation)
               ])

      assert %{rows: [[^count]]} =
               NewYou.Repo.query!(
                 "SELECT count(*) FROM message_intents WHERE source_operation_id = $1 AND role = 'account_recovery'",
                 [Ecto.UUID.dump!(operation)]
               )
    end)
  end

  defp stop_group(pid) do
    System.cmd("kill", ["-s", "KILL", "--", "-#{pid}"], stderr_to_stdout: true)
  end

  defp wait_until(callback, remaining \\ 200)
  defp wait_until(_callback, 0), do: false

  defp wait_until(callback, remaining) do
    if callback.() do
      true
    else
      receive do
      after
        10 -> wait_until(callback, remaining - 1)
      end
    end
  end
end
