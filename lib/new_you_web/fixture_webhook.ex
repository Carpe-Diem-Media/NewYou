if Mix.env() == :test do
  defmodule NewYouWeb.FixtureWebhook do
    @moduledoc false
    @behaviour Plug

    import Plug.Conn

    @impl Plug
    def init(opts), do: opts

    @impl Plug
    def call(%{request_path: "/__test/commerce/fixture-webhook"} = conn, _opts) do
      {status, conn} = read_request(conn)
      conn |> send_resp(status, "") |> halt()
    end

    def call(conn, _opts), do: conn

    defp read_request(%{method: "POST", query_string: ""} = conn) do
      with %{address: {127, _, _, _}} <- get_peer_data(conn),
           ["application/json"] <- get_req_header(conn, "content-type") do
        read_fixture_body(conn)
      else
        _ -> {404, conn}
      end
    end

    defp read_request(conn), do: {404, conn}

    defp read_fixture_body(conn) do
      case read_body(conn, length: 8_192, read_length: 8_193, read_timeout: 1_000) do
        {:ok, raw, conn} when byte_size(raw) <= 8_192 ->
          {ingest_status(raw, get_req_header(conn, "x-newyou-fixture-signature")), conn}

        {result, _, conn} when result in [:ok, :more] ->
          {413, conn}

        {:error, _} ->
          {400, conn}
      end
    end

    defp ingest_status(raw, signature) do
      case NewYou.Commerce.HostedPaymentEvidence.ingest(raw, signature) do
        :ok -> 202
        {:error, :unauthenticated} -> 401
        {:error, :unsupported} -> 400
        {:error, :unavailable} -> 503
      end
    end
  end
end
