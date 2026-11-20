defmodule NewYou.Identity.PasswordResetLifecycleTest do
  use ExUnit.Case, async: false
  import NewYou.Proof.ResetCases
  require Ash.Query
  import ExUnit.CaptureLog
  alias NewYou.{Identity, Communications, Audit, Repo}
  alias NewYou.Identity.{Account, Token, Session, DeviceAssurance}
  alias NewYou.Audit.EvidenceObligation
  alias NewYou.Proof.P805

  test "current password rejection preserves the full reset boundary for a later different password" do
    P805.with_fixture(fn ->
      {request, registration} = account()
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
      session = Ash.get!(Session, credentials.session_id, authorize?: false)

      Ash.update!(
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

      device_id = Ecto.UUID.generate()

      Repo.query!(
        "INSERT INTO device_assurances (id,account_id,fingerprint,state,security_version,expires_at) VALUES ($1,$2,$3,'trusted',1,now()+interval '1 day')",
        [
          Ecto.UUID.dump!(device_id),
          Ecto.UUID.dump!(registration.account_id),
          :crypto.strong_rand_bytes(32)
        ]
      )

      {proof, bearer} = issue(request, registration)
      confirmation_id = operation()
      before_account = Ash.get!(Account, registration.account_id, authorize?: false)
      before = reset_security_snapshot(registration.account_id)
      result = Identity.reset_password(bearer, request.password, confirmation_id)
      after_attempt = reset_security_snapshot(registration.account_id)

      old_password_authenticates? =
        match?({:ok, _}, Identity.authenticate_password(request.email, request.password))

      # RED diagnostics contain only fixed outcomes and per-table equality facts.
      # Account hashes, registration verifiers and bearer data stay in memory.
      observed =
        Map.new(before, fn {table, fingerprint} ->
          {table, Map.fetch!(after_attempt, table) == fingerprint}
        end)
        |> Map.put(:result, result)
        |> Map.put(:old_password_authenticates, old_password_authenticates?)

      expected =
        Map.new(before, fn {table, _fingerprint} -> {table, true} end)
        |> Map.put(:result, {:error, :reset_unavailable})
        |> Map.put(:old_password_authenticates, true)

      assert observed == expected
      assert Ash.get!(Token, proof.jti, authorize?: false).purpose == "password_reset"
      assert {:ok, _} = Identity.authorize_session(credentials)

      replacement = "a different password after the rejected reset"
      assert {:ok, :reset} = Identity.reset_password(bearer, replacement, confirmation_id)
      current = Ash.get!(Account, registration.account_id, authorize?: false)
      assert current.credential_version == before_account.credential_version + 1
      assert current.security_version == before_account.security_version + 1
      assert Ash.get!(Token, proof.jti, authorize?: false).purpose == "password_reset_consumed"
      assert {:error, :authentication_unavailable} = Identity.authorize_session(credentials)
      assert Ash.get!(Token, session.token_jti, authorize?: false).purpose == "revocation"
      assert Ash.get!(DeviceAssurance, device_id, authorize?: false).state == :revoked

      binding =
        Identity.RegistrationOperation
        |> Ash.Query.filter(operation_id == ^request.operation_id)
        |> Ash.read_one!(authorize?: false)

      assert binding.state == :tombstoned
      assert binding.password_verifier == nil

      obligation =
        EvidenceObligation
        |> Ash.Query.filter(source_operation_id == ^confirmation_id)
        |> Ash.read_one!(authorize?: false)

      assert obligation.evidence_type == :identity_password_reset
      assert obligation.outcome == :succeeded

      assert {:error, :authentication_unavailable} =
               Identity.authenticate_password(request.email, request.password)

      assert {:ok, _} = Identity.authenticate_password(request.email, replacement)
      committed = reset_security_snapshot(registration.account_id)

      assert {:ok, :already_reset} =
               Identity.reset_password(bearer, replacement, confirmation_id)

      assert reset_security_snapshot(registration.account_id) == committed
    end)
  end

  test "expiry revocation supersession replay and wrong-purpose proofs fail closed" do
    NewYou.Proof.ResetCases.fail_closed()
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
        P805.with_rejected_insert(table, fn reached ->
          assert reset(bearer) == {:error, :reset_uncertain}
          assert reached.()
          assert Ash.get!(Account, initial.id, authorize?: false) == initial
          assert Ash.get!(Token, proof.jti, authorize?: false).purpose == "password_reset"
          assert {:ok, _} = Identity.authorize_session(credentials)
        end)
      end

      assert {:ok, :reset} = reset(bearer)
    end)
  end

  for table <- ["evidence_obligations", "oban_jobs"] do
    test "#{table} reset fault excludes an independent registration connection" do
      P805.with_fixture(fn ->
        {request, registration} = account()
        {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
        {proof, bearer} = issue(request, registration)
        initial = reset_security_snapshot(registration.account_id)
        owner_backend = P805.scalar("SELECT pg_backend_pid()")
        owner = self()
        cleanup_reference = make_ref()

        P805.with_rejected_insert(unquote(table), fn reached ->
          # B's fault stays installed until A has committed and completed its
          # own teardown on a separate connection.
          foreign =
            P805.independent_fixture_task(fn ->
              Process.put({P805, :fixture_cleanup_hook}, fn ->
                send(owner, {cleanup_reference, :foreign_cleanup})
              end)

              distinct_connection? = P805.scalar("SELECT pg_backend_pid()") != owner_backend
              result = Identity.register(P805.request())
              {distinct_connection?, match?({:ok, _}, result), P805.counts()}
            end)

          {distinct_connection?, committed?, consequences} = Task.await(foreign, 10_000)
          assert distinct_connection?
          assert committed?, "independent registration must commit"
          assert consequences == [1, 1, 1, 0, 1, 1, 1, 1, 1, 1]
          assert_receive {^cleanup_reference, :foreign_cleanup}
          refute_receive {^cleanup_reference, :foreign_cleanup}
          assert reset(bearer) == {:error, :reset_uncertain}
          assert reached.()
          assert reset_security_snapshot(registration.account_id) == initial
          assert Ash.get!(Token, proof.jti, authorize?: false).purpose == "password_reset"
          assert {:ok, _} = Identity.authorize_session(credentials)
        end)

        assert {:ok, :reset} = reset(bearer)
      end)
    end
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
end
