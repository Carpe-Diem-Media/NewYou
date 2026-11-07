defmodule NewYou.Proof.P809MagicLogin do
  @moduledoc false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Identity, Repo}
  alias NewYou.Identity.{Account, Token}
  alias NewYou.Proof.{P805, RegistrationSeam, Scenario}
  require Ash.Query

  def run(id) do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      :ok = Identity.request_magic_login(request.email, "af", operation())
      proof = current_proof(registration.account_id)
      bearer = delivery!(proof, request.email)

      case id do
        "p809.magic_consume_race" ->
          consume_race(id, registration, proof, bearer)

        "p809.magic_issue_consume_race" ->
          issue_consume_race(id, request, registration, proof, bearer)

        "p809.magic_restart" ->
          restart(id, request, registration, proof, bearer)

        _ ->
          raise ArgumentError, "unknown P8-09 magic-login proof case"
      end

      :ok
    end)
  end

  defp consume_race(id, registration, proof, bearer) do
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()

    try do
      {first, first_monitor} =
        Scenario.spawn(scenario, :magic_first, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)
          Process.put(RegistrationSeam, {:pause, parent, reference})

          try do
            result = Identity.authenticate_magic_link(bearer)
            send(parent, {reference, :first_result, safe_consume_result(result)})
          after
            Sandbox.checkin(Repo)
          end
        end)

      {first_backend, _first_transaction} =
        receive do
          {^reference, :before_commit, ^first, backend, transaction} -> {backend, transaction}
        after
          15_000 -> raise "magic-login first consume checkpoint deadline"
        end

      {_second, second_monitor} =
        Scenario.spawn(scenario, :magic_second, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          try do
            backend = P805.scalar("SELECT pg_backend_pid()")
            send(parent, {reference, :second_backend, backend})
            result = Identity.authenticate_magic_link(bearer)
            send(parent, {reference, :second_result, safe_consume_result(result)})
          after
            Sandbox.checkin(Repo)
          end
        end)

      second_backend =
        receive do
          {^reference, :second_backend, backend} -> backend
        after
          15_000 -> raise "magic-login second consume connection deadline"
        end

      {second_transaction, first_transaction} =
        contention(second_backend, first_backend, System.monotonic_time(:millisecond) + 15_000)

      P805.check(id, "independent_connections", first_backend != second_backend)

      P805.check(
        id,
        "real_contention",
        is_binary(first_transaction) and first_transaction != second_transaction
      )

      send(first, {reference, :release})

      first_result = await_result(reference, :first_result)
      second_result = await_result(reference, :second_result)
      await_normal(first_monitor)
      await_normal(second_monitor)

      P805.check(id, "one_winner", first_result == :accepted and second_result == :denied)
      P805.check(id, "one_session", session_count(registration.account_id) == 1)
      P805.check(id, "proof_consumed", current_purpose(proof.jti) == "magic_login_consumed")

      P805.check(
        id,
        "replay_denied",
        safe_consume_result(Identity.authenticate_magic_link(bearer)) == :denied
      )
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp restart(id, request, registration, proof, bearer) do
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
      "consume_survives_restart",
      restart_call(%{
        mode: "consume",
        proof: bearer
      }) == :consumed
    )

    P805.check(
      id,
      "terminal_delivery_denied",
      restart_call(%{
        mode: "deliver",
        jti: proof.jti,
        destination: request.email,
        locale: "af"
      }) == :delivery_denied
    )

    P805.check(
      id,
      "terminal_replay_denied",
      restart_call(%{
        mode: "consume",
        proof: bearer
      }) == :denied
    )

    P805.check(id, "one_session", session_count(registration.account_id) == 1)
  end

  defp issue_consume_race(id, request, registration, proof, bearer) do
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()
    replacement_operation = operation()

    try do
      {_issuer, issuer_monitor} =
        Scenario.spawn(scenario, :magic_issuer, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)
          Process.put(RegistrationSeam, {:pause, parent, reference})

          try do
            result =
              Identity.request_magic_login(request.email, "af", replacement_operation)

            send(parent, {reference, :issue_result, result == :ok})
          after
            Sandbox.checkin(Repo)
          end
        end)

      {issuer_worker, issuer_backend, _issuer_transaction} =
        receive do
          {^reference, :before_commit, worker, backend, transaction} ->
            {worker, backend, transaction}
        after
          15_000 -> raise "magic-login replacement issue checkpoint deadline"
        end

      {_consumer, consumer_monitor} =
        Scenario.spawn(scenario, :magic_consumer, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          try do
            backend = P805.scalar("SELECT pg_backend_pid()")
            send(parent, {reference, :consumer_backend, backend})
            result = Identity.authenticate_magic_link(bearer)
            send(parent, {reference, :consume_result, safe_consume_result(result)})
          after
            Sandbox.checkin(Repo)
          end
        end)

      consumer_backend =
        receive do
          {^reference, :consumer_backend, backend} -> backend
        after
          15_000 -> raise "magic-login consumer connection deadline"
        end

      {consumer_transaction, issuer_transaction} =
        contention(consumer_backend, issuer_backend, System.monotonic_time(:millisecond) + 15_000)

      P805.check(id, "independent_connections", issuer_backend != consumer_backend)

      P805.check(
        id,
        "real_contention",
        is_binary(issuer_transaction) and issuer_transaction != consumer_transaction
      )

      send(issuer_worker, {reference, :release})

      issue_committed = await_result(reference, :issue_result)
      consume_result = await_result(reference, :consume_result)
      await_normal(issuer_monitor)
      await_normal(consumer_monitor)

      P805.check(id, "issue_commits", issue_committed)
      P805.check(id, "consumer_denied", consume_result == :denied)

      P805.check(
        id,
        "old_proof_superseded",
        current_purpose(proof.jti) == "magic_login_superseded"
      )

      P805.check(id, "one_current_proof", current_magic_count(registration.account_id) == 1)
      P805.check(id, "no_session", session_count(registration.account_id) == 0)
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  defp current_proof(account_id) do
    Token
    |> Ash.Query.filter(account_id == ^account_id and purpose == "magic_login")
    |> Ash.read_one!(authorize?: false)
  end

  defp delivery!(proof, destination) do
    case Ash.transact([Account, Token], fn ->
           Identity.magic_login_delivery(proof.jti, destination, "af")
         end) do
      {:ok, {:ok, bearer}} when is_binary(bearer) -> bearer
      _ -> raise "expected current magic-login delivery proof"
    end
  end

  defp safe_consume_result({:ok, %{session_id: session_id, token: token}})
       when is_binary(session_id) and is_binary(token),
       do: :accepted

  defp safe_consume_result(_), do: :denied

  defp session_count(account_id) do
    Repo.query!("SELECT count(*) FROM sessions WHERE account_id = $1", [
      Ecto.UUID.dump!(account_id)
    ]).rows
    |> hd()
    |> hd()
  end

  defp current_magic_count(account_id) do
    Token
    |> Ash.Query.filter(account_id == ^account_id and purpose == "magic_login")
    |> Ash.read!(authorize?: false)
    |> length()
  end

  defp current_purpose(jti) do
    case Repo.query!("SELECT purpose FROM tokens WHERE jti = $1", [jti]).rows do
      [[purpose]] -> purpose
      _ -> nil
    end
  end

  defp contention(second, first, deadline) do
    case Repo.query!(
           "SELECT a.virtualtransaction, b.virtualtransaction FROM pg_locks a JOIN pg_locks b ON b.pid = $1 AND b.locktype = 'virtualxid' WHERE a.pid = $2 AND a.locktype = 'virtualxid' AND $2 = ANY(pg_blocking_pids($1))",
           [second, first]
         ).rows do
      [[second_transaction, first_transaction]] ->
        {second_transaction, first_transaction}

      _ ->
        if System.monotonic_time(:millisecond) < deadline,
          do: contention(second, first, deadline),
          else: raise("magic-login consume contention not observed")
    end
  end

  defp await_result(reference, name) do
    receive do
      {^reference, ^name, result} -> result
    after
      15_000 -> raise "magic-login consume result deadline"
    end
  end

  defp await_normal(monitor) do
    receive do
      {:DOWN, ^monitor, :process, _, :normal} -> :ok
    after
      15_000 -> raise "magic-login worker cleanup deadline"
    end
  end

  defp restart_call(fields) do
    payload =
      fields
      |> Map.put(
        :signing_secret,
        Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))
      )
      |> Jason.encode!()

    executable = System.find_executable("mix") || raise "mix unavailable"

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        args: ["run", "test/proof/p8_09_magic_restart.exs"],
        env: [{~c"MIX_ENV", ~c"test"}, {~c"ERL_FLAGS", ~c"+S 2:2"}]
      ])

    true = Port.command(port, payload <> "\n")
    restart_output(port, "", System.monotonic_time(:millisecond) + 30_000)
  end

  defp restart_output(port, output, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {^port, {:data, bytes}} when byte_size(output) + byte_size(bytes) < 8_192 ->
        restart_output(port, output <> bytes, deadline)

      {^port, {:exit_status, 0}} ->
        parse_restart_output(output)

      {^port, {:exit_status, _status}} ->
        :error
    after
      remaining ->
        Port.close(port)
        :error
    end
  end

  defp parse_restart_output(output) do
    cond do
      String.contains?(output, "P809_MAGIC_DELIVERY_MATCH") ->
        :delivery_matches

      String.contains?(output, "P809_MAGIC_DELIVERY_MISMATCH") ->
        :delivery_mismatch

      String.contains?(output, "P809_MAGIC_DELIVERY_DENIED") ->
        :delivery_denied

      String.contains?(output, "P809_MAGIC_CONSUMED") ->
        :consumed

      String.contains?(output, "P809_MAGIC_DENIED") ->
        :denied

      true ->
        :error
    end
  end

  defp digest(bearer), do: :crypto.hash(:sha256, bearer) |> Base.encode16(case: :upper)
end
