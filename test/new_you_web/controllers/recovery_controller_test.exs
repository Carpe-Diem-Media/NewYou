defmodule NewYouWeb.RecoveryControllerTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Plug.Conn
  alias NewYou.Identity
  alias NewYou.Identity.{Account, Token}
  alias NewYou.Proof.P805
  require Ash.Query
  @endpoint NewYouWeb.Endpoint

  setup do
    previous = Application.get_env(:new_you, :p8_15_browser_development_fixtures)
    Application.put_env(:new_you, :p8_15_browser_development_fixtures, true)

    on_exit(fn ->
      if previous == nil,
        do: Application.delete_env(:new_you, :p8_15_browser_development_fixtures),
        else: Application.put_env(:new_you, :p8_15_browser_development_fixtures, previous)
    end)
  end

  test "passive confirmation renders a localized explicit POST form without password consumption" do
    for {locale, action} <- [{"en", "Continue recovery"}, {"af", "Gaan voort met herstel"}] do
      conn = get(build_conn(), "/recovery/confirm?locale=#{locale}&proof=synthetic-placeholder")
      assert conn.status == 200
      assert conn.resp_body =~ "action=\"/recovery/confirm\""
      assert conn.resp_body =~ action
      assert conn.resp_body =~ "name=\"_csrf_token\""
      refute conn.resp_body =~ "name=\"password\""
    end
  end

  test "delivered recovery proof requires explicit browser confirmation before password replacement" do
    P805.with_fixture(fn ->
      request = P805.request(%{preferred_language: :en})
      {:ok, registered} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registered.verification_proof)
      request_id = Ecto.UUID.generate()
      P805.track_operation(request_id)

      assert post(build_conn(), "/recovery", %{
               email: request.email,
               locale: "en",
               operation_id: request_id
             }).status == 200

      intent =
        NewYou.Communications.MessageIntent
        |> Ash.Query.filter(source_operation_id == ^request_id)
        |> Ash.read_one!(authorize?: false)

      Process.put(:p810_provider, fn _, payload ->
        [_, encoded] = Regex.run(~r{/recovery/confirm\?locale=en&proof=([^\s]+)}, payload.body)
        Process.put({__MODULE__, :proof}, URI.decode_www_form(encoded))
        :delivered
      end)

      assert {:ok, :processed} = NewYou.Communications.execute(intent.id)
      proof = Process.delete({__MODULE__, :proof})
      assert is_binary(proof)
      page = get(build_conn(), "/recovery/confirm?locale=en&proof=" <> URI.encode_www_form(proof))
      assert page.status == 200
      assert Ash.get!(Token, intent.source_reference, authorize?: false).purpose == "recovery"
      confirmation = field(page, "operation_id")
      P805.track_operation(confirmation)

      confirmed =
        page
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/recovery/confirm", %{
          proof: proof,
          locale: "en",
          operation_id: confirmation,
          _csrf_token: field(page, "_csrf_token")
        })

      assert confirmed.status == 200
      assert confirmed.resp_body =~ "name=\"password\""

      assert Ash.get!(Token, intent.source_reference, authorize?: false).purpose ==
               "recovery_consumed"

      completion = field(confirmed, "operation_id")
      P805.track_operation(completion)

      conn =
        confirmed
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/recovery/complete", %{
          proof: proof,
          locale: "en",
          password: "browser recovery replacement credential",
          operation_id: completion,
          _csrf_token: field(confirmed, "_csrf_token")
        })

      assert conn.status == 200
      assert conn.resp_body =~ "/login?locale=en"
      assert get_session(conn) == %{}
      assert Ash.get!(Account, registered.account_id, authorize?: false).email_verified?

      assert {:error, :authentication_unavailable} =
               Identity.authenticate_password(request.email, request.password)

      assert {:ok, fresh} =
               Identity.authenticate_password(
                 request.email,
                 "browser recovery replacement credential"
               )

      assert {:ok, _} = Identity.authorize_session(fresh)
    end)
  after
    Process.delete(:p810_provider)
    Process.delete({__MODULE__, :proof})
  end

  test "scanner GET HEAD preview and prefetch cannot consume or advance recovery" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registered} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registered.verification_proof)
      id = Ecto.UUID.generate()
      P805.track_operation(id)
      :ok = Identity.request_recovery(request.email, "af", id)

      recovery =
        NewYou.Identity.RecoveryCase
        |> Ash.Query.filter(account_id == ^registered.account_id)
        |> Ash.read_one!(authorize?: false)

      {:ok, {:ok, bearer}} =
        Ash.transact([Account, Token], fn ->
          Identity.recovery_delivery(recovery.proof_jti, request.email, "af")
        end)

      url = "/recovery/confirm?locale=af&proof=" <> URI.encode_www_form(bearer)

      for {method, header, value} <- [
            {:get, "purpose", "prefetch"},
            {:head, "user-agent", "scanner"},
            {:get, "sec-purpose", "prefetch;preview"}
          ] do
        conn = build_conn() |> put_req_header(header, value) |> dispatch(method, url)
        assert conn.status == 200
        assert get_resp_header(conn, "cache-control") == ["no-store"]
      end

      assert Ash.get!(Token, recovery.proof_jti, authorize?: false).purpose == "recovery"

      assert Ash.get!(NewYou.Identity.RecoveryCase, recovery.id, authorize?: false).version ==
               recovery.version

      denied =
        build_conn()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/recovery/confirm", %{proof: bearer, operation_id: Ecto.UUID.generate()})

      assert denied.status == 403
    end)
  end

  test "recovery proof transport redacts endpoint and router telemetry" do
    parent = self()
    handler = "recovery-telemetry-" <> Ecto.UUID.generate()

    events = [
      [:phoenix, :endpoint, :start],
      [:phoenix, :endpoint, :stop],
      [:phoenix, :router_dispatch, :start]
    ]

    :ok =
      :telemetry.attach_many(
        handler,
        events,
        fn event, _, metadata, _ -> send(parent, {:observed, event, inspect(metadata)}) end,
        nil
      )

    try do
      assert get(build_conn(), "/recovery/confirm?proof=SYNTHETIC-RECOVERY-MARKER").status == 204

      for _ <- 1..2 do
        assert_receive {:observed, _, metadata}
        refute metadata =~ "SYNTHETIC-RECOVERY-MARKER"
      end

      refute_receive {:observed, [:phoenix, :router_dispatch, :start], _}
    after
      :telemetry.detach(handler)
    end
  end

  test "known unknown and malformed public requests share a neutral result" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registered} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registered.verification_proof)

      unverified = P805.request()
      {:ok, other} = Identity.register(unverified)
      before_account = Ash.get!(Account, other.account_id, authorize?: false)

      responses =
        for email <- [request.email, unverified.email, "unknown@example.test", "invalid", nil] do
          id = Ecto.UUID.generate()
          P805.track_operation(id)
          conn = post(build_conn(), "/recovery", %{email: email, locale: "af", operation_id: id})
          assert conn.status == 200
          conn.resp_body
        end

      assert length(Enum.uniq(responses)) == 1

      assert Ash.get!(Account, other.account_id, authorize?: false) == before_account
    end)
  end

  defp dispatch(conn, :get, url), do: get(conn, url)
  defp dispatch(conn, :head, url), do: head(conn, url)

  defp field(page, name) do
    [_, value] = Regex.run(~r/name="#{name}"[^>]*value="([^"]+)"/, page.resp_body)
    value
  end
end
