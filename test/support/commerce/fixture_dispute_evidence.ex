defmodule NewYou.Commerce.FixtureDisputeEvidence do
  @moduledoc false

  alias NewYou.Commerce.{
    FixtureCorrectionSource,
    FixtureDisputeReceipt,
    FixtureDisputes,
    HostedPaymentEvidence,
    HostedPaymentReceipt,
    PaystackCheckout,
    Purchase,
    VerifiedPayment
  }

  require Ash.Query

  @outcomes %{
    "contested" => :contested,
    "awaiting_feedback" => :awaiting_feedback,
    "under_review" => :under_review,
    "unresolved" => :unresolved,
    "restored" => :restored,
    "lost" => :lost
  }
  @max_amount 9_223_372_036_854_775_807
  @unavailable {:error, :unavailable}

  @doc false
  @spec receive_webhook(binary(), term()) :: :ok | {:error, :unsupported | :unavailable}
  def receive_webhook(raw, data) do
    with false <- Ash.DataLayer.in_transaction?(Purchase),
         {:ok, observation} <- normalize(data),
         {:ok, %FixtureDisputeReceipt{} = receipt} <-
           FixtureCorrectionSource.transact(fn -> record_webhook(raw, observation) end),
         true <- visible?(receipt) do
      :ok
    else
      :error -> {:error, :unsupported}
      {:ok, :unsupported} -> {:error, :unsupported}
      _ -> @unavailable
    end
  end

  defp record_webhook(raw, observation) do
    with {:ok, payment} <- original_payment(observation.transaction),
         {:ok, %Purchase{} = purchase} <-
           FixtureCorrectionSource.lock_purchase(payment.purchase_id),
         :ok <- validate_source(purchase, payment, observation),
         {:ok, existing} <- FixtureDisputes.read_identity(observation.dispute_id),
         true <- valid_identity?(existing, payment, observation),
         {:ok, receipt} <- record(raw, observation, payment.id, :webhook, nil) do
      emit(:receipt_written)
      receipt
    else
      {:error, :unsupported} -> :unsupported
      {:error, _} -> @unavailable
      _ -> :unsupported
    end
  end

  defp original_payment(transaction) do
    VerifiedPayment
    |> Ash.Query.filter(fixture_transaction_id == ^transaction and not is_nil(fixture_receipt_id))
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :unsupported}
      result -> result
    end
  end

  defp validate_source(purchase, payment, observation) do
    with %{reference: reference, amount_minor: amount, currency: "ZAR"} <- observation,
         %{currency: "ZAR", quote_id: quote} when not is_nil(quote) <- purchase,
         true <- amount <= purchase.amount_minor,
         {:ok, %HostedPaymentReceipt{reference: ^reference}} <-
           Ash.get(HostedPaymentReceipt, payment.fixture_receipt_id, authorize?: false) do
      :ok
    else
      {:error, _} -> @unavailable
      _ -> {:error, :unsupported}
    end
  end

  defp valid_identity?(nil, _, _), do: true

  defp valid_identity?(dispute, payment, observation),
    do: dispute.payment_id == payment.id and dispute.amount_minor == observation.amount_minor

  defp record(raw, observation, payment_id, source, read_token) do
    attrs =
      Map.merge(Map.take(observation, [:dispute_id, :amount_minor, :revision, :outcome]), %{
        digest: :crypto.hash(:sha256, raw),
        payment_id: payment_id,
        source: source,
        read_token: read_token
      })

    Ash.create(FixtureDisputeReceipt, attrs, action: :receive, authorize?: false)
  end

  defp visible?(%{id: id, digest: digest}) do
    FixtureCorrectionSource.independently_visible?(fn ->
      match?(
        {:ok, %FixtureDisputeReceipt{digest: ^digest}},
        Ash.get(FixtureDisputeReceipt, id, authorize?: false, error?: false, timeout: 1_000)
      )
    end)
  end

  @doc false
  @spec read(NewYou.Commerce.FixtureDispute.t(), map()) :: :ok | {:error, :unavailable}
  def read(dispute, listener) do
    response =
      dispute.dispute_id
      |> PaystackCheckout.build_dispute_read(listener)
      |> Req.Request.run_request()
      |> elem(1)

    case response do
      %Req.Response{status: 200, body: raw} when is_binary(raw) ->
        ingest_read(dispute, raw)

      %Req.Response{status: 429} = rate_limit ->
        delay = FixtureCorrectionSource.retry_delay(rate_limit)
        emit(:rate_limited)
        FixtureDisputes.respect_read_delay(dispute, delay)

      %Req.Response{status: 404} ->
        emit(:not_found)

      %{reason: reason} when reason in [:timeout, :request_timeout] ->
        emit(:timeout)

      _ ->
        emit(:unavailable)
    end
  rescue
    _ -> @unavailable
  end

  defp ingest_read(dispute, raw) do
    with {:ok, %{"data" => data} = envelope} when map_size(envelope) == 1 <- Jason.decode(raw),
         {:ok, observation} <- normalize(data) do
      persist_read(dispute, raw, observation)
    else
      _ -> emit(:rejected)
    end
  end

  defp persist_read(dispute, raw, observation) do
    with {:ok, %FixtureDisputeReceipt{} = receipt} <-
           FixtureCorrectionSource.transact(fn -> record_read(dispute, raw, observation) end),
         true <- visible?(receipt) do
      emit(:evidence_committed)
      FixtureDisputes.apply_receipt(receipt.id)
    else
      {:ok, :rejected} -> emit(:rejected)
      _ -> @unavailable
    end
  end

  defp record_read(dispute, raw, observation) do
    with {:ok, current, purchase} <- FixtureDisputes.locked_case(dispute.id),
         true <- current.read_token == dispute.read_token,
         {:ok, %VerifiedPayment{fixture_transaction_id: transaction} = payment} <-
           Ash.get(VerifiedPayment, current.payment_id, authorize?: false),
         true <- transaction == observation.transaction,
         true <- current.dispute_id == observation.dispute_id,
         true <- valid_identity?(current, payment, observation),
         :ok <- validate_source(purchase, payment, observation),
         {:ok, receipt} <- record(raw, observation, payment.id, :read, current.read_token) do
      receipt
    else
      {:error, :unsupported} -> :rejected
      {:error, _} -> @unavailable
      _ -> :rejected
    end
  end

  defp normalize(
         %{
           "scope" => "newyou_dispute_fixture",
           "reference" => reference,
           "transaction" => transaction_id,
           "id" => dispute_id,
           "amount" => amount,
           "currency" => "ZAR",
           "revision" => revision,
           "outcome" => status
         } = data
       )
       when map_size(data) == 8 and is_binary(reference) and byte_size(reference) == 32 and
              is_integer(amount) and amount in 1..@max_amount and is_integer(revision) and
              revision in 1..2_147_483_647 do
    with true <- reference =~ ~r/\A[0-9a-f]{32}\z/,
         {:ok, transaction} <- HostedPaymentEvidence.lossless_id(transaction_id),
         {:ok, dispute} <- HostedPaymentEvidence.lossless_id(dispute_id),
         {:ok, outcome} <- Map.fetch(@outcomes, status) do
      {:ok,
       %{
         reference: reference,
         transaction: transaction,
         dispute_id: dispute,
         amount_minor: amount,
         currency: "ZAR",
         revision: revision,
         outcome: outcome
       }}
    else
      _ -> :error
    end
  end

  defp normalize(_), do: :error

  defp emit(stage) do
    :telemetry.execute([:new_you, :commerce, :fixture_dispute, :checkpoint], %{count: 1}, %{
      stage: stage
    })
  end
end
