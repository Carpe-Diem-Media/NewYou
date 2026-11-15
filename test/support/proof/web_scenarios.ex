defmodule NewYou.Proof.WebScenarios do
  @moduledoc false
  import ExUnit.Assertions
  import Phoenix.ConnTest
  import Plug.Conn
  require Ash.Query
  alias NewYou.Identity
  alias NewYou.Identity.{Account, Token}
  alias NewYou.Proof.{P805, P813HoldFixture, PassiveEvidence}
  @endpoint NewYouWeb.Endpoint
  def recovery_scanner() do
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

      before = PassiveEvidence.snapshot(registered.account_id)

      for {method, header, value} <- [
            {:get, "user-agent", "participant"},
            {:get, "purpose", "prefetch"},
            {:head, "user-agent", "scanner"},
            {:get, "sec-purpose", "prefetch;preview"}
          ] do
        conn = build_conn() |> put_req_header(header, value) |> dispatch(method, url)
        assert :ok = PassiveEvidence.assert_response!(conn)
        assert :ok = PassiveEvidence.assert_unchanged!(registered.account_id, before)
      end

      assert Ash.get!(Token, recovery.proof_jti, authorize?: false).purpose == "recovery"

      assert Ash.get!(NewYou.Identity.RecoveryCase, recovery.id, authorize?: false).version ==
               recovery.version

      denied =
        build_conn()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/recovery/confirm", %{proof: bearer, operation_id: Ecto.UUID.generate()})

      assert denied.status == 403
      assert :ok = PassiveEvidence.assert_unchanged!(registered.account_id, before)
    end)
  end

  def recovery_neutral() do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registered} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registered.verification_proof)
      unverified = P805.request()
      {:ok, other} = Identity.register(unverified)
      before_account = Ash.get!(Account, other.account_id, authorize?: false)
      before_sessions = PassiveEvidence.snapshot(registered.account_id).sessions
      other_sessions = PassiveEvidence.snapshot(other.account_id).sessions

      responses =
        for {kind, email} <- [
              {:unavailable, request.email},
              {:known, request.email},
              {:unverified, unverified.email},
              {:unknown, "unknown@example.test"},
              {:invalid, "invalid"},
              {:invalid, nil}
            ] do
          id = Ecto.UUID.generate()
          P805.track_operation(id)
          conn = recovery_request(kind, email, id, registered.account_id)

          assert conn.status == 200
          assert get_resp_header(conn, "cache-control") == ["no-store"]
          assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
          refute get_session(conn, :identity_session_id)
          refute get_session(conn, :identity_token)
          assert PassiveEvidence.snapshot(registered.account_id).sessions == before_sessions
          assert PassiveEvidence.snapshot(other.account_id).sessions == other_sessions
          PassiveEvidence.public_response(conn)
        end

      assert length(Enum.uniq(responses)) == 1
      assert Ash.get!(Account, other.account_id, authorize?: false) == before_account
    end)
  end

  defp recovery_request(kind, email, id, account_id) do
    before_owner = PassiveEvidence.snapshot(account_id)

    if kind == :unavailable do
      Process.put(
        NewYou.Proof.RegistrationSeam,
        {:observe,
         fn ->
           Process.put({__MODULE__, :unavailable_observed}, true)
           raise "synthetic recovery source unavailable"
         end}
      )
    end

    conn =
      try do
        post(build_conn(), "/recovery", %{email: email, locale: "af", operation_id: id})
      after
        Process.delete(NewYou.Proof.RegistrationSeam)
      end

    if kind == :unavailable do
      assert Process.delete({__MODULE__, :unavailable_observed}) == true
      assert :ok = PassiveEvidence.assert_unchanged!(account_id, before_owner)
    end

    conn
  end

  def login_neutral() do
    P805.with_fixture(fn -> login_neutral_fixture() end)
  end

  defp login_neutral_fixture() do
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

      {conn.status, body, get_resp_header(conn, "location"),
       get_resp_header(conn, "cache-control"), get_resp_header(conn, "referrer-policy"),
       get_resp_header(conn, "content-security-policy"), cookies,
       get_session(conn) |> Map.drop(["_csrf_token"])}
    end

    assert known.status == 200
    assert unknown.status == 200
    assert public_result.(known, request.email) == public_result.(unknown, unknown_email)
    refute get_session(known, :identity_session_id)
    refute get_session(unknown, :identity_session_id)
  end

  def reset_browser() do
    Mix.Task.run("assets.build")
    assert Code.ensure_loaded?(NewYou.Proof.P805Browser)
    assert function_exported?(NewYou.Proof.P805Browser, :run_password_reset, 3)

    for locale <- ["en", "af"] do
      P805.with_fixture(fn -> reset_browser_fixture(locale) end)
    end
  end

  defp reset_browser_fixture(locale) do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    :ok = Identity.request_password_reset(request.email, locale, operation())

    proof =
      Token
      |> Ash.Query.filter(account_id == ^registration.account_id and purpose == "password_reset")
      |> Ash.read_one!(authorize?: false)

    {:ok, {:ok, bearer}} =
      Ash.transact([Account, Token], fn ->
        Identity.password_reset_delivery(proof.jti, request.email, locale)
      end)

    checks = NewYou.Proof.P805Browser.run_password_reset(bearer, "browser replacement", locale)
    assert checks["explicit_form"]
    assert checks["reset_complete"]
    assert checks["replay_denied"]
    assert checks["no_session"]
    assert checks["stylesheet_loaded"]
    assert checks["keyboard_focus"]
    assert checks["responsive"]
    assert checks["reduced_motion"]
    assert {:ok, _} = Identity.authenticate_password(request.email, "browser replacement")
  end

  def support_lookup() do
    P813HoldFixture.with_fixture(fn fixture ->
      grant =
        P813HoldFixture.grant(
          fixture.actor,
          fixture.target,
          fixture.approver,
          :identity_lookup
        )

      {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :lookup_identity)
      target = Ash.get!(Account, fixture.target.id, authorize?: false)

      assert {:ok, projection} =
               Identity.lookup_support_identity(
                 fixture.actor.credentials,
                 grant.id,
                 target.id,
                 target.email
               )

      assert projection == %{
               account_id: target.id,
               account_status: target.account_status,
               email_verified?: target.email_verified?,
               security_posture: target.security_posture
             }

      refute Map.has_key?(projection, :email)
      refute Map.has_key?(projection, :first_name)
      refute Map.has_key?(projection, :surname)
      refute Map.has_key?(projection, :credential_status)
      refute Map.has_key?(projection, :recovery_case)

      assert {:error, :support_lookup_unavailable} =
               Identity.lookup_support_identity(
                 fixture.actor.credentials,
                 grant.id,
                 fixture.approver.id,
                 target.email
               )

      assert {:ok, :not_found} =
               Identity.lookup_support_identity(
                 fixture.actor.credentials,
                 grant.id,
                 target.id,
                 "different-person@example.test"
               )

      assert {:ok, ^projection} =
               Identity.lookup_support_identity(
                 fixture.actor.credentials,
                 grant.id,
                 target.id,
                 target.email
               )
    end)
  end

  defp dispatch(conn, :get, url) do
    get(conn, url)
  end

  defp dispatch(conn, :head, url) do
    head(conn, url)
  end

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end
end
