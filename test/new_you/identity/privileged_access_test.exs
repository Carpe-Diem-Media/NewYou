defmodule NewYou.Identity.PrivilegedAccessTest do
  use ExUnit.Case, async: false

  alias NewYou.Identity
  alias NewYou.Proof.{Concurrent, P805, P813HoldFixture, Scenario}

  setup do
    previous = Application.fetch_env(:new_you, :identity_mfa_keyring)

    Application.put_env(:new_you, :identity_mfa_keyring, %{
      active_version: "test-v1",
      keys: %{"test-v1" => :crypto.strong_rand_bytes(32)}
    })

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:new_you, :identity_mfa_keyring, value)
        :error -> Application.delete_env(:new_you, :identity_mfa_keyring)
      end
    end)

    :ok
  end

  test "Account TOTP enrollment requires a current Session and confirms with password and code" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)

      assert {:ok, %{secret: secret}} =
               Identity.enroll_privileged_mfa(credentials, request.password)

      assert is_binary(secret)

      assert {:ok, :ok} =
               Identity.confirm_privileged_mfa(
                 credentials,
                 request.password,
                 NimbleTOTP.verification_code(secret)
               )

      account = P805.account!(registration.account_id)
      assert account.mfa_enrollment_state == :active
      refute is_binary(account.totp_secret)

      assert %{rows: [[ciphertext]]} =
               NewYou.Repo.query!(
                 "SELECT encrypted_totp_secret FROM accounts WHERE id = $1",
                 [Ecto.UUID.dump!(registration.account_id)]
               )

      assert is_binary(ciphertext)
      refute ciphertext == secret
    end)
  end

  test "one captured TOTP instant governs both validation and the durable replay period" do
    P813HoldFixture.with_fixture(fn fixture ->
      actor = fixture.actor
      now = System.os_time(:second)
      code = NimbleTOTP.verification_code(actor.secret, time: now)

      captured =
        Enum.find([now - 30, now - 60, now - 90], fn time ->
          NimbleTOTP.verification_code(actor.secret, time: time) != code
        end)

      Process.put(NewYou.Proof.PrivilegedAccessSeam, captured)

      try do
        assert {:error, :privileged_access_unavailable} =
                 Identity.step_up_privileged(
                   actor.credentials,
                   actor.password,
                   code,
                   :release_security_hold
                 )

        assert P805.account!(actor.id).mfa_last_accepted_period == nil
      after
        Process.delete(NewYou.Proof.PrivilegedAccessSeam)
      end
    end)
  end

  test "MFA confirmation rolls back when its required Audit obligation cannot be written" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
      {:ok, %{secret: secret}} = Identity.enroll_privileged_mfa(credentials, request.password)

      install_mfa_audit_failure()

      try do
        assert {:error, :privileged_access_unavailable} =
                 Identity.confirm_privileged_mfa(
                   credentials,
                   request.password,
                   NimbleTOTP.verification_code(secret)
                 )
      after
        remove_mfa_audit_failure()
      end

      account = P805.account!(registration.account_id)
      assert account.mfa_enrollment_state == :pending

      assert %{rows: [[ciphertext]]} =
               NewYou.Repo.query!(
                 "SELECT encrypted_pending_totp_secret FROM accounts WHERE id = $1",
                 [Ecto.UUID.dump!(registration.account_id)]
               )

      assert is_binary(ciphertext)

      assert %{rows: [[0]]} =
               NewYou.Repo.query!(
                 "SELECT count(*) FROM evidence_obligations WHERE evidence_type = 'identity_mfa_confirmed' AND target_id = $1",
                 [Ecto.UUID.dump!(registration.account_id)]
               )
    end)
  end

  test "scoped grant consumption requires the exact current actor, target, capability and step-up" do
    P813HoldFixture.with_fixture(fn fixture ->
      actor = fixture.actor
      target = fixture.target
      grant = fixture.grants.release

      assert {:ok, :ok} = P813HoldFixture.step_up(actor, :release_security_hold)

      assert {:ok, %{actor: %{id: actor_id}, target: %{id: target_id}, grant: %{id: grant_id}}} =
               authorize(actor.credentials, grant.id, target.id, :release_security_hold)

      assert actor_id == actor.id
      assert target_id == target.id
      assert grant_id == grant.id

      assert :error ==
               authorize(
                 actor.credentials,
                 Ecto.UUID.generate(),
                 target.id,
                 :release_security_hold
               )

      assert :error ==
               authorize(
                 actor.credentials,
                 grant.id,
                 Ecto.UUID.generate(),
                 :release_security_hold
               )

      assert :error == authorize(actor.credentials, grant.id, target.id, :place_security_hold)

      future_target = P813HoldFixture.member()

      future_grant =
        make_grant(
          actor,
          future_target,
          fixture.approver,
          :release_security_hold,
          DateTime.add(DateTime.utc_now(), 60),
          DateTime.add(DateTime.utc_now(), 600)
        )

      assert :error ==
               authorize(
                 actor.credentials,
                 future_grant.id,
                 future_target.id,
                 :release_security_hold
               )

      expired_target = P813HoldFixture.member()

      expired_grant =
        make_grant(
          actor,
          expired_target,
          fixture.approver,
          :release_security_hold,
          DateTime.add(DateTime.utc_now(), -600),
          DateTime.add(DateTime.utc_now(), -60)
        )

      assert :error ==
               authorize(
                 actor.credentials,
                 expired_grant.id,
                 expired_target.id,
                 :release_security_hold
               )

      assert {:ok, :ok} = P813HoldFixture.step_up(actor, :place_security_hold)
      assert :error == authorize(actor.credentials, grant.id, target.id, :release_security_hold)

      reviewer = fixture.reviewer
      assert {:ok, :ok} = P813HoldFixture.step_up(reviewer, :release_security_hold)

      assert :error ==
               authorize(reviewer.credentials, grant.id, target.id, :release_security_hold)

      assert {:ok, :ok} = P813HoldFixture.step_up(actor, :release_security_hold)

      NewYou.Repo.query!(
        "UPDATE sessions SET step_up_expires_at = now() - interval '1 second' WHERE id = $1",
        [Ecto.UUID.dump!(actor.credentials.session_id)]
      )

      assert :error == authorize(actor.credentials, grant.id, target.id, :release_security_hold)

      assert {:ok, :ok} = P813HoldFixture.step_up(actor, :release_security_hold)

      NewYou.Repo.query!("UPDATE accounts SET mfa_version = mfa_version + 1 WHERE id = $1", [
        Ecto.UUID.dump!(actor.id)
      ])

      assert :error == authorize(actor.credentials, grant.id, target.id, :release_security_hold)

      assert {:ok, :ok} = P813HoldFixture.step_up(actor, :release_security_hold)

      Ash.update!(grant, %{actor_id: fixture.approver.id, reason_code: :security_review},
        action: :revoke,
        authorize?: false
      )

      assert :error == authorize(actor.credentials, grant.id, target.id, :release_security_hold)
    end)
  end

  test "two independent Sessions transactions cannot consume one TOTP period twice" do
    P813HoldFixture.with_fixture(fn fixture ->
      actor = fixture.actor

      NewYou.Repo.query!("UPDATE accounts SET mfa_last_accepted_period = NULL WHERE id = $1", [
        Ecto.UUID.dump!(actor.id)
      ])

      period = div(System.os_time(:second), 30)
      code = NimbleTOTP.verification_code(actor.secret)
      scenario = Scenario.start()

      try do
        assert {:ok, %{outcomes: outcomes}} =
                 Concurrent.run(scenario, %{
                   first: fn ->
                     Identity.step_up_privileged(
                       actor.credentials,
                       actor.password,
                       code,
                       :release_security_hold
                     )
                   end,
                   second: fn ->
                     Identity.step_up_privileged(
                       actor.credentials,
                       actor.password,
                       code,
                       :release_security_hold
                     )
                   end
                 })

        results = Enum.map(outcomes, fn {_label, result} -> result.outcome end)
        assert Enum.count(results, &(&1 == [:ok, :ok])) == 1, inspect(outcomes)

        assert Enum.count(results, &(&1 == [:error, :privileged_access_unavailable])) == 1

        assert %{rows: [[1]]} =
                 NewYou.Repo.query!(
                   "SELECT count(*) FROM accounts WHERE id = $1 AND mfa_last_accepted_period = $2",
                   [Ecto.UUID.dump!(actor.id), period]
                 )
      after
        Scenario.stop(scenario)
      end
    end)
  end

  test "failed reauthentication establishes a durable cooldown shared by fresh callers" do
    P813HoldFixture.with_fixture(fn fixture ->
      actor = fixture.actor

      for _ <- 1..5 do
        assert {:error, :privileged_access_unavailable} =
                 Identity.step_up_privileged(
                   actor.credentials,
                   "incorrect password",
                   NimbleTOTP.verification_code(actor.secret),
                   :release_security_hold
                 )
      end

      account = P805.account!(actor.id)
      assert account.mfa_failed_attempts == 5
      assert DateTime.compare(account.mfa_locked_until, DateTime.utc_now()) == :gt
      code = NimbleTOTP.verification_code(actor.secret)

      assert {:error, :privileged_access_unavailable} =
               Task.async(fn ->
                 Ecto.Adapters.SQL.Sandbox.unboxed_run(NewYou.Repo, fn ->
                   Identity.step_up_privileged(
                     actor.credentials,
                     actor.password,
                     code,
                     :release_security_hold
                   )
                 end)
               end)
               |> Task.await(15_000)

      assert P805.account!(actor.id).mfa_last_accepted_period == nil
    end)
  end

  test "wrong password, wrong TOTP and same-period replay fail and persist the attempt marker" do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, registration} = Identity.register(request)
      {:ok, :verified} = Identity.verify_email(registration.verification_proof)
      {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
      {:ok, %{secret: secret}} = Identity.enroll_privileged_mfa(credentials, request.password)
      code = NimbleTOTP.verification_code(secret)
      wrong_code = if code == "000000", do: "000001", else: "000000"

      assert {:error, :privileged_access_unavailable} =
               Identity.confirm_privileged_mfa(credentials, "incorrect password", code)

      assert P805.account!(registration.account_id).mfa_failed_attempts == 1

      assert {:error, :privileged_access_unavailable} =
               Identity.confirm_privileged_mfa(credentials, request.password, wrong_code)

      assert P805.account!(registration.account_id).mfa_failed_attempts == 2
      assert {:ok, :ok} = Identity.confirm_privileged_mfa(credentials, request.password, code)

      assert {:error, :privileged_access_unavailable} =
               Identity.step_up_privileged(
                 credentials,
                 request.password,
                 code,
                 :place_security_hold
               )

      account = P805.account!(registration.account_id)
      assert account.mfa_enrollment_state == :active
      assert account.mfa_failed_attempts == 1
    end)
  end

  defp authorize(credentials, grant_id, target_id, capability) do
    case Ash.transact(
           [Identity.Account, Identity.Token, Identity.Session, Identity.IdentityGrant],
           fn ->
             Identity.PrivilegedAccess.authorize_locked(
               credentials,
               grant_id,
               target_id,
               capability
             )
           end
         ) do
      {:ok, {:ok, result}} -> {:ok, result}
      _ -> :error
    end
  end

  defp make_grant(subject, target, approver, capability, starts_at, expires_at) do
    Ash.create!(
      Identity.IdentityGrant,
      %{
        subject_account_id: subject.id,
        target_account_id: target.id,
        approver_account_id: approver.id,
        role: :support,
        scope:
          Map.fetch!(
            %{
              place_security_hold: :security_hold_restriction,
              review_security_hold: :security_hold_review,
              release_security_hold: :security_hold_release
            },
            capability
          ),
        reason_code: :security_review,
        starts_at: starts_at,
        expires_at: expires_at
      },
      action: :provision,
      authorize?: false
    )
  end

  defp install_mfa_audit_failure do
    NewYou.Repo.query!("""
    CREATE FUNCTION p813_fail_mfa_audit() RETURNS trigger AS $$
    BEGIN
      IF NEW.evidence_type = 'identity_mfa_confirmed' THEN
        RAISE EXCEPTION 'injected MFA Audit failure';
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """)

    NewYou.Repo.query!("""
    CREATE TRIGGER p813_fail_mfa_audit_trigger
    BEFORE INSERT ON evidence_obligations
    FOR EACH ROW EXECUTE FUNCTION p813_fail_mfa_audit()
    """)
  end

  defp remove_mfa_audit_failure do
    NewYou.Repo.query!(
      "DROP TRIGGER IF EXISTS p813_fail_mfa_audit_trigger ON evidence_obligations"
    )

    NewYou.Repo.query!("DROP FUNCTION IF EXISTS p813_fail_mfa_audit()")
  end
end
