defmodule NewYou.Commerce.HostedCheckout do
  @moduledoc """
  Commerce's provider-disabled checkout boundary. It binds an accepted
  standalone Plan and commits one dispatch claim before TEST-only loopback
  Initialize. A committed claim never expires into permission to send again.
  """

  @derive {Inspect, only: [:status]}
  defstruct [:attempt_id, :reference, :status, :authorization_url]

  @type t :: %__MODULE__{
          attempt_id: Ecto.UUID.t(),
          reference: String.t(),
          status: :prepared | :ambiguous | :retained,
          authorization_url: String.t() | nil
        }
  @type scope :: %{
          provider: :paystack,
          integration: :local_fixture,
          environment: :test,
          channel: :card
        }
  @type result :: {:ok, t()} | {:error, :checkout_unavailable | :provider_disabled}

  @spec prepare(map(), NewYou.Commerce.OfferAdmission.snapshot(), scope()) :: result()
  @spec initialize(map(), NewYou.Commerce.OfferAdmission.snapshot(), scope(), pos_integer()) ::
          result()
  @spec recover(map(), NewYou.Commerce.OfferAdmission.snapshot(), scope()) :: result()

  if Mix.env() == :test do
    alias Ecto.Adapters.SQL.Sandbox

    alias NewYou.Commerce.{
      HostedDispatch,
      OfferAdmission,
      PaystackCheckout,
      Purchase,
      VerifiedPayment
    }

    alias NewYou.{Identity, Repo}

    require Ash.Query

    @scope %{provider: :paystack, integration: :local_fixture, environment: :test, channel: :card}

    @doc """
    Persist the reference for this exact accepted snapshot as its current payer.
    Replay recovers the same binding. This operation performs no HTTP.
    """
    def prepare(credentials, snapshot, scope) when scope == @scope do
      with_source(credentials, snapshot, fn
        nil, digest ->
          attrs =
            Map.merge(@scope, %{
              attempt_id: snapshot.attempt_id,
              reference: Base.encode16(:crypto.strong_rand_bytes(16), case: :lower),
              source_digest: digest
            })

          with {:ok, attempt} <-
                 Ash.create(HostedDispatch, attrs, action: :bind, authorize?: false),
               do: outcome(attempt)

        attempt, _ ->
          outcome(attempt)
      end)
    end

    def prepare(_, _, _), do: {:error, :checkout_unavailable}

    @doc """
    Admit one dispatch for the prepared snapshot and local fixture listener.
    Requires a current payer and a top-level transaction boundary. Once claimed,
    further submissions return the stored outcome without another request.
    """
    def initialize(credentials, snapshot, scope, port)
        when scope == @scope and is_integer(port) and port in 1..65_535 do
      # Ash.transact can join the caller's transaction. In that case this
      # function could otherwise get an acknowledgement before a real COMMIT.
      with false <- Ash.DataLayer.in_transaction?(Purchase),
           {:ok, {:dispatch, attempt}} <-
             with_source(credentials, snapshot, fn attempt, _ -> claim(attempt, port) end),
           true <- committed_claim?(attempt) do
        checkpoint(:claim_committed)
        send_once(attempt, snapshot.terms, port)
        recover(credentials, snapshot, scope)
      else
        {:ok, %__MODULE__{}} = replay -> replay
        _ -> {:error, :checkout_unavailable}
      end
    end

    def initialize(_, _, _, _), do: {:error, :checkout_unavailable}

    @doc """
    Recover the original reference and any retained fixture capability as the
    currently authorized payer. An inconclusive claim stays ambiguous.
    """
    def recover(credentials, snapshot, scope) when scope == @scope do
      with_source(credentials, snapshot, fn
        nil, _ -> {:error, :checkout_unavailable}
        attempt, _ -> outcome(attempt)
      end)
    end

    def recover(_, _, _), do: {:error, :checkout_unavailable}

    defp with_source(credentials, %{purchase_id: id} = snapshot, operation) do
      with {:ok, ^id} <- Ecto.UUID.cast(id),
           {:ok, result} <-
             Ash.transact(Purchase, fn ->
               locked_source(credentials, id, snapshot, operation)
             end) do
        {:ok, result}
      else
        _ -> {:error, :checkout_unavailable}
      end
    end

    defp with_source(_, _, _), do: {:error, :checkout_unavailable}

    defp locked_source(credentials, id, snapshot, operation) do
      with {:ok, %Purchase{payer_id: payer_id, attempt_id: attempt_id} = purchase} <-
             Purchase
             |> Ash.Query.filter(id == ^id)
             |> Ash.Query.lock(:for_update)
             |> Ash.read_one(authorize?: false),
           {:ok, %{account_id: ^payer_id}} <- Identity.authorize_canonical_session(credentials),
           :ok <- OfferAdmission.current_parties_privacy(purchase),
           %{terms: %{product: :plan}} = accepted <- OfferAdmission.bound_snapshot(purchase),
           true <- snapshot === accepted,
           {:ok, false} <-
             VerifiedPayment
             |> Ash.Query.filter(purchase_id == ^id)
             |> Ash.exists(authorize?: false),
           {:ok, attempt} <- Ash.get(HostedDispatch, attempt_id, authorize?: false, error?: false),
           digest <- HostedDispatch.source_digest(accepted),
           true <- is_nil(attempt) or attempt.source_digest == digest do
        operation.(attempt, digest)
      else
        _ -> {:error, :checkout_unavailable}
      end
    end

    defp claim(nil, _), do: {:error, :checkout_unavailable}

    # The purchase lock is shared with existing synthetic payment application.
    # The guarded write consumes this attempt's only dispatch epoch.
    defp claim(%HostedDispatch{claim_id: nil} = attempt, port) do
      with {:ok, claimed} <-
             Ash.update(
               attempt,
               %{
                 claim_id: Ash.UUID.generate(),
                 fixture_port: port,
                 verify_after: DateTime.utc_now()
               },
               action: :claim,
               authorize?: false
             ) do
        checkpoint(:claim_written)
        {:dispatch, claimed}
      end
    end

    defp claim(attempt, _), do: outcome(attempt)

    # SQL Sandbox can wrap an explicit transaction in a savepoint without
    # marking the caller in_transaction?. A separate unboxed read of the exact
    # claim is required before the TEST transport is allowed to write.
    defp committed_claim?(%HostedDispatch{
           attempt_id: id,
           claim_id: claim_id,
           reference: reference
         }) do
      observer = Task.async(fn -> observe_commit(id, claim_id, reference) end)

      case Task.yield(observer, 2_000) do
        {:ok, visible?} ->
          visible?

        nil ->
          Task.shutdown(observer, :brutal_kill)
          false
      end
    end

    defp observe_commit(id, claim_id, reference) do
      Sandbox.unboxed_run(Repo, fn ->
        match?(
          {:ok, %HostedDispatch{claim_id: ^claim_id, reference: ^reference}},
          Ash.get(HostedDispatch, id, authorize?: false, error?: false, timeout: 1_000)
        )
      end)
    rescue
      _ -> false
    end

    defp send_once(attempt, terms, port) do
      with {:ok, code} <- initialize_fixture(terms, attempt.reference, port),
           {:ok, _} <-
             Ash.update(
               attempt,
               %{expected_claim_id: attempt.claim_id, fixture_code: code},
               action: :retain,
               authorize?: false
             ) do
        checkpoint(:capability_committed)
      end
    end

    defp initialize_fixture(terms, reference, port) do
      request = PaystackCheckout.build(terms, reference, port)
      started_at = System.monotonic_time()
      checkpoint(:initialize_attempted)

      {result, http_status, classification} =
        request |> request_once() |> PaystackCheckout.decode(reference)

      :telemetry.execute(
        [:new_you, :commerce, :hosted_checkout, :http],
        %{duration: System.monotonic_time() - started_at},
        %{http_status: http_status, classification: classification}
      )

      result
    end

    defp request_once(request) do
      {_request, result} = Req.Request.run_request(request)
      result
    rescue
      _ -> :request_unavailable
    end

    defp outcome(attempt) do
      {status, url} =
        case attempt do
          %{claim_id: nil} -> {:prepared, nil}
          %{fixture_code: nil} -> {:ambiguous, nil}
          %{fixture_code: code} -> {:retained, PaystackCheckout.fixture_url(code)}
        end

      %__MODULE__{
        attempt_id: attempt.attempt_id,
        reference: attempt.reference,
        status: status,
        authorization_url: url
      }
    end

    defp checkpoint(stage) do
      :telemetry.execute([:new_you, :commerce, :hosted_checkout, :checkpoint], %{count: 1}, %{
        stage: stage
      })
    end
  else
    @doc "Disabled outside TEST. Acquires no attempt or reference."
    def prepare(_, _, _), do: {:error, :provider_disabled}
    @doc "Disabled outside TEST. Performs no HTTP."
    def initialize(_, _, _, _), do: {:error, :provider_disabled}
    @doc "Disabled outside TEST. Returns no fixture capability."
    def recover(_, _, _), do: {:error, :provider_disabled}
  end
end
