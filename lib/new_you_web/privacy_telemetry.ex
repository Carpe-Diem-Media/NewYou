defmodule NewYouWeb.PrivacyTelemetry do
  @moduledoc false

  @behaviour Plug
  @sensitive_browser_paths ["/register", "/verification", "/login", "/session", "/password"]

  @impl Plug
  def init(opts) do
    {event_prefix, opts} = Keyword.pop(opts, :event_prefix)
    {event_prefix ++ [:start], event_prefix ++ [:stop], opts}
  end

  @impl Plug
  def call(conn, {start_event, stop_event, opts}) do
    started_at = System.monotonic_time()

    :telemetry.execute(
      start_event,
      %{system_time: System.system_time()},
      %{conn: telemetry_conn(conn), options: opts}
    )

    Plug.Conn.register_before_send(conn, fn response_conn ->
      :telemetry.execute(
        stop_event,
        %{duration: System.monotonic_time() - started_at},
        %{conn: telemetry_conn(response_conn), options: opts}
      )

      response_conn
    end)
  end

  defp telemetry_conn(%Plug.Conn{request_path: path} = conn)
       when is_binary(path) do
    if sensitive_browser_path?(path), do: sanitize_conn(conn), else: conn
  end

  defp telemetry_conn(conn), do: conn

  defp sanitize_conn(conn) do
    %{
      conn
      | adapter: nil,
        assigns: %{},
        body_params: %{},
        cookies: %{},
        params: %{},
        path_params: %{},
        private: %{},
        query_params: %{},
        query_string: "",
        req_cookies: %{},
        req_headers: [],
        remote_ip: nil,
        resp_body: "",
        resp_cookies: %{},
        resp_headers: [],
        secret_key_base: nil,
        request_path: "/registration",
        path_info: ["registration"],
        script_name: []
    }
  end

  defp sensitive_browser_path?(path) do
    Enum.any?(@sensitive_browser_paths, fn root ->
      path == root or String.starts_with?(path, root <> "/")
    end)
  end
end
