defmodule NewYou.Audit.Actions.MaterializeRegistrationEvidence do
  @moduledoc """
  Materialises only Audit truth. The obligation row lock serializes every caller
  inside the Ash transaction, including direct action calls and duplicate jobs.
  An existing assertion is reused after interrupted fulfilment; Identity is
  never read or mutated by this executor.
  """
  use Ash.Resource.Actions.Implementation
  require Ash.Query

  defmacrop proof_checkpoint(point) do
    if Mix.env() == :test do
      quote do: NewYou.Proof.AuditSeam.checkpoint(unquote(point))
    else
      quote do: :ok
    end
  end

  @impl true
  def run(input, _opts, _context) do
    with {:ok, id} <- obligation_id(input.arguments.primary_key),
         :ok <- proof_checkpoint(:before_lock),
         {:ok, obligation} <- locked_obligation(id),
         {:ok, record} <- materialize_or_replay(obligation) do
      {:ok, %{obligation_id: obligation.id, evidence_record_id: record.id}}
    else
      {:error, error} -> {:error, error}
      _ -> {:error, :evidence_materialisation_unavailable}
    end
  end

  defp locked_obligation(id) do
    NewYou.Audit.EvidenceObligation
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one(domain: NewYou.Audit, authorize?: false)
  end

  defp materialize_or_replay(%NewYou.Audit.EvidenceObligation{state: :open} = obligation) do
    with {:ok, record} <- existing_or_create(obligation),
         :ok <- proof_checkpoint(:after_record),
         {:ok, _fulfilled} <-
           Ash.update(obligation, %{}, action: :fulfill, domain: NewYou.Audit, authorize?: false) do
      {:ok, record}
    end
  end

  defp materialize_or_replay(%NewYou.Audit.EvidenceObligation{state: :fulfilled} = obligation) do
    case NewYou.Audit.get_evidence_record_by_obligation(obligation.id, authorize?: false) do
      {:ok, %NewYou.Audit.EvidenceRecord{} = record} -> {:ok, record}
      _ -> {:error, :evidence_obligation_integrity_mismatch}
    end
  end

  defp materialize_or_replay(_), do: {:error, :evidence_materialisation_unavailable}

  defp existing_or_create(obligation) do
    case NewYou.Audit.get_evidence_record_by_obligation(obligation.id, authorize?: false) do
      {:ok, nil} ->
        Ash.create(NewYou.Audit.EvidenceRecord, %{obligation_id: obligation.id},
          action: :materialize,
          domain: NewYou.Audit,
          authorize?: false
        )

      {:ok, %NewYou.Audit.EvidenceRecord{} = record} ->
        {:ok, record}

      {:error, error} ->
        {:error, error}
    end
  end

  defp obligation_id(%{"id" => id}), do: Ecto.UUID.cast(id)
  defp obligation_id(%{id: id}), do: Ecto.UUID.cast(id)
  defp obligation_id(_), do: {:error, :evidence_materialisation_unavailable}
end
