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

  test "ordinary entry renders the exact approved Phase-9 copy with the proof fixture off" do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      Application.put_env(:new_you, :p8_15_browser_development_fixtures, false)

      for locale <- ["en", "af"] do
        packet =
          "docs/delivery/content-evidence/copy/evidence/FP001_RECOVERY_PHASE9_BROWSER_COPY_APPROVED_v0.3.0.json"
          |> File.read!()
          |> Jason.decode!()

        confirmation_body =
          Enum.find(
            packet["candidate"]["copy_items"],
            &(&1["key"] == "identity.recovery.confirmation.body")
          )["locales"][locale]["text"]

        conn = get(build_conn(), "/recovery/confirm?locale=#{locale}")
        assert conn.status == 200
        assert conn.resp_body =~ Plug.HTML.html_escape(confirmation_body)
        assert conn.resp_body =~ ~r/<html[^>]* lang="#{locale}">/
        assert conn.resp_body =~ ~s(name="_csrf_token")
      end
    end)
  end

  test "ordinary copy loss fails closed even when the historical fixture is enabled" do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      assert get(build_conn(), "/recovery?locale=af").status == 200

      Process.put({NewYou.Content.RecoveryBrowserCopy, :evidence_root}, :unavailable)
      assert %{status: 503, resp_body: ""} = get(build_conn(), "/recovery?locale=af")
      assert %{status: 204, resp_body: ""} = get(build_conn(), "/recovery?locale=en-ZA")

      Application.put_env(:new_you, :fp001_development_entry, false)
      assert get(build_conn(), "/recovery?locale=af").status == 200
    end)
  after
    Process.delete({NewYou.Content.RecoveryBrowserCopy, :evidence_root})
  end

  test "ordinary requests establish their own durable proof and completion notice in EN and AF" do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      Application.put_env(:new_you, :p8_15_browser_development_fixtures, false)

      for locale <- ["en", "af"] do
        registration = P805.request(%{preferred_language: String.to_existing_atom(locale)})
        assert {:ok, account} = Identity.register(registration)
        assert {:ok, :verified} = Identity.verify_email(account.verification_proof)

        assert {:ok, prior_session} =
                 Identity.authenticate_password(registration.email, registration.password)

        start = get(build_conn(), "/recovery?locale=#{locale}")
        request_id = field(start, "operation_id")
        P805.track_operation(request_id)

        requested =
          submit(start, "/recovery", %{
            email: registration.email,
            locale: locale,
            operation_id: request_id,
            context: "p8_15"
          })

        unknown =
          submit(start, "/recovery", %{
            email: "unknown-#{request_id}@example.test",
            locale: locale,
            operation_id: Ecto.UUID.generate()
          })

        assert requested.status == 200
        assert requested.resp_body == unknown.resp_body
        refute requested.resp_body =~ registration.email

        intent = recovery_intent(request_id, :account_recovery)
        assert intent.render_schema == "recovery-well183-v1"

        Process.put(:p810_provider, fn _, payload ->
          [_, encoded] =
            Regex.run(~r{/recovery/confirm\?locale=#{locale}&proof=([^\s]+)}, payload.body)

          Process.put({__MODULE__, :proof}, URI.decode_www_form(encoded))
          :delivered
        end)

        assert {:ok, :processed} = NewYou.Communications.execute(intent.id)
        proof = Process.delete({__MODULE__, :proof})
        url = "/recovery/confirm?locale=#{locale}&proof=" <> URI.encode_www_form(proof)
        confirmation = get(build_conn(), url)
        assert head(build_conn(), url).status == 200
        assert Ash.get!(Token, intent.source_reference, authorize?: false).purpose == "recovery"

        confirmation_fields = %{
          proof: proof,
          locale: locale,
          operation_id: field(confirmation, "operation_id")
        }

        csrf_denied =
          confirmation
          |> recycle()
          |> put_private(:plug_skip_csrf_protection, false)
          |> post("/recovery/confirm", confirmation_fields)

        assert csrf_denied.status == 403
        assert Ash.get!(Token, intent.source_reference, authorize?: false).purpose == "recovery"

        other_locale = if locale == "en", do: "af", else: "en"

        wrong_locale =
          submit(confirmation, "/recovery/confirm", %{confirmation_fields | locale: other_locale})

        refute wrong_locale.resp_body =~ ~s(autocomplete="new-password")
        assert Ash.get!(Token, intent.source_reference, authorize?: false).purpose == "recovery"

        assert {:error, :recovery_unavailable} =
                 Identity.submit_recovery_proof(proof, confirmation_fields.operation_id)

        early_completion = Ecto.UUID.generate()
        P805.track_operation(early_completion)

        assert {:error, :recovery_unavailable} =
                 Identity.complete_recovery(
                   proof,
                   "early password",
                   early_completion,
                   locale,
                   :well183
                 )

        assert P805.intents(early_completion) == []

        credential = submit(confirmation, "/recovery/confirm", confirmation_fields)
        assert credential.resp_body =~ ~s(autocomplete="new-password")
        assert {:ok, _} = Identity.authorize_session(prior_session)

        completion_id = field(credential, "operation_id")
        P805.track_operation(completion_id)
        replacement = "ordinary Recovery replacement credential"

        completion_fields = %{
          proof: proof,
          locale: locale,
          operation_id: completion_id,
          password: replacement
        }

        completed = submit(credential, "/recovery/complete", completion_fields)

        assert completed.resp_body =~ "/login?locale=#{locale}"
        assert get_session(completed) == %{}
        assert {:error, _} = Identity.authorize_session(prior_session)
        assert Ash.get!(Account, account.account_id, authorize?: false).credential_version == 2

        notice = recovery_intent(completion_id, :recovery_security_notice)
        assert notice.render_schema == "recovery-notice-well183-v1"
        assert notice.locale == locale

        again = submit(credential, "/recovery/complete", completion_fields)
        assert again.resp_body == completed.resp_body

        changed =
          submit(credential, "/recovery/complete", %{
            completion_fields
            | password: "different retry password"
          })

        refute changed.resp_body =~ "/login?locale=#{locale}"
        assert recovery_intent(completion_id, :recovery_security_notice).id == notice.id

        login = get(recycle(completed), "/login?locale=#{locale}")
        assert login.status == 200

        assert submit(login, "/login", %{
                 email: registration.email,
                 password: registration.password,
                 locale: locale
               }).status == 200

        signed_in =
          submit(login, "/login", %{
            email: registration.email,
            password: replacement,
            locale: locale
          })

        assert redirected_to(signed_in) == "/session/protected"
        assert get(recycle(signed_in), "/session/protected").status == 200
      end
    end)
  after
    Process.delete(:p810_provider)
    Process.delete({__MODULE__, :proof})
  end

  test "ordinary entry leaves a verified Account outside the synthetic email scope untouched" do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      request = P805.request(%{email: "well183-#{Ecto.UUID.generate()}@example.invalid"})
      assert {:ok, registration} = Identity.register(request)
      assert {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      before = Ash.get!(Account, registration.account_id, authorize?: false)
      operation = Ecto.UUID.generate()
      P805.track_operation(operation)

      assert :ok = Identity.request_recovery(request.email, "af", operation, :well183)
      assert P805.intents(operation) == []
      assert Ash.get!(Account, registration.account_id, authorize?: false) == before

      assert :ok = Identity.request_recovery(request.email, "af", operation, :p8_15)
      assert recovery_intent(operation, :account_recovery).render_schema == "recovery-v1"
    end)
  end

  test "a current additional-assurance case holds without opening ordinary completion" do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      Application.put_env(:new_you, :p8_15_browser_development_fixtures, false)
      request = P805.request(%{preferred_language: :af})
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      account = Ash.get!(Account, registration.account_id, authorize?: false)

      Ash.update!(account, %{mfa_enrollment_state: :active},
        action: :update_privileged_mfa,
        authorize?: false
      )

      request_id = Ecto.UUID.generate()
      P805.track_operation(request_id)
      :ok = Identity.request_recovery(request.email, "af", request_id, :well183)
      intent = recovery_intent(request_id, :account_recovery)

      assert {:ok, {:ok, proof}} =
               Ash.transact(Account, fn ->
                 Identity.recovery_delivery(intent.source_reference, request.email, "af")
               end)

      page = get(build_conn(), "/recovery/confirm?locale=af&proof=" <> URI.encode_www_form(proof))
      confirmation_id = field(page, "operation_id")
      P805.track_operation(confirmation_id)

      response =
        submit(page, "/recovery/confirm", %{
          locale: "af",
          proof: proof,
          operation_id: confirmation_id
        })

      refute response.resp_body =~ ~s(autocomplete="new-password")
      refute response.resp_body =~ request.email
      assert {:ok, :held} = Identity.submit_recovery_proof(proof, confirmation_id, "af", :well183)

      token = Ash.get!(Token, intent.source_reference, authorize?: false)
      recovery = Ash.get!(Identity.RecoveryCase, token.recovery_case_id, authorize?: false)
      assert recovery.state == :held_manual_review
      assert recovery.satisfied_assurance == 1
      assert NewYou.Proof.RecoveryScenarios.hold_obligation(request_id).case_id == recovery.id

      completion_id = Ecto.UUID.generate()
      P805.track_operation(completion_id)

      denied =
        submit(page, "/recovery/complete", %{
          locale: "af",
          proof: proof,
          operation_id: completion_id,
          password: "unavailable replacement"
        })

      refute denied.resp_body =~ "/login?locale=af"

      assert Ash.get!(Account, account.id, authorize?: false).credential_version ==
               account.credential_version

      assert P805.intents(completion_id) == []
    end)
  end

  defp recovery_intent(id, role) do
    NewYou.Communications.MessageIntent
    |> Ash.Query.filter(source_operation_id == ^id and role == ^role)
    |> Ash.read_one!(authorize?: false)
  end

  defp submit(page, action, fields) do
    page
    |> recycle()
    |> put_private(:plug_skip_csrf_protection, false)
    |> post(action, Map.put(fields, :_csrf_token, field(page, "_csrf_token")))
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

      [header, payload, _signature] = String.split(proof, ".")
      forged = Enum.join([header, payload, "invalid-signature"], ".")
      forged_page = get(build_conn(), "/recovery/confirm?locale=en&proof=" <> forged)
      assert field(forged_page, "operation_id") == confirmation

      denied =
        forged_page
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/recovery/confirm", %{
          proof: forged,
          locale: "en",
          operation_id: confirmation,
          _csrf_token: field(forged_page, "_csrf_token")
        })

      refute denied.resp_body =~ "name=\"password\""
      assert Ash.get!(Token, intent.source_reference, authorize?: false).purpose == "recovery"

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

      # A fresh browser can reopen the delivered link and explicitly recover the
      # same receipt. The previous page and process are not recovery authority.
      accepted_case =
        Ash.get!(
          NewYou.Identity.RecoveryCase,
          Ash.get!(Token, intent.source_reference, authorize?: false).recovery_case_id,
          authorize?: false
        )

      reopened =
        get(build_conn(), "/recovery/confirm?locale=en&proof=" <> URI.encode_www_form(proof))

      assert field(reopened, "operation_id") == confirmation

      confirmed =
        reopened
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/recovery/confirm", %{
          proof: proof,
          locale: "en",
          operation_id: field(reopened, "operation_id"),
          _csrf_token: field(reopened, "_csrf_token")
        })

      assert confirmed.resp_body =~ "name=\"password\""

      assert Ash.get!(NewYou.Identity.RecoveryCase, accepted_case.id, authorize?: false) ==
               accepted_case

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
    NewYou.Proof.WebScenarios.recovery_scanner()
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
    NewYou.Proof.WebScenarios.recovery_neutral()
  end

  defp field(page, name) do
    [_, value] = Regex.run(~r/name="#{name}"[^>]*value="([^"]+)"/, page.resp_body)
    value
  end
end
