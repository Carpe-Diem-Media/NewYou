defmodule NewYouWeb.PasswordSessionController do
  use NewYouWeb, :controller

  alias NewYou.Identity
  @development_environment Mix.env() in [:dev, :test]
  plug :require_proof_environment

  defp require_proof_environment(conn, _) do
    if :erlang.andalso(
         @development_environment,
         Application.get_env(:new_you, :p8_08_browser_development_fixtures) == true
       ) do
      conn
    else
      conn |> send_resp(404, "") |> halt()
    end
  end

  def new(conn, %{"locale" => locale}) when locale in ["en", "af"] do
    page(conn, locale, false)
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
        |> put_resp_header("cache-control", "no-store")
        |> redirect(to: "/session/protected")

      _ ->
        page(conn, locale, true)
    end
  end

  def create(conn, _), do: send_resp(conn, 404, "")

  def protected(conn, _) do
    conn = put_resp_header(conn, "cache-control", "no-store")

    case Identity.authorize_session(credentials(conn)) do
      {:ok, _} -> send_resp(conn, 200, "")
      _ -> send_resp(conn, 401, "")
    end
  end

  def logout(conn, _) do
    conn = put_resp_header(conn, "cache-control", "no-store")

    case Identity.logout(credentials(conn)) do
      :ok -> conn |> configure_session(drop: true) |> send_resp(204, "")
      _ -> send_resp(conn, 503, "")
    end
  end

  defp credentials(conn),
    do: %{
      session_id: get_session(conn, :identity_session_id),
      token: get_session(conn, :identity_token)
    }

  defp page(conn, locale, failed?) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'self'; font-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
    )
    |> put_root_layout(false)
    |> put_view(html: NewYouWeb.PasswordSessionHTML)
    |> render(:login, locale: locale, failed?: failed?)
  end
end
