defmodule NewYou.Proof.RecoveryScenarios do
  @moduledoc false
  import ExUnit.Assertions
  require Ash.Query
  alias NewYou.Identity
  alias NewYou.Identity.{Account, Token}
  alias NewYou.Proof.P805

  def scenario_explicit_proof_acceptance_and_completion_are_separate_durable_and_replay_safe() do
    P805.with_fixture(fn ->
      {request, registered} = account()
      {:ok, session} = Identity.authenticate_password(request.email, request.password)
      device_id = Ecto.UUID.generate()

      NewYou.Repo.query!(
        "INSERT INTO device_assurances (id,account_id,fingerprint,state,security_version,expires_at) VALUES ($1,$2,$3,'trusted',1,now()+interval '1 day')",
        [
          Ecto.UUID.dump!(device_id),
          Ecto.UUID.dump!(registered.account_id),
          :crypto.strong_rand_bytes(32)
        ]
      )

      :ok = invoke(:request_recovery, [request.email, "af", operation()])
      {:ok, [recovery]} = cases(registered.account_id)
      {:ok, bearer} = delivery(recovery, request.email)
      before = Ash.get!(Account, registered.account_id, authorize?: false)
      completion = operation()
      password = "new independent recovery credential"
      pending_effects = assert_recovery_proof(recovery)

      assert Identity.complete_recovery(bearer, password, completion) ==
               {:error, :recovery_unavailable}

      assert {:ok, [^recovery]} = cases(registered.account_id)
      assert assert_recovery_proof(recovery) == pending_effects
      assert P805.intents(completion) == []
      assert Ash.get!(Account, registered.account_id, authorize?: false) == before

      confirmation = operation()
      assert invoke(:submit_recovery_proof, [bearer, confirmation]) == {:ok, :accepted}
      {:ok, [accepted]} = cases(registered.account_id)
      assert accepted.state == :additional_assurance
      assert accepted.satisfied_assurance == 1
      assert accepted.proof_acceptance_id == confirmation
      assert Identity.complete_recovery(bearer, password, completion) == {:ok, :completed}

      assert {:ok, [%{state: :completed, completion_id: ^completion} = completed]} =
               cases(registered.account_id)

      assert completed.completed_at

      assert invoke(:complete_recovery, [bearer, "ignored retry credential", completion]) ==
               {:ok, :already_completed}

      assert invoke(:complete_recovery, [bearer, "replay credential", operation()]) ==
               {:error, :recovery_unavailable}

      assert {:ok, [^completed]} = cases(registered.account_id)

      after_account = Ash.get!(Account, registered.account_id, authorize?: false)
      assert after_account.credential_version == before.credential_version + 1
      assert after_account.email_verified? == before.email_verified?
      assert after_account.privacy_version_id == before.privacy_version_id
      assert Identity.authorize_session(session) == {:error, :authentication_unavailable}

      assert Ash.get!(NewYou.Identity.DeviceAssurance, device_id, authorize?: false).state ==
               :revoked

      session_count = fn ->
        P805.scalar("SELECT count(*) FROM sessions WHERE account_id = $1", [
          Ecto.UUID.dump!(registered.account_id)
        ])
      end

      assert session_count.() == 1

      assert Identity.authenticate_password(request.email, request.password) ==
               {:error, :authentication_unavailable}

      assert session_count.() == 1

      assert {:ok, fresh_session} =
               Identity.authenticate_password(
                 request.email,
                 password
               )

      assert fresh_session.session_id != session.session_id
      assert {:ok, _} = Identity.authorize_session(fresh_session)
      assert session_count.() == 2
    end)
  end

  def scenario_proof_and_assurance_rollback_together_at_the_existing_source_transaction_cut() do
    P805.with_fixture(fn ->
      {request, registered} = account()
      :ok = Identity.request_recovery(request.email, "af", operation())
      {:ok, [recovery]} = cases(registered.account_id)
      {:ok, bearer} = delivery(recovery, request.email)

      Process.put(
        NewYou.Proof.RegistrationSeam,
        {:observe, fn -> raise "synthetic proof acceptance cut" end}
      )

      assert Identity.submit_recovery_proof(bearer, operation()) ==
               {:error, :recovery_unavailable}

      Process.delete(NewYou.Proof.RegistrationSeam)
      assert Ash.get!(Token, recovery.proof_jti, authorize?: false).purpose == "recovery"

      assert Ash.get!(NewYou.Identity.RecoveryCase, recovery.id, authorize?: false).state ==
               :proof_pending

      assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}
    end)
  end

  def scenario_duplicates_reuse_one_case_and_never_lower_the_required_assurance() do
    P805.with_fixture(fn ->
      {request, registered} = account()
      current = Ash.get!(Account, registered.account_id, authorize?: false)

      Ash.update!(current, %{mfa_enrollment_state: :active},
        action: :update_privileged_mfa,
        authorize?: false
      )

      {:ok, session} = Identity.authenticate_password(request.email, request.password)
      before_request = Ash.get!(Account, registered.account_id, authorize?: false)
      device = trusted_device(registered.account_id)
      id = operation()
      :ok = Identity.request_recovery(request.email, "af", id)
      {:ok, [recovery]} = cases(registered.account_id)
      assert recovery.required_assurance == 2
      assert Ash.get!(Account, registered.account_id, authorize?: false) == before_request
      assert {:ok, _} = Identity.authorize_session(session)

      assert Ash.get!(NewYou.Identity.DeviceAssurance, device, authorize?: false).state ==
               :trusted

      {:ok, bearer} = delivery(recovery, request.email)

      Process.put(
        NewYou.Proof.RegistrationSeam,
        {:observe, fn -> raise "restriction source cut" end}
      )

      assert Identity.submit_recovery_proof(bearer, operation()) ==
               {:error, :recovery_unavailable}

      Process.delete(NewYou.Proof.RegistrationSeam)

      assert Ash.get!(Account, registered.account_id, authorize?: false).security_posture ==
               :normal

      assert is_nil(hold_obligation(id))
      assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}
      :ok = Identity.request_recovery(request.email, "af", operation())
      :ok = Identity.request_recovery(request.email, "af", id)
      {:ok, [held]} = cases(registered.account_id)
      assert held.id == recovery.id
      assert held.state == :held_manual_review
      assert held.required_assurance == 2
      assert held.satisfied_assurance == 1
      assert Ash.get!(Account, registered.account_id, authorize?: false).security_posture == :held
      hold_evidence = hold_obligation(id)
      assert hold_evidence.case_id == held.id
      assert hold_evidence.target_id == registered.account_id
      assert is_nil(hold_evidence.actor_id)
      assert hold_evidence.outcome == :succeeded
      assert Identity.authorize_session(session) == {:error, :authentication_unavailable}

      assert Ash.get!(NewYou.Identity.DeviceAssurance, device, authorize?: false).state ==
               :revoked

      assert Identity.complete_recovery(bearer, "forbidden ordinary shortcut", operation()) ==
               {:error, :recovery_unavailable}
    end)
  end

  def scenario_cancelled_expired_and_stale_security_cases_remain_terminal() do
    for expected <- [:cancelled, :expired, :failed] do
      P805.with_fixture(fn ->
        scenario_cancelled_expired_and_stale_security_cases_remain_terminal_fixture(expected)
      end)
    end
  end

  defp scenario_cancelled_expired_and_stale_security_cases_remain_terminal_fixture(expected) do
    {request, registered} = account()
    :ok = Identity.request_recovery(request.email, "af", operation())
    {:ok, [recovery]} = cases(registered.account_id)
    {:ok, bearer} = delivery(recovery, request.email)

    outcome =
      case expected do
        :cancelled ->
          Identity.cancel_recovery(bearer, operation())

        :expired ->
          Process.put({NewYou.Proof.RecoverySeam, :now}, DateTime.add(recovery.expires_at, 1))

          try do
            Identity.submit_recovery_proof(bearer, operation())
          after
            Process.delete({NewYou.Proof.RecoverySeam, :now})
          end

        :failed ->
          Ash.get!(Account, registered.account_id, authorize?: false)
          |> Ash.update!(%{}, action: :invalidate_grant_assurance, authorize?: false)

          Identity.submit_recovery_proof(bearer, operation())
      end

    assert outcome == {:ok, expected}

    assert Ash.get!(NewYou.Identity.RecoveryCase, recovery.id, authorize?: false).state ==
             expected

    assert Identity.complete_recovery(bearer, "terminal replay", operation()) ==
             {:error, :recovery_unavailable}

    assert Ash.get!(Token, recovery.proof_jti, authorize?: false).purpose == "recovery_revoked"
  end

  def scenario_completion_failure_rolls_back_credential_and_keeps_its_durable_e2_and_notice_absent() do
    P805.with_fixture(fn ->
      {request, registered} = account()
      :ok = Identity.request_recovery(request.email, "af", operation())
      {:ok, [recovery]} = cases(registered.account_id)
      {:ok, bearer} = delivery(recovery, request.email)
      assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}
      before = Ash.get!(Account, registered.account_id, authorize?: false)
      id = operation()

      Process.put(
        NewYou.Proof.RegistrationSeam,
        {:observe, fn -> raise "synthetic completion cut" end}
      )

      assert Identity.complete_recovery(bearer, "new recovery password", id) ==
               {:error, :recovery_unavailable}

      Process.delete(NewYou.Proof.RegistrationSeam)
      after_account = Ash.get!(Account, registered.account_id, authorize?: false)
      assert before.credential_version == after_account.credential_version
      assert before.hashed_password == after_account.hashed_password

      assert P805.scalar(
               "SELECT count(*) FROM evidence_obligations WHERE source_operation_id=$1",
               [Ecto.UUID.dump!(id)]
             ) == 0

      assert P805.scalar("SELECT count(*) FROM message_intents WHERE source_operation_id=$1", [
               Ecto.UUID.dump!(id)
             ]) == 0

      assert Identity.complete_recovery(bearer, "new recovery password", id) == {:ok, :completed}

      assert P805.scalar(
               "SELECT count(*) FROM evidence_obligations WHERE source_operation_id=$1",
               [Ecto.UUID.dump!(id)]
             ) == 1

      assert P805.scalar(
               "SELECT count(*) FROM message_intents WHERE source_operation_id=$1 AND role='recovery_security_notice' AND dispatch_disposition='held'",
               [Ecto.UUID.dump!(id)]
             ) == 1
    end)
  end

  def scenario_foreign_purpose_and_unauthorized_ash_access_cannot_advance_a_case() do
    P805.with_fixture(fn ->
      {request, registered} = account()
      :ok = Identity.request_recovery(request.email, "af", operation())
      {:ok, [recovery]} = cases(registered.account_id)

      assert Identity.submit_recovery_proof(registered.verification_proof, operation()) ==
               {:error, :recovery_unavailable}

      assert {:ok, []} = Ash.read(NewYou.Identity.RecoveryCase)
      assert {:error, _} = Ash.update(recovery, %{}, action: :finish)

      assert Ash.get!(NewYou.Identity.RecoveryCase, recovery.id, authorize?: false).state ==
               :proof_pending
    end)
  end

  def scenario_revoked_proof_and_reused_credentials_fail_without_creating_authority() do
    P805.with_fixture(fn ->
      {request, registered} = account()
      :ok = Identity.request_recovery(request.email, "af", operation())
      {:ok, [recovery]} = cases(registered.account_id)
      {:ok, bearer} = delivery(recovery, request.email)
      assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}

      assert Identity.complete_recovery(bearer, request.password, operation()) ==
               {:error, :recovery_unavailable}

      proof = Ash.get!(Token, recovery.proof_jti, authorize?: false)
      Ash.update!(proof, %{}, action: :revoke_recovery, authorize?: false)

      assert Identity.complete_recovery(bearer, "forbidden revoked proof", operation()) ==
               {:error, :recovery_unavailable}

      assert Ash.get!(NewYou.Identity.RecoveryCase, recovery.id, authorize?: false).state ==
               :additional_assurance
    end)
  end

  def scenario_recovery_bearer_and_replacement_input_never_enter_cases_notices_audit_or_jobs() do
    P805.with_fixture(fn ->
      {request, registered} = account()
      :ok = Identity.request_recovery(request.email, "af", operation())
      {:ok, [recovery]} = cases(registered.account_id)
      {:ok, bearer} = delivery(recovery, request.email)
      assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}
      replacement = "synthetic replacement credential " <> Ecto.UUID.generate()
      completion = operation()
      assert Identity.complete_recovery(bearer, replacement, completion) == {:ok, :completed}

      for table <-
            ~w(recovery_cases tokens message_intents delivery_attempts evidence_obligations evidence_records oban_jobs) do
        %{rows: rows} = NewYou.Repo.query!("SELECT to_jsonb(t)::text FROM " <> table <> " t")
        encoded = :erlang.term_to_binary(rows)
        assert :nomatch == :binary.match(encoded, bearer)
        assert :nomatch == :binary.match(encoded, replacement)
      end

      assert P805.scalar(
               "SELECT count(*) FROM oban_jobs WHERE args->'primary_key'->>'id' IN (SELECT id::text FROM evidence_obligations WHERE source_operation_id=$1)",
               [Ecto.UUID.dump!(completion)]
             ) == 1
    end)
  end

  def scenario_a_locked_known_account_cannot_extend_the_neutral_public_request_window() do
    P805.with_fixture(fn ->
      {request, registered} = account()
      alias NewYou.Proof.Scenario
      scenario = Scenario.start()
      parent = self()
      ref = make_ref()

      try do
        {worker, _monitor} =
          Scenario.spawn(scenario, :held_account, fn ->
            :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

            try do
              Ash.transact(Account, fn ->
                account =
                  Account
                  |> Ash.Query.filter(id == ^registered.account_id)
                  |> Ash.Query.lock(:for_update)
                  |> Ash.read_one!(authorize?: false)

                send(parent, {ref, :locked, account.id})

                receive do
                  {^ref, :release} -> :ok
                after
                  2000 -> :ok
                end
              end)
            after
              Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
            end
          end)

        assert_receive {^ref, :locked, _}, 5000
        assert :ok = Identity.request_recovery(request.email, "af", operation())
        Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)
        assert {:ok, []} = cases(registered.account_id)
        send(worker, {ref, :release})
      after
        Scenario.stop(scenario)
      end
    end)
  end

  def assert_recovery_proof(recovery) do
    assert [token] =
             Token
             |> Ash.Query.filter(recovery_case_id == ^recovery.id)
             |> Ash.read!(authorize?: false)

    assert token.account_id == recovery.account_id
    assert token.jti == recovery.proof_jti
    assert token.purpose == "recovery"
    assert [%{role: :account_recovery} = intent] = P805.intents(recovery.operation_id)
    assert intent.source_reference == token.jti
    {token, intent}
  end

  def cases(id) do
    NewYou.Identity.RecoveryCase
    |> Ash.Query.filter(account_id == ^id)
    |> Ash.read(authorize?: false)
  rescue
    _ -> {:error, :not_implemented}
  end

  def delivery(recovery, email) do
    case Ash.transact([Account, Token], fn ->
           invoke(:recovery_delivery, [recovery.proof_jti, email, "af"])
         end) do
      {:ok, result} -> result
      other -> other
    end
  end

  def invoke(name, args) do
    apply(Identity, name, args)
  rescue
    UndefinedFunctionError -> {:error, :not_implemented}
  end

  def hold_obligation(id) do
    NewYou.Audit.EvidenceObligation
    |> Ash.Query.filter(source_operation_id == ^id and evidence_type == :security_hold_placement)
    |> Ash.read_one!(authorize?: false)
  end

  def trusted_device(account_id) do
    id = Ecto.UUID.generate()

    NewYou.Repo.query!(
      "INSERT INTO device_assurances (id,account_id,fingerprint,state,security_version,expires_at) VALUES ($1,$2,$3,'trusted',1,now()+interval '1 day')",
      [Ecto.UUID.dump!(id), Ecto.UUID.dump!(account_id), :crypto.strong_rand_bytes(32)]
    )

    id
  end

  def operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  def account do
    request = P805.request()
    {:ok, registered} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registered.verification_proof)
    {request, registered}
  end
end
