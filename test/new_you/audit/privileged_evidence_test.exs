defmodule NewYou.Audit.PrivilegedEvidenceTest do
  use ExUnit.Case, async: false

  alias NewYou.Audit
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    :ok = Sandbox.checkout(NewYou.Repo, sandbox: false)
    attempt_id = Ecto.UUID.generate()

    on_exit(fn ->
      Sandbox.unboxed_run(NewYou.Repo, fn ->
        NewYou.Repo.transaction(fn ->
          NewYou.Repo.query!(
            "ALTER TABLE evidence_records DISABLE TRIGGER evidence_records_immutable"
          )

          NewYou.Repo.query!("DELETE FROM evidence_records WHERE attempt_id = $1", [
            Ecto.UUID.dump!(attempt_id)
          ])

          NewYou.Repo.query!(
            "ALTER TABLE evidence_records ENABLE TRIGGER evidence_records_immutable"
          )
        end)
      end)
    end)

    %{envelope: envelope(attempt_id)}
  end

  test "E1 admission commits once and preserves the immutable attempt binding", %{envelope: e} do
    assert {:ok, first} = Audit.admit_security_hold_release(e)
    assert {:ok, retry} = Audit.admit_security_hold_release(e)
    assert first.id == retry.id
    assert first.assertion_kind == :admission
    assert first.action_class == :security_hold_release
    assert first.outcome == :admitted
    assert first.obligation_id == nil
    assert first.actor_id == e.actor_id
    assert first.target_id == e.target_id

    assert {:error, :evidence_admission_unavailable} =
             Audit.admit_security_hold_release(%{e | target_id: Ecto.UUID.generate()})

    assert {:ok, retained} = Ash.get(Audit.EvidenceRecord, first.id, authorize?: false)
    fields = Enum.map(Ash.Resource.Info.attributes(Audit.EvidenceRecord), & &1.name)
    assert Map.take(retained, fields) == Map.take(first, fields)
  end

  test "E1 rejects an outer transaction so a later rollback cannot erase admission", %{
    envelope: e
  } do
    assert {:ok, {:ok, :rejected}} =
             Ash.transact(Audit.EvidenceRecord, fn ->
               assert {:error, :evidence_admission_unavailable} =
                        Audit.admit_security_hold_release(e)

               {:ok, :rejected}
             end)
  end

  test "E1 accepts only its minimised envelope", %{envelope: e} do
    assert {:error, :evidence_admission_unavailable} =
             Audit.admit_security_hold_release(Map.put(e, :support_notes, "private"))

    assert {:error, :evidence_admission_unavailable} =
             Audit.admit_security_hold_release(%{e | reason_code: :arbitrary_reason})
  end

  test "a committed admission survives a failed independent source transaction", %{envelope: e} do
    assert {:ok, admission} = Audit.admit_security_hold_release(e)
    assert {:error, _} = Ash.transact(Audit.EvidenceRecord, fn -> {:error, :source_failed} end)
    assert %{id: id} = Ash.get!(Audit.EvidenceRecord, admission.id, authorize?: false)
    assert id == admission.id
  end

  defp envelope(attempt_id) do
    %{
      attempt_id: attempt_id,
      actor_id: Ecto.UUID.generate(),
      target_id: Ecto.UUID.generate(),
      grant_id: Ecto.UUID.generate(),
      grant_version: 1,
      session_id: Ecto.UUID.generate(),
      expected_version: 1,
      reason_code: :security_review
    }
  end
end
