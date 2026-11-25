defmodule NewYou.Commerce.SyntheticCollectionLedger do
  @moduledoc false

  alias NewYou.Commerce.{SyntheticCollection, SyntheticExcessClaim}
  require Ash.Query

  @doc false
  @spec record(map(), map(), boolean()) :: {:ok, SyntheticCollection.t()} | {:error, term()}
  def record(source, fields, allow_initial?) do
    with %{payer_id: payer, recipient_id: recipient, price_version: version} <- fields,
         %{payer_id: ^payer, recipient_id: ^recipient, price_version: ^version} <- source,
         {:ok, id} <- Ecto.UUID.cast(Map.get(fields, :collection_id)),
         {:ok, _} <- Ecto.UUID.cast(Map.get(fields, :receipt_id)),
         {:ok, saved} <- Ash.get(SyntheticCollection, id, authorize?: false, error?: false),
         {:ok, original} <- accepted_collection(source.id) do
      persist(saved, id, source, original, allow_initial?)
    else
      _ -> {:error, :payment_unavailable}
    end
  end

  @doc false
  @spec accepted_collection(String.t()) :: {:ok, SyntheticCollection.t() | nil} | {:error, term()}
  def accepted_collection(source_id) do
    with {:ok, claim} <-
           Ash.get(SyntheticExcessClaim, source_id, authorize?: false, error?: false) do
      query = Ash.Query.filter(SyntheticCollection, source_id == ^source_id)
      Ash.read_one(exclude_excess(query, claim), authorize?: false)
    end
  end

  defp exclude_excess(query, nil), do: query

  defp exclude_excess(query, claim),
    do: Ash.Query.filter(query, collection_id != ^claim.collection_id)

  defp persist(
         %SyntheticCollection{source_id: id},
         _,
         %{id: id},
         %SyntheticCollection{} = original,
         _
       ),
       do: {:ok, original}

  defp persist(nil, collection_id, source, nil, true),
    do: create_collection(collection_id, source)

  defp persist(nil, collection_id, source, %SyntheticCollection{} = original, false) do
    with {:ok, _} <- create_collection(collection_id, source),
         {:ok, _} <-
           Ash.create(
             SyntheticExcessClaim,
             %{
               source_id: source.id,
               collection_id: collection_id,
               claimant_id: source.payer_id,
               amount_minor: source.amount_minor,
               currency: source.currency
             },
             action: :establish,
             authorize?: false
           ) do
      {:ok, original}
    end
  end

  defp persist(_, _, _, _, _), do: {:error, :payment_unavailable}

  defp create_collection(collection_id, source) do
    Ash.create(
      SyntheticCollection,
      %{collection_id: collection_id, source_id: source.id, amount_minor: source.amount_minor},
      action: :record,
      authorize?: false
    )
  end
end
