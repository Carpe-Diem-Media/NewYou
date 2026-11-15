defmodule NewYou.Proof.EmailChangeScenarios do
  @moduledoc false
  import ExUnit.Assertions
  import Phoenix.ConnTest
  import Plug.Conn
  alias Ecto.Adapters.SQL.Sandbox
  require Ash.Query
  alias NewYou.{Identity, Repo}
  alias NewYou.Identity.{Account, DeviceAssurance, RecoveryCase, Session, Token}
  alias NewYou.Communications.MessageIntent
  alias NewYou.Proof.{P805, RegistrationSeam, Scenario}
  @endpoint NewYouWeb.Endpoint
  def scenario_request_and_fresh_password_reauthentication_create_one_pending_proof_without_changing_canonical_email() do
    P805.with_fixture(fn ->
      registration_request = P805.request()
      target_request = P805.request()
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)
      {:ok, registration} = Identity.register(registration_request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      {:ok, credentials} =
        Identity.authenticate_password(registration_request.email, registration_request.password)

      assert {:error, :primary_email_change_unavailable} =
               Identity.request_primary_email_change(
                 credentials,
                 registration_request.email,
                 "af",
                 operation_id
               )

      assert {:ok, :requested} =
               Identity.request_primary_email_change(
                 credentials,
                 target_request.email,
                 "af",
                 operation_id
               )

      assert {:ok, :proof_pending} =
               Identity.reauthenticate_primary_email_change(
                 credentials,
                 registration_request.password,
                 operation_id
               )

      assert {:ok, :proof_pending} =
               Identity.reauthenticate_primary_email_change(
                 credentials,
                 registration_request.password,
                 operation_id
               )

      account = Ash.get!(Account, registration.account_id, authorize?: false)
      assert account.email == registration_request.email
      assert account.email_verified?
      assert account.primary_email_change_state == :new_address_pending
      assert account.primary_email_change_operation_id == operation_id
      assert account.primary_email_change_target == target_request.email
      assert account.primary_email_change_token_jti

      proofs =
        Token
        |> Ash.Query.filter(account_id == ^account.id and purpose == "email_change_confirmation")
        |> Ash.read!(authorize?: false)

      assert length(proofs) == 1
      assert proofs |> hd() |> Map.get(:email_change_operation_id) == operation_id

      intent =
        MessageIntent
        |> Ash.Query.filter(
          source_operation_id == ^operation_id and role == :email_change_confirmation
        )
        |> Ash.read_one!(authorize?: false)

      assert intent.destination == target_request.email

      assert intent.content_item_id ==
               "NEWYOU-CONTENTITEM-PRIMARY-EMAIL-CHANGE-CONFIRMATION-MESSAGE-EMAIL"

      assert intent.translation_version_id ==
               "NEWYOU-CONTENTTRANSLATIONVERSION-PRIMARY-EMAIL-CHANGE-CONFIRMATION-MESSAGE-EMAIL-AF-V1"
    end)
  end

  def scenario_active_mfa_requires_purpose_bound_totp_step_up_before_issuing_an_email_change_proof() do
    P805.with_fixture(fn ->
      registration_request = P805.request()
      target_request = P805.request()
      operation_id = tracked_operation()
      {:ok, registration} = Identity.register(registration_request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      {:ok, credentials} =
        Identity.authenticate_password(registration_request.email, registration_request.password)

      {:ok, %{secret: secret}} =
        Identity.enroll_privileged_mfa(credentials, registration_request.password)

      period = div(System.os_time(:second), 30)
      previous = Process.put(NewYou.Proof.PrivilegedAccessSeam, period * 30)

      try do
        assert {:ok, :ok} =
                 Identity.confirm_privileged_mfa(
                   credentials,
                   registration_request.password,
                   NimbleTOTP.verification_code(secret, time: period * 30)
                 )

        assert {:ok, :requested} =
                 Identity.request_primary_email_change(
                   credentials,
                   target_request.email,
                   "en",
                   operation_id
                 )

        assert {:error, :primary_email_change_unavailable} =
                 Identity.reauthenticate_primary_email_change(
                   credentials,
                   registration_request.password,
                   operation_id
                 )

        next_period = period + 1
        Process.put(NewYou.Proof.PrivilegedAccessSeam, next_period * 30)

        assert {:ok, :ok} =
                 Identity.step_up_privileged(
                   credentials,
                   registration_request.password,
                   NimbleTOTP.verification_code(secret, time: next_period * 30),
                   :change_primary_email
                 )

        assert {:ok, :proof_pending} =
                 Identity.reauthenticate_primary_email_change(
                   credentials,
                   registration_request.password,
                   operation_id
                 )

        account = current_account(registration.account_id)
        assert account.mfa_enrollment_state == :active
        assert account.primary_email_change_state == :new_address_pending
      after
        if is_nil(previous) do
          Process.delete(NewYou.Proof.PrivilegedAccessSeam)
        else
          Process.put(NewYou.Proof.PrivilegedAccessSeam, previous)
        end
      end
    end)
  end

  def scenario_development_only_email_change_intents_remain_held_and_never_reach_a_provider() do
    P805.with_fixture(fn ->
      registration_request = P805.request()
      target_request = P805.request()
      operation_id = tracked_operation()
      {:ok, registration} = Identity.register(registration_request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      {:ok, credentials} =
        Identity.authenticate_password(registration_request.email, registration_request.password)

      assert {:ok, :requested} =
               Identity.request_primary_email_change(
                 credentials,
                 target_request.email,
                 "af",
                 operation_id
               )

      assert {:ok, :proof_pending} =
               Identity.reauthenticate_primary_email_change(
                 credentials,
                 registration_request.password,
                 operation_id
               )

      intent =
        MessageIntent
        |> Ash.Query.filter(source_operation_id == ^operation_id)
        |> Ash.read_one!(authorize?: false)

      Process.put(:p810_provider, fn _, _ -> flunk("email-change intent reached the provider") end)

      try do
        assert {:ok, :held} = NewYou.Communications.execute(intent.id)
        assert [] == Ash.read!(NewYou.Communications.DeliveryAttempt, authorize?: false)
        assert Ash.get!(MessageIntent, intent.id, authorize?: false).dispatch_disposition == :held
        account = current_account(registration.account_id)
        assert account.email == registration_request.email
        assert account.primary_email_change_state == :new_address_pending
      after
        Process.delete(:p810_provider)
      end
    end)
  end

  def scenario_passive_retrieval_is_inert_and_explicit_csrf_confirmation_does_not_apply_the_email() do
    P805.with_fixture(fn ->
      registration_request = P805.request()
      target_request = P805.request()
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)
      {:ok, registration} = Identity.register(registration_request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      {:ok, credentials} =
        Identity.authenticate_password(registration_request.email, registration_request.password)

      assert {:ok, :requested} =
               Identity.request_primary_email_change(
                 credentials,
                 target_request.email,
                 "af",
                 operation_id
               )

      assert {:ok, :proof_pending} =
               Identity.reauthenticate_primary_email_change(
                 credentials,
                 registration_request.password,
                 operation_id
               )

      account = Ash.get!(Account, registration.account_id, authorize?: false)
      proof_jti = account.primary_email_change_token_jti

      {:ok, {:ok, proof}} =
        NewYou.Repo.transaction(fn ->
          Identity.primary_email_change_delivery(proof_jti, target_request.email, "af")
        end)

      url = "/primary-email-change/confirm?" <> URI.encode_query(%{proof: proof, locale: "af"})
      before = P805.counts()

      for method <- [:get, :head] do
        conn = dispatch(build_conn(), @endpoint, method, url)
        assert conn.status == 200
        assert P805.counts() == before
        refute current_account(registration.account_id).email == target_request.email

        assert current_account(registration.account_id).primary_email_change_state ==
                 :new_address_pending

        assert get_resp_header(conn, "cache-control") == ["no-store"]
        assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
      end

      page = get(build_conn(), url)
      [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, page.resp_body)

      missing_csrf =
        build_conn()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/primary-email-change/confirm", %{proof: proof, locale: "af"})

      assert missing_csrf.status == 403

      assert current_account(registration.account_id).primary_email_change_state ==
               :new_address_pending

      confirmed =
        page
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/primary-email-change/confirm", %{proof: proof, locale: "af", _csrf_token: csrf})

      assert confirmed.status == 200
      refute confirmed.resp_body =~ proof
      assert current_account(registration.account_id).email == registration_request.email
      assert current_account(registration.account_id).primary_email_change_state == :confirmed

      assert {:error, :primary_email_change_unavailable} =
               Identity.confirm_primary_email_change(proof)

      unavailable_url = "/primary-email-change/confirm?proof=invalid&locale=af"
      unavailable_page = get(build_conn(), unavailable_url)

      [_, unavailable_csrf] =
        Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, unavailable_page.resp_body)

      unavailable =
        unavailable_page
        |> recycle()
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/primary-email-change/confirm", %{
          proof: "invalid",
          locale: "af",
          _csrf_token: unavailable_csrf
        })

      assert unavailable.status == 200
      assert unavailable.resp_body =~ ~s(href="/recovery?locale=af")
      assert unavailable.resp_body =~ NewYouWeb.RecoveryCopy.text!("request.action", "af")
      assert current_account(registration.account_id).email == registration_request.email
    end)
  end

  def scenario_confirmed_operation_cannot_apply_after_its_originating_session_is_revoked() do
    with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
      assert :ok = Identity.revoke_session(fixture.credentials)
      assert_apply_denied(fixture)

      assert Ash.get!(Session, fixture.credentials.session_id, authorize?: false).state ==
               :revoked
    end)
  end

  def scenario_competing_session_logout_and_primary_email_apply_serialize_against_current_authority() do
    assert_logout_apply_race(:apply_first)
    assert_logout_apply_race(:logout_first)
  end

  def scenario_guarded_apply_changes_the_canonical_email_and_commits_security_consequences_once() do
    with_apply_policy(%{delay_seconds: 0, requires_review?: false}, fn ->
      P805.with_fixture(fn ->
        scenario_guarded_apply_changes_the_canonical_email_and_commits_security_consequences_once_fixture()
      end)
    end)
  end

  defp scenario_guarded_apply_changes_the_canonical_email_and_commits_security_consequences_once_fixture() do
    registration_request = P805.request()
    target_request = P805.request()
    operation_id = Ecto.UUID.generate()
    P805.track_operation(operation_id)
    {:ok, registration} = Identity.register(registration_request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)

    {:ok, credentials} =
      Identity.authenticate_password(
        registration_request.email,
        registration_request.password
      )

    device_id = Ecto.UUID.generate()

    Repo.query!(
      "INSERT INTO device_assurances (id,account_id,fingerprint,state,security_version,expires_at) VALUES ($1,$2,$3,'trusted',1,now()+interval '1 day')",
      [
        Ecto.UUID.dump!(device_id),
        Ecto.UUID.dump!(registration.account_id),
        :crypto.strong_rand_bytes(32)
      ]
    )

    assert {:ok, :requested} =
             Identity.request_primary_email_change(
               credentials,
               target_request.email,
               "en",
               operation_id
             )

    assert {:ok, :proof_pending} =
             Identity.reauthenticate_primary_email_change(
               credentials,
               registration_request.password,
               operation_id
             )

    account = current_account(registration.account_id)

    {:ok, {:ok, proof}} =
      NewYou.Repo.transaction(fn ->
        Identity.primary_email_change_delivery(
          account.primary_email_change_token_jti,
          target_request.email,
          "en"
        )
      end)

    assert {:ok, :confirmed} = Identity.confirm_primary_email_change(proof)
    refute current_account(registration.account_id).email == target_request.email
    assert {:ok, :applied} = Identity.apply_primary_email_change(operation_id)
    applied = current_account(registration.account_id)
    assert applied.email == target_request.email
    assert applied.email_verified?
    assert applied.primary_email_change_state == :applied
    assert applied.primary_email_change_applied_at

    assert Ash.get!(NewYou.Identity.Session, credentials.session_id, authorize?: false).state ==
             :revoked

    revoked_device = Ash.get!(DeviceAssurance, device_id, authorize?: false)
    assert revoked_device.state == :revoked
    assert revoked_device.revoked_at

    old_address_notice =
      MessageIntent
      |> Ash.Query.filter(
        source_operation_id == ^operation_id and role == :email_change_old_address_notice
      )
      |> Ash.read_one!(authorize?: false)

    assert old_address_notice.destination == registration_request.email
    assert old_address_notice.dispatch_disposition == :held

    evidence =
      NewYou.Audit.EvidenceObligation
      |> Ash.Query.filter(source_operation_id == ^operation_id)
      |> Ash.read!(authorize?: false)

    assert Enum.map(evidence, & &1.evidence_type) |> Enum.sort() == [
             :identity_primary_email_change_applied,
             :identity_primary_email_change_confirmed,
             :identity_primary_email_change_requested
           ]

    assert Enum.all?(evidence, fn event ->
             event.actor_id == registration.account_id and
               event.target_id == registration.account_id and event.outcome == :succeeded and
               is_nil(event.session_id) and is_nil(event.case_id) and is_nil(event.reason_code)
           end)

    refute :binary.match(:erlang.term_to_binary(evidence), registration_request.email) != :nomatch
    refute :binary.match(:erlang.term_to_binary(evidence), target_request.email) != :nomatch
    refute :binary.match(:erlang.term_to_binary(evidence), proof) != :nomatch
    assert Identity.apply_primary_email_change(operation_id) == {:ok, :already_applied}
  end

  def scenario_a_confirmed_change_resumes_and_applies_after_a_fresh_beam_restart() do
    with_apply_policy(%{delay_seconds: 0, requires_review?: false}, fn ->
      P805.with_fixture(fn ->
        registration_request = P805.request()
        target_request = P805.request()
        operation_id = tracked_operation()
        {:ok, registration} = Identity.register(registration_request)
        {:ok, :verified} = Identity.verify_email(registration.verification_proof)

        {:ok, credentials} =
          Identity.authenticate_password(
            registration_request.email,
            registration_request.password
          )

        assert {:ok, :requested} =
                 Identity.request_primary_email_change(
                   credentials,
                   target_request.email,
                   "en",
                   operation_id
                 )

        assert {:ok, :proof_pending} =
                 Identity.reauthenticate_primary_email_change(
                   credentials,
                   registration_request.password,
                   operation_id
                 )

        account = current_account(registration.account_id)
        proof = current_confirmation_proof(account, target_request.email)

        assert current_account(registration.account_id).primary_email_change_state ==
                 :new_address_pending

        signing_secret =
          Application.fetch_env!(:new_you, :identity_token_signing_secret) |> Base.encode64()

        assert :applied ==
                 restart_primary_email_change(%{
                   proof: proof,
                   operation_id: operation_id,
                   signing_secret: signing_secret
                 })

        applied = current_account(registration.account_id)
        assert applied.email == target_request.email
        assert applied.primary_email_change_state == :applied
        assert Ash.get!(Session, credentials.session_id, authorize?: false).state == :revoked

        notices =
          MessageIntent
          |> Ash.Query.filter(
            source_operation_id == ^operation_id and role == :email_change_old_address_notice
          )
          |> Ash.read!(authorize?: false)

        assert length(notices) == 1
        assert hd(notices).dispatch_disposition == :held
      end)
    end)
  end

  def scenario_primary_email_apply_and_recovery_completion_serialize_in_both_postgresql_commit_orders() do
    assert apply_recovery_race(:recovery_first) == :ok
    assert apply_recovery_race(:email_change_first) == :ok
  end

  def scenario_proof_only_protected_mutation_denies_when_current_privacy_authority_is_missing() do
    with_test_privacy_proof(fn ->
      with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
        assert {:ok, :missing} =
                 NewYou.Privacy.current_p817_proof_purpose(
                   fixture.registration.account_id,
                   fixture.operation_id
                 )

        assert_apply_denied(fixture)
      end)
    end)
  end

  def scenario_committed_privacy_withdrawal_wins_before_identity_s_current_mutation_check() do
    with_test_privacy_proof(fn ->
      with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
        assert {:ok, :allowed} =
                 NewYou.Privacy.grant_p817_proof_purpose(
                   fixture.registration.account_id,
                   fixture.operation_id
                 )

        assert {:ok, :allowed} =
                 NewYou.Privacy.current_p817_proof_purpose(
                   fixture.registration.account_id,
                   fixture.operation_id
                 )

        parent = self()
        reference = make_ref()
        scenario = Scenario.start()

        try do
          {worker, worker_monitor} =
            Scenario.spawn(scenario, :privacy_withdrawal_before_apply, fn ->
              :ok = Sandbox.checkout(Repo, sandbox: false)

              Process.put(
                NewYou.Proof.P817PrivacySeam,
                {:pause, parent, reference, :before_current_read}
              )

              try do
                result = Identity.apply_primary_email_change(fixture.operation_id)
                send(parent, {reference, :p817_apply_result, result})
              after
                :ok = Sandbox.checkin(Repo)
              end
            end)

          {apply_backend, apply_transaction} =
            await_p817_privacy_checkpoint(reference, :before_current_read)

          withdrawal_backend =
            Repo.query!("SELECT pg_backend_pid()") |> Map.fetch!(:rows) |> hd() |> hd()

          assert apply_backend != withdrawal_backend

          assert {:ok, :withdrawn} =
                   NewYou.Privacy.withdraw_p817_proof_purpose(
                     fixture.registration.account_id,
                     fixture.operation_id
                   )

          assert {:ok, :withdrawn} =
                   NewYou.Privacy.current_p817_proof_purpose(
                     fixture.registration.account_id,
                     fixture.operation_id
                   )

          send(worker, {reference, :release})

          assert await_result(reference, :p817_apply_result) ==
                   {:error, :primary_email_change_unavailable}

          await_normal(worker_monitor)
          assert_no_apply_consequences(fixture)

          assert {:error, :primary_email_change_unavailable} =
                   Identity.apply_primary_email_change(fixture.operation_id)

          assert {:ok, :withdrawn} =
                   NewYou.Privacy.current_p817_proof_purpose(
                     fixture.registration.account_id,
                     fixture.operation_id
                   )

          assert apply_transaction != ""
        after
          :ok = Scenario.stop(scenario)
        end
      end)
    end)
  end

  def scenario_identity_mutation_committed_first_serializes_before_privacy_withdrawal() do
    with_test_privacy_proof(fn ->
      with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
        assert {:ok, :allowed} =
                 NewYou.Privacy.grant_p817_proof_purpose(
                   fixture.registration.account_id,
                   fixture.operation_id
                 )

        parent = self()
        reference = make_ref()
        scenario = Scenario.start()

        try do
          {apply_worker, apply_monitor} =
            Scenario.spawn(scenario, :identity_mutation_first, fn ->
              :ok = Sandbox.checkout(Repo, sandbox: false)

              Process.put(
                NewYou.Proof.P817PrivacySeam,
                {:pause, parent, reference, :after_current_read}
              )

              try do
                result = Identity.apply_primary_email_change(fixture.operation_id)
                send(parent, {reference, :p817_apply_first_result, result})
              after
                :ok = Sandbox.checkin(Repo)
              end
            end)

          {apply_backend, _apply_transaction} =
            await_p817_privacy_checkpoint(reference, :after_current_read)

          {_withdraw_worker, withdraw_monitor} =
            Scenario.spawn(scenario, :privacy_withdrawal_second, fn ->
              :ok = Sandbox.checkout(Repo, sandbox: false)

              try do
                backend = Repo.query!("SELECT pg_backend_pid()").rows |> hd() |> hd()
                send(parent, {reference, :p817_withdraw_backend, backend})

                result =
                  NewYou.Privacy.withdraw_p817_proof_purpose(
                    fixture.registration.account_id,
                    fixture.operation_id
                  )

                send(parent, {reference, :p817_withdraw_result, result})
              after
                :ok = Sandbox.checkin(Repo)
              end
            end)

          withdraw_backend = receive_backend(reference, :p817_withdraw_backend)
          assert_contention(withdraw_backend, apply_backend)
          send(apply_worker, {reference, :release})
          assert await_result(reference, :p817_apply_first_result) == {:ok, :applied}
          assert await_result(reference, :p817_withdraw_result) == {:ok, :withdrawn}
          await_normal(apply_monitor)
          await_normal(withdraw_monitor)
          account = current_account(fixture.registration.account_id)
          assert account.email == fixture.target_request.email
          assert account.primary_email_change_state == :applied

          assert {:ok, :withdrawn} ==
                   NewYou.Privacy.current_p817_proof_purpose(
                     fixture.registration.account_id,
                     fixture.operation_id
                   )

          assert Identity.apply_primary_email_change(fixture.operation_id) ==
                   {:ok, :already_applied}
        after
          :ok = Scenario.stop(scenario)
        end
      end)
    end)
  end

  def scenario_withdrawn_privacy_authority_remains_denied_after_a_fresh_beam_restart() do
    with_test_privacy_proof(fn ->
      with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
        assert {:ok, :allowed} =
                 NewYou.Privacy.grant_p817_proof_purpose(
                   fixture.registration.account_id,
                   fixture.operation_id
                 )

        assert {:ok, :withdrawn} =
                 NewYou.Privacy.withdraw_p817_proof_purpose(
                   fixture.registration.account_id,
                   fixture.operation_id
                 )

        signing_secret =
          Application.fetch_env!(:new_you, :identity_token_signing_secret) |> Base.encode64()

        assert :denied ==
                 restart_p817_privacy_retry(%{
                   operation_id: fixture.operation_id,
                   signing_secret: signing_secret
                 })

        assert_no_apply_consequences(fixture)

        assert {:ok, :withdrawn} =
                 NewYou.Privacy.current_p817_proof_purpose(
                   fixture.registration.account_id,
                   fixture.operation_id
                 )
      end)
    end)
  end

  def scenario_identity_fails_closed_when_its_current_privacy_read_is_unavailable() do
    with_test_privacy_proof(fn ->
      with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
        assert {:ok, :allowed} =
                 NewYou.Privacy.grant_p817_proof_purpose(
                   fixture.registration.account_id,
                   fixture.operation_id
                 )

        Process.put(NewYou.Proof.P817PrivacySeam, {:fail, :owner_read})

        try do
          assert_apply_denied(fixture)
        after
          Process.delete(NewYou.Proof.P817PrivacySeam)
        end
      end)
    end)
  end

  def scenario_cancellation_revokes_the_proof_and_leaves_the_canonical_address_unchanged() do
    P805.with_fixture(fn ->
      registration_request = P805.request()
      target_request = P805.request()
      operation_id = tracked_operation()
      {:ok, registration} = Identity.register(registration_request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      {:ok, credentials} =
        Identity.authenticate_password(registration_request.email, registration_request.password)

      assert {:ok, :requested} =
               Identity.request_primary_email_change(
                 credentials,
                 target_request.email,
                 "en",
                 operation_id
               )

      assert {:ok, :proof_pending} =
               Identity.reauthenticate_primary_email_change(
                 credentials,
                 registration_request.password,
                 operation_id
               )

      account = current_account(registration.account_id)

      {:ok, {:ok, proof}} =
        Repo.transaction(fn ->
          Identity.primary_email_change_delivery(
            account.primary_email_change_token_jti,
            target_request.email,
            "en"
          )
        end)

      assert {:ok, :cancelled} = Identity.cancel_primary_email_change(credentials, operation_id)

      assert {:ok, :already_cancelled} =
               Identity.cancel_primary_email_change(credentials, operation_id)

      assert {:error, :primary_email_change_unavailable} =
               Identity.confirm_primary_email_change(proof)

      assert {:error, :primary_email_change_unavailable} =
               Identity.apply_primary_email_change(operation_id)

      cancelled = current_account(registration.account_id)
      assert cancelled.email == registration_request.email
      assert cancelled.primary_email_change_state == :cancelled

      assert Ash.get!(Token, account.primary_email_change_token_jti, authorize?: false).purpose ==
               "email_change_confirmation_revoked"
    end)
  end

  def scenario_a_newer_accepted_operation_supersedes_the_old_proof_and_remains_the_only_current_operation() do
    P805.with_fixture(fn ->
      registration_request = P805.request()
      first_target = P805.request()
      second_target = P805.request()
      first_operation = tracked_operation()
      second_operation = tracked_operation()
      {:ok, registration} = Identity.register(registration_request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      {:ok, credentials} =
        Identity.authenticate_password(registration_request.email, registration_request.password)

      assert {:ok, :requested} =
               Identity.request_primary_email_change(
                 credentials,
                 first_target.email,
                 "en",
                 first_operation
               )

      assert {:ok, :proof_pending} =
               Identity.reauthenticate_primary_email_change(
                 credentials,
                 registration_request.password,
                 first_operation
               )

      first_account = current_account(registration.account_id)

      {:ok, {:ok, first_proof}} =
        Repo.transaction(fn ->
          Identity.primary_email_change_delivery(
            first_account.primary_email_change_token_jti,
            first_target.email,
            "en"
          )
        end)

      assert {:ok, :requested} =
               Identity.request_primary_email_change(
                 credentials,
                 second_target.email,
                 "af",
                 second_operation
               )

      assert {:ok, :proof_pending} =
               Identity.reauthenticate_primary_email_change(
                 credentials,
                 registration_request.password,
                 second_operation
               )

      assert {:error, :primary_email_change_unavailable} =
               Identity.confirm_primary_email_change(first_proof)

      assert {:error, :primary_email_change_unavailable} =
               Identity.apply_primary_email_change(first_operation)

      current = current_account(registration.account_id)
      assert current.email == registration_request.email
      assert current.primary_email_change_operation_id == second_operation
      assert current.primary_email_change_state == :new_address_pending
      assert current.primary_email_change_target == second_target.email

      assert Ash.get!(Token, first_account.primary_email_change_token_jti, authorize?: false).purpose ==
               "email_change_confirmation_superseded"

      current_proofs =
        Token
        |> Ash.Query.filter(
          account_id == ^registration.account_id and purpose == "email_change_confirmation"
        )
        |> Ash.read!(authorize?: false)

      assert length(current_proofs) == 1
      assert hd(current_proofs).email_change_operation_id == second_operation
    end)
  end

  def scenario_expiry_terminalizes_the_durable_operation_and_revokes_its_proof() do
    P805.with_fixture(fn ->
      registration_request = P805.request()
      target_request = P805.request()
      operation_id = tracked_operation()
      {:ok, registration} = Identity.register(registration_request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      {:ok, credentials} =
        Identity.authenticate_password(registration_request.email, registration_request.password)

      assert {:ok, :requested} =
               Identity.request_primary_email_change(
                 credentials,
                 target_request.email,
                 "en",
                 operation_id
               )

      assert {:ok, :proof_pending} =
               Identity.reauthenticate_primary_email_change(
                 credentials,
                 registration_request.password,
                 operation_id
               )

      account = current_account(registration.account_id)

      {:ok, {:ok, proof}} =
        Repo.transaction(fn ->
          Identity.primary_email_change_delivery(
            account.primary_email_change_token_jti,
            target_request.email,
            "en"
          )
        end)

      Repo.query!(
        "UPDATE accounts SET primary_email_change_expires_at = now() - interval '1 second' WHERE id = $1",
        [Ecto.UUID.dump!(registration.account_id)]
      )

      assert {:ok, :expired} = Identity.expire_primary_email_change(operation_id)
      assert {:ok, :already_expired} = Identity.expire_primary_email_change(operation_id)

      assert {:error, :primary_email_change_unavailable} =
               Identity.confirm_primary_email_change(proof)

      assert {:error, :primary_email_change_unavailable} =
               Identity.apply_primary_email_change(operation_id)

      expired = current_account(registration.account_id)
      assert expired.email == registration_request.email
      assert expired.primary_email_change_state == :expired

      assert Ash.get!(Token, account.primary_email_change_token_jti, authorize?: false).purpose ==
               "email_change_confirmation_revoked"
    end)
  end

  def scenario_a_current_security_hold_terminalizes_the_change_without_applying_its_target() do
    with_apply_policy(%{delay_seconds: 0, requires_review?: false}, fn ->
      P805.with_fixture(fn ->
        scenario_a_current_security_hold_terminalizes_the_change_without_applying_its_target_fixture()
      end)
    end)
  end

  defp scenario_a_current_security_hold_terminalizes_the_change_without_applying_its_target_fixture() do
    registration_request = P805.request()
    target_request = P805.request()
    operation_id = tracked_operation()
    {:ok, registration} = Identity.register(registration_request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)

    {:ok, credentials} =
      Identity.authenticate_password(
        registration_request.email,
        registration_request.password
      )

    assert {:ok, :requested} =
             Identity.request_primary_email_change(
               credentials,
               target_request.email,
               "en",
               operation_id
             )

    assert {:ok, :proof_pending} =
             Identity.reauthenticate_primary_email_change(
               credentials,
               registration_request.password,
               operation_id
             )

    account = current_account(registration.account_id)

    {:ok, {:ok, proof}} =
      Repo.transaction(fn ->
        Identity.primary_email_change_delivery(
          account.primary_email_change_token_jti,
          target_request.email,
          "en"
        )
      end)

    assert {:ok, :confirmed} = Identity.confirm_primary_email_change(proof)

    current_account(registration.account_id)
    |> Ash.update!(%{}, action: :hold_for_recovery, authorize?: false)

    assert {:ok, :held} = Identity.apply_primary_email_change(operation_id)
    assert {:ok, :already_held} = Identity.apply_primary_email_change(operation_id)
    held = current_account(registration.account_id)
    assert held.email == registration_request.email
    assert held.primary_email_change_state == :held
    assert held.security_posture == :held
  end

  def with_confirmed_email_change(policy, fun) do
    with_confirmed_email_change(policy, [], fun)
  end

  def with_confirmed_email_change(policy, options, fun) do
    with_apply_policy(policy, fn ->
      P805.with_fixture(fn ->
        registration_request = P805.request()
        target_request = P805.request()
        operation_id = Ecto.UUID.generate()
        P805.track_operation(operation_id)
        {:ok, registration} = Identity.register(registration_request)
        {:ok, :verified} = Identity.verify_email(registration.verification_proof)

        {:ok, credentials} =
          Identity.authenticate_password(
            registration_request.email,
            registration_request.password
          )

        {:ok, other_credentials} =
          Identity.authenticate_password(
            registration_request.email,
            registration_request.password
          )

        mfa_secret = maybe_activate_mfa(options, credentials, registration_request.password)
        device_id = Ecto.UUID.generate()

        Repo.query!(
          "INSERT INTO device_assurances (id,account_id,fingerprint,state,security_version,expires_at) VALUES ($1,$2,$3,'trusted',1,now()+interval '1 day')",
          [
            Ecto.UUID.dump!(device_id),
            Ecto.UUID.dump!(registration.account_id),
            :crypto.strong_rand_bytes(32)
          ]
        )

        assert {:ok, :requested} =
                 Identity.request_primary_email_change(
                   credentials,
                   target_request.email,
                   "en",
                   operation_id
                 )

        assert {:ok, :proof_pending} =
                 Identity.reauthenticate_primary_email_change(
                   credentials,
                   registration_request.password,
                   operation_id
                 )

        account = current_account(registration.account_id)
        proof = current_confirmation_proof(account, target_request.email)
        assert {:ok, :confirmed} = Identity.confirm_primary_email_change(proof)
        account = current_account(registration.account_id)

        fun.(%{
          registration_request: registration_request,
          target_request: target_request,
          registration: registration,
          operation_id: operation_id,
          credentials: credentials,
          other_credentials: other_credentials,
          proof_jti: account.primary_email_change_token_jti,
          confirmation_id: account.primary_email_change_confirmation_id,
          mfa_secret: mfa_secret,
          device_id: device_id
        })
      end)
    end)
  end

  def activate_mfa_and_step_up(credentials, password) do
    {:ok, %{secret: secret}} = Identity.enroll_privileged_mfa(credentials, password)
    period = div(System.os_time(:second), 30)
    previous = Process.put(NewYou.Proof.PrivilegedAccessSeam, period * 30)

    try do
      assert {:ok, :ok} =
               Identity.confirm_privileged_mfa(
                 credentials,
                 password,
                 NimbleTOTP.verification_code(secret, time: period * 30)
               )

      next_period = period + 1
      Process.put(NewYou.Proof.PrivilegedAccessSeam, next_period * 30)

      assert {:ok, :ok} =
               Identity.step_up_privileged(
                 credentials,
                 password,
                 NimbleTOTP.verification_code(secret, time: next_period * 30),
                 :change_primary_email
               )

      secret
    after
      if is_nil(previous) do
        Process.delete(NewYou.Proof.PrivilegedAccessSeam)
      else
        Process.put(NewYou.Proof.PrivilegedAccessSeam, previous)
      end
    end
  end

  def maybe_activate_mfa(options, credentials, password) do
    if Keyword.get(options, :active_mfa?, false) do
      activate_mfa_and_step_up(credentials, password)
    end
  end

  def current_confirmation_proof(account, destination) do
    {:ok, {:ok, proof}} =
      Repo.transaction(fn ->
        Identity.primary_email_change_delivery(
          account.primary_email_change_token_jti,
          destination,
          "en"
        )
      end)

    proof
  end

  def assert_no_apply_consequences(fixture) do
    account = current_account(fixture.registration.account_id)
    assert account.email == fixture.registration_request.email
    assert account.primary_email_change_state == :delayed
    assert account.primary_email_change_confirmation_id == fixture.confirmation_id

    assert Ash.get!(Token, fixture.proof_jti, authorize?: false).purpose ==
             "email_change_confirmation_consumed"

    refute NewYou.Audit.EvidenceObligation
           |> Ash.Query.filter(
             source_operation_id == ^fixture.operation_id and
               evidence_type == :identity_primary_email_change_applied
           )
           |> Ash.exists?(authorize?: false)

    assert [] ==
             MessageIntent
             |> Ash.Query.filter(
               source_operation_id == ^fixture.operation_id and
                 role == :email_change_old_address_notice
             )
             |> Ash.read!(authorize?: false)

    assert Ash.get!(Session, fixture.other_credentials.session_id, authorize?: false).state ==
             :active

    other_session = Ash.get!(Session, fixture.other_credentials.session_id, authorize?: false)
    assert Ash.get!(Token, other_session.token_jti, authorize?: false).purpose == "user"
    assert Ash.get!(DeviceAssurance, fixture.device_id, authorize?: false).state == :trusted
  end

  def assert_apply_denied(fixture) do
    assert {:error, :primary_email_change_unavailable} =
             Identity.apply_primary_email_change(fixture.operation_id)

    assert_no_apply_consequences(fixture)
  end

  def with_apply_policy(policy, fun) do
    previous = Application.get_env(:new_you, :p8_16_primary_email_change_policy)
    Application.put_env(:new_you, :p8_16_primary_email_change_policy, policy)

    try do
      fun.()
    after
      if is_nil(previous) do
        Application.delete_env(:new_you, :p8_16_primary_email_change_policy)
      else
        Application.put_env(:new_you, :p8_16_primary_email_change_policy, previous)
      end
    end
  end

  def with_test_privacy_proof(fun) do
    previous = Application.get_env(:new_you, :p8_17_test_proof_purpose?)
    Application.put_env(:new_you, :p8_17_test_proof_purpose?, true)

    try do
      fun.()
    after
      if is_nil(previous) do
        Application.delete_env(:new_you, :p8_17_test_proof_purpose?)
      else
        Application.put_env(:new_you, :p8_17_test_proof_purpose?, previous)
      end
    end
  end

  def apply_recovery_race(order) do
    with_apply_policy(%{delay_seconds: 0, requires_review?: false}, fn ->
      P805.with_fixture(fn -> execute_recovery_race(order) end)
    end)
  end

  def assert_logout_apply_race(order) do
    with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
      execute_logout_apply_race(order, fixture)
    end)
  end

  def execute_logout_apply_race(:apply_first, fixture) do
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()

    try do
      {apply_worker, apply_monitor} =
        spawn_paused_race_worker(
          scenario,
          :primary_email_apply,
          parent,
          reference,
          :apply_result,
          fn -> Identity.apply_primary_email_change(fixture.operation_id) end
        )

      apply_backend = await_checkpoint(reference)

      {_logout_worker, logout_monitor} =
        spawn_contending_race_worker(
          scenario,
          parent,
          reference,
          :logout_result,
          fn -> Identity.logout(fixture.credentials) end
        )

      logout_backend = receive_backend(reference, :second_backend)
      assert_contention(logout_backend, apply_backend)
      send(apply_worker, {reference, :release})
      assert await_result(reference, :apply_result) == {:ok, :applied}
      assert await_result(reference, :logout_result) == {:error, :authentication_unavailable}
      await_normal(apply_monitor)
      await_normal(logout_monitor)
      account = current_account(fixture.registration.account_id)
      assert account.email == fixture.target_request.email
      assert account.primary_email_change_state == :applied

      assert Ash.get!(Session, fixture.credentials.session_id, authorize?: false).state ==
               :revoked
    after
      :ok = Scenario.stop(scenario)
    end
  end

  def execute_logout_apply_race(:logout_first, fixture) do
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()

    try do
      {logout_worker, logout_monitor} =
        Scenario.spawn(scenario, :logout_transaction, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          try do
            result =
              Repo.transaction(fn ->
                session = Ash.get!(Session, fixture.credentials.session_id, authorize?: false)

                {:ok, _logged_out, notifications} =
                  Ash.update(session, %{},
                    action: :logout,
                    authorize?: false,
                    return_notifications?: true
                  )

                send(parent, {reference, :first_backend, P805.scalar("SELECT pg_backend_pid()")})

                receive do
                  {^reference, :release_logout} -> :ok
                after
                  15000 -> raise "logout transaction release deadline"
                end

                notifications
              end)

            case result do
              {:ok, notifications} ->
                Ash.Notifier.notify(notifications)
                send(parent, {reference, :logout_result, {:ok, :ok}})

              error ->
                send(parent, {reference, :logout_result, error})
            end
          after
            Sandbox.checkin(Repo)
          end
        end)

      logout_backend = receive_backend(reference, :first_backend)

      {_apply_worker, apply_monitor} =
        spawn_contending_race_worker(
          scenario,
          parent,
          reference,
          :apply_result,
          fn -> Identity.apply_primary_email_change(fixture.operation_id) end
        )

      apply_backend = receive_backend(reference, :second_backend)
      assert_contention(apply_backend, logout_backend)
      send(logout_worker, {reference, :release_logout})
      assert await_result(reference, :logout_result) == {:ok, :ok}
      assert await_result(reference, :apply_result) == {:error, :primary_email_change_unavailable}
      await_normal(logout_monitor)
      await_normal(apply_monitor)

      assert Ash.get!(Session, fixture.credentials.session_id, authorize?: false).state ==
               :logged_out

      assert_apply_denied_after_logout(fixture)
    after
      :ok = Scenario.stop(scenario)
    end
  end

  def assert_apply_denied_after_logout(fixture) do
    account = current_account(fixture.registration.account_id)
    assert account.email == fixture.registration_request.email
    assert account.primary_email_change_state == :delayed
    assert account.primary_email_change_confirmation_id == fixture.confirmation_id

    refute NewYou.Audit.EvidenceObligation
           |> Ash.Query.filter(
             source_operation_id == ^fixture.operation_id and
               evidence_type == :identity_primary_email_change_applied
           )
           |> Ash.exists?(authorize?: false)

    assert [] ==
             MessageIntent
             |> Ash.Query.filter(
               source_operation_id == ^fixture.operation_id and
                 role == :email_change_old_address_notice
             )
             |> Ash.read!(authorize?: false)

    assert Ash.get!(Session, fixture.other_credentials.session_id, authorize?: false).state ==
             :active

    assert Ash.get!(DeviceAssurance, fixture.device_id, authorize?: false).state == :trusted
  end

  def execute_recovery_race(order) do
    registration_request = P805.request()
    target_request = P805.request()
    change_operation = tracked_operation()
    {:ok, registration} = Identity.register(registration_request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)

    {:ok, credentials} =
      Identity.authenticate_password(
        registration_request.email,
        registration_request.password
      )

    assert {:ok, :requested} =
             Identity.request_primary_email_change(
               credentials,
               target_request.email,
               "en",
               change_operation
             )

    assert {:ok, :proof_pending} =
             Identity.reauthenticate_primary_email_change(
               credentials,
               registration_request.password,
               change_operation
             )

    account = current_account(registration.account_id)

    {:ok, {:ok, email_proof}} =
      Ash.transact([Account, Token], fn ->
        Identity.primary_email_change_delivery(
          account.primary_email_change_token_jti,
          target_request.email,
          "en"
        )
      end)

    assert {:ok, :confirmed} = Identity.confirm_primary_email_change(email_proof)
    recovery_request_id = tracked_operation()
    acceptance_id = tracked_operation()
    completion_id = tracked_operation()
    :ok = Identity.request_recovery(registration_request.email, "en", recovery_request_id)

    [recovery] =
      RecoveryCase
      |> Ash.Query.filter(account_id == ^registration.account_id)
      |> Ash.read!(authorize?: false)

    {:ok, {:ok, recovery_proof}} =
      Ash.transact([Account, Token], fn ->
        Identity.recovery_delivery(recovery.proof_jti, registration_request.email, "en")
      end)

    assert {:ok, :accepted} = Identity.submit_recovery_proof(recovery_proof, acceptance_id)

    context = %{
      account: account,
      change_operation: change_operation,
      completion_id: completion_id,
      recovery: recovery,
      recovery_proof: recovery_proof,
      registration: registration,
      registration_request: registration_request,
      target_request: target_request
    }

    execute_competing_identity_writes(order, context)
  end

  def execute_competing_identity_writes(order, context) do
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()
    {first_action, second_action, first_expected, second_expected} = race_actions(order, context)

    try do
      {first_worker, first_monitor} =
        spawn_paused_race_worker(
          scenario,
          :first_identity_write,
          parent,
          reference,
          :first_result,
          first_action
        )

      first_backend = await_checkpoint(reference)

      {_second_worker, second_monitor} =
        spawn_contending_race_worker(
          scenario,
          parent,
          reference,
          :second_result,
          second_action
        )

      second_backend = receive_backend(reference, :second_backend)
      assert_contention(second_backend, first_backend)
      send(first_worker, {reference, :release})
      assert await_result(reference, :first_result) == first_expected
      assert await_result(reference, :second_result) == second_expected
      await_normal(first_monitor)
      await_normal(second_monitor)
      assert_race_winner(order, context)
      :ok
    after
      :ok = Scenario.stop(scenario)
    end
  end

  def race_actions(:recovery_first, context) do
    {fn ->
       Identity.complete_recovery(
         context.recovery_proof,
         "recovered race password",
         context.completion_id
       )
     end, fn -> Identity.apply_primary_email_change(context.change_operation) end,
     {:ok, :completed}, {:error, :primary_email_change_unavailable}}
  end

  def race_actions(:email_change_first, context) do
    {fn -> Identity.apply_primary_email_change(context.change_operation) end,
     fn ->
       Identity.complete_recovery(
         context.recovery_proof,
         "stale recovery race password",
         context.completion_id
       )
     end, {:ok, :applied}, {:ok, :failed}}
  end

  def spawn_paused_race_worker(scenario, label, parent, reference, result_key, action) do
    Scenario.spawn(scenario, label, fn ->
      :ok = Sandbox.checkout(Repo, sandbox: false)
      Process.put(RegistrationSeam, {:pause, parent, reference})

      try do
        send(parent, {reference, result_key, action.()})
      after
        Sandbox.checkin(Repo)
      end
    end)
  end

  def spawn_contending_race_worker(scenario, parent, reference, result_key, action) do
    Scenario.spawn(scenario, :competing_identity_write, fn ->
      :ok = Sandbox.checkout(Repo, sandbox: false)

      try do
        send(parent, {reference, :second_backend, P805.scalar("SELECT pg_backend_pid()")})
        send(parent, {reference, result_key, action.()})
      after
        Sandbox.checkin(Repo)
      end
    end)
  end

  def assert_race_winner(:recovery_first, context) do
    final_account = current_account(context.registration.account_id)
    final_recovery = Ash.get!(RecoveryCase, context.recovery.id, authorize?: false)
    assert final_account.email == context.registration_request.email
    assert final_account.credential_version == context.account.credential_version + 1
    assert final_recovery.state == :completed
  end

  def assert_race_winner(:email_change_first, context) do
    final_account = current_account(context.registration.account_id)
    final_recovery = Ash.get!(RecoveryCase, context.recovery.id, authorize?: false)
    assert final_account.email == context.target_request.email
    assert final_account.credential_version == context.account.credential_version
    assert final_recovery.state == :failed
  end

  def restart_primary_email_change(fields) do
    payload = Jason.encode!(fields)
    executable = System.find_executable("mix") || raise "mix unavailable"

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        args: ["run", "test/proof/p8_16_restart.exs"],
        env: [{~c"MIX_ENV", ~c"test"}, {~c"ERL_FLAGS", ~c"+S 2:2"}]
      ])

    true = Port.command(port, payload <> "\n")
    read_restart_result(port, "", System.monotonic_time(:millisecond) + 30000)
  end

  def restart_p817_privacy_retry(fields) do
    payload = Jason.encode!(fields)
    executable = System.find_executable("mix") || raise "mix unavailable"

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        args: ["run", "test/proof/p8_17_privacy_restart.exs"],
        env: [{~c"MIX_ENV", ~c"test"}, {~c"ERL_FLAGS", ~c"+S 2:2"}]
      ])

    true = Port.command(port, payload <> "\n")
    read_p817_restart_result(port, "", System.monotonic_time(:millisecond) + 30000)
  end

  def read_p817_restart_result(port, output, deadline) do
    receive do
      {^port, {:data, bytes}} when byte_size(output) + byte_size(bytes) < 8192 ->
        read_p817_restart_result(port, output <> bytes, deadline)

      {^port, {:exit_status, 0}} ->
        if String.contains?(output, "P817_RESTART_DENIED") do
          :denied
        else
          :error
        end

      {^port, {:exit_status, _}} ->
        :error
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        Port.close(port)
        :error
    end
  end

  def read_restart_result(port, output, deadline) do
    receive do
      {^port, {:data, bytes}} when byte_size(output) + byte_size(bytes) < 8192 ->
        read_restart_result(port, output <> bytes, deadline)

      {^port, {:exit_status, 0}} ->
        if String.contains?(output, "P816_APPLIED") do
          :applied
        else
          :error
        end

      {^port, {:exit_status, _}} ->
        :error
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        Port.close(port)
        :error
    end
  end

  def tracked_operation do
    id = Ecto.UUID.generate()
    P805.track_operation(id)
    id
  end

  def await_checkpoint(reference) do
    receive do
      {^reference, :before_commit, _worker, backend, _transaction} -> backend
    after
      15000 -> raise "primary-email/recovery commit checkpoint deadline"
    end
  end

  def await_checkpoints(reference, workers) do
    workers = MapSet.new(workers)

    Enum.reduce(1..MapSet.size(workers), %{}, fn _, checkpoints ->
      receive do
        {^reference, :before_commit, worker, backend, _transaction} ->
          if MapSet.member?(workers, worker) do
            Map.put(checkpoints, worker, backend)
          else
            raise "unexpected primary-email target checkpoint worker"
          end
      after
        15000 -> raise "primary-email target claim checkpoint deadline"
      end
    end)
  end

  def receive_backend(reference, key) do
    receive do
      {^reference, ^key, backend} -> backend
    after
      15000 -> raise "primary-email/recovery contender connection deadline"
    end
  end

  def assert_contention(contender, owner) do
    deadline = System.monotonic_time(:millisecond) + 15000
    wait_contention(contender, owner, deadline)
  end

  def wait_contention(contender, owner, deadline) do
    rows =
      Repo.query!(
        "SELECT a.virtualtransaction, b.virtualtransaction FROM pg_locks a JOIN pg_locks b ON b.pid = $1 AND b.locktype = 'virtualxid' WHERE a.pid = $2 AND a.locktype = 'virtualxid' AND $2 = ANY(pg_blocking_pids($1))",
        [contender, owner]
      ).rows

    case rows do
      [[contender_transaction, owner_transaction]] when contender != owner ->
        assert contender_transaction != owner_transaction

      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          wait_contention(contender, owner, deadline)
        else
          raise "primary-email/recovery PostgreSQL lock contention was not observed"
        end
    end
  end

  def await_result(reference, name) do
    receive do
      {^reference, ^name, result} -> result
    after
      15000 -> raise "primary-email/recovery worker result deadline"
    end
  end

  def await_p817_privacy_checkpoint(reference, point) do
    receive do
      {^reference, :p817_privacy_checkpoint, _worker, backend, transaction, ^point} ->
        {backend, transaction}
    after
      15000 -> raise "P8-17 Privacy current-read checkpoint deadline"
    end
  end

  def await_normal(monitor) do
    receive do
      {:DOWN, ^monitor, :process, _worker, :normal} -> :ok
    after
      15000 -> raise "primary-email/recovery worker cleanup deadline"
    end
  end

  def current_account(id) do
    Ash.get!(Account, id, authorize?: false)
  end
end
