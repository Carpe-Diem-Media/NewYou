defmodule NewYouWeb.SignInJourneyTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Plug.Conn

  alias NewYou.Identity
  alias NewYou.Proof.P805
  @endpoint NewYouWeb.Endpoint

  setup do
    flags =
      ~w(fp001_development_entry p8_08_browser_development_fixtures p8_09_browser_development_fixtures)a

    prior = Map.new(flags, &{&1, Application.fetch_env(:new_you, &1)})
    Application.put_env(:new_you, :fp001_development_entry, true)
    Application.put_env(:new_you, :p8_08_browser_development_fixtures, false)
    Application.put_env(:new_you, :p8_09_browser_development_fixtures, false)

    on_exit(fn ->
      Enum.each(prior, fn
        {key, {:ok, value}} -> Application.put_env(:new_you, key, value)
        {key, :error} -> Application.delete_env(:new_you, key)
      end)
    end)

    :ok
  end

  test "ordinary bilingual password sign-in reaches a protected page and durably logs out" do
    for locale <- ~w(en af) do
      P805.with_fixture(fn ->
        Application.put_env(:new_you, :p8_08_browser_development_fixtures, false)
        Application.put_env(:new_you, :p8_09_browser_development_fixtures, false)
        input = P805.request()
        {:ok, registration} = Identity.register(input)
        {:ok, :verified} = Identity.verify_email(registration.verification_proof)

        page = get(build_conn(), "/login?locale=#{locale}")
        assert page.status == 200
        assert page.resp_body =~ ~s(lang="#{locale}")
        assert page.resp_body =~ ~s(/login/magic?locale=#{locale})

        signed_in =
          post(recycle(page), "/login", %{
            "email" => input.email,
            "password" => input.password,
            "locale" => locale
          })

        assert signed_in.status == 302
        protected = get(recycle(signed_in), "/session/protected")
        assert protected.status == 200

        assert protected.resp_body =~
                 if(locale == "af", do: "Jy is aangemeld.", else: "You&#39;re signed in.")

        assert protected.resp_body =~ ~s(action="/session/logout")

        credentials = %{
          session_id: get_session(signed_in, :identity_session_id),
          token: get_session(signed_in, :identity_token)
        }

        result = post(recycle(protected), "/session/logout", %{"locale" => locale})
        assert result.status == 200
        assert result.resp_body =~ ~s(/login?locale=#{locale})
        assert is_nil(get_session(result, :identity_token))
        assert Identity.authorize_session(credentials) == {:error, :authentication_unavailable}
        assert get(recycle(signed_in), "/session/protected").status == 401
      end)
    end
  end

  test "denied access is a usable reauthentication page without a false logout claim" do
    page = get(build_conn(), "/session/protected?locale=af")
    assert page.status == 401
    assert page.resp_body =~ "Meld aan om voort te gaan."
    assert page.resp_body =~ ~s(action="/login")
    refute page.resp_body =~ "Jy is afgemeld."
  end

  test "logout rejects a missing CSRF token and an uncertain result offers safe recovery" do
    P805.with_fixture(fn ->
      input = P805.request()
      {:ok, registration} = Identity.register(input)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      login =
        post(build_conn(), "/login", %{
          "email" => input.email,
          "password" => input.password,
          "locale" => "af"
        })

      id = get_session(login, :identity_session_id)

      forbidden =
        login
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/session/logout", %{"locale" => "af"})

      assert forbidden.status == 403
      assert Ash.get!(Identity.Session, id, authorize?: false).state == :active

      session = Ash.get!(Identity.Session, id, authorize?: false)

      NewYou.Repo.query!("UPDATE tokens SET purpose = 'revocation' WHERE jti = $1", [
        session.token_jti
      ])

      uncertain = post(recycle(login), "/session/logout", %{"locale" => "af"})
      assert uncertain.status == 503
      assert uncertain.resp_body =~ ~s(id="logout-retry")
      assert uncertain.resp_body =~ ~s(/login?locale=af)
      refute uncertain.resp_body =~ "Jy is afgemeld."
      assert Ash.get!(Identity.Session, id, authorize?: false).state == :active

      denied = get(recycle(uncertain), "/session/protected")
      assert denied.status == 401
      assert is_nil(get_session(denied, :identity_session_id))

      recovered =
        post(recycle(denied), "/login", %{
          "email" => input.email,
          "password" => input.password,
          "locale" => "af"
        })

      assert recovered.status == 302
      assert get(recycle(recovered), "/session/protected").status == 200
    end)
  end

  test "idle and absolute expiry deny the copied cookie and retain a terminal Session" do
    P805.with_fixture(fn ->
      input = P805.request()
      {:ok, registration} = Identity.register(input)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      for column <- ~w(idle_expires_at expires_at) do
        login =
          post(build_conn(), "/login", %{
            "email" => input.email,
            "password" => input.password,
            "locale" => "en"
          })

        id = get_session(login, :identity_session_id)

        NewYou.Repo.query!(
          "UPDATE sessions SET #{column} = now() - interval '1 second' WHERE id = $1",
          [Ecto.UUID.dump!(id)]
        )

        assert get(recycle(login), "/session/protected").status == 401
        assert get(recycle(login), "/session/protected").status == 401
        assert Ash.get!(Identity.Session, id, authorize?: false).state == :expired
      end
    end)
  end

  test "ordinary English browser completes password and magic sign-in without proof entry flags" do
    NewYou.Proof.SignInJourney.run("en")
  end

  test "ordinary Afrikaans browser completes password and magic sign-in without proof entry flags" do
    NewYou.Proof.SignInJourney.run("af")
  end
end
