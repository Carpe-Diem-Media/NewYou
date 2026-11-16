defmodule NewYou.Proof.ConcurrentTest do
  use ExUnit.Case, async: false

  alias NewYou.Proof.{Concurrent, Scenario}

  test "run gives each callback an independent checked out backend without a transaction" do
    scenario = Scenario.start()
    parent = self()

    callbacks =
      for label <- [:one, :two], into: %{} do
        {label,
         fn ->
           {:ok, %{rows: [[pid, xid]]}} =
             NewYou.Repo.query("SELECT pg_backend_pid(), pg_current_xact_id_if_assigned()::text")

           send(parent, {:callback, label, pid, xid})
           :ok
         end}
      end

    assert {:ok, %{outcomes: outcomes}} = Concurrent.run(scenario, callbacks, timeout: 2_000)
    assert Enum.sort(Map.keys(outcomes)) == [:one, :two]
    assert_receive {:callback, :one, first_pid, nil}
    assert_receive {:callback, :two, second_pid, nil}
    assert first_pid != second_pid
    assert :ok = Scenario.stop(scenario)
  end

  test "run does not inherit a parent-owned sandbox connection" do
    scenario = Scenario.start()
    assert :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo)

    assert {:ok, %{outcomes: %{one: %{outcome: :ok}}}} =
             Concurrent.run(scenario, %{one: fn -> :ok end}, timeout: 500)

    assert :ok = Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
    assert :ok = Scenario.stop(scenario)
  end

  test "run rejects callback results that can contain unbounded sensitive values" do
    scenario = Scenario.start()

    assert {:error, %{reason: :unsafe_callback_outcome}} =
             Concurrent.run(scenario, %{unsafe: fn -> "secret canary" end}, timeout: 500)

    assert :ok = Scenario.stop(scenario)
  end

  test "run kills a timed out worker and reports bounded cleanup" do
    scenario = Scenario.start()
    parent = self()

    assert {:error, %{reason: :timeout}} =
             Concurrent.run(
               scenario,
               %{
                 stuck: fn ->
                   send(parent, {:stuck_worker, self()})
                   Process.sleep(:infinity)
                 end
               },
               timeout: 50
             )

    assert_receive {:stuck_worker, worker}
    refute Process.alive?(worker)
    assert {:error, _} = Scenario.stop(scenario)
  end

  test "run cleans up its peers after a worker is killed" do
    scenario = Scenario.start()

    coordinator =
      spawn(fn ->
        receive do
          {:ready, :crashing, crashing} ->
            receive do
              {:ready, :waiting, waiting} ->
                send(crashing, :kill_now)
                send(waiting, :wait_forever)
            end
        end
      end)

    callbacks = %{
      crashing: fn ->
        send(coordinator, {:ready, :crashing, self()})
        receive do: (:kill_now -> Process.exit(self(), :kill))
      end,
      waiting: fn ->
        send(coordinator, {:ready, :waiting, self()})
        receive do: (:wait_forever -> Process.sleep(:infinity))
      end
    }

    assert {:error, %{reason: {:worker_down, :killed}}} =
             Concurrent.run(scenario, callbacks, timeout: 1_000)

    refute Process.alive?(coordinator)
    assert [] = Scenario.owned_processes(scenario)
    assert {:error, _} = Scenario.stop(scenario)
  end

  test "cleanup acknowledgement consumes controller DOWNs queued after the request" do
    scenario = Scenario.start()
    {worker, monitor} = Scenario.spawn(scenario, :worker, fn -> receive do: (:finish -> :ok) end)
    [{^worker, guardian}] = Scenario.owned_processes(scenario)
    guardian_monitor = Process.monitor(guardian)

    # monitor/2 sends an asynchronous signal. Confirm the monitor at the
    # guardian before another process can make it exit. process_info/2 observes
    # signals from this caller in order; a returned reference alone is not an ack.
    assert {:monitored_by, monitoring_processes} = Process.info(guardian, :monitored_by)
    assert self() in monitoring_processes
    request_ref = make_ref()

    # Queue the acknowledgement before either DOWN in the controller mailbox,
    # while the owner independently observes both deaths. No timing sleep.
    :erlang.suspend_process(scenario.controller)

    try do
      send(scenario.controller, {
        :scenario_request,
        scenario.reference,
        request_ref,
        self(),
        {:await_owned_down, [worker], 1_000}
      })

      send(worker, :finish)
      assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}
    after
      :erlang.resume_process(scenario.controller)
    end

    assert_receive {:scenario_reply, ^request_ref, :ok}, 2_000
    assert [] = Scenario.owned_processes(scenario)
    assert :ok = Scenario.stop(scenario)
  end

  test "cleanup acknowledgement preserves excluded workers and fails closed for live targets" do
    scenario = Scenario.start()
    {worker, monitor} = Scenario.spawn(scenario, :worker, fn -> receive do: (:finish -> :ok) end)

    {observer, _monitor} =
      Scenario.spawn(scenario, :observer, fn -> receive do: (:finish -> :ok) end)

    send(worker, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}

    assert :ok = Scenario.request(scenario, {:await_owned_down, [worker], 1_000})
    assert [{^observer, guardian}] = Scenario.owned_processes(scenario)
    assert Process.alive?(guardian)

    assert {:error, :cleanup_timeout} =
             Scenario.request(scenario, {:await_owned_down, [observer], 10})

    assert [{^observer, ^guardian}] = Scenario.owned_processes(scenario)
    assert {:error, _} = Scenario.stop(scenario)
  end

  test "run reports unconfirmed cleanup when the scenario controller is lost" do
    scenario = Scenario.start()
    parent = self()

    killer =
      spawn(fn ->
        receive do
          {:callback_waiting, worker} ->
            send(parent, {:controller_killed, worker})
            Process.exit(scenario.controller, :kill)
        end
      end)

    result =
      Concurrent.run(
        scenario,
        %{
          waiting: fn ->
            send(killer, {:callback_waiting, self()})
            Process.sleep(:infinity)
          end
        },
        timeout: 1_000
      )

    assert_receive {:controller_killed, worker}
    assert {:error, %{cleanup: %{confirmed: false}}} = result
    refute Process.alive?(worker)
  end

  test "a worker death rolls back its PostgreSQL transaction" do
    scenario = Scenario.start()
    parent = self()

    callback = fn ->
      NewYou.Repo.transaction(fn ->
        {:ok, %{rows: [[xid]]}} =
          NewYou.Repo.query("SELECT pg_current_xact_id()::text")

        {:ok, %{rows: [[backend_pid]]}} = NewYou.Repo.query("SELECT pg_backend_pid()")

        send(parent, {:transaction_xid, xid, backend_pid})
        Process.exit(self(), :kill)
      end)
    end

    assert {:error, %{reason: {:worker_down, :killed}}} =
             Concurrent.run(scenario, %{transaction: callback}, timeout: 1_000)

    assert_receive {:transaction_xid, xid, old_backend_pid}
    assert :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)
    xid = String.to_integer(xid)

    try do
      assert eventually(fn ->
               case NewYou.Repo.query("SELECT pg_xact_status($1::xid8)", [xid]) do
                 {:ok, %{rows: [["aborted"]]}} -> true
                 _ -> false
               end
             end)
    after
      assert :ok = Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
    end

    replacement = Scenario.start()
    parent = self()

    assert {:ok, %{outcomes: %{replacement: %{outcome: :ok}}}} =
             Concurrent.run(
               replacement,
               %{
                 replacement: fn ->
                   {:ok, %{rows: [[new_backend_pid]]}} =
                     NewYou.Repo.query("SELECT pg_backend_pid()")

                   send(parent, {:replacement_backend_pid, new_backend_pid})
                   :ok
                 end
               },
               timeout: 1_000
             )

    assert_receive {:replacement_backend_pid, new_backend_pid}
    assert new_backend_pid != old_backend_pid
    assert :ok = Scenario.stop(replacement)
    assert {:error, _} = Scenario.stop(scenario)
  end

  test "a PostgreSQL lock timeout is observed and leaves no advisory lock" do
    scenario = Scenario.start()
    parent = self()
    watcher = spawn(fn -> coordinate_lock_timeout(parent) end)
    lock_key = rem(System.unique_integer([:positive, :monotonic]), 2_000_000_000) + 1

    callbacks = %{
      owner: fn ->
        NewYou.Repo.transaction(fn ->
          {:ok, _} = NewYou.Repo.query("SELECT pg_advisory_xact_lock(7319, $1)", [lock_key])
          send(watcher, {:owner_locked, self()})
          receive do: (:release -> :released)
        end)
      end,
      waiter: fn ->
        send(watcher, {:waiter_ready, self()})
        receive do: (:attempt -> :ok)

        result =
          NewYou.Repo.transaction(fn ->
            {:ok, _} = NewYou.Repo.query("SELECT set_config('lock_timeout', '25ms', true)")

            case NewYou.Repo.query("SELECT pg_advisory_xact_lock(7319, $1)", [lock_key]) do
              {:error, %Postgrex.Error{postgres: %{pg_code: "55P03"}}} ->
                NewYou.Repo.rollback(:postgres_lock_timeout)

              {:ok, _} ->
                :unexpected_acquisition

              {:error, _error} ->
                NewYou.Repo.rollback(:unexpected_database_error)
            end
          end)

        send(watcher, {:waiter_result, result})
        result
      end
    }

    assert {:ok, %{outcomes: outcomes}} = Concurrent.run(scenario, callbacks, timeout: 2_000)
    assert outcomes.owner.outcome == [:ok, :released]
    assert outcomes.waiter.outcome == [:error, :postgres_lock_timeout]
    assert outcomes.owner.backend_pid != outcomes.waiter.backend_pid
    assert_receive :lock_timeout_released
    assert :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

    try do
      assert {:ok, %{rows: [[0]]}} =
               NewYou.Repo.query(
                 "SELECT count(*) FROM pg_locks WHERE locktype = 'advisory' AND classid = 7319::oid AND objid = $1::oid AND objsubid = 2",
                 [lock_key]
               )
    after
      assert :ok = Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
    end

    assert :ok = Scenario.stop(scenario)
  end

  defp coordinate_lock_timeout(parent) do
    receive do
      {:waiter_ready, waiter} ->
        receive do
          {:owner_locked, owner} ->
            send(waiter, :attempt)

            receive do
              {:waiter_result, {:error, :postgres_lock_timeout}} ->
                send(owner, :release)
                send(parent, :lock_timeout_released)
            end
        end
    end
  end

  test "owner death stops connection workers and rolls back open transactions" do
    parent = self()

    {owner, owner_monitor} =
      spawn_monitor(fn ->
        scenario = Scenario.start()

        callback = fn ->
          NewYou.Repo.transaction(fn ->
            {:ok, %{rows: [[xid]]}} =
              NewYou.Repo.query("SELECT pg_current_xact_id()::text")

            {:ok, %{rows: [[backend_pid]]}} = NewYou.Repo.query("SELECT pg_backend_pid()")
            send(parent, {:owner_context, scenario.controller, self(), xid, backend_pid})
            Process.sleep(:infinity)
          end)
        end

        Concurrent.run(scenario, %{owner_dies: callback}, timeout: 20_000)
      end)

    assert_receive {:owner_context, controller, worker, xid, backend_pid}
    controller_monitor = Process.monitor(controller)
    worker_monitor = Process.monitor(worker)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :killed}
    assert_receive {:DOWN, ^worker_monitor, :process, ^worker, _reason}
    assert_receive {:DOWN, ^controller_monitor, :process, ^controller, _reason}

    assert :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)
    xid = String.to_integer(xid)

    try do
      assert eventually(fn ->
               case NewYou.Repo.query("SELECT pg_xact_status($1::xid8)", [xid]) do
                 {:ok, %{rows: [["aborted"]]}} -> true
                 _ -> false
               end
             end)

      assert {:ok, %{rows: [[0]]}} =
               NewYou.Repo.query(
                 "SELECT count(*) FROM pg_stat_activity WHERE pid = $1 AND xact_start IS NOT NULL",
                 [backend_pid]
               )
    after
      assert :ok = Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
    end
  end

  defp eventually(predicate, attempts \\ 100)
  defp eventually(_predicate, 0), do: false

  defp eventually(predicate, attempts) do
    if predicate.() do
      true
    else
      Process.sleep(10)
      eventually(predicate, attempts - 1)
    end
  end

  test "infrastructure fixture reports real observed PostgreSQL contention and cleanup" do
    scenario = Scenario.start()
    stale_run_pid = self()
    send(self(), {:concurrent_tx_done, stale_run_pid, :a, {:ok, :released}})

    assert {:ok, result} = Concurrent.infrastructure_fixture(scenario, timeout: 5_000)
    assert result.contention_observed
    assert result.backend_pids.a != result.backend_pids.b
    assert result.transaction_ids.a != result.transaction_ids.b
    assert result.acquisition_order == [:a, :b]
    assert result.cleanup.confirmed
    assert_receive {:concurrent_tx_done, ^stale_run_pid, :a, {:ok, :released}}
    assert :ok = Scenario.stop(scenario)
  end

  test "infrastructure fixture rejects overlapping independent transactions without blocking" do
    scenario = Scenario.start()

    assert {:error, result} =
             Concurrent.infrastructure_fixture(scenario, fixture: :nonblocking, timeout: 2_000)

    assert result.reason == :contention_not_observed
    assert Map.fetch!(result, :overlap_observed)
    refute result.contention_observed
    assert length(Map.values(result.backend_pids) |> Enum.uniq()) == 3
    assert result.transaction_ids.a != result.transaction_ids.b
    assert result.cleanup.confirmed, inspect(result)
    assert :ok = Scenario.stop(scenario)
  end

  test "infrastructure fixture rejects Sandbox.allow shared ownership" do
    scenario = Scenario.start()

    assert {:error, result} =
             Concurrent.infrastructure_fixture(scenario,
               fixture: :shared_connection,
               timeout: 2_000
             )

    assert result.reason == :shared_connection_rejected
    assert result.backend_pids.a == result.backend_pids.b
    assert result.cleanup.confirmed
    assert result.cleanup.locks_remaining == 0
    assert result.cleanup.active_transactions == 0
    assert :ok = Scenario.stop(scenario)
  end

  test "infrastructure fixture rejects sequential PostgreSQL transactions" do
    scenario = Scenario.start()

    assert {:error, result} =
             Concurrent.infrastructure_fixture(scenario, fixture: :sequential, timeout: 2_000)

    assert result.reason == :sequential_execution_rejected
    assert result.backend_pids.a == result.backend_pids.b
    assert result.transaction_ids.a != result.transaction_ids.b
    refute result.contention_observed
    assert result.cleanup.confirmed
    assert :ok = Scenario.stop(scenario)
  end

  test "infrastructure fixture bounds pool exhaustion and reports unavailable capacity" do
    scenario = Scenario.start()
    parent = self()

    holders =
      for index <- 1..9 do
        Scenario.spawn(scenario, "pool_holder_#{index}", fn ->
          :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)
          send(parent, {:pool_held, self()})

          receive do
            :release -> Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
          end
        end)
      end

    holder_pids =
      Enum.map(holders, fn _holder ->
        assert_receive({:pool_held, pid})
        pid
      end)

    assert {:error, %{reason: :pool_unavailable, cleanup: %{confirmed: true}}} =
             Concurrent.infrastructure_fixture(scenario, timeout: 100)

    Enum.each(holder_pids, &send(&1, :release))
    assert :ok = await_owned_processes(scenario)
    assert {:error, _} = Scenario.stop(scenario)
  end

  defp await_owned_processes(scenario, attempts \\ 100)
  defp await_owned_processes(_scenario, 0), do: {:error, :workers_still_alive}

  defp await_owned_processes(scenario, attempts) do
    case Scenario.owned_processes(scenario) do
      [] ->
        :ok

      _ ->
        Process.sleep(10)
        await_owned_processes(scenario, attempts - 1)
    end
  end
end
