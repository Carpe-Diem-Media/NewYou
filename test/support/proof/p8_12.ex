defmodule NewYou.Proof.P812 do
  @moduledoc false
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}
  alias NewYou.Identity.{Account, Session, Token}
  alias NewYou.Proof.{CutPoints, P805, RegistrationSeam, Scenario}
  require Ash.Query

  def run(id) do
    P805.with_fixture(fn ->
      {request, registration} = account()
      {proof, bearer} = issue(request, registration)

      case id do
        "p812.reset_race" -> reset_race(id, registration, bearer)
        "p812.stale_login_race" -> stale_login_race(id, registration, request, bearer)
        "p812.interrupted_reset" -> interrupted_reset(id, registration, request, proof, bearer)
        "p812.restart" -> restart(id, request, registration, proof, bearer)
        _ -> raise ArgumentError, "unknown P8-12 proof case"
      end

      :ok
    end)
  end

  defp reset_race(id, registration, bearer) do
    parent = self()
    reference = make_ref()
    first_operation = operation()
    second_operation = operation()
    scenario = Scenario.start()

    try do
      {first, first_monitor} =
        Scenario.spawn(scenario, :reset_first, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)
          Process.put(RegistrationSeam, {:pause, parent, reference})

          try do
            result = Identity.reset_password(bearer, "replacement one", first_operation)
            send(parent, {reference, :first_result, result})
          after
            Sandbox.checkin(Repo)
          end
        end)

      {first_backend, _first_transaction} = await_checkpoint(reference)

      {_second, second_monitor} =
        Scenario.spawn(scenario, :reset_second, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          try do
            backend = P805.scalar("SELECT pg_backend_pid()")
            send(parent, {reference, :second_backend, backend})
            result = Identity.reset_password(bearer, "replacement two", second_operation)
            send(parent, {reference, :second_result, result})
          after
            Sandbox.checkin(Repo)
          end
        end)

      second_backend = receive_backend(reference, :second_backend)
      {contender_transaction, owner_transaction} = contention(second_backend, first_backend)
      P805.check(id, "independent_connections", first_backend != second_backend)

      P805.check(
        id,
        "real_contention",
        is_binary(contender_transaction) and is_binary(owner_transaction) and
          contender_transaction != owner_transaction
      )

      send(first, {reference, :release})
      first_result = await_result(reference, :first_result)
      second_result = await_result(reference, :second_result)
      await_normal(first_monitor)
      await_normal(second_monitor)
      results = [first_result, second_result]

      P805.check(
        id,
        "one_winner",
        Enum.count(results, &(&1 == {:ok, :reset})) == 1 and
          Enum.count(results, &(&1 == {:error, :reset_unavailable})) == 1
      )

      P805.check(
        id,
        "one_reset_consumption",
        current_purpose(proof_jti(bearer)) == "password_reset_consumed"
      )

      P805.check(
        id,
        "credential_version_once",
        account_version(registration.account_id) == {2, 2}
      )

      P805.check(
        id,
        "replay_denied",
        Identity.reset_password(bearer, "replay", operation()) == {:error, :reset_unavailable}
      )

      P805.check(id, "no_session", active_sessions(registration.account_id) == 0)
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp stale_login_race(id, registration, request, bearer) do
    parent = self()
    reference = make_ref()
    reset_operation = operation()
    scenario = Scenario.start()

    try do
      {reset_worker, reset_monitor} =
        Scenario.spawn(scenario, :reset, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)
          Process.put(RegistrationSeam, {:pause, parent, reference})

          try do
            result = Identity.reset_password(bearer, "new password", reset_operation)
            send(parent, {reference, :reset_result, result})
          after
            Sandbox.checkin(Repo)
          end
        end)

      {reset_backend, _reset_transaction} = await_checkpoint(reference)

      {_login_worker, login_monitor} =
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
      {contender_transaction, owner_transaction} = contention(login_backend, reset_backend)
      P805.check(id, "independent_connections", login_backend != reset_backend)

      P805.check(
        id,
        "real_contention",
        is_binary(contender_transaction) and is_binary(owner_transaction) and
          contender_transaction != owner_transaction
      )

      send(reset_worker, {reference, :release})
      reset_result = await_result(reference, :reset_result)
      login_result = await_result(reference, :login_result)
      await_normal(reset_monitor)
      await_normal(login_monitor)
      P805.check(id, "reset_committed", reset_result == {:ok, :reset})
      P805.check(id, "login_denied", login_result == :denied)
      P805.check(id, "no_session", active_sessions(registration.account_id) == 0)
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp interrupted_reset(id, registration, request, proof, bearer) do
    {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
    before = Ash.get!(Account, registration.account_id, authorize?: false)
    scenario = Scenario.start()
    reset_operation = operation()
    :ok = CutPoints.arm(scenario, "transaction.before_commit", :reset, :terminate)

    try do
      {worker, monitor} =
        Scenario.spawn(scenario, :reset, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          Process.put(
            RegistrationSeam,
            {:observe, fn -> CutPoints.hit(scenario, "transaction.before_commit", :reset) end}
          )

          try do
            Identity.reset_password(bearer, "replacement", reset_operation)
          after
            Sandbox.checkin(Repo)
          end
        end)

      receive do
        {:DOWN, ^monitor, :process, ^worker, :proof_terminated} -> :ok
      after
        15_000 -> raise "P8-12 interrupted reset termination deadline"
      end

      P805.check(id, "cut_consumed", CutPoints.verify_consumed(scenario) == :ok)
      P805.check(id, "atomic_rollback", Ash.get!(Account, before.id, authorize?: false) == before)

      P805.check(
        id,
        "proof_current",
        Ash.get!(Token, proof.jti, authorize?: false).purpose == "password_reset"
      )

      P805.check(id, "session_valid", match?({:ok, _}, Identity.authorize_session(credentials)))

      P805.check(
        id,
        "retry_commits",
        Identity.reset_password(bearer, "replacement", reset_operation) == {:ok, :reset}
      )

      P805.check(id, "no_session", active_sessions(registration.account_id) == 0)
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp restart(id, request, registration, proof, bearer) do
    {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
    operation_id = operation()
    password = "restart replacement password"

    P805.check(
      id,
      "delivery_survives_restart",
      restart_call(%{
        mode: "deliver",
        jti: proof.jti,
        destination: request.email,
        locale: "af",
        expected_digest: digest(bearer)
      }) == :delivery_matches
    )

    P805.check(
      id,
      "reset_survives_restart",
      restart_call(%{
        mode: "consume",
        proof: bearer,
        password: password,
        operation_id: operation_id
      }) == :reset
    )

    P805.check(
      id,
      "replay_survives_restart",
      restart_call(%{
        mode: "replay",
        proof: bearer,
        password: "ignored",
        operation_id: operation_id
      }) == :already_reset
    )

    obligation_count =
      P805.scalar("SELECT count(*) FROM evidence_obligations WHERE source_operation_id = $1", [
        Ecto.UUID.dump!(operation_id)
      ])

    P805.check(id, "audit_once", obligation_count == 1)

    P805.check(
      id,
      "prior_session_revoked",
      match?({:error, _}, Identity.authorize_session(credentials))
    )

    P805.check(id, "no_session", active_sessions(registration.account_id) == 0)
  end

  defp account do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {request, registration}
  end

  defp issue(request, registration) do
    :ok = Identity.request_password_reset(request.email, "af", operation())

    proof =
      Token
      |> Ash.Query.filter(account_id == ^registration.account_id and purpose == "password_reset")
      |> Ash.read_one!(authorize?: false)

    {:ok, bearer} =
      Ash.transact([Account, Token], fn ->
        Identity.password_reset_delivery(proof.jti, request.email, "af")
      end)
      |> case do
        {:ok, result} -> result
        _ -> {:error, :delivery}
      end

    {proof, bearer}
  end

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  defp proof_jti(bearer) do
    {:ok, %{"jti" => jti}, Account} = AshAuthentication.Jwt.verify(bearer, Account)
    jti
  end

  defp account_version(id) do
    account = Ash.get!(Account, id, authorize?: false)
    {account.credential_version, account.security_version}
  end

  defp active_sessions(id),
    do:
      Session
      |> Ash.Query.filter(account_id == ^id and state == :active)
      |> Ash.read!(authorize?: false)
      |> length()

  defp current_purpose(jti) do
    case Repo.query!("SELECT purpose FROM tokens WHERE jti = $1", [jti]).rows do
      [[purpose]] -> purpose
      _ -> nil
    end
  end

  defp safe_login({:ok, _}), do: :accepted
  defp safe_login(_), do: :denied
  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :upper)

  defp await_checkpoint(reference) do
    receive do
      {^reference, :before_commit, _worker, backend, transaction} -> {backend, transaction}
    after
      15_000 -> raise "P8-12 transaction checkpoint deadline"
    end
  end

  defp receive_backend(reference, name) do
    receive do
      {^reference, ^name, backend} -> backend
    after
      15_000 -> raise "P8-12 contender connection deadline"
    end
  end

  defp contention(contender, owner) do
    deadline = System.monotonic_time(:millisecond) + 15_000
    find_contention(contender, owner, deadline)
  end

  defp find_contention(contender, owner, deadline) do
    rows =
      Repo.query!(
        "SELECT a.virtualtransaction, b.virtualtransaction FROM pg_locks a JOIN pg_locks b ON b.pid = $1 AND b.locktype = 'virtualxid' WHERE a.pid = $2 AND a.locktype = 'virtualxid' AND $2 = ANY(pg_blocking_pids($1))",
        [contender, owner]
      ).rows

    case rows do
      [[contender_transaction, owner_transaction]] ->
        {contender_transaction, owner_transaction}

      _ ->
        if System.monotonic_time(:millisecond) < deadline,
          do: find_contention(contender, owner, deadline),
          else: raise("P8-12 PostgreSQL contention not observed")
    end
  end

  defp await_result(reference, name) do
    receive do
      {^reference, ^name, result} -> result
    after
      15_000 -> raise "P8-12 worker result deadline"
    end
  end

  defp await_normal(monitor) do
    receive do
      {:DOWN, ^monitor, :process, _worker, :normal} -> :ok
    after
      15_000 -> raise "P8-12 worker cleanup deadline"
    end
  end

  defp restart_call(fields) do
    fields =
      Map.put(
        fields,
        :signing_secret,
        Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))
      )

    payload = Jason.encode!(fields)
    executable = System.find_executable("mix") || raise "mix unavailable"

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        args: ["run", "test/proof/p8_12_restart.exs"],
        env: [{~c"MIX_ENV", ~c"test"}, {~c"ERL_FLAGS", ~c"+S 2:2"}]
      ])

    true = Port.command(port, payload <> "\n")
    restart_output(port, "", System.monotonic_time(:millisecond) + 30_000)
  end

  defp restart_output(port, output, deadline) do
    receive do
      {^port, {:data, bytes}} when byte_size(output) + byte_size(bytes) < 8_192 ->
        restart_output(port, output <> bytes, deadline)

      {^port, {:exit_status, 0}} ->
        parse_restart(output)

      {^port, {:exit_status, _}} ->
        :error
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        Port.close(port)
        :error
    end
  end

  defp parse_restart(output) do
    Enum.find_value([:delivery_matches, :reset, :already_reset], :error, fn result ->
      marker = "P812_" <> (Atom.to_string(result) |> String.upcase())
      if String.contains?(output, marker), do: result
    end)
  end
end
