defmodule NewYou.Commerce.AssessmentAdmissions do
  @moduledoc """
  Commerce owns the Assessment-bearing claim from acceptance until proven
  nonpayability or acknowledged owner grant. Missing outcomes leave the claim
  active. The qualified payment and grant cuts exercise this boundary in TEST.
  """

  alias NewYou.Commerce.{AssessmentAdmission, PaymentConsequence, Purchase, VerifiedPayment}
  alias NewYou.{Entitlements, Temperament}
  require Ash.Query

  @doc false
  @spec eligible?(Ecto.UUID.t()) ::
          :ok
          | {:denied,
             :unused_credit
             | :annual_interval
             | :competing_purchase
             | :credit_evidence_unavailable
             | :delivery_evidence_unavailable}
  def eligible?(recipient_id) do
    with {:ok, false} <- active?(recipient_id),
         {:ok, credit} when credit in [:none, :consumed] <-
           Entitlements.ordinary_assessment_credit(recipient_id),
         {:ok, delivery} <- Temperament.latest_paid_assessment_delivery(recipient_id) do
      check_delivery_interval(credit, delivery)
    else
      {:ok, true} -> {:denied, :competing_purchase}
      {:ok, :unused} -> {:denied, :unused_credit}
      {:error, cause} -> {:denied, cause}
    end
  end

  @doc false
  @spec admit(Purchase.t()) :: :ok | {:error, term()}
  def admit(purchase) do
    with {:ok, _} <-
           Ash.create(
             AssessmentAdmission,
             %{purchase_id: purchase.id, recipient_id: purchase.recipient_id},
             action: :admit,
             authorize?: false
           ) do
      :ok
    end
  end

  @doc false
  @spec check_payable(Purchase.t(), NewYou.Commerce.OfferCatalogue.product()) ::
          :ok | {:error, :payment_unavailable}
  def check_payable(_purchase, :plan), do: :ok

  def check_payable(purchase, _) do
    case Ash.get(AssessmentAdmission, purchase.id, authorize?: false) do
      {:ok, %{state: state}} when state in [:pending, :paid, :reconciled] -> :ok
      _ -> {:error, :payment_unavailable}
    end
  end

  @doc false
  @spec record_payment(Purchase.t(), :plan | :s1_fixture) :: :ok | {:error, term()}
  def record_payment(_purchase, :plan), do: :ok

  def record_payment(purchase, :s1_fixture) do
    case Ash.get(AssessmentAdmission, purchase.id, authorize?: false, error?: false) do
      {:ok, nil} ->
        :ok

      {:ok, %{state: :pending} = admission} ->
        with {:ok, _} <- Ash.update(admission, %{}, action: :record_payment, authorize?: false),
             do: :ok

      _ ->
        {:error, :payment_unavailable}
    end
  end

  @doc """
  Settle the TEST claim using qualified evidence of irreversible nonpayability
  for the exact accepted attempt. An outstanding or applied payment prevents
  this transition. Replaying the same final evidence has no additional effect.
  """
  @spec confirm_nonpayable(term()) :: :ok | {:error, :reconciliation_unavailable}
  if Mix.env() == :test do
    def confirm_nonpayable(evidence) do
      case NewYou.Proof.PlanPaymentObservation.verify(evidence) do
        {:ok, %{scope: :s1_nonpayability, outcome: :irreversible_nonpayability} = fields} ->
          reconcile(fn -> settle_nonpayable(fields) end)

        _ ->
          {:error, :reconciliation_unavailable}
      end
    end

    defp settle_nonpayable(%{
           purchase_id: id,
           attempt_id: attempt,
           quote_id: quote,
           resolution_id: resolution
         })
         when not is_nil(quote) do
      with {:ok, %Purchase{attempt_id: ^attempt, quote_id: ^quote}} <- lock_purchase(id),
           {:ok, admission} <- Ash.get(AssessmentAdmission, id, authorize?: false),
           {:ok, false} <-
             Ash.exists(Ash.Query.filter(VerifiedPayment, purchase_id == ^id), authorize?: false) do
        case admission do
          %{state: :pending} -> resolve(admission, resolution, :confirm_nonpayable)
          %{state: :nonpayable, resolution_id: ^resolution} -> :ok
          _ -> {:error, :reconciliation_unavailable}
        end
      end
    end

    defp settle_nonpayable(_), do: {:error, :reconciliation_unavailable}
  else
    def confirm_nonpayable(_), do: {:error, :reconciliation_unavailable}
  end

  @doc """
  Discover the outstanding Assessment grant or acknowledgement for an accepted
  source in TEST. The result carries only the consequence ID. A caller can
  retry the owner grant and acknowledgement independently.
  """
  @spec open_credit_consequence(Ecto.UUID.t()) ::
          {:ok, Ecto.UUID.t() | nil} | {:error, :reconciliation_unavailable}
  if Mix.env() == :test do
    def open_credit_consequence(purchase_id) do
      with {:ok, %AssessmentAdmission{}} <-
             Ash.get(AssessmentAdmission, purchase_id, authorize?: false),
           {:ok, open} <-
             PaymentConsequence
             |> Ash.Query.filter(
               purchase_id == ^purchase_id and delivery_kind == :s1_fixture and
                 is_nil(fulfilled_at)
             )
             |> Ash.read_one(authorize?: false) do
        {:ok, if(open, do: open.id)}
      else
        _ -> {:error, :reconciliation_unavailable}
      end
    end
  else
    def open_credit_consequence(_), do: {:error, :reconciliation_unavailable}
  end

  @doc """
  Acknowledge an Assessment grant in TEST after the Entitlements transaction
  commits. Commerce releases only this source's claim, under lock, after it
  finds the exact committed owner right. A repeated acknowledgement is safe.
  """
  @spec acknowledge_credit(Ecto.UUID.t()) :: :ok | {:error, :reconciliation_unavailable}
  if Mix.env() == :test do
    def acknowledge_credit(id) do
      if Ash.DataLayer.in_transaction?(Purchase),
        do: {:error, :reconciliation_unavailable},
        else: reconcile(fn -> acknowledge_locked(id) end)
    end

    defp acknowledge_locked(id) do
      with {:ok, %{admission: admission, consequence: consequence} = source} <-
             locked_paid_source(id),
           {:ok, :allowed} <-
             NewYou.Privacy.SyntheticSuppression.locked_status(source.recipient_id),
           {:ok, %{id: right_id}} <-
             NewYou.Entitlements.SyntheticAssessmentCredit.grant_receipt(source) do
        acknowledge_after_grant(admission, consequence, right_id)
      end
    end

    defp acknowledge_after_grant(
           %{state: :reconciled, resolution_id: id},
           %{fulfilled_at: %DateTime{}},
           id
         ),
         do: :ok

    defp acknowledge_after_grant(
           %{state: :paid} = admission,
           %{fulfilled_at: nil} = consequence,
           right_id
         ) do
      with :ok <- resolve(admission, right_id, :acknowledge_credit),
           {:ok, _} <-
             Ash.update(consequence, %{fulfilled_at: DateTime.utc_now()},
               action: :acknowledge,
               authorize?: false
             ) do
        :ok
      end
    end

    defp acknowledge_after_grant(_, _, _), do: {:error, :reconciliation_unavailable}

    defp reconcile(operation) do
      case Ash.transact(Purchase, operation) do
        {:ok, :ok} -> :ok
        _ -> {:error, :reconciliation_unavailable}
      end
    end

    defp resolve(admission, id, action) do
      with {:ok, _} <-
             Ash.update(admission, %{resolution_id: id, resolved_at: DateTime.utc_now()},
               action: action,
               authorize?: false
             ) do
        :ok
      end
    end
  else
    def acknowledge_credit(_), do: {:error, :reconciliation_unavailable}
  end

  @doc false
  @spec locked_paid_source(Ecto.UUID.t()) :: {:ok, map()} | {:error, :source_unavailable}
  def locked_paid_source(consequence_id) do
    with true <- Ash.DataLayer.in_transaction?(Purchase),
         {:ok, %PaymentConsequence{purchase_id: id, delivery_kind: :s1_fixture}} <-
           Ash.get(PaymentConsequence, consequence_id, authorize?: false),
         {:ok, %Purchase{recipient_id: recipient}} <- lock_purchase(id),
         {:ok, %AssessmentAdmission{recipient_id: ^recipient, state: state} = admission}
         when state in [:paid, :reconciled] <- Ash.get(AssessmentAdmission, id, authorize?: false),
         {:ok, %PaymentConsequence{payment_id: payment} = consequence} <-
           Ash.get(PaymentConsequence, consequence_id, authorize?: false),
         {:ok, %VerifiedPayment{purchase_id: ^id}} <-
           Ash.get(VerifiedPayment, payment, authorize?: false) do
      {:ok,
       %{
         purchase_id: id,
         payment_id: payment,
         recipient_id: recipient,
         admission: admission,
         consequence: consequence
       }}
    else
      _ -> {:error, :source_unavailable}
    end
  end

  defp lock_purchase(id) do
    Purchase
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one(authorize?: false)
  end

  defp active?(recipient_id) do
    AssessmentAdmission
    |> Ash.Query.filter(recipient_id == ^recipient_id and state in [:pending, :paid])
    |> Ash.exists(authorize?: false)
    |> case do
      {:ok, _} = result -> result
      _ -> {:error, :credit_evidence_unavailable}
    end
  end

  defp check_delivery_interval(:consumed, :none), do: {:denied, :delivery_evidence_unavailable}

  defp check_delivery_interval(_, delivery) do
    if within_year?(delivery), do: {:denied, :annual_interval}, else: :ok
  end

  defp within_year?(:none), do: false

  defp within_year?(%DateTime{} = previous_delivery) do
    DateTime.compare(DateTime.utc_now(), DateTime.shift(previous_delivery, year: 1)) == :lt
  end
end
