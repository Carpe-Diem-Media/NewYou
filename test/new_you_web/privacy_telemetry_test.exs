defmodule NewYouWeb.PrivacyTelemetryTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest, only: [get: 2]
  import Phoenix.LiveViewTest

  @endpoint NewYouWeb.Endpoint

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

  test "DEV guide paths render without exposing session transport to router telemetry" do
    handler =
      attach([
        [:phoenix, :router_dispatch, :start],
        [:phoenix, :router_dispatch, :stop],
        [:phoenix, :error_rendered]
      ])

    try do
      for method <- [:get, :head],
          path <- ["/dev/design-system", "/dev/design-system/preview"] do
        conn =
          Phoenix.ConnTest.build_conn()
          |> Plug.Test.init_test_session(%{identity_token: "synthetic-session-bearer"})
          |> put_req_header("cookie", "synthetic-session-transport")
          |> put_req_header("authorization", "Bearer synthetic-authorization")

        result =
          Phoenix.ConnTest.dispatch(
            conn,
            NewYouWeb.Endpoint,
            method,
            path <> "?proof=synthetic-query-proof",
            nil
          )

        assert result.status == 200
        assert observed_events() == []
      end

      for {method, path} <- [
            {:post, "/dev/design-system"},
            {:post, "/dev/design-system/preview"},
            {:get, "/dev/design-system/unknown"},
            {:get, "/dev/design-system/"}
          ] do
        conn =
          Phoenix.ConnTest.build_conn()
          |> Plug.Test.init_test_session(%{identity_token: "synthetic-session-bearer"})

        assert Phoenix.ConnTest.dispatch(conn, NewYouWeb.Endpoint, method, path, nil).status ==
                 404

        assert observed_events() == []
      end
    after
      :telemetry.detach(handler)
    end
  end

  test "guide mounts and connected events exclude the original request and Identity session" do
    events =
      for stage <- [:mount, :handle_params, :handle_event], edge <- [:start, :stop] do
        [:phoenix, :live_view, stage, edge]
      end

    handler = attach(events)

    try do
      for path <- ["/dev/design-system", "/dev/design-system/preview"] do
        conn =
          Phoenix.ConnTest.build_conn()
          |> Plug.Test.init_test_session(%{identity_token: "synthetic-session-bearer"})
          |> put_req_header("cookie", "synthetic-session-transport")
          |> put_req_header("authorization", "Bearer synthetic-authorization")
          |> assign(:private_context, "synthetic-private-context")

        result =
          Phoenix.ConnTest.dispatch(
            conn,
            @endpoint,
            :get,
            path <> "?count=synthetic-invalid-count&proof=synthetic-query-proof",
            nil
          )

        assert result.status == 200
        assert get_session(result, :identity_token) == "synthetic-session-bearer"
        assert get_resp_header(result, "cache-control") == ["no-store"]
        assert result.resp_body =~ ~s|data-live-socket="/dev/design-system/live"|

        assert_guide_metadata(observed_metadata(), [:mount, :handle_params])

        # LiveViewTest otherwise inserts the original test Conn/session into the
        # simulated socket. Match the guide's real sessionless transport instead.
        result = put_private(result, :live_view_connect_info, %{session: %{}})
        {:ok, view, _html} = live(result)
        assert_guide_metadata(observed_metadata(), [:mount, :handle_params])

        if path == "/dev/design-system" do
          view
          |> element("#grid-controls")
          |> render_change(%{"grid" => %{"count" => "4", "alignment" => "center"}})

          assert_patch(view, "/dev/design-system?alignment=center&count=4&viewport=auto")
          assert has_element?(view, "#card-grid[data-alignment=center]")
          assert_guide_metadata(observed_metadata(), [:handle_event, :handle_params])
        end
      end
    after
      :telemetry.detach(handler)
    end
  end

  test "the dedicated guide transport never reads the browser session" do
    assert {_, _, options} =
             Enum.find(@endpoint.__sockets__(), fn {path, _, _} ->
               path == "/dev/design-system/live"
             end)

    for transport <- [:websocket, :longpoll] do
      keys = Keyword.fetch!(options[transport], :connect_info)
      assert keys == []

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("cookie", "synthetic-session-transport")

      assert Phoenix.Socket.Transport.connect_info(conn, @endpoint, keys) == %{}
      assert options[transport][:check_origin] == :conn

      same_origin = put_req_header(conn, "origin", "http://www.example.com")

      refute Phoenix.Socket.Transport.check_origin(
               same_origin,
               Phoenix.LiveView.Socket,
               @endpoint,
               options[transport]
             ).halted

      ExUnit.CaptureLog.capture_log(fn ->
        for origin <- [
              "http://untrusted.example",
              "https://www.example.com",
              "http://www.example.com:8765"
            ] do
          rejected =
            conn
            |> put_req_header("origin", origin)
            |> Phoenix.Socket.Transport.check_origin(
              Phoenix.LiveView.Socket,
              @endpoint,
              options[transport]
            )

          assert rejected.status == 403
          assert rejected.halted
        end
      end)
    end
  end

  test "the sessionless transport is reviewed again before another LiveView is routed" do
    views =
      NewYouWeb.Router
      |> Phoenix.Router.routes()
      |> Enum.flat_map(fn route ->
        case route.metadata[:phoenix_live_view] do
          {view, _, _, _} -> [view]
          _ -> []
        end
      end)
      |> Enum.uniq()

    assert views == [NewYouWeb.DesignSystemLive]
  end

  test "production compiles neither guide dispatch nor its sessionless transport" do
    for {file, replacement} <- [
          {"lib/new_you_web/registration_boundary.ex", NewYouWeb.DesignSystemProductionBoundary},
          {"lib/new_you_web/endpoint.ex", NewYouWeb.DesignSystemProductionEndpoint}
        ] do
      ast =
        file
        |> File.read!()
        |> Code.string_to_quoted!()
        |> Macro.prewalk(fn
          {:defmodule, meta, [_name, body]} -> {:defmodule, meta, [replacement, body]}
          {{:., _, [{:__aliases__, _, [:Mix]}, :env]}, _, []} -> :prod
          node -> node
        end)

      Code.compile_quoted(ast)
    end

    boundary = Module.concat(NewYouWeb, "DesignSystemProductionBoundary")
    endpoint = Module.concat(NewYouWeb, "DesignSystemProductionEndpoint")

    for path <- ["/dev/design-system", "/dev/design-system/preview"] do
      conn = Phoenix.ConnTest.build_conn(:get, path)
      assert boundary.call(conn, []).status == 404
    end

    refute Enum.any?(endpoint.__sockets__(), fn {path, _, _} ->
             String.starts_with?(path, "/dev/design-system")
           end)
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

  defp observed_metadata(acc \\ []) do
    receive do
      {:observed, event, metadata} -> observed_metadata([{event, metadata} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp assert_guide_metadata(observed, stages) do
    for stage <- stages do
      assert Enum.any?(observed, fn {event, _} ->
               event == [:phoenix, :live_view, stage, :start]
             end)
    end

    markers = [
      "synthetic-session-bearer",
      "synthetic-session-transport",
      "synthetic-authorization",
      "synthetic-private-context",
      "synthetic-invalid-count",
      "synthetic-query-proof",
      @endpoint.config(:secret_key_base)
    ]

    for {_event, metadata} <- observed do
      encoded = :erlang.term_to_binary(metadata)

      assert Enum.all?(markers, fn marker -> :binary.match(encoded, marker) == :nomatch end),
             "guide telemetry retained sensitive request data"
    end
  end

  defp attach(events) do
    handler = "well134-browser-#{System.unique_integer([:positive])}"
    :ok = :telemetry.attach_many(handler, events, &__MODULE__.observe/4, self())
    handler
  end

  def observe(event, _, metadata, parent), do: send(parent, {:observed, event, metadata})
end
