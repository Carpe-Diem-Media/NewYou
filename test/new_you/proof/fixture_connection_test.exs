defmodule NewYou.Proof.FixtureConnectionTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}
  alias NewYou.Proof.P805
  import ExUnit.CaptureLog

  test "fixture teardown survives a borrowed connection being disconnected" do
    capture_log(fn ->
      assert :callback_completed =
               P805.with_fixture(fn ->
                 guardian = Process.get({P805, :guardian})

                 on_exit(fn ->
                   monitor = Process.monitor(guardian)

                   receive do
                     {:DOWN, ^monitor, :process, ^guardian, reason}
                     when reason in [:normal, :noproc] ->
                       :ok
                   after
                     5_000 -> flunk("fixture guardian did not finish recovery")
                   end
                 end)

                 input = P805.request()
                 {:ok, registration} = Identity.register(input)
                 Process.put(:disconnected_fixture_account, registration.account_id)

                 task =
                   Task.Supervisor.async_nolink(
                     NewYou.Identity.MagicLogin.RequestSupervisor,
                     fn -> Repo.query!("SELECT pg_sleep(1)", [], timeout: 25) end
                   )

                 assert {:exit, _reason} = Task.yield(task, 2_000)
                 :callback_completed
               end)
    end)

    account_id = Process.delete(:disconnected_fixture_account)

    Sandbox.unboxed_run(Repo, fn ->
      assert P805.scalar("SELECT count(*) FROM accounts WHERE id = $1", [
               Ecto.UUID.dump!(account_id)
             ]) == 0
    end)
  end

  test "fixture guardian retries a transient teardown failure" do
    attempts = :atomics.new(1, [])
    parent = self()

    hook = fn ->
      attempt = :atomics.add_get(attempts, 1, 1)
      send(parent, {:fixture_cleanup_attempt, attempt})
      if attempt == 1, do: raise("synthetic teardown failure")
      :ok
    end

    Process.put({P805, :fixture_cleanup_hook}, hook)
    on_exit(fn -> Process.delete({P805, :fixture_cleanup_hook}) end)

    assert_raise RuntimeError, "original fixture failure", fn ->
      P805.with_fixture(fn ->
        projection_key = P805.analytics_projection_key()
        assert :ok = NewYou.Analytics.rebuild_p817_privacy_projection()

        assert P805.scalar(
                 "SELECT count(*) FROM p817_privacy_projections WHERE projection_key = $1",
                 [projection_key]
               ) == 1

        send(parent, {:fixture_projection_key, projection_key})
        raise "original fixture failure"
      end)
    end

    assert_receive {:fixture_cleanup_attempt, 1}, 5_000
    assert_receive {:fixture_cleanup_attempt, 2}, 5_000
    assert_receive {:fixture_projection_key, projection_key}
    assert :atomics.get(attempts, 1) == 2

    Sandbox.unboxed_run(Repo, fn ->
      assert P805.scalar(
               "SELECT count(*) FROM p817_privacy_projections WHERE projection_key = $1",
               [projection_key]
             ) == 0
    end)
  end

  test "persistent fixture teardown failure remains unconfirmed" do
    attempts = :atomics.new(1, [])
    parent = self()

    Process.put({P805, :fixture_cleanup_hook}, fn ->
      attempt = :atomics.add_get(attempts, 1, 1)
      send(parent, {:fixture_cleanup_attempt, attempt})
      raise "synthetic persistent teardown failure"
    end)

    on_exit(fn -> Process.delete({P805, :fixture_cleanup_hook}) end)

    assert_raise RuntimeError, "P8-05 fixture cleanup unconfirmed", fn ->
      P805.with_fixture(fn -> :callback_completed end)
    end

    assert_receive {:fixture_cleanup_attempt, 1}, 5_000
    assert_receive {:fixture_cleanup_attempt, 2}, 5_000
    assert :atomics.get(attempts, 1) == 2
  end

  test "setup failure before checkout restores fixture process and environment state" do
    previous_key = Process.get({NewYou.Analytics, :p817_test_projection_key}, :missing)
    previous_secret = Application.fetch_env(:new_you, :identity_token_signing_secret)
    Process.put({NewYou.Analytics, :p817_test_projection_key}, "preexisting-test-key")
    Process.put({P805, :setup_checkpoint}, fn :configured -> raise "synthetic setup failure" end)

    on_exit(fn ->
      Process.delete({P805, :setup_checkpoint})

      if previous_key == :missing do
        Process.delete({NewYou.Analytics, :p817_test_projection_key})
      else
        Process.put({NewYou.Analytics, :p817_test_projection_key}, previous_key)
      end
    end)

    assert_raise RuntimeError, "synthetic setup failure", fn ->
      P805.with_fixture(fn -> flunk("fixture callback ran after setup failure") end)
    end

    assert Application.fetch_env(:new_you, :identity_token_signing_secret) == previous_secret
    assert Process.get({NewYou.Analytics, :p817_test_projection_key}) == "preexisting-test-key"
    refute Process.get({P805, :guardian})
    refute Process.get({P805, :fixture_checked_out})
  end

  test "P8-18 reports persistent fixture cleanup failure" do
    case_id = "p818.analytics_projection"

    registration =
      Enum.find(NewYou.Proof.P818Catalog.registrations(), &(&1.case_id == case_id))

    attempts = :atomics.new(1, [])
    parent = self()

    {case_result, cleanup} =
      NewYou.Proof.SelfTest.execute_registered_case(
        Map.put(registration.manifest, :version, "p8-18.hardening"),
        fn ->
          Process.put({P805, :fixture_cleanup_hook}, fn ->
            if :atomics.add_get(attempts, 1, 1) == 1 do
              send(parent, {
                :fixture_scope,
                P805.analytics_projection_key(),
                Process.get({P805, :operations}, [])
              })
            end

            raise "synthetic persistent teardown failure"
          end)

          registration.callback.()
        end
      )

    assert case_result["verdict"] == "FAIL"
    assert cleanup.connections_released == false
    assert cleanup.locks_released == false

    assert_receive {:fixture_scope, projection_key, operation_ids}

    Sandbox.unboxed_run(Repo, fn ->
      assert P805.scalar(
               "SELECT count(*) FROM p817_privacy_projections WHERE projection_key = $1",
               [projection_key]
             ) == 1
    end)

    P805.with_fixture(fn -> Enum.each(operation_ids, &P805.track_operation/1) end)

    Sandbox.unboxed_run(Repo, fn ->
      :ok = P805.cleanup_test_analytics_projection(projection_key)

      assert P805.scalar(
               "SELECT count(*) FROM p817_privacy_projections WHERE projection_key = $1",
               [projection_key]
             ) == 0

      assert P805.scalar(
               "SELECT count(*) FROM privacy_purpose_authorities WHERE source_operation_id = ANY($1::uuid[])",
               [Enum.map(operation_ids, &Ecto.UUID.dump!/1)]
             ) == 0

      assert P805.scalar(
               "SELECT count(*) FROM privacy_purpose_events WHERE source_operation_id = ANY($1::uuid[])",
               [Enum.map(operation_ids, &Ecto.UUID.dump!/1)]
             ) == 0
    end)
  end
end
