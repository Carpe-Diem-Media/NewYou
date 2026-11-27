defmodule NewYou.Commerce.HostedCheckoutReceiver do
  @moduledoc false

  import Plug.Conn

  def with_bound_receiver(reply, fun, options \\ []) do
    san = {:Extension, {2, 5, 29, 17}, false, [{:iPAddress, [127, 0, 0, 1]}]}

    %{cert: certificate, key: key} =
      :public_key.pkix_test_root_cert(~c"NewYou local fixture",
        key: {:namedCurve, {1, 2, 840, 10_045, 3, 1, 7}},
        digest: :sha256,
        extensions: [san]
      )

    der_key = {elem(key, 0), :public_key.der_encode(elem(key, 0), key)}

    options =
      Keyword.merge(options,
        scheme: :https,
        thousand_island_options: [transport_options: [cert: certificate, key: der_key]]
      )

    with_receiver(
      reply,
      fn port, tag -> fun.(%{port: port, certificate: certificate}, tag) end,
      options
    )
  end

  def with_receiver(reply, fun, options \\ []) do
    tag = make_ref()

    {:ok, server} =
      Bandit.start_link(
        Keyword.merge(
          [
            plug: {__MODULE__, {self(), tag, reply}},
            ip: {127, 0, 0, 1},
            port: 0,
            startup_log: false
          ],
          options
        )
      )

    try do
      {:ok, {{127, 0, 0, 1}, port}} = ThousandIsland.listener_info(server)
      fun.(port, tag)
    after
      Supervisor.stop(server)
    end
  end

  def init(options), do: options

  def call(conn, {observer, tag, reply}) do
    {:ok, body, conn} = read_body(conn)
    payload = if body == "", do: %{}, else: Jason.decode!(body)

    send(
      observer,
      {tag, conn.method, conn.request_path, get_req_header(conn, "authorization"), payload}
    )

    reply.(conn, payload)
  end

  def json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end

  def success(conn, payload, code \\ "fixture-checkout-canary") do
    json(conn, 200, %{
      status: true,
      data: %{
        reference: payload["reference"],
        access_code: code,
        authorization_url: "https://checkout.paystack.invalid/" <> code
      }
    })
  end
end
