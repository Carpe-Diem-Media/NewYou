defmodule NewYou.Audit do
  @moduledoc "Audit owns append-only admission and outcome assertions, never Identity authority or source replay."
  @doc "Confirm the fixed append-only provenance policy for existing Audit records. No history is remapped; this does not inspect individual records."
  @spec review_identity_reconciliation(String.t(), String.t()) :: {:ok, map()}
  def review_identity_reconciliation(candidate_id, canonical_id) do
    {:ok,
     %{
       "policy" => "preserve_immutable_provenance",
       "candidate_id" => candidate_id,
       "canonical_id" => canonical_id,
       "commands" => []
     }}
  end

  use Ash.Domain, otp_app: :new_you

  resources do
    resource NewYou.Audit.EvidenceObligation do
      define :establish_registration_obligation, action: :establish_registration
      define :get_evidence_obligation, action: :read, get_by: [:id]

      define :materialize_registration_evidence, action: :materialize_registration_evidence
    end

    resource NewYou.Audit.EvidenceRecord do
      define :get_evidence_record_by_obligation,
        action: :read,
        get_by: [:obligation_id],
        not_found_error?: false
    end
  end

  @doc "Commit or replay the same minimised E1 attempt before the caller opens its protected source transaction."
  @spec admit_security_hold_release(map()) ::
          {:ok, NewYou.Audit.EvidenceRecord.t()} | {:error, :evidence_admission_unavailable}
  defdelegate admit_security_hold_release(envelope),
    to: NewYou.Audit.PrivilegedEvidence,
    as: :admit

  @doc "Commit a case-bound reconciliation E1 attempt independently of Identity apply."
  @spec admit_reconciliation(map()) ::
          {:ok, NewYou.Audit.EvidenceRecord.t()} | {:error, :evidence_admission_unavailable}
  def admit_reconciliation(envelope),
    do: NewYou.Audit.PrivilegedEvidence.admit(envelope, :identity_reconciliation)

  @doc "Commit a case-bound recovery E1 attempt independently of Identity recovery completion."
  @spec admit_recovery(map()) ::
          {:ok, NewYou.Audit.EvidenceRecord.t()} | {:error, :evidence_admission_unavailable}
  def admit_recovery(envelope),
    do: NewYou.Audit.PrivilegedEvidence.admit(envelope, :identity_recovery)

  @doc "Establish selected security E2 work inside the owning source transaction. Executor recovery never calls Identity."
  @spec establish_identity_security_obligation(map()) ::
          {:ok, NewYou.Audit.EvidenceObligation.t()} | {:error, term()}
  defdelegate establish_identity_security_obligation(envelope),
    to: NewYou.Audit.PrivilegedEvidence,
    as: :establish_outcome
end
