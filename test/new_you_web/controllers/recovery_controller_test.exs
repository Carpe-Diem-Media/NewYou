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
        assert conn.status == 204
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

  test "known unknown and malformed public requests share an empty neutral result" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registered} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registered.verification_proof)

      for email <- [request.email, "unknown@example.test", "invalid", nil] do
        id = Ecto.UUID.generate()
        P805.track_operation(id)
        conn = post(build_conn(), "/recovery", %{email: email, locale: "af", operation_id: id})
        assert conn.status == 204
        assert conn.resp_body == ""
      end
    end)
  end

  defp dispatch(conn, :get, url), do: get(conn, url)
  defp dispatch(conn, :head, url), do: head(conn, url)
end
