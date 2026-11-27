defmodule NewYou.Commerce do
  @moduledoc """
  Commerce owns accepted purchases, payment application, and the
  obligation to hand the resulting source to Entitlements. Qualified TEST
  collections may also establish a source-bound excess claim.
  """
  use Ash.Domain, otp_app: :new_you

  alias NewYou.Commerce.{PaymentConsequence, Purchase, VerifiedPayment}

  alias NewYou.Entitlements

  require Ash.Query

  resources do
    resource Purchase
    resource NewYou.Commerce.HostedDispatch
    resource NewYou.Commerce.HostedPaymentReceipt
    resource NewYou.Commerce.OfferVersion
    resource NewYou.Commerce.PurchaseQuote
    resource NewYou.Commerce.AssessmentAdmission
    resource VerifiedPayment
    resource NewYou.Commerce.FixtureRefund
    resource NewYou.Commerce.FixtureRefundReceipt
    resource PaymentConsequence
    resource NewYou.Commerce.SyntheticCollection
    resource NewYou.Commerce.SyntheticCollectionReceipt
    resource NewYou.Commerce.SyntheticExcessClaim
    resource NewYou.Commerce.SyntheticOrder
    resource NewYou.Commerce.SyntheticCorrection
    resource NewYou.Commerce.SyntheticCorrectionReceipt
  end

  @doc """
  Establish or replay a TEST-only refund obligation for the signed, exact
  hosted payment allocation. The current canonical payer must match the
  immutable purchase. This operation cannot dispatch a refund.
  """
  @spec authorize_fixture_refund(map(), term()) ::
          {:ok, NewYou.Commerce.FixtureRefund.t()} | {:error, :refund_unavailable}
  if Mix.env() == :test do
    def authorize_fixture_refund(credentials, proof),
      do: NewYou.Commerce.FixtureRefunds.authorize(credentials, proof)
  else
    def authorize_fixture_refund(_, _), do: {:error, :refund_unavailable}
  end

  @doc """
  Reserve a previously authorized TEST refund as its current canonical payer.
  Replays return the same intent. Reservation performs no provider request.
  """
  @spec reserve_fixture_refund(map(), Ecto.UUID.t()) ::
          {:ok, NewYou.Commerce.FixtureRefund.t()} | {:error, :refund_unavailable}
  if Mix.env() == :test do
    def reserve_fixture_refund(credentials, id),
      do: NewYou.Commerce.FixtureRefunds.reserve(credentials, id)
  else
    def reserve_fixture_refund(_, _), do: {:error, :refund_unavailable}
  end

  @doc """
  Consume a TEST refund's only dispatch claim. Only the committed winner can
  POST to the checkout fixture's pinned listener. The result remains unresolved
  until qualified evidence arrives, including when the response is lost.
  """
  @spec dispatch_fixture_refund(map(), Ecto.UUID.t()) ::
          {:ok, NewYou.Commerce.FixtureRefund.t()} | {:error, :refund_unavailable}
  if Mix.env() == :test do
    def dispatch_fixture_refund(credentials, id),
      do: NewYou.Commerce.FixtureRefunds.dispatch(credentials, id)
  else
    def dispatch_fixture_refund(_, _), do: {:error, :refund_unavailable}
  end

  @doc """
  Qualify a persisted, authenticated TEST refund receipt. Only exact bound
  evidence can advance the original claim. Replay cannot repeat its effect.
  """
  @spec apply_fixture_refund_receipt(Ecto.UUID.t()) :: :ok | {:error, :refund_unavailable}
  if Mix.env() == :test do
    def apply_fixture_refund_receipt(id),
      do: NewYou.Commerce.FixtureRefunds.apply_receipt(id)
  else
    def apply_fixture_refund_receipt(_), do: {:error, :refund_unavailable}
  end

  @doc """
  Deliver the committed TEST refund consequence to Entitlements and acknowledge
  it after their transaction. The same source can be safely applied after a
  lost acknowledgement.
  """
  @spec deliver_fixture_refund(Ecto.UUID.t()) :: :ok | {:error, :refund_unavailable}
  if Mix.env() == :test do
    def deliver_fixture_refund(id), do: NewYou.Commerce.FixtureRefunds.deliver(id)
  else
    def deliver_fixture_refund(_), do: {:error, :refund_unavailable}
  end

  @doc """
  Accept the fixed synthetic Plan price for the current canonical Account.
  The same operation and payer replay the original purchase and attempt.
  Changed input or an ineligible session returns `{:error, :purchase_unavailable}`.
  """
  @spec accept_plan_purchase(map(), map()) ::
          {:ok, Purchase.t()} | {:error, :purchase_unavailable}
  if Mix.env() == :test do
    @price_version "synthetic-plan-v1"

    def accept_plan_purchase(
          credentials,
          %{operation_id: id, price_version: @price_version} = request
        )
        when map_size(request) == 2 do
      with {:ok, operation_id} <- Ecto.UUID.cast(id),
           {:ok, %Purchase{} = purchase} <-
             Ash.transact(Purchase, fn -> accept_locked(credentials, operation_id) end) do
        {:ok, purchase}
      else
        _ -> {:error, :purchase_unavailable}
      end
    end

    def accept_plan_purchase(_, _), do: {:error, :purchase_unavailable}

    defp accept_locked(credentials, operation_id) do
      with {:ok, %{account_id: account_id}} <-
             NewYou.Identity.authorize_canonical_session(credentials),
           {:ok, %Purchase{payer_id: ^account_id, quote_id: nil} = purchase} <-
             accept_once(operation_id, account_id) do
        purchase
      else
        _ -> {:error, :purchase_unavailable}
      end
    end

    defp accept_once(operation_id, account_id) do
      Ash.create(
        Purchase,
        %{
          operation_id: operation_id,
          payer_id: account_id,
          recipient_id: account_id,
          price_version: @price_version,
          amount_minor: Application.fetch_env!(:new_you, :p1_synthetic_plan_amount_minor),
          currency: "ZAR"
        },
        action: :accept,
        authorize?: false
      )
    end
  else
    def accept_plan_purchase(_credentials, _request), do: {:error, :purchase_unavailable}
  end

  @doc """
  Review whether the Account pair has Commerce history. P1 only supports an
  empty scope. A recorded purchase or TEST fixture involving either party
  requires a separately supported review.
  """
  @spec review_identity_reconciliation(String.t(), String.t()) ::
          {:ok, map()} | {:error, :commerce_scope_unavailable}
  def review_identity_reconciliation(candidate_id, canonical_id)
      when candidate_id != canonical_id do
    ids = [candidate_id, canonical_id]
    query = Ash.Query.filter(Purchase, payer_id in ^ids or recipient_id in ^ids)

    with {:ok, false} <- Ash.exists(query, authorize?: false),
         {:ok, false} <- synthetic_order_history?(candidate_id, canonical_id) do
      {:ok,
       %{
         "candidate_id" => candidate_id,
         "canonical_id" => canonical_id,
         "policy" => "empty_commerce_scope",
         "commands" => []
       }}
    else
      _ -> {:error, :commerce_scope_unavailable}
    end
  end

  def review_identity_reconciliation(_, _), do: {:error, :commerce_scope_unavailable}

  if Mix.env() == :test do
    defp synthetic_order_history?(candidate_id, canonical_id) do
      ids = [candidate_id, canonical_id]

      NewYou.Commerce.SyntheticOrder
      |> Ash.Query.filter(payer_id in ^ids or recipient_id in ^ids)
      |> Ash.exists(authorize?: false)
    end
  else
    defp synthetic_order_history?(_, _), do: {:ok, false}
  end

  @doc """
  Apply qualified payment evidence to an exact accepted attempt. Commerce
  commits payment and its consequence together. Explicit collection proofs bind
  their receipt to the accepted observation in the same transaction. Exact
  replay returns the committed result. An attempt bound to the local Hosted
  Checkout fixture cannot accept synthetic payment evidence. The verifier is
  compiled only in TEST.
  """
  @spec apply_payment_observation(term()) ::
          {:ok, VerifiedPayment.t()} | {:error, :payment_unavailable}
  if Mix.env() == :test do
    alias NewYou.Commerce.{
      AssessmentAdmissions,
      FixtureRefunds,
      HostedDispatch,
      HostedPaymentReceipt,
      OfferAdmission,
      SyntheticCollectionLedger
    }

    def apply_payment_observation(observation) do
      with {:ok, %{status: :succeeded, integration: :synthetic, environment: :test} = fields} <-
             NewYou.Proof.PlanPaymentObservation.verify(observation),
           {:ok, %VerifiedPayment{} = payment} <-
             Ash.transact(Purchase, fn ->
               apply_qualified(fields)
             end) do
        {:ok, payment}
      else
        _ -> {:error, :payment_unavailable}
      end
    end

    @doc """
    Process persisted TEST fixture evidence through the Commerce owner. The id
    identifies an authenticated receipt or a server Verify observation. Exact
    replay is safe. Qualification, payment, and its consequence commit together.
    """
    @spec apply_hosted_payment_evidence(Ecto.UUID.t()) :: :ok | {:error, :unavailable}
    def apply_hosted_payment_evidence(id) do
      result =
        NewYou.Repo.without_query_telemetry(fn ->
          Ash.transact(Purchase, fn -> process_fixture_evidence(id) end)
        end)

      case result do
        {:ok, classification} ->
          :telemetry.execute(
            [:new_you, :commerce, :fixture_payment, :classification],
            %{count: 1},
            %{outcome: classification}
          )

          :ok

        _ ->
          {:error, :unavailable}
      end
    end

    defp process_fixture_evidence(id) do
      case HostedPaymentReceipt
           |> Ash.Query.filter(id == ^id)
           |> Ash.Query.lock(:for_update)
           |> Ash.read_one(authorize?: false) do
        {:ok, %HostedPaymentReceipt{state: :pending} = receipt} ->
          with {:ok, state, reason} <- qualify_fixture_receipt(receipt),
               {:ok, _} <-
                 Ash.update(receipt, %{state: state, classification: reason},
                   action: :classify,
                   authorize?: false
                 ) do
            state
          end

        {:ok, %HostedPaymentReceipt{state: state}} ->
          state

        _ ->
          {:error, :unavailable}
      end
    end

    defp qualify_fixture_receipt(%{outcome: outcome} = receipt)
         when outcome in [:succeeded, :pending, :excess] do
      with {:ok, attempt} <- find_fixture_attempt(receipt),
           {:ok, purchase} <- lock_fixture_purchase(attempt, receipt) do
        classify_bound_fixture_receipt(receipt, purchase, attempt)
      else
        {:error, :mismatch} -> {:ok, :quarantined, :source_mismatch}
        error -> error
      end
    end

    defp qualify_fixture_receipt(%{outcome: reason})
         when reason in [:not_found, :timeout, :rate_limited, :unavailable],
         do: {:ok, :unresolved, reason}

    defp qualify_fixture_receipt(%{outcome: reason}), do: {:ok, :quarantined, reason}

    defp classify_bound_fixture_receipt(%{outcome: :pending}, _purchase, _attempt),
      do: {:ok, :unresolved, :pending}

    defp classify_bound_fixture_receipt(
           %{outcome: :excess, source: :webhook} = receipt,
           purchase,
           _
         ) do
      with :ok <- OfferAdmission.current_parties_privacy(purchase),
           {:ok, prior} <- fixture_payment_history(purchase, receipt) do
        apply_excess_fixture_payment(prior, purchase, receipt)
      end
    end

    defp classify_bound_fixture_receipt(%{outcome: :excess}, _, _),
      do: {:ok, :quarantined, :source_mismatch}

    defp classify_bound_fixture_receipt(receipt, purchase, attempt) do
      with :ok <- OfferAdmission.current_parties_privacy(purchase),
           {:ok, prior} <- fixture_payment_history(purchase, receipt) do
        apply_fixture_payment(prior, purchase, attempt, receipt)
      end
    end

    defp find_fixture_attempt(%{
           source: :verify,
           requested_reference: requested,
           reference: reference
         })
         when requested != reference,
         do: {:error, :mismatch}

    defp find_fixture_attempt(receipt) do
      case HostedDispatch
           |> Ash.Query.filter(
             reference == ^receipt.reference and provider == ^receipt.provider and
               integration == ^receipt.integration and environment == ^receipt.environment and
               channel == :card and not is_nil(claim_id)
           )
           |> Ash.read_one(authorize?: false) do
        {:ok, %HostedDispatch{} = attempt} -> {:ok, attempt}
        {:ok, nil} -> {:error, :mismatch}
        error -> error
      end
    end

    defp lock_fixture_purchase(attempt, receipt) do
      case Purchase
           |> Ash.Query.filter(attempt_id == ^attempt.attempt_id)
           |> Ash.Query.lock(:for_update)
           |> Ash.read_one(authorize?: false) do
        {:ok, %Purchase{} = purchase} ->
          with true <-
                 purchase.amount_minor == receipt.amount_minor and
                   purchase.currency == receipt.currency,
               %{terms: %{product: :plan}} = snapshot <- OfferAdmission.bound_snapshot(purchase),
               true <- HostedDispatch.source_digest(snapshot) == attempt.source_digest do
            {:ok, purchase}
          else
            _ -> {:error, :mismatch}
          end

        {:ok, nil} ->
          {:error, :mismatch}

        error ->
          error
      end
    end

    defp fixture_payment_history(purchase, receipt) do
      VerifiedPayment
      |> Ash.Query.filter(
        (purchase_id == ^purchase.id and collection_kind == :primary) or
          fixture_transaction_id == ^receipt.transaction_id
      )
      |> Ash.read(authorize?: false)
    end

    defp apply_fixture_payment([], purchase, attempt, receipt) do
      source = %{fixture_receipt_id: receipt.id, fixture_transaction_id: receipt.transaction_id}

      with %VerifiedPayment{} <- commit_payment(nil, purchase, :plan, source),
           {:ok, _} <- Ash.update(attempt, %{}, action: :close_verify, authorize?: false) do
        {:ok, :qualified, :applied}
      end
    end

    defp apply_fixture_payment(
           [
             %VerifiedPayment{
               purchase_id: purchase_id,
               collection_kind: :primary,
               fixture_transaction_id: transaction_id
             }
           ],
           %{id: purchase_id},
           _attempt,
           %{transaction_id: transaction_id}
         ),
         do: {:ok, :qualified, :replayed}

    defp apply_fixture_payment(_, _, _, _), do: {:ok, :quarantined, :payment_conflict}

    defp apply_excess_fixture_payment(prior, purchase, receipt) do
      original =
        Enum.find(
          prior,
          &(&1.collection_kind == :primary and
              &1.purchase_id == purchase.id and not is_nil(&1.fixture_receipt_id))
        )

      same_transaction = Enum.find(prior, &(&1.fixture_transaction_id == receipt.transaction_id))

      case {original, same_transaction} do
        {%VerifiedPayment{}, nil} ->
          attrs = %{
            purchase_id: purchase.id,
            fixture_receipt_id: receipt.id,
            fixture_transaction_id: receipt.transaction_id
          }

          with {:ok, collection} <-
                 Ash.create(VerifiedPayment, attrs, action: :record_excess, authorize?: false),
               %NewYou.Commerce.FixtureRefund{} <-
                 FixtureRefunds.establish_excess_locked(purchase, collection) do
            {:ok, :qualified, :excess_recorded}
          end

        {%VerifiedPayment{}, %VerifiedPayment{purchase_id: id, collection_kind: :excess}}
        when id == purchase.id ->
          {:ok, :qualified, :replayed}

        _ ->
          {:ok, :quarantined, :payment_conflict}
      end
    end

    defp apply_qualified(
           %{
             purchase_id: purchase_id,
             attempt_id: attempt_id,
             amount_minor: amount_minor,
             currency: currency
           } = fields
         ) do
      with {:ok,
            %Purchase{attempt_id: ^attempt_id, amount_minor: ^amount_minor, currency: ^currency} =
              purchase} <-
             Purchase
             |> Ash.Query.filter(id == ^purchase_id)
             |> Ash.Query.lock(:for_update)
             |> Ash.read_one(authorize?: false),
           {:ok, nil} <-
             Ash.get(HostedDispatch, attempt_id, authorize?: false, error?: false),
           {:ok, delivery} <- payment_scope(purchase, fields),
           {:ok, prior} <-
             VerifiedPayment
             |> Ash.Query.filter(purchase_id == ^purchase_id and collection_kind == :primary)
             |> Ash.read_one(authorize?: false),
           :ok <- record_collection(fields, purchase, prior) do
        commit_payment(prior, purchase, delivery, %{})
      else
        _ -> {:error, :payment_unavailable}
      end
    end

    defp apply_qualified(_), do: {:error, :payment_unavailable}

    defp payment_scope(%Purchase{quote_id: nil}, fields) do
      if Map.get(fields, :scope) == :s1_payment,
        do: {:error, :payment_unavailable},
        else: {:ok, :plan}
    end

    defp payment_scope(%Purchase{quote_id: id} = purchase, %{
           scope: :s1_payment,
           quote_id: id,
           collection_id: _,
           receipt_id: _
         }) do
      with {:ok, terms} <- OfferAdmission.accepted_terms(purchase),
           :ok <- AssessmentAdmissions.check_payable(purchase, terms.product) do
        {:ok, :s1_fixture}
      end
    end

    defp payment_scope(_, _), do: {:error, :payment_unavailable}

    defp record_collection(fields, purchase, prior)
         when is_map_key(fields, :collection_id) or is_map_key(fields, :receipt_id) do
      with {:ok, _} <- SyntheticCollectionLedger.record(purchase, fields, is_nil(prior)) do
        :ok
      end
    end

    defp record_collection(_fields, _purchase, _prior), do: :ok

    defp commit_payment(%VerifiedPayment{} = prior, _purchase, _delivery, _source), do: prior

    defp commit_payment(nil, %Purchase{id: purchase_id} = purchase, delivery, source) do
      with {:ok, payment} <-
             Ash.create(VerifiedPayment, Map.put(source, :purchase_id, purchase_id),
               action: :apply,
               authorize?: false
             ),
           {:ok, _consequence} <-
             Ash.create(
               PaymentConsequence,
               %{purchase_id: purchase_id, payment_id: payment.id, delivery_kind: delivery},
               action: :establish,
               authorize?: false
             ),
           :ok <- AssessmentAdmissions.record_payment(purchase, delivery) do
        payment
      end
    end
  else
    def apply_payment_observation(_observation), do: {:error, :payment_unavailable}
    @doc "Fixture evidence processing is disabled outside TEST."
    @spec apply_hosted_payment_evidence(Ecto.UUID.t()) :: {:error, :unavailable}
    def apply_hosted_payment_evidence(_id), do: {:error, :unavailable}
  end

  @doc """
  Return the immutable paid source for Entitlements. This internal interface
  exposes only source and recipient identifiers. Call after the payment commit.
  """
  @spec paid_plan_source(String.t()) :: {:ok, map()} | {:error, :source_unavailable}
  def paid_plan_source(consequence_id) do
    with {:ok, %PaymentConsequence{delivery_kind: :plan} = consequence} <-
           Ash.get(PaymentConsequence, consequence_id, authorize?: false),
         {:ok, %VerifiedPayment{purchase_id: purchase_id, collection_kind: :primary} = payment} <-
           Ash.get(VerifiedPayment, consequence.payment_id, authorize?: false),
         true <- eligible_plan_payment?(payment),
         true <- purchase_id == consequence.purchase_id,
         {:ok, %Purchase{recipient_id: recipient_id}} <-
           Ash.get(Purchase, purchase_id, authorize?: false) do
      {:ok,
       %{purchase_id: purchase_id, payment_id: consequence.payment_id, recipient_id: recipient_id}}
    else
      _ -> {:error, :source_unavailable}
    end
  end

  if Mix.env() == :test do
    defp eligible_plan_payment?(_payment), do: true
  else
    defp eligible_plan_payment?(payment), do: is_nil(payment.fixture_receipt_id)
  end

  @doc """
  Recover the open consequence for an accepted purchase. The background
  scheduler independently locates the same open rows after process loss.
  """
  @spec open_plan_payment_consequences(String.t()) ::
          {:ok, [String.t()]} | {:error, :source_unavailable}
  def open_plan_payment_consequences(purchase_id) do
    query =
      Ash.Query.filter(
        PaymentConsequence,
        purchase_id == ^purchase_id and delivery_kind == :plan and is_nil(fulfilled_at)
      )

    case Ash.read(query, authorize?: false) do
      {:ok, consequences} -> {:ok, Enum.map(consequences, & &1.id)}
      _ -> {:error, :source_unavailable}
    end
  end

  @doc """
  Deliver the committed payment consequence and acknowledge it after the
  Entitlements transaction commits. Retry reuses the original right and
  completes the original consequence after either process-loss cut. A TEST-only
  suppression or prior correction can settle delivery as `:withheld`.
  """
  @spec deliver_plan_payment_consequence(String.t()) ::
          {:ok, Entitlements.PlanRight.t() | :withheld} | {:error, :delivery_unavailable}
  def deliver_plan_payment_consequence(consequence_id) do
    with {:ok, right} <- Entitlements.grant_paid_plan(consequence_id),
         {:ok, %PaymentConsequence{}} <-
           Ash.transact(PaymentConsequence, fn -> acknowledge(consequence_id) end) do
      {:ok, right}
    else
      _ -> {:error, :delivery_unavailable}
    end
  end

  defp acknowledge(consequence_id) do
    query =
      PaymentConsequence
      |> Ash.Query.filter(id == ^consequence_id)
      |> Ash.Query.lock(:for_update)

    case Ash.read_one(query, authorize?: false) do
      {:ok, %PaymentConsequence{fulfilled_at: nil} = open} ->
        case Ash.update(open, %{fulfilled_at: DateTime.utc_now()},
               action: :acknowledge,
               authorize?: false
             ) do
          {:ok, fulfilled} -> fulfilled
          {:error, error} -> {:error, error}
        end

      {:ok, %PaymentConsequence{} = fulfilled} ->
        fulfilled

      _ ->
        {:error, :delivery_unavailable}
    end
  end
end
