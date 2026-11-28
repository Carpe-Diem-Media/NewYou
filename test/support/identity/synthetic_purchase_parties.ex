defmodule NewYou.Identity.SyntheticPurchaseParties do
  @moduledoc false

  alias NewYou.Identity
  alias NewYou.Proof.PlanPaymentObservation

  @doc false
  @spec authorize(map()) :: {:ok, map()} | {:error, :purchase_unavailable}
  def authorize(%{payer: payer, recipient: recipient, authorization: evidence}) do
    with {:ok,
          %{
            scope: :s1_purchase_parties,
            operation_id: op,
            payer_id: payer_id,
            recipient_id: recipient_id
          }} <-
           PlanPaymentObservation.verify(evidence),
         {:ok, ^op} <- Ecto.UUID.cast(op),
         true <- authorize_sessions([{payer_id, payer}, {recipient_id, recipient}]) do
      {:ok, %{operation_id: op, payer_id: payer_id, recipient_id: recipient_id}}
    else
      _ -> {:error, :purchase_unavailable}
    end
  end

  def authorize(_), do: {:error, :purchase_unavailable}

  defp authorize_sessions(parties) do
    parties
    |> Enum.uniq()
    |> Enum.sort_by(fn {id, _credentials} -> id end)
    |> Enum.all?(fn {id, credentials} ->
      match?({:ok, %{account_id: ^id}}, Identity.authorize_canonical_session(credentials))
    end)
  end
end
