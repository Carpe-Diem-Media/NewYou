defmodule NewYouWeb.RegistrationBoundary do
  @moduledoc """
  Dispatches the reviewed browser paths without Phoenix.Router's full-conn
  telemetry. Unknown paths fail closed before framework error telemetry can
  retain their session transport. Controllers render and call Identity interfaces.
  """

  @behaviour Plug

  alias NewYouWeb.RegistrationController
  alias NewYouWeb.EmailVerificationController
  alias NewYouWeb.PasswordSessionController
  alias NewYouWeb.MagicLoginController
  alias NewYouWeb.PrimaryEmailChangeController

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    conn
    |> Plug.Parsers.call(
      Plug.Parsers.init(
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Phoenix.json_library()
      )
    )
    |> Plug.MethodOverride.call(Plug.MethodOverride.init([]))
    |> Plug.Head.call(Plug.Head.init([]))
    |> dispatch(opts)
  rescue
    error ->
      log_browser_failure(error.__struct__)
      fail_closed_response(conn, Plug.Exception.status(error))
  catch
    kind, _reason ->
      log_browser_failure(kind)
      fail_closed_response(conn, 500)
  end

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/"} = conn, _opts) do
    dispatch_browser_request(conn, :new)
  end

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/register"} = conn, _opts) do
    dispatch_browser_request(conn, :new)
  end

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/register"} = conn, _opts) do
    dispatch_browser_request(conn, :create)
  end

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/verification/resend"} = conn, _opts) do
    dispatch_browser_request(conn, :resend)
  end

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/verification/confirm"} = conn, _opts) do
    dispatch_browser_request(conn, :show, EmailVerificationController)
  end

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/verification/confirm"} = conn, _opts) do
    dispatch_browser_request(conn, :confirm, EmailVerificationController)
  end

  defp dispatch(
         %Plug.Conn{method: method, request_path: "/primary-email-change/confirm"} = conn,
         _opts
       )
       when method in ["GET", "HEAD"] do
    dispatch_browser_request(conn, :show, PrimaryEmailChangeController)
  end

  defp dispatch(
         %Plug.Conn{method: "POST", request_path: "/primary-email-change/confirm"} = conn,
         _opts
       ) do
    dispatch_browser_request(conn, :confirm, PrimaryEmailChangeController)
  end

  defp dispatch(
         %Plug.Conn{method: "GET", request_path: "/primary-email-change/confirmation"} = conn,
         _opts
       ),
       do:
         dispatch_browser_request(
           conn,
           :confirmation,
           NewYouWeb.OrdinaryPrimaryEmailChangeController
         )

  defp dispatch(
         %Plug.Conn{method: "POST", request_path: "/primary-email-change/confirmation"} = conn,
         _opts
       ),
       do:
         dispatch_browser_request(conn, :confirm, NewYouWeb.OrdinaryPrimaryEmailChangeController)

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/primary-email-change"} = conn, _opts),
    do: dispatch_browser_request(conn, :show, NewYouWeb.OrdinaryPrimaryEmailChangeController)

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/primary-email-change"} = conn, _opts),
    do: dispatch_browser_request(conn, :request, NewYouWeb.OrdinaryPrimaryEmailChangeController)

  defp dispatch(
         %Plug.Conn{method: "POST", request_path: "/primary-email-change/advance"} = conn,
         _opts
       ),
       do:
         dispatch_browser_request(conn, :advance, NewYouWeb.OrdinaryPrimaryEmailChangeController)

  defp dispatch(
         %Plug.Conn{method: "POST", request_path: "/primary-email-change/cancel"} = conn,
         _opts
       ),
       do: dispatch_browser_request(conn, :cancel, NewYouWeb.OrdinaryPrimaryEmailChangeController)

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/recovery"} = conn, _opts),
    do: dispatch_browser_request(conn, :new, NewYouWeb.RecoveryController)

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/recovery/confirm"} = conn, _opts),
    do: dispatch_browser_request(conn, :show, NewYouWeb.RecoveryController)

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/recovery"} = conn, _opts),
    do: dispatch_browser_request(conn, :request, NewYouWeb.RecoveryController)

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/recovery/confirm"} = conn, _opts),
    do: dispatch_browser_request(conn, :confirm, NewYouWeb.RecoveryController)

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/recovery/complete"} = conn, _opts),
    do: dispatch_browser_request(conn, :complete, NewYouWeb.RecoveryController)

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/recovery/cancel"} = conn, _opts),
    do: dispatch_browser_request(conn, :cancel, NewYouWeb.RecoveryController)

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/password/reset"} = conn, _opts),
    do: dispatch_browser_request(conn, :new, NewYouWeb.PasswordResetController)

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/password/reset"} = conn, _opts),
    do: dispatch_browser_request(conn, :request, NewYouWeb.PasswordResetController)

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/password/reset/confirm"} = conn, _opts),
    do: dispatch_browser_request(conn, :show, NewYouWeb.PasswordResetController)

  defp dispatch(
         %Plug.Conn{method: "POST", request_path: "/password/reset/confirm"} = conn,
         _opts
       ),
       do: dispatch_browser_request(conn, :confirm, NewYouWeb.PasswordResetController)

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/login"} = conn, _opts),
    do: dispatch_browser_request(conn, :new, PasswordSessionController)

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/login/magic"} = conn, _opts),
    do: dispatch_browser_request(conn, :new, MagicLoginController)

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/login/magic"} = conn, _opts),
    do: dispatch_browser_request(conn, :request, MagicLoginController)

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/login/magic/confirm"} = conn, _opts),
    do: dispatch_browser_request(conn, :show, MagicLoginController)

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/login/magic/confirm"} = conn, _opts),
    do: dispatch_browser_request(conn, :confirm, MagicLoginController)

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/login"} = conn, _opts),
    do: dispatch_browser_request(conn, :create, PasswordSessionController)

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/session/protected"} = conn, _opts),
    do: dispatch_browser_request(conn, :protected, PasswordSessionController)

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/session/manage"} = conn, _opts),
    do: dispatch_browser_request(conn, :show, NewYouWeb.SessionManagementController)

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/session/manage/all"} = conn, _opts),
    do: dispatch_browser_request(conn, :confirm_all, NewYouWeb.SessionManagementController)

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/session/manage/all"} = conn, _opts),
    do: dispatch_browser_request(conn, :revoke_all, NewYouWeb.SessionManagementController)

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/session/manage/revoke"} = conn, _opts),
    do: dispatch_browser_request(conn, :revoke, NewYouWeb.SessionManagementController)

  defp dispatch(%Plug.Conn{method: "POST", request_path: "/session/logout"} = conn, _opts),
    do: dispatch_browser_request(conn, :logout, PasswordSessionController)

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/legal/terms"} = conn, _opts),
    do: dispatch_browser_request(conn, :terms)

  defp dispatch(%Plug.Conn{method: "GET", request_path: "/legal/privacy"} = conn, _opts),
    do: dispatch_browser_request(conn, :privacy)

  if Mix.env() in [:dev, :test] do
    defp dispatch(%Plug.Conn{method: "GET", request_path: path} = conn, _opts)
         when path in ["/dev/design-system", "/dev/design-system/preview"] do
      NewYouWeb.DesignSystemBoundary.render(conn)
    end
  end

  # Every current browser route is dispatched above. A Router fallback would
  # expose session-bearing connections through dispatch or error telemetry.
  defp dispatch(%Plug.Conn{} = conn, _opts), do: fail_closed_response(conn, 404)

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
end
