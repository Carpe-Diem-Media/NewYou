defmodule NewYou.Temperament do
  @moduledoc """
  Temperament owns successful complete paid Assessment delivery provenance.
  S1 exposes an authoritative history read backed by bounded TEST fixtures.
  """

  use Ash.Domain, otp_app: :new_you

  alias NewYou.Temperament.AssessmentDeliveryEvidence

  require Ash.Query

  resources do
    resource AssessmentDeliveryEvidence
  end

  @doc """
  Review an Identity reconciliation pair for an empty Temperament scope. A
  recorded Assessment observation requires separately governed reconciliation.
  """
  @spec review_identity_reconciliation(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, map()} | {:error, :temperament_scope_unavailable}
  def review_identity_reconciliation(candidate_id, canonical_id)
      when candidate_id != canonical_id do
    query =
      Ash.Query.filter(AssessmentDeliveryEvidence, recipient_id in ^[candidate_id, canonical_id])

    case Ash.exists(query, authorize?: false) do
      {:ok, false} ->
        {:ok,
         %{
           "candidate_id" => candidate_id,
           "canonical_id" => canonical_id,
           "policy" => "empty_temperament_scope",
           "commands" => []
         }}

      _ ->
        {:error, :temperament_scope_unavailable}
    end
  end

  def review_identity_reconciliation(_, _), do: {:error, :temperament_scope_unavailable}

  @doc """
  Read the latest successful complete paid delivery for an established canonical
  recipient in the caller's owner transaction. `:none` requires explicit
  negative evidence. An unavailable result cannot authorize a purchase.
  """
  @spec latest_paid_assessment_delivery(Ecto.UUID.t()) ::
          {:ok, :none | DateTime.t()} | {:error, :delivery_evidence_unavailable}
  if Mix.env() == :test do
    def latest_paid_assessment_delivery(recipient_id) do
      with true <- Ash.DataLayer.in_transaction?(AssessmentDeliveryEvidence),
           {:ok, evidence} <-
             Ash.get(AssessmentDeliveryEvidence, recipient_id, authorize?: false, error?: false) do
        delivery_result(evidence)
      else
        _ -> {:error, :delivery_evidence_unavailable}
      end
    end

    defp delivery_result(%{status: :none}), do: {:ok, :none}

    defp delivery_result(%{status: :successful, successful_at: %DateTime{} = delivered_at}) do
      if DateTime.compare(delivered_at, DateTime.utc_now()) == :gt,
        do: {:error, :delivery_evidence_unavailable},
        else: {:ok, delivered_at}
    end

    defp delivery_result(_), do: {:error, :delivery_evidence_unavailable}
  else
    def latest_paid_assessment_delivery(_), do: {:error, :delivery_evidence_unavailable}
  end
end
