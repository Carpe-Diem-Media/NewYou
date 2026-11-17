defmodule NewYouWeb.DesignSystemBoundary do
  @moduledoc false

  alias NewYouWeb.{DesignSystemLive, Endpoint, Layouts, Router}

  # Only RegistrationBoundary's exact DEV/test GET allowlist calls this module.
  # Render through a fresh connection: LiveView telemetry retains its Conn.
  # The real request sends the response but never enters a LiveView socket.
  @spec render(Plug.Conn.t()) :: Plug.Conn.t()
  def render(conn) do
    %{phoenix_live_view: {DesignSystemLive, _action, options, live_session}} =
      Phoenix.Router.route_info(Router, "GET", conn.request_path, conn.host)

    params =
      conn
      |> Plug.Conn.fetch_query_params()
      |> Map.fetch!(:query_params)
      |> DesignSystemLive.display_params()

    query = params |> Enum.sort() |> URI.encode_query()

    render_conn = %Plug.Conn{
      adapter: nil,
      host: conn.host,
      port: conn.port,
      scheme: conn.scheme,
      method: "GET",
      request_path: conn.request_path,
      path_info: conn.path_info,
      params: params,
      query_params: params,
      query_string: query,
      body_params: %{},
      cookies: %{},
      req_cookies: %{},
      private: %{
        phoenix_endpoint: Endpoint,
        phoenix_router: Router,
        phoenix_live_view: {DesignSystemLive, options, live_session},
        plug_session: %{},
        plug_session_fetch: :done
      }
    }

    content = Phoenix.Component.live_render(render_conn, DesignSystemLive, options)

    conn
    |> Map.put(:query_string, query)
    |> Map.put(:query_params, params)
    |> Map.put(:params, params)
    |> Plug.Conn.assign(:live_module, DesignSystemLive)
    |> Plug.Conn.put_private(:phoenix_router, Router)
    |> Phoenix.Controller.put_secure_browser_headers()
    |> Plug.Conn.put_resp_header("cache-control", "no-store")
    |> Phoenix.Controller.accepts(["html"])
    |> Phoenix.Controller.put_view(html: Layouts)
    |> Phoenix.Controller.put_layout(false)
    |> Phoenix.Controller.put_root_layout(false)
    |> Phoenix.Controller.render(:root,
      inner_content: content,
      page_title: "Design system",
      page_language: "en"
    )
  end
end
