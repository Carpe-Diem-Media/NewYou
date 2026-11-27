defmodule NewYou.Entitlements do
  @moduledoc """
  Entitlements owns Plan rights. It grants a held right only for a committed
  Commerce source and permits the original recipient to read it through Identity.
  """
  use Ash.Domain, otp_app: :new_you

  alias NewYou.Identity
  alias NewYou.Entitlements.{AssessmentCreditEvidence, PlanRight}

  require Ash.Query

  resources do
    resource PlanRight
    resource AssessmentCreditEvidence
  end

  @doc """
  Read whether the canonical recipient has an unused ordinary paid Assessment
  credit. The caller must hold the recipient's current Privacy scope lock in
  this transaction. Premium credits and Plan rights do not enter the result.
  Explicit owner evidence is required for an authoritative absence.
  """
  @spec ordinary_assessment_credit(Ecto.UUID.t()) ::
          {:ok, :unused | :consumed | :none} | {:error, :credit_evidence_unavailable}
  if Mix.env() == :test do
    def ordinary_assessment_credit(recipient_id) do
      with true <- Ash.DataLayer.in_transaction?(PlanRight),
           {:ok, %{ordinary_state: state}} when state != :unavailable <-
             Ash.get(AssessmentCreditEvidence, recipient_id, authorize?: false, error?: false),
           {:ok, active?} <-
             PlanRight
             |> Ash.Query.filter(
               recipient_id == ^recipient_id and component == :assessment and
                 state == :held_unconsumed
             )
             |> Ash.exists(authorize?: false) do
        cond do
          active? or state in [:available_unused, :held_unconsumed] -> {:ok, :unused}
          state == :consumed -> {:ok, :consumed}
          true -> {:ok, :none}
        end
      else
        _ -> {:error, :credit_evidence_unavailable}
      end
    end
  else
    def ordinary_assessment_credit(_), do: {:error, :credit_evidence_unavailable}
  end

  @doc """
  Apply or replay one Plan right for the given Commerce consequence. The
  executor cannot supply the recipient, component or paid purchase. Those
  fields come from the committed source. A committed TEST correction or
  suppression may withhold the grant. Missing or unavailable TEST Privacy
  authority leaves the grant open for retry. Call outside any existing transaction.
  """
  @spec grant_paid_plan(String.t()) ::
          {:ok, PlanRight.t() | :withheld} | {:error, :grant_unavailable}
  def grant_paid_plan(consequence_id) do
    if Ash.DataLayer.in_transaction?(PlanRight),
      do: {:error, :grant_unavailable},
      else: grant_current_plan(consequence_id)
  end

  @doc """
  Apply the exact component ending authorized by a committed TEST refund.
  Entitlements resolves the source through Commerce under current Privacy
  authority. Replays cannot create a right or end a different component.
  """
  @spec apply_fixture_refund(Ecto.UUID.t()) :: :ok | {:error, :grant_unavailable}
  if Mix.env() == :test do
    def apply_fixture_refund(id), do: NewYou.Entitlements.SyntheticRights.apply_hosted_refund(id)
  else
    def apply_fixture_refund(_), do: {:error, :grant_unavailable}
  end

  if Mix.env() == :test do
    defp grant_current_plan(consequence_id),
      do: NewYou.Entitlements.SyntheticRights.grant_p1(consequence_id)

    defp scope_visible?(recipient_id) do
      case NewYou.Privacy.SyntheticSuppression.locked_status(recipient_id) do
        {:ok, status} -> {:ok, status == :allowed}
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
  Review an Identity reconciliation pair for an empty Entitlements scope.
  A recorded right or Assessment credit observation requires separately
  governed reconciliation.
  """
  @spec review_identity_reconciliation(String.t(), String.t()) ::
          {:ok, map()} | {:error, :entitlements_scope_unavailable}
  def review_identity_reconciliation(candidate_id, canonical_id)
      when candidate_id != canonical_id do
    recipients = [candidate_id, canonical_id]
    rights = Ash.Query.filter(PlanRight, recipient_id in ^recipients)
    evidence = Ash.Query.filter(AssessmentCreditEvidence, recipient_id in ^recipients)

    with {:ok, false} <- Ash.exists(rights, authorize?: false),
         {:ok, false} <- Ash.exists(evidence, authorize?: false) do
      {:ok,
       %{
         "candidate_id" => candidate_id,
         "canonical_id" => canonical_id,
         "policy" => "empty_entitlements_scope",
         "commands" => []
       }}
    else
      _ ->
        {:error, :entitlements_scope_unavailable}
    end
  end

  def review_identity_reconciliation(_, _), do: {:error, :entitlements_scope_unavailable}
end
