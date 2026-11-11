defmodule NewYou.Identity.MagicLoginLifecycleTest do
  use ExUnit.Case, async: false
  require Ash.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Identity
  alias NewYou.Identity.{Account, Session, Token}
  alias NewYou.Proof.P805

  test "a cancelled request loses its fixture lease but a bound retry proves fresh durable issuance" do
    P805.with_fixture(fn ->
      {request, registration} = verified_account()
      prior = request_current_proof(request.email, registration.account_id, operation())
      prior_bearer = delivery!(prior, request.email, "af")
      interrupted_operation = operation()
      checkpoint = make_ref()

      Process.put(NewYou.Proof.RegistrationSeam, {:pause, self(), checkpoint})

      try do
        :ok = Identity.request_magic_login(request.email, "af", interrupted_operation)
      after
        Process.delete(NewYou.Proof.RegistrationSeam)
      end

      assert_received {^checkpoint, :before_commit, worker, _backend, _transaction}
      refute Process.alive?(worker)
      proof = request_current_proof(request.email, registration.account_id, interrupted_operation)
      assert proof.magic_request_id == interrupted_operation
      assert proof.jti != prior.jti
      assert delivery_rejected?(prior.jti, request.email, "af")
      assert consume(prior_bearer) == :denied
      bearer = delivery!(proof, request.email, "af")
      assert consume(bearer) == :accepted
      assert consume(bearer) == :denied
    end)
  end

  test "expiry, revocation, supersession and replay fail closed" do
    P805.with_fixture(fn ->
      {request, registration} = verified_account()

      for disposition <- [:expired, :revoked, :superseded] do
        operation = operation()
        proof = request_current_proof(request.email, registration.account_id, operation)
        bearer = delivery!(proof, request.email, "af")

        case disposition do
          :expired ->
            NewYou.Repo.query!(
              "UPDATE tokens SET expires_at = now() - interval '1 second' WHERE jti = $1",
              [proof.jti]
            )

          :revoked ->
            NewYou.Repo.query!("UPDATE tokens SET purpose = 'revocation' WHERE jti = $1", [
              proof.jti
            ])

          :superseded ->
            request_current_proof(request.email, registration.account_id, operation())
        end

        rejected = delivery_rejected?(proof.jti, request.email, "af")
        outcome = consume(bearer)
        assert rejected, "invalidated delivery proof was accepted"
        assert outcome == :denied, "invalidated magic proof created a Session"
      end

      operation = operation()
      proof = request_current_proof(request.email, registration.account_id, operation)
      bearer = delivery!(proof, request.email, "af")
      first = consume(bearer)
      replay = consume(bearer)
      assert first == :accepted, "current magic proof did not create a Session"
      assert replay == :denied, "consumed magic proof replay was accepted"
    end)
  end

  test "delivery binds the current locale and authentication rejects wrong purpose and altered claims" do
    P805.with_fixture(fn ->
      {request, registration} = verified_account()
      :ok = Identity.request_magic_login(request.email, "af", operation())
      proof = current_proof(registration.account_id)
      bearer = delivery!(proof, request.email, "af")

      wrong_locale = delivery_rejected?(proof.jti, request.email, "en")
      tampered_bearer = alter_locale_claim(bearer)
      tampered_outcome = consume(tampered_bearer)
      assert wrong_locale, "delivery accepted a different locale"
      assert tampered_outcome == :denied, "altered signed claims were accepted"

      NewYou.Repo.query!("UPDATE tokens SET purpose = 'account_recovery' WHERE jti = $1", [
        proof.jti
      ])

      wrong_purpose = consume(bearer)
      assert wrong_purpose == :denied, "stored wrong-purpose proof was accepted"
    end)
  end

  test "repeated delivery rematerialises one unchanged Token without extending expiry" do
    P805.with_fixture(fn ->
      {request, registration} = verified_account()
      operation = operation()
      :ok = Identity.request_magic_login(request.email, "af", operation)
      proof = current_proof(registration.account_id)
      before = magic_proof_snapshot(proof.jti)

      first = delivery!(proof, request.email, "af")
      second = delivery!(proof, request.email, "af")
      after_snapshot = magic_proof_snapshot(proof.jti)
      same_bearer = first == second
      unchanged_token = before == after_snapshot
      one_token = token_count_for_operation(operation) == 1

      assert same_bearer, "repeated delivery changed the rematerialised proof"
      assert unchanged_token, "delivery changed the durable Token or its expiry"
      assert one_token, "delivery created another Token for the same request"
    end)
  end

  test "current verification, credential, email, closure and hold state gates issuance and use" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      :ok = Identity.request_magic_login(request.email, "af", operation())
      no_proof = no_magic_proof?(registration.account_id)
      assert no_proof, "unverified Account received a magic proof"

      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      :ok = Identity.request_magic_login(request.email, "af", operation())
      proof = current_proof(registration.account_id)
      bearer = delivery!(proof, request.email, "af")
      account_id = Ecto.UUID.dump!(registration.account_id)

      for {column, value, restore} <- [
            {"credential_status", "revoked", "active"},
            {"\"email_verified?\"", false, true},
            {"security_posture", "held", "normal"},
            {"account_status", "closed_recoverable", "open"},
            {"account_status", "closed_terminal", "open"},
            {"email", "changed-#{Ecto.UUID.generate()}@example.test", request.email}
          ] do
        NewYou.Repo.query!("UPDATE accounts SET #{column} = $1 WHERE id = $2", [value, account_id])

        destination = value_for(column, value, request.email)
        rejected_delivery = delivery_rejected?(proof.jti, destination, "af")
        outcome = consume(bearer)
        assert rejected_delivery, "current Account state did not reject magic delivery"
        assert outcome == :denied, "current Account state did not reject authentication"

        NewYou.Repo.query!("UPDATE accounts SET #{column} = $1 WHERE id = $2", [
          restore,
          account_id
        ])
      end
    end)
  end

  test "a failed Session insert restores the proof for a later attempt" do
    P805.with_fixture(fn ->
      {request, registration} = verified_account()
      :ok = Identity.request_magic_login(request.email, "af", operation())
      proof = current_proof(registration.account_id)
      bearer = delivery!(proof, request.email, "af")
      sessions_before = session_count(registration.account_id)

      NewYou.Repo.query!("""
      CREATE FUNCTION p809_reject_magic_session() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN RAISE EXCEPTION 'p809 magic session failure' USING ERRCODE = '23514'; END; $$
      """)

      NewYou.Repo.query!(
        "CREATE TRIGGER p809_reject_magic BEFORE INSERT ON sessions FOR EACH ROW EXECUTE FUNCTION p809_reject_magic_session()"
      )

      try do
        failed_attempt = consume(bearer)
        proof_unchanged = current_purpose(proof.jti) == "magic_login"
        sessions_unchanged = session_count(registration.account_id) == sessions_before
        assert failed_attempt == :denied, "Session write failure was accepted"
        assert proof_unchanged, "Session write failure consumed the proof"
        assert sessions_unchanged, "Session write failure committed a Session"
      after
        NewYou.Repo.query!("DROP TRIGGER p809_reject_magic ON sessions")
        NewYou.Repo.query!("DROP FUNCTION p809_reject_magic_session()")
      end

      retry_result = consume(bearer)
      retry_consumed = current_purpose(proof.jti) == "magic_login_consumed"
      retry_created_session = session_count(registration.account_id) == sessions_before + 1
      assert retry_result == :accepted, "retry did not consume the restored proof"
      assert retry_consumed, "retry did not mark the proof consumed"
      assert retry_created_session, "retry did not create exactly one Session"
    end)
  end

  test "the existing partial Identity proof runs consume contention and BEAM restart cases" do
    for id <- ~w(
          p809.magic_consume_race
          p809.magic_issue_consume_race
          p809.magic_restart
        ) do
      registration = Enum.find(NewYou.Proof.P809MagicCatalog.registrations(), &(&1.case_id == id))

      {result, cleanup} =
        NewYou.Proof.SelfTest.execute_registered_case(
          registration.manifest,
          registration.callback
        )

      failed =
        result["observations"]
        |> Enum.filter(&(&1["value"] == false))
        |> Enum.map_join(",", & &1["code"])

      reasons = Enum.join(result["reason_codes"], ",")
      assert result["verdict"] == "PASS", "#{id} failed: #{failed} #{reasons}"
      assert Enum.all?(cleanup, fn {_key, value} -> value == true end), "#{id} did not clean up"
    end
  end

  defp verified_account do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {request, registration}
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

  defp no_magic_proof?(account_id) do
    Token
    |> Ash.Query.filter(account_id == ^account_id and not is_nil(magic_request_id))
    |> Ash.read!(authorize?: false)
    |> Enum.empty?()
  end

  defp current_purpose(jti) do
    NewYou.Repo.query!("SELECT purpose FROM tokens WHERE jti = $1", [jti]).rows
    |> case do
      [[purpose]] -> purpose
      _ -> nil
    end
  end

  defp magic_proof_snapshot(jti) do
    NewYou.Repo.query!(
      "SELECT magic_request_id, purpose, expires_at, magic_claims, magic_account_binding, magic_locale, created_at, updated_at FROM tokens WHERE jti = $1",
      [jti]
    ).rows
  end

  defp token_count_for_operation(operation) do
    P805.scalar("SELECT count(*) FROM tokens WHERE magic_request_id = $1", [
      Ecto.UUID.dump!(operation)
    ])
  end

  defp session_count(account_id) do
    NewYou.Repo.query!("SELECT count(*) FROM sessions WHERE account_id = $1", [
      Ecto.UUID.dump!(account_id)
    ]).rows
    |> hd()
    |> hd()
  end

  defp delivery!(proof, destination, locale) do
    case Ash.transact([Account, Token], fn ->
           Identity.magic_login_delivery(proof.jti, destination, locale)
         end) do
      {:ok, {:ok, bearer}} when is_binary(bearer) -> bearer
      {:ok, bearer} when is_binary(bearer) -> bearer
      _ -> raise "expected current magic-login delivery proof"
    end
  end

  defp request_current_proof(email, account_id, operation_id) do
    proof =
      Enum.reduce_while(1..3, nil, fn _, _ ->
        # Cancellation may disconnect the borrowed lease. A neutral response is
        # not issuance proof: reacquire, then observe this exact durable operation.
        Sandbox.unboxed_run(NewYou.Repo, fn ->
          :ok = Identity.request_magic_login(email, "af", operation_id)
        end)

        :ok = Sandbox.checkout(NewYou.Repo, sandbox: false)

        case current_proof(account_id) do
          %Token{magic_request_id: ^operation_id} = current -> {:halt, current}
          _ -> {:cont, nil}
        end
      end)

    assert match?(%Token{magic_request_id: ^operation_id}, proof),
           "request fixture did not commit the expected current magic proof"

    proof
  end

  defp delivery_rejected?(jti, destination, locale) do
    case Ash.transact([Account, Token], fn ->
           Identity.magic_login_delivery(jti, destination, locale)
         end) do
      {:ok, {:ok, bearer}} when is_binary(bearer) -> false
      {:ok, bearer} when is_binary(bearer) -> false
      _ -> true
    end
  end

  defp consume(bearer) do
    case Identity.authenticate_magic_link(bearer) do
      {:ok, %{session_id: session_id, token: token}}
      when is_binary(session_id) and is_binary(token) ->
        case Ash.get(Session, session_id, authorize?: false) do
          {:ok, %Session{}} -> :accepted
          _ -> :denied
        end

      _ ->
        :denied
    end
  end

  defp alter_locale_claim(bearer) do
    [header, payload, signature] = String.split(bearer, ".")
    claims = payload |> Base.url_decode64!(padding: false) |> Jason.decode!()

    tampered =
      claims |> Map.put("locale", "en") |> Jason.encode!() |> Base.url_encode64(padding: false)

    Enum.join([header, tampered, signature], ".")
  end

  defp value_for("email", value, _original), do: value
  defp value_for(_column, _value, original), do: original
end
