defmodule NewYouWeb.SupportLookupController do
  @moduledoc false
  use NewYouWeb, :controller

  alias NewYou.Identity
  alias NewYouWeb.SupportLookupHTML

  plug :require_development_entry
  plug :require_current_session

  @doc false
  def show(conn, _params), do: page(conn, nil, false)

  @doc false
  def lookup(
        %{
          body_params: %{
            "grant_id" => grant,
            "target_account_id" => target,
            "email" => email,
            "password" => password,
            "code" => code
          }
        } = conn,
        _params
      ) do
    credentials = credentials(conn)

    with {:ok, :ok} <- Identity.step_up_privileged(credentials, password, code, :lookup_identity),
         {:ok, %{account_status: _, email_verified?: _, security_posture: _} = diagnostics} <-
           Identity.lookup_support_identity(credentials, grant, target, email) do
      page(
        conn,
        Map.take(diagnostics, [:account_status, :email_verified?, :security_posture]),
        false
      )
    else
      _ -> unavailable(conn)
    end
  end

  def lookup(conn, _params), do: unavailable(conn)

  defp unavailable(conn), do: conn |> put_status(:forbidden) |> page(nil, true)

  defp require_development_entry(conn, _opts) do
    if NewYouWeb.DevelopmentEntry.enabled?(), do: conn, else: hidden(conn)
  end

  defp require_current_session(conn, _opts) do
    case Identity.authorize_session(credentials(conn)) do
      {:ok, _} -> conn
      _ -> hidden(conn)
    end
  end

  defp hidden(conn), do: conn |> send_resp(404, "") |> halt()

  defp credentials(conn) do
    %{
      session_id: get_session(conn, :identity_session_id),
      token: get_session(conn, :identity_token)
    }
  end

  defp page(conn, diagnostics, unavailable?) do
    conn
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'self'; font-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
    )
    |> put_root_layout(false)
    |> put_view(html: SupportLookupHTML)
    |> render(:index, diagnostics: diagnostics, unavailable?: unavailable?)
  end
end
