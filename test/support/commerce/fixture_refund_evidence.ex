defmodule NewYou.Commerce.FixtureRefundEvidence do
  @moduledoc false

  alias NewYou.Commerce.{
    FixtureRefundReceipt,
    FixtureRefunds,
    HostedPaymentEvidence,
    PaystackCheckout
  }

  alias NewYou.Repo

  @max_amount 9_223_372_036_854_775_807
  @status %{
    "pending" => :pending,
    "processing" => :processing,
    "needs_attention" => :needs_attention,
    "failed" => :failed,
    "insufficient_balance" => :insufficient_balance,
    "processed" => :processed
  }

  def receive_webhook(raw, "refund." <> status, data) do
    if Map.has_key?(@status, status) do
      observed = normalize(data)
      expected = Map.fetch!(@status, status)

      observation =
        if observed.outcome == expected, do: observed, else: %{observed | outcome: :unqualified}

      with false <- Ash.DataLayer.in_transaction?(FixtureRefundReceipt),
           {:ok, receipt} <- record(:webhook, raw, nil, observation),
           true <- committed_receipt?(receipt.id) do
        :ok
      else
        _ -> {:error, :unavailable}
      end
    else
      {:error, :unsupported}
    end
  end

  defp committed_receipt?(id) do
    FixtureRefunds.independently_visible?(fn ->
      match?(
        {:ok, %FixtureRefundReceipt{}},
        Ash.get(FixtureRefundReceipt, id, authorize?: false, timeout: 1_000)
      )
    end)
  end

  defp record(source, raw, requested_reference, observation) do
    attrs =
      Map.merge(observation, %{
        source: source,
        requested_reference: requested_reference,
        digest: :crypto.hash(:sha256, raw)
      })

    Repo.without_query_telemetry(fn ->
      Ash.create(FixtureRefundReceipt, attrs, action: :receive, authorize?: false)
    end)
  end

  def read(refund, listener) do
    {raw, observation, wait} = observe(refund.reference, listener)

    with :ok <- respect_hold(refund, wait),
         {:ok, receipt} <- record(:read, raw, refund.reference, observation),
         :ok <- NewYou.Commerce.apply_fixture_refund_receipt(receipt.id) do
      :ok
    else
      _ -> {:error, :refund_unavailable}
    end
  end

  defp observe(reference, listener) do
    reference
    |> PaystackCheckout.build_refund_read(listener)
    |> Req.Request.run_request()
    |> elem(1)
    |> decode_read()
  rescue
    _ -> unresolved(:unavailable)
  end

  defp decode_read(%Req.Response{status: 200, body: raw}) when is_binary(raw) do
    observation =
      case Jason.decode(raw) do
        {:ok, %{"status" => true, "data" => data} = envelope} when map_size(envelope) == 2 ->
          normalize(data)

        _ ->
          %{outcome: :unqualified}
      end

    {raw, observation, 0}
  end

  defp decode_read(%Req.Response{status: 404}), do: unresolved(:not_found)

  defp decode_read(%{reason: reason}) when reason in [:timeout, :request_timeout],
    do: unresolved(:timeout)

  defp decode_read(%Req.Response{status: 429} = response) do
    wait =
      with [header] when byte_size(header) <= 10 <-
             Req.Response.get_header(response, "retry-after"),
           {seconds, ""} <- Integer.parse(header) do
        max(60, min(seconds, 900))
      else
        _ -> 60
      end

    {"rate_limited", %{outcome: :rate_limited}, wait}
  end

  defp decode_read(_), do: unresolved(:unavailable)

  defp unresolved(outcome), do: {Atom.to_string(outcome), %{outcome: outcome}, 0}

  defp respect_hold(_, 0), do: :ok
  defp respect_hold(%{verify_after: nil}, _), do: :ok

  defp respect_hold(refund, seconds) do
    result =
      Repo.without_query_telemetry(fn ->
        Ash.update(refund, %{retry_at: DateTime.add(DateTime.utc_now(), seconds)},
          action: :respect_retry_after,
          authorize?: false
        )
      end)

    case result do
      {:ok, _} -> :ok
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} -> :ok
      _ -> {:error, :refund_unavailable}
    end
  end

  defp normalize(
         %{
           "reference" => reference,
           "transaction" => transaction,
           "id" => refund_id,
           "amount" => amount,
           "currency" => "ZAR",
           "status" => status,
           "provider" => "paystack",
           "integration" => "local_fixture",
           "environment" => "test"
         } = data
       )
       when map_size(data) == 9 and is_integer(amount) and amount in 1..@max_amount and
              is_binary(reference) and byte_size(reference) == 32 do
    with true <- reference =~ ~r/\A[0-9a-f]{32}\z/,
         {:ok, transaction} <- HostedPaymentEvidence.lossless_id(transaction),
         {:ok, refund_id} <- HostedPaymentEvidence.lossless_id(refund_id) do
      %{
        reference: reference,
        transaction_id: transaction,
        provider_refund_id: refund_id,
        amount_minor: amount,
        currency: "ZAR",
        outcome: Map.get(@status, status, :unqualified)
      }
    else
      _ -> %{outcome: :unqualified}
    end
  end

  defp normalize(_), do: %{outcome: :unqualified}
end
