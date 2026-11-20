defmodule NewYouWeb.OrdinaryPrimaryEmailChangeTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Plug.Conn

  alias NewYou.{Identity, Repo}
  alias NewYou.Identity.Account
  alias NewYou.Proof.P805

  @endpoint NewYouWeb.Endpoint

  setup do
    settings = %{
      fp001_development_entry: true,
      well156_primary_email_change_proof_policy: %{delay_seconds: 0, requires_review?: false}
    }

    previous = Map.new(settings, fn {key, _} -> {key, Application.fetch_env(:new_you, key)} end)
    Enum.each(settings, fn {key, value} -> Application.put_env(:new_you, key, value) end)

    on_exit(fn ->
      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:new_you, key, value)
        {key, :error} -> Application.delete_env(:new_you, key)
      end)
    end)
  end

  test "ordinary entry requires a current session in either supported language" do
    for locale <- ["en", "af"] do
      response = get(build_conn(), "/primary-email-change?locale=#{locale}")
      body = html_response(response, 401)

      assert body =~ ~s(lang="#{locale}")
      assert body =~ ~s(href="/login?locale=#{locale}")
      refute body =~ ~s(name="target")
    end
  end

  test "both languages reach explicit confirmation and apply with fresh sign-in" do
    for locale <- ["en", "af"] do
      P805.with_fixture(fn ->
        review? = locale == "af"

        Application.put_env(:new_you, :well156_primary_email_change_proof_policy, %{
          delay_seconds: 0,
          requires_review?: review?
        })

        exercise_journey(locale, review?)
      end)
    end
  end

  test "cancelling the current operation leaves the canonical email and rejects stale form identity" do
    P805.with_fixture(fn ->
      input = P805.request()
      {:ok, registration} = Identity.register(input)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      login =
        post(build_conn(), "/login", %{
          "email" => input.email,
          "password" => input.password,
          "locale" => "en"
        })

      entry = get(recycle(login), "/primary-email-change?locale=en")
      id = hidden(entry, "operation_id")
      P805.track_operation(id)
      params = %{"locale" => "en", "operation_id" => id}

      assert submit(
               entry,
               "/primary-email-change",
               Map.put(params, "target", P805.request().email)
             ).status == 303

      requested = get(recycle(entry), "/primary-email-change?locale=en")
      stale = Map.put(params, "operation_id", Ecto.UUID.generate())
      assert submit(requested, "/primary-email-change/cancel", stale).status == 422
      assert submit(requested, "/primary-email-change/cancel", params).status == 303
      assert submit(requested, "/primary-email-change/cancel", params).status == 303

      assert html_response(get(recycle(entry), "/primary-email-change?locale=en"), 200) =~
               "Email change cancelled"

      account = Ash.get!(Account, registration.account_id, authorize?: false)
      assert account.email == input.email
      assert account.primary_email_change_state == :cancelled
    end)
  end

  for locale <- ["en", "af"] do
    @locale locale
    @tag timeout: 120_000
    test "Chromium completes the #{@locale} development journey" do
      NewYou.Proof.Well156Browser.run(@locale)
    end
  end

  defp exercise_journey(locale, review?) do
    input = P805.request()
    target = P805.request().email
    {:ok, registration} = Identity.register(input)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)

    login =
      post(build_conn(), "/login", %{
        "email" => input.email,
        "password" => input.password,
        "locale" => locale
      })

    assert login.status == 302

    credentials = %{
      session_id: get_session(login, :identity_session_id),
      token: get_session(login, :identity_token)
    }

    protected = get(recycle(login), "/session/protected")
    assert protected.resp_body =~ ~s(href="/primary-email-change?locale=#{locale}")
    entry = get(recycle(protected), "/primary-email-change?locale=#{locale}")
    assert html_response(entry, 200) =~ input.email
    id = hidden(entry, "operation_id")
    P805.track_operation(id)

    request = %{"target" => target, "locale" => locale, "operation_id" => id}
    assert submit(entry, "/primary-email-change", request).status == 303
    assert submit(entry, "/primary-email-change", request).status == 303

    assert {:ok, %{state: :requested, email: email, operation_id: ^id}} =
             Identity.primary_email_change_status(credentials)

    assert email == input.email

    requested = get(recycle(entry), "/primary-email-change?locale=#{locale}")
    advance = %{"locale" => locale, "operation_id" => id, "password" => input.password}

    assert submit(requested, "/primary-email-change/advance", %{advance | "password" => "wrong"}).status ==
             422

    assert {:ok, %{state: :requested}} = Identity.primary_email_change_status(credentials)
    assert submit(requested, "/primary-email-change/advance", advance).status == 303

    account = Ash.get!(Account, registration.account_id, authorize?: false)

    {:ok, {:ok, proof}} =
      Repo.transaction(fn ->
        Identity.primary_email_change_delivery(
          account.primary_email_change_token_jti,
          target,
          locale
        )
      end)

    url =
      "/primary-email-change/confirmation?" <> URI.encode_query(%{proof: proof, locale: locale})

    confirmation = get(build_conn(), url)
    assert confirmation.status == 200
    assert head(build_conn(), url).status == 200

    assert {:ok, %{state: :new_address_pending}} =
             Identity.primary_email_change_status(credentials)

    other_locale = if locale == "en", do: "af", else: "en"

    assert Identity.confirm_primary_email_change(proof) ==
             {:error, :primary_email_change_unavailable}

    assert Identity.confirm_phase9_primary_email_change(proof, other_locale) ==
             {:error, :primary_email_change_unavailable}

    confirm = %{"locale" => locale, "proof" => proof}

    assert post(
             recycle(confirmation) |> put_private(:plug_skip_csrf_protection, false),
             "/primary-email-change/confirmation",
             confirm
           ).status == 403

    assert submit(confirmation, "/primary-email-change/confirmation", confirm).status == 200

    assert {:ok, %{state: :delayed, email: ^email}} =
             Identity.primary_email_change_status(credentials)

    assert Identity.confirm_phase9_primary_email_change(proof, locale) ==
             {:error, :primary_email_change_unavailable}

    due = get(recycle(entry), "/primary-email-change?locale=#{locale}")

    due =
      if review? do
        assert submit(due, "/primary-email-change/advance", advance).status == 303

        assert {:ok, %{state: :reviewed, email: ^email}} =
                 Identity.primary_email_change_status(credentials)

        get(recycle(due), "/primary-email-change?locale=#{locale}")
      else
        due
      end

    applied = submit(due, "/primary-email-change/advance", advance)
    assert html_response(applied, 200) =~ ~s(href="/login?locale=#{locale}")
    assert get(recycle(entry), "/primary-email-change?locale=#{locale}").status == 401

    assert %{email: ^target, email_verified?: true, primary_email_change_state: :applied} =
             Ash.get!(Account, registration.account_id, authorize?: false)

    assert {:ok, _} = Identity.authenticate_password(target, input.password)
  end

  defp hidden(conn, name) do
    [_, value] = Regex.run(~r/name="#{name}"[^>]*value="([^"]+)"/, conn.resp_body)
    value
  end

  defp submit(page, path, params) do
    page
    |> recycle()
    |> put_private(:plug_skip_csrf_protection, false)
    |> post(path, Map.put(params, "_csrf_token", hidden(page, "_csrf_token")))
  end
end
