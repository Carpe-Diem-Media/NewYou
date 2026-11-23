defmodule NewYouWeb.SessionManagementControllerTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Plug.Conn

  require Ash.Query

  alias NewYou.{Audit, Identity}
  alias NewYou.Identity.{Account, DeviceAssurance, PasswordSession, Session, Token}
  alias NewYou.Proof.{P805, P805Browser, P813HoldFixture, PrivilegedAccessSeam, SignInJourney}

  @endpoint NewYouWeb.Endpoint

  test "explicit EN/AF device consent uses a private cookie and removal leaves the Session active" do
    P805.with_fixture(fn ->
      input = verified_input()

      for locale <- ["en", "af"] do
        origin = login(input, locale)
        page = get(recycle(origin), "/session/manage")
        body = html_response(page, 200)
        assert body =~ if(locale == "af", do: "Vertroude toestelle", else: "Trusted devices")
        refute Map.has_key?(page.resp_cookies, "new_you_device")

        [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, body)
        [_, proof] = Regex.run(~r/name="device_proof"[^>]*value="([^"]+)"/, body)

        path = "/session/manage/devices"
        params = %{"locale" => locale, "operation" => "consent", "device_proof" => proof}
        assert post(with_csrf(page), path, params).status == 403

        result = post(with_csrf(page), path, Map.put(params, "_csrf_token", csrf))
        updated = html_response(result, 200)

        assert %{secure: true, http_only: true, same_site: "Lax", value: artifact} =
                 result.resp_cookies["new_you_device"]

        refute updated =~ artifact

        [_, target] = Regex.run(~r/name="device_id"[^>]*value="([^"]+)"/, updated)
        [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, updated)

        removed =
          post(with_csrf(result), path, %{
            "locale" => locale,
            "_csrf_token" => csrf,
            "operation" => "revoke",
            "device_id" => target
          })

        assert html_response(removed, 200) =~
                 if(locale == "af",
                   do: "Vertroue vir hierdie toestel is verwyder.",
                   else: "Trust removed from this device."
                 )

        assert get(recycle(removed), "/session/protected").status == 200
      end
    end)
  end

  test "an Audit insertion rejection leaves neither device state nor a cookie" do
    P805.with_fixture(fn ->
      input = verified_input()
      origin = login(input, "en")
      session = session(get_session(origin, :identity_session_id))
      page = get(recycle(origin), "/session/manage")
      body = html_response(page, 200)
      [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, body)
      [_, proof] = Regex.run(~r/name="device_proof"[^>]*value="([^"]+)"/, body)
      path = "/session/manage/devices"

      params = %{
        "locale" => "en",
        "operation" => "consent",
        "device_proof" => proof,
        "_csrf_token" => csrf
      }

      P805.with_rejected_insert("evidence_obligations", fn reached ->
        rejected = post(with_csrf(page), path, params)

        assert html_response(rejected, 503) =~
                 "We couldn&#39;t confirm whether this device was trusted."

        assert reached.()
        refute Map.has_key?(rejected.resp_cookies, "new_you_device")

        assert {:ok, false} =
                 DeviceAssurance
                 |> Ash.Query.filter(account_id == ^session.account_id)
                 |> Ash.exists(authorize?: false)
      end)

      accepted = post(with_csrf(page), path, params)
      assert accepted.status == 200
      assert Map.has_key?(accepted.resp_cookies, "new_you_device")
    end)
  end

  test "global confirmation is read-only and requires a bound CSRF-protected POST in EN and AF" do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      input = P805.request()
      assert {:ok, registration} = Identity.register(input)
      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      for locale <- ["en", "af"] do
        origin = login(input, locale)
        target = login(input, locale)
        origin_id = get_session(origin, :identity_session_id)
        path = "/session/manage/all"
        assert head(recycle(origin), path).status == 200
        page = get(recycle(origin), path)
        body = html_response(page, 200)
        assert body =~ ~s(lang="#{locale}")
        assert body =~ "current-password"
        assert get(recycle(target), "/session/protected").status == 200

        params = %{"locale" => locale, "password" => input.password, "presenting" => origin_id}
        assert post(with_csrf(page), path, params).status == 403
        assert get(recycle(target), "/session/protected").status == 200

        [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, body)
        result = post(with_csrf(page), path, Map.put(params, "_csrf_token", csrf))
        assert_status_copy(result, 200, locale, "all.completed")
        assert get_resp_header(result, "cache-control") == ["no-store"]
        assert get(recycle(result), "/session/protected?locale=#{locale}").status == 401
        assert get(recycle(target), "/session/protected").status == 401

        fresh = login(input, locale)
        fresh_form = get(recycle(fresh), path)

        [_, fresh_csrf] =
          Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, html_response(fresh_form, 200))

        stale = post(with_csrf(fresh_form), path, Map.put(params, "_csrf_token", fresh_csrf))
        assert_status_copy(stale, 403, locale, "all.failed")
        assert get(recycle(fresh), "/session/protected").status == 200
      end
    end)
  end

  test "the browser confirmation requires the real enrolled factor" do
    previous = Application.fetch_env(:new_you, :identity_mfa_keyring)

    Application.put_env(:new_you, :identity_mfa_keyring, %{
      active_version: "test-v1",
      keys: %{"test-v1" => :crypto.strong_rand_bytes(32)}
    })

    try do
      P805.with_fixture(fn ->
        input = verified_input()
        origin = login(input, "af")
        target = login(input, "af")

        credentials = %{
          session_id: get_session(origin, :identity_session_id),
          token: get_session(origin, :identity_token)
        }

        timestamp = 1_800_000_000
        Process.put(PrivilegedAccessSeam, timestamp)

        assert {:ok, %{secret: secret}} =
                 Identity.enroll_privileged_mfa(credentials, input.password)

        confirmation = NimbleTOTP.verification_code(secret, time: timestamp)

        assert {:ok, :ok} =
                 Identity.confirm_privileged_mfa(credentials, input.password, confirmation)

        path = "/session/manage/all"
        page = get(recycle(origin), path)
        body = html_response(page, 200)
        assert body =~ ~s(autocomplete="one-time-code")
        [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, body)

        params = %{
          "locale" => "af",
          "password" => input.password,
          "presenting" => credentials.session_id,
          "_csrf_token" => csrf
        }

        for rejected_params <- [params, Map.put(params, "otp", confirmation)] do
          rejected = post(with_csrf(page), path, rejected_params)
          assert_status_copy(rejected, 403, "af", "all.failed")
        end

        next_timestamp = timestamp + 30
        Process.put(PrivilegedAccessSeam, next_timestamp)
        code = NimbleTOTP.verification_code(secret, time: next_timestamp)
        wrong_code = if code == "000000", do: "000001", else: "000000"
        wrong = post(with_csrf(page), path, Map.put(params, "otp", wrong_code))
        assert_status_copy(wrong, 403, "af", "all.failed")
        assert get(recycle(target), "/session/protected").status == 200

        result = post(with_csrf(page), path, Map.put(params, "otp", code))
        assert_status_copy(result, 200, "af", "all.completed")
        assert get(recycle(target), "/session/protected").status == 401
      end)
    after
      Process.delete(PrivilegedAccessSeam)

      case previous do
        {:ok, value} -> Application.put_env(:new_you, :identity_mfa_keyring, value)
        :error -> Application.delete_env(:new_you, :identity_mfa_keyring)
      end
    end
  end

  test "global POST rejects a newly granted Support account despite an existing form" do
    P813HoldFixture.with_fixture(fn %{target: target, approver: approver} ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      member = P813HoldFixture.factor_member()
      input = %{email: P805.account!(member.id).email, password: member.password}
      origin = login(input, "en")
      origin_id = get_session(origin, :identity_session_id)
      path = "/session/manage/all"
      page = get(recycle(origin), path)
      body = html_response(page, 200)
      assert body =~ ~s(autocomplete="one-time-code")
      [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, body)

      grant = P813HoldFixture.grant(member, target, approver, :security_hold_restriction)
      assert grant.state == :active

      timestamp = 1_800_000_000
      Process.put(PrivilegedAccessSeam, timestamp)

      try do
        result =
          post(with_csrf(page), path, %{
            "locale" => "en",
            "presenting" => origin_id,
            "password" => input.password,
            "otp" => NimbleTOTP.verification_code(member.secret, time: timestamp),
            "_csrf_token" => csrf
          })

        assert_status_copy(result, 403, "en", "all.failed")
        assert_global_session_state([origin_id, member.credentials.session_id], :active, "user")
        assert P805.account!(member.id).mfa_last_accepted_period == nil
        assert selected_evidence(origin_id) == []
      after
        Process.delete(PrivilegedAccessSeam)
      end
    end)
  end

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

  for locale <- ["en", "af"] do
    @locale locale
    @tag timeout: 120_000
    test "Chromium signs out every Session and reconciles with a new sign-in in #{@locale}" do
      P805.with_fixture(fn ->
        input = verified_input()

        result =
          run_browser(input, @locale, SignInJourney.Endpoint, %{global_revocation: true})

        assert_browser_checks(
          result,
          ~w(confirmation cancel focus responsive reduced_motion completed initiator_denied target_denied reconciled)
        )
      end)
    end
  end

  @tag timeout: 120_000
  test "Chromium reconciles an interrupted global sign-out response by signing in again" do
    P805.with_fixture(fn ->
      input = verified_input()

      result =
        run_browser(input, "af", SignInJourney.Endpoint, %{
          global_revocation: true,
          lose_response: true
        })

      assert_browser_checks(result, ~w(response_lost initiator_denied target_denied reconciled))
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
    test "global POST distinguishes rollback from an unconfirmed commit in #{@locale}" do
      P805.with_fixture(fn ->
        input = verified_input()
        origin = login(input, @locale)
        target = login(input, @locale)
        origin_id = get_session(origin, :identity_session_id)
        target_id = get_session(target, :identity_session_id)
        path = "/session/manage/all"
        form = get(recycle(origin), path)

        [_, csrf] =
          Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, html_response(form, 200))

        params = %{
          "locale" => @locale,
          "password" => input.password,
          "presenting" => origin_id,
          "_csrf_token" => csrf
        }

        account_id = session(origin_id).account_id
        reject_revocation(origin_id, account_id)
        prior_evidence = selected_evidence(origin_id)
        assert [%{outcome: :failed}] = prior_evidence

        failed = post(with_csrf(form), path, params)
        assert_status_copy(failed, 503, @locale, "all.failed")
        assert get_resp_header(failed, "cache-control") == ["no-store"]
        assert_global_session_state([origin_id, target_id], :active, "user")
        assert selected_evidence(origin_id) == prior_evidence
        assert get(recycle(origin), "/session/protected").status == 200
        assert get(recycle(target), "/session/protected").status == 200

        # Use a fresh presenting Session so the earlier immutable Audit
        # conflict remains in place while this operation can commit.
        fresh = login(input, @locale)
        fresh_id = get_session(fresh, :identity_session_id)
        fresh_form = get(recycle(fresh), path)

        [_, fresh_csrf] =
          Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, html_response(fresh_form, 200))

        fresh_params = %{params | "presenting" => fresh_id, "_csrf_token" => fresh_csrf}
        assert selected_evidence(fresh_id) == []

        acknowledgement = {PasswordSession, :lose_revocation_acknowledgement}
        Process.put(acknowledgement, true)

        uncertain =
          try do
            post(with_csrf(fresh_form), path, fresh_params)
          after
            Process.delete(acknowledgement)
          end

        assert_status_copy(uncertain, 503, @locale, "all.uncertain")
        assert get_resp_header(uncertain, "cache-control") == ["no-store"]
        assert_global_session_state([origin_id, target_id, fresh_id], :revoked, "revocation")
        assert [%{outcome: :succeeded}] = selected_evidence(fresh_id)
        assert selected_evidence(origin_id) == prior_evidence
        assert get(recycle(fresh), "/session/protected").status == 401
        assert get(recycle(origin), "/session/protected").status == 401
        assert get(recycle(target), "/session/protected").status == 401
      end)
    end

    test "shows approved rollback and uncertain outcomes without reporting success in #{@locale}" do
      P805.with_fixture(fn ->
        input = verified_input()

        actor = login(input, @locale)
        rolled_back = login(input, @locale)
        unconfirmed = login(input, @locale)
        rollback_id = get_session(rolled_back, :identity_session_id)
        unconfirmed_id = get_session(unconfirmed, :identity_session_id)
        account_id = session(rollback_id).account_id

        reject_revocation(rollback_id, account_id)

        path = "/session/manage?locale=#{@locale}"
        page = get(recycle(actor), path)
        original_evidence = selected_evidence(rollback_id)
        assert [%{outcome: :failed}] = original_evidence
        assert selected_evidence(unconfirmed_id) == []
        assert get(recycle(rolled_back), "/session/protected").status == 200
        assert get(recycle(unconfirmed), "/session/protected").status == 200

        failed = revoke(page, rollback_id, @locale)
        assert_status_copy(failed, 503, @locale, "revoke.failed")
        assert %{state: :active, ended_at: nil} = session(rollback_id)
        assert selected_evidence(rollback_id) == original_evidence
        assert get(recycle(rolled_back), "/session/protected").status == 200
        assert html_response(get(recycle(failed), path), 200) =~ ~s(value="#{rollback_id}")

        acknowledgement = {PasswordSession, :lose_revocation_acknowledgement}
        Process.put(acknowledgement, true)

        uncertain =
          try do
            revoke(get(recycle(actor), path), unconfirmed_id, @locale)
          after
            Process.delete(acknowledgement)
          end

        assert_status_copy(uncertain, 503, @locale, "revoke.uncertain")
        assert %{state: :revoked, ended_at: %DateTime{}} = session(unconfirmed_id)
        assert [%{outcome: :succeeded}] = selected_evidence(unconfirmed_id)
        assert get(recycle(unconfirmed), "/session/protected").status == 401
        assert get(recycle(actor), "/session/protected").status == 200
        refreshed = html_response(get(recycle(uncertain), path), 200)
        refute refreshed =~ ~s(value="#{unconfirmed_id}")
        assert refreshed =~ ~s(value="#{rollback_id}")
      end)
    end

    @tag timeout: 120_000
    test "Chromium can consent, name and remove a trusted device in #{@locale}" do
      P805.with_fixture(fn ->
        input = verified_input()
        result = run_browser(input, @locale, SignInJourney.Endpoint, %{trusted_devices: true})

        assert_browser_checks(
          result,
          ~w(empty responsive reduced_motion cookie_private current name_saved explicit_confirm removed refreshed session_survives)
        )
      end)
    end

    @tag timeout: 120_000
    test "two independent Chromium Sessions complete individual revocation in #{@locale}" do
      P805.with_fixture(fn ->
        input = verified_input()
        result = run_browser(input, @locale, SignInJourney.Endpoint)

        assert_browser_checks(
          result,
          ~w(protected_entry locale active_list reduced_motion responsive focus explicit_confirm cancel revoked target_denied initiator_survives)
        )
      end)
    end

    @tag timeout: 120_000
    test "fresh browser navigation reconciles a lost committed revocation in #{@locale}" do
      P805.with_fixture(fn ->
        input = verified_input()
        unrelated = login(input, @locale)
        unrelated_id = get_session(unrelated, :identity_session_id)
        assert get(recycle(unrelated), "/session/protected").status == 200

        owner = self()
        reference = make_ref()

        observe_commit = fn target_id ->
          refute Ash.DataLayer.in_transaction?(Session)
          ended = session(target_id)

          send(
            owner,
            {reference, target_id, ended.state, ended.ended_at, selected_evidence(target_id)}
          )
        end

        result =
          run_browser(input, @locale, {__MODULE__.CommitObservationEndpoint, observe_commit}, %{
            unrelated_session: unrelated_id
          })

        assert_browser_checks(
          result,
          ~w(target_usable_before_submit response_lost refreshed_inventory replay_already_ended target_denied initiator_survives)
        )

        assert_received {^reference, target_id, :revoked, %DateTime{} = ended_at, [evidence]}
        assert_received {^reference, ^target_id, :revoked, ^ended_at, [^evidence]}
        refute_received {^reference, _, _, _, _}
        assert target_id != unrelated_id
        assert %{outcome: :succeeded, source_operation_id: ^target_id} = evidence
        assert DateTime.compare(evidence.source_occurred_at, ended_at) == :eq
        assert %{state: :revoked, ended_at: ^ended_at} = session(target_id)
        assert selected_evidence(target_id) == [evidence]
        assert selected_evidence(unrelated_id) == []
        assert get(recycle(unrelated), "/session/protected").status == 200
      end)
    end
  end

  defmodule CommitObservationEndpoint do
    @moduledoc false
    @behaviour Plug

    def init(opts), do: opts

    def call(conn, observe_commit) do
      conn =
        Plug.Conn.register_before_send(conn, fn
          %{method: "POST", request_path: "/session/manage/revoke", status: 200} = response ->
            observe_commit.(Map.fetch!(response.params, "target"))
            response

          response ->
            response
        end)

      SignInJourney.Endpoint.call(conn, [])
    end
  end

  defp verified_input do
    Application.put_env(:new_you, :fp001_development_entry, true)
    input = P805.request()
    assert {:ok, registration} = Identity.register(input)
    assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    input
  end

  defp run_browser(input, locale, plug, proof \\ %{}) do
    Mix.Task.run("assets.build")
    {:ok, server} = Bandit.start_link(plug: plug, ip: {127, 0, 0, 1}, port: 0)

    try do
      {:ok, {_, port}} = ThousandIsland.listener_info(server)

      payload =
        %{
          mode: "session_management",
          port: port,
          locale: locale,
          email: input.email,
          password: input.password
        }
        |> Map.merge(proof)
        |> Jason.encode!()

      P805Browser.run_port(
        System.find_executable("node"),
        Path.expand("../../proof/p8_05_browser.mjs", __DIR__),
        payload
      )
    after
      Supervisor.stop(server)
    end
  end

  defp assert_browser_checks(result, checks) do
    assert result["cleanup"]

    for check <- checks do
      assert result["checks"][check] == true, "WELL-163 browser check failed: #{check}"
    end
  end

  defp reject_revocation(session_id, account_id) do
    assert {:ok, _} =
             Ash.transact(Account, fn ->
               Audit.establish_identity_security_obligation(%{
                 source_operation_id: session_id,
                 source_occurred_at: ~U[2025-01-01 00:00:00Z],
                 evidence_type: :identity_session_revoked,
                 actor_id: account_id,
                 target_id: account_id,
                 outcome: :failed
               })
             end)
  end

  defp assert_global_session_state(ids, state, purpose) do
    for id <- ids do
      assert %{state: ^state, token_jti: jti} = session(id)
      assert Ash.get!(Token, jti, authorize?: false).purpose == purpose
    end
  end

  defp session(id), do: Ash.get!(Session, id, authorize?: false)

  defp selected_evidence(id) do
    Audit.EvidenceObligation
    |> Ash.Query.filter(source_operation_id == ^id and evidence_type == :identity_session_revoked)
    |> Ash.read!(authorize?: false)
    |> Enum.map(
      &Map.take(&1, [
        :id,
        :source_operation_id,
        :source_occurred_at,
        :actor_id,
        :target_id,
        :outcome
      ])
    )
  end

  defp revoke(page, target, locale) do
    [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, html_response(page, 200))

    post(with_csrf(page), "/session/manage/revoke", %{
      "locale" => locale,
      "target" => target,
      "_csrf_token" => csrf
    })
  end

  defp assert_status_copy(conn, status, locale, key) do
    assert {:ok, copy} = NewYou.Content.SessionManagementCopy.load(locale)
    assert conn.status == status
    body = html_response(conn, status)
    assert body =~ ~s(lang="#{locale}")
    assert [_, rendered] = Regex.run(~r/<p\b[^>]*\brole="status"[^>]*>\s*(.*?)\s*<\/p>/s, body)

    expected =
      copy["identity.sessions.#{key}"]
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()

    assert rendered == expected

    if String.ends_with?(key, [".failed", ".uncertain"]) do
      refute body =~
               Phoenix.HTML.safe_to_string(
                 Phoenix.HTML.html_escape(copy["identity.sessions.all.completed"])
               )

      refute body =~
               Phoenix.HTML.safe_to_string(
                 Phoenix.HTML.html_escape(copy["identity.sessions.revoke.completed"])
               )
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
