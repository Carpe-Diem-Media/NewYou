defmodule NewYouWeb.PrivacyTelemetry do
  @moduledoc false

  @behaviour Plug

  # Session cookies accompany ordinary and unknown URLs too. Redact the
  # telemetry projection for every request, leaving the real connection intact.
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
      %{conn: sanitize_conn(conn), options: opts}
    )

    Plug.Conn.register_before_send(conn, fn response_conn ->
      :telemetry.execute(
        stop_event,
        %{duration: System.monotonic_time() - started_at},
        %{conn: sanitize_conn(response_conn), options: opts}
      )

      response_conn
    end)
  end

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
end
