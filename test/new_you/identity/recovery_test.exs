defmodule NewYou.Identity.RecoveryTest do
  use ExUnit.Case, async: false
  require Ash.Query
  alias NewYou.Identity
  alias NewYou.Identity.{Account, Token}
  alias NewYou.Proof.P805

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

      id = operation()
      :ok = Identity.request_recovery(request.email, "af", id)
      {:ok, [recovery]} = cases(registered.account_id)
      assert recovery.required_assurance == 2
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

      Ash.get!(Account, registered.account_id, authorize?: false)
      |> Ash.update!(%{recovery_assurance_floor: 2},
        action: :set_recovery_floor,
        authorize?: false
      )

      assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
               NewYou.Repo.query("UPDATE accounts SET recovery_assurance_floor=1 WHERE id=$1", [
                 Ecto.UUID.dump!(registered.account_id)
               ])
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

  test "an unverified account enters durable hold and cannot create email verification" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registered} = Identity.register(request)
      :ok = Identity.request_recovery(request.email, "af", operation())
      {:ok, [held]} = cases(registered.account_id)
      assert held.state == :held_manual_review
      assert held.required_assurance == 2
      assert held.satisfied_assurance == 0
      assert is_nil(held.proof_jti)
      assert hold_obligation(held.operation_id).case_id == held.id
      after_account = Ash.get!(Account, registered.account_id, authorize?: false)
      refute after_account.email_verified?
      assert after_account.security_posture == :held

      assert Identity.authenticate_password(request.email, request.password) ==
               {:error, :authentication_unavailable}
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
      # Fixture-only representation of the P8-16 owner commit. This ticket adds
      # no email-change action or verification grant. The snapshot must go stale.
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

      refute Enum.any?(Ash.Resource.Info.actions(Account), fn action ->
               action.type == :update and :email in Map.get(action, :accept, [])
             end)
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
