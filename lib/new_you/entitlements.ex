defmodule NewYou.Entitlements do
  @moduledoc """
  Entitlements owns Plan rights. It grants a held right only for a committed
  Commerce source and permits the original recipient to read it through Identity.
  """
  use Ash.Domain, otp_app: :new_you

  alias NewYou.Identity
  alias NewYou.Entitlements.PlanRight

  require Ash.Query

  resources do
    resource PlanRight
  end

  @doc """
  Apply or replay one Plan right for the given Commerce consequence. The
  executor cannot supply the recipient, component or paid purchase. Those
  fields come from the committed source. A committed TEST correction or
  suppression may withhold the grant. Call outside any existing transaction.
  """
  @spec grant_paid_plan(String.t()) ::
          {:ok, PlanRight.t() | :withheld} | {:error, :grant_unavailable}
  def grant_paid_plan(consequence_id) do
    if Ash.DataLayer.in_transaction?(PlanRight),
      do: {:error, :grant_unavailable},
      else: grant_current_plan(consequence_id)
  end

  if Mix.env() == :test do
    defp grant_current_plan(consequence_id),
      do: NewYou.Entitlements.SyntheticRights.grant_p1(consequence_id)

    defp scope_visible?(recipient_id) do
      case NewYou.Privacy.SyntheticSuppression.locked_status(recipient_id) do
        {:ok, status} -> {:ok, status != :suppressed}
        {:error, _} = error -> error
      end
    end
  else
    defp grant_current_plan(consequence_id) do
      with {:ok, %{recipient_id: recipient_id, payment_id: payment_id} = source} <-
             NewYou.Commerce.paid_plan_source(consequence_id),
           {:ok, %PlanRight{recipient_id: ^recipient_id, payment_id: ^payment_id} = right} <-
             Ash.create(PlanRight, source, action: :grant, authorize?: false) do
        {:ok, right}
      else
        _ -> {:error, :grant_unavailable}
      end
    end

    defp scope_visible?(_), do: {:ok, true}
  end

  @doc """
  List held Plan rights for the canonical Account on the current session.
  A held right supplies no permission to read delivered Plan content.
  """
  @spec plan_rights(map()) :: {:ok, [PlanRight.t()]} | {:error, :rights_unavailable}
  def plan_rights(credentials) do
    case Ash.transact(PlanRight, fn -> recipient_rights(credentials) end) do
      {:ok, rights} when is_list(rights) -> {:ok, rights}
      _ -> {:error, :rights_unavailable}
    end
  end

  defp recipient_rights(credentials) do
    with {:ok, %{account_id: recipient_id}} <-
           Identity.authorize_canonical_session(credentials),
         {:ok, true} <- scope_visible?(recipient_id),
         {:ok, rights} <-
           PlanRight
           |> Ash.Query.filter(
             recipient_id == ^recipient_id and component == :plan and state == :held_unconsumed
           )
           |> Ash.read(authorize?: false) do
      rights
    else
      {:ok, false} -> []
      {:error, _} = error -> error
    end
  end

  @doc """
  Review this Account pair for reconciliation. A pair with Plan rights is
  outside P1's empty-scope review and cannot be reconciled by this policy.
  """
  @spec review_identity_reconciliation(String.t(), String.t()) ::
          {:ok, map()} | {:error, :entitlements_scope_unavailable}
  def review_identity_reconciliation(candidate_id, canonical_id)
      when candidate_id != canonical_id do
    query = Ash.Query.filter(PlanRight, recipient_id in ^[candidate_id, canonical_id])

    case Ash.exists(query, authorize?: false) do
      {:ok, false} ->
        {:ok,
         %{
           "candidate_id" => candidate_id,
           "canonical_id" => canonical_id,
           "policy" => "empty_entitlements_scope",
           "commands" => []
         }}

      _ ->
        {:error, :entitlements_scope_unavailable}
    end
  end

  def review_identity_reconciliation(_, _), do: {:error, :entitlements_scope_unavailable}
end
