defmodule NewYou.Commerce.HostedCheckout do
  @moduledoc """
  Commerce's non-production checkout boundary for Paystack TEST. It binds an accepted standalone Plan
  and commits one dispatch claim before Paystack Hosted Redirect Initialize.
  A committed claim never expires into permission to send again.
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
          integration: :local_fixture | :voelgoedwinkel,
          environment: :test,
          channel: :card
        }
  @type result :: {:ok, t()} | {:error, :checkout_unavailable | :provider_disabled}
  @type listener :: %{port: :inet.port_number(), certificate: binary()}

  @spec prepare(map(), NewYou.Commerce.OfferAdmission.snapshot(), scope()) :: result()
  @spec initialize(map(), NewYou.Commerce.OfferAdmission.snapshot(), scope()) :: result()
  @spec initialize(
          map(),
          NewYou.Commerce.OfferAdmission.snapshot(),
          scope(),
          pos_integer() | listener()
        ) ::
          result()
  @spec recover(map(), NewYou.Commerce.OfferAdmission.snapshot(), scope()) :: result()

  if Mix.env() in [:dev, :test] do
    alias NewYou.Commerce.{
      HostedDispatch,
      OfferAdmission,
      PaystackCheckout,
      PaystackTestIntegration,
      Purchase,
      VerifiedPayment
    }

    alias NewYou.{Identity, Repo}

    require Ash.Query

    @scope %{provider: :paystack, integration: :local_fixture, environment: :test, channel: :card}
    @provider_scope %{@scope | integration: :voelgoedwinkel}
    @checkout_scopes if(Mix.env() == :test,
                       do: [@scope, @provider_scope],
                       else: [@provider_scope]
                     )

    @doc """
    Persist the reference for this exact accepted snapshot as its current payer.
    Replay recovers the same binding. This operation performs no HTTP.
    """
    def prepare(credentials, snapshot, scope) when scope in @checkout_scopes do
      with {:ok, settings} <- checkout_settings(scope, snapshot) do
        with_source(credentials, snapshot, scope, fn
          nil, digest ->
            bind(snapshot.attempt_id, digest, scope, settings)

          attempt, _ ->
            outcome(attempt, settings)
        end)
      end
    end

    def prepare(_, _, _), do: {:error, :checkout_unavailable}

    defp bind(attempt_id, digest, scope, settings) do
      attrs =
        Map.merge(scope, %{
          attempt_id: attempt_id,
          reference: Base.encode16(:crypto.strong_rand_bytes(16), case: :lower),
          source_digest: digest
        })

      with {:ok, attempt} <- Ash.create(HostedDispatch, attrs, action: :bind, authorize?: false),
           do: outcome(attempt, settings)
    end

    @doc """
    Initialize the configured South African TEST integration for the current payer's exact
    prepared purchase. The approved attempt is bound at runtime. Replay recovers the
    existing result without sending another request.
    """
    def initialize(credentials, snapshot, scope) when scope == @provider_scope do
      with {:ok, settings} <- checkout_settings(scope, snapshot),
           true <- PaystackTestIntegration.transport_observers_safe?() do
        dispatch(credentials, snapshot, scope, %{}, settings, fn attempt ->
          send_to_provider(attempt, snapshot.terms, settings)
        end)
      else
        _ -> {:error, :checkout_unavailable}
      end
    end

    def initialize(_, _, _), do: {:error, :checkout_unavailable}

    if Mix.env() == :test do
      @doc """
      Admit one dispatch for the prepared snapshot and local fixture listener.
      Requires a current payer and a top-level transaction boundary. Once claimed,
      further submissions return the stored outcome without another request.
      A port with a pinned listener certificate schedules Verify. The original
      integer port form supports the existing initialize-only fixture.
      """
      def initialize(credentials, snapshot, scope, listener) when scope == @scope do
        case listener_schedule(listener) do
          {:ok, fields} ->
            dispatch(credentials, snapshot, scope, fields, nil, fn attempt ->
              send_fixture(attempt, snapshot.terms, listener)
            end)

          _ ->
            {:error, :checkout_unavailable}
        end
      end

      def initialize(_, _, _, _), do: {:error, :checkout_unavailable}
    else
      def initialize(_, _, _, _), do: {:error, :provider_disabled}
    end

    defp dispatch(credentials, snapshot, scope, fields, settings, send_once) do
      # Ash.transact can join the caller's transaction. In that case this
      # function could otherwise get an acknowledgement before a real COMMIT.
      with false <- Ash.DataLayer.in_transaction?(Purchase),
           {:ok, {:dispatch, attempt}} <-
             with_source(credentials, snapshot, scope, fn attempt, _ ->
               claim(attempt, fields, settings)
             end),
           true <- committed_claim?(attempt) do
        checkpoint(:claim_committed)
        send_once.(attempt)
        recover(credentials, snapshot, scope)
      else
        {:ok, %__MODULE__{}} = replay -> replay
        _ -> {:error, :checkout_unavailable}
      end
    end

    if Mix.env() == :test do
      defp listener_schedule(%{port: port, certificate: certificate})
           when port in 1..65_535 and is_binary(certificate) and byte_size(certificate) in 1..8192 do
        {:ok,
         %{
           fixture_port: port,
           fixture_certificate: certificate,
           verify_after: DateTime.utc_now()
         }}
      end

      defp listener_schedule(port) when port in 1..65_535, do: {:ok, %{}}
      defp listener_schedule(_), do: {:error, :invalid_listener}
    end

    @doc """
    Recover the original reference and any retained fixture capability as the
    currently authorized payer. An inconclusive claim stays ambiguous.
    """
    def recover(credentials, snapshot, scope) when scope in @checkout_scopes do
      with {:ok, settings} <- checkout_settings(scope, snapshot) do
        with_source(credentials, snapshot, scope, fn
          nil, _ -> {:error, :checkout_unavailable}
          attempt, _ -> outcome(attempt, settings)
        end)
      end
    end

    def recover(_, _, _), do: {:error, :checkout_unavailable}

    if Mix.env() == :test do
      defp checkout_settings(@scope, _), do: {:ok, nil}
    end

    defp checkout_settings(@provider_scope, %{attempt_id: id}),
      do: PaystackTestIntegration.settings(id)

    defp checkout_settings(_, _), do: {:error, :checkout_unavailable}

    defp with_source(credentials, %{purchase_id: id} = snapshot, scope, operation) do
      with {:ok, ^id} <- Ecto.UUID.cast(id),
           {:ok, result} <- transact_source(credentials, id, snapshot, scope, operation) do
        {:ok, result}
      else
        _ -> {:error, :checkout_unavailable}
      end
    end

    defp with_source(_, _, _, _), do: {:error, :checkout_unavailable}

    defp transact_source(credentials, id, snapshot, scope, operation) do
      Repo.without_query_telemetry(fn ->
        Ash.transact(Purchase, fn ->
          locked_source(credentials, id, snapshot, scope, operation)
        end)
      end)
    end

    defp locked_source(credentials, id, snapshot, scope, operation) do
      with {:ok, %Purchase{payer_id: payer_id, attempt_id: attempt_id} = purchase} <-
             Purchase
             |> Ash.Query.filter(id == ^id)
             |> Ash.Query.lock(:for_update)
             |> Ash.read_one(authorize?: false),
           {:ok, %{account_id: ^payer_id}} <- Identity.authorize_canonical_session(credentials),
           :ok <- OfferAdmission.current_parties_privacy(purchase),
           %{terms: %{product: :plan}} = accepted <- OfferAdmission.bound_snapshot(purchase),
           true <- development_source_allowed?(purchase, accepted),
           true <- snapshot === accepted,
           {:ok, false} <-
             VerifiedPayment
             |> Ash.Query.filter(purchase_id == ^id)
             |> Ash.exists(authorize?: false),
           {:ok, attempt} <- Ash.get(HostedDispatch, attempt_id, authorize?: false, error?: false),
           digest <- HostedDispatch.source_digest(accepted),
           true <-
             is_nil(attempt) or
               (attempt.source_digest == digest and Map.take(attempt, Map.keys(scope)) == scope) do
        operation.(attempt, digest)
      else
        _ -> {:error, :checkout_unavailable}
      end
    end

    if Mix.env() == :dev do
      defp development_source_allowed?(
             %{payer_id: id, recipient_id: id, operation_id: operation},
             %{terms: %{offer_id: offer, amount_minor: 39_900, currency: "ZAR"}}
           ) do
        match?(
          {:ok, %{"payer_id" => ^id, "operation_id" => ^operation, "offer_id" => ^offer}},
          NewYou.LocalConfig.paystack_development_plan()
        )
      end

      defp development_source_allowed?(_, _), do: false
    else
      defp development_source_allowed?(_, _), do: true
    end

    defp claim(nil, _, _), do: {:error, :checkout_unavailable}

    # The purchase lock is shared with existing synthetic payment application.
    # The guarded write consumes this attempt's only dispatch epoch.
    defp claim(%HostedDispatch{claim_id: nil} = attempt, fields, _) do
      with {:ok, claimed} <-
             Ash.update(
               attempt,
               Map.put(fields, :claim_id, Ash.UUID.generate()),
               action: :claim,
               authorize?: false
             ) do
        checkpoint(:claim_written)
        {:dispatch, claimed}
      end
    end

    defp claim(attempt, _, settings), do: outcome(attempt, settings)

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
      read_committed(fn ->
        Repo.without_query_telemetry(fn ->
          match?(
            {:ok, %HostedDispatch{claim_id: ^claim_id, reference: ^reference}},
            Ash.get(HostedDispatch, id, authorize?: false, error?: false, timeout: 1_000)
          )
        end)
      end)
    rescue
      _ -> false
    end

    if Mix.env() == :test do
      defp read_committed(read), do: Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, read)
    else
      # The DEV Task checks out from the regular pool. It never shares a caller transaction.
      defp read_committed(read), do: read.()
    end

    if Mix.env() == :test do
      defp send_fixture(attempt, terms, port) do
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
    end

    defp send_to_provider(attempt, terms, settings) do
      with true <- PaystackTestIntegration.transport_observers_safe?(),
           request <- PaystackCheckout.build_provider(terms, attempt.reference, settings),
           {:ok, url} <- initialize_request(request, attempt.reference, attempt.integration),
           encrypted <- PaystackTestIntegration.seal(attempt, url, settings.capability_key),
           {:ok, _} <-
             Repo.without_query_telemetry(fn ->
               Ash.update(
                 attempt,
                 %{expected_claim_id: attempt.claim_id, provider_capability: encrypted},
                 action: :retain_provider_capability,
                 authorize?: false
               )
             end) do
        checkpoint(:capability_committed)
      end
    end

    if Mix.env() == :test do
      defp initialize_fixture(terms, reference, port) do
        request = PaystackCheckout.build(terms, reference, port)
        initialize_request(request, reference, :local_fixture)
      end
    end

    defp initialize_request(request, reference, integration) do
      started_at = System.monotonic_time()
      checkpoint(:initialize_attempted)

      {result, http_status, classification} =
        request |> request_once() |> PaystackCheckout.decode(reference, integration)

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

    defp outcome(attempt, settings) do
      {status, url} =
        case attempt do
          %{claim_id: nil} ->
            {:prepared, nil}

          %{integration: :voelgoedwinkel} ->
            case PaystackTestIntegration.unseal(attempt, settings.capability_key) do
              {:ok, url} -> {:retained, url}
              :error -> {:ambiguous, nil}
            end

          _ ->
            fixture_outcome(attempt)
        end

      %__MODULE__{
        attempt_id: attempt.attempt_id,
        reference: attempt.reference,
        status: status,
        authorization_url: url
      }
    end

    if Mix.env() == :test do
      defp fixture_outcome(%{integration: :local_fixture, fixture_code: code})
           when is_binary(code),
           do: {:retained, PaystackCheckout.fixture_url(code)}
    end

    defp fixture_outcome(_), do: {:ambiguous, nil}

    defp checkpoint(stage) do
      :telemetry.execute([:new_you, :commerce, :hosted_checkout, :checkpoint], %{count: 1}, %{
        stage: stage
      })
    end
  else
    @doc "Disabled outside DEV and TEST. Acquires no attempt or reference."
    def prepare(_, _, _), do: {:error, :provider_disabled}
    @doc "Disabled outside DEV and TEST. Performs no HTTP."
    def initialize(_, _, _), do: {:error, :provider_disabled}
    @doc "Disabled outside DEV and TEST. Performs no HTTP."
    def initialize(_, _, _, _), do: {:error, :provider_disabled}
    @doc "Disabled outside DEV and TEST. Returns no fixture capability."
    def recover(_, _, _), do: {:error, :provider_disabled}
  end
end
