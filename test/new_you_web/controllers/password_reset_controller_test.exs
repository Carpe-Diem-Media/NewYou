defmodule NewYouWeb.PasswordResetControllerTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Plug.Conn
  import ExUnit.CaptureLog
  alias NewYou.Identity
  alias NewYou.Identity.{Account, Token}
  alias NewYou.Proof.P805
  require Ash.Query
  @endpoint NewYouWeb.Endpoint

  setup do
    previous = Application.get_env(:new_you, :p8_12_browser_development_fixtures)
    Application.put_env(:new_you, :p8_12_browser_development_fixtures, true)

    on_exit(fn ->
      if previous == nil,
        do: Application.delete_env(:new_you, :p8_12_browser_development_fixtures),
        else: Application.put_env(:new_you, :p8_12_browser_development_fixtures, previous)
    end)
  end

  test "bilingual request form and neutral results protect CSRF and Account existence" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, _} = Identity.register(request)

      for locale <- ["en", "af"] do
        page = get(build_conn(), "/password/reset?locale=#{locale}")
        assert page.status == 200

        assert get_resp_header(page, "content-security-policy") == [
                 "default-src 'none'; style-src 'self'; font-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"
               ]

        assert page.resp_body =~ "autocomplete=\"email\""

        known =
          post(recycle(page), "/password/reset", %{
            locale: locale,
            email: request.email,
            operation_id: operation()
          })

        unknown =
          post(recycle(page), "/password/reset", %{
            locale: locale,
            email: "unknown@example.test",
            operation_id: operation()
          })

        assert known.status == 200
        assert known.resp_body == unknown.resp_body

        denied =
          build_conn()
          |> put_private(:plug_skip_csrf_protection, false)
          |> post("/password/reset", %{
            locale: locale,
            email: request.email,
            operation_id: operation()
          })

        assert denied.status == 403
      end
    end)
  end

  test "GET HEAD scanner and prefetch preserve all durable Identity state; explicit confirmation never logs in" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
      :ok = Identity.request_password_reset(request.email, "af", operation())

      proof =
        Token
        |> Ash.Query.filter(
          account_id == ^registration.account_id and purpose == "password_reset"
        )
        |> Ash.read_one!(authorize?: false)

      {:ok, {:ok, bearer}} =
        Ash.transact([Account, Token], fn ->
          Identity.password_reset_delivery(proof.jti, request.email, "af")
        end)

      url = "/password/reset/confirm?" <> URI.encode_query(%{proof: bearer, locale: "af"})
      before = snapshot(registration.account_id)

      for {method, headers} <- [
            {:get, []},
            {:head, []},
            {:get, [{"purpose", "prefetch"}]},
            {:get, [{"sec-purpose", "prefetch;prerender"}]},
            {:get, [{"user-agent", "MailScanner/1.0 link-preview"}]}
          ] do
        conn = Enum.reduce(headers, build_conn(), fn {k, v}, c -> put_req_header(c, k, v) end)
        response = dispatch(conn, @endpoint, method, url)
        assert response.status == 200
        assert get_resp_header(response, "cache-control") == ["no-store"]
        assert get_resp_header(response, "referrer-policy") == ["no-referrer"]
        assert snapshot(registration.account_id) == before
      end

      page = get(build_conn(), url)
      csrf = field(page, "_csrf_token")
      operation = field(page, "operation_id")
      P805.track_operation(operation)

      bad =
        build_conn()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/password/reset/confirm", %{
          locale: "af",
          proof: bearer,
          password: "replacement",
          operation_id: operation
        })

      assert bad.status == 403
      assert snapshot(registration.account_id) == before

      response =
        page
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/password/reset/confirm", %{
          locale: "af",
          proof: bearer,
          password: "replacement",
          operation_id: operation,
          _csrf_token: csrf
        })

      assert response.status == 200
      assert get_session(response, :identity_session_id) == nil
      assert get_session(response, :identity_token) == nil
      assert Identity.authorize_session(credentials) == {:error, :authentication_unavailable}
      assert {:ok, _} = Identity.authenticate_password(request.email, "replacement")
    end)
  end

  test "reset requests and result bodies do not leak secrets into endpoint telemetry or logs" do
    parent = self()
    id = "p812-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      id,
      [[:phoenix, :endpoint, :start], [:phoenix, :endpoint, :stop]],
      fn _, _, metadata, _ -> send(parent, {:reset_telemetry, metadata}) end,
      nil
    )

    secret = "never-log-this-reset-password"

    try do
      logs =
        capture_log([level: :debug], fn ->
          response =
            post(build_conn(), "/password/reset/confirm", %{
              locale: "en",
              proof: secret,
              password: secret,
              operation_id: Ecto.UUID.generate()
            })

          assert response.status == 200
        end)

      refute logs =~ secret

      for _ <- 1..2 do
        assert_receive {:reset_telemetry, metadata}
        refute inspect(metadata) =~ secret
      end
    after
      :telemetry.detach(id)
    end
  end

  test "browser flow is unavailable without the explicit development fixture flag" do
    Application.delete_env(:new_you, :p8_12_browser_development_fixtures)
    assert get(build_conn(), "/password/reset?locale=en").status == 404
  end

  test "Chromium submits the bilingual confirmation and requires fresh login" do
    # Focus and responsive checks must use current CSS even in a clean checkout.
    Mix.Task.run("assets.build")
    assert Code.ensure_loaded?(NewYou.Proof.P805Browser)
    assert function_exported?(NewYou.Proof.P805Browser, :run_password_reset, 3)

    for locale <- ["en", "af"] do
      P805.with_fixture(fn ->
        request = P805.request()
        {:ok, registration} = Identity.register(request)
        {:ok, :verified} = Identity.verify_email(registration.verification_proof)
        :ok = Identity.request_password_reset(request.email, locale, operation())

        proof =
          Token
          |> Ash.Query.filter(
            account_id == ^registration.account_id and purpose == "password_reset"
          )
          |> Ash.read_one!(authorize?: false)

        {:ok, {:ok, bearer}} =
          Ash.transact([Account, Token], fn ->
            Identity.password_reset_delivery(proof.jti, request.email, locale)
          end)

        checks =
          NewYou.Proof.P805Browser.run_password_reset(bearer, "browser replacement", locale)

        assert checks["explicit_form"]
        assert checks["reset_complete"]
        assert checks["replay_denied"]
        assert checks["no_session"]
        assert checks["stylesheet_loaded"]
        assert checks["keyboard_focus"]
        assert checks["responsive"]
        assert checks["reduced_motion"]
        assert {:ok, _} = Identity.authenticate_password(request.email, "browser replacement")
      end)
    end
  end

  defp field(page, name) do
    [_, value] = Regex.run(~r/name="#{name}"[^>]*value="([^"]+)"/, page.resp_body)
    value
  end

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  defp snapshot(id) do
    NewYou.Repo.query!("SELECT row_to_json(a)::text FROM accounts a WHERE id = $1", [
      Ecto.UUID.dump!(id)
    ]).rows ++
      NewYou.Repo.query!(
        "SELECT row_to_json(t)::text FROM tokens t WHERE account_id = $1 ORDER BY jti",
        [Ecto.UUID.dump!(id)]
      ).rows ++
      NewYou.Repo.query!(
        "SELECT row_to_json(s)::text FROM sessions s WHERE account_id = $1 ORDER BY id",
        [Ecto.UUID.dump!(id)]
      ).rows
  end
end
