defmodule NewYou.Commerce.FixtureDisputes do
  @moduledoc """
  Commerce's TEST-only dispute qualification and recovery. The accepted
  purchase serializes receipt qualification, refund dispatch and entitlement
  convergence. A receipt and a dispute have independent identities.
  """

  alias NewYou.Commerce.{
    FixtureCorrectionSource,
    FixtureDispute,
    FixtureDisputeEvidence,
    FixtureDisputeReceipt,
    FixtureRefund,
    FixtureRefunds,
    OfferAdmission,
    Purchase,
    VerifiedPayment
  }

  alias NewYou.{Entitlements, Repo}

  import FixtureCorrectionSource, only: [lock_purchase: 1, transact: 1]
  require Ash.Query

  @unavailable {:error, :dispute_unavailable}
  @terminal [:lost, :restored]

  @doc false
  @spec apply_receipt(Ecto.UUID.t()) :: :ok | {:error, :dispute_unavailable}
  def apply_receipt(id) do
    case transact(fn -> classify_receipt(id) end) do
      {:ok, :ok} ->
        checkpoint(:commerce_committed)
        :ok

      _ ->
        @unavailable
    end
  end

  defp classify_receipt(id) do
    with {:ok, %{payment_id: payment_id}} <- Ash.get(FixtureDisputeReceipt, id, authorize?: false),
         {:ok, %VerifiedPayment{purchase_id: purchase_id} = payment} <-
           Ash.get(VerifiedPayment, payment_id, authorize?: false),
         {:ok, %Purchase{} = purchase} <- lock_purchase(purchase_id),
         {:ok, receipt} <- Ash.get(FixtureDisputeReceipt, id, authorize?: false) do
      classify_pending(receipt, purchase, payment)
    else
      _ -> @unavailable
    end
  end

  defp classify_pending(%{state: :pending} = receipt, purchase, payment) do
    with {:ok, classification} <- qualify(receipt, purchase, payment),
         {:ok, _} <- update(receipt, :classify, %{state: classification}),
         do: :ok
  end

  defp classify_pending(_, _, _), do: :ok

  defp qualify(receipt, purchase, payment) do
    with {:ok, dispute} <- read_identity(receipt.dispute_id) do
      case {dispute, receipt.source} do
        {nil, :webhook} -> bind(receipt, purchase, payment)
        {nil, :read} -> {:ok, :quarantined}
        {dispute, _} -> advance(dispute, receipt)
      end
    end
  end

  defp bind(receipt, purchase, payment) do
    with {:ok, allocation} <- allocation(purchase, payment, receipt.amount_minor),
         {:ok, conflict?} <- initial_terminal_conflict?(receipt),
         {:ok, dispute} <-
           Ash.create(
             FixtureDispute,
             %{
               dispute_id: receipt.dispute_id,
               payment_id: payment.id,
               purchase_id: purchase.id,
               amount_minor: receipt.amount_minor,
               allocation: allocation,
               state: if(conflict?, do: :unresolved, else: receipt.outcome),
               revision: receipt.revision,
               conflict?: conflict?,
               verify_after: DateTime.utc_now()
             },
             action: :bind,
             authorize?: false
           ) do
      # Another purchase can race for a previously absent provider identity.
      if matches?(dispute, receipt),
        do: {:ok, if(conflict?, do: :conflict, else: :applied)},
        else: {:ok, :quarantined}
    end
  end

  defp initial_terminal_conflict?(%{outcome: outcome} = receipt) when outcome in @terminal,
    do: receipt |> opposing_terminal() |> Ash.exists(authorize?: false)

  defp initial_terminal_conflict?(_receipt), do: {:ok, false}

  defp allocation(%{amount_minor: amount}, %{collection_kind: :excess}, amount),
    do: {:ok, :excess}

  defp allocation(%{amount_minor: amount} = purchase, %{collection_kind: :primary}, amount) do
    with {:ok, terms} <- OfferAdmission.accepted_terms(purchase) do
      if OfferAdmission.accepted_component_minor(terms, :plan) == amount,
        do: {:ok, :plan},
        else: {:ok, :unallocated}
    end
  end

  defp allocation(_, _, _), do: {:ok, :unallocated}

  defp advance(dispute, receipt) do
    cond do
      not matches?(dispute, receipt) ->
        {:ok, :quarantined}

      receipt.source == :read and dispute.read_token != receipt.read_token ->
        {:ok, :stale}

      true ->
        advance_qualified(dispute, receipt)
    end
  end

  defp advance_qualified(
         %{state: state, conflict?: true, revision: revision} = dispute,
         %{
           source: :read,
           outcome: state,
           revision: incoming
         } = receipt
       )
       when state in @terminal and incoming > revision,
       do: confirm_terminal(dispute, receipt)

  defp advance_qualified(%{state: state} = dispute, %{outcome: outcome, revision: revision})
       when state in @terminal and outcome in @terminal and state != outcome,
       do: terminal_disagreement(dispute, revision)

  defp advance_qualified(%{state: state, revision: revision}, %{revision: incoming})
       when state in @terminal or incoming < revision,
       do: {:ok, :stale}

  defp advance_qualified(%{revision: revision, state: outcome}, %{
         revision: revision,
         outcome: outcome
       }),
       do: {:ok, :stale}

  defp advance_qualified(%{revision: revision} = dispute, %{revision: revision}),
    do: conflict(dispute)

  defp advance_qualified(dispute, %{outcome: outcome} = receipt) when outcome in @terminal,
    do: qualify_terminal(dispute, receipt)

  defp advance_qualified(dispute, receipt),
    do: qualify_outcome(dispute, receipt, dispute.conflict?)

  defp qualify_terminal(%{conflict?: true}, %{source: :webhook}), do: {:ok, :conflict}

  defp qualify_terminal(%{conflict?: true} = dispute, receipt) do
    competing =
      receipt
      |> terminal_evidence()
      |> Ash.Query.filter(
        revision > ^receipt.revision or
          (revision == ^receipt.revision and outcome != ^receipt.outcome)
      )

    case Ash.exists(competing, authorize?: false) do
      {:ok, false} -> qualify_outcome(dispute, receipt, false)
      {:ok, true} -> {:ok, :stale}
      {:error, _} = error -> error
    end
  end

  defp qualify_terminal(dispute, receipt) do
    case initial_terminal_conflict?(receipt) do
      {:ok, false} -> qualify_outcome(dispute, receipt, false)
      {:ok, true} -> conflict(dispute)
      {:error, _} = error -> error
    end
  end

  defp qualify_outcome(dispute, receipt, conflict?) do
    with {:ok, _} <-
           update(dispute, :qualify, %{
             state: receipt.outcome,
             revision: receipt.revision,
             conflict?: conflict?,
             effect_version: dispute.effect_version + 1
           }),
         do: {:ok, :applied}
  end

  # The current pinned read can confirm the retained terminal decision only
  # when it is newer than every opposing terminal observation for this case.
  # An opposing read still needs adjudication and never reopens an ended right.
  defp confirm_terminal(dispute, receipt) do
    opposing =
      receipt
      |> opposing_terminal()
      |> Ash.Query.filter(revision >= ^receipt.revision)

    with {:ok, false} <- Ash.exists(opposing, authorize?: false),
         {:ok, _} <-
           update(dispute, :confirm_terminal, %{
             revision: receipt.revision,
             effect_version: dispute.effect_version + 1
           }) do
      {:ok, :applied}
    else
      {:ok, true} -> {:ok, :stale}
      {:error, _} = error -> error
    end
  end

  # A superseded lease prevents direct application. Its committed, exact-source
  # terminal observation still counts when another receipt seeks qualification.
  defp opposing_terminal(receipt) do
    receipt
    |> terminal_evidence()
    |> Ash.Query.filter(outcome != ^receipt.outcome)
  end

  defp terminal_evidence(scope) do
    scope
    |> case_receipts()
    |> Ash.Query.filter(outcome in ^@terminal and state != :quarantined)
  end

  defp terminal_disagreement(dispute, revision) when revision < dispute.revision do
    confirmed =
      dispute
      |> case_receipts()
      |> Ash.Query.filter(
        source == :read and state == :applied and outcome == ^dispute.state and
          revision == ^dispute.revision
      )

    case Ash.exists(confirmed, authorize?: false) do
      {:ok, true} -> {:ok, :stale}
      {:ok, false} -> conflict(dispute)
      {:error, _} = error -> error
    end
  end

  defp terminal_disagreement(dispute, _revision), do: conflict(dispute)

  defp case_receipts(dispute) do
    Ash.Query.filter(
      FixtureDisputeReceipt,
      payment_id == ^dispute.payment_id and dispute_id == ^dispute.dispute_id and
        amount_minor == ^dispute.amount_minor
    )
  end

  defp matches?(dispute, receipt) do
    dispute.payment_id == receipt.payment_id and dispute.amount_minor == receipt.amount_minor
  end

  defp conflict(%{conflict?: true}), do: {:ok, :conflict}

  defp conflict(dispute) do
    with {:ok, _} <-
           update(dispute, :record_conflict, %{effect_version: dispute.effect_version + 1}),
         do: {:ok, :conflict}
  end

  @doc false
  @spec locked_case(Ecto.UUID.t()) ::
          {:ok, FixtureDispute.t(), Purchase.t()} | {:error, :dispute_unavailable}
  def locked_case(id) do
    with true <- Ash.DataLayer.in_transaction?(Purchase),
         {:ok, %{purchase_id: purchase_id}} <- Ash.get(FixtureDispute, id, authorize?: false),
         {:ok, %Purchase{} = purchase} <- lock_purchase(purchase_id),
         {:ok, %FixtureDispute{} = dispute} <- Ash.get(FixtureDispute, id, authorize?: false) do
      {:ok, dispute, purchase}
    else
      _ -> @unavailable
    end
  end

  @doc false
  @spec refund_clear?(Ecto.UUID.t()) :: {:ok, boolean()} | {:error, term()}
  def refund_clear?(payment_id) do
    with true <- Ash.DataLayer.in_transaction?(Purchase),
         {:ok, false} <- blocking_case?(payment_id),
         {:ok, false} <-
           FixtureDisputeReceipt
           |> Ash.Query.filter(payment_id == ^payment_id and state == :pending)
           |> Ash.exists(authorize?: false) do
      {:ok, true}
    else
      {:ok, true} -> {:ok, false}
      _ -> @unavailable
    end
  end

  defp blocking_case?(payment_id) do
    FixtureDispute
    |> Ash.Query.filter(payment_id == ^payment_id and (state != :restored or conflict?))
    |> Ash.exists(authorize?: false)
  end

  @doc """
  Classify the current competing correction for the same collection. Recorded
  refund obligations and loss evidence retain their own amounts and identities.
  An existing POST claim stays fenced and requires reconciliation even after
  absence, failed or pending provider observations.
  """
  @spec correction_overlap(Ecto.UUID.t()) ::
          {:ok, :none | :refund_owed | :unresolved} | {:error, :dispute_unavailable}
  def correction_overlap(id) do
    case transact(fn -> classify_overlap(id) end) do
      {:ok, result} -> {:ok, result}
      _ -> @unavailable
    end
  end

  defp classify_overlap(id) do
    with {:ok, %{payment_id: payment_id}, _} <- locked_case(id),
         {:ok, true} <- blocking_case?(payment_id),
         {:ok, refunds} <-
           FixtureRefund
           |> Ash.Query.filter(payment_id == ^payment_id)
           |> Ash.read(authorize?: false) do
      cond do
        Enum.any?(refunds, &(not is_nil(&1.claim_id))) -> :unresolved
        refunds != [] -> :refund_owed
        true -> :none
      end
    else
      {:ok, false} -> :none
      _ -> @unavailable
    end
  end

  @doc false
  @spec right_effect(Ecto.UUID.t(), :plan) ::
          {:ok, :available | :suspend | :end} | {:error, term()}
  def right_effect(payment_id, :plan) do
    Repo.without_query_telemetry(fn ->
      query =
        Ash.Query.filter(FixtureDispute, payment_id == ^payment_id and allocation == :plan)

      with {:ok, false} <-
             query |> Ash.Query.filter(state == :lost) |> Ash.exists(authorize?: false),
           {:ok, blocked?} <-
             query
             |> Ash.Query.filter(state != :restored or conflict?)
             |> Ash.exists(authorize?: false) do
        {:ok, if(blocked?, do: :suspend, else: :available)}
      else
        {:ok, true} -> {:ok, :end}
        {:error, _} = error -> error
      end
    end)
  end

  @doc false
  def locked_effect(id) do
    with {:ok, dispute, purchase} <- locked_case(id),
         scope = %{
           purchase_id: purchase.id,
           payment_id: dispute.payment_id,
           recipient_id: purchase.recipient_id
         },
         {:ok, effect} <- effect_for_case(dispute, scope) do
      {:ok, scope, effect, dispute.effect_version}
    end
  end

  defp effect_for_case(%{allocation: :plan}, scope) do
    with {:ok, ended?} <- FixtureRefunds.plan_ended?(scope) do
      if ended?, do: {:ok, :end}, else: right_effect(scope.payment_id, :plan)
    end
  end

  defp effect_for_case(_, _), do: {:ok, :none}

  @doc false
  @spec deliver(Ecto.UUID.t()) :: :ok | {:error, :dispute_unavailable}
  def deliver(id) do
    with {:ok, version} <- Entitlements.apply_fixture_dispute(id),
         :ok <- checkpoint(:entitlements_committed),
         {:ok, :ok} <- transact(fn -> acknowledge(id, version) end) do
      :ok
    else
      _ -> @unavailable
    end
  end

  defp acknowledge(id, version) do
    with {:ok, dispute, _} <- locked_case(id) do
      acknowledge_version(dispute, version)
    end
  end

  defp acknowledge_version(
         %{effect_version: version, acknowledged_version: prior} = dispute,
         version
       )
       when prior < version do
    with {:ok, _} <- update(dispute, :acknowledge, %{acknowledged_version: version}), do: :ok
  end

  defp acknowledge_version(_, _), do: :ok

  @doc false
  @spec read_due(Ecto.UUID.t()) :: :ok | {:error, :dispute_unavailable}
  def read_due(id) do
    with false <- Ash.DataLayer.in_transaction?(Purchase),
         {:ok, reservation} <- transact(fn -> reserve_read(id) end) do
      read_committed(reservation)
    else
      _ -> @unavailable
    end
  end

  defp reserve_read(id) do
    with {:ok, dispute, purchase} <- locked_case(id) do
      reserve_if_due(dispute, purchase, DateTime.utc_now())
    end
  end

  defp reserve_if_due(dispute, purchase, now) do
    if (dispute.state not in @terminal or dispute.conflict?) and
         DateTime.compare(dispute.verify_after, now) != :gt do
      attrs =
        dispute.verify_round
        |> FixtureCorrectionSource.next_read(now)
        |> Map.put(:read_token, Ash.UUID.generate())

      with {:ok, listener} <- FixtureCorrectionSource.pinned_listener(purchase),
           {:ok, reserved} <- update(dispute, :reserve_read, attrs) do
        {reserved, listener}
      end
    else
      :not_due
    end
  end

  defp read_committed(:not_due), do: :ok

  defp read_committed({%{id: id, read_token: token, verify_after: due} = dispute, listener}) do
    visible? =
      FixtureCorrectionSource.independently_visible?(fn ->
        match?(
          {:ok, %{read_token: ^token, verify_after: ^due}},
          Ash.get(FixtureDispute, id, authorize?: false, error?: false, timeout: 1_000)
        )
      end)

    if visible? and DateTime.after?(due, DateTime.utc_now()) do
      checkpoint(:read_reserved)
      FixtureDisputeEvidence.read(dispute, listener)
    else
      @unavailable
    end
  end

  @doc false
  @spec respect_read_delay(FixtureDispute.t(), non_neg_integer()) :: :ok | {:error, term()}
  def respect_read_delay(_, 0), do: :ok

  def respect_read_delay(dispute, delay) do
    case transact(fn -> extend_reservation(dispute, delay) end) do
      {:ok, :ok} -> :ok
      _ -> @unavailable
    end
  end

  defp extend_reservation(dispute, delay) do
    with {:ok, current, _} <- locked_case(dispute.id) do
      until = DateTime.add(DateTime.utc_now(), delay)
      extend_matching_reservation(current, dispute.read_token, until)
    end
  end

  defp extend_matching_reservation(%{read_token: token} = current, token, until) do
    if DateTime.after?(until, current.verify_after) do
      with {:ok, _} <- update(current, :reserve_read, %{verify_after: until}), do: :ok
    else
      :ok
    end
  end

  defp extend_matching_reservation(_, _, _), do: :ok

  @doc false
  def read_identity(id) do
    FixtureDispute |> Ash.Query.filter(dispute_id == ^id) |> Ash.read_one(authorize?: false)
  end

  defp update(record, action, changes),
    do: Ash.update(record, changes, action: action, authorize?: false)

  defp checkpoint(stage) do
    :telemetry.execute([:new_you, :commerce, :fixture_dispute, :checkpoint], %{count: 1}, %{
      stage: stage
    })
  end
end
