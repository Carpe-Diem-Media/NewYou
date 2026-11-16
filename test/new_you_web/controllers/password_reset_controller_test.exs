defmodule NewYouWeb.PasswordResetControllerTest do
  use ExUnit.Case, async: false
  import NewYou.Proof.ResetScannerCases
  import Phoenix.ConnTest
  import Plug.Conn
  import ExUnit.CaptureLog
  alias NewYou.Identity
  alias NewYou.Proof.P805
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
    NewYou.Proof.ResetScannerCases.scanner()
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
    NewYou.Proof.WebScenarios.reset_browser()
  end
end
