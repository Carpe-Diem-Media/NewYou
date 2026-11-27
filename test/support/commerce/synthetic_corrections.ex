defmodule NewYou.Commerce.SyntheticCorrections do
  @moduledoc """
  Commerce's TEST-only adjudication interface for qualified synthetic orders and
  collection evidence. It owns the fixture's accepted snapshot and excess claim.
  """

  alias NewYou.Commerce.{
    OfferAdmission,
    Purchase,
    SyntheticCollectionLedger,
    SyntheticCorrection,
    SyntheticCorrectionReceipt,
    SyntheticExcessClaim,
    SyntheticOrder,
    VerifiedPayment
  }

  alias NewYou.Entitlements.SyntheticRights
  alias NewYou.Identity
  alias NewYou.Proof.PlanPaymentObservation
  require Ash.Query

  @allocation_fields [
    :operation_id,
    :payer_id,
    :recipient_id,
    :price_version,
    :currency,
    :amount_minor,
    :plan_list_minor,
    :plan_discount_minor,
    :assessment_list_minor,
    :assessment_discount_minor
  ]

  @doc """
  Accept a signed fixture for the exact verified payer and recipient. Repeating
  the operation returns the original snapshot. Changed input rolls back.
  """
  @spec accept(map(), map(), PlanPaymentObservation.t()) ::
          {:ok, SyntheticOrder.t()} | {:error, :source_unavailable}
  def accept(payer_credentials, recipient_credentials, fixture) do
    with {:ok, %{scope: :accepted_correction_fixture, price_version: version} = fields} <-
           PlanPaymentObservation.verify(fixture),
         true <- version in ["synthetic-bundle-v1", "synthetic-bundle-v2"],
         {:ok, %SyntheticOrder{} = order} <-
           Ash.transact(SyntheticOrder, fn ->
             accept_locked(payer_credentials, recipient_credentials, fields)
           end) do
      {:ok, order}
    else
      _ -> {:error, :source_unavailable}
    end
  end

  @doc """
  Apply signed collection evidence to the exact accepted synthetic order.
  A replay returns the original applied collection identity.
  """
  @spec observe_collection(PlanPaymentObservation.t()) ::
          {:ok, %{id: String.t()}} | {:error, :payment_unavailable}
  def observe_collection(observation) do
    with {:ok,
          %{scope: :collection, environment: :test, integration: :synthetic, status: :succeeded} =
            fields} <- PlanPaymentObservation.verify(observation),
         {:ok, %{id: _} = payment} <-
           Ash.transact(SyntheticOrder, fn -> observe_locked(fields) end) do
      {:ok, payment}
    else
      _ -> {:error, :payment_unavailable}
    end
  end

  defp accept_locked(payer_credentials, recipient_credentials, fields) do
    attrs = Map.take(fields, @allocation_fields)

    with %{payer_id: payer, recipient_id: recipient} <- attrs,
         true <-
           canonical_parties?([{payer, payer_credentials}, {recipient, recipient_credentials}]),
         {:ok, order} <-
           Ash.create(SyntheticOrder, attrs, action: :accept_fixture, authorize?: false),
         ^attrs <- Map.take(order, @allocation_fields) do
      order
    else
      _ -> {:error, :source_unavailable}
    end
  end

  defp canonical_parties?(parties) do
    parties
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.all?(fn {id, credentials} ->
      match?({:ok, %{account_id: ^id}}, Identity.authorize_canonical_session(credentials))
    end)
  end

  defp observe_locked(
         %{source_id: id, operation_id: operation, amount_minor: amount, currency: currency} =
           fields
       ) do
    with {:ok,
          %SyntheticOrder{operation_id: ^operation, amount_minor: ^amount, currency: ^currency} =
            order} <-
           lock_order(id),
         {:ok, existing} <- SyntheticCollectionLedger.accepted_collection(id),
         {:ok, applied} <- SyntheticCollectionLedger.record(order, fields, is_nil(existing)) do
      %{id: applied.collection_id}
    else
      _ -> {:error, :payment_unavailable}
    end
  end

  defp observe_locked(_), do: {:error, :payment_unavailable}

  defp lock_order(id) do
    SyntheticOrder
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one(authorize?: false)
  end

  @doc """
  Record qualified correction evidence. Unattributable evidence for a known
  operation remains unresolved. A final component end or returned excess
  has one durable consequence, including on replay with a fresh receipt.
  """
  @spec observe_correction(PlanPaymentObservation.t()) ::
          {:ok, SyntheticCorrection.t()} | {:error, :correction_unavailable}
  def observe_correction(observation) do
    with {:ok, %{scope: :correction, integration: :synthetic, environment: :test} = fields} <-
           PlanPaymentObservation.verify(observation),
         {:ok, %SyntheticCorrection{} = result} <-
           Ash.transact(SyntheticCorrection, fn -> adjudicate(fields) end) do
      {:ok, result}
    else
      _ -> {:error, :correction_unavailable}
    end
  end

  @doc "Discover committed, unacknowledged effects for this source even when no job exists."
  @spec open_consequences(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def open_consequences(source_id) do
    with {:ok, rows} <-
           SyntheticCorrection
           |> Ash.Query.filter(
             source_id == ^source_id and kind != :unresolved and is_nil(acknowledged_at)
           )
           |> Ash.read(authorize?: false) do
      {:ok, Enum.map(rows, & &1.id)}
    end
  end

  @doc """
  Ask Entitlements to converge from current owner facts. Acknowledge in a
  separate transaction. An acknowledgement never changes money or entitlement state.
  """
  @spec deliver(String.t()) :: {:ok, SyntheticCorrection.t()} | {:error, :delivery_unavailable}
  def deliver(id) do
    with false <- Ash.DataLayer.in_transaction?(SyntheticCorrection),
         :ok <- SyntheticRights.apply_correction(id),
         {:ok, %SyntheticCorrection{} = acknowledged} <-
           Ash.transact(SyntheticCorrection, fn -> acknowledge(id) end) do
      {:ok, acknowledged}
    else
      _ -> {:error, :delivery_unavailable}
    end
  end

  @doc "Resolve the exact corrective consequence and hold its paid source lock."
  @spec locked_effect(String.t()) :: {:ok, map(), SyntheticCorrection.t()} | {:error, term()}
  def locked_effect(id) do
    with {:ok, %SyntheticCorrection{source_id: source, kind: kind} = effect}
         when kind != :unresolved <-
           Ash.get(SyntheticCorrection, id, authorize?: false, error?: false),
         {:ok, scope} <- locked_paid_scope(source) do
      {:ok, scope, effect}
    else
      _ -> {:error, :source_unavailable}
    end
  end

  @doc """
  Read current paid scope and final component ends for Entitlements while
  holding the source lock in its transaction. A missing application fails closed.
  """
  @spec locked_paid_scope(String.t()) :: {:ok, map()} | {:error, term()}
  def locked_paid_scope(id) do
    with true <- Ash.DataLayer.in_transaction?(SyntheticCorrection),
         {:ok, source} <- lock_source(id),
         {:ok, %{collection_id: collection_id}} <-
           SyntheticCollectionLedger.accepted_collection(id) do
      paid_scope(source, collection_id)
    else
      _ -> {:error, :source_unavailable}
    end
  end

  @doc """
  Read the final Assessment component correction for the caller's locked paid
  source. Its acknowledgement is written only after Entitlements commits the end.
  """
  @spec assessment_end_for_locked_source(Ecto.UUID.t()) ::
          {:ok, SyntheticCorrection.t() | nil} | {:error, term()}
  def assessment_end_for_locked_source(id) do
    if Ash.DataLayer.in_transaction?(SyntheticCorrection) do
      SyntheticCorrection
      |> Ash.Query.filter(
        source_id == ^id and kind == :component_end and component == :assessment
      )
      |> Ash.read_one(authorize?: false)
    else
      {:error, :source_unavailable}
    end
  end

  @doc """
  Resolve the original P1 grant under the same source lock as adjudication.
  Receipts from the original P1 case have no explicit collection identity.
  """
  @spec locked_p1_grant_scope(String.t()) ::
          {:ok, {:legacy | :qualified | :hosted_ended | :hosted_suspended, map()}}
          | {:error, term()}
  def locked_p1_grant_scope(consequence_id) do
    with true <- Ash.DataLayer.in_transaction?(SyntheticCorrection),
         {:ok, %{purchase_id: id} = immutable} <- NewYou.Commerce.paid_plan_source(consequence_id),
         {:ok, %Purchase{} = source} <- lock_source(id),
         {:ok, original} <- SyntheticCollectionLedger.accepted_collection(id) do
      p1_scope(original, immutable, source)
    else
      _ -> {:error, :source_unavailable}
    end
  end

  defp p1_scope(nil, immutable, _source) do
    with {:ok, false} <- NewYou.Commerce.FixtureRefunds.plan_ended?(immutable),
         {:ok, effect} <-
           NewYou.Commerce.FixtureDisputes.right_effect(immutable.payment_id, :plan) do
      case effect do
        :end -> {:ok, {:hosted_ended, immutable}}
        :suspend -> {:ok, {:hosted_suspended, immutable}}
        :available -> {:ok, {:legacy, immutable}}
      end
    else
      {:ok, true} -> {:ok, {:hosted_ended, immutable}}
      error -> error
    end
  end

  defp p1_scope(%{collection_id: collection_id}, _immutable, source) do
    with {:ok, scope} <- paid_scope(source, collection_id), do: {:ok, {:qualified, scope}}
  end

  defp paid_scope(source, collection_id) do
    id = source.id

    with {:ok, payment_id} <- applied_payment(source, collection_id),
         {:ok, components} <- components(source),
         {:ok, rows} <-
           SyntheticCorrection
           |> Ash.Query.filter(source_id == ^id and kind == :component_end)
           |> Ash.read(authorize?: false) do
      {:ok,
       %{
         purchase_id: id,
         payment_id: payment_id,
         recipient_id: source.recipient_id,
         components: components,
         materialize?: legacy_source?(source),
         ended_components: MapSet.new(rows, & &1.component)
       }}
    end
  end

  @doc """
  Read the minimum projection for a current canonical session and an exact,
  signed TEST-only grant. Role labels alone confer no visibility or write authority.
  """
  @spec read_evidence(map(), String.t(), :finance | :support | :audit, term()) ::
          {:ok, map()} | {:error, :read_unavailable}
  def read_evidence(credentials, source_id, role, grant) do
    with true <- role in [:finance, :support, :audit],
         {:ok,
          %{
            scope: :synthetic_correction_read,
            source_id: ^source_id,
            role: ^role,
            staff_id: staff_id
          }} <- PlanPaymentObservation.verify(grant),
         {:ok, projection} when is_map(projection) <-
           Ash.transact(SyntheticCorrection, fn ->
             scoped_projection(credentials, staff_id, source_id, role)
           end) do
      {:ok, projection}
    else
      _ -> {:error, :read_unavailable}
    end
  end

  defp scoped_projection(credentials, staff_id, source_id, role) do
    with {:ok, %{account_id: ^staff_id}} <- Identity.authorize_canonical_session(credentials),
         {:ok, %{id: ^source_id}} <- lock_source(source_id),
         {:ok, values} <- projection(source_id, role) do
      values
    else
      _ -> {:error, :read_unavailable}
    end
  end

  defp projection(id, :audit) do
    query = Ash.Query.filter(SyntheticCorrection, source_id == ^id)

    with {:ok, rows} <- Ash.read(query, authorize?: false) do
      {:ok, %{correction_kinds: rows |> Enum.map(& &1.kind) |> Enum.uniq() |> Enum.sort()}}
    end
  end

  defp projection(id, role) do
    case Ash.get(SyntheticExcessClaim, id, authorize?: false, error?: false) do
      {:ok, nil} ->
        {:ok, %{status: :none}}

      {:ok, claim} ->
        status = if is_nil(claim.satisfied_at), do: :owed, else: :satisfied
        {:ok, claim_projection(role, claim, status)}

      {:error, _} = error ->
        error
    end
  end

  defp claim_projection(:support, _, status), do: %{status: status}

  defp claim_projection(:finance, claim, status) do
    claim
    |> Map.take([:claimant_id, :amount_minor, :currency])
    |> Map.put(:status, status)
  end

  defp adjudicate(%{source_id: id, operation_id: operation, receipt_id: receipt} = fields) do
    with {:ok, receipt_id} <- Ecto.UUID.cast(receipt),
         {:ok, %{operation_id: ^operation} = source} <- lock_source(id),
         {:ok, original} <- SyntheticCollectionLedger.accepted_collection(id),
         {:ok, claim} <- Ash.get(SyntheticExcessClaim, id, authorize?: false, error?: false),
         decision = decide(source, original, claim, fields),
         {:ok, correction} <- record_decision(source.id, receipt_id, decision, fields),
         :ok <- settle_claim(correction, claim) do
      correction
    else
      _ -> {:error, :correction_unavailable}
    end
  end

  defp adjudicate(_), do: {:error, :correction_unavailable}

  defp decide(source, original, claim, fields) do
    case fields do
      %{
        status: :final,
        payer_id: payer,
        recipient_id: recipient,
        price_version: version,
        currency: currency
      }
      when payer == source.payer_id and recipient == source.recipient_id and
             version == source.price_version and currency == source.currency ->
        attribute_correction(source, original, claim, fields)

      _ ->
        %{kind: :unresolved, component: nil, amount_minor: nil}
    end
  end

  defp attribute_correction(
         source,
         %{collection_id: collection},
         _,
         %{
           reason: :unused_component,
           collection_id: collection,
           component: component,
           amount_minor: amount
         } = fields
       ) do
    case component_amount(source, component, fields) do
      ^amount when is_integer(amount) ->
        %{kind: :component_end, component: component, amount_minor: amount}

      _ ->
        %{kind: :unresolved, component: nil, amount_minor: nil}
    end
  end

  defp attribute_correction(
         _,
         _,
         %{collection_id: collection, amount_minor: amount},
         %{
           reason: :excess_returned,
           collection_id: collection,
           amount_minor: amount
         } = fields
       ) do
    if is_nil(Map.get(fields, :component)) do
      %{kind: :excess_satisfied, component: nil, amount_minor: amount}
    else
      %{kind: :unresolved, component: nil, amount_minor: nil}
    end
  end

  defp attribute_correction(_, _, _, _),
    do: %{kind: :unresolved, component: nil, amount_minor: nil}

  defp component_amount(%Purchase{quote_id: nil, amount_minor: amount}, :plan, _), do: amount

  defp component_amount(%Purchase{quote_id: id} = purchase, component, %{quote_id: id})
       when not is_nil(id) do
    with {:ok, terms} <- OfferAdmission.accepted_terms(purchase) do
      OfferAdmission.accepted_component_minor(terms, component)
    end
  end

  defp component_amount(%SyntheticOrder{} = order, :plan, _),
    do: order.plan_list_minor - order.plan_discount_minor

  defp component_amount(%SyntheticOrder{} = order, :assessment, _),
    do: order.assessment_list_minor - order.assessment_discount_minor

  defp component_amount(_, _, _), do: nil

  defp record_decision(source_id, receipt_id, decision, fields) do
    fingerprint = :crypto.hash(:sha256, :erlang.term_to_binary(fields, [:deterministic]))

    case Ash.get(SyntheticCorrectionReceipt, receipt_id, authorize?: false, error?: false) do
      {:ok, nil} ->
        attrs = Map.merge(decision, %{source_id: source_id, receipt_id: receipt_id})
        bind_effect(attrs, fingerprint)

      {:ok, %{fingerprint: ^fingerprint, correction_id: id}} ->
        Ash.get(SyntheticCorrection, id, authorize?: false)

      _ ->
        {:error, :changed_receipt}
    end
  end

  defp bind_effect(attrs, fingerprint) do
    with {:ok, effect} <- find_or_create_effect(attrs.source_id, attrs.kind, attrs),
         {:ok, _} <-
           Ash.create(
             SyntheticCorrectionReceipt,
             %{receipt_id: attrs.receipt_id, fingerprint: fingerprint, correction_id: effect.id},
             action: :bind,
             authorize?: false
           ) do
      {:ok, effect}
    end
  end

  defp find_or_create_effect(_source_id, :unresolved, attrs), do: create_decision(attrs)

  defp find_or_create_effect(source_id, kind, attrs) do
    query = Ash.Query.filter(SyntheticCorrection, source_id == ^source_id and kind == ^kind)

    query =
      if kind == :component_end,
        do: Ash.Query.filter(query, component == ^attrs.component),
        else: query

    case Ash.read_one(query, authorize?: false) do
      {:ok, nil} -> create_decision(attrs)
      {:ok, saved} -> {:ok, saved}
      {:error, _} = error -> error
    end
  end

  defp create_decision(attrs),
    do: Ash.create(SyntheticCorrection, attrs, action: :record, authorize?: false)

  defp settle_claim(%{kind: :excess_satisfied}, %{satisfied_at: nil} = claim) do
    with {:ok, _} <-
           Ash.update(claim, %{satisfied_at: DateTime.utc_now()},
             action: :satisfy,
             authorize?: false
           ) do
      :ok
    end
  end

  defp settle_claim(_, _), do: :ok

  defp acknowledge(id) do
    query =
      SyntheticCorrection
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.lock(:for_update)

    case Ash.read_one(query, authorize?: false) do
      {:ok, %SyntheticCorrection{acknowledged_at: nil} = effect} -> update_acknowledgement(effect)
      {:ok, %SyntheticCorrection{} = effect} -> effect
      _ -> {:error, :delivery_unavailable}
    end
  end

  defp update_acknowledgement(effect) do
    with {:ok, updated} <-
           Ash.update(effect, %{acknowledged_at: DateTime.utc_now()},
             action: :acknowledge,
             authorize?: false
           ) do
      updated
    end
  end

  defp lock_source(id) do
    query = Purchase |> Ash.Query.filter(id == ^id) |> Ash.Query.lock(:for_update)

    case Ash.read_one(query, authorize?: false) do
      {:ok, nil} -> lock_order(id)
      result -> result
    end
  end

  defp applied_payment(%SyntheticOrder{}, collection_id), do: {:ok, collection_id}

  defp applied_payment(%Purchase{id: id}, _) do
    with {:ok, %VerifiedPayment{id: payment_id}} <-
           VerifiedPayment
           |> Ash.Query.filter(purchase_id == ^id and collection_kind == :primary)
           |> Ash.read_one(authorize?: false) do
      {:ok, payment_id}
    end
  end

  defp legacy_source?(%Purchase{quote_id: id}), do: is_nil(id)
  defp legacy_source?(%SyntheticOrder{}), do: true

  defp components(%Purchase{quote_id: nil}), do: {:ok, [:plan]}

  defp components(%Purchase{} = purchase) do
    with {:ok, %{components: components}} <- OfferAdmission.accepted_terms(purchase),
         do: {:ok, Map.keys(components)}
  end

  defp components(%SyntheticOrder{}), do: {:ok, [:assessment, :plan]}
end
