defmodule NewYou.Proof.Well156Browser do
  @moduledoc false
  @behaviour Plug

  import ExUnit.Assertions
  import Plug.Conn

  alias NewYou.{Identity, Repo}
  alias NewYou.Identity.Account
  alias NewYou.Proof.{P805, P805Browser}

  def run(locale) do
    P805.with_fixture(fn ->
      request = P805.request()
      target = P805.request().email
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)

      {:ok, server} =
        Bandit.start_link(
          plug: {__MODULE__, {registration.account_id, operation_id, target, locale}},
          ip: {127, 0, 0, 1},
          port: 0
        )

      try do
        {:ok, {_, port}} = ThousandIsland.listener_info(server)
        assert_browser(locale, request, port, operation_id, target)

        assert %{email: ^target, primary_email_change_state: :applied} =
                 Ash.get!(Account, registration.account_id, authorize?: false)
      after
        Supervisor.stop(server)
      end
    end)
  end

  defp assert_browser(locale, request, port, operation_id, target) do
    payload =
      Jason.encode!(%{
        mode: "ordinary_email_change",
        port: port,
        locale: locale,
        email: request.email,
        password: request.password,
        target: target,
        operation_id: operation_id
      })

    result =
      P805Browser.run_port(
        System.find_executable("node"),
        Path.expand("../../proof/p8_05_browser.mjs", __DIR__),
        payload
      )

    assert result["cleanup"]

    for check <- ~w(entry stylesheet keyboard_focus reflow text_resize reduced_motion
                    accessible_form requested pending confirm confirmed applied fresh_sign_in) do
      assert result["checks"][check] == true, "WELL-156 browser check failed: #{check}"
    end
  end

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, {account_id, operation_id, target, locale}) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

    try do
      case conn.request_path do
        "/__well156/" <> ^operation_id -> proof(conn, account_id, operation_id, target, locale)
        _ -> NewYouWeb.Endpoint.call(conn, NewYouWeb.Endpoint.init([]))
      end
    after
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)
    end
  end

  # Loopback test fixture reads only the seeded Account's held proof. The
  # application never exposes this endpoint or sends the email to a provider.
  defp proof(conn, account_id, operation_id, target, locale) do
    assert %{
             primary_email_change_operation_id: ^operation_id,
             primary_email_change_token_jti: jti
           } =
             Ash.get!(Account, account_id, authorize?: false)

    assert {:ok, {:ok, bearer}} =
             Repo.transaction(fn ->
               Identity.primary_email_change_delivery(jti, target, locale)
             end)

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{proof: bearer}))
  end
end
