defmodule NewYou.Identity.DeliveryEligibility do
  @moduledoc """
  Identity's current, read-only source guard for Communications admission and
  evidence disposition. Called inside the owning Communications transaction. Account and Token locks serialize
  admission with consumption, revocation and supersession. No provider evidence
  enters this interface and no Identity state changes here.
  """
  require Ash.Query
  alias NewYou.Identity.{Account, Recovery, Token}

  @doc """
  Checks the exact recovery issuance under Account, case and Token locks without
  serializing or consuming its proof. Requires an owning transaction. This is
  source eligibility only; content and provider admission remain separate gates.
  """
  @spec recovery(String.t(), String.t(), String.t(), Ecto.UUID.t()) ::
          :ok | {:error, :source_invalid}
  def recovery(reference, destination, locale, operation_id),
    do: Recovery.delivery_eligibility(reference, destination, locale, operation_id)

  @doc """
  Checks the exact durable completion receipt under Account, case and Token locks.
  Requires an owning transaction. Link expiry and later Account changes cannot
  erase a committed notice obligation. Communications preserves the destination
  authorised in the atomic completion handoff; this check never retargets it.
  It grants no content eligibility, provider permission, Session or hold release.
  """
  @spec recovery_notice(String.t(), String.t(), Ecto.UUID.t()) ::
          :ok | {:error, :source_invalid}
  def recovery_notice(reference, locale, completion_id),
    do: Recovery.notice_eligibility(reference, locale, completion_id)

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
