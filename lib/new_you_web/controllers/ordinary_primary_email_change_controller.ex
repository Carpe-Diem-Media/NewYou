defmodule NewYouWeb.OrdinaryPrimaryEmailChangeController do
  use NewYouWeb, :controller

  alias NewYou.Content.{PrimaryEmailChangeBrowserCopy, PrimaryEmailChangeMessage}
  alias NewYou.Identity
  alias NewYouWeb.{DevelopmentEntry, PrimaryEmailChangeHTML, SignInCopy}

  plug :load_copy
  plug :require_message_eligibility when action in [:request, :advance]

  @doc false
  def show(conn, _params), do: with_status(conn, &show_status/3)

  @doc false
  def request(conn, params), do: with_status(conn, &request_change(&1, &2, &3, params))

  @doc false
  def advance(conn, params), do: with_status(conn, &advance_change(&1, &2, &3, params))

  @doc false
  def cancel(conn, params), do: with_status(conn, &cancel_change(&1, &2, &3, params))

  @doc false
  def confirmation(conn, params) do
    proof = params["proof"]

    if confirmation_eligible?(conn.assigns.locale) do
      proof = if is_binary(proof) and byte_size(proof) <= 8192, do: proof, else: ""
      render_confirmation(conn, :confirm, proof)
    else
      render_confirmation(conn, :unavailable, "")
    end
  end

  @doc false
  def confirm(conn, params) do
    case Identity.confirm_phase9_primary_email_change(params["proof"], conn.assigns.locale) do
      {:ok, :confirmed} -> render_confirmation(conn, :confirmed, "")
      _ -> render_confirmation(conn, :unavailable, "")
    end
  end

  defp render_confirmation(conn, state, proof) do
    conn
    |> secure_page()
    |> render(:phase9_confirmation, state: state, proof: proof)
  end

  defp load_copy(conn, _) do
    locale = Map.get(conn.params, "locale", get_session(conn, :identity_locale))

    with true <- DevelopmentEntry.enabled?() and SignInCopy.available?(),
         {:ok, copy} <- PrimaryEmailChangeBrowserCopy.load(locale) do
      conn |> assign(:locale, locale) |> assign(:copy, copy)
    else
      _ -> conn |> put_resp_header("cache-control", "no-store") |> send_resp(404, "") |> halt()
    end
  end

  defp require_message_eligibility(conn, _) do
    if messages_eligible?(conn.assigns.locale) do
      conn
    else
      conn |> put_status(:service_unavailable) |> page(:unavailable) |> halt()
    end
  end

  defp messages_eligible?(locale) do
    confirmation_eligible?(locale) and
      match?(
        {:ok, _},
        PrimaryEmailChangeMessage.binding(:email_change_old_address_notice, locale, :well156)
      )
  end

  defp confirmation_eligible?(locale) do
    match?(
      {:ok, _},
      PrimaryEmailChangeMessage.binding(:email_change_confirmation, locale, :well156)
    )
  end

  defp with_status(conn, callback) do
    credentials = %{
      session_id: get_session(conn, :identity_session_id),
      token: get_session(conn, :identity_token)
    }

    case Identity.primary_email_change_status(credentials) do
      {:ok, status} ->
        callback.(conn, credentials, status)

      _ ->
        conn
        |> put_status(:unauthorized)
        |> page(:signed_out)
    end
  end

  defp show_status(conn, _credentials, status), do: page(conn, :status, status)

  defp request_change(conn, credentials, status, params) do
    operation_id = params["operation_id"]

    case Identity.request_primary_email_change(
           credentials,
           params["target"],
           {conn.assigns.locale, :well156},
           operation_id
         ) do
      {:ok, :requested} -> redirect_to_status(conn)
      _ -> conn |> put_status(:unprocessable_entity) |> page(:status, status, true)
    end
  end

  defp advance_change(conn, credentials, status, params) do
    with true <- current_operation?(status, params),
         true <- advanceable?(status),
         :ok <- step_up(credentials, status, params),
         {:ok, result} <- advance_operation(credentials, status, params["password"]) do
      case result do
        state when state in [:applied, :already_applied] ->
          conn |> clear_session() |> configure_session(drop: true) |> page(:applied)

        _ ->
          redirect_to_status(conn)
      end
    else
      _ -> conn |> put_status(:unprocessable_entity) |> page(:status, status, true)
    end
  end

  defp cancel_change(conn, credentials, status, params) do
    with true <- current_operation?(status, params),
         {:ok, _} <- Identity.cancel_primary_email_change(credentials, status.operation_id) do
      redirect_to_status(conn)
    else
      _ -> conn |> put_status(:unprocessable_entity) |> page(:status, status, true)
    end
  end

  defp current_operation?(status, params) do
    status.content_context == :well156 and is_binary(status.operation_id) and
      status.operation_id == params["operation_id"]
  end

  defp advanceable?(%{state: :requested}), do: true

  defp advanceable?(%{state: state, apply_after: %DateTime{} = at})
       when state in [:delayed, :reviewed],
       do: DateTime.compare(DateTime.utc_now(), at) != :lt

  defp advanceable?(_), do: false

  defp step_up(credentials, %{mfa?: true}, params) do
    case Identity.step_up_privileged(
           credentials,
           params["password"],
           params["code"],
           :change_primary_email
         ) do
      {:ok, :ok} -> :ok
      error -> error
    end
  end

  defp step_up(_, _, _), do: :ok

  defp advance_operation(credentials, %{state: :requested, operation_id: id}, password),
    do: Identity.reauthenticate_primary_email_change(credentials, password, id)

  defp advance_operation(credentials, status, password) do
    with {:ok, :assurance_refreshed} <-
           Identity.reauthenticate_primary_email_change(
             credentials,
             password,
             status.operation_id
           ) do
      finish_confirmed_operation(credentials, status, password)
    end
  end

  defp finish_confirmed_operation(
         credentials,
         %{state: :delayed, requires_review?: true, operation_id: id},
         password
       ),
       do: Identity.review_primary_email_change(credentials, password, id)

  defp finish_confirmed_operation(credentials, %{operation_id: id}, _password),
    do: Identity.apply_authenticated_primary_email_change(credentials, id)

  defp redirect_to_status(conn) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_status(:see_other)
    |> redirect(to: "/primary-email-change?locale=#{conn.assigns.locale}")
  end

  defp page(conn, view, status \\ nil, error? \\ false) do
    active = status && status.content_context == :well156
    state = if active, do: status.state, else: :none
    eligible? = view == :status and messages_eligible?(conn.assigns.locale)

    conn
    |> secure_page()
    |> render(:journey,
      view: view,
      status: status,
      state: state,
      error?: error?,
      can_request?: eligible? and PrimaryEmailChangeHTML.open_request?(state),
      can_advance?: eligible? && active && advanceable?(status),
      operation_id: Ecto.UUID.generate()
    )
  end

  defp secure_page(conn) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'self'; font-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
    )
    |> put_root_layout(false)
    |> put_view(html: PrimaryEmailChangeHTML)
  end
end
