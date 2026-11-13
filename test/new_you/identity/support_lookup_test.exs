defmodule NewYou.Identity.SupportLookupTest do
  use ExUnit.Case, async: false

  alias NewYou.Identity
  alias NewYou.Identity.{Account, IdentityGrant}
  alias NewYou.Proof.P813HoldFixture

  test "one current named grant returns a minimum projection for its bound Account only" do
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

  test "lookup denies missing and wrong-scope grants without an administrative bypass" do
    P813HoldFixture.with_fixture(fn fixture ->
      {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :lookup_identity)

      assert {:error, :support_lookup_unavailable} =
               Identity.lookup_support_identity(
                 fixture.actor.credentials,
                 Ecto.UUID.generate(),
                 fixture.target.id,
                 "someone@example.test"
               )

      assert {:error, :support_lookup_unavailable} =
               Identity.lookup_support_identity(
                 fixture.actor.credentials,
                 fixture.grants.release.id,
                 fixture.target.id,
                 "someone@example.test"
               )

      wrong_actor_grant =
        provision_grant(fixture, :identity_lookup,
          subject: fixture.approver,
          approver: fixture.actor
        )

      assert {:error, :support_lookup_unavailable} =
               Identity.lookup_support_identity(
                 fixture.actor.credentials,
                 wrong_actor_grant.id,
                 fixture.target.id,
                 "someone@example.test"
               )

      invalid_credentials = Map.put(fixture.actor.credentials, :token, "invalid-session-token")

      assert {:error, :support_lookup_unavailable} =
               Identity.lookup_support_identity(
                 invalid_credentials,
                 wrong_actor_grant.id,
                 fixture.target.id,
                 "someone@example.test"
               )

      refute IdentityGrant.permits?(
               %{role: :platform_administrator, scope: :identity_lookup},
               :lookup_identity
             )
    end)
  end

  test "lookup denies expired and revoked grants" do
    P813HoldFixture.with_fixture(fn fixture ->
      now = DateTime.utc_now()

      expired =
        provision_grant(fixture, :identity_lookup,
          starts_at: DateTime.add(now, -3_600, :second),
          expires_at: DateTime.add(now, -60, :second)
        )

      {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :lookup_identity)

      assert {:error, :support_lookup_unavailable} =
               Identity.lookup_support_identity(
                 fixture.actor.credentials,
                 expired.id,
                 fixture.target.id,
                 "someone@example.test"
               )

      revoked =
        provision_grant(fixture, :identity_lookup,
          target: P813HoldFixture.member(),
          reason_code: :security_review
        )

      assert {:ok, _} =
               Ash.update(
                 revoked,
                 %{actor_id: fixture.approver.id, reason_code: :security_review},
                 action: :revoke,
                 authorize?: false
               )

      {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :lookup_identity)

      assert {:error, :support_lookup_unavailable} =
               Identity.lookup_support_identity(
                 fixture.actor.credentials,
                 revoked.id,
                 revoked.target_account_id,
                 "someone@example.test"
               )
    end)
  end

  test "lookup requires the current Session and purpose-bound assurance" do
    P813HoldFixture.with_fixture(fn fixture ->
      grant =
        P813HoldFixture.grant(
          fixture.actor,
          fixture.target,
          fixture.approver,
          :identity_lookup
        )

      {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :lookup_identity)
      assert :ok = Identity.logout(fixture.actor.credentials)

      assert {:error, :support_lookup_unavailable} =
               Identity.lookup_support_identity(
                 fixture.actor.credentials,
                 grant.id,
                 fixture.target.id,
                 "someone@example.test"
               )
    end)
  end

  test "a step-up for another Support purpose cannot authorize lookup" do
    P813HoldFixture.with_fixture(fn fixture ->
      grant =
        P813HoldFixture.grant(
          fixture.actor,
          fixture.target,
          fixture.approver,
          :identity_lookup
        )

      {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :review_security_hold)

      assert {:error, :support_lookup_unavailable} =
               Identity.lookup_support_identity(
                 fixture.actor.credentials,
                 grant.id,
                 fixture.target.id,
                 "someone@example.test"
               )
    end)
  end

  test "lookup denies assurance made stale by an MFA authority change" do
    P813HoldFixture.with_fixture(fn fixture ->
      grant =
        P813HoldFixture.grant(
          fixture.actor,
          fixture.target,
          fixture.approver,
          :identity_lookup
        )

      {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :lookup_identity)

      NewYou.Repo.query!("UPDATE accounts SET mfa_version = mfa_version + 1 WHERE id = $1", [
        Ecto.UUID.dump!(fixture.actor.id)
      ])

      assert {:error, :support_lookup_unavailable} =
               Identity.lookup_support_identity(
                 fixture.actor.credentials,
                 grant.id,
                 fixture.target.id,
                 "someone@example.test"
               )
    end)
  end

  defp provision_grant(fixture, scope, opts) do
    subject = Keyword.get(opts, :subject, fixture.actor)
    approver = Keyword.get(opts, :approver, fixture.approver)
    target = Keyword.get(opts, :target, fixture.target)
    now = DateTime.utc_now()

    Ash.create!(
      IdentityGrant,
      %{
        subject_account_id: subject.id,
        target_account_id: target.id,
        approver_account_id: approver.id,
        role: :support,
        scope: scope,
        reason_code: Keyword.get(opts, :reason_code, :security_review),
        starts_at: Keyword.get(opts, :starts_at, DateTime.add(now, -60, :second)),
        expires_at: Keyword.get(opts, :expires_at, DateTime.add(now, 3_600, :second))
      },
      action: :provision,
      authorize?: false
    )
  end
end
