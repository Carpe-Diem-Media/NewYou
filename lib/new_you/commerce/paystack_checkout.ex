defmodule NewYou.Commerce.PaystackCheckout do
  @moduledoc false

  # Compile only into TEST. The provider integration has a fixed origin.
  # The test seam connects only to a separately pinned loopback listener.
  if Mix.env() == :test do
    @fixture_origin "https://checkout.paystack.invalid/"
    @fixture_key "rk_test_fixture_well218"
    @response_limit 16_384
    @known_codes ~w(duplicate_reference transaction_not_found invalid_params)

    @doc false
    def fixture_url(code), do: @fixture_origin <> code

    @doc false
    def build(%{amount_minor: amount, currency: "ZAR"}, reference, listener)
        when is_integer(amount) and amount > 0 and is_binary(reference) do
      # Adapt the Store Initialize envelope and restricted, non-retrying POST.
      # The local fixture has no callback, participant contact data or metadata.
      payload = %{
        amount: amount,
        currency: "ZAR",
        reference: reference,
        email: "checkout-fixture@example.com",
        channels: ["card"]
      }

      loopback_request(:post, listener, "/transaction/initialize", json: payload)
    end

    def build_provider(%{amount_minor: amount, currency: "ZAR"}, reference, settings)
        when is_integer(amount) and amount > 0 and is_binary(reference) do
      payload = %{
        amount: amount,
        currency: "ZAR",
        reference: reference,
        email: settings.email,
        channels: ["card"]
      }

      {origin, connect_options} = provider_connection(settings.listener)

      request(
        :post,
        origin <> "/transaction/initialize",
        settings.restricted_key,
        [json: payload],
        connect_options,
        6_000
      )
    end

    def build_verify(reference, %{port: port, certificate: certificate} = listener)
        when is_binary(reference) and port in 1..65_535 and is_binary(certificate) do
      loopback_request(:get, listener, "/transaction/verify/" <> reference, [])
    end

    def build_refund(refund, %{port: port, certificate: certificate} = listener)
        when port in 1..65_535 and is_binary(certificate) do
      payload = %{
        transaction: refund.transaction_id,
        reference: refund.reference,
        amount: refund.amount_minor,
        currency: refund.currency
      }

      loopback_request(:post, listener, "/refund", json: payload)
    end

    @doc false
    def build_refund_read(reference, %{port: port, certificate: certificate} = listener)
        when port in 1..65_535 and is_binary(certificate) do
      loopback_request(:get, listener, "/refund/" <> reference, [])
    end

    @doc false
    def build_dispute_read(dispute_id, %{port: port, certificate: certificate} = listener)
        when is_binary(dispute_id) and port in 1..65_535 and is_binary(certificate) do
      loopback_request(:get, listener, "/__test/dispute/" <> dispute_id, [])
    end

    defp loopback_request(method, listener, path, options) do
      # A bare request bypasses Req global defaults. HTTP/1 also excludes
      # Finch's transparent retry on a draining HTTP/2 pool.
      {origin, connect_options} = loopback_connection(listener)
      request(method, origin <> path, @fixture_key, options, connect_options, 500)
    end

    defp request(method, url, key, options, connect_options, timeout) do
      Req.Request.new(
        method: method,
        url: url,
        headers: [{"authorization", "Bearer " <> key}],
        options:
          options ++
            [
              retry: false,
              redirect: false,
              raw: true,
              connect_options: [timeout: timeout, protocols: [:http1]] ++ connect_options,
              pool_timeout: timeout,
              receive_timeout: timeout,
              request_timeout: 2 * timeout
            ]
      )
      |> Req.Steps.attach()
      |> Map.replace!(:into, &collect_body/2)
    end

    defp provider_connection(:paystack),
      do: {"https://api.paystack.co", [transport_opts: [verify: :verify_peer]]}

    defp provider_connection(%{port: _, certificate: _} = listener),
      do: loopback_connection(listener)

    defp loopback_connection(port) when port in 1..65_535,
      do: {"http://127.0.0.1:#{port}", []}

    defp loopback_connection(%{port: port, certificate: certificate}) do
      # Authenticate the pinned peer on the same connection before sending HTTP.
      # A closed or reassigned port must never receive a payment reference.
      tls_options = [
        verify: :verify_peer,
        cacerts: [certificate],
        verify_fun: {&verify_listener/4, certificate},
        reuse_sessions: false,
        session_tickets: :disabled
      ]

      {"https://127.0.0.1:#{port}", [transport_opts: tls_options]}
    end

    defp verify_listener(_, pin, {:bad_cert, :selfsigned_peer}, pin), do: {:valid, pin}
    defp verify_listener(_, _, {:bad_cert, _} = reason, _), do: {:fail, reason}
    defp verify_listener(_, _, {:extension, _}, pin), do: {:unknown, pin}
    defp verify_listener(_, _, :valid, pin), do: {:valid, pin}
    defp verify_listener(_, pin, :valid_peer, pin), do: {:valid, pin}
    defp verify_listener(_, _, :valid_peer, _), do: {:fail, :unexpected_fixture_certificate}

    defp collect_body({:data, chunk}, {request, response}) do
      if byte_size(response.body) + byte_size(chunk) <= @response_limit do
        {:cont, {request, %{response | body: response.body <> chunk}}}
      else
        {:halt, {request, %{response | body: :oversized}}}
      end
    end

    # Adapt Store's typed envelope and match the exact request reference.
    def decode(response, reference), do: decode(response, reference, :local_fixture)

    def decode(%Req.Response{status: status, body: body}, reference, integration)
        when is_binary(body) do
      case Jason.decode(body) do
        {:ok, %{"status" => true, "data" => data}} when status in [200, 201] ->
          decode_checkout(data, reference, status, integration)

        {:ok, %{"status" => false, "code" => code}} when code in @known_codes ->
          {:unresolved, status, code}

        _ ->
          {:unresolved, status, :unrecognized_response}
      end
    end

    def decode(%Req.Response{status: status, body: :oversized}, _, _),
      do: {:unresolved, status, :oversized_response}

    def decode(%{reason: reason}, _, _) when reason in [:timeout, :request_timeout],
      do: {:unresolved, nil, :timeout}

    def decode(_, _, _), do: {:unresolved, nil, :transport_error}

    defp decode_checkout(data, reference, status, integration) do
      case data do
        %{"reference" => ^reference, "access_code" => code, "authorization_url" => url}
        when is_binary(code) ->
          if code =~ ~r/\A[A-Za-z0-9_-]{1,128}\z/ and valid_capability?(integration, url, code),
            do: {{:ok, capability_value(integration, url, code)}, status, :initialized},
            else: {:unresolved, status, :invalid_capability}

        _ ->
          {:unresolved, status, :invalid_binding}
      end
    end

    defp valid_capability?(:local_fixture, url, code), do: url == fixture_url(code)

    defp valid_capability?(:voelgoedwinkel, url, code),
      do: url == "https://checkout.paystack.com/" <> code

    defp capability_value(:local_fixture, _, code), do: code
    defp capability_value(:voelgoedwinkel, url, _), do: url
  end
end
