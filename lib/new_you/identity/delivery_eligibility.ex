defmodule NewYou.Identity.DeliveryEligibility do
  @moduledoc """
  Identity's current, read-only source guard for Communications admission.
  Called inside the admission transaction. Account and Token locks serialize
  admission with consumption, revocation and supersession. No provider evidence
  enters this interface and no Identity state changes here.
  """
  require Ash.Query
  alias NewYou.Identity.{Account, Token}

  @spec verification(String.t(), String.t()) :: :ok | {:error, :source_invalid}
  def verification(reference, destination) do
    with true <- NewYou.Repo.in_transaction?(),
         {:ok, %Token{} = candidate} <- token(reference),
         {:ok, %Account{} = account} <- lock_account(candidate.account_id),
         {:ok, %Token{} = current} <- token(reference, true),
         true <- current.account_id == account.id,
         true <- current.purpose == "email_verification",
         true <- current.subject == AshAuthentication.user_to_subject(account),
         :gt <- DateTime.compare(current.expires_at, DateTime.utc_now()),
         true <- account.email == destination,
         true <- account.credential_status == :active and not account.email_verified?,
         true <- account.account_status == :open and account.security_posture == :normal do
      :ok
    else
      _ -> {:error, :source_invalid}
    end
  end

  defp token(reference, lock? \\ false) do
    query = Ash.Query.filter(Token, jti == ^reference)
    query = if lock?, do: Ash.Query.lock(query, :for_update), else: query
    Ash.read_one(query, domain: NewYou.Identity, authorize?: false)
  end

  defp lock_account(id) do
    Account
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one(domain: NewYou.Identity, authorize?: false)
  end
end
