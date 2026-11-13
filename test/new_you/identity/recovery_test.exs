defmodule NewYou.Identity.RecoveryTest do
  use ExUnit.Case, async: false
  require Ash.Query
  alias NewYou.Identity
  alias NewYou.Identity.{Account, Token}
  alias NewYou.Proof.P805

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

  test "a verified-channel request creates durable case authority without consuming proof" do
    P805.with_fixture(fn ->
      {request, registered} = account()
      assert invoke(:request_recovery, [request.email, "af", operation()]) == :ok
      assert {:ok, [recovery]} = cases(registered.account_id)
      assert recovery.state == :proof_pending
      assert recovery.required_assurance == 1
      assert recovery.satisfied_assurance == 0
      assert is_nil(recovery.completed_at)
      assert Ash.get!(Account, registered.account_id, authorize?: false).email_verified?
      assert Ash.get!(Token, recovery.proof_jti, authorize?: false).purpose == "recovery"
    end)
  end

  test "explicit proof acceptance and completion are separate, durable and replay-safe" do
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
      confirmation = operation()
      assert invoke(:submit_recovery_proof, [bearer, confirmation]) == {:ok, :accepted}
      {:ok, [accepted]} = cases(registered.account_id)
      assert accepted.state == :additional_assurance
      assert accepted.satisfied_assurance == 1
      before = Ash.get!(Account, registered.account_id, authorize?: false)
      completion = operation()

      assert invoke(:complete_recovery, [
               bearer,
               "new independent recovery credential",
               completion
             ]) == {:ok, :completed}

      assert invoke(:complete_recovery, [bearer, "ignored retry credential", completion]) ==
               {:ok, :already_completed}

      assert invoke(:complete_recovery, [bearer, "replay credential", operation()]) ==
               {:error, :recovery_unavailable}

      after_account = Ash.get!(Account, registered.account_id, authorize?: false)
      assert after_account.credential_version == before.credential_version + 1
      assert after_account.email_verified? == before.email_verified?
      assert after_account.privacy_version_id == before.privacy_version_id
      assert Identity.authorize_session(session) == {:error, :authentication_unavailable}

      assert Ash.get!(NewYou.Identity.DeviceAssurance, device_id, authorize?: false).state ==
               :revoked

      # Completion invalidates prior authentication; only a fresh password sign-in
      # may create the next Session. Idempotent completion must not create one.
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
                 "new independent recovery credential"
               )

      assert fresh_session.session_id != session.session_id
      assert {:ok, _} = Identity.authorize_session(fresh_session)
      assert session_count.() == 2
    end)
  end

  test "proof and assurance rollback together at the existing source transaction cut" do
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

  test "duplicates reuse one case and never lower the required assurance" do
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

  test "cancelled expired and stale-security cases remain terminal" do
    for expected <- [:cancelled, :expired, :failed] do
      P805.with_fixture(fn ->
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

        assert Ash.get!(Token, recovery.proof_jti, authorize?: false).purpose ==
                 "recovery_revoked"
      end)
    end
  end

  test "completion failure rolls back credential and keeps its durable E2 and notice absent" do
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

  test "foreign purpose and unauthorized Ash access cannot advance a case" do
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

  test "anonymous unverified requests do not restrict the Account and can resume after owner verification" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registered} = Identity.register(request)
      before_account = Ash.get!(Account, registered.account_id, authorize?: false)
      request_id = operation()
      :ok = Identity.request_recovery(request.email, "af", request_id)
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

      :ok = Identity.request_recovery(request.email, "af", operation())
      assert {:ok, [^held]} = cases(registered.account_id)
      assert Ash.get!(Account, registered.account_id, authorize?: false) == before_account

      assert {:ok, :verified} = Identity.verify_email(registered.verification_proof)
      :ok = Identity.request_recovery(request.email, "af", request_id)
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
        # The bounded DB checkout is disconnected on timeout. Reconnect for
        # observation, as the existing P8-12 cancellation proof does.
        Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)
        assert {:ok, []} = cases(registered.account_id)
        send(worker, {ref, :release})
      after
        Scenario.stop(scenario)
      end
    end)
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

  defp cases(id) do
    NewYou.Identity.RecoveryCase
    |> Ash.Query.filter(account_id == ^id)
    |> Ash.read(authorize?: false)
  rescue
    _ -> {:error, :not_implemented}
  end

  defp delivery(recovery, email) do
    case Ash.transact([Account, Token], fn ->
           invoke(:recovery_delivery, [recovery.proof_jti, email, "af"])
         end) do
      {:ok, result} -> result
      other -> other
    end
  end

  defp invoke(name, args) do
    apply(Identity, name, args)
  rescue
    UndefinedFunctionError -> {:error, :not_implemented}
  end

  defp hold_obligation(id) do
    NewYou.Audit.EvidenceObligation
    |> Ash.Query.filter(source_operation_id == ^id and evidence_type == :security_hold_placement)
    |> Ash.read_one!(authorize?: false)
  end

  defp trusted_device(account_id) do
    id = Ecto.UUID.generate()

    NewYou.Repo.query!(
      "INSERT INTO device_assurances (id,account_id,fingerprint,state,security_version,expires_at) VALUES ($1,$2,$3,'trusted',1,now()+interval '1 day')",
      [Ecto.UUID.dump!(id), Ecto.UUID.dump!(account_id), :crypto.strong_rand_bytes(32)]
    )

    id
  end

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  defp account do
    request = P805.request()
    {:ok, registered} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registered.verification_proof)
    {request, registered}
  end
end
