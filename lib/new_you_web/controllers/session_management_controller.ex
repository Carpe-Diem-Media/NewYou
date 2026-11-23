defmodule NewYouWeb.SessionManagementController do
  @moduledoc "Bounded participant browser access to Identity-owned Session management."
  use NewYouWeb, :controller

  alias NewYou.Content.SessionManagementCopy
  alias NewYou.Identity
  alias NewYouWeb.{DevelopmentEntry, SessionManagementHTML}

  @device_cookie "new_you_device"
  @device_path "/session/manage"
  @consent_salt "trusted-device-consent"
  @consent_seconds 600

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

  @doc false
  def manage_device(conn, %{"operation" => "consent", "device_proof" => proof})
      when is_binary(proof) and byte_size(proof) <= 1024 do
    credentials = credentials(conn)
    presenting = credentials.session_id

    with {:ok, {^presenting, artifact}} <-
           Phoenix.Token.decrypt(conn, @consent_salt, proof, max_age: @consent_seconds),
         {:ok, device} <- Identity.manage_trusted_devices(credentials, {:grant, artifact}) do
      encoded = Base.url_encode64(artifact, padding: false)
      max_age = max(0, DateTime.diff(device.expires_at, DateTime.utc_now()))

      conn
      |> put_resp_cookie(@device_cookie, encoded,
        secure: true,
        http_only: true,
        same_site: "Lax",
        path: @device_path,
        max_age: max_age
      )
      |> assign(:consented_artifact, artifact)
      |> render_list(nil, nil, :ok)
    else
      {:error, :device_result_uncertain} ->
        device_result(conn, "consent.uncertain", :service_unavailable)

      _ ->
        device_result(conn, "consent.failed", :forbidden)
    end
  end

  def manage_device(conn, %{"operation" => "rename", "device_id" => id, "device_name" => name}) do
    case Identity.manage_trusted_devices(credentials(conn), {:rename, id, name}) do
      {:ok, :renamed} ->
        render_list(conn, nil, nil, :ok)

      {:error, :device_result_uncertain} ->
        device_result(conn, "item.name.uncertain", :service_unavailable)

      _ ->
        device_result(conn, "item.name.failed", :unprocessable_entity)
    end
  end

  def manage_device(conn, %{"operation" => "revoke", "device_id" => id}) do
    case Identity.manage_trusted_devices(credentials(conn), {:revoke, id}) do
      {:ok, :revoked} ->
        device_result(conn, "revoke.completed", :ok)

      {:ok, :already_ended} ->
        device_result(conn, "revoke.already_ended", :ok)

      {:error, :device_result_uncertain} ->
        device_result(conn, "revoke.uncertain", :service_unavailable)

      _ ->
        device_result(conn, "revoke.failed", :forbidden)
    end
  end

  def manage_device(conn, _params), do: device_result(conn, "consent.failed", :forbidden)

  defp device_result(conn, message, status) do
    conn
    |> assign(:device_message, message)
    |> render_list(nil, nil, status)
  end

  defp inventory(conn, nil), do: {conn, nil}

  defp inventory(conn, _page) do
    conn = fetch_cookies(conn)
    credentials = credentials(conn)
    artifact = conn.assigns[:consented_artifact] || device_artifact(conn)

    case Identity.manage_trusted_devices(credentials, {:list, artifact}) do
      {:ok, devices} ->
        if Enum.any?(devices, & &1.current?) do
          {conn, %{devices: devices, consent: nil}}
        else
          consent =
            Phoenix.Token.encrypt(
              conn,
              @consent_salt,
              {credentials.session_id, :crypto.strong_rand_bytes(32)}
            )

          {conn, %{devices: devices, consent: consent}}
        end

      _ ->
        {conn, nil}
    end
  end

  defp device_artifact(conn) do
    with <<encoded::binary-size(43)>> <- conn.req_cookies[@device_cookie],
         {:ok, <<artifact::binary-size(32)>>} <- Base.url_decode64(encoded, padding: false) do
      artifact
    else
      _ -> nil
    end
  end

  @doc false
  def confirm_all(conn, _params) do
    case Identity.global_session_revocation_form(credentials(conn)) do
      {:ok, form} ->
        conn
        |> prepare_page(:ok)
        |> render(:confirm_all, form: form)

      {:error, :session_unavailable} ->
        render_page(conn, nil, "active.unavailable", :unauthorized)
    end
  end

  @doc false
  def revoke_all(conn, %{"presenting" => presenting, "password" => password} = params)
      when is_binary(presenting) and is_binary(password) do
    credentials = credentials(conn)

    if credentials.session_id == presenting do
      conn |> global_result(Identity.revoke_all_sessions(credentials, password, params["otp"]))
    else
      render_page(conn, nil, "all.failed", :forbidden)
    end
  end

  def revoke_all(conn, _params), do: render_page(conn, nil, "all.failed", :forbidden)

  defp global_result(conn, {:ok, :revoked}) do
    conn
    |> clear_session()
    |> configure_session(drop: true)
    |> delete_resp_cookie(@device_cookie, path: @device_path, secure: true)
    |> render_page(nil, "all.completed", :ok)
  end

  defp global_result(conn, {:error, :session_result_uncertain}),
    do: render_page(conn, nil, "all.uncertain", :service_unavailable)

  defp global_result(conn, {:error, :session_revocation_failed}),
    do: render_page(conn, nil, "all.failed", :service_unavailable)

  defp global_result(conn, {:error, :session_unavailable}),
    do: render_page(conn, nil, "all.failed", :forbidden)

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

      {:error, :authentication_unavailable} when message == "revoke.uncertain" ->
        render_page(conn, nil, message, status)

      {:error, :authentication_unavailable} ->
        render_page(conn, nil, "active.unavailable", :unauthorized)
    end
  end

  defp render_page(conn, page, message, status) do
    {conn, inventory} = inventory(conn, page)

    conn
    |> prepare_page(status)
    |> render(:index,
      page: page,
      message: message,
      page_number: conn.assigns[:page_number] || 1,
      inventory: inventory,
      device_message: conn.assigns[:device_message]
    )
  end

  defp prepare_page(conn, status) do
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
  end

  defp require_eligible_copy(conn, _) do
    locale = Map.get(conn.params, "locale", get_session(conn, :identity_locale))

    with true <- DevelopmentEntry.enabled?() and NewYouWeb.SignInCopy.available?(),
         {:ok, copy} <- SessionManagementCopy.load(locale),
         {:ok, device_copy} <- SessionManagementCopy.load_devices(locale) do
      conn |> assign(:locale, locale) |> assign(:copy, copy) |> assign(:device_copy, device_copy)
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
