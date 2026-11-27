defmodule NewYou.Privacy.FixtureDisputePurpose do
  @moduledoc false

  alias NewYou.Privacy.{FixtureDisputePurposeAuthority, FixtureDisputePurposeEvent}
  alias NewYou.Proof.PlanPaymentObservation
  require Ash.Query

  @purpose :commercial_dispute_evidence
  @origin :fp002_dispute_test_fixture

  @doc "Grant the exact TEST disclosure purpose once for a recipient, operation and dispute."
  def grant(subject_id, operation_id, dispute_id) do
    with {:ok, subject_id} <- uuid(subject_id),
         {:ok, operation_id} <- uuid(operation_id),
         {:ok, dispute_id} <- uuid(dispute_id),
         do: grant_transaction(subject_id, operation_id, dispute_id)
  rescue
    _ -> {:error, :privacy_authority_unavailable}
  catch
    _, _ -> {:error, :privacy_authority_unavailable}
  end

  defp grant_transaction(subject_id, operation_id, dispute_id) do
    case Ash.transact([FixtureDisputePurposeAuthority, FixtureDisputePurposeEvent], fn ->
           grant_locked(subject_id, operation_id, dispute_id)
         end) do
      {:ok, result} -> result
      {:error, :withdrawn} -> {:error, :withdrawn}
      {:error, _} -> resolve_grant_failure(subject_id, operation_id, dispute_id)
      _ -> {:error, :privacy_authority_unavailable}
    end
  end

  @doc "Withdraw the exact TEST disclosure purpose. Withdrawal is terminal."
  def withdraw(subject_id, operation_id, dispute_id) do
    with {:ok, subject_id} <- uuid(subject_id),
         {:ok, operation_id} <- uuid(operation_id),
         {:ok, dispute_id} <- uuid(dispute_id),
         {:ok, result} <-
           Ash.transact([FixtureDisputePurposeAuthority, FixtureDisputePurposeEvent], fn ->
             withdraw_locked(subject_id, operation_id, dispute_id)
           end) do
      result
    else
      _ -> {:error, :privacy_authority_unavailable}
    end
  rescue
    _ -> {:error, :privacy_authority_unavailable}
  catch
    _, _ -> {:error, :privacy_authority_unavailable}
  end

  @doc "Issue a signed proof only while the exact persisted owner purpose is currently allowed."
  def issue_proof(subject_id, operation_id, dispute_id) do
    with {:ok, subject_id} <- uuid(subject_id),
         {:ok, operation_id} <- uuid(operation_id),
         {:ok, dispute_id} <- uuid(dispute_id),
         {:ok, :allowed} <- current(subject_id, operation_id, dispute_id) do
      {:ok,
       PlanPaymentObservation.produce(%{
         scope: :fixture_dispute_privacy_purpose,
         purpose: @purpose,
         source_id: dispute_id,
         operation_id: operation_id,
         state: :allowed,
         subject_id: subject_id
       })}
    else
      {:ok, :withdrawn} -> {:error, :privacy_authority_denied}
      {:ok, :missing} -> {:error, :privacy_authority_denied}
      _ -> {:error, :privacy_authority_unavailable}
    end
  rescue
    _ -> {:error, :privacy_authority_unavailable}
  catch
    _, _ -> {:error, :privacy_authority_unavailable}
  end

  @doc false
  def require_current_locked(subject_id, operation_id, dispute_id) do
    with true <- Ash.DataLayer.in_transaction?(FixtureDisputePurposeAuthority),
         {:ok, subject_id} <- uuid(subject_id),
         {:ok, operation_id} <- uuid(operation_id),
         {:ok, dispute_id} <- uuid(dispute_id),
         {:ok, %{state: :allowed}} <-
           read_authority(subject_id, operation_id, dispute_id, lock?: true) do
      :ok
    else
      {:error, :privacy_authority_unavailable} = error -> error
      _ -> {:error, :privacy_authority_denied}
    end
  rescue
    _ -> {:error, :privacy_authority_unavailable}
  catch
    _, _ -> {:error, :privacy_authority_unavailable}
  end

  defp grant_locked(subject_id, operation_id, dispute_id) do
    case read_authority(subject_id, operation_id, dispute_id, lock?: true) do
      {:ok, nil} ->
        attrs = authority_attrs(subject_id, operation_id, dispute_id)

        with {:ok, authority} <-
               Ash.create(FixtureDisputePurposeAuthority, attrs,
                 action: :grant_fixture_only,
                 authorize?: false
               ),
             {:ok, _event} <- record_event(authority, :granted, 1) do
          {:ok, :allowed}
        end

      {:ok, %{state: :allowed}} ->
        {:ok, :already_allowed}

      {:ok, %{state: :withdrawn}} ->
        {:error, :withdrawn}

      _ ->
        {:error, :privacy_authority_unavailable}
    end
  end

  defp withdraw_locked(subject_id, operation_id, dispute_id) do
    case read_authority(subject_id, operation_id, dispute_id, lock?: true) do
      {:ok, %{state: :allowed} = authority} ->
        next_version = authority.version + 1

        with {:ok, withdrawn} <-
               Ash.update(authority, %{version: next_version},
                 action: :withdraw_fixture_only,
                 authorize?: false
               ),
             {:ok, _event} <- record_event(withdrawn, :withdrawn, next_version) do
          {:ok, :withdrawn}
        end

      {:ok, %{state: :withdrawn}} ->
        {:ok, :already_withdrawn}

      {:ok, nil} ->
        {:error, :missing}

      _ ->
        {:error, :privacy_authority_unavailable}
    end
  end

  defp record_event(authority, transition, version) do
    Ash.create(
      FixtureDisputePurposeEvent,
      %{
        authority_id: authority.id,
        subject_id: authority.subject_id,
        dispute_id: authority.dispute_id,
        source_operation_id: authority.source_operation_id,
        purpose: @purpose,
        transition: transition,
        origin: @origin,
        version: version
      },
      action: :record_fixture_transition,
      authorize?: false
    )
  end

  defp authority_attrs(subject_id, operation_id, dispute_id) do
    %{
      subject_id: subject_id,
      dispute_id: dispute_id,
      source_operation_id: operation_id,
      purpose: @purpose,
      state: :allowed,
      origin: @origin,
      version: 1
    }
  end

  defp current(subject_id, operation_id, dispute_id) do
    case read_authority(subject_id, operation_id, dispute_id) do
      {:ok, nil} -> {:ok, :missing}
      {:ok, %{state: state}} -> {:ok, state}
      _ -> {:error, :privacy_authority_unavailable}
    end
  end

  defp resolve_grant_failure(subject_id, operation_id, dispute_id) do
    case current(subject_id, operation_id, dispute_id) do
      {:ok, :allowed} -> {:ok, :already_allowed}
      {:ok, :withdrawn} -> {:error, :withdrawn}
      _ -> {:error, :privacy_authority_unavailable}
    end
  rescue
    _ -> {:error, :privacy_authority_unavailable}
  catch
    _, _ -> {:error, :privacy_authority_unavailable}
  end

  defp read_authority(subject_id, operation_id, dispute_id, opts \\ []) do
    query =
      FixtureDisputePurposeAuthority
      |> Ash.Query.filter(
        subject_id == ^subject_id and dispute_id == ^dispute_id and
          source_operation_id == ^operation_id and purpose == ^@purpose
      )

    query =
      if Keyword.get(opts, :lock?, false), do: Ash.Query.lock(query, :for_update), else: query

    Ash.read_one(query, authorize?: false)
  end

  defp uuid(value) do
    case Ecto.UUID.cast(value) do
      {:ok, cast} -> {:ok, cast}
      _ -> {:error, :invalid_id}
    end
  end
end
