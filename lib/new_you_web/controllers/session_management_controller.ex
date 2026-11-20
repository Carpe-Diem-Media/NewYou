defmodule NewYouWeb.SessionManagementController do
  @moduledoc "Bounded participant browser access to Identity-owned Session management."
  use NewYouWeb, :controller

  alias NewYou.Content.SessionManagementCopy
  alias NewYou.Identity
  alias NewYouWeb.{DevelopmentEntry, SessionManagementHTML}

  plug :require_eligible_copy

  @doc false
  def show(conn, params) do
    conn
    |> assign(:page_number, page_number(params["page"]))
    |> render_list(params["after"], nil, :ok)
  end

  @doc false
  def revoke(conn, %{"target" => target}) do
    {message, status} =
      case Identity.revoke_other_session(credentials(conn), target) do
        {:ok, :revoked} -> {"revoke.completed", :ok}
        {:ok, :already_ended} -> {"revoke.already_ended", :ok}
        {:ok, :stale} -> {"revoke.stale", :conflict}
        {:error, :session_revocation_failed} -> {"revoke.failed", :service_unavailable}
        {:error, :session_result_uncertain} -> {"revoke.uncertain", :service_unavailable}
        {:error, :session_unavailable} -> {"revoke.failed", :forbidden}
      end

    render_list(conn, nil, message, status)
  end

  def revoke(conn, _params), do: render_list(conn, nil, "revoke.failed", :forbidden)

  # The number is presentation only; Identity alone bounds and scopes the cursor.
  defp page_number(value) when is_binary(value) and byte_size(value) <= 9 do
    case Integer.parse(value) do
      {number, ""} when number > 0 -> number
      _ -> 1
    end
  end

  defp page_number(_value), do: 1

  defp render_list(conn, cursor, message, status) do
    case Identity.list_active_sessions(credentials(conn), cursor) do
      {:ok, page} ->
        render_page(conn, page, message, status)

      {:error, :authentication_unavailable} ->
        render_page(conn, nil, "active.unavailable", :unauthorized)
    end
  end

  defp render_page(conn, page, message, status) do
    conn
    |> put_status(status)
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; script-src 'self'; style-src 'self'; font-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
    )
    |> put_root_layout(false)
    |> put_view(html: SessionManagementHTML)
    |> render(:index, page: page, message: message, page_number: conn.assigns[:page_number] || 1)
  end

  defp require_eligible_copy(conn, _) do
    locale = Map.get(conn.params, "locale", get_session(conn, :identity_locale))

    with true <- DevelopmentEntry.enabled?() and NewYouWeb.SignInCopy.available?(),
         {:ok, copy} <- SessionManagementCopy.load(locale) do
      conn |> assign(:locale, locale) |> assign(:copy, copy)
    else
      _ -> conn |> put_resp_header("cache-control", "no-store") |> send_resp(404, "") |> halt()
    end
  end

  defp credentials(conn) do
    %{
      session_id: get_session(conn, :identity_session_id),
      token: get_session(conn, :identity_token)
    }
  end
end
