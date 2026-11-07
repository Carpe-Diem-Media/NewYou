defmodule NewYou.Identity.MagicLoginRequestTimingTest do
  use ExUnit.Case, async: false
  require Ash.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}
  alias NewYou.Identity.{Account, Token}
  alias NewYou.Communications.MessageIntent
  alias NewYou.Proof.{P805, RegistrationSeam}

  test "eligible, unknown and ineligible requests share the public response window" do
    P805.with_fixture(fn ->
      eligible = account(true)
      ineligible = account(false)

      elapsed_by_class =
        for email <- [
              eligible.email,
              "unknown-#{Ecto.UUID.generate()}@example.test",
              ineligible.email
            ] do
          {result, elapsed} = request(email, operation())
          assert result == :ok
          assert_response_window(elapsed)
          elapsed
        end

      assert Enum.max(elapsed_by_class) - Enum.min(elapsed_by_class) < 150,
             "Account classes did not share the same padded response window"

      assert magic_count(eligible.account_id) == 1
      assert magic_count(ineligible.account_id) == 0
      assert intent_count() == 1
    end)
  end

  test "transaction failures keep the same response window and permit an unchanged retry" do
    P805.with_fixture(fn ->
      account = account(true)
      operation = operation()

      for failure <- [:exception, :exit] do
        Process.put(RegistrationSeam, {:observe, fn -> fail(failure) end})

        try do
          {result, elapsed} = request(account.email, operation)
          assert result == :ok
          assert_response_window(elapsed)
          assert magic_count(account.account_id) == 0
          assert intent_count() == 0
        after
          Process.delete(RegistrationSeam)
        end
      end

      for _ <- 1..2 do
        {result, elapsed} = request(account.email, operation)
        assert result == :ok
        assert_response_window(elapsed)
        assert magic_count(account.account_id) == 1
        assert intent_count() == 1
      end
    end)
  end

  test "a held Account lock exhausts the work budget without extending the public response" do
    P805.with_fixture(fn ->
      account = account(true)
      operation = operation()
      parent = self()
      reference = make_ref()

      {locker, locker_monitor} =
        database_worker(fn ->
          Ash.transact(Account, fn ->
            Account
            |> Ash.Query.filter(id == ^account.account_id)
            |> Ash.Query.lock(:for_update)
            |> Ash.read_one!(authorize?: false)

            send(parent, {reference, :locked, P805.scalar("SELECT pg_backend_pid()")})

            receive do
              {^reference, :release} -> :ok
            after
              5_000 -> raise "Account lock proof deadline"
            end
          end)
        end)

      assert_receive {^reference, :locked, locker_backend}, 2_000

      {requester, requester_monitor} =
        database_worker(fn ->
          send(parent, {reference, :request_backend, P805.scalar("SELECT pg_backend_pid()")})
          outcome = request(account.email, operation)
          send(parent, {reference, :result, outcome})
        end)

      try do
        assert_receive {^reference, :request_backend, requester_backend}, 2_000
        assert locker_backend != requester_backend
        assert_contention(locker_backend, requester_backend)
        assert_receive {^reference, :result, {result, elapsed}}, 1_500
        assert result == :ok
        assert_response_window(elapsed)
        assert magic_count(account.account_id) == 0
        assert intent_count() == 0
      after
        send(locker, {reference, :release})
        finish_worker(locker, locker_monitor)
        finish_worker(requester, requester_monitor)
      end

      {result, elapsed} = request(account.email, operation)
      assert result == :ok
      assert_response_window(elapsed)
      assert magic_count(account.account_id) == 1
      assert intent_count() == 1
    end)
  end

  test "slow application work is cancelled before the neutral response and cannot commit later" do
    P805.with_fixture(fn ->
      account = account(true)
      operation = operation()
      parent = self()
      reference = make_ref()

      {requester, requester_monitor} =
        database_worker(fn ->
          Process.put(RegistrationSeam, {:pause, parent, reference})
          outcome = request(account.email, operation)
          send(parent, {reference, :result, outcome})
        end)

      try do
        assert_receive {^reference, :before_commit, worker, _backend, _transaction}, 1_000
        worker_monitor = Process.monitor(worker)
        assert_receive {^reference, :result, {:ok, elapsed}}, 1_000
        assert_response_window(elapsed)
        assert_receive {:DOWN, ^worker_monitor, :process, ^worker, :killed}, 1_000
        send(worker, {reference, :release})
        assert magic_count(account.account_id) == 0
        assert intent_count() == 0
      after
        if Process.alive?(requester), do: Process.exit(requester, :kill)
        Process.demonitor(requester_monitor, [:flush])
      end

      {result, elapsed} = request(account.email, operation)
      assert result == :ok
      assert_response_window(elapsed)
      assert magic_count(account.account_id) == 1
      assert intent_count() == 1
    end)
  end

  test "the work deadline survives death of the requesting process" do
    P805.with_fixture(fn ->
      account = account(true)
      operation = operation()
      parent = self()
      reference = make_ref()

      {requester, requester_monitor} =
        database_worker(fn ->
          Process.put(RegistrationSeam, {:pause, parent, reference})
          request(account.email, operation)
        end)

      assert_receive {^reference, :before_commit, worker, _backend, _transaction}, 1_000
      worker_monitor = Process.monitor(worker)
      Process.exit(requester, :kill)
      assert_receive {:DOWN, ^requester_monitor, :process, ^requester, :killed}, 1_000
      assert_receive {:DOWN, ^worker_monitor, :process, ^worker, :killed}, 1_000
      send(worker, {reference, :release})
      assert magic_count(account.account_id) == 0
      assert intent_count() == 0

      {result, elapsed} = request(account.email, operation)
      assert result == :ok
      assert_response_window(elapsed)
      assert magic_count(account.account_id) == 1
      assert intent_count() == 1
    end)
  end

  test "worker admission exhaustion remains neutral for every Account class" do
    P805.with_fixture(fn ->
      eligible = account(true)
      ineligible = account(false)

      blockers =
        for _ <- 1..32 do
          {:ok, pid} =
            Task.Supervisor.start_child(NewYou.Identity.MagicLogin.RequestSupervisor, fn ->
              receive do
                :release -> :ok
              end
            end)

          {pid, Process.monitor(pid)}
        end

      try do
        for email <- [eligible.email, ineligible.email, "unknown@example.test"] do
          {result, elapsed} = request(email, operation())
          assert result == :ok
          assert_response_window(elapsed)
        end

        assert magic_count(eligible.account_id) == 0
        assert intent_count() == 0
      after
        for {pid, monitor} <- blockers do
          send(pid, :release)
          finish_worker(pid, monitor)
        end
      end
    end)
  end

  defp account(verified?) do
    input = P805.request()
    {:ok, registration} = Identity.register(input)
    if verified?, do: Identity.verify_email(registration.verification_proof)
    %{email: input.email, account_id: registration.account_id}
  end

  defp operation do
    operation = Ecto.UUID.generate()
    P805.track_operation(operation)
    operation
  end

  defp request(email, operation) do
    started = System.monotonic_time(:millisecond)
    result = Identity.request_magic_login(email, "af", operation)
    {result, System.monotonic_time(:millisecond) - started}
  end

  defp assert_response_window(elapsed) do
    assert elapsed >= 500, "public request bypassed its common response floor"
    assert elapsed < 1_000, "public request exceeded its common response window"
  end

  defp magic_count(account_id) do
    Token
    |> Ash.Query.filter(account_id == ^account_id and not is_nil(magic_request_id))
    |> Ash.count!(authorize?: false)
  end

  defp intent_count do
    MessageIntent |> Ash.Query.filter(role == :magic_login) |> Ash.count!(authorize?: false)
  end

  defp fail(:exception), do: raise("magic request transaction failure")
  defp fail(:exit), do: exit(:magic_request_transaction_failure)

  defp database_worker(callback) do
    spawn_monitor(fn ->
      :ok = Sandbox.checkout(Repo, sandbox: false)

      try do
        callback.()
      after
        Sandbox.checkin(Repo)
      end
    end)
  end

  defp finish_worker(pid, monitor) do
    receive do
      {:DOWN, ^monitor, :process, ^pid, :normal} ->
        :ok

      {:DOWN, ^monitor, :process, ^pid, reason} ->
        flunk("database worker failed: #{inspect(reason)}")
    after
      3_000 ->
        Process.exit(pid, :kill)
        flunk("database worker cleanup deadline")
    end
  end

  defp assert_contention(locker, requester) do
    deadline = System.monotonic_time(:millisecond) + 1_000
    wait_for_contention(locker, requester, deadline)
  end

  defp wait_for_contention(locker, requester, deadline) do
    if P805.scalar("SELECT $1::integer = ANY(pg_blocking_pids($2))", [locker, requester]) do
      :ok
    else
      if System.monotonic_time(:millisecond) < deadline,
        do: wait_for_contention(locker, requester, deadline),
        else: flunk("request did not contend on the independently held Account lock")
    end
  end
end
