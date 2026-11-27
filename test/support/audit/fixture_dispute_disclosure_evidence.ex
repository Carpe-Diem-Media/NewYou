defmodule NewYou.Audit.FixtureDisputeDisclosureEvidence do
  @moduledoc false

  alias NewYou.Audit.FixtureDisputeDisclosure
  require Ash.Query

  @field_set "commercial_dispute_v1"
  @unavailable {:error, :disclosure_unavailable}

  @doc false
  @spec record_in_transaction(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          :ok | {:error, :disclosure_unavailable}
  def record_in_transaction(operation_id, actor_id, dispute_id) do
    with true <- Ash.DataLayer.in_transaction?(FixtureDisputeDisclosure),
         {:ok, operation_id} <- uuid(operation_id),
         {:ok, actor_id} <- uuid(actor_id),
         {:ok, dispute_id} <- uuid(dispute_id),
         :ok <- record_exact(operation_id, actor_id, dispute_id) do
      :ok
    else
      _ -> @unavailable
    end
  rescue
    _ -> @unavailable
  catch
    _, _ -> @unavailable
  end

  defp record_exact(operation_id, actor_id, dispute_id) do
    attrs = %{
      operation_id: operation_id,
      actor_id: actor_id,
      dispute_id: dispute_id,
      purpose: :fixture_dispute_evidence_read,
      field_set: @field_set
    }

    query = Ash.Query.filter(FixtureDisputeDisclosure, operation_id == ^operation_id)

    case Ash.read_one(query, authorize?: false) do
      {:ok, nil} ->
        case Ash.create(FixtureDisputeDisclosure, attrs,
               action: :record_disclosure,
               authorize?: false
             ) do
          {:ok, _record} -> :ok
          _ -> @unavailable
        end

      {:ok, existing} ->
        if Map.take(existing, Map.keys(attrs)) == attrs, do: :ok, else: @unavailable

      _ ->
        @unavailable
    end
  end

  defp uuid(value) do
    case Ecto.UUID.cast(value) do
      {:ok, cast} -> {:ok, cast}
      _ -> {:error, :invalid_id}
    end
  end
end
