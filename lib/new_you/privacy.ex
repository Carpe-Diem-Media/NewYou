defmodule NewYou.Privacy do
  @moduledoc """
  Privacy & Consent owns purpose-specific permission and withdrawal truth.

  The P8-17 purpose is a development/test proof fixture only. It is not
  participant consent or a production requirement for primary-email change.
  """
  use Ash.Domain, otp_app: :new_you

  require Ash.Query

  alias NewYou.Privacy.{PurposeAuthority, PurposeEvent}

  @proof_purpose :p8_17_protected_mutation
  @proof_origin :p8_17_test_fixture

  resources do
    resource PurposeAuthority
    resource PurposeEvent
  end

  @doc false
  def proof_purpose, do: @proof_purpose

  if Mix.env() in [:dev, :test] do
    @doc "Create one operation-bound P8-17 proof purpose. This is not production consent."
    def grant_p817_proof_purpose(subject_id, operation_id) do
      with {:ok, subject_id} <- Ecto.UUID.cast(subject_id),
           {:ok, operation_id} <- Ecto.UUID.cast(operation_id) do
        transaction_result =
          Ash.transact([PurposeAuthority, PurposeEvent], fn ->
            grant_locked(subject_id, operation_id)
          end)

        case transaction_result do
          {:ok, {:ok, :withdrawn}} -> {:error, :withdrawn}
          {:ok, {:ok, result}} -> {:ok, result}
          _ -> resolve_grant_failure(subject_id, operation_id)
        end
      else
        _ -> {:error, :privacy_authority_unavailable}
      end
    rescue
      _ -> resolve_grant_failure(subject_id, operation_id)
    catch
      _, _ -> resolve_grant_failure(subject_id, operation_id)
    end

    @doc "Withdraw one operation-bound P8-17 proof purpose. Withdrawal is terminal for this operation."
    def withdraw_p817_proof_purpose(subject_id, operation_id) do
      with {:ok, subject_id} <- Ecto.UUID.cast(subject_id),
           {:ok, operation_id} <- Ecto.UUID.cast(operation_id),
           {:ok, result} <-
             Ash.transact([PurposeAuthority, PurposeEvent], fn ->
               withdraw_locked(subject_id, operation_id)
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
  else
    @doc false
    def grant_p817_proof_purpose(_, _), do: {:error, :privacy_authority_unavailable}

    @doc false
    def withdraw_p817_proof_purpose(_, _), do: {:error, :privacy_authority_unavailable}
  end

  if Mix.env() in [:dev, :test] do
    @doc false
    def current_p817_proof_purpose(subject_id, operation_id) do
      with {:ok, subject_id} <- Ecto.UUID.cast(subject_id),
           {:ok, operation_id} <- Ecto.UUID.cast(operation_id),
           {:ok, record} <- current_record(subject_id, operation_id) do
        case record do
          nil -> {:ok, :missing}
          %{state: :allowed} -> {:ok, :allowed}
          %{state: :withdrawn} -> {:ok, :withdrawn}
        end
      else
        _ -> {:error, :privacy_authority_unavailable}
      end
    rescue
      _ -> {:error, :privacy_authority_unavailable}
    catch
      _, _ -> {:error, :privacy_authority_unavailable}
    end

    @doc false
    def require_current_p817_proof_purpose_locked(subject_id, operation_id) do
      with :ok <- owner_read_checkpoint(),
           true <- Ash.DataLayer.in_transaction?(PurposeAuthority),
           {:ok, subject_id} <- Ecto.UUID.cast(subject_id),
           {:ok, operation_id} <- Ecto.UUID.cast(operation_id),
           {:ok, record} <- current_record(subject_id, operation_id, lock?: true),
           %{state: :allowed} <- record do
        :ok
      else
        {:error, :privacy_authority_unavailable} ->
          {:error, :privacy_authority_unavailable}

        _ ->
          {:error, :privacy_authority_denied}
      end
    rescue
      _ -> {:error, :privacy_authority_unavailable}
    catch
      _, _ -> {:error, :privacy_authority_unavailable}
    end
  else
    def current_p817_proof_purpose(_, _), do: {:error, :privacy_authority_unavailable}

    def require_current_p817_proof_purpose_locked(_, _),
      do: {:error, :privacy_authority_unavailable}
  end

  defp grant_locked(subject_id, operation_id) do
    case current_record(subject_id, operation_id, lock?: true) do
      {:ok, nil} ->
        with :ok <- grant_missing_checkpoint(),
             {:ok, authority} <-
               Ash.create(
                 PurposeAuthority,
                 %{
                   subject_id: subject_id,
                   source_operation_id: operation_id,
                   purpose: @proof_purpose,
                   state: :allowed,
                   origin: @proof_origin,
                   version: 1
                 },
                 action: :grant_proof_only,
                 authorize?: false
               ),
             {:ok, _event} <- record_event(authority, :granted, 1) do
          {:ok, :allowed}
        end

      {:ok, %{state: :allowed}} ->
        {:ok, :already_allowed}

      {:ok, %{state: :withdrawn}} ->
        {:ok, :withdrawn}

      _ ->
        {:error, :privacy_authority_unavailable}
    end
  end

  defp resolve_grant_failure(subject_id, operation_id) do
    case current_record(subject_id, operation_id) do
      {:ok, %{state: :allowed}} -> {:ok, :already_allowed}
      {:ok, %{state: :withdrawn}} -> {:error, :withdrawn}
      _ -> {:error, :privacy_authority_unavailable}
    end
  rescue
    _ -> {:error, :privacy_authority_unavailable}
  catch
    _, _ -> {:error, :privacy_authority_unavailable}
  end

  defp withdraw_locked(subject_id, operation_id) do
    case current_record(subject_id, operation_id, lock?: true) do
      {:ok, %{state: :allowed} = authority} ->
        next_version = authority.version + 1

        with {:ok, withdrawn} <-
               Ash.update(
                 authority,
                 %{version: next_version},
                 action: :withdraw_proof_only,
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
      PurposeEvent,
      %{
        authority_id: authority.id,
        subject_id: authority.subject_id,
        source_operation_id: authority.source_operation_id,
        purpose: @proof_purpose,
        transition: transition,
        origin: @proof_origin,
        version: version
      },
      action: :record_transition,
      authorize?: false
    )
  end

  defp current_record(subject_id, operation_id, opts \\ []) do
    query =
      PurposeAuthority
      |> Ash.Query.filter(
        subject_id == ^subject_id and purpose == ^@proof_purpose and
          source_operation_id == ^operation_id
      )

    query =
      if Keyword.get(opts, :lock?, false), do: Ash.Query.lock(query, :for_update), else: query

    Ash.read_one(query, authorize?: false)
  end

  if Mix.env() == :test do
    defp owner_read_checkpoint, do: NewYou.Proof.P817PrivacySeam.checkpoint(:owner_read)

    defp grant_missing_checkpoint,
      do: NewYou.Proof.P817PrivacySeam.checkpoint(:grant_after_missing)
  else
    defp owner_read_checkpoint, do: :ok
    defp grant_missing_checkpoint, do: :ok
  end
end
