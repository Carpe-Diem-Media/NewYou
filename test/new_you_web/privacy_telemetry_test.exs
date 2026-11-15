defmodule NewYouWeb.PrivacyTelemetryTest do
  use ExUnit.Case, async: false

  import Plug.Conn

  test "endpoint events redact transport and payload on every request path" do
    events = [[:well134, :browser, :start], [:well134, :browser, :stop]]
    handler = attach(events)

    try do
      for path <- [
            "/",
            "/login",
            "/session/protected",
            "/legal/terms",
            "/legal/privacy",
            "/support",
            "/unrecognised"
          ] do
        conn =
          Plug.Test.conn(:post, path <> "?proof=synthetic-query-proof")
          |> put_req_header("cookie", "synthetic-session-transport")
          |> put_req_header("authorization", "Bearer synthetic-authorization")
          |> Plug.Test.init_test_session(%{identity_token: "synthetic-session-bearer"})
          |> assign(:private_context, "synthetic-context")
          |> Map.put(:secret_key_base, "synthetic-endpoint-key")
          |> Map.put(:body_params, %{"password" => "synthetic-password"})

        result =
          conn
          |> NewYouWeb.PrivacyTelemetry.call(
            NewYouWeb.PrivacyTelemetry.init(event_prefix: [:well134, :browser])
          )
          |> put_resp_cookie("synthetic", "synthetic-response-cookie")
          |> send_resp(200, "synthetic-response-body")

        # Redaction is a telemetry projection, not a mutation of the real request.
        assert result.req_headers == conn.req_headers
        assert get_session(result, :identity_token) == "synthetic-session-bearer"
        assert result.resp_body == "synthetic-response-body"

        for event <- events do
          assert_receive {:observed, ^event, metadata}
          observed = metadata.conn

          hidden =
            observed.adapter == nil and observed.assigns == %{} and
              observed.body_params == %{} and observed.cookies == %{} and
              observed.params == %{} and observed.path_params == %{} and
              observed.private == %{} and observed.query_params == %{} and
              observed.query_string == "" and observed.req_cookies == %{} and
              observed.req_headers == [] and observed.remote_ip == nil and
              observed.resp_body == "" and observed.resp_cookies == %{} and
              observed.resp_headers == [] and observed.secret_key_base == nil and
              observed.request_path == "/registration" and observed.path_info == ["registration"]

          assert hidden, "endpoint redaction failed for #{path}"
          assert observed.status == if(List.last(event) == :stop, do: 200, else: nil)
        end
      end
    after
      :telemetry.detach(handler)
    end
  end

  test "legal pages keep session-bearing requests out of router dispatch telemetry" do
    events = [[:phoenix, :router_dispatch, :start], [:phoenix, :router_dispatch, :stop]]
    handler = attach(events)
    previous = Application.fetch_env(:new_you, :fp001_development_entry)
    Application.put_env(:new_you, :fp001_development_entry, true)

    try do
      for method <- [:get, :head], path <- ["/legal/terms", "/legal/privacy"] do
        conn =
          Plug.Test.conn(method, path)
          |> Plug.Test.init_test_session(%{identity_token: "synthetic-session-bearer"})
          |> put_req_header("cookie", "synthetic-session-transport")
          |> put_private(:phoenix_endpoint, NewYouWeb.Endpoint)

        result = NewYouWeb.RegistrationBoundary.call(conn, [])
        assert result.status == 200
        assert get_resp_header(result, "cache-control") == ["no-store"]
        assert observed_events() == []
      end

      Application.put_env(:new_you, :fp001_development_entry, false)

      for path <- ["/legal/terms", "/legal/privacy"] do
        conn = Plug.Test.conn(:get, path) |> Plug.Test.init_test_session(%{})
        assert NewYouWeb.RegistrationBoundary.call(conn, []).status == 404
        assert observed_events() == []
      end
    after
      :telemetry.detach(handler)

      case previous do
        {:ok, value} -> Application.put_env(:new_you, :fp001_development_entry, value)
        :error -> Application.delete_env(:new_you, :fp001_development_entry)
      end
    end
  end

  test "unfinished paths and unsupported methods fail closed without router errors or telemetry" do
    handler =
      attach([
        [:phoenix, :router_dispatch, :start],
        [:phoenix, :router_dispatch, :stop],
        [:phoenix, :error_rendered]
      ])

    try do
      for method <- [:get, :post, :put, :patch, :delete, :options],
          path <- ["/support", "/assessment", "/unknown", "/legal/terms/", "/legal/privacy/"] do
        conn =
          Plug.Test.conn(method, path <> "?proof=synthetic-query-proof")
          |> Plug.Test.init_test_session(%{identity_token: "synthetic-session-bearer"})
          |> put_req_header("cookie", "synthetic-session-transport")
          |> put_private(:phoenix_endpoint, NewYouWeb.Endpoint)

        assert NewYouWeb.RegistrationBoundary.call(conn, []).status == 404
        assert observed_events() == []
      end
    after
      :telemetry.detach(handler)
    end
  end

  test "malformed requests return safe errors without full-connection error telemetry" do
    handler =
      attach([
        [:phoenix, :endpoint, :start],
        [:phoenix, :endpoint, :stop],
        [:phoenix, :router_dispatch, :start],
        [:phoenix, :router_dispatch, :stop],
        [:phoenix, :error_rendered]
      ])

    try do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          for {method, path} <- [
                {:post, "/login?proof=synthetic-query-proof"},
                {:post, "/login/magic?proof=synthetic-query-proof"},
                {:get, "/legal/terms?invalid=%FF"}
              ] do
            conn =
              Plug.Test.conn(method, path, "{")
              |> put_req_header("content-type", "application/json")
              |> put_req_header("cookie", "synthetic-session-transport")

            result = NewYouWeb.Endpoint.call(conn, [])
            assert result.status == 400
            assert result.resp_body == ""

            for event <- [[:phoenix, :endpoint, :start], [:phoenix, :endpoint, :stop]] do
              assert_receive {:observed, ^event, %{conn: observed}}

              hidden =
                observed.req_headers == [] and observed.private == %{} and
                  observed.query_params == %{} and observed.secret_key_base == nil

              assert hidden
            end

            assert observed_events() == []
          end
        end)

      refute log =~ "synthetic-session-transport"
      refute log =~ "synthetic-query-proof"
    after
      :telemetry.detach(handler)
    end
  end

  defp observed_events(acc \\ []) do
    receive do
      {:observed, event, _metadata} -> observed_events([event | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp attach(events) do
    handler = "well134-browser-#{System.unique_integer([:positive])}"
    :ok = :telemetry.attach_many(handler, events, &__MODULE__.observe/4, self())
    handler
  end

  def observe(event, _, metadata, parent), do: send(parent, {:observed, event, metadata})
end
