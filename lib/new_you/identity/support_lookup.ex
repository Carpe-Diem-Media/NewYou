defmodule NewYou.Identity.SupportLookup do
  @moduledoc false

  alias NewYou.Identity.{Account, IdentityGrant, PrivilegedAccess, Session, Token}

  @transaction_resources [Account, Token, Session, IdentityGrant]

  @doc false
  def lookup(credentials, grant_id, target_account_id, email) do
    with {:ok, grant_id} <- Ecto.UUID.cast(grant_id),
         {:ok, target_account_id} <- Ecto.UUID.cast(target_account_id),
         {:ok, canonical_email} <- NewYou.Identity.Email.canonicalize(email),
         {:ok, result} <-
           Ash.transact(@transaction_resources, fn ->
             lookup_locked(credentials, grant_id, target_account_id, canonical_email)
           end) do
      result
    else
      _ -> unavailable()
    end
  rescue
    _ -> unavailable()
  catch
    _, _ -> unavailable()
  end

  defp lookup_locked(credentials, grant_id, target_account_id, canonical_email) do
    with {:ok, authority} <-
           PrivilegedAccess.authorize_locked(
             credentials,
             grant_id,
             target_account_id,
             :lookup_identity
           ),
         true <- authority.actor.id != authority.target.id do
      if authority.target.email == canonical_email do
        {:ok,
         %{
           account_id: authority.target.id,
           account_status: authority.target.account_status,
           email_verified?: authority.target.email_verified?,
           security_posture: authority.target.security_posture
         }}
      else
        {:ok, :not_found}
      end
    else
      _ -> unavailable()
    end
  end

  defp unavailable, do: {:error, :support_lookup_unavailable}
end
