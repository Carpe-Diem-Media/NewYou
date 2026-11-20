defmodule NewYouWeb.PasswordSessionController do
  use NewYouWeb, :controller

  alias NewYou.Identity
  alias NewYouWeb.{DevelopmentEntry, SignInCopy}
  @development_environment Mix.env() in [:dev, :test]
  plug :require_proof_environment

  defp require_proof_environment(conn, _) do
    if :erlang.andalso(
         @development_environment,
         SignInCopy.available?() and
           (DevelopmentEntry.enabled?() or
              Application.get_env(:new_you, :p8_08_browser_development_fixtures) == true or
              conn.private[:p8_08_browser_development_fixtures] == true)
       ) do
      conn
    else
      conn |> send_resp(404, "") |> halt()
    end
  end

  def new(conn, %{"locale" => locale}) when locale in ["en", "af"] do
    page(conn, locale, nil)
  end

  def new(conn, _), do: send_resp(conn, 404, "")

  def create(conn, %{"locale" => locale, "email" => email, "password" => password})
      when locale in ["en", "af"] do
    case Identity.authenticate_password(email, password) do
      {:ok, %{session_id: id, token: token}} ->
        conn
        |> configure_session(renew: true)
        |> clear_session()
        |> put_session(:identity_session_id, id)
        |> put_session(:identity_token, token)
        |> put_session(:identity_locale, locale)
        |> put_resp_header("cache-control", "no-store")
        |> redirect(to: "/session/protected")

      _ ->
        page(conn, locale, "identity.login.credential_failure")
    end
  end

  def create(conn, _), do: send_resp(conn, 404, "")

  def protected(conn, params) do
    case locale(conn, params) do
      locale when locale in ["en", "af"] ->
        case Identity.authorize_session(credentials(conn)) do
          {:ok, _} ->
            render_page(conn, :protected, locale, %{
              email_change_copy: email_change_copy(locale),
              session_management_title: session_management_title(locale)
            })

          _ ->
            conn
            |> clear_session()
            |> configure_session(drop: true)
            |> put_status(:unauthorized)
            |> page(locale, "identity.session.reauthentication_required")
        end

      _ ->
        send_resp(conn, 404, "")
    end
  end

  def logout(conn, params) do
    locale = locale(conn, params)

    cond do
      locale not in ["en", "af"] ->
        send_resp(conn, 404, "")

      is_nil(get_session(conn, :identity_session_id)) ->
        conn
        |> clear_session()
        |> configure_session(drop: true)
        |> put_status(:unauthorized)
        |> page(locale, "identity.session.reauthentication_required")

      true ->
        case Identity.logout(credentials(conn)) do
          :ok ->
            conn
            |> clear_session()
            |> configure_session(drop: true)
            |> render_page(:logout, locale, %{confirmed?: true})

          _ ->
            conn
            |> put_status(:service_unavailable)
            |> render_page(:logout, locale, %{confirmed?: false})
        end
    end
  end

  defp email_change_copy(locale) do
    with true <- DevelopmentEntry.enabled?(),
         {:ok, copy} <- NewYou.Content.PrimaryEmailChangeBrowserCopy.load(locale) do
      Map.fetch!(copy, "identity.change_email.start.title")
    else
      _ -> nil
    end
  end

  defp session_management_title(locale) do
    with true <- DevelopmentEntry.enabled?(),
         {:ok, copy} <- NewYou.Content.SessionManagementCopy.load(locale) do
      Map.fetch!(copy, "identity.sessions.page.title")
    else
      _ -> nil
    end
  end

  defp locale(conn, params),
    do: Map.get(params, "locale", get_session(conn, :identity_locale) || "en")

  defp credentials(conn),
    do: %{
      session_id: get_session(conn, :identity_session_id),
      token: get_session(conn, :identity_token)
    }

  defp page(conn, locale, error_key),
    do: render_page(conn, :login, locale, %{error_key: error_key})

  defp render_page(conn, template, locale, assigns) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'self'; font-src 'self'; connect-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
    )
    |> put_root_layout(false)
    |> put_view(html: NewYouWeb.PasswordSessionHTML)
    |> render(template, Map.merge(%{locale: locale}, assigns))
  end
end
