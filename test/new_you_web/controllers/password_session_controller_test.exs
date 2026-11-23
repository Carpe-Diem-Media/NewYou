defmodule NewYouWeb.PasswordSessionControllerTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Plug.Conn
  import ExUnit.CaptureLog
  alias NewYou.Identity
  alias NewYou.Proof.P805
  @endpoint NewYouWeb.Endpoint

  setup do
    old = Application.get_env(:new_you, :p8_08_browser_development_fixtures)
    Application.put_env(:new_you, :p8_08_browser_development_fixtures, true)

    on_exit(fn ->
      if old == nil,
        do: Application.delete_env(:new_you, :p8_08_browser_development_fixtures),
        else: Application.put_env(:new_you, :p8_08_browser_development_fixtures, old)
    end)
  end

  test "signed-out sign-in links to ordinary Recovery in the selected locale" do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)

      observer = make_ref()
      parent = self()

      :ok =
        :telemetry.attach(
          observer,
          [:new_you, :repo, :query],
          fn _event, _measurements, metadata, _config ->
            if self() == parent and
                 Regex.match?(~r/\b(?:INSERT|UPDATE|DELETE|TRUNCATE)\b/i, metadata.query) do
              send(parent, {observer, :write})
            end
          end,
          nil
        )

      try do
        for {locale, title} <- [{"en", "Recover your account"}, {"af", "Herstel jou rekening"}] do
          login = get(build_conn(), "/login?locale=#{locale}")
          document = LazyHTML.from_document(html_response(login, 200))
          recovery = LazyHTML.query(document, ~s(a[href="/recovery?locale=#{locale}"]))
          assert String.trim(LazyHTML.text(recovery)) == title

          for path <- ["/password/reset", "/login/magic", "/register"] do
            assert [_] =
                     document
                     |> LazyHTML.query(~s(a[href="#{path}?locale=#{locale}"]))
                     |> LazyHTML.attribute("href")
          end

          [href] = LazyHTML.attribute(recovery, "href")
          request = get(recycle(login), href)
          assert html_response(request, 200) =~ title
          assert request.resp_body =~ ~r/<html[^>]* lang="#{locale}">/
          refute get_session(login, :identity_session_id)
          refute get_session(request, :identity_session_id)
        end

        refute_received {^observer, :write}
        assert get(build_conn(), "/login?locale=af-ZA").status == 404
      after
        :telemetry.detach(observer)
      end
    end)
  end

  test "sign-in hides ordinary Recovery when its copy or development entry is unavailable" do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      Process.put({NewYou.Content.RecoveryBrowserCopy, :evidence_root}, :unavailable)

      refute html_response(get(build_conn(), "/login?locale=af"), 200) =~ "/recovery?"
      assert get(build_conn(), "/recovery?locale=af").status == 503

      Process.delete({NewYou.Content.RecoveryBrowserCopy, :evidence_root})
      Application.put_env(:new_you, :fp001_development_entry, false)
      Application.put_env(:new_you, :p8_15_browser_development_fixtures, false)
      assert get(build_conn(), "/recovery?locale=af").status == 404
      refute html_response(get(build_conn(), "/login?locale=af"), 200) =~ "/recovery?"
    end)
  after
    Process.delete({NewYou.Content.RecoveryBrowserCopy, :evidence_root})
  end

  test "browser login requires CSRF and protected access rechecks current Session" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      page = get(build_conn(), "/login?locale=en")
      assert page.status == 200

      assert get_resp_header(page, "content-security-policy") == [
               "default-src 'none'; style-src 'self'; font-src 'self'; connect-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
             ]

      [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, page.resp_body)

      invalid =
        build_conn()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/login", %{email: request.email, password: request.password, locale: "en"})

      assert invalid.status == 403

      login =
        page
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/login", %{
          email: request.email,
          password: request.password,
          locale: "en",
          _csrf_token: csrf
        })

      assert login.status == 302
      cookie = Enum.join(get_resp_header(login, "set-cookie"), " ")
      assert cookie =~ "HttpOnly"
      assert String.downcase(cookie) =~ "; secure"
      assert cookie =~ "SameSite=Lax"
      refute cookie =~ request.password

      protected = login |> recycle() |> get("/session/protected")
      assert protected.status == 200
      pmr = Ash.get!(Identity.Account, registration.account_id, authorize?: false).pmr
      assert protected.resp_body =~ pmr
      assert get_resp_header(protected, "cache-control") == ["no-store"]

      NewYou.Repo.query!("UPDATE accounts SET security_posture = 'held' WHERE id = $1", [
        Ecto.UUID.dump!(registration.account_id)
      ])

      denied = protected |> recycle() |> get("/session/protected")
      assert denied.status == 401
      refute denied.resp_body =~ pmr
    end)
  end

  test "stale browser cookies cannot bypass Session or token revocation" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      first =
        post(build_conn(), "/login", %{
          email: request.email,
          password: request.password,
          locale: "en"
        })

      second =
        post(build_conn(), "/login", %{
          email: request.email,
          password: request.password,
          locale: "en"
        })

      assert first.status == 302
      assert second.status == 302
      first_id = get_session(first, :identity_session_id)
      second_id = get_session(second, :identity_session_id)

      %{rows: [[jti]]} =
        NewYou.Repo.query!("SELECT token_jti FROM sessions WHERE id = $1", [
          Ecto.UUID.dump!(second_id)
        ])

      NewYou.Repo.query!("UPDATE sessions SET state = 'revoked' WHERE id = $1", [
        Ecto.UUID.dump!(first_id)
      ])

      NewYou.Repo.query!("UPDATE tokens SET purpose = 'revocation' WHERE jti = $1", [jti])
      assert (first |> recycle() |> get("/session/protected")).status == 401
      assert (second |> recycle() |> get("/session/protected")).status == 401
    end)
  end

  test "known wrong-password and unknown-account login failures have the same public response" do
    NewYou.Proof.WebScenarios.login_neutral()
  end

  test "Chromium submits the bilingual form and reconstructs protected access" do
    for locale <- ["en", "af"] do
      P805.with_fixture(fn ->
        request = P805.request()
        {:ok, registration} = Identity.register(request)
        {:ok, :verified} = Identity.verify_email(registration.verification_proof)
        pmr = Ash.get!(Identity.Account, registration.account_id, authorize?: false).pmr
        checks = browser_checks_without_pmr_telemetry(request, locale, pmr)
        assert checks["login_form"] == true
        assert checks["protected_access"] == true
        assert checks["reloaded_access"] == true
        assert checks["member_reference"]
        assert checks["member_reference_keyboard"]
        assert checks["member_reference_announced"]
        assert checks["member_reference_copied"]
        assert checks["member_reference_locale_switch"]
        assert checks["member_reference_reconnect_denied"]
        assert checks["member_reference_reauthenticated"]
      end)
    end
  end

  test "authentication credentials are absent from endpoint telemetry and logs" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      pmr = Ash.get!(Identity.Account, registration.account_id, authorize?: false).pmr
      parent = self()
      handler = "p809-#{System.unique_integer([:positive])}"

      :ok =
        :telemetry.attach_many(
          handler,
          [[:phoenix, :endpoint, :start], [:phoenix, :endpoint, :stop]],
          fn _, _, metadata, _ -> send(parent, {:p809_telemetry, metadata}) end,
          nil
        )

      try do
        logs =
          capture_log([level: :debug], fn ->
            conn =
              post(build_conn(), "/login", %{
                email: request.email,
                password: request.password,
                locale: "en"
              })

            token = get_session(conn, :identity_token)
            send(parent, {:p809_bearer, token})
            conn |> recycle() |> get("/session/protected")
          end)

        assert_receive {:p809_bearer, token}
        refute logs =~ request.password
        refute logs =~ token
        refute logs =~ pmr

        for _ <- 1..4 do
          assert_receive {:p809_telemetry, metadata}
          refute inspect(metadata) =~ request.password
          refute inspect(metadata) =~ token
          refute inspect(metadata) =~ pmr
        end
      after
        :telemetry.detach(handler)
      end
    end)
  end

  test "logout does not report success when durable revocation fails" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      login =
        post(build_conn(), "/login", %{
          email: request.email,
          password: request.password,
          locale: "en"
        })

      {:ok, claims} = AshAuthentication.Jwt.peek(get_session(login, :identity_token))

      NewYou.Repo.query!("UPDATE tokens SET purpose = 'revocation' WHERE jti = $1", [
        claims["jti"]
      ])

      assert (login |> recycle() |> post("/session/logout")).status == 503
    end)
  end

  defp browser_checks_without_pmr_telemetry(request, locale, pmr) do
    owner = self()
    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(
        handler,
        [:bandit, :request, :stop],
        fn _, _, metadata, _ ->
          if metadata.conn.request_path == "/session/protected" and metadata.conn.status == 200 do
            exposed? = :binary.match(:erlang.term_to_binary(metadata), pmr) != :nomatch
            send(owner, {handler, exposed?})
          end
        end,
        nil
      )

    try do
      checks = NewYou.Proof.P805Browser.run_login(request, locale, pmr)
      refute_received {^handler, true}
      assert_received {^handler, false}
      checks
    after
      :telemetry.detach(handler)
    end
  end
end
