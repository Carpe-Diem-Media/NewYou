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

  test "browser login requires CSRF and protected access rechecks current Session" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      page = get(build_conn(), "/login?locale=en")
      assert page.status == 200
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

      NewYou.Repo.query!("UPDATE accounts SET security_posture = 'held' WHERE id = $1", [
        Ecto.UUID.dump!(registration.account_id)
      ])

      assert (protected |> recycle() |> get("/session/protected")).status == 401
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
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      submit = fn email ->
        page = get(build_conn(), "/login?locale=en")
        assert page.status == 200
        [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, page.resp_body)

        page
        |> post("/login", %{
          email: email,
          password: "same invalid password for both requests",
          locale: "en",
          _csrf_token: csrf
        })
      end

      known = submit.(request.email)
      unknown_email = "unknown-#{Ecto.UUID.generate()}@example.test"
      unknown = submit.(unknown_email)

      public_result = fn conn, submitted_email ->
        {:ok, canonical_email} = Identity.Email.canonicalize(submitted_email)

        body =
          [submitted_email, canonical_email]
          |> Enum.uniq()
          |> Enum.reduce(conn.resp_body, fn email, body ->
            String.replace(body, email, "[submitted-email]")
          end)

        body =
          Regex.replace(
            ~r/(name="_csrf_token"[^>]*value=")[^"]+/,
            body,
            "\\1[session-token]"
          )

        cookies =
          conn
          |> get_resp_header("set-cookie")
          |> Enum.map(&Regex.replace(~r/(^[^=;]+=)[^;]*/, &1, "\\1[cookie]"))

        {
          conn.status,
          body,
          get_resp_header(conn, "location"),
          get_resp_header(conn, "cache-control"),
          get_resp_header(conn, "referrer-policy"),
          get_resp_header(conn, "content-security-policy"),
          cookies,
          get_session(conn) |> Map.drop(["_csrf_token"])
        }
      end

      assert known.status == 200
      assert unknown.status == 200
      assert public_result.(known, request.email) == public_result.(unknown, unknown_email)
      refute get_session(known, :identity_session_id)
      refute get_session(unknown, :identity_session_id)
    end)
  end

  test "Chromium submits the bilingual form and reconstructs protected access" do
    for locale <- ["en", "af"] do
      P805.with_fixture(fn ->
        request = P805.request()
        {:ok, registration} = Identity.register(request)
        {:ok, :verified} = Identity.verify_email(registration.verification_proof)
        checks = NewYou.Proof.P805Browser.run_login(request, locale)
        assert checks["login_form"] == true
        assert checks["protected_access"] == true
        assert checks["reloaded_access"] == true
      end)
    end
  end

  test "authentication credentials are absent from endpoint telemetry and logs" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
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

        for _ <- 1..4 do
          assert_receive {:p809_telemetry, metadata}
          refute inspect(metadata) =~ request.password
          refute inspect(metadata) =~ token
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
end
