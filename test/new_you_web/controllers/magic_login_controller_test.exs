defmodule NewYouWeb.MagicLoginControllerTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Plug.Conn
  import ExUnit.CaptureLog

  alias NewYou.Identity
  alias NewYou.Proof.P805
  alias NewYou.Identity.Token

  require Ash.Query

  @endpoint NewYouWeb.Endpoint

  setup do
    previous = Application.get_env(:new_you, :p8_09_browser_development_fixtures)
    Application.put_env(:new_you, :p8_09_browser_development_fixtures, true)

    on_exit(fn ->
      if previous == nil,
        do: Application.delete_env(:new_you, :p8_09_browser_development_fixtures),
        else: Application.put_env(:new_you, :p8_09_browser_development_fixtures, previous)
    end)
  end

  test "request form renders in EN and AF with a fresh operation ID and protected headers" do
    for locale <- ["en", "af"] do
      page = get(build_conn(), "/login/magic?locale=#{locale}")

      assert page.status == 200
      assert page.resp_body =~ "name=\"operation_id\""
      assert page.resp_body =~ "name=\"_csrf_token\""
      assert get_resp_header(page, "cache-control") == ["no-store"]
      assert get_resp_header(page, "referrer-policy") == ["no-referrer"]

      assert get_resp_header(page, "content-security-policy") == [
               "default-src 'none'; style-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
             ]

      assert page.resp_body =~ NewYouWeb.MagicLoginCopy.text!("request.title", locale)
    end

    first = get(build_conn(), "/login/magic?locale=en")
    second = get(build_conn(), "/login/magic?locale=en")
    [_, first_id] = Regex.run(~r/name="operation_id"[^>]*value="([^"]+)"/, first.resp_body)
    [_, second_id] = Regex.run(~r/name="operation_id"[^>]*value="([^"]+)"/, second.resp_body)
    assert {:ok, _} = Ecto.UUID.cast(first_id)
    assert {:ok, _} = Ecto.UUID.cast(second_id)
    refute first_id == second_id
  end

  test "request POST requires CSRF and returns the same neutral response for unknown addresses" do
    P805.with_fixture(fn ->
      page = get(build_conn(), "/login/magic?locale=en")
      [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, page.resp_body)

      [_, operation_id] =
        Regex.run(~r/name="operation_id"[^>]*value="([^"]+)"/, page.resp_body)

      P805.track_operation(operation_id)

      missing_csrf =
        build_conn()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/login/magic", %{
          email: "unknown-#{operation_id}@example.test",
          locale: "en",
          operation_id: operation_id
        })

      assert missing_csrf.status == 403

      request =
        page
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/login/magic", %{
          email: "unknown-#{operation_id}@example.test",
          locale: "en",
          operation_id: operation_id,
          _csrf_token: csrf
        })

      assert request.status == 200
      assert request.resp_body =~ NewYouWeb.MagicLoginCopy.text!("request.accepted.title", "en")
      assert request.resp_body =~ NewYouWeb.MagicLoginCopy.text!("request.accepted.body", "en")
      assert :ok = no_identity_session(request)
      assert get_resp_header(request, "cache-control") == ["no-store"]
      assert get_resp_header(request, "referrer-policy") == ["no-referrer"]
    end)
  end

  test "confirmation GET, HEAD, scanner and prefetch requests remain passive" do
    P805.with_fixture(fn ->
      proof = magic_proof("af")
      url = "/login/magic/confirm?" <> URI.encode_query(%{proof: proof, locale: "af"})
      page = get(build_conn(), url)
      [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, page.resp_body)
      before = P805.counts()

      for {method, headers} <- [
            {:get, []},
            {:head, []},
            {:get, [{"purpose", "prefetch"}]},
            {:get, [{"sec-purpose", "prefetch;prerender"}]},
            {:get, [{"user-agent", "MailScanner/1.0 link-preview"}]}
          ] do
        request =
          Enum.reduce(headers, build_conn(), fn {key, value}, conn ->
            put_req_header(conn, key, value)
          end)

        conn = dispatch(request, @endpoint, method, url)
        assert conn.status == 200

        if method == :get do
          assert conn.resp_body =~ NewYouWeb.MagicLoginCopy.text!("confirm.title", "af")
          assert conn.resp_body =~ ~s(value="#{proof}")
        end

        assert before == P805.counts()
        assert get_resp_header(conn, "cache-control") == ["no-store"]
        assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
        assert :ok = no_identity_session(conn)
      end

      confirmation =
        page
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/login/magic/confirm", %{
          proof: proof,
          locale: "af",
          _csrf_token: csrf
        })

      assert confirmation.status == 303
    end)
  end

  test "explicit confirmation consumes the proof, renews the browser session and redirects" do
    P805.with_fixture(fn ->
      request = P805.request(%{preferred_language: :af})
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      request_page = get(build_conn(), "/login/magic?locale=af")
      [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, request_page.resp_body)

      [_, operation_id] =
        Regex.run(~r/name="operation_id"[^>]*value="([^"]+)"/, request_page.resp_body)

      P805.track_operation(operation_id)

      request_response =
        request_page
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/login/magic", %{
          email: request.email,
          locale: "af",
          operation_id: operation_id,
          _csrf_token: csrf
        })

      assert request_response.status == 200

      assert request_response.resp_body =~
               NewYouWeb.MagicLoginCopy.text!("request.accepted.title", "af")

      assert :ok = no_identity_session(request_response)

      unknown_page = get(build_conn(), "/login/magic?locale=af")

      [_, unknown_csrf] =
        Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, unknown_page.resp_body)

      [_, unknown_operation_id] =
        Regex.run(~r/name="operation_id"[^>]*value="([^"]+)"/, unknown_page.resp_body)

      P805.track_operation(unknown_operation_id)

      unknown_response =
        unknown_page
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/login/magic", %{
          email: "unknown-#{unknown_operation_id}@example.test",
          locale: "af",
          operation_id: unknown_operation_id,
          _csrf_token: unknown_csrf
        })

      assert unknown_response.status == request_response.status
      assert unknown_response.resp_body == request_response.resp_body

      token =
        Token
        |> Ash.Query.filter(account_id == ^registration.account_id and purpose == "magic_login")
        |> Ash.read_one!(authorize?: false)

      assert token.magic_request_id == operation_id

      {:ok, {:ok, proof}} =
        Ash.transact([NewYou.Identity.Account, Token], fn ->
          Identity.magic_login_delivery(token.jti, request.email, "af")
        end)

      page =
        get(
          build_conn(),
          "/login/magic/confirm?" <> URI.encode_query(%{proof: proof, locale: "af"})
        )

      [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, page.resp_body)
      assert page.resp_body =~ ~s(value="#{proof}")

      missing_csrf =
        build_conn()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/login/magic/confirm", %{proof: proof, locale: "af"})

      assert missing_csrf.status == 403

      confirmation =
        page
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/login/magic/confirm", %{
          proof: proof,
          locale: "af",
          _csrf_token: csrf
        })

      assert confirmation.status == 303
      assert get_resp_header(confirmation, "location") == ["/"]
      refute confirmation.resp_body =~ proof
      assert is_binary(get_session(confirmation, :identity_session_id))
      assert is_binary(get_session(confirmation, :identity_token))
      account_id = registration.account_id

      assert {:ok, %{account_id: ^account_id}} =
               Identity.authorize_session(%{
                 session_id: get_session(confirmation, :identity_session_id),
                 token: get_session(confirmation, :identity_token)
               })

      cookie = Enum.join(get_resp_header(confirmation, "set-cookie"), " ")
      assert cookie =~ "HttpOnly"
      assert String.downcase(cookie) =~ "; secure"
      assert cookie =~ "SameSite=Lax"
      refute cookie =~ proof
    end)
  end

  test "invalid confirmation is neutral, locale is strict, and disabled fixtures fail closed" do
    invalid_request = get(build_conn(), "/login/magic?locale=zz")
    invalid_confirmation = get(build_conn(), "/login/magic/confirm?locale=zz&proof=x")

    for conn <- [invalid_request, invalid_confirmation] do
      assert conn.status == 404
      assert get_resp_header(conn, "cache-control") == ["no-store"]
      assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]

      assert get_resp_header(conn, "content-security-policy") == [
               "default-src 'none'; style-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
             ]
    end

    invalid =
      post(build_conn(), "/login/magic/confirm", %{proof: "invalid", locale: "en"})

    assert invalid.status == 200
    assert invalid.resp_body =~ NewYouWeb.MagicLoginCopy.text!("confirm.unavailable.title", "en")
    assert :ok = no_identity_session(invalid)

    Application.put_env(:new_you, :p8_09_browser_development_fixtures, false)

    for conn <- [
          get(build_conn(), "/login/magic?locale=en"),
          post(build_conn(), "/login/magic", %{})
        ] do
      assert conn.status == 404
      assert get_resp_header(conn, "cache-control") == ["no-store"]
      assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
    end
  end

  test "proof and session bearers stay out of browser request logs and endpoint telemetry" do
    P805.with_fixture(fn ->
      proof = magic_proof("en")
      parent = self()
      handler = "p809-browser-#{System.unique_integer([:positive])}"

      :ok =
        :telemetry.attach_many(
          handler,
          [[:phoenix, :endpoint, :start], [:phoenix, :endpoint, :stop]],
          fn event, _, metadata, _ -> send(parent, {:magic_telemetry, event, metadata}) end,
          nil
        )

      try do
        logs =
          capture_log([level: :debug], fn ->
            page =
              get(
                build_conn(),
                "/login/magic/confirm?" <> URI.encode_query(%{proof: proof, locale: "en"})
              )

            [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, page.resp_body)

            confirmation =
              page
              |> recycle()
              |> put_private(:plug_skip_csrf_protection, false)
              |> post("/login/magic/confirm", %{
                proof: proof,
                locale: "en",
                _csrf_token: csrf
              })

            send(parent, {:magic_session_bearer, get_session(confirmation, :identity_token)})
          end)

        assert_receive {:magic_session_bearer, session_bearer}
        refute logs =~ proof
        refute logs =~ session_bearer

        for _ <- 1..4 do
          assert_receive {:magic_telemetry, _event, metadata}
          refute inspect(metadata) =~ proof
          refute inspect(metadata) =~ session_bearer
        end
      after
        :telemetry.detach(handler)
      end
    end)
  end

  defp no_identity_session(conn) do
    assert Enum.all?(Map.keys(get_session(conn)), &(&1 == "_csrf_token"))
    :ok
  end

  defp magic_proof(locale) do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    operation_id = Ecto.UUID.generate()
    P805.track_operation(operation_id)
    :ok = Identity.request_magic_login(request.email, locale, operation_id)

    token =
      Token
      |> Ash.Query.filter(account_id == ^registration.account_id and purpose == "magic_login")
      |> Ash.read_one!(authorize?: false)

    {:ok, {:ok, proof}} =
      Ash.transact([NewYou.Identity.Account, Token], fn ->
        Identity.magic_login_delivery(token.jti, request.email, locale)
      end)

    proof
  end
end
