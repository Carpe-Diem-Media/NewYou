defmodule NewYouWeb.PasswordResetController do
  use NewYouWeb, :controller

  alias NewYou.Identity

  @historical_templates %{
    request: :request_p8_12,
    request_result: :request_result_p8_12,
    confirmation: :confirmation_p8_12,
    confirmation_result: :confirmation_result_p8_12
  }

  @development_environment Mix.env() in [:dev, :test]
  @verification_development_fixtures Application.compile_env(
                                       :new_you,
                                       :verification_development_fixtures,
                                       false
                                     )

  plug :require_proof_environment

  def new(conn, %{"locale" => locale}) when locale in ["en", "af"] do
    if email_available?(locale, conn.assigns.password_reset_context),
      do: render_page(conn, :request, locale, %{operation_id: Ecto.UUID.generate()}),
      else: unavailable(conn, locale)
  end

  def new(conn, _params), do: not_found(conn)

  def request(conn, %{"locale" => locale, "email" => email, "operation_id" => operation_id})
      when locale in ["en", "af"] and is_binary(email) and is_binary(operation_id) do
    if email_available?(locale, conn.assigns.password_reset_context) do
      if valid_operation_id?(operation_id),
        do:
          safely_request_password_reset(
            email,
            locale,
            operation_id,
            conn.assigns.password_reset_context
          )

      render_page(conn, :request_result, locale, %{})
    else
      unavailable(conn, locale)
    end
  end

  def request(conn, _params), do: not_found(conn)

  # The GET only carries the proof into an explicit, CSRF-protected form. A
  # scanner, prefetcher or HEAD request cannot consume the Identity capability.
  def show(conn, %{"locale" => locale} = params) when locale in ["en", "af"] do
    proof = Map.get(params, "proof", "")

    render_page(conn, :confirmation, locale, %{
      proof: if(is_binary(proof) and byte_size(proof) <= 8192, do: proof, else: ""),
      operation_id: Ecto.UUID.generate()
    })
  end

  def show(conn, _params), do: not_found(conn)

  def confirm(conn, %{
        "locale" => locale,
        "proof" => proof,
        "password" => password,
        "operation_id" => operation_id
      })
      when locale in ["en", "af"] do
    # This check only rejects a mismatched presentation locale. Identity alone
    # verifies the signature, current proof, Account and durable outcome.
    outcome =
      if proof_locale?(proof, locale),
        do: Identity.reset_password(proof, password, operation_id),
        else: {:error, :reset_unavailable}

    if match?({:ok, result} when result in [:reset, :already_reset], outcome) do
      conn
      |> configure_session(renew: true)
      |> clear_session()
      |> render_page(:confirmation_result, locale, %{completed?: true, uncertain?: false})
    else
      render_page(conn, :confirmation_result, locale, %{
        completed?: false,
        uncertain?: outcome != {:error, :reset_unavailable}
      })
    end
  end

  def confirm(conn, %{"locale" => locale}) when locale in ["en", "af"],
    do: render_page(conn, :confirmation_result, locale, %{completed?: false, uncertain?: false})

  def confirm(conn, _params), do: not_found(conn)

  defp require_proof_environment(conn, _opts) do
    context = entry_context()

    if :erlang.andalso(
         @development_environment,
         :erlang.andalso(
           @verification_development_fixtures == true,
           context in [:p8_12, :well136]
         )
       ) do
      assign(conn, :password_reset_context, context)
    else
      conn |> not_found() |> halt()
    end
  end

  # Ordinary entry takes precedence. Its missing eligibility must never turn
  # an ordinary request into a historical P8-12 consumption.
  defp entry_context do
    if Application.get_env(:new_you, :fp001_development_entry) == true do
      if NewYouWeb.DevelopmentEntry.enabled?() and
           NewYou.Content.PasswordResetBrowserCopy.available?(),
         do: :well136
    else
      if Application.get_env(:new_you, :p8_12_browser_development_fixtures) == true,
        do: :p8_12
    end
  end

  defp valid_operation_id?(operation_id), do: match?({:ok, _}, Ecto.UUID.cast(operation_id))

  defp email_available?(locale, :p8_12),
    do: match?({:ok, _}, NewYou.Content.PasswordResetMessage.binding(locale))

  defp email_available?(locale, :well136),
    do: match?({:ok, _}, NewYou.Content.PasswordResetMessage.binding(locale, :well136))

  defp unavailable(conn, locale),
    do: conn |> put_status(:service_unavailable) |> render_page(:service_unavailable, locale, %{})

  defp proof_locale?(proof, locale) when is_binary(proof) and byte_size(proof) <= 8192 do
    match?({:ok, %{"locale" => ^locale}}, Joken.peek_claims(proof))
  end

  defp proof_locale?(_, _), do: false

  defp safely_request_password_reset(email, locale, operation_id, context) do
    Identity.request_password_reset(email, locale, operation_id, context)
  rescue
    _ -> :unavailable
  catch
    _, _ -> :unavailable
  end

  defp render_page(conn, template, locale, assigns) do
    context = conn.assigns.password_reset_context

    if context == :p8_12 and
         (template == :service_unavailable or Map.get(assigns, :uncertain?, false)) do
      # No approved historical copy describes an ambiguous result or unavailable
      # service. Return a status without borrowing WELL-136-only wording or
      # presenting an unconfirmed outcome as a confirmed failure.
      conn |> security_headers() |> send_resp(503, "")
    else
      render_context_page(conn, template, locale, assigns, context)
    end
  end

  defp render_context_page(conn, template, locale, assigns, context) do
    assigns = if template == :confirmation_result, do: result_copy(assigns), else: assigns

    template =
      if context == :p8_12, do: Map.fetch!(@historical_templates, template), else: template

    conn
    |> security_headers()
    |> put_root_layout(false)
    |> put_view(html: NewYouWeb.PasswordResetHTML)
    |> render(template, Map.merge(%{locale: locale}, assigns))
  rescue
    NewYou.Content.PasswordResetBrowserCopy.UnavailableError ->
      # Content can disappear after admission or an Identity commit. This is a
      # presentation outage, never evidence that issuance/reset failed or
      # succeeded. Send no withdrawn wording, retain the durable owner outcome
      # and let an unchanged operation recover its receipt when copy is eligible.
      # Rendering is buffered, so no partial approved/unapproved body was sent.
      conn |> security_headers() |> send_resp(503, "")
  end

  defp result_copy(%{completed?: completed?, uncertain?: uncertain?} = assigns) do
    prefix =
      cond do
        completed? -> "identity.password_reset.confirm.complete"
        uncertain? -> "identity.password_reset.uncertain"
        true -> "identity.password_reset.confirm.unavailable"
      end

    Map.merge(assigns, %{result_title: prefix <> ".title", result_body: prefix <> ".body"})
  end

  defp security_headers(conn) do
    # Only the ordinary form loads the pending-state script. Keep historical
    # P8-12's existing transport policy independent of the ordinary journey.
    csp =
      if conn.assigns[:password_reset_context] == :well136 do
        "default-src 'none'; style-src 'self'; font-src 'self'; script-src 'self'; connect-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
      else
        "default-src 'none'; style-src 'self'; font-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
      end

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header("content-security-policy", csp)
  end

  defp not_found(conn), do: conn |> security_headers() |> send_resp(404, "")
end
