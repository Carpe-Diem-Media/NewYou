defmodule NewYou.Temperament.SyntheticAssessmentDelivery do
  @moduledoc false

  alias NewYou.Privacy.SyntheticSuppression
  alias NewYou.Proof.PlanPaymentObservation
  alias NewYou.Temperament.AssessmentDeliveryEvidence

  @doc false
  @spec establish(PlanPaymentObservation.t()) ::
          {:ok, AssessmentDeliveryEvidence.t()} | {:error, :delivery_evidence_unavailable}
  def establish(observation) do
    with {:ok,
          %{scope: :s1_delivery_evidence, recipient_id: id, prior_evidence_id: expected} = fields} <-
           PlanPaymentObservation.verify(observation),
         attrs = Map.take(fields, [:recipient_id, :evidence_id, :status, :successful_at]),
         {:ok, %AssessmentDeliveryEvidence{} = evidence} <-
           Ash.transact(AssessmentDeliveryEvidence, fn ->
             establish_current(id, expected, attrs)
           end) do
      {:ok, evidence}
    else
      _ -> {:error, :delivery_evidence_unavailable}
    end
  end

  defp establish_current(id, expected, attrs) do
    with {:ok, :allowed} <- SyntheticSuppression.locked_status(id),
         {:ok, current} <-
           Ash.get(AssessmentDeliveryEvidence, id, authorize?: false, error?: false) do
      write(current, expected, attrs)
    else
      _ -> {:error, :delivery_evidence_unavailable}
    end
  end

  defp write(nil, nil, attrs) do
    with {:ok, saved} <-
           Ash.create(AssessmentDeliveryEvidence, attrs,
             action: :establish_fixture,
             authorize?: false
           ),
         do: saved
  end

  defp write(%{evidence_id: prior} = current, expected, %{evidence_id: proposed} = attrs) do
    cond do
      prior == proposed and Map.take(current, Map.keys(attrs)) == attrs ->
        current

      prior == expected and prior != proposed and advances_history?(current, attrs) ->
        with {:ok, saved} <-
               Ash.update(current, Map.delete(attrs, :recipient_id),
                 action: :observe_fixture,
                 authorize?: false
               ),
             do: saved

      true ->
        {:error, :delivery_evidence_unavailable}
    end
  end

  defp write(_, _, _), do: {:error, :delivery_evidence_unavailable}

  defp advances_history?(%{status: :successful, successful_at: prior}, %{
         status: :successful,
         successful_at: %DateTime{} = proposed
       }),
       do: DateTime.compare(proposed, prior) != :lt

  defp advances_history?(%{status: :successful}, _), do: false
  defp advances_history?(_, _), do: true
end
