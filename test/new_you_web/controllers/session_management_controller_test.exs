defmodule NewYouWeb.SessionManagementControllerTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Plug.Conn

  alias NewYou.Identity
  alias NewYou.Proof.{P805, P805Browser, SignInJourney}

  @endpoint NewYouWeb.Endpoint

  test "both locales link to a current Session list and require explicit CSRF-protected revocation" do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      input = P805.request()
      assert {:ok, registration} = Identity.register(input)
      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      for locale <- ["en", "af"] do
        origin = login(input, locale)
        target = login(input, locale)
        target_id = get_session(target, :identity_session_id)

        protected = get(recycle(origin), "/session/protected")
        path = "/session/manage?locale=#{locale}"
        assert html_response(protected, 200) =~ ~s(href="#{path}")

        page = get(recycle(protected), path)
        body = html_response(page, 200)
        assert body =~ ~s(lang="#{locale}")
        assert body =~ ~s(value="#{target_id}")

        assert get(recycle(page), "/session/manage/revoke").status == 404
        assert get(recycle(target), "/session/protected").status == 200

        params = %{"locale" => locale, "target" => target_id}
        assert post(with_csrf(page), "/session/manage/revoke", params).status == 403
        assert get(recycle(target), "/session/protected").status == 200

        [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, body)

        assert post(
                 with_csrf(page),
                 "/session/manage/revoke",
                 Map.put(params, "_csrf_token", csrf)
               ).status ==
                 200

        assert get(recycle(target), "/session/protected").status == 401
        assert get(recycle(origin), "/session/protected").status == 200
        assert post(with_csrf(origin), "/session/logout", %{"locale" => locale}).status == 403
      end
    end)
  end

  test "foreign and missing targets receive indistinguishable denial with a valid CSRF token" do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      input = P805.request()
      foreign = P805.request()

      for request <- [input, foreign] do
        assert {:ok, registration} = Identity.register(request)
        assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      end

      actor = login(input, "en")
      other_account = login(foreign, "en")
      foreign_id = get_session(other_account, :identity_session_id)
      page = get(recycle(actor), "/session/manage?locale=en")

      for id <- [foreign_id, Ecto.UUID.generate()] do
        # Seed a valid CSRF form using the normal protected page, even when
        # the actor has no other Session that could render a revoke form.
        protected = get(recycle(page), "/session/protected")

        [_, token] =
          Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, protected.resp_body)

        result =
          post(with_csrf(protected), "/session/manage/revoke", %{
            "locale" => "en",
            "target" => id,
            "_csrf_token" => token
          })

        assert html_response(result, 403) =~ "Refresh the list and try again."
        refute result.resp_body =~ id
      end

      assert get(recycle(other_account), "/session/protected").status == 200
    end)
  end

  for locale <- ["en", "af"] do
    @locale locale
    @tag timeout: 120_000
    test "two independent Chromium Sessions complete individual revocation in #{@locale}" do
      Mix.Task.run("assets.build")

      P805.with_fixture(fn ->
        Application.put_env(:new_you, :fp001_development_entry, true)
        input = P805.request()
        assert {:ok, registration} = Identity.register(input)
        assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)

        {:ok, server} =
          Bandit.start_link(plug: SignInJourney.Endpoint, ip: {127, 0, 0, 1}, port: 0)

        try do
          {:ok, {_, port}} = ThousandIsland.listener_info(server)

          payload =
            Jason.encode!(%{
              mode: "session_management",
              port: port,
              locale: @locale,
              email: input.email,
              password: input.password
            })

          result =
            P805Browser.run_port(
              System.find_executable("node"),
              Path.expand("../../proof/p8_05_browser.mjs", __DIR__),
              payload
            )

          assert result["cleanup"]

          for check <-
                ~w(protected_entry locale active_list reduced_motion responsive focus explicit_confirm cancel revoked target_denied initiator_survives) do
            assert result["checks"][check] == true, "WELL-163 browser check failed: #{check}"
          end
        after
          Supervisor.stop(server)
        end
      end)
    end
  end

  defp with_csrf(conn), do: conn |> recycle() |> put_private(:plug_skip_csrf_protection, false)

  defp login(input, locale) do
    page = get(build_conn(), "/login?locale=#{locale}")
    [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, html_response(page, 200))

    post(with_csrf(page), "/login", %{
      "email" => input.email,
      "password" => input.password,
      "locale" => locale,
      "_csrf_token" => csrf
    })
  end
end
