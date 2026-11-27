defmodule NewYou.Commerce.FixtureRefunds do
  @moduledoc false

  alias NewYou.Commerce.{
    FixtureRefund,
    FixtureRefundEvidence,
    FixtureRefundReceipt,
    HostedDispatch,
    OfferAdmission,
    PaystackCheckout,
    Purchase,
    VerifiedPayment
  }

  alias NewYou.{Entitlements, Identity, Repo}
  alias NewYou.Proof.PlanPaymentObservation
  alias Ecto.Adapters.SQL.Sandbox

  require Ash.Query

  @unavailable {:error, :refund_unavailable}
  @progress %{
    unresolved: 0,
    pending: 1,
    processing: 2,
    needs_attention: 3,
    failed: 4,
    insufficient_balance: 4,
    processed: 5
  }

  @spec authorize(map(), term()) :: {:ok, FixtureRefund.t()} | {:error, :refund_unavailable}
  def authorize(credentials, proof) do
    with {:ok, fields} <- PlanPaymentObservation.verify(proof),
         %{scope: :hosted_refund_authorization, purchase_id: purchase_id} <- fields,
         true <- map_size(fields) == 10,
         {:ok, ^purchase_id} <- Ecto.UUID.cast(purchase_id),
         {:ok, %FixtureRefund{} = refund} <-
           transact(fn -> admit(credentials, fields) end) do
      {:ok, refund}
    else
      _ -> @unavailable
    end
  end

  @doc false
  @spec establish_excess_locked(Purchase.t(), VerifiedPayment.t()) ::
          FixtureRefund.t() | {:error, :refund_unavailable}
  def establish_excess_locked(
        %{id: id, quote_id: quote, currency: "ZAR"} = purchase,
        %VerifiedPayment{purchase_id: id, collection_kind: :excess} = collection
      )
      when not is_nil(quote) do
    if Ash.DataLayer.in_transaction?(Purchase) do
      fields = %{
        scope: :hosted_refund_authorization,
        purchase_id: id,
        quote_id: quote,
        payment_id: collection.id,
        transaction_id: collection.fixture_transaction_id,
        payer_id: purchase.payer_id,
        recipient_id: purchase.recipient_id,
        amount_minor: purchase.amount_minor,
        currency: "ZAR",
        allocation: :excess
      }

      establish(purchase, fields)
    else
      @unavailable
    end
  end

  @spec reserve(map(), Ecto.UUID.t()) :: {:ok, FixtureRefund.t()} | {:error, :refund_unavailable}
  def reserve(credentials, id) do
    update_for_payer(credentials, id, fn
      %{state: :owed} = intent, _purchase ->
        mutate(intent, :reserve, %{})

      intent, _purchase ->
        intent
    end)
  end

  @spec dispatch(map(), Ecto.UUID.t()) :: {:ok, FixtureRefund.t()} | {:error, :refund_unavailable}
  def dispatch(credentials, id) do
    with false <- Ash.DataLayer.in_transaction?(FixtureRefund),
         {:ok, result} <- update_for_payer(credentials, id, &claim/2) do
      dispatch_committed(result)
    else
      _ -> @unavailable
    end
  end

  defp dispatch_committed(%FixtureRefund{} = refund), do: {:ok, refund}

  defp dispatch_committed({:claimed, refund, listener}) do
    if committed_claim?(refund) do
      checkpoint(:claim_committed)
      post_once(refund, listener)
      {:ok, refund}
    else
      @unavailable
    end
  end

  defp claim(%{state: :reserved} = refund, purchase) do
    with {:ok, listener} <- pinned_listener(purchase),
         %FixtureRefund{} = claimed <-
           mutate(refund, :claim, %{
             claim_id: Ash.UUID.generate(),
             verify_after: DateTime.add(DateTime.utc_now(), 30)
           }) do
      checkpoint(:claim_written)
      {:claimed, claimed, listener}
    else
      _ -> @unavailable
    end
  end

  defp claim(%{claim_id: nil}, _), do: @unavailable
  defp claim(refund, _), do: refund

  defp post_once(refund, listener) do
    checkpoint(:post_attempted)
    refund |> PaystackCheckout.build_refund(listener) |> Req.Request.run_request()
    :ok
  rescue
    _ -> :ok
  end

  defp committed_claim?(%{id: id, claim_id: claim, reference: ref}) do
    independently_visible?(fn ->
      match?(
        {:ok, %FixtureRefund{claim_id: ^claim, reference: ^ref}},
        Ash.get(FixtureRefund, id, authorize?: false, error?: false, timeout: 1_000)
      )
    end)
  end

  # Sandbox can acknowledge a savepoint while the enclosing transaction can
  # still roll back. An unboxed connection must see the exact winning claim.
  @doc false
  def independently_visible?(read) do
    observer = Task.async(fn -> independently_read(read) end)

    case Task.yield(observer, 2_000) do
      {:ok, result} ->
        result

      nil ->
        Task.shutdown(observer, :brutal_kill)
        false
    end
  end

  @spec apply_receipt(Ecto.UUID.t()) :: :ok | {:error, :refund_unavailable}
  def apply_receipt(id) do
    case transact(fn -> classify_receipt(id) end) do
      {:ok, :ok} -> :ok
      _ -> @unavailable
    end
  end

  defp classify_receipt(id) do
    query = FixtureRefundReceipt |> Ash.Query.filter(id == ^id) |> Ash.Query.lock(:for_update)

    case Ash.read_one(query, authorize?: false) do
      {:ok, %FixtureRefundReceipt{state: :pending} = receipt} ->
        with {:ok, state} <- reconcile(receipt),
             {:ok, _} <-
               Ash.update(receipt, %{state: state}, action: :classify, authorize?: false) do
          :ok
        end

      {:ok, %FixtureRefundReceipt{}} ->
        :ok

      _ ->
        @unavailable
    end
  end

  defp reconcile(%{outcome: outcome})
       when outcome in [:not_found, :timeout, :rate_limited, :unavailable],
       do: {:ok, :unresolved}

  defp reconcile(%{outcome: :unqualified}), do: {:ok, :quarantined}

  defp reconcile(%{source: :read, requested_reference: request, reference: reference})
       when request != reference,
       do: {:ok, :quarantined}

  defp reconcile(receipt) do
    case FixtureRefund
         |> Ash.Query.filter(reference == ^receipt.reference)
         |> Ash.read_one(authorize?: false) do
      {:ok, %FixtureRefund{id: id}} ->
        with {:ok, refund, _purchase} <- lock_refund_source(id) do
          qualify_progress(refund, receipt)
        end

      {:ok, nil} ->
        {:ok, :quarantined}

      error ->
        error
    end
  end

  defp qualify_progress(refund, receipt) do
    cond do
      is_nil(refund.claim_id) or refund.transaction_id != receipt.transaction_id or
        refund.amount_minor != receipt.amount_minor or refund.currency != receipt.currency ->
        {:ok, :quarantined}

      refund.provider_refund_id not in [nil, receipt.provider_refund_id] ->
        {:ok, :quarantined}

      Map.fetch!(@progress, receipt.outcome) <= Map.fetch!(@progress, refund.state) ->
        {:ok, :stale}

      true ->
        record_progress(refund, receipt)
    end
  end

  defp record_progress(refund, %{outcome: :processed} = receipt) do
    with %FixtureRefund{} <-
           mutate(refund, :satisfy, %{
             provider_refund_id: receipt.provider_refund_id,
             processed_receipt_id: receipt.id,
             processed_at: DateTime.utc_now()
           }),
         do: {:ok, :applied}
  end

  defp record_progress(refund, receipt) do
    with %FixtureRefund{} <-
           mutate(refund, :record_progress, %{
             state: receipt.outcome,
             provider_refund_id: receipt.provider_refund_id
           }),
         do: {:ok, :applied}
  end

  defp independently_read(read) do
    Sandbox.unboxed_run(Repo, fn -> Repo.without_query_telemetry(read) end)
  rescue
    _ -> false
  end

  @spec read_due(Ecto.UUID.t()) :: :ok | {:error, :refund_unavailable}
  def read_due(id) do
    with false <- Ash.DataLayer.in_transaction?(FixtureRefund),
         {:ok, reservation} <- transact(fn -> reserve_read(id) end) do
      read_committed(reservation)
    else
      _ -> @unavailable
    end
  end

  defp reserve_read(id) do
    with {:ok, refund, purchase} <- lock_refund_source(id),
         {:ok, listener} <- pinned_listener(purchase) do
      now = DateTime.utc_now()

      if refund.verify_after && refund.verify_round < 6 &&
           DateTime.compare(refund.verify_after, now) != :gt do
        reserve_read(refund, listener, now)
      else
        :not_due
      end
    end
  end

  defp reserve_read(refund, listener, now) do
    round = refund.verify_round + 1
    next = if round < 6, do: DateTime.add(now, 30 * Integer.pow(2, round - 1))

    with %FixtureRefund{} = reserved <-
           mutate(refund, :defer_read, %{verify_round: round, verify_after: next}) do
      {reserved, listener}
    end
  end

  defp read_committed(:not_due), do: :ok

  defp read_committed({%{id: id, verify_round: round, verify_after: due} = refund, listener}) do
    visible? =
      independently_visible?(fn ->
        match?(
          {:ok, %FixtureRefund{verify_round: ^round, verify_after: ^due, state: state}}
          when state != :processed,
          Ash.get(FixtureRefund, id, authorize?: false, error?: false, timeout: 1_000)
        )
      end)

    if visible? and (is_nil(due) or DateTime.after?(due, DateTime.utc_now())),
      do: FixtureRefundEvidence.read(refund, listener),
      else: @unavailable
  end

  @spec deliver(Ecto.UUID.t()) :: :ok | {:error, :refund_unavailable}
  def deliver(id) do
    with :ok <- Entitlements.apply_fixture_refund(id),
         {:ok, %FixtureRefund{}} <- transact(fn -> acknowledge(id) end) do
      :ok
    else
      _ -> @unavailable
    end
  end

  @doc false
  @spec locked_component_effect(Ecto.UUID.t()) ::
          {:ok, map(), atom()} | {:error, :refund_unavailable}
  def locked_component_effect(id) do
    with true <- Ash.DataLayer.in_transaction?(Purchase),
         {:ok, %{state: :processed, allocation: component} = refund, purchase}
         when component in [:plan, :assessment] <- lock_refund_source(id) do
      {:ok,
       %{
         purchase_id: purchase.id,
         payment_id: refund.payment_id,
         recipient_id: purchase.recipient_id,
         ended_components: MapSet.new([component])
       }, component}
    else
      _ -> @unavailable
    end
  end

  @doc false
  @spec plan_ended?(map()) :: {:ok, boolean()} | {:error, term()}
  def plan_ended?(%{purchase_id: purchase, payment_id: payment}) do
    if Ash.DataLayer.in_transaction?(Purchase) do
      FixtureRefund
      |> Ash.Query.filter(
        purchase_id == ^purchase and payment_id == ^payment and allocation == :plan and
          state == :processed
      )
      |> Ash.exists(authorize?: false)
    else
      @unavailable
    end
  end

  defp acknowledge(id) do
    case lock_refund_source(id) do
      {:ok, %{state: :processed, allocation: component, acknowledged_at: nil} = refund, _}
      when component in [:plan, :assessment] ->
        mutate(refund, :acknowledge, %{acknowledged_at: DateTime.utc_now()})

      {:ok, %{state: :processed, allocation: component} = refund, _}
      when component in [:plan, :assessment] ->
        refund

      _ ->
        @unavailable
    end
  end

  defp pinned_listener(%{attempt_id: attempt_id}) do
    case Ash.get(HostedDispatch, attempt_id, authorize?: false) do
      {:ok, %{fixture_certificate: certificate, fixture_port: port}}
      when is_binary(certificate) and byte_size(certificate) in 1..8_192 and port in 1..65_535 ->
        {:ok, %{port: port, certificate: certificate}}

      _ ->
        @unavailable
    end
  end

  defp update_for_payer(credentials, id, operation) do
    with {:ok, ^id} <- Ecto.UUID.cast(id),
         {:ok, result} <- transact(fn -> authorized_refund(credentials, id, operation) end) do
      {:ok, result}
    else
      _ -> @unavailable
    end
  end

  defp authorized_refund(credentials, id, operation) do
    with {:ok, refund, purchase} <- lock_refund_source(id),
         {:ok, %{account_id: payer}} <- Identity.authorize_canonical_session(credentials),
         true <- payer == refund.payer_id,
         :ok <- OfferAdmission.current_parties_privacy(purchase) do
      operation.(refund, purchase)
    else
      _ -> @unavailable
    end
  end

  defp lock_refund_source(id) do
    with {:ok, %FixtureRefund{purchase_id: purchase_id}} <-
           Ash.get(FixtureRefund, id, authorize?: false),
         {:ok, %Purchase{} = purchase} <- lock_purchase(purchase_id),
         {:ok, %FixtureRefund{} = current} <-
           FixtureRefund
           |> Ash.Query.filter(id == ^id)
           |> Ash.Query.lock(:for_update)
           |> Ash.read_one(authorize?: false) do
      {:ok, current, purchase}
    else
      _ -> @unavailable
    end
  end

  defp mutate(refund, action, changes) do
    with {:ok, updated} <- Ash.update(refund, changes, action: action, authorize?: false),
         do: updated
  end

  defp checkpoint(stage) do
    :telemetry.execute([:new_you, :commerce, :fixture_refund, :checkpoint], %{count: 1}, %{
      stage: stage
    })
  end

  defp admit(credentials, fields) do
    with {:ok, %Purchase{} = purchase} <- lock_purchase(fields.purchase_id),
         {:ok, %{account_id: payer}} <- Identity.authorize_canonical_session(credentials),
         true <- payer == purchase.payer_id,
         :ok <- OfferAdmission.current_parties_privacy(purchase),
         {:ok, %VerifiedPayment{fixture_receipt_id: receipt_id} = payment}
         when not is_nil(receipt_id) <-
           Ash.get(VerifiedPayment, fields[:payment_id], authorize?: false),
         {:ok, terms} <- OfferAdmission.accepted_terms(purchase),
         true <- authorized_terms?(purchase, payment, terms, fields) do
      establish(purchase, fields)
    else
      _ -> @unavailable
    end
  end

  defp authorized_terms?(
         purchase,
         payment,
         terms,
         %{
           quote_id: quote,
           payer_id: payer,
           recipient_id: recipient,
           transaction_id: transaction,
           amount_minor: amount,
           allocation: allocation,
           currency: "ZAR"
         }
       ) do
    purchase.quote_id == quote and purchase.payer_id == payer and
      purchase.recipient_id == recipient and payment.purchase_id == purchase.id and
      payment.fixture_transaction_id == transaction and
      is_integer(amount) and amount > 0 and
      allocation_minor(purchase, payment, terms, allocation) == amount
  end

  defp authorized_terms?(_, _, _, _), do: false

  defp allocation_minor(purchase, %{collection_kind: :excess}, _terms, :excess),
    do: purchase.amount_minor

  defp allocation_minor(_, %{collection_kind: :primary}, terms, allocation),
    do: OfferAdmission.accepted_component_minor(terms, allocation)

  defp allocation_minor(_, _, _, _), do: nil

  defp establish(purchase, fields) do
    fingerprint = HostedDispatch.source_digest(fields)

    case read_allocation(fields.payment_id, fields.allocation) do
      {:ok, nil} ->
        with {:ok, admitted} <- admitted_minor(fields.payment_id),
             true <- admitted + fields.amount_minor <= purchase.amount_minor,
             {:ok, refund} <- create_request(fields, fingerprint) do
          refund
        else
          _ -> @unavailable
        end

      {:ok, %FixtureRefund{fingerprint: ^fingerprint} = refund} ->
        refund

      _ ->
        @unavailable
    end
  end

  defp read_allocation(payment_id, allocation) do
    FixtureRefund
    |> Ash.Query.filter(payment_id == ^payment_id and allocation == ^allocation)
    |> Ash.read_one(authorize?: false)
  end

  defp admitted_minor(payment_id) do
    FixtureRefund
    |> Ash.Query.filter(payment_id == ^payment_id)
    |> Ash.sum(:amount_minor, authorize?: false, default: 0)
  end

  defp create_request(fields, fingerprint) do
    attrs =
      fields
      |> Map.drop([:scope, :recipient_id])
      |> Map.merge(%{
        fingerprint: fingerprint,
        reference: Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
      })

    Ash.create(FixtureRefund, attrs, action: :establish, authorize?: false)
  end

  defp lock_purchase(id) do
    Purchase
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one(authorize?: false)
  end

  defp transact(fun), do: Repo.without_query_telemetry(fn -> Ash.transact(Purchase, fun) end)
end
