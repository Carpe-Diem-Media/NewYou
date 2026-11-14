defmodule NewYouWeb.RegistrationControllerTest do
  use NewYouWeb.ConnCase
  import ExUnit.CaptureLog

  alias NewYou.Identity
  alias NewYouWeb.CopyRegistry
  alias NewYouWeb.RegistrationController

  require Ash.Query

  @copy_registry_path Path.expand(
                        "../../../docs/delivery/content-evidence/copy/COPY_REGISTRY.json",
                        __DIR__
                      )
  @design_tokens_path Path.expand("../../../assets/css/tokens.css", __DIR__)
  @copy_registry @copy_registry_path |> File.read!() |> Jason.decode!()
  @terms_path Path.expand(
                "../../../docs/delivery/content-evidence/content_media/legal_baselines/NEWYOU-TERMS-EN-DEV-BASELINE-2026-10-27-001.html",
                __DIR__
              )
  @privacy_path Path.expand(
                  "../../../docs/delivery/content-evidence/content_media/legal_baselines/NEWYOU-PRIVACY-EN-DEV-BASELINE-2026-10-27-001.html",
                  __DIR__
                )
  @registration_copy_keys ~w(
    public.entry.launch.title
    public.entry.launch.body
    public.entry.safety.body
    shared.language.afrikaans
    shared.language.english
    shared.language.change
    identity.registration.title
    identity.registration.intro
    identity.registration.first_name.label
    identity.registration.surname.label
    identity.registration.email.label
    identity.registration.password.label
    identity.registration.preferred_language.label
    identity.registration.preferred_language.help
    identity.registration.age_confirmation
    legal.shared.document_language_disclosure
    identity.registration.terms_acceptance
    identity.registration.terms_link
    identity.registration.privacy_presentation
    identity.registration.privacy_link
    identity.registration.privacy_acceptance
    identity.registration.submit
  )
  @pending_copy_keys ~w(
    identity.verification.pending.title
    identity.verification.pending.explanation
    identity.verification.pending.check_inbox
    identity.verification.pending.address_label
    identity.verification.pending.not_arrived.title
    identity.verification.pending.not_arrived.body
    identity.verification.resend.action
    identity.verification.pending.access_limitation
    identity.verification.pending.browse_public
    identity.verification.pending.home
  )
  @development_terms_id "NEWYOU-TERMS-EN-DEV-2026-10-27-001"
  @development_privacy_id "NEWYOU-PRIVACY-EN-DEV-2026-10-27-001"
  @pinned_copy_source_hashes %{
    "docs/delivery/content-evidence/copy/COPY_REGISTRY.json" =>
      "744f1a34ad80c0158c86395f3f66227622714969526f5e9d69ee62314fd48635",
    "docs/delivery/content-evidence/copy/pages/public/registration.yaml" =>
      "09ea540487523e9ac236fef4c706378540ea4b07fef7ca5a5b745624d41a8dd8",
    "docs/delivery/content-evidence/copy/pages/public/verification-pending.yaml" =>
      "6d433ead78a86cf58510f4a028b1a94b40d3e631a5e8fc3feb221eb0806c679b",
    "docs/delivery/content-evidence/copy/journeys/registration/P8_05_REGISTRATION_COPY.md" =>
      "67bc2f3a5a5712a74c996dcf2c4418f1629d1183dbea03b6454c883809584313",
    "docs/delivery/content-evidence/copy/journeys/verification/P8_05_VERIFICATION_PENDING_COPY.md" =>
      "a2c2e774d027c14af1e03cdfd1ce8b4032e41f101609cbddd0e6abee9bbe3fe5"
  }

  setup do
    previous = %{
      binding_keys: Application.get_env(:new_you, :identity_registration_binding_keys),
      token_secret: Application.get_env(:new_you, :identity_token_signing_secret),
      communications_keyring: Application.get_env(:new_you, :communications_keyring),
      browser_fixtures: Application.get_env(:new_you, :p8_05_browser_development_fixtures)
    }

    Application.put_env(:new_you, :identity_registration_binding_keys, %{
      active_version: "test-v1",
      keys: %{"test-v1" => :crypto.strong_rand_bytes(32)}
    })

    Application.put_env(:new_you, :identity_token_signing_secret, :crypto.strong_rand_bytes(32))

    Application.put_env(:new_you, :communications_keyring, %{
      active: "test-v1",
      keys: %{"test-v1" => :crypto.strong_rand_bytes(32)}
    })

    Application.put_env(:new_you, :p8_05_browser_development_fixtures, true)

    on_exit(fn ->
      restore_env(:identity_registration_binding_keys, previous.binding_keys)
      restore_env(:identity_token_signing_secret, previous.token_secret)
      restore_env(:communications_keyring, previous.communications_keyring)
      restore_env(:p8_05_browser_development_fixtures, previous.browser_fixtures)
    end)

    :ok
  end

  describe "GET /register" do
    test "copy inputs match the bounded-development source tree pinned for WELL-52" do
      Enum.each(@pinned_copy_source_hashes, fn {relative_path, expected_hash} ->
        path = Path.expand("../../../#{relative_path}", __DIR__)

        actual_hash =
          path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

        assert actual_hash == expected_hash, "changed pinned copy source: #{relative_path}"
      end)
    end

    test "renders the registered English launch and registration copy without Afrikaans fallback",
         %{
           conn: conn
         } do
      html = conn |> get("/register?locale=en") |> html_response(200)

      assert_page_copy(html, @registration_copy_keys, "en")

      assert_registration_label_copy(
        html,
        "registration-surname",
        "identity.registration.surname.label",
        "en"
      )

      assert html =~ ~r/<html\b[^>]*\blang="en"/
      assert html =~ ~s(name="registration[preferred_language]")
      assert html =~ ~s(value="en")
      assert html =~ ~s(name="registration[confirmed_age_18]")
      assert html =~ ~s(name="registration[terms_accepted]")
      assert html =~ ~s(name="registration[privacy_accepted]")
      assert html =~ ~s(name="registration[first_name]")
      assert html =~ ~s(name="registration[surname]")
      assert html =~ ~s(name="registration[email]")
      assert html =~ ~s(name="registration[password]")
      assert html =~ ~s(autocomplete="given-name")
      assert html =~ ~s(autocomplete="family-name")
      assert html =~ ~s(autocomplete="email")
      assert html =~ ~s(autocomplete="new-password")
      assert html =~ ~s(href="/legal/terms")
      assert html =~ ~s(href="/legal/privacy")
      refute html =~ "terms_version_id"
      refute html =~ "privacy_version_id"
    end

    test "does not treat an opaque CSRF token as Afrikaans copy", %{conn: conn} do
      previous_token = Process.get(:plug_masked_csrf_token)
      token = "Van" <> String.duplicate("A", 21)
      Process.put(:plug_masked_csrf_token, token)

      try do
        html = conn |> get("/register?locale=en") |> html_response(200)

        assert html =~ ~s(name="csrf-token" content="#{token}")
        assert_page_copy(html, @registration_copy_keys, "en")
      after
        if previous_token do
          Process.put(:plug_masked_csrf_token, previous_token)
        else
          Process.delete(:plug_masked_csrf_token)
        end
      end
    end

    test "still rejects Afrikaans participant copy added to the English page", %{conn: conn} do
      html = conn |> get("/register?locale=en") |> html_response(200)

      mixed_copy =
        html <>
          "<p>" <> expected_rendered_copy("identity.registration.surname.label", "af") <> "</p>"

      assert_raise ExUnit.AssertionError, ~r/found identity.registration.surname.label\/af/, fn ->
        assert_page_copy(mixed_copy, @registration_copy_keys, "en")
      end
    end

    test "renders the registered Afrikaans launch and registration copy without English fallback",
         %{
           conn: conn
         } do
      html = conn |> get("/register?locale=af") |> html_response(200)

      assert_page_copy(html, @registration_copy_keys, "af")

      assert_registration_label_copy(
        html,
        "registration-surname",
        "identity.registration.surname.label",
        "af"
      )

      assert html =~ ~r/<html\b[^>]*\blang="af"/
      assert html =~ ~s(value="af")
    end

    test "renders useful English registration content by default with a visible language switcher",
         %{conn: conn} do
      html = conn |> get("/register") |> html_response(200)

      assert_page_copy(html, @registration_copy_keys, "en")
      assert html =~ ~r/<html\b[^>]*\blang="en"/
      assert html =~ ~s(href="/register?locale=af")
      assert html =~ ~s(href="/register?locale=en")
      assert html =~ ~s(aria-label="#{expected_rendered_copy("shared.language.change", "en")}")
      assert html =~ ~r/<h1\b[^>]*id="launch-heading"/
    end

    test "uses NewYou tokens for responsive headings, focus, selection, and reduced motion", %{
      conn: conn
    } do
      tokens = File.read!(@design_tokens_path)

      assert tokens =~ "--ny-paper:"
      assert tokens =~ "--ny-focus:"
      assert tokens =~ "overflow-x: clip"
      assert tokens =~ ".registration-page :focus-visible"
      assert tokens =~ ".registration-page a:active"
      assert tokens =~ ".registration-page button:active"
      assert tokens =~ "outline: 2px solid var(--ny-focus)"
      assert tokens =~ "text-wrap: balance"
      assert tokens =~ "::selection"
      assert tokens =~ "caret-color: var(--ny-accent)"
      assert tokens =~ "@media (prefers-reduced-motion: reduce)"

      for locale <- ["en", "af"] do
        html = conn |> get("/register?locale=#{locale}") |> html_response(200)
        assert html =~ ~r/<h1\b[^>]*id="launch-heading"/
        assert html =~ "disabled:bg-ny-muted"
        assert html =~ "disabled:text-ny-paper"
        assert html =~ "disabled:cursor-not-allowed"
        refute html =~ "disabled:opacity-60"
      end
    end

    test "keeps the launch and safety copy before a full-width registration section at desktop sizes",
         %{conn: conn} do
      for locale <- ["en", "af"] do
        html = conn |> get("/register?locale=#{locale}") |> html_response(200)
        {page_index, _} = :binary.match(html, "registration-page")
        page_content = binary_part(html, page_index, byte_size(html) - page_index)

        safety_copy = expected_copy("public.entry.safety.body", locale)
        registration_copy = expected_copy("identity.registration.title", locale)

        assert :binary.match(page_content, safety_copy) <
                 :binary.match(page_content, registration_copy)

        assert html =~ "lg:col-span-12"
        refute html =~ "lg:col-start-6 lg:row-span-2"
        assert html =~ "lg:grid-cols-12"
        assert html =~ "min-w-0"
        assert html =~ "break-words"
      end
    end

    test "rejects unsupported registration locales without falling back", %{conn: conn} do
      conn = get(conn, "/register?locale=mi")
      assert conn.status == 404
      assert conn.resp_body == ""
      refute conn.resp_body =~ expected_copy("public.entry.launch.title", "en")
      refute conn.resp_body =~ expected_copy("public.entry.launch.title", "af")
    end

    test "copy lookup fails closed for unknown keys, locales, and unresolved tokens" do
      assert_raise KeyError, fn -> CopyRegistry.text!("missing.semantic.key", "en") end
      assert_raise ArgumentError, fn -> CopyRegistry.text!("public.entry.launch.title", "mi") end
      assert_raise ArgumentError, fn -> CopyRegistry.text!("public.entry.launch.body", "en") end

      assert_raise ArgumentError, fn ->
        CopyRegistry.text!("public.entry.launch.title", "en", %{"unconfigured" => "value"})
      end

      assert_raise ArgumentError, fn ->
        CopyRegistry.text!("public.entry.launch.body", "en", %{"platform_name" => nil})
      end

      assert_raise ArgumentError, fn ->
        CopyRegistry.text!("public.entry.launch.body", "en", %{"platform_name" => "  "})
      end
    end
  end

  describe "legal development baselines" do
    test "serves the exact English development artifacts at their linked routes", %{conn: conn} do
      terms_conn = get(conn, "/legal/terms")
      privacy_conn = get(build_conn(), "/legal/privacy")
      terms = response(terms_conn, 200)
      privacy = response(privacy_conn, 200)

      assert terms == File.read!(@terms_path)
      assert privacy == File.read!(@privacy_path)

      assert Base.encode16(:crypto.hash(:sha256, terms), case: :lower) ==
               "6feb2d016f30e889c08995990a863429db0034af49fc6b6bd3467b90cda03937"

      assert Base.encode16(:crypto.hash(:sha256, privacy), case: :lower) ==
               "ac603377eaafce20bf5e425f64cfc97fbc855b20bd66deca481401f0f6efd43e"

      manifest =
        "docs/delivery/content-evidence/content_media/LEGAL_BASELINE_CONTENT_MANIFEST_v0.1.0.json"
        |> File.read!()
        |> Jason.decode!()

      terms_entry = Enum.find(manifest["versions"], &(&1["document_type"] == "terms"))
      privacy_entry = Enum.find(manifest["versions"], &(&1["document_type"] == "privacy"))

      assert RegistrationController.legal_baseline_valid?(:terms, terms_entry, terms)
      assert RegistrationController.legal_baseline_valid?(:privacy, privacy_entry, privacy)
      refute RegistrationController.legal_baseline_valid?(:terms, terms_entry, terms <> " ")
      refute RegistrationController.legal_baseline_valid?(:privacy, privacy_entry, privacy <> " ")
      assert get_resp_header(terms_conn, "cache-control") == ["no-store"]
      assert get_resp_header(terms_conn, "content-type") |> List.first() =~ "text/html"
    end

    test "does not serve development legal baselines when the feature gate is off", %{conn: conn} do
      previous = Application.fetch_env!(:new_you, :p8_05_browser_development_fixtures)
      Application.put_env(:new_you, :p8_05_browser_development_fixtures, false)

      on_exit(fn ->
        Application.put_env(:new_you, :p8_05_browser_development_fixtures, previous)
      end)

      assert get(conn, "/legal/terms").status == 404
      assert get(build_conn(), "/legal/privacy").status == 404
    end
  end

  describe "POST /register" do
    test "rejects a registration POST without the browser CSRF token" do
      registration = valid_registration("en")

      response =
        build_conn()
        |> Plug.Conn.put_private(:plug_skip_csrf_protection, false)
        |> post("/register", %{"registration" => registration})

      assert response.status == 403
      assert response.resp_body == ""
      assert accounts_for(registration["email"]) == []
    end

    test "accepts a same-browser registration with the CSRF token from its form" do
      registration = valid_registration("en")
      conn = get(build_conn(), "/register?locale=en")
      token = hidden_value!(html_response(conn, 200), ~r/name="_csrf_token"[^>]*value="([^"]+)"/)
      conn = Plug.Conn.put_private(conn, :plug_skip_csrf_protection, false)

      response =
        post(conn, "/register", %{
          "_csrf_token" => token,
          "registration" => registration
        })

      assert response.status == 200
      assert accounts_for(registration["email"]) |> length() == 1
    end

    test "creates an unverified Account in the selected locale and renders the exact pending copy",
         %{
           conn: conn
         } do
      registration = valid_registration("en")
      registered_conn = post(conn, "/register", %{"registration" => registration})
      html = html_response(registered_conn, 200)

      assert_page_copy(html, @pending_copy_keys, "en")
      assert html =~ ~r/<html\b[^>]*\blang="en"/
      assert html =~ expected_copy("identity.registration.accepted_neutral", "en")
      refute html =~ "account_id"
      refute html =~ registration["password"]
      assert registered_conn.request_path == "/register"
      assert registered_conn.query_string == ""

      [account] = accounts_for(registration["email"])
      assert account.preferred_language == :en
      assert account.acceptance_locale == :en
      assert account.terms_version_id == @development_terms_id
      assert account.privacy_version_id == @development_privacy_id
      assert account.confirmed_age_18?
      refute account.email_verified?

      session = Plug.Conn.get_session(registered_conn)
      refute Map.has_key?(session, "email")
      refute Map.has_key?(session, :email)
      refute Map.has_key?(session, "account_id")
      refute Map.has_key?(session, :account_id)
      refute Map.has_key?(session, "preferred_language")
      refute Map.has_key?(session, "operation_id")
      refute Map.has_key?(session, "password")
      assert Map.has_key?(session, "_csrf_token")
      assert Enum.all?(Map.keys(session), &(&1 == "_csrf_token"))
    end

    test "pending navigation separates the public entry content from home" do
      for locale <- ["en", "af"] do
        registration = valid_registration(locale)

        html =
          build_conn()
          |> post("/register", %{"registration" => registration})
          |> html_response(200)

        browse_label = expected_copy("identity.verification.pending.browse_public", locale)
        home_label = expected_copy("identity.verification.pending.home", locale)

        assert link_target(html, browse_label) == "/register?locale=#{locale}"
        assert link_target(html, home_label) == "/register"
        refute link_target(html, browse_label) == link_target(html, home_label)
        assert html =~ ~r/<a href="\/register" class="[^"]*whitespace-nowrap/
      end
    end

    test "persists Afrikaans as the Account preferred and acceptance language", %{conn: conn} do
      registration = valid_registration("af")
      html = conn |> post("/register", %{"registration" => registration}) |> html_response(200)

      assert_page_copy(html, @pending_copy_keys, "af")
      assert html =~ ~r/<html\b[^>]*\blang="af"/
      [account] = accounts_for(registration["email"])
      assert account.preferred_language == :af
      assert account.acceptance_locale == :af
    end

    test "age and both legal gates must be accepted before the Identity call" do
      for field <- ["confirmed_age_18", "terms_accepted", "privacy_accepted"] do
        registration = valid_registration("en") |> Map.put(field, "false")

        html =
          build_conn()
          |> post("/register", %{"registration" => registration})
          |> html_response(200)

        key =
          case field do
            "confirmed_age_18" -> "identity.registration.age.required"
            "terms_accepted" -> "identity.registration.terms.required"
            "privacy_accepted" -> "identity.registration.privacy_acceptance.required"
          end

        assert html =~ expected_copy(key, "en")
        assert accounts_for(registration["email"]) == []
      end
    end

    test "all DEC-027 registration fields are required before an Account can be created" do
      for {field, key} <- [
            {"first_name", "identity.registration.first_name.required"},
            {"surname", "identity.registration.surname.required"},
            {"email", "identity.registration.email.required"},
            {"password", "identity.registration.password.required"}
          ] do
        registration = valid_registration("en") |> Map.delete(field)
        original_email = registration["email"] || "registration-absent@example.test"

        html =
          build_conn()
          |> post("/register", %{"registration" => registration})
          |> html_response(200)

        assert html =~ expected_copy(key, "en")
        assert accounts_for(original_email) == []
      end
    end

    test "changed input cannot reuse an operation ID already bound by Identity", %{conn: conn} do
      registration = valid_registration("en")

      first_html =
        conn |> post("/register", %{"registration" => registration}) |> html_response(200)

      changed = Map.put(registration, "surname", "Changed")

      retry_html =
        build_conn()
        |> post("/register", %{"registration" => changed})
        |> html_response(200)

      assert first_html =~ expected_copy("identity.registration.accepted_neutral", "en")
      assert retry_html =~ expected_copy("identity.registration.failure", "en")
      assert length(accounts_for(registration["email"])) == 1
    end

    test "registration request details are not written to the application log" do
      registration = valid_registration("en")

      logs =
        capture_log(fn ->
          post(build_conn(), "/register", %{"registration" => registration})
        end)

      refute logs =~ registration["first_name"]
      refute logs =~ registration["surname"]
      refute logs =~ registration["email"]
      refute logs =~ registration["password"]
    end

    test "participant fields and rendered pending context are excluded from framework telemetry" do
      registration = valid_registration("en")
      parent = self()
      ref = make_ref()

      events = [
        [:phoenix, :endpoint, :start],
        [:phoenix, :endpoint, :stop],
        [:phoenix, :router_dispatch, :start],
        [:phoenix, :router_dispatch, :stop]
      ]

      :ok =
        :telemetry.attach_many(
          ref,
          events,
          fn event, _measurements, %{conn: telemetry_conn}, {test_pid, test_ref} ->
            send(test_pid, {test_ref, event, telemetry_conn})
          end,
          {parent, ref}
        )

      on_exit(fn -> :telemetry.detach(ref) end)

      post(build_conn(), "/register", %{"registration" => registration})

      received_telemetry = receive_telemetry_events(ref, [])

      assert Enum.any?(received_telemetry, fn {event, _conn} ->
               event == [:phoenix, :endpoint, :start]
             end)

      assert Enum.any?(received_telemetry, fn {event, _conn} ->
               event == [:phoenix, :endpoint, :stop]
             end)

      refute Enum.any?(received_telemetry, fn {event, _conn} ->
               event in [
                 [:phoenix, :router_dispatch, :start],
                 [:phoenix, :router_dispatch, :stop]
               ]
             end)

      Enum.each(received_telemetry, fn {_event, telemetry_conn} ->
        assert telemetry_conn.body_params == %{}
        assert telemetry_conn.params == %{}
        assert telemetry_conn.query_params == %{}
        assert telemetry_conn.path_params == %{}
        assert telemetry_conn.assigns == %{}
        assert telemetry_conn.private == %{}
        assert telemetry_conn.req_headers == []
        assert telemetry_conn.resp_headers == []
        assert telemetry_conn.resp_body == ""
        assert telemetry_conn.secret_key_base == nil
        assert telemetry_conn.remote_ip == nil
        refute inspect(telemetry_conn) =~ registration["email"]
        refute inspect(telemetry_conn) =~ registration["password"]
      end)
    end

    test "nearby registration paths do not expose submitted fields through router telemetry" do
      registration = valid_registration("en")
      parent = self()
      ref = make_ref()

      events = [
        [:phoenix, :endpoint, :start],
        [:phoenix, :endpoint, :stop],
        [:phoenix, :router_dispatch, :start],
        [:phoenix, :router_dispatch, :stop]
      ]

      :ok =
        :telemetry.attach_many(
          ref,
          events,
          fn event, _measurements, %{conn: telemetry_conn}, {test_pid, test_ref} ->
            send(test_pid, {test_ref, event, telemetry_conn})
          end,
          {parent, ref}
        )

      on_exit(fn -> :telemetry.detach(ref) end)

      response =
        post(build_conn(), "/register/", %{"registration" => registration})

      assert response.status == 404
      received_telemetry = receive_telemetry_events(ref, [])

      refute Enum.any?(received_telemetry, fn {event, _conn} ->
               event in [
                 [:phoenix, :router_dispatch, :start],
                 [:phoenix, :router_dispatch, :stop]
               ]
             end)

      Enum.each(received_telemetry, fn {_event, telemetry_conn} ->
        assert telemetry_conn.body_params == %{}
        assert telemetry_conn.params == %{}
        assert telemetry_conn.private == %{}
        refute inspect(telemetry_conn) =~ registration["email"]
        refute inspect(telemetry_conn) =~ registration["password"]
      end)
    end

    test "an identical transport retry reuses its operation ID and does not create a second Account",
         %{
           conn: conn
         } do
      registration = valid_registration("en")
      first = conn |> post("/register", %{"registration" => registration}) |> html_response(200)

      retry =
        build_conn() |> post("/register", %{"registration" => registration}) |> html_response(200)

      assert first =~ expected_copy("identity.registration.accepted_neutral", "en")
      assert retry =~ expected_copy("identity.registration.accepted_neutral", "en")
      assert length(accounts_for(registration["email"])) == 1
    end

    test "a duplicate canonical email receives the same neutral pending outcome", %{conn: conn} do
      first = valid_registration("en")
      first_conn = post(conn, "/register", %{"registration" => first})
      assert first_conn.status == 200

      duplicate_email = String.replace_suffix(first["email"], "@example.test", "@EXAMPLE.TEST ")
      duplicate = valid_registration("en") |> Map.put("email", duplicate_email)

      duplicate_conn =
        build_conn()
        |> post("/register", %{"registration" => duplicate})

      neutral = expected_copy("identity.registration.accepted_neutral", "en")
      assert first_conn.resp_body =~ neutral
      assert duplicate_conn.resp_body =~ neutral

      assert registration_public_result(first_conn, first["email"]) ==
               registration_public_result(duplicate_conn, duplicate_email)

      assert length(accounts_for(first["email"])) == 1
      refute duplicate_conn.resp_body =~ "account_id"
    end

    test "an unknown email receives the same neutral resend outcome", %{conn: conn} do
      resend = %{
        "operation_id" => Ecto.UUID.generate(),
        "preferred_language" => "af",
        "email" => "unknown-#{System.unique_integer([:positive])}@example.test"
      }

      html =
        post(conn, "/verification/resend", %{"resend" => resend})
        |> html_response(200)

      assert html =~ expected_copy("identity.verification.resend.accepted_neutral", "af")
      refute html =~ expected_copy("identity.verification.resend.failure", "af")
      assert accounts_for(resend["email"]) == []
    end

    test "registration is unavailable when the bounded development feature is disabled", %{
      conn: conn
    } do
      previous = Application.fetch_env!(:new_you, :p8_05_browser_development_fixtures)
      Application.put_env(:new_you, :p8_05_browser_development_fixtures, false)

      on_exit(fn ->
        Application.put_env(:new_you, :p8_05_browser_development_fixtures, previous)
      end)

      assert get(conn, "/register?locale=en").status == 404

      assert post(build_conn(), "/register", %{"registration" => valid_registration("en")}).status ==
               404
    end

    test "missing or unsupported preferred language cannot fall back on POST" do
      registration = valid_registration("en")
      unsupported = Map.put(registration, "preferred_language", "mi")
      missing = Map.delete(registration, "preferred_language")

      assert post(build_conn(), "/register", %{"registration" => unsupported}).status == 404
      assert post(build_conn(), "/register", %{"registration" => missing}).status == 404
      assert accounts_for(registration["email"]) == []
    end
  end

  test "login, verification consumption, and email correction remain outside this browser slice" do
    assert get(build_conn(), "/login").status == 404
    assert get(build_conn(), "/verification/consume").status == 404
    assert get(build_conn(), "/email/change").status == 404
  end

  describe "POST /verification/resend" do
    test "resends explicitly, returns neutral copy, and offers a fresh ID for a later click", %{
      conn: conn
    } do
      registration = valid_registration("en")
      pending = conn |> post("/register", %{"registration" => registration}) |> html_response(200)
      operation_id = hidden_value!(pending, ~r/name="resend\[operation_id\]"[^>]*value="([^"]+)"/)

      resend = %{
        "operation_id" => operation_id,
        "preferred_language" => "en",
        "email" => registration["email"]
      }

      resent =
        build_conn()
        |> post("/verification/resend", %{"resend" => resend})
        |> html_response(200)

      assert resent =~ expected_copy("identity.verification.resend.accepted_neutral", "en")

      next_operation_id =
        hidden_value!(resent, ~r/name="resend\[operation_id\]"[^>]*value="([^"]+)"/)

      refute next_operation_id == operation_id
      assert accounts_for(registration["email"]) |> length() == 1
      refute resent =~ "account_id"
      refute resent =~ registration["password"]
    end

    test "a resend transport retry with the same ID stays neutral", %{conn: conn} do
      registration = valid_registration("en")
      pending = conn |> post("/register", %{"registration" => registration}) |> html_response(200)
      operation_id = hidden_value!(pending, ~r/name="resend\[operation_id\]"[^>]*value="([^"]+)"/)

      resend = %{
        "operation_id" => operation_id,
        "preferred_language" => "en",
        "email" => registration["email"]
      }

      first =
        build_conn()
        |> post("/verification/resend", %{"resend" => resend})
        |> html_response(200)

      retry =
        build_conn()
        |> post("/verification/resend", %{"resend" => resend})
        |> html_response(200)

      neutral = expected_copy("identity.verification.resend.accepted_neutral", "en")
      assert first =~ neutral
      assert retry =~ neutral
      assert accounts_for(registration["email"]) |> length() == 1
    end
  end

  defp assert_page_copy(html, keys, locale) do
    other_locale = if locale == "en", do: "af", else: "en"
    text_nodes = rendered_text_nodes(html)

    Enum.each(keys, fn key ->
      own = expected_rendered_copy(key, locale)
      other = expected_rendered_copy(key, other_locale)

      assert copy_present?(html, text_nodes, key, own), "missing #{key}/#{locale} from page"

      refute own != other and copy_present?(html, text_nodes, key, other),
             "found #{key}/#{other_locale} in #{locale} page"
    end)
  end

  defp copy_present?(html, _text_nodes, "shared.language.change", copy),
    do: html =~ ~s(aria-label="#{copy}")

  defp copy_present?(_html, text_nodes, _key, copy), do: copy in text_nodes

  defp assert_registration_label_copy(html, field_id, key, locale) do
    field_id = Regex.escape(field_id)

    assert [label_text] =
             Regex.run(
               ~r/<label\b(?=[^>]*\bfor="#{field_id}")[^>]*>([^<]*)<\/label>/s,
               html,
               capture: :all_but_first
             )

    assert String.trim(label_text) == expected_rendered_copy(key, locale)
  end

  defp rendered_text_nodes(html) do
    Regex.scan(~r/>([^<>]*)</s, html, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp expected_rendered_copy(key, locale) do
    key
    |> expected_copy(locale)
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  defp expected_copy(key, locale) do
    entry = Enum.find(@copy_registry["entries"], &(&1["key"] == key))
    text = entry |> Map.fetch!(locale) |> Map.fetch!("text")
    String.replace(text, "{{platform_name}}", NewYou.platform_name())
  end

  defp valid_registration(locale) do
    %{
      "operation_id" => Ecto.UUID.generate(),
      "first_name" => "Participant",
      "surname" => "Example",
      "email" => "registration-#{System.unique_integer([:positive])}@example.test",
      "password" => Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false),
      "preferred_language" => locale,
      "confirmed_age_18" => "true",
      "terms_accepted" => "true",
      "privacy_accepted" => "true"
    }
  end

  defp accounts_for(email) do
    {:ok, canonical_email} = Identity.Email.canonicalize(email)

    Identity.Account
    |> Ash.Query.filter(email == ^canonical_email)
    |> Ash.read!(domain: Identity, authorize?: false)
  end

  defp hidden_value!(html, pattern) do
    case Regex.run(pattern, html, capture: :all_but_first) do
      [value] -> value
      _ -> flunk("expected a hidden form value matching #{inspect(pattern)}")
    end
  end

  defp registration_public_result(conn, submitted_email) do
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

    body =
      Regex.replace(
        ~r/(<meta name="csrf-token" content=")[^"]+/,
        body,
        "\\1[session-token]"
      )

    body =
      Regex.replace(
        ~r/(name="resend\[operation_id\]"[^>]*value=")[^"]+/,
        body,
        "\\1[operation-id]"
      )

    cookies =
      conn
      |> Plug.Conn.get_resp_header("set-cookie")
      |> Enum.map(&Regex.replace(~r/(^[^=;]+=)[^;]*/, &1, "\\1[cookie]"))

    {
      conn.status,
      body,
      Plug.Conn.get_resp_header(conn, "location"),
      Plug.Conn.get_resp_header(conn, "cache-control"),
      Plug.Conn.get_resp_header(conn, "referrer-policy"),
      Plug.Conn.get_resp_header(conn, "content-security-policy"),
      cookies,
      Plug.Conn.get_session(conn) |> Map.drop(["_csrf_token"])
    }
  end

  defp link_target(html, label) do
    pattern = ~r/<a href="([^"]+)"[^>]*>\s*#{Regex.escape(label)}\s*<\/a>/s

    case Regex.run(pattern, html, capture: :all_but_first) do
      [target] -> target
      _ -> flunk("expected a link for #{inspect(label)}")
    end
  end

  defp receive_telemetry_events(ref, events) do
    receive do
      {^ref, event, telemetry_conn} ->
        receive_telemetry_events(ref, [{event, telemetry_conn} | events])
    after
      0 -> Enum.reverse(events)
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:new_you, key)
  defp restore_env(key, value), do: Application.put_env(:new_you, key, value)
end
