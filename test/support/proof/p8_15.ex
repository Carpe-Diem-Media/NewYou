defmodule NewYou.Proof.P815 do
  @moduledoc false

  import ExUnit.Assertions
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}
  alias NewYou.Identity.{Account, RecoveryCase, Token}
  alias NewYou.Proof.{CutPoints, P805, RegistrationSeam, Scenario}
  require Ash.Query

  def duplicate_request_race do
    P805.with_fixture(fn ->
      {request, registration} = account()
      parent = self()
      reference = make_ref()
      first_operation = operation()
      second_operation = operation()
      scenario = Scenario.start()

      try do
        {first, first_monitor} =
          Scenario.spawn(scenario, :first_request, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)
            Process.put(RegistrationSeam, {:pause, parent, reference})

            try do
              result = Identity.request_recovery(request.email, "af", first_operation)
              send(parent, {reference, :first_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        first_backend = await_checkpoint(reference)

        {_second, second_monitor} =
          Scenario.spawn(scenario, :second_request, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            try do
              backend = P805.scalar("SELECT pg_backend_pid()")
              send(parent, {reference, :second_backend, backend})
              result = Identity.request_recovery(request.email, "af", second_operation)
              send(parent, {reference, :second_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        second_backend = receive_backend(reference, :second_backend)
        assert_contention(second_backend, first_backend)
        send(first, {reference, :release})
        assert await_result(reference, :first_result) == :ok
        assert await_result(reference, :second_result) == :ok
        await_normal(first_monitor)
        await_normal(second_monitor)
        assert length(cases(registration.account_id)) == 1
      after
        :ok = Scenario.stop(scenario)
      end
    end)
  end

  def completion_race do
    P805.with_fixture(fn ->
      {request, registration, recovery, bearer} = pending_recovery()
      assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}
      parent = self()
      reference = make_ref()
      first_operation = operation()
      second_operation = operation()
      scenario = Scenario.start()

      try do
        {first, first_monitor} =
          Scenario.spawn(scenario, :first_completion, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)
            Process.put(RegistrationSeam, {:pause, parent, reference})

            try do
              result = Identity.complete_recovery(bearer, "recovered credential", first_operation)
              send(parent, {reference, :first_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        first_backend = await_checkpoint(reference)

        {_second, second_monitor} =
          Scenario.spawn(scenario, :second_completion, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            try do
              backend = P805.scalar("SELECT pg_backend_pid()")
              send(parent, {reference, :second_backend, backend})

              result =
                Identity.complete_recovery(bearer, "competing credential", second_operation)

              send(parent, {reference, :second_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        second_backend = receive_backend(reference, :second_backend)
        assert_contention(second_backend, first_backend)
        send(first, {reference, :release})
        assert await_result(reference, :first_result) == {:ok, :completed}
        assert await_result(reference, :second_result) == {:error, :recovery_unavailable}
        await_normal(first_monitor)
        await_normal(second_monitor)
        assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).state == :completed
        assert account_version(registration.account_id) == 2

        assert Identity.complete_recovery(bearer, "retry", first_operation) ==
                 {:ok, :already_completed}

        assert Identity.complete_recovery(bearer, "replay", second_operation) ==
                 {:error, :recovery_unavailable}

        assert request.email == recovery_account_email(registration.account_id)
      after
        :ok = Scenario.stop(scenario)
      end
    end)
  end

  def stale_login_race do
    P805.with_fixture(fn ->
      {request, _registration, recovery, bearer} = pending_recovery()
      {:ok, session} = Identity.authenticate_password(request.email, request.password)
      assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}
      parent = self()
      reference = make_ref()
      scenario = Scenario.start()

      try do
        {completion, completion_monitor} =
          Scenario.spawn(scenario, :completion, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)
            Process.put(RegistrationSeam, {:pause, parent, reference})

            try do
              result = Identity.complete_recovery(bearer, "new recovery password", operation())
              send(parent, {reference, :completion_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        completion_backend = await_checkpoint(reference)

        {_login, login_monitor} =
          Scenario.spawn(scenario, :old_password_login, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            try do
              backend = P805.scalar("SELECT pg_backend_pid()")
              send(parent, {reference, :login_backend, backend})
              result = Identity.authenticate_password(request.email, request.password)
              send(parent, {reference, :login_result, safe_login(result)})
            after
              Sandbox.checkin(Repo)
            end
          end)

        login_backend = receive_backend(reference, :login_backend)
        assert_contention(login_backend, completion_backend)
        send(completion, {reference, :release})
        assert await_result(reference, :completion_result) == {:ok, :completed}
        assert await_result(reference, :login_result) == :denied
        await_normal(completion_monitor)
        await_normal(login_monitor)
        assert Identity.authorize_session(session) == {:error, :authentication_unavailable}
        assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).state == :completed
      after
        :ok = Scenario.stop(scenario)
      end

      :ok
    end)
  end

  def reset_vs_recovery_race do
    P805.with_fixture(fn ->
      {request, _registration, _recovery, recovery_bearer} = pending_recovery()
      assert Identity.submit_recovery_proof(recovery_bearer, operation()) == {:ok, :accepted}
      reset_bearer = password_reset_delivery(request)
      parent = self()
      reference = make_ref()
      scenario = Scenario.start()

      try do
        {completion, completion_monitor} =
          Scenario.spawn(scenario, :recovery_completion, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)
            Process.put(RegistrationSeam, {:pause, parent, reference})

            try do
              result =
                Identity.complete_recovery(
                  recovery_bearer,
                  "recovery credential wins",
                  operation()
                )

              send(parent, {reference, :completion_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        completion_backend = await_checkpoint(reference)

        {_reset, reset_monitor} =
          Scenario.spawn(scenario, :stale_password_reset, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            try do
              backend = P805.scalar("SELECT pg_backend_pid()")
              send(parent, {reference, :reset_backend, backend})

              result =
                Identity.reset_password(reset_bearer, "stale reset credential", operation())

              send(parent, {reference, :reset_result, safe_reset(result)})
            after
              Sandbox.checkin(Repo)
            end
          end)

        reset_backend = receive_backend(reference, :reset_backend)
        assert_contention(reset_backend, completion_backend)
        send(completion, {reference, :release})
        assert await_result(reference, :completion_result) == {:ok, :completed}
        assert await_result(reference, :reset_result) == :denied
        await_normal(completion_monitor)
        await_normal(reset_monitor)
        assert account_version_by_email(request.email) == 2
      after
        :ok = Scenario.stop(scenario)
      end
    end)
  end

  def interrupted_acceptance do
    P805.with_fixture(fn ->
      {_request, _registration, recovery, bearer} = pending_recovery()
      scenario = Scenario.start()
      :ok = CutPoints.arm(scenario, "transaction.before_commit", :proof_acceptance, :terminate)

      try do
        {worker, monitor} =
          Scenario.spawn(scenario, :proof_acceptance, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            Process.put(
              RegistrationSeam,
              {:observe,
               fn -> CutPoints.hit(scenario, "transaction.before_commit", :proof_acceptance) end}
            )

            try do
              Identity.submit_recovery_proof(bearer, operation())
            after
              Sandbox.checkin(Repo)
            end
          end)

        receive do
          {:DOWN, ^monitor, :process, ^worker, :proof_terminated} -> :ok
        after
          15_000 -> raise "P8-15 proof acceptance termination deadline"
        end

        assert CutPoints.verify_consumed(scenario) == :ok
        assert Ash.get!(Token, recovery.proof_jti, authorize?: false).purpose == "recovery"
        rolled_back = Ash.get!(RecoveryCase, recovery.id, authorize?: false)
        assert rolled_back.state == :proof_pending
        assert rolled_back.satisfied_assurance == 0
        assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}
      after
        :ok = Scenario.stop(scenario)
      end
    end)
  end

  def restart_proof do
    P805.with_fixture(fn ->
      {request, registration, recovery, bearer} = pending_recovery()
      operation_id = operation()
      password = "recovery survives a fresh BEAM"
      secret = Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))

      assert restart_call(%{
               mode: "deliver",
               jti: recovery.proof_jti,
               destination: request.email,
               locale: "af",
               expected_digest: digest(bearer),
               signing_secret: secret
             }) == :delivery_matches

      assert restart_call(%{
               mode: "submit",
               proof: bearer,
               operation_id: operation(),
               signing_secret: secret
             }) == :accepted

      assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).state == :additional_assurance

      assert restart_call(%{
               mode: "complete",
               proof: bearer,
               password: password,
               operation_id: operation_id,
               signing_secret: secret
             }) == :completed

      assert restart_call(%{
               mode: "replay",
               proof: bearer,
               password: "ignored",
               operation_id: operation_id,
               signing_secret: secret
             }) == :already_completed

      assert Ash.get!(RecoveryCase, recovery.id, authorize?: false).state == :completed
      assert account_version(registration.account_id) == 2

      assert P805.scalar("SELECT count(*) FROM recovery_cases WHERE completion_id = $1", [
               Ecto.UUID.dump!(operation_id)
             ]) == 1

      :ok
    end)
  end

  defp pending_recovery do
    {request, registration} = account()
    :ok = Identity.request_recovery(request.email, "af", operation())
    [recovery] = cases(registration.account_id)
    {:ok, bearer} = delivery(recovery, request.email)
    {request, registration, recovery, bearer}
  end

  defp account do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {request, registration}
  end

  defp cases(account_id) do
    RecoveryCase
    |> Ash.Query.filter(account_id == ^account_id)
    |> Ash.read!(authorize?: false)
  end

  defp delivery(recovery, email) do
    {:ok, {:ok, bearer}} =
      Ash.transact([Account, Token], fn ->
        Identity.recovery_delivery(recovery.proof_jti, email, "af")
      end)

    {:ok, bearer}
  end

  defp password_reset_delivery(request) do
    :ok = Identity.request_password_reset(request.email, "af", operation())

    proof =
      Token
      |> Ash.Query.filter(purpose == "password_reset")
      |> Ash.read_one!(authorize?: false)

    {:ok, {:ok, bearer}} =
      Ash.transact([Account, Token], fn ->
        Identity.password_reset_delivery(proof.jti, request.email, "af")
      end)

    bearer
  end

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  defp await_checkpoint(reference) do
    receive do
      {^reference, :before_commit, _worker, backend, _transaction} -> backend
    after
      15_000 -> raise "P8-15 transaction checkpoint deadline"
    end
  end

  defp receive_backend(reference, key) do
    receive do
      {^reference, ^key, backend} -> backend
    after
      15_000 -> raise "P8-15 contender connection deadline"
    end
  end

  defp assert_contention(contender, owner) do
    deadline = System.monotonic_time(:millisecond) + 15_000
    wait_contention(contender, owner, deadline)
  end

  defp wait_contention(contender, owner, deadline) do
    rows =
      Repo.query!(
        "SELECT a.virtualtransaction, b.virtualtransaction FROM pg_locks a JOIN pg_locks b ON b.pid = $1 AND b.locktype = 'virtualxid' WHERE a.pid = $2 AND a.locktype = 'virtualxid' AND $2 = ANY(pg_blocking_pids($1))",
        [contender, owner]
      ).rows

    case rows do
      [[contender_transaction, owner_transaction]] when contender != owner ->
        assert contender_transaction != owner_transaction

      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          wait_contention(contender, owner, deadline)
        else
          raise "P8-15 PostgreSQL lock contention was not observed"
        end
    end
  end

  defp await_result(reference, name) do
    receive do
      {^reference, ^name, result} -> result
    after
      15_000 -> raise "P8-15 worker result deadline"
    end
  end

  defp await_normal(monitor) do
    receive do
      {:DOWN, ^monitor, :process, _worker, :normal} -> :ok
    after
      15_000 -> raise "P8-15 worker cleanup deadline"
    end
  end

  defp account_version(id), do: Ash.get!(Account, id, authorize?: false).credential_version

  defp account_version_by_email(email) do
    Account
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one!(authorize?: false)
    |> Map.fetch!(:credential_version)
  end

  defp recovery_account_email(id), do: Ash.get!(Account, id, authorize?: false).email
  defp safe_login({:ok, _}), do: :accepted
  defp safe_login(_), do: :denied
  defp safe_reset({:ok, :reset}), do: :reset
  defp safe_reset(_), do: :denied
  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :upper)

  defp restart_call(fields) do
    payload = Jason.encode!(fields)
    executable = System.find_executable("mix") || raise "mix unavailable"

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        args: ["run", "test/proof/p8_15_restart.exs"],
        env: [{~c"MIX_ENV", ~c"test"}, {~c"ERL_FLAGS", ~c"+S 2:2"}]
      ])

    true = Port.command(port, payload <> "\n")
    read_restart(port, "", System.monotonic_time(:millisecond) + 30_000)
  end

  defp read_restart(port, output, deadline) do
    receive do
      {^port, {:data, bytes}} when byte_size(output) + byte_size(bytes) < 8_192 ->
        read_restart(port, output <> bytes, deadline)

      {^port, {:exit_status, 0}} ->
        Enum.find_value(
          [:delivery_matches, :accepted, :completed, :already_completed],
          :error,
          fn result ->
            marker = "P815_" <> (Atom.to_string(result) |> String.upcase())
            if String.contains?(output, marker), do: result
          end
        )

      {^port, {:exit_status, _}} ->
        :error
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        Port.close(port)
        :error
    end
  end
end
