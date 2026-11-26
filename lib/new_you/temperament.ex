defmodule NewYou.Temperament do
  @moduledoc """
  Temperament owns successful complete paid Assessment delivery provenance.
  S1 exposes an authoritative history read backed by bounded TEST fixtures.
  """

  use Ash.Domain, otp_app: :new_you

  alias NewYou.Temperament.AssessmentDeliveryEvidence

  resources do
    resource AssessmentDeliveryEvidence
  end

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
