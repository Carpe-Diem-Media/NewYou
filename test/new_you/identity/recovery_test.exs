defmodule NewYou.Identity.RecoveryTest do
  use ExUnit.Case, async: false
  import NewYou.Proof.RecoveryScenarios
  require Ash.Query
  import ExUnit.CaptureLog
  alias NewYou.{Identity, Repo}
  alias NewYou.Identity.{Account, Token}
  alias NewYou.Proof.{P805, RecoverySeam}

  test "non-completed terminal cases cannot retain partial completion metadata" do
    P805.with_fixture(fn ->
      {request, registered} = account()
      :ok = Identity.request_recovery(request.email, "af", operation())
      {:ok, [recovery]} = cases(registered.account_id)

      for partial <- [%{completed_at: DateTime.utc_now()}, %{completion_id: Ecto.UUID.generate()}] do
        attrs =
          Map.merge(partial, %{
            terminated_at: DateTime.utc_now(),
            history:
              recovery.history ++ [%{"state" => "failed", "version" => recovery.version + 1}]
          })

        assert {:error, error} = Ash.update(recovery, attrs, action: :fail, authorize?: false)

        assert Enum.any?(
                 error.errors,
                 &match?(%Ash.Error.Changes.InvalidAttribute{field: :state}, &1)
               )

        assert Ash.get!(NewYou.Identity.RecoveryCase, recovery.id, authorize?: false) == recovery
      end
    end)
  end

  test "a verified-channel request and its replay keep one linked unconsumed proof" do
    P805.with_fixture(fn ->
      {request, registered} = account()
      operation_id = operation()
      account = P805.account!(registered.account_id)
      assert account.email_verified?
      assert :ok = Identity.request_recovery(request.email, "af", operation_id)
      assert {:ok, [recovery]} = cases(registered.account_id)
      assert recovery.operation_id == operation_id
      assert recovery.state == :proof_pending
      assert recovery.required_assurance == 1
      assert recovery.satisfied_assurance == 0
      assert is_nil(recovery.completed_at)
      effects = assert_recovery_proof(recovery)

      assert :ok = Identity.request_recovery(request.email, "af", operation_id)
      assert {:ok, [^recovery]} = cases(registered.account_id)
      assert assert_recovery_proof(recovery) == effects
      assert P805.account!(account.id) == account
    end)
  end

  test "explicit proof acceptance and completion are separate, durable and replay-safe" do
    NewYou.Proof.RecoveryScenarios.scenario_explicit_proof_acceptance_and_completion_are_separate_durable_and_replay_safe()
  end

  test "proof and assurance rollback together at the existing source transaction cut" do
    NewYou.Proof.RecoveryScenarios.scenario_proof_and_assurance_rollback_together_at_the_existing_source_transaction_cut()
  end

  test "duplicates reuse one case and never lower the required assurance" do
    NewYou.Proof.RecoveryScenarios.scenario_duplicates_reuse_one_case_and_never_lower_the_required_assurance()
  end

  test "cancelled expired and stale-security cases remain terminal" do
    NewYou.Proof.RecoveryScenarios.scenario_cancelled_expired_and_stale_security_cases_remain_terminal()
  end

  test "completion failure rolls back credential and keeps its durable E2 and notice absent" do
    NewYou.Proof.RecoveryScenarios.scenario_completion_failure_rolls_back_credential_and_keeps_its_durable_e2_and_notice_absent()
  end

  test "foreign purpose and unauthorized Ash access cannot advance a case" do
    NewYou.Proof.RecoveryScenarios.scenario_foreign_purpose_and_unauthorized_ash_access_cannot_advance_a_case()
  end

  test "PostgreSQL rejects assurance reduction and terminal reopening" do
    P805.with_fixture(fn ->
      {request, registered} = account()
      :ok = Identity.request_recovery(request.email, "af", operation())
      {:ok, [recovery]} = cases(registered.account_id)
      {:ok, bearer} = delivery(recovery, request.email)
      assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}

      assert Identity.complete_recovery(bearer, "new permanent credential", operation()) ==
               {:ok, :completed}

      assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
               NewYou.Repo.query(
                 "UPDATE recovery_cases SET state='proof_pending',completed_at=NULL,completion_id=NULL,terminated_at=NULL,version=version+1 WHERE id=$1",
                 [Ecto.UUID.dump!(recovery.id)]
               )

      assert Ash.get!(NewYou.Identity.RecoveryCase, recovery.id, authorize?: false).state ==
               :completed
    end)
  end

  test "revoked proof and reused credentials fail without creating authority" do
    NewYou.Proof.RecoveryScenarios.scenario_revoked_proof_and_reused_credentials_fail_without_creating_authority()
  end

  test "anonymous unverified requests do not restrict the Account and can resume after owner verification" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registered} = Identity.register(request)
      before_account = Ash.get!(Account, registered.account_id, authorize?: false)
      request_id = operation()
      :ok = RecoverySeam.isolated_fixture_request(request.email, request_id)
      {:ok, [held]} = cases(registered.account_id)
      assert held.state == :held_manual_review
      assert held.required_assurance == 2
      assert held.satisfied_assurance == 0
      assert is_nil(held.proof_jti)
      assert is_nil(hold_obligation(held.operation_id))
      after_account = Ash.get!(Account, registered.account_id, authorize?: false)
      refute after_account.email_verified?
      assert after_account == before_account
      assert after_account.security_posture == :normal

      :ok = RecoverySeam.isolated_fixture_request(request.email, operation())
      assert {:ok, [^held]} = cases(registered.account_id)
      assert Ash.get!(Account, registered.account_id, authorize?: false) == before_account

      assert {:ok, :verified} = Identity.verify_email(registered.verification_proof)
      :ok = RecoverySeam.isolated_fixture_request(request.email, request_id)
      assert {:ok, [resumed]} = cases(registered.account_id)
      assert resumed.id == held.id
      assert resumed.required_assurance == 2
      assert resumed.satisfied_assurance == 0
      assert resumed.state == :proof_pending
      {:ok, bearer} = delivery(resumed, request.email)
      assert {:ok, session} = Identity.authenticate_password(request.email, request.password)
      assert {:ok, _} = Identity.authorize_session(session)

      assert {:ok, :accepted} = Identity.submit_recovery_proof(bearer, operation())
      assert Ash.get!(Account, registered.account_id, authorize?: false).security_posture == :held
      assert hold_obligation(held.operation_id).case_id == held.id

      assert Identity.authorize_session(session) == {:error, :authentication_unavailable}
      assert {:ok, :cancelled} = Identity.cancel_recovery(bearer, operation())
      # Case termination cannot silently release a justified Account hold.
      assert Ash.get!(Account, registered.account_id, authorize?: false).security_posture == :held
    end)
  end

  test "a resumed recovery lease can expire without disconnecting the fixture owner" do
    P805.with_fixture(fn ->
      request = P805.request()
      assert {:ok, registration} = Identity.register(request)
      id = operation()
      assert :ok = RecoverySeam.isolated_fixture_request(request.email, id)
      assert {:ok, [held]} = cases(registration.account_id)
      assert held.state == :held_manual_review
      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      account = P805.account!(registration.account_id)
      assert account.email_verified?
      assert account.security_posture == :normal
      owner_backend = P805.scalar("SELECT pg_backend_pid()")
      parent = self()
      reference = make_ref()

      RecoverySeam.observe(fn
        :checkpoint ->
          assert {:ok, [pending]} = cases(registration.account_id)
          assert pending.state == :proof_pending
          assert recovery_effects(pending) == {1, 1}

          %{rows: [[backend, xid]]} =
            Repo.query!("SELECT pg_backend_pid(), pg_current_xact_id()::text")

          send(parent, {reference, :checkpoint, backend, xid})
          Repo.query!("SELECT pg_sleep(1)")

        _ ->
          :ok
      end)

      try do
        log =
          capture_log(fn ->
            started = System.monotonic_time(:millisecond)
            assert :ok = RecoverySeam.isolated_fixture_request(request.email, id)
            assert System.monotonic_time(:millisecond) - started >= 500
          end)

        assert_receive {^reference, :checkpoint, backend, xid}

        assert log =~
                 "checked out the connection for longer than #{NewYou.Identity.Recovery.request_transaction_timeout_ms()}ms"

        assert P805.scalar("SELECT pg_backend_pid()") == owner_backend
        refute backend == owner_backend
        assert P805.scalar("SELECT pg_xact_status($1::text::xid8)", [xid]) == "aborted"
        assert {:ok, [^held]} = cases(registration.account_id)
        assert P805.account!(registration.account_id) == account
        assert recovery_effects(held) == {0, 0}
        assert is_nil(hold_obligation(id))
      after
        Process.delete({RecoverySeam, :observer})
      end

      assert :ok = RecoverySeam.isolated_fixture_request(request.email, id)
      assert {:ok, [resumed]} = cases(registration.account_id)
      assert resumed.id == held.id
      assert resumed.operation_id == id
      assert resumed.version == held.version + 1
      assert resumed.state == :proof_pending
      assert resumed.required_assurance == held.required_assurance
      assert Ash.get!(Token, resumed.proof_jti, authorize?: false).purpose == "recovery"
      assert recovery_effects(resumed) == {1, 1}

      assert [%{source_reference: proof_jti, dispatch_disposition: :held}] =
               P805.intents(id)

      assert proof_jti == resumed.proof_jti
      assert :ok = RecoverySeam.isolated_fixture_request(request.email, id)
      assert {:ok, [^resumed]} = cases(registration.account_id)
      assert recovery_effects(resumed) == {1, 1}
      assert P805.account!(registration.account_id) == account
      assert is_nil(hold_obligation(id))
    end)
  end

  test "expiry of an unverified request and its retries never leave an Account restriction" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registered} = Identity.register(request)
      before_account = Ash.get!(Account, registered.account_id, authorize?: false)
      id = operation()
      :ok = Identity.request_recovery(request.email, "af", id)
      {:ok, [recovery]} = cases(registered.account_id)
      Process.put({NewYou.Proof.RecoverySeam, :now}, DateTime.add(recovery.expires_at, 1))

      try do
        :ok = Identity.request_recovery(request.email, "af", id)

        assert Ash.get!(NewYou.Identity.RecoveryCase, recovery.id, authorize?: false).state ==
                 :expired

        :ok = Identity.request_recovery(request.email, "af", id)
        assert {:ok, [_]} = cases(registered.account_id)
        :ok = Identity.request_recovery(request.email, "af", operation())
      after
        Process.delete({NewYou.Proof.RecoverySeam, :now})
      end

      assert Ash.get!(Account, registered.account_id, authorize?: false) == before_account
      assert is_nil(hold_obligation(id))
    end)
  end

  test "case assurance survives retries while a terminal case does not impose permanent Account policy" do
    for terminal <- [:cancel, :expire] do
      P805.with_fixture(fn ->
        {request, registered} = account()
        current = Ash.get!(Account, registered.account_id, authorize?: false)

        Ash.update!(current, %{mfa_enrollment_state: :active},
          action: :update_privileged_mfa,
          authorize?: false
        )

        :ok = Identity.request_recovery(request.email, "af", operation())
        {:ok, [recovery]} = cases(registered.account_id)
        assert recovery.required_assurance == 2
        {:ok, bearer} = delivery(recovery, request.email)

        # Fixture representation of an earlier authorized factor-policy change.
        Ash.get!(Account, registered.account_id, authorize?: false)
        |> Ash.update!(%{mfa_enrollment_state: :disabled},
          action: :update_privileged_mfa,
          authorize?: false
        )

        :ok = Identity.request_recovery(request.email, "af", operation())
        assert {:ok, [same]} = cases(registered.account_id)
        assert same.id == recovery.id
        assert same.required_assurance == 2

        assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
                 NewYou.Repo.query(
                   "UPDATE recovery_cases SET required_assurance=1,version=version+1,history=array_append(history,$1::jsonb) WHERE id=$2",
                   [
                     Jason.encode!(%{action: "lower", version: recovery.version + 1}),
                     Ecto.UUID.dump!(recovery.id)
                   ]
                 )

        case terminal do
          :cancel ->
            assert {:ok, :cancelled} = Identity.cancel_recovery(bearer, operation())

          :expire ->
            Process.put({NewYou.Proof.RecoverySeam, :now}, DateTime.add(recovery.expires_at, 1))
        end

        try do
          :ok = Identity.request_recovery(request.email, "af", operation())
        after
          Process.delete({NewYou.Proof.RecoverySeam, :now})
        end

        {:ok, all} = cases(registered.account_id)
        successor = Enum.find(all, &(&1.id != recovery.id))
        assert successor.required_assurance == 1
        assert successor.state == :proof_pending

        assert Ash.get!(Account, registered.account_id, authorize?: false).security_posture ==
                 :normal
      end)
    end
  end

  test "a successor case still requires stronger assurance while current Account risk remains" do
    P805.with_fixture(fn ->
      {request, registered} = account()

      Ash.get!(Account, registered.account_id, authorize?: false)
      |> Ash.update!(%{mfa_enrollment_state: :active},
        action: :update_privileged_mfa,
        authorize?: false
      )

      :ok = Identity.request_recovery(request.email, "af", operation())
      {:ok, [recovery]} = cases(registered.account_id)
      Process.put({NewYou.Proof.RecoverySeam, :now}, DateTime.add(recovery.expires_at, 1))

      try do
        :ok = Identity.request_recovery(request.email, "af", operation())
      after
        Process.delete({NewYou.Proof.RecoverySeam, :now})
      end

      {:ok, all} = cases(registered.account_id)
      successor = Enum.find(all, &(&1.id != recovery.id))
      assert successor.required_assurance == 2
      assert successor.satisfied_assurance == 0
      assert successor.state == :proof_pending
    end)
  end

  test "ordinary security evidence materializes once without replaying recovery" do
    P805.with_fixture(fn ->
      {request, registered} = account()
      :ok = Identity.request_recovery(request.email, "af", operation())
      {:ok, [recovery]} = cases(registered.account_id)
      {:ok, bearer} = delivery(recovery, request.email)
      assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :accepted}
      id = operation()

      assert Identity.complete_recovery(bearer, "durable audited recovery", id) ==
               {:ok, :completed}

      obligation =
        NewYou.Audit.EvidenceObligation
        |> Ash.Query.filter(source_operation_id == ^id)
        |> Ash.read_one!(authorize?: false)

      assert is_nil(obligation.admission_id)
      assert obligation.case_id == recovery.id
      before = Ash.get!(Account, registered.account_id, authorize?: false)

      assert {:ok, _} =
               NewYou.Audit.materialize_registration_evidence(
                 %{primary_key: %{id: obligation.id}},
                 authorize?: false
               )

      assert {:ok, _} =
               NewYou.Audit.materialize_registration_evidence(
                 %{primary_key: %{id: obligation.id}},
                 authorize?: false
               )

      assert P805.scalar("SELECT count(*) FROM evidence_records WHERE obligation_id=$1", [
               Ecto.UUID.dump!(obligation.id)
             ]) == 1

      assert Ash.get!(Account, registered.account_id, authorize?: false) == before
    end)
  end

  test "recovery bearer and replacement input never enter cases notices Audit or jobs" do
    NewYou.Proof.RecoveryScenarios.scenario_recovery_bearer_and_replacement_input_never_enter_cases_notices_audit_or_jobs()
  end

  test "a new request expires an elapsed active case before allocating its successor" do
    P805.with_fixture(fn ->
      {request, registered} = account()
      :ok = Identity.request_recovery(request.email, "af", operation())
      {:ok, [old]} = cases(registered.account_id)
      Process.put({NewYou.Proof.RecoverySeam, :now}, DateTime.add(old.expires_at, 1))

      try do
        :ok = Identity.request_recovery(request.email, "af", operation())
      after
        Process.delete({NewYou.Proof.RecoverySeam, :now})
      end

      {:ok, current} = cases(registered.account_id)
      assert length(current) == 2
      assert Ash.get!(NewYou.Identity.RecoveryCase, old.id, authorize?: false).state == :expired
      assert Ash.get!(Token, old.proof_jti, authorize?: false).purpose == "recovery_revoked"
    end)
  end

  test "a locked known account cannot extend the neutral public request window" do
    NewYou.Proof.RecoveryScenarios.scenario_a_locked_known_account_cannot_extend_the_neutral_public_request_window()
  end

  test "later canonical email authority invalidates the old recovery binding" do
    P805.with_fixture(fn ->
      {request, registered} = account()
      :ok = Identity.request_recovery(request.email, "af", operation())
      {:ok, [recovery]} = cases(registered.account_id)
      {:ok, bearer} = delivery(recovery, request.email)
      replacement_email = "changed-" <> Ecto.UUID.generate() <> "@example.test"
      # This fixture advances canonical email after the recovery snapshot. The
      # dedicated P8-16 race test exercises the real owning apply interface.
      NewYou.Repo.query!("UPDATE accounts SET email=$1 WHERE id=$2", [
        replacement_email,
        Ecto.UUID.dump!(registered.account_id)
      ])

      NewYou.Proof.P805.request(%{email: replacement_email})
      assert Identity.submit_recovery_proof(bearer, operation()) == {:ok, :failed}

      assert Ash.get!(Account, registered.account_id, authorize?: false).email ==
               replacement_email

      assert Ash.get!(NewYou.Identity.RecoveryCase, recovery.id, authorize?: false).state ==
               :failed

      email_write_actions =
        Enum.filter(Ash.Resource.Info.actions(Account), fn action ->
          action.type == :update and :email in Map.get(action, :accept, [])
        end)

      assert Enum.map(email_write_actions, & &1.name) == [:apply_primary_email_change]
      refute hd(email_write_actions).public?
    end)
  end

  defp recovery_effects(recovery) do
    tokens =
      P805.scalar("SELECT count(*) FROM tokens WHERE recovery_case_id = $1", [
        Ecto.UUID.dump!(recovery.id)
      ])

    intents = Enum.count(P805.intents(recovery.operation_id), &(&1.role == :account_recovery))
    {tokens, intents}
  end
end
