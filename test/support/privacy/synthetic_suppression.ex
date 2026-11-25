defmodule NewYou.Privacy.SyntheticSuppression do
  @moduledoc """
  Privacy owns the persisted TEST-only deletion fixture. A signed completed
  deletion is terminal. The row holds only an opaque subject ID and its status.
  """
  alias NewYou.Identity
  alias NewYou.Privacy.SyntheticDeletionScope
  alias NewYou.Proof.PlanPaymentObservation
  require Ash.Query

  @doc "Register an eligible synthetic subject. A replay cannot reset suppression."
  @spec register(map()) :: :ok | {:error, :suppression_unavailable}
  def register(credentials) do
    result =
      Ash.transact(SyntheticDeletionScope, fn ->
        with {:ok, %{account_id: id}} <- Identity.authorize_canonical_session(credentials),
             {:ok, record} <- locked_scope(id),
             {:ok, _} <- ensure_registered(record, id) do
          :ok
        end
      end)

    case result do
      {:ok, :ok} -> :ok
      _ -> {:error, :suppression_unavailable}
    end
  end

  @doc "Persist qualified synthetic completion and preserve it on every retry."
  @spec suppress(PlanPaymentObservation.t()) :: :ok | {:error, :suppression_unavailable}
  def suppress(observation) do
    with {:ok, %{scope: :completed_deletion, subject_id: id}} <-
           PlanPaymentObservation.verify(observation),
         {:ok, %SyntheticDeletionScope{suppressed?: true}} <-
           Ash.transact(SyntheticDeletionScope, fn -> suppress_locked(id) end) do
      :ok
    else
      _ -> {:error, :suppression_unavailable}
    end
  end

  @doc "Read current authority in the caller's transaction and retain the row lock until commit."
  @spec locked_status(String.t()) :: {:ok, :allowed | :suppressed | :missing} | {:error, term()}
  def locked_status(subject_id) do
    case locked_scope(subject_id) do
      {:ok, nil} -> {:ok, :missing}
      {:ok, %{suppressed?: true}} -> {:ok, :suppressed}
      {:ok, %{suppressed?: false}} -> {:ok, :allowed}
      {:error, _} = error -> error
    end
  end

  defp suppress_locked(id) do
    with {:ok, %SyntheticDeletionScope{} = record} <- locked_scope(id),
         {:ok, suppressed} <- Ash.update(record, %{}, action: :suppress, authorize?: false) do
      suppressed
    else
      _ -> {:error, :suppression_unavailable}
    end
  end

  defp locked_scope(subject_id) do
    SyntheticDeletionScope
    |> Ash.Query.filter(subject_id == ^subject_id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one(authorize?: false)
  end

  defp ensure_registered(nil, id),
    do:
      Ash.create(SyntheticDeletionScope, %{subject_id: id}, action: :register, authorize?: false)

  defp ensure_registered(record, _id), do: {:ok, record}
end
