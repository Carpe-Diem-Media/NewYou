defmodule NewYou.Entitlements.SyntheticAssessmentCredit do
  @moduledoc """
  Entitlements' bounded TEST Assessment grant and terminal outcome for a paid
  S1 source. Existing correction and right records establish the outcome.
  """

  alias NewYou.Commerce.{AssessmentAdmissions, SyntheticCorrections}
  alias NewYou.Entitlements
  alias NewYou.Entitlements.{AssessmentCreditEvidence, PlanRight}
  alias NewYou.Privacy.SyntheticSuppression
  alias NewYou.Proof.PlanPaymentObservation

  require Ash.Query

  @unused [:available_unused, :held_unconsumed]

  @doc false
  @spec establish(PlanPaymentObservation.t()) ::
          {:ok, AssessmentCreditEvidence.t()} | {:error, :credit_evidence_unavailable}
  def establish(observation) do
    with {:ok,
          %{scope: :s1_credit_evidence, recipient_id: id, prior_evidence_id: expected} = fields} <-
           PlanPaymentObservation.verify(observation),
         attrs =
           Map.take(fields, [
             :recipient_id,
             :evidence_id,
             :ordinary_state,
             :credit_id,
             :premium_state
           ]),
         {:ok, %AssessmentCreditEvidence{} = evidence} <-
           Ash.transact(AssessmentCreditEvidence, fn -> establish_current(id, expected, attrs) end) do
      {:ok, evidence}
    else
      _ -> {:error, :credit_evidence_unavailable}
    end
  end

  @doc """
  Materialize only the bounded Assessment grant fixture for a paid S1 source.
  Call outside the Commerce transaction. The same source always returns the
  same owner right. Existing corrections prevent a late fixture grant.
  """
  @spec grant(Ecto.UUID.t()) :: {:ok, PlanRight.t()} | {:error, :grant_unavailable}
  def grant(id) do
    with false <- Ash.DataLayer.in_transaction?(PlanRight),
         {:ok, %PlanRight{} = right} <-
           Ash.transact(PlanRight, fn -> grant_locked(id) end) do
      {:ok, right}
    else
      _ -> {:error, :grant_unavailable}
    end
  end

  @doc """
  Resolve the exact paid Assessment outcome under the caller's purchase and
  Privacy locks. A live grant or an acknowledged correction is terminal.
  Return the original right ID when it exists, or the correction ID when the
  correction withheld the grant. An unacknowledged correction stays pending.
  """
  @spec terminal_resolution(map()) :: {:ok, Ecto.UUID.t()} | {:error, term()}
  def terminal_resolution(source) do
    with {:ok, right} <- grant_receipt(source),
         {:ok, correction} <-
           SyntheticCorrections.assessment_end_for_locked_source(source.purchase_id) do
      resolution_id(right, correction)
    end
  end

  defp resolution_id(%PlanRight{id: id, state: :held_unconsumed}, nil), do: {:ok, id}

  defp resolution_id(%PlanRight{id: id, state: :ended}, %{acknowledged_at: %DateTime{}}),
    do: {:ok, id}

  defp resolution_id(nil, %{id: id, acknowledged_at: %DateTime{}}), do: {:ok, id}

  defp resolution_id(_, _), do: {:error, :outcome_unavailable}

  defp grant_receipt(%{purchase_id: id, payment_id: payment, recipient_id: recipient}) do
    PlanRight
    |> Ash.Query.filter(purchase_id == ^id and component == :assessment)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %{payment_id: ^payment, recipient_id: ^recipient}} = result -> result
      {:ok, nil} = result -> result
      _ -> {:error, :grant_unavailable}
    end
  end

  defp grant_locked(id) do
    with {:ok, source} <- AssessmentAdmissions.locked_paid_source(id),
         {:ok, :allowed} <- SyntheticSuppression.locked_status(source.recipient_id),
         {:ok, right} <- grant_receipt(source) do
      materialize(right, source)
    else
      _ -> {:error, :grant_unavailable}
    end
  end

  defp materialize(%PlanRight{} = existing, _), do: existing

  defp materialize(nil, source) do
    with {:ok, credit} when credit in [:none, :consumed] <-
           Entitlements.ordinary_assessment_credit(source.recipient_id),
         {:ok, %{ended_components: ended_components}} <-
           SyntheticCorrections.locked_paid_scope(source.purchase_id),
         false <- MapSet.member?(ended_components, :assessment),
         attrs = Map.take(source, [:purchase_id, :payment_id, :recipient_id]),
         {:ok, right} <-
           Ash.create(PlanRight, Map.put(attrs, :component, :assessment),
             action: :grant,
             authorize?: false
           ) do
      right
    else
      _ -> {:error, :grant_unavailable}
    end
  end

  defp establish_current(id, expected, attrs) do
    with {:ok, :allowed} <- SyntheticSuppression.locked_status(id),
         {:ok, current} <- Ash.get(AssessmentCreditEvidence, id, authorize?: false, error?: false) do
      write(current, expected, attrs)
    else
      _ -> {:error, :credit_evidence_unavailable}
    end
  end

  defp write(nil, nil, attrs) do
    with {:ok, saved} <-
           Ash.create(AssessmentCreditEvidence, attrs,
             action: :establish_fixture,
             authorize?: false
           ),
         do: saved
  end

  defp write(%{evidence_id: prior} = current, expected, %{evidence_id: proposed} = attrs) do
    cond do
      prior == proposed and Map.take(current, Map.keys(attrs)) == attrs ->
        current

      prior == expected and prior != proposed and compatible_credit?(current, attrs) ->
        with {:ok, saved} <-
               Ash.update(current, Map.delete(attrs, :recipient_id),
                 action: :observe_fixture,
                 authorize?: false
               ),
             do: saved

      true ->
        {:error, :credit_evidence_unavailable}
    end
  end

  defp write(_, _, _), do: {:error, :credit_evidence_unavailable}

  defp compatible_credit?(%{ordinary_state: prior, credit_id: id}, %{
         ordinary_state: next,
         credit_id: proposed
       })
       when prior in @unused,
       do: next == :unavailable or (id == proposed and next in (@unused ++ [:consumed, :closed]))

  defp compatible_credit?(_, _), do: true
end
