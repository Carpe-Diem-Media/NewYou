defmodule NewYou.Commerce.HostedCheckoutReceiver do
  @moduledoc false

  import Plug.Conn

  def with_receiver(reply, fun) do
    tag = make_ref()

    {:ok, server} =
      Bandit.start_link(
        plug: {__MODULE__, {self(), tag, reply}},
        ip: {127, 0, 0, 1},
        port: 0,
        startup_log: false
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
    payload = Jason.decode!(body)

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
