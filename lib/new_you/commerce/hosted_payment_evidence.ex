defmodule NewYou.Commerce.HostedPaymentEvidence do
  @moduledoc false

  if Mix.env() == :test do
    alias Ecto.Adapters.SQL.Sandbox
    alias NewYou.Commerce
    alias NewYou.Commerce.{HostedDispatch, HostedPaymentReceipt, PaystackCheckout}
    alias NewYou.Repo

    require Ash.Query

    @body_limit 8_192

    @spec ingest(binary(), [binary()]) ::
            :ok | {:error, :unauthenticated | :unsupported | :unavailable}
    def ingest(raw, [signature]) when byte_size(raw) <= @body_limit do
      key = Application.get_env(:new_you, :fixture_webhook_key)

      with true <- is_binary(key) and byte_size(key) >= 32,
           {:ok, decoded} when byte_size(decoded) == 64 <- Base.decode16(signature, case: :lower),
           true <- Plug.Crypto.secure_compare(decoded, :crypto.mac(:hmac, :sha512, key, raw)) do
        result = persist_webhook(raw)
        emit(:receipt, if(result == :ok, do: :accepted, else: elem(result, 1)))
        result
      else
        _ -> rejected()
      end
    end

    def ingest(_, _), do: rejected()

    defp rejected do
      emit(:receipt, :unauthenticated)
      {:error, :unauthenticated}
    end

    defp persist_webhook(raw) do
      case Jason.decode(raw) do
        {:ok, %{"event" => event, "data" => data} = envelope}
        when event in ["charge.success", "charge.pending"] and map_size(envelope) == 2 ->
          record_webhook(raw, data, event)

        _ ->
          {:error, :unsupported}
      end
    end

    defp record_webhook(raw, data, event) do
      case normalize(data) do
        %{reference: _} = observation ->
          outcome = event_outcome(event, observation.outcome)

          Repo.without_query_telemetry(fn ->
            commit_webhook(raw, %{observation | outcome: outcome})
          end)

        _ ->
          {:error, :unsupported}
      end
    end

    defp commit_webhook(raw, observation) do
      with false <- Ash.DataLayer.in_transaction?(HostedPaymentReceipt),
           {:ok, receipt} <- record(:webhook, raw, nil, observation),
           true <- committed_receipt?(receipt.id) do
        emit(:receipt_checkpoint, :committed)
        :ok
      else
        _ -> {:error, :unavailable}
      end
    end

    defp event_outcome("charge.success", :pending), do: :invalid_event
    defp event_outcome("charge.pending", :succeeded), do: :invalid_event
    defp event_outcome(_, outcome), do: outcome

    # SQL Sandbox can return a row still inside its implicit outer transaction.
    # Require independent visibility before acknowledging even a duplicate.
    defp committed_receipt?(id) do
      observer = Task.async(fn -> visible_receipt?(id) end)

      case Task.yield(observer, 2_000) do
        {:ok, visible?} ->
          visible?

        nil ->
          Task.shutdown(observer, :brutal_kill)
          false
      end
    end

    defp visible_receipt?(id) do
      Sandbox.unboxed_run(Repo, fn ->
        Repo.without_query_telemetry(fn ->
          match?(
            {:ok, %HostedPaymentReceipt{}},
            Ash.get(HostedPaymentReceipt, id, authorize?: false, error?: false, timeout: 1_000)
          )
        end)
      end)
    rescue
      _ -> false
    end

    @spec verify_due(Ecto.UUID.t()) :: :ok | {:error, :unavailable}
    def verify_due(id), do: Repo.without_query_telemetry(fn -> run_due_verify(id) end)

    defp run_due_verify(id) do
      with false <- Ash.DataLayer.in_transaction?(HostedDispatch),
           {:ok, attempt} <- Ash.transact(HostedDispatch, fn -> reserve_verify(id) end) do
        case attempt do
          %HostedDispatch{} -> verify(attempt)
          :not_due -> :ok
        end
      else
        _ -> {:error, :unavailable}
      end
    end

    defp reserve_verify(id) do
      now = DateTime.utc_now()

      case HostedDispatch
           |> Ash.Query.filter(attempt_id == ^id and verify_after <= ^now)
           |> Ash.Query.lock(:for_update)
           |> Ash.read_one(authorize?: false) do
        {:ok, %HostedDispatch{} = attempt} -> defer_verify(attempt, now)
        {:ok, nil} -> :not_due
        error -> error
      end
    end

    defp defer_verify(attempt, now) do
      round = min(attempt.verify_round + 1, 6)
      delay = min(30 * Integer.pow(2, round - 1), 900)

      case Ash.update(attempt, %{verify_round: round, verify_after: DateTime.add(now, delay)},
             action: :defer_verify,
             authorize?: false
           ) do
        {:ok, reserved} -> reserved
        error -> error
      end
    end

    defp verify(attempt) do
      started_at = System.monotonic_time()
      {raw, observation, retry_after} = observe(attempt)

      :telemetry.execute(
        [:new_you, :commerce, :fixture_payment, :verify],
        %{duration: System.monotonic_time() - started_at, retry_after: retry_after},
        %{outcome: observation.outcome}
      )

      with :ok <- respect_retry_after(attempt, retry_after),
           {:ok, receipt} <- record(:verify, raw, attempt.reference, observation) do
        emit(:verify_checkpoint, :evidence_committed)
        Commerce.apply_hosted_payment_evidence(receipt.id)
      else
        _ -> {:error, :unavailable}
      end
    end

    defp respect_retry_after(_, 0), do: :ok

    defp respect_retry_after(attempt, delay) do
      until = DateTime.add(DateTime.utc_now(), delay)

      case Ash.update(attempt, %{retry_after: until},
             action: :respect_retry_after,
             authorize?: false
           ) do
        {:ok, _} -> :ok
        {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} -> :ok
        _ -> {:error, :unavailable}
      end
    end

    defp observe(attempt) do
      response =
        attempt.reference
        |> PaystackCheckout.build_verify(attempt.fixture_port)
        |> Req.Request.run_request()
        |> elem(1)

      case response do
        %Req.Response{status: 200, body: body} when is_binary(body) ->
          observation =
            case Jason.decode(body) do
              {:ok, %{"status" => true, "data" => data}} -> normalize(data)
              _ -> %{outcome: :unknown}
            end

          {body, observation, 0}

        %Req.Response{status: 429} = response ->
          {"rate_limited", %{outcome: :rate_limited}, retry_delay(response)}

        %Req.Response{status: 404} ->
          {"not_found", %{outcome: :not_found}, 0}

        %{reason: reason} when reason in [:timeout, :request_timeout] ->
          {"timeout", %{outcome: :timeout}, 0}

        _ ->
          {"unavailable", %{outcome: :unavailable}, 0}
      end
    rescue
      _ -> {"unavailable", %{outcome: :unavailable}, 0}
    end

    defp retry_delay(response) do
      with [header] <- Req.Response.get_header(response, "retry-after"),
           true <- byte_size(header) <= 10,
           {seconds, ""} <- Integer.parse(header) do
        max(60, min(seconds, 900))
      else
        _ -> 60
      end
    end

    defp normalize(
           %{
             "reference" => reference,
             "id" => id,
             "amount" => amount,
             "currency" => currency,
             "status" => status,
             "provider" => provider,
             "integration" => integration,
             "environment" => environment
           } = data
         )
         when map_size(data) == 8 and is_binary(reference) and byte_size(reference) == 32 and
                is_integer(amount) and amount in 1..2_147_483_647 and is_binary(currency) and
                byte_size(currency) == 3 do
      with true <- reference =~ ~r/\A[0-9a-f]{32}\z/,
           true <- currency =~ ~r/\A[A-Z]{3}\z/,
           {:ok, transaction_id} <- lossless_id(id) do
        %{
          reference: reference,
          transaction_id: transaction_id,
          amount_minor: amount,
          currency: currency,
          outcome: outcome(provider, integration, environment, status)
        }
      else
        _ -> %{outcome: :unknown}
      end
    end

    defp normalize(_), do: %{outcome: :unknown}

    defp lossless_id(id) when is_integer(id) and id in 1..18_446_744_073_709_551_615,
      do: {:ok, Integer.to_string(id)}

    defp lossless_id(id) when is_binary(id) and byte_size(id) in 1..20 do
      case Integer.parse(id) do
        {value, ""} ->
          case lossless_id(value) do
            {:ok, ^id} -> {:ok, id}
            _ -> :error
          end

        _ ->
          :error
      end
    end

    defp lossless_id(_), do: :error

    defp outcome("paystack", "local_fixture", "test", status) do
      case status do
        "success" -> :succeeded
        "pending" -> :pending
        _ -> :unknown
      end
    end

    defp outcome(_, _, _, _), do: :scope_mismatch

    defp record(source, raw, requested_reference, observation) do
      attrs =
        Map.merge(observation, %{
          source: source,
          digest: :crypto.hash(:sha256, raw),
          requested_reference: requested_reference
        })

      Ash.create(HostedPaymentReceipt, attrs, action: :receive_evidence, authorize?: false)
    end

    defp emit(event, outcome) do
      :telemetry.execute([:new_you, :commerce, :fixture_payment, event], %{count: 1}, %{
        outcome: outcome
      })
    end
  else
    @doc false
    def verify_due(_), do: {:error, :provider_disabled}
  end
end
