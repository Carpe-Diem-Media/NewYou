defmodule NewYouWeb.RegistrationController do
  use NewYouWeb, :controller

  alias NewYou.Identity
  alias NewYou.Identity.RegistrationResult

  @locales ~w(en af)
  @development_environment Mix.env() in [:dev, :test]

  plug :put_entry_headers

  defp put_entry_headers(conn, _opts) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
  end

  def new(conn, %{"locale" => locale}) when locale in @locales do
    if development_browser_enabled?() do
      render_registration(conn, locale, %{}, %{}, nil)
    else
      not_found(conn)
    end
  end

  def new(conn, %{"locale" => _unsupported}) do
    not_found(conn)
  end

  def new(conn, _params) do
    if development_browser_enabled?() do
      render_registration(conn, "en", %{}, %{}, nil)
    else
      not_found(conn)
    end
  end

  def create(conn, %{"registration" => params}) when is_map(params) do
    if development_browser_enabled?() do
      case Map.get(params, "preferred_language") do
        locale when locale in @locales -> create_registration(conn, params, locale)
        _unsupported -> not_found(conn)
      end
    else
      not_found(conn)
    end
  end

  def create(conn, _params), do: not_found(conn)

  def resend(conn, %{"resend" => params}) when is_map(params) do
    if development_browser_enabled?() do
      case Map.get(params, "preferred_language") do
        locale when locale in @locales -> resend_verification(conn, params, locale)
        _unsupported -> not_found(conn)
      end
    else
      not_found(conn)
    end
  end

  def resend(conn, _params), do: not_found(conn)

  def terms(conn, _params), do: send_legal_baseline(conn, :terms)
  def privacy(conn, _params), do: send_legal_baseline(conn, :privacy)

  @doc false
  defdelegate legal_baseline_valid?(baseline, entry, body), to: NewYou.Content.Registration

  defp create_registration(conn, params, locale) do
    errors = registration_errors(params)

    if map_size(errors) > 0 do
      render_registration(conn, locale, safe_form_values(params), errors, nil)
    else
      case Identity.register(registration_request(params, locale)) do
        {:ok, %RegistrationResult{status: :verification_pending}} ->
          render_pending(
            conn,
            locale,
            Map.fetch!(params, "email"),
            "identity.registration.accepted_neutral",
            nil
          )

        _ ->
          render_registration(
            conn,
            locale,
            safe_form_values(params),
            %{},
            "identity.registration.failure"
          )
      end
    end
  end

  defp resend_verification(conn, params, locale) do
    request = %{
      operation_id: Map.get(params, "operation_id"),
      email: Map.get(params, "email")
    }

    case Identity.resend_verification_by_email(request) do
      {:ok, :verification_pending} ->
        render_pending(
          conn,
          locale,
          Map.get(params, "email", ""),
          nil,
          "identity.verification.resend.accepted_neutral"
        )

      _ ->
        render_pending(
          conn,
          locale,
          Map.get(params, "email", ""),
          nil,
          "identity.verification.resend.failure"
        )
    end
  end

  defp registration_request(params, locale) do
    {:ok, legal_versions} = NewYou.Content.Registration.legal_versions()

    %{
      operation_id: Map.get(params, "operation_id"),
      first_name: Map.get(params, "first_name"),
      surname: Map.get(params, "surname"),
      email: Map.get(params, "email"),
      password: Map.get(params, "password"),
      preferred_language: locale,
      confirmed_age_18?: Map.get(params, "confirmed_age_18") == "true",
      terms_version_id: legal_versions.terms_version_id,
      privacy_version_id: legal_versions.privacy_version_id
    }
  end

  defp registration_errors(params) do
    %{}
    |> require_value(params, "first_name", "identity.registration.first_name.required")
    |> require_value(params, "surname", "identity.registration.surname.required")
    |> require_value(params, "email", "identity.registration.email.required")
    |> require_password(params)
    |> require_checked(params, "confirmed_age_18", "identity.registration.age.required")
    |> require_checked(params, "terms_accepted", "identity.registration.terms.required")
    |> require_checked(
      params,
      "privacy_accepted",
      "identity.registration.privacy_acceptance.required"
    )
  end

  defp require_value(errors, params, field, copy_key) do
    value = Map.get(params, field)

    if is_binary(value) and String.trim(value) != "" do
      errors
    else
      Map.put(errors, field, copy_key)
    end
  end

  defp require_password(errors, params) do
    case Map.get(params, "password") do
      value when is_binary(value) and byte_size(value) > 0 -> errors
      _ -> Map.put(errors, "password", "identity.registration.password.required")
    end
  end

  defp require_checked(errors, params, field, copy_key) do
    if Map.get(params, field) == "true" do
      errors
    else
      Map.put(errors, field, copy_key)
    end
  end

  defp safe_form_values(params) do
    Map.take(params, [
      "first_name",
      "surname",
      "email",
      "preferred_language",
      "confirmed_age_18",
      "terms_accepted",
      "privacy_accepted"
    ])
  end

  defp render_registration(conn, locale, values, errors, global_error) do
    copy = &NewYouWeb.RegistrationHTML.copy(&1, locale)

    conn
    |> assign(:locale, locale)
    |> assign(:page_language, locale)
    |> assign(:page_title, copy.("identity.registration.title"))
    |> assign(:page_description, copy.("identity.registration.intro"))
    |> assign(:operation_id, Ecto.UUID.generate())
    |> assign(:form, Phoenix.Component.to_form(values, as: :registration))
    |> assign(:values, values)
    |> assign(:errors, errors)
    |> assign(:global_error, global_error)
    |> render(:new)
  end

  defp render_pending(conn, locale, email, registration_notice, resend_notice) do
    copy = &NewYouWeb.RegistrationHTML.copy(&1, locale)

    conn
    |> assign(:locale, locale)
    |> assign(:page_language, locale)
    |> assign(:page_title, copy.("identity.verification.pending.title"))
    |> assign(:page_description, copy.("identity.verification.pending.explanation"))
    |> assign(:email, email)
    |> assign(:registration_notice, registration_notice)
    |> assign(:resend_notice, resend_notice)
    |> assign(:resend_operation_id, Ecto.UUID.generate())
    |> assign(:resend_form, Phoenix.Component.to_form(%{}, as: :resend))
    |> render(:pending)
  end

  defp send_legal_baseline(conn, baseline) do
    if development_browser_enabled?() do
      case NewYou.Content.Registration.legal_document(baseline) do
        {:ok, body} ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "text/html; charset=utf-8")
          |> Plug.Conn.put_resp_header("cache-control", "no-store")
          |> Plug.Conn.resp(200, body)

        {:error, :content_ineligible} ->
          not_found(conn)
      end
    else
      not_found(conn)
    end
  end

  defp development_browser_enabled? do
    :erlang.andalso(
      @development_environment,
      (NewYouWeb.DevelopmentEntry.enabled?() or
         Application.get_env(:new_you, :p8_05_browser_development_fixtures, false) == true) and
        NewYou.Content.EntryCopy.available?() and
        match?({:ok, _}, NewYou.Content.Registration.legal_versions())
    )
  end

  defp not_found(conn), do: send_resp(conn, 404, "")
end
