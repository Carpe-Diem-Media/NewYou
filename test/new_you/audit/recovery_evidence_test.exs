defmodule NewYou.Audit.RecoveryEvidenceTest do
  use ExUnit.Case, async: false

  alias NewYou.Audit
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    :ok = Sandbox.checkout(NewYou.Repo, sandbox: false)
    attempt_id = Ecto.UUID.generate()
    operation_ids = [Ecto.UUID.generate(), Ecto.UUID.generate()]

    on_exit(fn ->
      Sandbox.unboxed_run(NewYou.Repo, fn ->
        NewYou.Repo.transaction(fn ->
          NewYou.Repo.query!(
            "ALTER TABLE evidence_records DISABLE TRIGGER evidence_records_immutable"
          )

          NewYou.Repo.query!(
            "ALTER TABLE evidence_obligations DISABLE TRIGGER evidence_obligations_no_delete"
          )

          NewYou.Repo.query!("DELETE FROM evidence_records WHERE attempt_id = $1", [
            Ecto.UUID.dump!(attempt_id)
          ])

          NewYou.Repo.query!(
            "DELETE FROM evidence_obligations WHERE source_operation_id = ANY($1)",
            [Enum.map(operation_ids, &Ecto.UUID.dump!/1)]
          )

          NewYou.Repo.query!(
            "ALTER TABLE evidence_obligations ENABLE TRIGGER evidence_obligations_no_delete"
          )

          NewYou.Repo.query!(
            "ALTER TABLE evidence_records ENABLE TRIGGER evidence_records_immutable"
          )
        end)
      end)
    end)

    %{attempt_id: attempt_id, operation_ids: operation_ids}
  end

  test "recovery E1 binds an immutable admission to its case without reconciliation grants", %{
    attempt_id: attempt_id
  } do
    envelope = recovery_admission(attempt_id)

    assert {:ok, first} = Audit.admit_recovery(envelope)
    assert {:ok, retry} = Audit.admit_recovery(envelope)
    assert first.id == retry.id
    assert first.assertion_kind == :admission
    assert first.action_class == :identity_recovery
    assert first.case_id == envelope.case_id
    assert is_nil(first.canonical_grant_id)
    assert is_nil(first.canonical_grant_version)

    assert {:error, :evidence_admission_unavailable} =
             Audit.admit_recovery(%{envelope | case_id: Ecto.UUID.generate()})

    assert {:error, :evidence_admission_unavailable} =
             Audit.admit_recovery(Map.put(envelope, :canonical_grant_id, Ecto.UUID.generate()))

    assert {:error, :evidence_admission_unavailable} =
             Audit.admit_recovery(Map.put(envelope, :credential, "secret"))
  end

  test "recovery E2 outcome binds completion and review evidence to the recovery case", %{
    operation_ids: [completion_id, review_id]
  } do
    case_id = Ecto.UUID.generate()

    for {operation_id, evidence_type} <- [
          {completion_id, :identity_recovery_completed},
          {review_id, :identity_recovery_review}
        ] do
      envelope = %{
        source_operation_id: operation_id,
        source_occurred_at: DateTime.utc_now(),
        evidence_type: evidence_type,
        actor_id: Ecto.UUID.generate(),
        target_id: Ecto.UUID.generate(),
        case_id: case_id,
        outcome: :succeeded
      }

      assert {:ok, {:ok, obligation}} =
               Ash.transact(Audit.EvidenceObligation, fn ->
                 Audit.establish_identity_security_obligation(envelope)
               end)

      assert obligation.evidence_type == evidence_type
      assert obligation.case_id == case_id
    end
  end

  test "recovery outcomes require case binding and reject recovery credentials", %{
    operation_ids: [operation_id, _]
  } do
    envelope = %{
      source_operation_id: operation_id,
      source_occurred_at: DateTime.utc_now(),
      evidence_type: :identity_recovery_completed,
      actor_id: Ecto.UUID.generate(),
      target_id: Ecto.UUID.generate(),
      case_id: Ecto.UUID.generate(),
      outcome: :succeeded
    }

    assert {:error, :evidence_outcome_unavailable} =
             Audit.establish_identity_security_obligation(Map.delete(envelope, :case_id))

    assert {:error, :evidence_outcome_unavailable} =
             Audit.establish_identity_security_obligation(Map.put(envelope, :proof_jti, "secret"))
  end

  defp recovery_admission(attempt_id) do
    %{
      attempt_id: attempt_id,
      actor_id: Ecto.UUID.generate(),
      target_id: Ecto.UUID.generate(),
      grant_id: Ecto.UUID.generate(),
      grant_version: 1,
      session_id: Ecto.UUID.generate(),
      expected_version: 0,
      reason_code: :verified_recovery,
      case_id: Ecto.UUID.generate()
    }
  end
end
