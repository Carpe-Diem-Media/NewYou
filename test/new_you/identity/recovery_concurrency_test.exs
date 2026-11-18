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

  test "restarted recovery retries the same case after a bounded request loses its lease" do
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

  test "proof acceptance rolls back when its transaction worker terminates" do
    assert P815.interrupted_acceptance()
  end

  test "recovery delivery and completion receipts survive fresh BEAM processes" do
    assert P815.restart_proof() == :ok
  end
end
