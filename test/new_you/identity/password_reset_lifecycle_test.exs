defmodule NewYou.Identity.PasswordResetLifecycleTest do
  use ExUnit.Case, async: false
  require Ash.Query
  import ExUnit.CaptureLog
  alias NewYou.{Identity, Communications, Audit, Repo}
  alias NewYou.Identity.{Account, Token, Session, DeviceAssurance}
  alias NewYou.Audit.EvidenceObligation
  alias NewYou.Proof.P805

  test "expiry revocation supersession replay and wrong-purpose proofs fail closed" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      initial = Ash.get!(Account, registration.account_id, authorize?: false)

      for disposition <- [:expired, :revoked, :superseded] do
        {proof, bearer} = issue(request, registration)

        case disposition do
          :expired ->
            Repo.query!(
              "UPDATE tokens SET expires_at = now() - interval '1 second' WHERE jti = $1",
              [proof.jti]
            )

          :revoked ->
            Repo.query!("UPDATE tokens SET purpose = 'revocation' WHERE jti = $1", [proof.jti])

          :superseded ->
            Identity.request_password_reset(request.email, "af", operation())
        end

        assert reset(bearer) == {:error, :reset_unavailable}
        assert delivery(proof, request.email) == {:error, :source_invalid}
        assert Ash.get!(Account, initial.id, authorize?: false) == initial
      end

      {_, bearer} = issue(request, registration)

      for password <- [nil, "", String.duplicate("a", 1025)] do
        assert Identity.reset_password(bearer, password, operation()) ==
                 {:error, :reset_unavailable}
      end

      assert reset(bearer <> "x") == {:error, :reset_unavailable}
      assert reset(registration.verification_proof) == {:error, :reset_unavailable}
      :ok = Identity.request_magic_login(request.email, "af", operation())

      magic =
        Token
        |> Ash.Query.filter(account_id == ^initial.id and purpose == "magic_login")
        |> Ash.read_one!(authorize?: false)

      {:ok, {:ok, magic_bearer}} =
        Ash.transact([Account, Token], fn ->
          Identity.magic_login_delivery(magic.jti, request.email, "af")
        end)

      assert reset(magic_bearer) == {:error, :reset_unavailable}
      assert Identity.authenticate_magic_link(bearer) == {:error, :authentication_unavailable}
      assert Identity.verify_email(bearer) == {:error, :verification_unavailable}
      assert {:ok, :reset} = reset(bearer)
      assert reset(bearer) == {:error, :reset_unavailable}
    end)
  end

  test "request retries retain one proof and binding, and invalid current Account state prevents use" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      request_id = operation()
      :ok = Identity.request_password_reset(request.email, "af", request_id)
      proof = current_proof(registration.account_id)
      {:ok, bearer} = delivery(proof, request.email)
      :ok = Identity.request_password_reset(request.email, "en", request_id)
      assert current_proof(registration.account_id) == proof
      assert delivery(proof, request.email, "en") == {:error, :source_invalid}

      for {column, value, original} <- [
            {"account_status", "closed_recoverable", "open"},
            {"security_posture", "held", "normal"},
            {"credential_status", "revoked", "active"},
            {"security_version", 2, 1},
            {"credential_version", 2, 1},
            {"email", "changed@example.test", request.email}
          ] do
        Repo.query!("UPDATE accounts SET #{column} = $1 WHERE id = $2", [
          value,
          Ecto.UUID.dump!(registration.account_id)
        ])

        assert reset(bearer) == {:error, :reset_unavailable}
        assert delivery(proof, request.email) == {:error, :source_invalid}

        Repo.query!("UPDATE accounts SET #{column} = $1 WHERE id = $2", [
          original,
          Ecto.UUID.dump!(registration.account_id)
        ])
      end
    end)
  end

  test "reset clears elevated assurance, terminates trusted devices, and preserves independent proofs and MFA" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
      session = Ash.get!(Session, credentials.session_id, authorize?: false)

      {:ok, _} =
        Ash.update(
          session,
          %{
            step_up_purpose: :place_security_hold,
            step_up_at: DateTime.utc_now(),
            step_up_expires_at: DateTime.add(DateTime.utc_now(), 300),
            step_up_mfa_version: 1,
            step_up_security_version: 1
          },
          action: :set_step_up,
          authorize?: false
        )

      # Existing trusted-device state is synthetic. This slice exposes no grant interface.
      id = Ecto.UUID.generate()

      Repo.query!(
        "INSERT INTO device_assurances (id,account_id,fingerprint,state,security_version,expires_at) VALUES ($1,$2,$3,'trusted',1,now()+interval '1 day')",
        [
          Ecto.UUID.dump!(id),
          Ecto.UUID.dump!(registration.account_id),
          :crypto.strong_rand_bytes(32)
        ]
      )

      user = Ash.get!(Account, registration.account_id, authorize?: false)

      {:ok, independent, claims} =
        AshAuthentication.Jwt.token_for_user(user, %{"purpose" => "account_recovery"},
          purpose: :account_recovery,
          authorize?: false
        )

      independent_before = Ash.get!(Token, claims["jti"], authorize?: false)
      {_, bearer} = issue(request, registration)
      assert {:ok, :reset} = reset(bearer)
      device = Ash.get!(DeviceAssurance, id, authorize?: false)
      assert device.state == :revoked
      assert device.revoked_at != nil
      updated = Ash.get!(Session, session.id, authorize?: false)
      assert updated.state == :revoked

      assert Enum.all?(
               [
                 :step_up_purpose,
                 :step_up_at,
                 :step_up_expires_at,
                 :step_up_mfa_version,
                 :step_up_security_version
               ],
               &(Map.get(updated, &1) == nil)
             )

      assert Ash.get!(Token, claims["jti"], authorize?: false) == independent_before
      assert {:ok, _, Account} = AshAuthentication.Jwt.verify(independent, Account)
      assert Ash.get!(Account, user.id, authorize?: false).mfa_version == user.mfa_version
    end)
  end

  test "Audit obligation or job failure rolls back proof credential Sessions and device revocations" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
      {proof, bearer} = issue(request, registration)
      initial = Ash.get!(Account, registration.account_id, authorize?: false)

      for table <- ["evidence_obligations", "oban_jobs"] do
        Repo.query!(
          "CREATE FUNCTION p812_fault() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'p812 synthetic failure' USING ERRCODE = '23514'; END; $$"
        )

        Repo.query!(
          "CREATE TRIGGER p812_fault BEFORE INSERT ON #{table} FOR EACH ROW EXECUTE FUNCTION p812_fault()"
        )

        try do
          assert reset(bearer) == {:error, :reset_unavailable}
          assert Ash.get!(Account, initial.id, authorize?: false) == initial
          assert Ash.get!(Token, proof.jti, authorize?: false).purpose == "password_reset"
          assert {:ok, _} = Identity.authorize_session(credentials)
        after
          Repo.query!("DROP TRIGGER p812_fault ON #{table}")
          Repo.query!("DROP FUNCTION p812_fault()")
        end
      end

      assert {:ok, :reset} = reset(bearer)
    end)
  end

  test "minimized reset evidence materializes once and jobs retain identifiers only" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      {_, bearer} = issue(request, registration)
      operation = operation()
      password = "sensitive replacement password"
      old = Ash.get!(Account, registration.account_id, authorize?: false)

      logs =
        capture_log([level: :debug], fn ->
          assert {:ok, :reset} = Identity.reset_password(bearer, password, operation)
        end)

      current = Ash.get!(Account, old.id, authorize?: false)

      obligation =
        EvidenceObligation
        |> Ash.Query.filter(source_operation_id == ^operation)
        |> Ash.read_one!(authorize?: false)

      assert obligation.evidence_type == :identity_password_reset
      assert obligation.outcome == :succeeded
      assert obligation.actor_id == old.id
      assert obligation.target_id == old.id

      assert Enum.all?(
               [:grant_id, :session_id, :admission_id, :reason_code, :case_id],
               &(Map.get(obligation, &1) == nil)
             )

      assert {:ok, result} =
               Audit.materialize_registration_evidence(%{primary_key: %{id: obligation.id}},
                 authorize?: false
               )

      assert {:ok, ^result} =
               Audit.materialize_registration_evidence(%{primary_key: %{id: obligation.id}},
                 authorize?: false
               )

      payload =
        Repo.query!(
          "SELECT row_to_json(e)::text FROM evidence_obligations e WHERE source_operation_id=$1",
          [Ecto.UUID.dump!(operation)]
        ).rows
        |> inspect()

      jobs =
        Repo.query!("SELECT args::text FROM oban_jobs WHERE args->'primary_key'->>'id'=$1", [
          obligation.id
        ]).rows
        |> inspect()

      for sensitive <- [
            password,
            request.password,
            bearer,
            old.hashed_password,
            current.hashed_password,
            request.email
          ] do
        refute String.contains?(logs, sensitive)
        refute String.contains?(payload, sensitive)
        refute String.contains?(jobs, sensitive)
      end
    end)
  end

  test "provider ambiguity and missing signing authority never imply a reset" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      {proof, _} = issue(request, registration)

      intent =
        Communications.MessageIntent
        |> Ash.Query.filter(source_reference == ^proof.jti)
        |> Ash.read_one!(authorize?: false)

      before = Ash.get!(Account, registration.account_id, authorize?: false)
      key = Application.fetch_env!(:new_you, :identity_token_signing_secret)

      try do
        Application.delete_env(:new_you, :identity_token_signing_secret)
        assert {:ok, :held} = Communications.execute(intent.id)
      after
        Application.put_env(:new_you, :identity_token_signing_secret, key)
      end

      Process.put(:p810_provider, fn _, _ -> :unknown end)

      try do
        assert {:ok, :processed} = Communications.execute(intent.id)
        assert {:ok, :waiting} = Communications.execute(intent.id)
      after
        Process.delete(:p810_provider)
      end

      assert Ash.get!(Token, proof.jti, authorize?: false).purpose == "password_reset"
      assert Ash.get!(Account, before.id, authorize?: false) == before
    end)
  end

  for {point, cut} <- [
        after_admission: :"transaction.after_commit",
        before_invoke: :"provider.before_invoke",
        after_invoke: :"provider.after_invoke_before_persist"
      ] do
    test "reset delivery survives executor loss at #{point} without changing Identity" do
      P805.with_fixture(fn ->
        {request, registration} = account()
        {proof, _} = issue(request, registration)

        intent =
          Communications.MessageIntent
          |> Ash.Query.filter(source_reference == ^proof.jti)
          |> Ash.read_one!(authorize?: false)

        before = Ash.get!(Account, registration.account_id, authorize?: false)
        scenario = NewYou.Proof.Scenario.start()
        :ok = NewYou.Proof.CutPoints.arm(scenario, unquote(cut), :executor, :terminate)

        try do
          {worker, monitor} =
            NewYou.Proof.Scenario.spawn(scenario, :executor, fn ->
              Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
                Process.put(:p810_provider, fn _, _ -> :accepted end)

                Process.put(NewYou.Proof.DeliverySeam, fn point ->
                  if point == unquote(point),
                    do: NewYou.Proof.CutPoints.hit(scenario, unquote(cut), :executor)
                end)

                Communications.execute(intent.id)
              end)
            end)

          assert_receive {:DOWN, ^monitor, :process, ^worker, :proof_terminated}, 10_000
          assert NewYou.Proof.CutPoints.verify_consumed(scenario) == :ok
          assert Ash.get!(Token, proof.jti, authorize?: false).purpose == "password_reset"
          assert Ash.get!(Account, before.id, authorize?: false) == before
          Process.put(:p810_provider, fn _, _ -> :delivered end)
          assert {:ok, :waiting} = Communications.execute(intent.id)

          attempts =
            Communications.DeliveryAttempt
            |> Ash.Query.filter(message_intent_id == ^intent.id)
            |> Ash.read!(authorize?: false)

          if unquote(point) == :after_admission do
            assert Enum.all?(attempts, &(&1.invocation_started_at == nil))
            assert {:ok, :processed} = Communications.execute(intent.id)
          else
            assert Enum.any?(attempts, &(&1.provider_observation == :unknown))

            Process.put(:p810_provider, fn _, _ ->
              flunk("ambiguous delivery must not resubmit")
            end)

            assert {:ok, :waiting} = Communications.execute(intent.id)
          end

          assert Ash.get!(Account, before.id, authorize?: false) == before
        after
          Process.delete(:p810_provider)
          NewYou.Proof.Scenario.stop(scenario)
        end
      end)
    end
  end

  test "committed confirmation recovers its receipt after proof expiry and expired cleanup" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      {proof, _} = issue(request, registration)
      expiry = System.system_time(:second) + 3
      claims = Map.put(proof.reset_claims, "exp", expiry)

      {:ok, bearer, ^claims} =
        Joken.encode_and_sign(claims, AshAuthentication.Jwt.Config.token_signer(Account))

      Repo.query!("UPDATE tokens SET reset_claims=$1, expires_at=to_timestamp($2) WHERE jti=$3", [
        claims,
        expiry,
        proof.jti
      ])

      operation = operation()
      assert {:ok, :reset} = Identity.reset_password(bearer, "replacement", operation)
      after_account = Ash.get!(Account, registration.account_id, authorize?: false)
      Process.sleep(max((expiry - System.system_time(:second)) * 1000 + 100, 0))

      assert {:ok, :already_reset} =
               Identity.reset_password(bearer, "different ignored input", operation)

      assert reset(bearer) == {:error, :reset_unavailable}
      assert Ash.get!(Account, after_account.id, authorize?: false) == after_account
      consumed = Ash.get!(Token, proof.jti, authorize?: false)
      assert consumed.reset_account_binding == nil

      assert Token
             |> Ash.Query.for_read(:expired, %{}, authorize?: false)
             |> Ash.read!()
             |> Enum.all?(&(&1.jti != proof.jti))

      assert match?(
               {:error, _},
               Ash.destroy(consumed, action: :expunge_expired, authorize?: false)
             )
    end)
  end

  defp reset(bearer), do: Identity.reset_password(bearer, "replacement", operation())

  defp account do
    request = P805.request()
    {:ok, result} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(result.verification_proof)
    {request, result}
  end

  defp issue(request, registration) do
    :ok = Identity.request_password_reset(request.email, "af", operation())
    proof = current_proof(registration.account_id)
    {:ok, bearer} = delivery(proof, request.email)
    {proof, bearer}
  end

  defp current_proof(id),
    do:
      Token
      |> Ash.Query.filter(account_id == ^id and purpose == "password_reset")
      |> Ash.read_one!(authorize?: false)

  defp delivery(proof, email, locale \\ "af") do
    case Ash.transact([Account, Token], fn ->
           Identity.password_reset_delivery(proof.jti, email, locale)
         end) do
      {:ok, result} -> result
      _ -> {:error, :source_invalid}
    end
  end

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end
end
