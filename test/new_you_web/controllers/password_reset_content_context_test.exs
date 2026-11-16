defmodule NewYouWeb.PasswordResetContentContextTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  require Ash.Query

  alias NewYou.{Communications, Identity}
  alias NewYou.Communications.MessageIntent
  alias NewYou.Content.PasswordResetMessage, as: Content
  alias NewYou.Content.PasswordResetBrowserCopy, as: BrowserCopy
  alias NewYou.Identity.{Account, Token}
  alias NewYou.Proof.{P805, RegistrationSeam}

  @endpoint NewYouWeb.Endpoint
  @packet_directory "docs/delivery/content-evidence/content_media/password_reset_messages"
  @phase9_packet "PASSWORD_RESET_MESSAGE_WELL136_PHASE9_ELIGIBILITY_v0.3.0.json"
  @historical_packet "PASSWORD_RESET_MESSAGE_EVIDENCE_PACKET_v0.2.0.json"

  setup do
    root = Path.join(System.tmp_dir!(), "well136-context-#{Ecto.UUID.generate()}")
    File.mkdir_p!(root)
    File.cp_r!("docs", Path.join(root, "docs"))
    Process.put({Content, :evidence_root}, root)
    Process.put({BrowserCopy, :evidence_root}, root)
    previous = Application.fetch_env(:new_you, :fp001_development_entry)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:new_you, :fp001_development_entry, value)
        :error -> Application.delete_env(:new_you, :fp001_development_entry)
      end

      File.rm_rf!(root)
    end)

    {:ok, root: root}
  end

  test "historical browser copy and mutation remain independent of missing or corrupt C-02", %{
    root: root
  } do
    for file <- ["well136-c02-v0.1.json", "well136-c02-owner-approval.json"] do
      path = Path.join([root, "docs/development/fixtures", file])
      original = File.read!(path)

      for state <- [:missing, :corrupt], locale <- ["en", "af"] do
        invalidate(path, original, state)

        P805.with_fixture(fn ->
          Application.put_env(:new_you, :fp001_development_entry, false)
          Application.put_env(:new_you, :p8_12_browser_development_fixtures, true)
          {request, account} = account()
          assert {:ok, _} = Content.binding(locale)
          page = get(build_conn(), "/password/reset?locale=#{locale}")
          assert page.status == 200

          legacy_action =
            if locale == "en", do: "Request reset link", else: "Vra wagwoordskakel aan"

          assert page.resp_body =~ legacy_action
          operation = operation()

          result =
            post(recycle(page), "/password/reset", %{
              locale: locale,
              email: request.email,
              operation_id: operation,
              context: "well136"
            })

          assert result.status == 200

          legacy_body =
            if locale == "en",
              do:
                "If the address can receive a reset link, it will arrive shortly. You can close this page.",
              else:
                "As die adres ’n wagwoordskakel kan ontvang, sal dit binnekort aankom. Jy kan hierdie bladsy toemaak."

          assert result.resp_body =~ legacy_body
          assert intent(operation).render_schema == "password-reset-v1"
          token = proof(account.id)

          {:ok, {:ok, bearer}} =
            Ash.transact([Account, Token], fn ->
              Identity.password_reset_delivery(token.jti, request.email, locale)
            end)

          for method <- [:get, :head] do
            passive =
              Phoenix.ConnTest.dispatch(
                build_conn(),
                @endpoint,
                method,
                "/password/reset/confirm?locale=#{locale}&proof=#{URI.encode_www_form(bearer)}"
              )

            assert passive.status == 200
            assert proof(account.id) == token
            assert Ash.get!(Account, account.id, authorize?: false) == account
            assert session_count(account.id) == 0
          end

          confirmation =
            post(build_conn(), "/password/reset/confirm", %{
              locale: locale,
              proof: bearer,
              password: "historical replacement password",
              operation_id: operation()
            })

          assert confirmation.status == 200

          legacy_success =
            if locale == "en",
              do: "Sign in again with your new password.",
              else: "Meld weer met jou nuwe wagwoord aan."

          assert confirmation.resp_body =~ legacy_success
          assert proof(account.id) == nil

          assert Ash.get!(Account, account.id, authorize?: false).credential_version ==
                   account.credential_version + 1

          assert session_count(account.id) == 0
        end)

        File.write!(path, original)
      end
    end
  end

  test "ordinary browser cannot fall back when C-02 is missing or corrupt", %{root: root} do
    for file <- ["well136-c02-v0.1.json", "well136-c02-owner-approval.json"] do
      path = Path.join([root, "docs/development/fixtures", file])
      original = File.read!(path)

      for state <- [:missing, :corrupt], locale <- ["en", "af"] do
        invalidate(path, original, state)

        P805.with_fixture(fn ->
          Application.put_env(:new_you, :fp001_development_entry, true)
          Application.put_env(:new_you, :p8_12_browser_development_fixtures, true)
          {request, account} = account()
          assert :ok = Identity.request_password_reset(request.email, locale, operation())
          token = proof(account.id)

          {:ok, {:ok, bearer}} =
            Ash.transact([Account, Token], fn ->
              Identity.password_reset_delivery(token.jti, request.email, locale)
            end)

          assert {:ok, _} = Content.binding(locale)
          assert {:ok, _} = Content.binding(locale, :well136)
          operation = operation()

          for method <- [:get, :head] do
            assert Phoenix.ConnTest.dispatch(
                     build_conn(),
                     @endpoint,
                     method,
                     "/password/reset?locale=#{locale}"
                   ).status == 404

            assert Phoenix.ConnTest.dispatch(
                     build_conn(),
                     @endpoint,
                     method,
                     "/password/reset/confirm?locale=#{locale}&proof=#{URI.encode_www_form(bearer)}"
                   ).status == 404
          end

          assert post(build_conn(), "/password/reset", %{
                   locale: locale,
                   email: request.email,
                   operation_id: operation,
                   context: "p8_12"
                 }).status == 404

          assert post(build_conn(), "/password/reset/confirm", %{
                   locale: locale,
                   proof: bearer,
                   password: "unauthorized replacement",
                   operation_id: operation(),
                   context: "p8_12"
                 }).status == 404

          assert intent(operation) == nil
          assert proof(account.id) == token
          assert Ash.get!(Account, account.id, authorize?: false) == account
          assert session_count(account.id) == 0
        end)

        File.write!(path, original)
      end
    end
  end

  test "historical unavailable and uncertain responses never borrow C-02 wording", %{root: root} do
    File.rm!(Path.join(root, "docs/development/fixtures/well136-c02-v0.1.json"))
    historical_path = packet_path(root, @historical_packet)
    original = File.read!(historical_path)

    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, false)
      Application.put_env(:new_you, :p8_12_browser_development_fixtures, true)
      {request, account} = account()

      for locale <- ["en", "af"] do
        File.rm!(historical_path)
        unavailable = get(build_conn(), "/password/reset?locale=#{locale}")
        assert unavailable.status == 503
        assert unavailable.resp_body == ""
        File.write!(historical_path, original)
        assert :ok = Identity.request_password_reset(request.email, locale, operation())
        token = proof(account.id)

        {:ok, {:ok, bearer}} =
          Ash.transact([Account, Token], fn ->
            Identity.password_reset_delivery(token.jti, request.email, locale)
          end)

        Process.put(
          RegistrationSeam,
          {:observe, fn -> raise "synthetic historical reset interruption" end}
        )

        try do
          uncertain =
            post(build_conn(), "/password/reset/confirm", %{
              locale: locale,
              proof: bearer,
              password: "uncertain historical replacement",
              operation_id: operation()
            })

          assert uncertain.status == 503
          assert uncertain.resp_body == ""
          assert proof(account.id) == token
          assert Ash.get!(Account, account.id, authorize?: false) == account
          assert session_count(account.id) == 0
        after
          Process.delete(RegistrationSeam)
        end
      end
    end)
  end

  test "historical fresh issuance and delivery do not require Phase-9 applicability", %{
    root: root
  } do
    path = packet_path(root, @phase9_packet)
    original = File.read!(path)

    for locale <- ["en", "af"], state <- [:missing, :withdrawn, :corrupt] do
      invalidate(path, original, state)
      assert {:ok, historical} = Content.binding(locale)
      assert {:error, :content_ineligible} = Content.binding(locale, :well136)

      P805.with_fixture(fn ->
        {request, account} = account()
        operation = operation()

        # This assertion executes inside the real bounded issuance worker. The
        # negative evidence must apply there, not only in this test process.
        Process.put(
          RegistrationSeam,
          {:observe,
           fn ->
             assert {:error, :content_ineligible} = Content.binding(locale, :well136)
           end}
        )

        assert :ok = Identity.request_password_reset(request.email, locale, operation)
        intent = intent(operation)
        assert intent != nil
        assert intent.render_schema == "password-reset-v1"
        assert intent.translation_version_id == historical.translation_version_id
        assert intent.content_sha256 == historical.content_sha256
        deliver(intent)
        assert Ash.get!(Account, account.id, authorize?: false) == account
        assert proof(account.id).purpose == "password_reset"
        assert session_count(account.id) == 0
      end)
    end
  end

  test "legacy browser entry and request remain valid without Phase-9 applicability", %{
    root: root
  } do
    File.rm!(packet_path(root, @phase9_packet))

    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, false)
      Application.put_env(:new_you, :p8_12_browser_development_fixtures, true)
      {request, _account} = account()

      for locale <- ["en", "af"] do
        page = get(build_conn(), "/password/reset?locale=#{locale}")
        assert page.status == 200
        operation = operation()

        result =
          post(recycle(page), "/password/reset", %{
            locale: locale,
            email: request.email,
            operation_id: operation
          })

        assert result.status == 200
        assert intent(operation).render_schema == "password-reset-v1"
        deliver(intent(operation))
      end
    end)
  end

  test "ordinary entry never falls back to legacy approval or a posted context", %{root: root} do
    File.rm!(packet_path(root, @phase9_packet))

    P805.with_fixture(fn ->
      Application.put_env(:new_you, :fp001_development_entry, true)
      Application.put_env(:new_you, :p8_12_browser_development_fixtures, true)
      {request, account} = account()

      for locale <- ["en", "af"] do
        assert {:ok, _} = Content.binding(locale)
        page = get(build_conn(), "/password/reset?locale=#{locale}")
        assert page.status == 503
        operation = operation()

        result =
          post(build_conn(), "/password/reset", %{
            locale: locale,
            email: request.email,
            operation_id: operation,
            context: "p8_12",
            render_schema: "password-reset-v1"
          })

        assert result.status == 503
        assert result.resp_body == page.resp_body
        assert intent(operation) == nil
      end

      assert proof(account.id) == nil
    end)
  end

  test "WELL-136 issuance cannot supersede historical proof when Phase-9 evidence is ineligible",
       %{
         root: root
       } do
    path = packet_path(root, @phase9_packet)
    original = File.read!(path)

    for locale <- ["en", "af"], state <- [:missing, :withdrawn, :corrupt] do
      invalidate(path, original, state)

      P805.with_fixture(fn ->
        {request, account} = account()
        historical_operation = operation()
        assert :ok = Identity.request_password_reset(request.email, locale, historical_operation)
        original_proof = proof(account.id)
        assert original_proof != nil
        ordinary_operation = operation()

        assert :ok =
                 Identity.request_password_reset(
                   request.email,
                   locale,
                   ordinary_operation,
                   :well136
                 )

        assert intent(ordinary_operation) == nil
        assert proof(account.id) == original_proof
        assert intent(historical_operation).render_schema == "password-reset-v1"
        deliver(intent(historical_operation))
        assert Ash.get!(Account, account.id, authorize?: false) == account
      end)
    end
  end

  test "request retries cannot retarget the persisted context and unknown contexts issue nothing" do
    P805.with_fixture(fn ->
      {request, account} = account()
      historical_operation = operation()
      assert :ok = Identity.request_password_reset(request.email, "en", historical_operation)
      original_proof = proof(account.id)
      original_intent = intent(historical_operation)

      assert :ok =
               Identity.request_password_reset(
                 request.email,
                 "en",
                 historical_operation,
                 :well136
               )

      assert proof(account.id) == original_proof
      assert intent(historical_operation) == original_intent
      assert original_intent.render_schema == "password-reset-v1"
      invalid_operation = operation()

      assert :ok =
               Identity.request_password_reset(
                 request.email,
                 "en",
                 invalid_operation,
                 :production
               )

      assert intent(invalid_operation) == nil
      assert proof(account.id) == original_proof
    end)
  end

  test "historical queued delivery still fails closed on its own approval withdrawal", %{
    root: root
  } do
    File.rm!(packet_path(root, @phase9_packet))

    P805.with_fixture(fn ->
      {request, account} = account()
      operation = operation()
      assert :ok = Identity.request_password_reset(request.email, "af", operation)
      queued = intent(operation)
      assert queued != nil
      assert queued.render_schema == "password-reset-v1"
      path = packet_path(root, @historical_packet)
      packet = path |> File.read!() |> Jason.decode!()
      File.write!(path, Jason.encode!(put_in(packet, ["lifecycle", "state"], "withdrawn")))
      parent = self()
      reference = make_ref()

      Process.put(:p810_provider, fn _, _ ->
        send(parent, reference)
        :delivered
      end)

      assert {:ok, :held} = Communications.execute(queued.id)
      refute_received ^reference
      assert Ash.get!(Account, account.id, authorize?: false) == account
      assert proof(account.id).purpose == "password_reset"
    end)
  end

  defp account do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {request, Ash.get!(Account, registration.account_id, authorize?: false)}
  end

  defp intent(operation) do
    MessageIntent
    |> Ash.Query.filter(source_operation_id == ^operation and role == :password_reset)
    |> Ash.read_one!(authorize?: false)
  end

  defp proof(account_id) do
    Token
    |> Ash.Query.filter(account_id == ^account_id and purpose == "password_reset")
    |> Ash.read_one!(authorize?: false)
  end

  defp session_count(account_id),
    do:
      P805.scalar("SELECT count(*) FROM sessions WHERE account_id=$1", [
        Ecto.UUID.dump!(account_id)
      ])

  defp deliver(intent) do
    parent = self()
    reference = make_ref()

    Process.put(:p810_provider, fn _, payload ->
      assert String.contains?(payload.body, "/password/reset/confirm?")
      send(parent, reference)
      :delivered
    end)

    assert {:ok, :processed} = Communications.execute(intent.id)
    assert_received ^reference
  end

  defp operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  defp packet_path(root, filename), do: Path.join([root, @packet_directory, filename])

  defp invalidate(path, _original, :missing), do: File.rm!(path)

  defp invalidate(path, original, :withdrawn),
    do:
      File.write!(
        path,
        Jason.encode!(put_in(Jason.decode!(original), ["lifecycle", "state"], "withdrawn"))
      )

  defp invalidate(path, original, :corrupt), do: File.write!(path, original <> "\n")
end
