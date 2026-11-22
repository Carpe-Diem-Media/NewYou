defmodule NewYou.Identity.ManualRecoveryTest do
  use ExUnit.Case, async: false
  require Ash.Query

  alias NewYou.Identity
  alias NewYou.Audit.{EvidenceObligation, EvidenceRecord}
  alias NewYou.Identity.{Account, RecoveryCase, Token}
  alias NewYou.Proof.P813HoldFixture

  test "approval rejects incomplete authority without changing recovery state" do
    assert {:error, :recovery_unavailable} = Identity.approve_manual_recovery(%{})
  end

  test "completion rejects incomplete authority without changing credentials" do
    assert {:error, :recovery_unavailable} = Identity.complete_manual_recovery(%{})
  end

  test "current scoped staff cannot turn zero claimant assurance into manual recovery" do
    P813HoldFixture.with_fixture(fn fixture ->
      NewYou.Repo.query!("UPDATE accounts SET \"email_verified?\"=false WHERE id=$1", [
        Ecto.UUID.dump!(fixture.target.id)
      ])

      before_account = Ash.get!(Account, fixture.target.id, authorize?: false)
      :ok = Identity.request_recovery(before_account.email, "en", operation())
      recovery = recovery_case(fixture.target.id)

      grant =
        P813HoldFixture.grant(
          fixture.reviewer,
          fixture.target,
          fixture.approver,
          :identity_recovery
        )

      assert {:ok, :ok} = P813HoldFixture.step_up(fixture.reviewer, :approve_manual_recovery)

      request = %{
        credentials: fixture.reviewer.credentials,
        grant_id: grant.id,
        case_id: recovery.id,
        expected_version: recovery.version,
        operation_id: operation(),
        reason_code: :verified_recovery
      }

      assert recovery.satisfied_assurance == 0
      assert is_nil(recovery.proof_jti)
      assert {:error, :recovery_unavailable} = Identity.approve_manual_recovery(request)

      assert {:error, :recovery_unavailable} =
               Identity.complete_manual_recovery(
                 Map.put(request, :password, "no claimant evidence")
               )

      assert is_nil(admission(request.operation_id))
      assert Ash.get!(Account, fixture.target.id, authorize?: false) == before_account
    end)
  end

  test "a distinct current scoped reviewer approves and a scoped actor completes once" do
    P813HoldFixture.with_fixture(fn fixture ->
      release_request = P813HoldFixture.reviewed_hold(fixture)
      target = Ash.get!(Account, fixture.target.id, authorize?: false)
      assert :ok = Identity.request_recovery(target.email, "en", operation())
      recovery = recovery_case(target.id)
      {:ok, bearer} = recovery_delivery(recovery, target.email)
      assert {:ok, :accepted} = Identity.submit_recovery_proof(bearer, operation())
      recovery = recovery_case(target.id)
      assert recovery.state == :held_manual_review
      assert recovery.satisfied_assurance == 1

      reviewer_grant =
        P813HoldFixture.grant(
          fixture.reviewer,
          fixture.target,
          fixture.approver,
          :identity_recovery
        )

      completer_grant =
        P813HoldFixture.grant(
          fixture.actor,
          fixture.target,
          fixture.approver,
          :identity_recovery
        )

      assert {:ok, :ok} = P813HoldFixture.step_up(fixture.reviewer, :approve_manual_recovery)

      review_operation = operation()

      review_request = %{
        credentials: fixture.reviewer.credentials,
        grant_id: reviewer_grant.id,
        case_id: recovery.id,
        expected_version: recovery.version,
        operation_id: review_operation,
        reason_code: :verified_recovery
      }

      wrong_scope_request = %{review_request | grant_id: fixture.grants.review.id}

      assert {:error, :recovery_unavailable} =
               Identity.approve_manual_recovery(wrong_scope_request)

      approval_failure = %{review_request | operation_id: operation()}

      Process.put(NewYou.Proof.AuditSeam, fn :before_admission ->
        raise "approval admission cut"
      end)

      assert {:error, :recovery_unavailable} =
               Identity.approve_manual_recovery(approval_failure)

      Process.delete(NewYou.Proof.AuditSeam)
      refute admission(approval_failure.operation_id)
      assert recovery_case(target.id).version == recovery.version

      source_review_failure = %{review_request | operation_id: operation()}

      Process.put(
        NewYou.Proof.RegistrationSeam,
        {:observe, fn -> raise "approval source cut" end}
      )

      assert {:error, :recovery_unavailable} =
               Identity.approve_manual_recovery(source_review_failure)

      Process.delete(NewYou.Proof.RegistrationSeam)

      assert %EvidenceRecord{id: failed_review_admission} =
               admission(source_review_failure.operation_id)

      assert %EvidenceObligation{outcome: :failed, admission_id: ^failed_review_admission} =
               outcome(source_review_failure.operation_id)

      assert recovery_case(target.id).version == recovery.version

      assert {:error, :recovery_unavailable} =
               Identity.approve_manual_recovery(source_review_failure)

      assert {:ok, %{status: :approved, version: reviewed_version}} =
               after_process_loss(review_request, :approve_manual_recovery)

      assert %EvidenceRecord{id: approval_admission_id} = admission(review_operation)

      assert %EvidenceObligation{
               evidence_type: :identity_recovery_review,
               outcome: :succeeded,
               admission_id: ^approval_admission_id
             } = outcome(review_operation)

      assert {:ok, %{status: :approved, version: ^reviewed_version}} =
               Identity.approve_manual_recovery(review_request)

      assert reviewed_version == recovery.version + 1
      assert {:ok, reviewed} = Ash.get(RecoveryCase, recovery.id, authorize?: false)
      assert reviewed.review["reviewer_id"] == fixture.reviewer.id
      assert reviewed.review["case_version"] == reviewed.version
      assert is_nil(reviewed.review["bearer"])

      reviewer_account = Ash.get!(Account, fixture.reviewer.id, authorize?: false)

      {:ok, same_actor_credentials} =
        Identity.authenticate_password(reviewer_account.email, fixture.reviewer.password)

      same_actor = %{fixture.reviewer | credentials: same_actor_credentials}
      assert {:ok, :ok} = P813HoldFixture.step_up(same_actor, :complete_manual_recovery)

      same_actor_request = %{
        credentials: same_actor.credentials,
        grant_id: reviewer_grant.id,
        case_id: recovery.id,
        expected_version: reviewed.version,
        operation_id: operation(),
        reason_code: :verified_recovery,
        password: "must not self approve"
      }

      assert {:error, :recovery_unavailable} =
               Identity.complete_manual_recovery(same_actor_request)

      assert {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :complete_manual_recovery)
      completion_operation = operation()

      request = %{
        credentials: fixture.actor.credentials,
        grant_id: completer_grant.id,
        case_id: recovery.id,
        expected_version: reviewed.version,
        operation_id: completion_operation,
        reason_code: :verified_recovery,
        password: "new manual recovery credential"
      }

      before_failure = Ash.get!(Account, fixture.target.id, authorize?: false)
      admission_failure = %{request | operation_id: operation()}
      Process.put(NewYou.Proof.AuditSeam, fn :before_admission -> raise "admission cut" end)

      assert {:error, :recovery_unavailable} =
               Identity.complete_manual_recovery(admission_failure)

      Process.delete(NewYou.Proof.AuditSeam)
      refute admission(admission_failure.operation_id)

      assert Ash.get!(Account, fixture.target.id, authorize?: false).credential_version ==
               before_failure.credential_version

      source_failure = %{request | operation_id: operation()}

      Process.put(
        NewYou.Proof.RegistrationSeam,
        {:observe, fn -> raise "source transaction cut" end}
      )

      assert {:error, :recovery_unavailable} = Identity.complete_manual_recovery(source_failure)
      Process.delete(NewYou.Proof.RegistrationSeam)

      assert %EvidenceRecord{} = admission(source_failure.operation_id)

      assert %EvidenceObligation{outcome: :failed, admission_id: admission_id} =
               outcome(source_failure.operation_id)

      assert admission_id == admission(source_failure.operation_id).id
      assert recovery_case(target.id).state == :held_manual_review

      assert Ash.get!(Account, fixture.target.id, authorize?: false).credential_version ==
               before_failure.credential_version

      assert {:error, :recovery_unavailable} = Identity.complete_manual_recovery(source_failure)
      assert %EvidenceObligation{outcome: :failed} = outcome(source_failure.operation_id)

      # Synthetic fixture expiry changes no accepted assurance. Fresh scoped
      # staff authority and the case deadline still govern manual completion.
      NewYou.Repo.query!("UPDATE tokens SET expires_at=$1 WHERE jti=$2", [
        DateTime.add(DateTime.utc_now(), -1),
        recovery.proof_jti
      ])

      assert DateTime.compare(
               Ash.get!(Token, recovery.proof_jti, authorize?: false).expires_at,
               DateTime.utc_now()
             ) == :lt

      assert {:ok, :completed} = after_process_loss(request, :complete_manual_recovery)

      assert {:ok, :already_completed} =
               Identity.complete_manual_recovery(%{
                 request
                 | password: "ignored replay credential"
               })

      assert {:error, :recovery_unavailable} =
               Identity.complete_manual_recovery(%{request | operation_id: operation()})

      assert Ash.get!(Account, fixture.target.id, authorize?: false).credential_version ==
               target.credential_version + 1

      assert Ash.get!(Account, fixture.target.id, authorize?: false).security_posture == :held

      assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
               NewYou.Repo.query("UPDATE accounts SET email=$1 WHERE id=$2", [
                 "forbidden-" <> Ecto.UUID.generate() <> "@example.test",
                 Ecto.UUID.dump!(fixture.target.id)
               ])

      assert {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :release_security_hold)
      assert {:ok, %{status: :released}} = Identity.release_security_hold(release_request)
      assert :ok = Identity.request_recovery(target.email, "en", operation())

      next_case =
        RecoveryCase
        |> Ash.Query.filter(account_id == ^target.id and state == :proof_pending)
        |> Ash.read_one!(authorize?: false)

      assert next_case.id != recovery.id
      assert next_case.required_assurance == 1
    end)
  end

  test "current historical operators cannot approve or complete a held Phase-9 case" do
    P813HoldFixture.with_fixture(fn fixture ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      P813HoldFixture.reviewed_hold(fixture)
      target = Ash.get!(Account, fixture.target.id, authorize?: false)

      historical = held_recovery(target, :p8_15, :accepted)
      review = operator_request(fixture, :reviewer, :approve_manual_recovery, historical)

      assert {:ok, %{status: :approved, version: reviewed_version}} =
               Identity.approve_manual_recovery(review)

      historical = recovery_case(target.id)
      assert historical.version == reviewed_version

      completion =
        fixture
        |> operator_request(:actor, :complete_manual_recovery, historical)
        |> Map.put(:password, "historical operator replacement credential")

      assert {:ok, :completed} = Identity.complete_manual_recovery(completion)

      ordinary = held_recovery(target, :well183, :held)
      account = Ash.get!(Account, target.id, authorize?: false)
      assert account.credential_version == target.credential_version + 1
      assert account.hold_version == historical.review["hold_version"]
      assert ordinary.required_assurance == 2
      assert Identity.Recovery.current?(ordinary, account)

      approval = %{
        review
        | case_id: ordinary.id,
          expected_version: ordinary.version,
          operation_id: operation()
      }

      assert {:error, :recovery_unavailable} = Identity.approve_manual_recovery(approval)
      refute admission(approval.operation_id)
      refute outcome(approval.operation_id)
      assert Ash.get!(RecoveryCase, ordinary.id, authorize?: false) == ordinary

      # Give completion a current review from the same reviewer and target.
      # The private fixture write bypasses approval only to reach the separate
      # completion guard with valid historical authority and accepted proof.
      review_record = Map.put(historical.review, "case_version", ordinary.version + 1)

      assert {:ok, seeded} =
               Identity.Recovery.transition(ordinary, :record_review, %{review: review_record})

      seeded = Ash.get!(RecoveryCase, seeded.id, authorize?: false)
      assert seeded.review == review_record

      denied = %{
        completion
        | case_id: seeded.id,
          expected_version: seeded.version,
          operation_id: operation(),
          password: "forbidden Phase-9 operator replacement"
      }

      token = Ash.get!(Token, seeded.proof_jti, authorize?: false)
      assert token.purpose == "recovery_consumed"
      assert {:error, :recovery_unavailable} = Identity.complete_manual_recovery(denied)
      refute admission(denied.operation_id)
      refute outcome(denied.operation_id)
      assert NewYou.Proof.P805.intents(denied.operation_id) == []
      assert Ash.get!(RecoveryCase, seeded.id, authorize?: false) == seeded
      assert Ash.get!(Token, seeded.proof_jti, authorize?: false) == token
      assert Ash.get!(Account, target.id, authorize?: false) == account
    end)
  end

  defp held_recovery(target, context, proof_outcome) do
    id = operation()
    assert :ok = Identity.request_recovery(target.email, "en", id, context)

    recovery =
      Ash.read_one!(Ash.Query.filter(RecoveryCase, operation_id == ^id), authorize?: false)

    assert {:ok, bearer} = recovery_delivery(recovery, target.email)

    assert {:ok, ^proof_outcome} =
             Identity.submit_recovery_proof(bearer, operation(), "en", context)

    assert %{state: :held_manual_review, entry_context: ^context, satisfied_assurance: 1} =
             Ash.get!(RecoveryCase, recovery.id, authorize?: false)
  end

  defp operator_request(fixture, role, purpose, recovery) do
    operator = Map.fetch!(fixture, role)
    grant = P813HoldFixture.grant(operator, fixture.target, fixture.approver, :identity_recovery)
    assert {:ok, :ok} = P813HoldFixture.step_up(operator, purpose)

    %{
      credentials: operator.credentials,
      grant_id: grant.id,
      case_id: recovery.id,
      expected_version: recovery.version,
      operation_id: operation(),
      reason_code: :verified_recovery
    }
  end

  defp after_process_loss(request, action) do
    alias NewYou.Proof.{Scenario, CutPoints, RegistrationSeam}
    alias Ecto.Adapters.SQL.Sandbox
    scenario = Scenario.start()
    :ok = CutPoints.arm(scenario, "transaction.before_commit", :manual_completion, :terminate)

    try do
      {worker, monitor} =
        Scenario.spawn(scenario, :manual_completion, fn ->
          :ok = Sandbox.checkout(NewYou.Repo, sandbox: false)

          Process.put(
            RegistrationSeam,
            {:observe,
             fn -> CutPoints.hit(scenario, "transaction.before_commit", :manual_completion) end}
          )

          try do
            apply(Identity, action, [request])
          after
            Sandbox.checkin(NewYou.Repo)
          end
        end)

      receive do
        {:DOWN, ^monitor, :process, ^worker, :proof_terminated} -> :ok
      after
        15_000 -> flunk("manual recovery worker termination deadline")
      end

      assert CutPoints.verify_consumed(scenario) == :ok
      assert %EvidenceRecord{} = admission(request.operation_id)
      assert is_nil(outcome(request.operation_id))

      assert Ash.get!(RecoveryCase, request.case_id, authorize?: false).state ==
               :held_manual_review

      assert {:ok, _} = result = apply(Identity, action, [request])
      assert %EvidenceObligation{outcome: :succeeded} = outcome(request.operation_id)
      result
    after
      Scenario.stop(scenario)
    end
  end

  defp operation do
    id = Ecto.UUID.generate()
    NewYou.Proof.P805.track_operation(id)
    id
  end

  defp recovery_case(account_id) do
    RecoveryCase
    |> Ash.Query.filter(account_id == ^account_id)
    |> Ash.read_one!(authorize?: false)
  end

  defp recovery_delivery(recovery, destination) do
    Ash.transact([Account, Token], fn ->
      Identity.recovery_delivery(recovery.proof_jti, destination, recovery.locale)
    end)
    |> case do
      {:ok, result} -> result
      error -> error
    end
  end

  defp admission(operation_id) do
    EvidenceRecord
    |> Ash.Query.filter(attempt_id == ^operation_id and assertion_kind == :admission)
    |> Ash.read_one!(authorize?: false)
    |> then(fn result -> result end)
  end

  defp outcome(operation_id) do
    EvidenceObligation
    |> Ash.Query.filter(source_operation_id == ^operation_id)
    |> Ash.read_one!(authorize?: false)
  end
end
