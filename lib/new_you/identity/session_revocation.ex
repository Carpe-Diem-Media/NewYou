defmodule NewYou.Identity.SessionRevocation do
  @moduledoc false

  require Ash.Query

  alias NewYou.Identity.{DeviceAssurance, Session, Token}

  # The caller holds the Account lock and owns the surrounding transaction.
  # Account-locked issuance cannot add Sessions while this set is being ended.
  # The bang Ash calls raise on failure, leaving rollback to the caller.
  @spec revoke_sessions(Ecto.UUID.t()) :: :ok
  def revoke_sessions(id), do: revoke_sessions(id, lock_linked_tokens(id))

  # The token set is valid only while the caller keeps the Account locked.
  @spec lock_linked_tokens(Ecto.UUID.t()) :: %{optional(String.t()) => Token.t()}
  def lock_linked_tokens(id) do
    jtis =
      Session
      |> Ash.Query.filter(account_id == ^id and state == :active)
      |> Ash.Query.sort(:id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.token_jti)
      |> Enum.uniq()

    Token
    |> Ash.Query.filter(account_id == ^id and purpose == "user" and jti in ^jtis)
    |> Ash.Query.sort(:jti)
    |> Ash.Query.lock(:for_update)
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.jti, &1})
  end

  @spec revoke_sessions(Ecto.UUID.t(), %{optional(String.t()) => Token.t()}) :: :ok
  def revoke_sessions(id, linked_tokens) do
    # Account-level security writes lock related Token rows before Sessions.
    # Keep password reset aligned with primary-email apply and recovery.
    sessions =
      Session
      |> Ash.Query.filter(account_id == ^id and state == :active)
      |> Ash.Query.sort(:id)
      |> Ash.Query.lock(:for_update)
      |> Ash.read!(authorize?: false)

    Enum.each(sessions, fn session ->
      # Invalidate only linked authentication authority, never other purposes.
      case Map.get(linked_tokens, session.token_jti) do
        %Token{purpose: "user"} = linked ->
          Ash.update!(linked, %{}, action: :revoke_authentication, authorize?: false)

        _ ->
          :ok
      end

      Ash.update!(session, %{}, action: :revoke, authorize?: false)
    end)

    :ok
  end

  # Also requires the caller's Account lock and transaction.
  @spec revoke_devices(Ecto.UUID.t()) :: :ok
  def revoke_devices(id) do
    DeviceAssurance
    |> Ash.Query.filter(account_id == ^id and state == :trusted)
    |> Ash.Query.sort(:id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.update!(&1, %{}, action: :revoke, authorize?: false))

    :ok
  end
end
