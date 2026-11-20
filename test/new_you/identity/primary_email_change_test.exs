defmodule NewYou.Identity.PrimaryEmailChangeTest do
  use ExUnit.Case, async: false
  import NewYou.Proof.EmailChangeScenarios
  import Phoenix.ConnTest
  import Plug.Conn
  import ExUnit.CaptureLog
  alias Ecto.Adapters.SQL.Sandbox

  require Ash.Query

  alias NewYou.{Identity, Repo}
  alias NewYou.Identity.{Account, Session, Token}
  alias NewYou.Communications.MessageIntent
  alias NewYou.Proof.{P805, RegistrationSeam, Scenario}

  @endpoint NewYouWeb.Endpoint

  test "a real Support hold terminalizes the confirmed Phase-9 operation before revoked-session retries" do
    NewYou.Proof.P813HoldFixture.with_fixture(fn fixture ->
      alias NewYou.Proof.P813HoldFixture
      target = fixture.target
      before = P805.account!(target.id)
      replacement = P805.request().email
      id = tracked_operation()

      assert {:ok, :requested} =
               Identity.request_primary_email_change(
                 target.credentials,
                 replacement,
                 {"en", :well156},
                 id
               )

      assert {:ok, :proof_pending} =
               Identity.reauthenticate_primary_email_change(
                 target.credentials,
                 target.password,
                 id
               )

      pending = P805.account!(target.id)

      assert {:ok, {:ok, proof}} =
               Repo.transaction(fn ->
                 Identity.primary_email_change_delivery(
                   pending.primary_email_change_token_jti,
                   replacement,
                   "en"
                 )
               end)

      assert {:ok, :confirmed} = Identity.confirm_phase9_primary_email_change(proof, "en")

      assert {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :place_security_hold)
      hold = P813HoldFixture.request(fixture, :place, 0)
      assert {:ok, %{status: :held}} = Identity.place_security_hold(hold)
      assert {:ok, %{status: :held}} = Identity.place_security_hold(hold)
      assert Ash.get!(Session, target.credentials.session_id, authorize?: false).state == :revoked

      for _ <- 1..2 do
        assert {:error, :primary_email_change_unavailable} =
                 Identity.apply_authenticated_primary_email_change(target.credentials, id)
      end

      held = P805.account!(target.id)
      assert held.primary_email_change_state == :held
      assert held.email == before.email
      assert held.email_verified? == before.email_verified?

      assert Ash.get!(Token, pending.primary_email_change_token_jti, authorize?: false).purpose ==
               "email_change_confirmation_revoked"

      assert {:ok, :already_held} = Identity.apply_primary_email_change(id)

      evidence =
        NewYou.Audit.EvidenceObligation
        |> Ash.Query.filter(source_operation_id == ^id)
        |> Ash.read!(authorize?: false)
        |> Enum.frequencies_by(& &1.evidence_type)

      assert evidence[:identity_primary_email_change_held] == 1
      refute Map.has_key?(evidence, :identity_primary_email_change_applied)

      refute MessageIntent
             |> Ash.Query.filter(
               source_operation_id == ^id and role == :email_change_old_address_notice
             )
             |> Ash.read_one!(authorize?: false)
    end)
  end

  test "request and fresh password reauthentication create one pending proof without changing canonical email" do
    NewYou.Proof.EmailChangeScenarios.scenario_request_and_fresh_password_reauthentication_create_one_pending_proof_without_changing_canonical_email()
  end

  test "active MFA requires purpose-bound TOTP step-up before issuing an email-change proof" do
    NewYou.Proof.EmailChangeScenarios.scenario_active_mfa_requires_purpose_bound_totp_step_up_before_issuing_an_email_change_proof()
  end

  test "development-only email-change intents remain held and never reach a provider" do
    NewYou.Proof.EmailChangeScenarios.scenario_development_only_email_change_intents_remain_held_and_never_reach_a_provider()
  end

  test "passive retrieval is inert and explicit CSRF confirmation does not apply the email" do
    NewYou.Proof.EmailChangeScenarios.scenario_passive_retrieval_is_inert_and_explicit_csrf_confirmation_does_not_apply_the_email()
  end

  test "new-address bearer is absent from logs, endpoint telemetry, ordinary rows and jobs" do
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

      parent = self()
      handler = "p816-#{System.unique_integer([:positive])}"

      :ok =
        :telemetry.attach_many(
          handler,
          [[:phoenix, :endpoint, :start], [:phoenix, :endpoint, :stop]],
          fn event, _, metadata, _ -> send(parent, {:p816_telemetry, event, metadata}) end,
          nil
        )

      try do
        url =
          "/primary-email-change/confirm?" <>
            URI.encode_query(%{proof: proof, locale: "en"})

        logs =
          capture_log([level: :debug], fn ->
            page = get(build_conn(), url)
            [_, csrf] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, page.resp_body)

            confirmed =
              page
              |> recycle()
              |> put_private(:plug_skip_csrf_protection, false)
              |> post("/primary-email-change/confirm", %{
                proof: proof,
                locale: "en",
                _csrf_token: csrf
              })

            Process.put(:p816_confirmed, confirmed)
          end)

        confirmed = Process.delete(:p816_confirmed)

        assert confirmed.status == 200
        refute confirmed.resp_body =~ proof
        refute String.contains?(logs, proof)

        for _ <- 1..4 do
          assert_receive {:p816_telemetry, _event, metadata}
          refute String.contains?(inspect(metadata), proof)
        end

        for resource <- [
              Account,
              Token,
              MessageIntent,
              NewYou.Audit.EvidenceObligation,
              NewYou.Audit.EvidenceRecord
            ] do
          records = Ash.read!(resource, authorize?: false)
          refute :binary.match(:erlang.term_to_binary(records), proof) != :nomatch
        end

        refute :binary.match(:erlang.term_to_binary(Repo.all(Oban.Job)), proof) != :nomatch
        assert current_account(registration.account_id).primary_email_change_state == :confirmed
        assert current_account(registration.account_id).email == registration_request.email
      after
        :telemetry.detach(handler)
      end
    end)
  end

  test "confirmed operation cannot apply after its originating Session logs out" do
    with_confirmed_email_change(
      %{delay_seconds: 0, requires_review?: false},
      [active_mfa?: true],
      fn fixture ->
        assert :ok = Identity.logout(fixture.credentials)

        assert {:error, :primary_email_change_unavailable} =
                 Identity.apply_primary_email_change(fixture.operation_id)

        assert current_account(fixture.registration.account_id).email ==
                 fixture.registration_request.email

        assert Ash.get!(Session, fixture.credentials.session_id, authorize?: false).state ==
                 :logged_out

        assert_no_apply_consequences(fixture)
      end
    )
  end

  test "confirmed operation cannot apply after its originating Session is revoked" do
    NewYou.Proof.EmailChangeScenarios.scenario_confirmed_operation_cannot_apply_after_its_originating_session_is_revoked()
  end

  test "confirmed operation cannot apply after its originating Session expires absolutely" do
    with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
      Repo.query!(
        "UPDATE sessions SET expires_at = now() - interval '1 second' WHERE id = $1",
        [Ecto.UUID.dump!(fixture.credentials.session_id)]
      )

      assert_apply_denied(fixture)
    end)
  end

  test "confirmed operation cannot apply after its originating Session idles out" do
    with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
      Repo.query!(
        "UPDATE sessions SET idle_expires_at = now() - interval '1 second' WHERE id = $1",
        [Ecto.UUID.dump!(fixture.credentials.session_id)]
      )

      assert_apply_denied(fixture)
    end)
  end

  test "confirmed operation cannot apply after purpose-bound step-up expires" do
    with_confirmed_email_change(
      %{delay_seconds: 0, requires_review?: false},
      [active_mfa?: true],
      fn fixture ->
        Repo.query!(
          "UPDATE sessions SET step_up_expires_at = now() - interval '1 second' WHERE id = $1",
          [Ecto.UUID.dump!(fixture.credentials.session_id)]
        )

        assert_apply_denied(fixture)
      end
    )
  end

  test "confirmed operation cannot apply after its current step-up is cleared" do
    with_confirmed_email_change(
      %{delay_seconds: 0, requires_review?: false},
      [active_mfa?: true],
      fn fixture ->
        session = Ash.get!(Session, fixture.credentials.session_id, authorize?: false)
        assert {:ok, _} = Ash.update(session, %{}, action: :clear_step_up, authorize?: false)

        assert_apply_denied(fixture)
      end
    )
  end

  test "confirmed operation cannot apply with step-up bound to the wrong purpose" do
    with_confirmed_email_change(
      %{delay_seconds: 0, requires_review?: false},
      [active_mfa?: true],
      fn fixture ->
        session = Ash.get!(Session, fixture.credentials.session_id, authorize?: false)

        assert {:ok, _} =
                 Ash.update(
                   session,
                   %{step_up_purpose: :review_security_hold},
                   action: :set_step_up,
                   authorize?: false
                 )

        assert_apply_denied(fixture)
      end
    )
  end

  test "confirmed operation cannot apply after purpose-bound step-up expires without MFA" do
    with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
      assert current_account(fixture.registration.account_id).mfa_enrollment_state == :disabled

      Repo.query!(
        "UPDATE sessions SET step_up_expires_at = now() - interval '1 second' WHERE id = $1",
        [Ecto.UUID.dump!(fixture.credentials.session_id)]
      )

      assert_apply_denied(fixture)
    end)
  end

  test "confirmed operation cannot apply after its step-up is cleared without MFA" do
    with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
      assert current_account(fixture.registration.account_id).mfa_enrollment_state == :disabled
      session = Ash.get!(Session, fixture.credentials.session_id, authorize?: false)
      assert {:ok, _} = Ash.update(session, %{}, action: :clear_step_up, authorize?: false)

      assert_apply_denied(fixture)
    end)
  end

  test "confirmed operation cannot apply with wrong-purpose step-up without MFA" do
    with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
      assert current_account(fixture.registration.account_id).mfa_enrollment_state == :disabled
      session = Ash.get!(Session, fixture.credentials.session_id, authorize?: false)

      assert {:ok, _} =
               Ash.update(
                 session,
                 %{step_up_purpose: :review_security_hold},
                 action: :set_step_up,
                 authorize?: false
               )

      assert_apply_denied(fixture)
    end)
  end

  test "confirmed operation cannot apply with stale MFA version binding without MFA" do
    with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
      assert current_account(fixture.registration.account_id).mfa_enrollment_state == :disabled

      Repo.query!(
        "UPDATE sessions SET step_up_mfa_version = step_up_mfa_version + 1 WHERE id = $1",
        [Ecto.UUID.dump!(fixture.credentials.session_id)]
      )

      assert_apply_denied(fixture)
    end)
  end

  test "confirmed operation cannot apply with stale security version binding without MFA" do
    with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
      assert current_account(fixture.registration.account_id).mfa_enrollment_state == :disabled

      Repo.query!(
        "UPDATE sessions SET step_up_security_version = step_up_security_version - 1 WHERE id = $1",
        [Ecto.UUID.dump!(fixture.credentials.session_id)]
      )

      assert_apply_denied(fixture)
    end)
  end

  test "confirmed operation cannot apply with stale MFA version binding" do
    with_confirmed_email_change(
      %{delay_seconds: 0, requires_review?: false},
      [active_mfa?: true],
      fn fixture ->
        Repo.query!(
          "UPDATE accounts SET mfa_version = mfa_version + 1 WHERE id = $1",
          [Ecto.UUID.dump!(fixture.registration.account_id)]
        )

        assert_apply_denied(fixture)
      end
    )
  end

  test "confirmed operation cannot apply with stale Session security version binding" do
    with_confirmed_email_change(
      %{delay_seconds: 0, requires_review?: false},
      [active_mfa?: true],
      fn fixture ->
        session = Ash.get!(Session, fixture.credentials.session_id, authorize?: false)

        assert {:ok, _} =
                 Ash.update(
                   session,
                   %{step_up_security_version: session.step_up_security_version - 1},
                   action: :set_step_up,
                   authorize?: false
                 )

        assert_apply_denied(fixture)
      end
    )
  end

  test "confirmed operation cannot apply after its authentication Token is revoked" do
    with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
      session = Ash.get!(Session, fixture.credentials.session_id, authorize?: false)
      token = Ash.get!(Token, session.token_jti, authorize?: false)
      assert {:ok, _} = Ash.update(token, %{}, action: :revoke_authentication, authorize?: false)

      assert_apply_denied(fixture)
    end)
  end

  test "confirmed operation cannot apply after its authentication Token expires" do
    with_confirmed_email_change(%{delay_seconds: 0, requires_review?: false}, fn fixture ->
      session = Ash.get!(Session, fixture.credentials.session_id, authorize?: false)

      Repo.query!(
        "UPDATE tokens SET expires_at = now() - interval '1 second' WHERE jti = $1",
        [session.token_jti]
      )

      assert_apply_denied(fixture)
    end)
  end

  test "confirmed delayed operation can refresh current assurance without restarting confirmation" do
    with_confirmed_email_change(
      %{delay_seconds: 360, requires_review?: false},
      [active_mfa?: true],
      fn fixture ->
        original_account = current_account(fixture.registration.account_id)

        Repo.query!(
          "UPDATE accounts SET primary_email_change_apply_after = now() - interval '1 second' WHERE id = $1",
          [Ecto.UUID.dump!(fixture.registration.account_id)]
        )

        Repo.query!(
          "UPDATE sessions SET step_up_expires_at = now() - interval '1 second' WHERE id = $1",
          [Ecto.UUID.dump!(fixture.credentials.session_id)]
        )

        assert {:error, :primary_email_change_unavailable} =
                 Identity.apply_primary_email_change(fixture.operation_id)

        assert_no_apply_consequences(fixture)

        account = current_account(fixture.registration.account_id)
        next_period = account.mfa_last_accepted_period + 1
        previous = Process.put(NewYou.Proof.PrivilegedAccessSeam, next_period * 30)

        try do
          assert {:ok, :ok} =
                   Identity.step_up_privileged(
                     fixture.credentials,
                     fixture.registration_request.password,
                     NimbleTOTP.verification_code(fixture.mfa_secret, time: next_period * 30),
                     :change_primary_email
                   )
        after
          if is_nil(previous),
            do: Process.delete(NewYou.Proof.PrivilegedAccessSeam),
            else: Process.put(NewYou.Proof.PrivilegedAccessSeam, previous)
        end

        assert {:ok, :assurance_refreshed} =
                 Identity.reauthenticate_primary_email_change(
                   fixture.credentials,
                   fixture.registration_request.password,
                   fixture.operation_id
                 )

        refreshed = current_account(fixture.registration.account_id)
        assert refreshed.primary_email_change_state == :delayed
        assert refreshed.primary_email_change_operation_id == fixture.operation_id
        assert refreshed.primary_email_change_token_jti == fixture.proof_jti
        assert refreshed.primary_email_change_confirmation_id == fixture.confirmation_id

        assert refreshed.primary_email_change_confirmed_at ==
                 original_account.primary_email_change_confirmed_at

        assert refreshed.primary_email_change_apply_after ==
                 account.primary_email_change_apply_after

        proofs =
          Token
          |> Ash.Query.filter(
            account_id == ^fixture.registration.account_id and
              email_change_operation_id == ^fixture.operation_id
          )
          |> Ash.read!(authorize?: false)

        assert length(proofs) == 1

        intents =
          MessageIntent
          |> Ash.Query.filter(
            source_operation_id == ^fixture.operation_id and
              role == :email_change_confirmation
          )
          |> Ash.read!(authorize?: false)

        assert length(intents) == 1
        assert {:ok, :applied} = Identity.apply_primary_email_change(fixture.operation_id)

        assert current_account(fixture.registration.account_id).email ==
                 fixture.target_request.email
      end
    )
  end

  test "confirmed delayed operation can refresh password-bound assurance without MFA" do
    with_confirmed_email_change(
      %{delay_seconds: 360, requires_review?: false},
      fn fixture ->
        original_account = current_account(fixture.registration.account_id)
        assert original_account.mfa_enrollment_state == :disabled

        Repo.query!(
          "UPDATE accounts SET primary_email_change_apply_after = now() - interval '1 second' WHERE id = $1",
          [Ecto.UUID.dump!(fixture.registration.account_id)]
        )

        Repo.query!(
          "UPDATE sessions SET step_up_expires_at = now() - interval '1 second' WHERE id = $1",
          [Ecto.UUID.dump!(fixture.credentials.session_id)]
        )

        assert_apply_denied(fixture)

        due_account = current_account(fixture.registration.account_id)

        assert {:ok, :assurance_refreshed} =
                 Identity.reauthenticate_primary_email_change(
                   fixture.credentials,
                   fixture.registration_request.password,
                   fixture.operation_id
                 )

        refreshed = current_account(fixture.registration.account_id)
        refreshed_session = Ash.get!(Session, fixture.credentials.session_id, authorize?: false)

        assert refreshed.primary_email_change_state == :delayed
        assert refreshed.primary_email_change_operation_id == fixture.operation_id
        assert refreshed.primary_email_change_token_jti == fixture.proof_jti
        assert refreshed.primary_email_change_confirmation_id == fixture.confirmation_id

        assert refreshed.primary_email_change_confirmed_at ==
                 original_account.primary_email_change_confirmed_at

        assert refreshed.primary_email_change_apply_after ==
                 due_account.primary_email_change_apply_after

        assert refreshed.primary_email_change_reauth_session_id == refreshed_session.id
        assert refreshed_session.step_up_purpose == :change_primary_email
        assert DateTime.compare(refreshed_session.step_up_at, DateTime.utc_now()) != :gt
        assert DateTime.compare(refreshed_session.step_up_expires_at, DateTime.utc_now()) == :gt
        assert refreshed_session.step_up_mfa_version == refreshed.mfa_version
        assert refreshed_session.step_up_security_version == refreshed.security_version

        proofs =
          Token
          |> Ash.Query.filter(
            account_id == ^fixture.registration.account_id and
              email_change_operation_id == ^fixture.operation_id
          )
          |> Ash.read!(authorize?: false)

        assert length(proofs) == 1

        intents =
          MessageIntent
          |> Ash.Query.filter(
            source_operation_id == ^fixture.operation_id and
              role == :email_change_confirmation
          )
          |> Ash.read!(authorize?: false)

        assert length(intents) == 1

        assert {:ok, :applied} = Identity.apply_primary_email_change(fixture.operation_id)

        assert current_account(fixture.registration.account_id).email ==
                 fixture.target_request.email
      end
    )
  end

  test "a fresh Session can lawfully rebind assurance to the same confirmed operation" do
    with_confirmed_email_change(
      %{delay_seconds: 0, requires_review?: false},
      [active_mfa?: true],
      fn fixture ->
        assert :ok = Identity.logout(fixture.credentials)

        {:ok, rebound_credentials} =
          Identity.authenticate_password(
            fixture.registration_request.email,
            fixture.registration_request.password
          )

        account = current_account(fixture.registration.account_id)
        next_period = account.mfa_last_accepted_period + 1
        previous = Process.put(NewYou.Proof.PrivilegedAccessSeam, next_period * 30)

        try do
          assert {:ok, :ok} =
                   Identity.step_up_privileged(
                     rebound_credentials,
                     fixture.registration_request.password,
                     NimbleTOTP.verification_code(fixture.mfa_secret, time: next_period * 30),
                     :change_primary_email
                   )
        after
          if is_nil(previous),
            do: Process.delete(NewYou.Proof.PrivilegedAccessSeam),
            else: Process.put(NewYou.Proof.PrivilegedAccessSeam, previous)
        end

        assert {:ok, :assurance_refreshed} =
                 Identity.reauthenticate_primary_email_change(
                   rebound_credentials,
                   fixture.registration_request.password,
                   fixture.operation_id
                 )

        rebound_account = current_account(fixture.registration.account_id)

        assert rebound_account.primary_email_change_reauth_session_id ==
                 rebound_credentials.session_id

        assert rebound_account.primary_email_change_operation_id == fixture.operation_id
        assert rebound_account.primary_email_change_token_jti == fixture.proof_jti
        assert rebound_account.primary_email_change_confirmation_id == fixture.confirmation_id
        assert {:ok, :applied} = Identity.apply_primary_email_change(fixture.operation_id)

        assert current_account(fixture.registration.account_id).email ==
                 fixture.target_request.email
      end
    )
  end

  test "competing Session logout and primary-email apply serialize against current authority" do
    NewYou.Proof.EmailChangeScenarios.scenario_competing_session_logout_and_primary_email_apply_serialize_against_current_authority()
  end

  test "guarded apply changes the canonical email and commits security consequences once" do
    NewYou.Proof.EmailChangeScenarios.scenario_guarded_apply_changes_the_canonical_email_and_commits_security_consequences_once()
  end

  test "a confirmed change resumes and applies after a fresh BEAM restart" do
    NewYou.Proof.EmailChangeScenarios.scenario_a_confirmed_change_resumes_and_applies_after_a_fresh_beam_restart()
  end

  test "a target address claimed by another Account rejects and terminalizes the operation" do
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

        assert {:ok, :confirmed} = Identity.confirm_primary_email_change(proof)

        {:ok, competing_registration} =
          Identity.register(P805.request(%{email: target_request.email}))

        assert {:ok, :rejected} = Identity.apply_primary_email_change(operation_id)
        assert {:ok, :already_rejected} = Identity.apply_primary_email_change(operation_id)

        rejected = current_account(registration.account_id)
        assert rejected.email == registration_request.email
        assert rejected.primary_email_change_state == :rejected

        assert Ash.get!(Account, competing_registration.account_id, authorize?: false).email ==
                 target_request.email

        assert Ash.get!(Token, account.primary_email_change_token_jti, authorize?: false).purpose ==
                 "email_change_confirmation_revoked"
      end)
    end)
  end

  test "primary-email apply and recovery completion serialize in both PostgreSQL commit orders" do
    NewYou.Proof.EmailChangeScenarios.scenario_primary_email_apply_and_recovery_completion_serialize_in_both_postgresql_commit_orders()
  end

  @tag :p817_privacy_red
  test "proof-only protected mutation denies when current Privacy authority is missing" do
    NewYou.Proof.EmailChangeScenarios.scenario_proof_only_protected_mutation_denies_when_current_privacy_authority_is_missing()
  end

  test "committed Privacy withdrawal wins before Identity's current mutation check" do
    NewYou.Proof.EmailChangeScenarios.scenario_committed_privacy_withdrawal_wins_before_identity_s_current_mutation_check()
  end

  test "Identity mutation committed first serializes before Privacy withdrawal" do
    NewYou.Proof.EmailChangeScenarios.scenario_identity_mutation_committed_first_serializes_before_privacy_withdrawal()
  end

  test "withdrawn Privacy authority remains denied after a fresh BEAM restart" do
    NewYou.Proof.EmailChangeScenarios.scenario_withdrawn_privacy_authority_remains_denied_after_a_fresh_beam_restart()
  end

  test "Identity fails closed when its current Privacy read is unavailable" do
    NewYou.Proof.EmailChangeScenarios.scenario_identity_fails_closed_when_its_current_privacy_read_is_unavailable()
  end

  test "cancellation revokes the proof and leaves the canonical address unchanged" do
    NewYou.Proof.EmailChangeScenarios.scenario_cancellation_revokes_the_proof_and_leaves_the_canonical_address_unchanged()
  end

  test "a newer accepted operation supersedes the old proof and remains the only current operation" do
    NewYou.Proof.EmailChangeScenarios.scenario_a_newer_accepted_operation_supersedes_the_old_proof_and_remains_the_only_current_operation()
  end

  test "database target identity rejects competing Account requests after both prechecks pass" do
    P805.with_fixture(fn ->
      first_registration_request = P805.request()
      second_registration_request = P805.request()
      target = P805.request().email

      {:ok, first_registration} = Identity.register(first_registration_request)
      {:ok, :verified} = Identity.verify_email(first_registration.verification_proof)
      {:ok, second_registration} = Identity.register(second_registration_request)
      {:ok, :verified} = Identity.verify_email(second_registration.verification_proof)

      {:ok, first_credentials} =
        Identity.authenticate_password(
          first_registration_request.email,
          first_registration_request.password
        )

      {:ok, second_credentials} =
        Identity.authenticate_password(
          second_registration_request.email,
          second_registration_request.password
        )

      first_operation = tracked_operation()
      second_operation = tracked_operation()
      parent = self()
      reference = make_ref()
      scenario = Scenario.start()

      try do
        {first_worker, first_monitor} =
          Scenario.spawn(scenario, :first_target_claim, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)
            Process.put(RegistrationSeam, {:pause, parent, reference})

            try do
              result =
                Identity.request_primary_email_change(
                  first_credentials,
                  target,
                  "en",
                  first_operation
                )

              send(parent, {reference, :first_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        {second_worker, second_monitor} =
          Scenario.spawn(scenario, :second_target_claim, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)
            Process.put(RegistrationSeam, {:pause, parent, reference})

            try do
              result =
                Identity.request_primary_email_change(
                  second_credentials,
                  target,
                  "en",
                  second_operation
                )

              send(parent, {reference, :second_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        checkpoints = await_checkpoints(reference, [first_worker, second_worker])
        assert Map.fetch!(checkpoints, first_worker) != Map.fetch!(checkpoints, second_worker)

        send(first_worker, {reference, :release})
        assert await_result(reference, :first_result) == {:ok, :requested}
        await_normal(first_monitor)

        send(second_worker, {reference, :release})

        assert await_result(reference, :second_result) ==
                 {:error, :primary_email_change_unavailable}

        await_normal(second_monitor)

        current_claims =
          Account
          |> Ash.Query.filter(primary_email_change_target == ^target)
          |> Ash.read!(authorize?: false)

        assert length(current_claims) == 1
        assert hd(current_claims).primary_email_change_operation_id == first_operation
        assert current_account(second_registration.account_id).primary_email_change_state == :none
      after
        :ok = Scenario.stop(scenario)
      end
    end)
  end

  test "competing requests on one Account serialize and retain only the later operation" do
    P805.with_fixture(fn ->
      registration_request = P805.request()
      first_target = P805.request()
      second_target = P805.request()
      first_operation = tracked_operation()
      second_operation = tracked_operation()

      {:ok, registration} = Identity.register(registration_request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)

      {:ok, credentials} =
        Identity.authenticate_password(
          registration_request.email,
          registration_request.password
        )

      parent = self()
      reference = make_ref()
      scenario = Scenario.start()

      try do
        {first_worker, first_monitor} =
          Scenario.spawn(scenario, :first_account_operation, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)
            Process.put(RegistrationSeam, {:pause, parent, reference})

            try do
              result =
                Identity.request_primary_email_change(
                  credentials,
                  first_target.email,
                  "en",
                  first_operation
                )

              send(parent, {reference, :first_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        first_backend = await_checkpoint(reference)

        {second_worker, second_monitor} =
          Scenario.spawn(scenario, :second_account_operation, fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)
            Process.put(RegistrationSeam, {:pause, parent, reference})

            try do
              send(parent, {reference, :second_backend, P805.scalar("SELECT pg_backend_pid()")})

              result =
                Identity.request_primary_email_change(
                  credentials,
                  second_target.email,
                  "af",
                  second_operation
                )

              send(parent, {reference, :second_result, result})
            after
              Sandbox.checkin(Repo)
            end
          end)

        second_backend = receive_backend(reference, :second_backend)
        assert_contention(second_backend, first_backend)

        send(first_worker, {reference, :release})
        assert await_result(reference, :first_result) == {:ok, :requested}
        await_normal(first_monitor)

        assert await_checkpoint(reference) == second_backend
        send(second_worker, {reference, :release})
        assert await_result(reference, :second_result) == {:ok, :requested}
        await_normal(second_monitor)

        current = current_account(registration.account_id)
        assert current.primary_email_change_operation_id == second_operation
        assert current.primary_email_change_target == second_target.email
        assert current.primary_email_change_locale == "af"
        assert current.primary_email_change_state == :requested

        assert {:error, :primary_email_change_unavailable} =
                 Identity.reauthenticate_primary_email_change(
                   credentials,
                   registration_request.password,
                   first_operation
                 )

        first_events =
          NewYou.Audit.EvidenceObligation
          |> Ash.Query.filter(source_operation_id == ^first_operation)
          |> Ash.read!(authorize?: false)
          |> Enum.map(& &1.evidence_type)

        assert Enum.sort(first_events) == [
                 :identity_primary_email_change_requested,
                 :identity_primary_email_change_superseded
               ]
      after
        :ok = Scenario.stop(scenario)
      end
    end)
  end

  test "expiry terminalizes the durable operation and revokes its proof" do
    NewYou.Proof.EmailChangeScenarios.scenario_expiry_terminalizes_the_durable_operation_and_revokes_its_proof()
  end

  test "a current security hold terminalizes the change without applying its target" do
    NewYou.Proof.EmailChangeScenarios.scenario_a_current_security_hold_terminalizes_the_change_without_applying_its_target()
  end

  test "risk-required changes need current Identity step-up review before apply" do
    with_apply_policy(%{delay_seconds: 0, requires_review?: true}, fn ->
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

        {:ok, {:ok, proof}} =
          Repo.transaction(fn ->
            Identity.primary_email_change_delivery(
              account.primary_email_change_token_jti,
              target_request.email,
              "en"
            )
          end)

        assert {:ok, :confirmed} = Identity.confirm_primary_email_change(proof)

        reviewed_account = current_account(registration.account_id)
        reviewed_session = Ash.get!(Session, credentials.session_id, authorize?: false)
        assert reviewed_account.primary_email_change_state == :delayed
        assert reviewed_account.primary_email_change_requires_review?
        assert reviewed_account.primary_email_change_reauth_session_id == reviewed_session.id
        assert reviewed_session.step_up_purpose == :change_primary_email

        assert {:ok, :assurance_refreshed} =
                 Identity.reauthenticate_primary_email_change(
                   credentials,
                   registration_request.password,
                   operation_id
                 )

        assert current_account(registration.account_id).primary_email_change_state == :delayed
        assert current_account(registration.account_id).primary_email_change_reviewed_at == nil

        assert {:error, :primary_email_change_unavailable} =
                 Identity.apply_primary_email_change(operation_id)

        assert {:ok, :reviewed} =
                 Identity.review_primary_email_change(
                   credentials,
                   registration_request.password,
                   operation_id
                 )

        assert {:ok, :applied} = Identity.apply_primary_email_change(operation_id)
        assert current_account(registration.account_id).email == target_request.email
      end)
    end)
  end
end
