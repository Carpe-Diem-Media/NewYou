defmodule NewYou.Identity.Actions.ConfirmEmail do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias NewYou.Identity
  alias NewYou.Identity.{Account, Token}
  alias AshAuthentication.Jwt
  require Ash.Query

  @impl true
  def run(input, _opts, _context) do
    proof = input.arguments.proof

    # This first read selects the lock only. Everything granting authority is
    # repeated after the Account lock, including signature and expiry validation.
    with {:ok, %{"purpose" => "email_verification", "sub" => subject, "jti" => jti}, Account} <-
           Jwt.verify(proof, Account),
         {:ok, account} <- AshAuthentication.subject_to_user(subject, Account) do
      confirmation_transaction(proof, account.id, subject, jti)
    else
      _ -> {:error, :verification_unavailable}
    end
  end

  defp confirmation_transaction(proof, account_id, subject, jti) do
    case Ash.transact([Account, Token], fn -> consume(proof, account_id, subject, jti) end) do
      {:ok, {:ok, :verified}} -> {:ok, :verified}
      {:ok, :verified} -> {:ok, :verified}
      _ -> {:error, :verification_unavailable}
    end
  end

  defp consume(proof, account_id, subject, jti) do
    with {:ok, [account]} <- lock_account(account_id),
         true <- eligible?(account),
         ^subject <- AshAuthentication.user_to_subject(account),
         {:ok, [token]} <- lock_token(jti, account.id, subject),
         {:ok, %{"purpose" => "email_verification", "sub" => ^subject, "jti" => ^jti}, Account} <-
           Jwt.verify(proof, Account),
         :lt <- DateTime.compare(DateTime.utc_now(), token.expires_at),
         :ok <-
           AshAuthentication.TokenResource.Actions.revoke(
             Token,
             proof,
             single_use?: true,
             authorize?: false,
             context: %{ash_authentication: %{user: account}}
           ),
         {:ok, _account} <-
           Ash.update(account, %{}, action: :mark_email_verified, authorize?: false) do
      checkpoint()
      {:ok, :verified}
    else
      _ -> {:error, :verification_unavailable}
    end
  end

  defp eligible?(account),
    do:
      account.credential_status == :active and account.email_verified? == false and
        account.account_status == :open and account.security_posture == :normal

  defp lock_account(id) do
    Account
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read(domain: Identity, authorize?: false)
  end

  defp lock_token(jti, account_id, subject) do
    Token
    |> Ash.Query.filter(
      jti == ^jti and account_id == ^account_id and subject == ^subject and
        purpose == "email_verification"
    )
    |> Ash.Query.lock(:for_update)
    |> Ash.read(domain: Identity, authorize?: false)
  end

  if Mix.env() == :test do
    # Reuses the existing TEST-only transaction seam. No request or production
    # configuration can supply callbacks or change the authoritative transition.
    defp checkpoint, do: NewYou.Proof.RegistrationSeam.checkpoint()
  else
    defp checkpoint, do: :ok
  end
end
