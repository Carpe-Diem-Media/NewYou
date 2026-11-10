defmodule NewYouWeb.RegistrationBoundary do
  @moduledoc """
  Dispatches the registration browser paths without Phoenix.Router's full-conn
  dispatch telemetry. Controllers still own rendering and call Identity interfaces.
  """

  @behaviour Plug

  alias NewYouWeb.RegistrationController
  alias NewYouWeb.EmailVerificationController
  alias NewYouWeb.PasswordSessionController
  alias NewYouWeb.MagicLoginController

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{method: "GET", request_path: "/register"} = conn, _opts) do
    dispatch_browser_request(conn, :new)
  end

  def call(%Plug.Conn{method: "POST", request_path: "/register"} = conn, _opts) do
    dispatch_browser_request(conn, :create)
  end

  def call(%Plug.Conn{method: "POST", request_path: "/verification/resend"} = conn, _opts) do
    dispatch_browser_request(conn, :resend)
  end

  def call(%Plug.Conn{method: "GET", request_path: "/verification/confirm"} = conn, _opts) do
    dispatch_browser_request(conn, :show, EmailVerificationController)
  end

  def call(%Plug.Conn{method: "POST", request_path: "/verification/confirm"} = conn, _opts) do
    dispatch_browser_request(conn, :confirm, EmailVerificationController)
  end

  def call(%Plug.Conn{method: "GET", request_path: "/recovery/confirm"} = conn, _opts),
    do: dispatch_browser_request(conn, :show, NewYouWeb.RecoveryController)

  def call(%Plug.Conn{method: "POST", request_path: "/recovery"} = conn, _opts),
    do: dispatch_browser_request(conn, :request, NewYouWeb.RecoveryController)

  def call(%Plug.Conn{method: "POST", request_path: "/recovery/confirm"} = conn, _opts),
    do: dispatch_browser_request(conn, :confirm, NewYouWeb.RecoveryController)

  def call(%Plug.Conn{method: "POST", request_path: "/recovery/complete"} = conn, _opts),
    do: dispatch_browser_request(conn, :complete, NewYouWeb.RecoveryController)

  def call(%Plug.Conn{method: "POST", request_path: "/recovery/cancel"} = conn, _opts),
    do: dispatch_browser_request(conn, :cancel, NewYouWeb.RecoveryController)

  def call(%Plug.Conn{method: "GET", request_path: "/password/reset"} = conn, _opts),
    do: dispatch_browser_request(conn, :new, NewYouWeb.PasswordResetController)

  def call(%Plug.Conn{method: "POST", request_path: "/password/reset"} = conn, _opts),
    do: dispatch_browser_request(conn, :request, NewYouWeb.PasswordResetController)

  def call(%Plug.Conn{method: "GET", request_path: "/password/reset/confirm"} = conn, _opts),
    do: dispatch_browser_request(conn, :show, NewYouWeb.PasswordResetController)

  def call(%Plug.Conn{method: "POST", request_path: "/password/reset/confirm"} = conn, _opts),
    do: dispatch_browser_request(conn, :confirm, NewYouWeb.PasswordResetController)

  def call(%Plug.Conn{method: "GET", request_path: "/login"} = conn, _opts),
    do: dispatch_browser_request(conn, :new, PasswordSessionController)

  def call(%Plug.Conn{method: "GET", request_path: "/login/magic"} = conn, _opts),
    do: dispatch_browser_request(conn, :new, MagicLoginController)

  def call(%Plug.Conn{method: "POST", request_path: "/login/magic"} = conn, _opts),
    do: dispatch_browser_request(conn, :request, MagicLoginController)

  def call(%Plug.Conn{method: "GET", request_path: "/login/magic/confirm"} = conn, _opts),
    do: dispatch_browser_request(conn, :show, MagicLoginController)

  def call(%Plug.Conn{method: "POST", request_path: "/login/magic/confirm"} = conn, _opts),
    do: dispatch_browser_request(conn, :confirm, MagicLoginController)

  def call(%Plug.Conn{method: "POST", request_path: "/login"} = conn, _opts),
    do: dispatch_browser_request(conn, :create, PasswordSessionController)

  def call(%Plug.Conn{method: "GET", request_path: "/session/protected"} = conn, _opts),
    do: dispatch_browser_request(conn, :protected, PasswordSessionController)

  def call(%Plug.Conn{method: "POST", request_path: "/session/logout"} = conn, _opts),
    do: dispatch_browser_request(conn, :logout, PasswordSessionController)

  def call(%Plug.Conn{request_path: path} = conn, _opts) do
    if sensitive_browser_path?(path) do
      fail_closed_response(conn, 404)
    else
      NewYouWeb.Router.call(conn, NewYouWeb.Router.init([]))
    end
  end

  defp dispatch_browser_request(conn, action, controller \\ RegistrationController) do
    conn
    |> Plug.Conn.fetch_query_params()
    |> Phoenix.Controller.accepts(["html"])
    |> Plug.Conn.fetch_session()
    |> Phoenix.LiveView.Router.fetch_live_flash([])
    |> Phoenix.Controller.put_root_layout(html: {NewYouWeb.Layouts, :root})
    |> Plug.CSRFProtection.call(Plug.CSRFProtection.init([]))
    |> Phoenix.Controller.put_secure_browser_headers()
    |> controller.call(action)
  rescue
    error ->
      log_browser_failure(error.__struct__)

      fail_closed_response(
        conn,
        if(match?(%Plug.CSRFProtection.InvalidCSRFTokenError{}, error), do: 403, else: 500)
      )
  catch
    kind, _reason ->
      log_browser_failure(kind)
      fail_closed_response(conn, 500)
  end

  defp fail_closed_response(conn, status) do
    conn
    |> Phoenix.Controller.put_secure_browser_headers()
    |> Plug.Conn.send_resp(status, "")
  end

  defp log_browser_failure(error_kind) do
    require Logger
    Logger.error("WELL-52 browser action failed (#{inspect(error_kind)})")
  end

  defp sensitive_browser_path?(path) do
    Enum.any?(
      ["/register", "/verification", "/login", "/session", "/password", "/recovery"],
      fn root ->
        path == root or String.starts_with?(path, root <> "/")
      end
    )
  end
end
