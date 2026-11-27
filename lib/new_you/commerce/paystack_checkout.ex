defmodule NewYou.Commerce.PaystackCheckout do
  @moduledoc false

  # The only wire implementation is compiled into TEST. A fixture port never
  # selects a host, a credential, a proxy, a Req plugin or a request adapter.
  if Mix.env() == :test do
    @fixture_origin "https://checkout.paystack.invalid/"
    @fixture_key "rk_test_fixture_well218"
    @response_limit 16_384
    @known_codes ~w(duplicate_reference transaction_not_found invalid_params)

    @doc false
    def fixture_url(code), do: @fixture_origin <> code

    @doc false
    def build(%{amount_minor: amount, currency: "ZAR"}, reference, port)
        when is_integer(amount) and amount > 0 and is_binary(reference) and
               is_integer(port) and port in 1..65_535 do
      # Adapt the Store Initialize envelope and restricted, non-retrying POST.
      # The local fixture has no callback, participant contact data or metadata.
      payload = %{
        amount: amount,
        currency: "ZAR",
        reference: reference,
        email: "checkout-fixture@example.com",
        channels: ["card"]
      }

      # A bare request bypasses Req global defaults. HTTP/1 also excludes
      # Finch's transparent retry on a draining HTTP/2 pool.
      Req.Request.new(
        method: :post,
        url: "http://127.0.0.1:#{port}/transaction/initialize",
        headers: [{"authorization", "Bearer " <> @fixture_key}],
        options: [
          json: payload,
          retry: false,
          redirect: false,
          raw: true,
          connect_options: [timeout: 500, protocols: [:http1]],
          pool_timeout: 500,
          receive_timeout: 500,
          request_timeout: 1000
        ]
      )
      |> Req.Steps.attach()
      |> Map.replace!(:into, &collect_body/2)
    end

    defp collect_body({:data, chunk}, {request, response}) do
      if byte_size(response.body) + byte_size(chunk) <= @response_limit do
        {:cont, {request, %{response | body: response.body <> chunk}}}
      else
        {:halt, {request, %{response | body: :oversized}}}
      end
    end

    # Adapt Store's typed envelope and match the exact request reference.
    # Only the canonical, non-routable fixture capability is ever retained.
    def decode(%Req.Response{status: status, body: body}, reference) when is_binary(body) do
      case Jason.decode(body) do
        {:ok, %{"status" => true, "data" => data}} when status in [200, 201] ->
          decode_checkout(data, reference, status)

        {:ok, %{"status" => false, "code" => code}} when code in @known_codes ->
          {:unresolved, status, code}

        _ ->
          {:unresolved, status, :unrecognized_response}
      end
    end

    def decode(%Req.Response{status: status, body: :oversized}, _),
      do: {:unresolved, status, :oversized_response}

    def decode(%{reason: reason}, _) when reason in [:timeout, :request_timeout],
      do: {:unresolved, nil, :timeout}

    def decode(_, _), do: {:unresolved, nil, :transport_error}

    defp decode_checkout(data, reference, status) do
      case data do
        %{"reference" => ^reference, "access_code" => code, "authorization_url" => url}
        when is_binary(code) ->
          if code =~ ~r/\A[A-Za-z0-9_-]{1,128}\z/ and url == fixture_url(code),
            do: {{:ok, code}, status, :initialized},
            else: {:unresolved, status, :invalid_capability}

        _ ->
          {:unresolved, status, :invalid_binding}
      end
    end
  end
end
