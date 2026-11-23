defmodule NewYouWeb.SupportLookupControllerTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Plug.Conn

  alias NewYou.Identity
  alias NewYou.Proof.{P805, P805Browser, P813HoldFixture, PrivilegedAccessSeam, SignInJourney}

  @endpoint NewYouWeb.Endpoint
  @path "/dev/support/account-access"

  test "explicit CSRF-protected lookup renders only current scoped diagnostics" do
    P813HoldFixture.with_fixture(fn fixture ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      target = P805.account!(fixture.target.id)

      grant =
        P813HoldFixture.grant(fixture.actor, fixture.target, fixture.approver, :identity_lookup)

      timestamp = 1_800_000_000
      Process.put(PrivilegedAccessSeam, timestamp)

      _ = Plug.CSRFProtection.get_csrf_token()
      csrf_state = Plug.CSRFProtection.dump_state()

      conn = fn ->
        Plug.Test.init_test_session(operator_conn(fixture.actor), %{"_csrf_token" => csrf_state})
      end

      page = get(conn.(), @path)
      body = html_response(page, 200)
      [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, body)

      params = %{
        "grant_id" => grant.id,
        "target_account_id" => target.id,
        "email" => target.email,
        "password" => fixture.actor.password,
        "code" => NimbleTOTP.verification_code(fixture.actor.secret, time: timestamp)
      }

      assert post(operator_conn(fixture.actor), @path, params).status == 403

      result =
        conn.()
        |> post(@path, Map.put(params, "_csrf_token", csrf))

      rendered = html_response(result, 200)
      assert rendered =~ "Email verified"
      assert rendered =~ "Security posture"
      assert get_resp_header(result, "cache-control") == ["no-store"]
      assert get_resp_header(result, "referrer-policy") == ["no-referrer"]

      for secret <- [target.email, target.id, grant.id, params["password"], params["code"]] do
        refute rendered =~ secret
      end

      replay = post(conn.(), @path, Map.put(params, "_csrf_token", csrf))
      assert html_response(replay, 403) =~ "Lookup unavailable."
      refute replay.resp_body =~ "Access diagnostics"
      assert response(get(conn.(), @path <> "?target_account_id=" <> target.id), 404) == ""

      Application.put_env(:new_you, :fp001_development_entry, false)
      assert response(get(conn.(), @path), 404) == ""
      Application.put_env(:new_you, :fp001_development_entry, true)

      assert :ok = Identity.logout(fixture.actor.credentials)
      assert get(operator_conn(fixture.actor), @path).status == 404
    end)
  after
    Process.delete(PrivilegedAccessSeam)
  end

  @tag :no_database
  test "private dispatcher rejects an unprotected lookup POST before entering the controller" do
    conn =
      Plug.Test.conn(:post, @path)
      |> Plug.Test.init_test_session(%{})
      |> NewYouWeb.RegistrationBoundary.call([])

    assert conn.status == 403
  end

  test "an anonymous request cannot open the form when the development entry is enabled" do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      assert response(get(build_conn(), @path), 404) == ""
    end)
  end

  test "Chromium clears history state and rechecks current authority after revocation and logout" do
    P813HoldFixture.with_fixture(fn fixture ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      Mix.Task.run("assets.build")

      grant =
        P813HoldFixture.grant(fixture.actor, fixture.target, fixture.approver, :identity_lookup)

      timestamp = 1_800_000_000
      attempts = :atomics.new(1, [])
      options = {grant, fixture.approver.id, timestamp, attempts}

      {:ok, server} =
        Bandit.start_link(
          plug: {__MODULE__.BrowserEndpoint, options},
          ip: {127, 0, 0, 1},
          port: 0
        )

      handler = {__MODULE__, make_ref()}

      :ok =
        :telemetry.attach_many(
          handler,
          [[:bandit, :request, :stop], [:new_you, :repo, :query]],
          &__MODULE__.observe_transport/4,
          self()
        )

      try do
        {:ok, {_, port}} = ThousandIsland.listener_info(server)

        payload =
          Jason.encode!(%{
            mode: "support_lookup",
            locale: "en",
            port: port,
            email: P805.account!(fixture.actor.id).email,
            password: fixture.actor.password,
            target_email: P805.account!(fixture.target.id).email,
            target_account_id: fixture.target.id,
            grant_id: grant.id,
            codes:
              for(
                offset <- [0, 30],
                do: NimbleTOTP.verification_code(fixture.actor.secret, time: timestamp + offset)
              )
          })

        result =
          P805Browser.run_port(
            System.find_executable("node"),
            Path.expand("../../proof/p8_05_browser.mjs", __DIR__),
            payload
          )

        assert result["cleanup"]

        for check <- ~w(
              signed_in keyboard reflow form_cleared_on_leave form_back_blank form_forward form_back_again_blank
              diagnostics private_response result_cleared_on_leave result_restored_as_get
              revoked_back_blank revoked_forward revoked_back_again_blank revoked
              logout_back_denied logout_forward_denied
            ) do
          assert result["checks"][check] == true, "Support lookup browser check failed: #{check}"
        end

        assert_receive {:lookup_transport, 200, true}
        assert_receive {:lookup_transport, 403, true}
        refute_received {:lookup_transport, _, _}
        assert_receive {:lookup_get, 404}
        assert_receive {:lookup_get, 404}
        refute_received :lookup_query_telemetry
      after
        :telemetry.detach(handler)
        Supervisor.stop(server)
      end
    end)
  end

  @doc false
  def observe_transport([:new_you, :repo, :query], _measurements, metadata, test_pid) do
    payload? =
      metadata.params not in [[], nil] or match?({:ok, %{rows: [_ | _]}}, metadata.result)

    if Process.get({__MODULE__, :lookup_request}) && payload?,
      do: send(test_pid, :lookup_query_telemetry)
  end

  def observe_transport([:bandit, :request, :stop], _measurements, %{conn: conn}, test_pid) do
    if conn.request_path == @path and conn.method == "GET" do
      send(test_pid, {:lookup_get, conn.status})
    end

    if conn.request_path == @path and conn.method == "POST" do
      safe =
        conn.params == %{} and conn.body_params == %{} and conn.assigns == %{} and
          conn.private == %{} and conn.req_headers == [] and is_nil(conn.resp_body)

      send(test_pid, {:lookup_transport, conn.status, safe})
    end
  end

  defmodule BrowserEndpoint do
    @moduledoc false
    @behaviour Plug
    import Plug.Conn

    def init(options), do: options

    def call(
          %{method: "POST", request_path: "/dev/support/account-access"} = conn,
          {grant, approver_id, timestamp, attempts}
        ) do
      attempt = :atomics.add_get(attempts, 1, 1)
      Process.put(PrivilegedAccessSeam, timestamp + 30 * (attempt - 1))

      conn
      |> register_before_send(fn response ->
        if response.status == 200 and attempt == 1, do: revoke_fixture_grant(grant, approver_id)

        response
      end)
      |> dispatch_lookup()
    after
      Process.delete(PrivilegedAccessSeam)
    end

    def call(%{request_path: "/dev/support/account-access"} = conn, _options),
      do: dispatch_lookup(conn)

    def call(conn, _options), do: SignInJourney.Endpoint.call(conn, [])

    defp revoke_fixture_grant(grant, approver_id) do
      # The proof observes lookup queries separately from the independent
      # fixture's audited grant revocation.
      Process.delete({NewYouWeb.SupportLookupControllerTest, :lookup_request})

      Ash.update!(grant, %{actor_id: approver_id, reason_code: :security_review},
        action: :revoke,
        authorize?: false
      )
    after
      Process.put({NewYouWeb.SupportLookupControllerTest, :lookup_request}, true)
    end

    defp dispatch_lookup(conn) do
      Process.put({NewYouWeb.SupportLookupControllerTest, :lookup_request}, true)
      SignInJourney.Endpoint.call(conn, [])
    after
      Process.delete({NewYouWeb.SupportLookupControllerTest, :lookup_request})
    end
  end

  defp operator_conn(actor) do
    conn = build_conn() |> put_private(:plug_skip_csrf_protection, false)

    Plug.Test.init_test_session(conn, %{
      identity_session_id: actor.credentials.session_id,
      identity_token: actor.credentials.token
    })
  end
end
