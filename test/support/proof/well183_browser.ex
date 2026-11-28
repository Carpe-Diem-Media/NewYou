defmodule NewYou.Proof.Well183Browser do
  @moduledoc false
  import ExUnit.Assertions
  alias NewYou.{Communications, Identity}
  alias NewYou.Identity.{Account, DeviceAssurance}
  alias NewYou.Proof.{P805, P805Browser, RecoveryScenarios}

  def run(locale) do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      Application.put_env(:new_you, :p8_15_browser_development_fixtures, false)

      request = P805.request(%{preferred_language: String.to_existing_atom(locale)})
      assert {:ok, registration} = Identity.register(request)
      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      device = RecoveryScenarios.trusted_device(registration.account_id)

      result = browser(request, registration.account_id, locale)
      assert result["cleanup"]
      Enum.each(result["operations"], &P805.track_operation/1)

      for check <- ~w(
            discovery_copy discovery_keyboard discovery_destination
            request_copy usable_form keyboard_focus responsive reduced_motion
            neutral_request real_delivery passive_safe confirmation_copy
            credential_copy completed_copy no_automatic_login replay_denied
            old_password_denied fresh_sign_in
          ) do
        assert result["checks"][check] == true, "WELL-183 browser check failed: #{check}"
      end

      assert Ash.get!(Account, registration.account_id, authorize?: false).credential_version == 2
      assert Ash.get!(DeviceAssurance, device, authorize?: false).state == :revoked

      completion = Enum.at(result["operations"], 3)

      assert [%{role: :recovery_security_notice, locale: ^locale, dispatch_disposition: :held}] =
               Enum.filter(P805.intents(completion), &(&1.role == :recovery_security_notice))
    end)
  end

  defp browser(request, account_id, locale) do
    reference = make_ref()

    {:ok, server} =
      Bandit.start_link(
        plug: {__MODULE__.Endpoint, {self(), reference, account_id}},
        ip: {127, 0, 0, 1},
        port: 0
      )

    try do
      {:ok, {_, port}} = ThousandIsland.listener_info(server)

      P805Browser.run_port(
        System.find_executable("node"),
        Path.expand("../../proof/p8_05_browser.mjs", __DIR__),
        Jason.encode!(%{
          mode: "ordinary_recovery",
          port: port,
          locale: locale,
          email: request.email,
          password: request.password,
          replacement: "WELL-183 browser replacement credential"
        })
      )
    after
      Supervisor.stop(server)
      track_operations(reference)
    end
  end

  defp track_operations(ref) do
    receive do
      {^ref, :operation, id} ->
        P805.track_operation(id)
        track_operations(ref)
    after
      0 -> :ok
    end
  end

  defmodule Endpoint do
    @moduledoc false
    @behaviour Plug
    import Plug.Conn
    require Ash.Query
    alias NewYou.Identity.Token

    @impl true
    def init(opts), do: opts

    @impl true
    def call(conn, {parent, reference, account_id}) do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

      try do
        case conn.request_path do
          "/__well183/delivery" ->
            deliver(fetch_query_params(conn), account_id)

          _ ->
            conn
            |> register_before_send(fn response ->
              if response.method == "POST" and is_binary(response.params["operation_id"]),
                do: send(parent, {reference, :operation, response.params["operation_id"]})

              response
            end)
            |> NewYouWeb.Endpoint.call(NewYouWeb.Endpoint.init([]))
        end
      after
        Process.delete(:p810_provider)
        Process.delete({__MODULE__, :proof})
        Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
      end
    end

    defp deliver(conn, account_id) do
      with {:ok, operation} <- Ecto.UUID.cast(conn.query_params["operation"]),
           {:ok, %{render_schema: "recovery-well183-v1"} = intent} <-
             Communications.MessageIntent
             |> Ash.Query.filter(source_operation_id == ^operation and role == :account_recovery)
             |> Ash.read_one(authorize?: false),
           {:ok, %Token{account_id: ^account_id}} <-
             Ash.get(Token, intent.source_reference, authorize?: false) do
        Process.put(:p810_provider, fn _, payload ->
          [_, encoded] =
            Regex.run(~r{/recovery/confirm\?locale=[a-z]+&proof=([^\s]+)}, payload.body)

          Process.put({__MODULE__, :proof}, URI.decode_www_form(encoded))
          :delivered
        end)

        with {:ok, :processed} <- Communications.execute(intent.id),
             proof when is_binary(proof) <- Process.delete({__MODULE__, :proof}) do
          conn
          |> put_resp_header("cache-control", "no-store")
          |> put_resp_content_type("application/json")
          |> send_resp(200, Jason.encode!(%{proof: proof}))
        else
          _ -> send_resp(conn, 503, "")
        end
      else
        _ -> send_resp(conn, 404, "")
      end
    end
  end
end
