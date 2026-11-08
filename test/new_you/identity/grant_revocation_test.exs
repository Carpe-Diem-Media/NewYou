defmodule NewYou.Identity.GrantRevocationTest do
  use ExUnit.Case, async: false

  alias NewYou.Identity
  alias NewYou.Proof.{Concurrent, P805, P813HoldFixture, Scenario}

  require Ash.Query

  test "revocation and replacement require fresh assurance on the existing Session" do
    P813HoldFixture.with_fixture(fn fixture ->
      request = P813HoldFixture.reviewed_hold(fixture)
      actor_before = P805.account!(fixture.actor.id)
      old_grant = fixture.grants.release
      assert session!(fixture.actor).step_up_purpose == :release_security_hold

      revoked = Ash.update!(old_grant, %{}, action: :revoke, authorize?: false)

      replacement =
        P813HoldFixture.grant(
          fixture.actor,
          fixture.target,
          fixture.approver,
          :release_security_hold
        )

      replacement_request = %{request | grant_id: replacement.id}

      assert {:error, :security_hold_unavailable} =
               Identity.release_security_hold(replacement_request)

      assert P805.account!(fixture.target.id).security_posture == :held
      assert admission_count(request.operation_id) == 0
      assert P805.account!(fixture.actor.id).security_version == actor_before.security_version + 1
      assert session!(fixture.actor).step_up_purpose == nil

      fresh_step_up!(fixture.actor)
      before_replay = P805.account!(fixture.actor.id)
      replay = Ash.update!(old_grant, %{}, action: :revoke, authorize?: false)
      assert replay.version == revoked.version
      assert replay.revoked_at == revoked.revoked_at
      assert P805.account!(fixture.actor.id).security_version == before_replay.security_version
      assert session!(fixture.actor).step_up_purpose == :release_security_hold

      assert {:ok, %{status: :released, version: 2}} =
               Identity.release_security_hold(replacement_request)
    end)
  end

  test "concurrent revocation invalidates assurance exactly once" do
    P813HoldFixture.with_fixture(fn fixture ->
      assert {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :release_security_hold)
      before = P805.account!(fixture.actor.id)
      scenario = Scenario.start()

      try do
        revoke = fn ->
          Ash.update!(fixture.grants.release, %{}, action: :revoke, authorize?: false)
          :revoked
        end

        assert {:ok, %{outcomes: outcomes}} =
                 Concurrent.run(scenario, %{first: revoke, second: revoke}, timeout: 15_000)

        assert outcomes.first.backend_pid != outcomes.second.backend_pid
        assert Enum.all?(outcomes, fn {_label, result} -> result.outcome == :revoked end)
        assert P805.account!(fixture.actor.id).security_version == before.security_version + 1

        assert Ash.get!(Identity.IdentityGrant, fixture.grants.release.id, authorize?: false).version ==
                 2

        assert session!(fixture.actor).step_up_purpose == nil
      after
        Scenario.stop(scenario)
      end
    end)
  end

  test "failed grant revocation rolls back Account and Session invalidation" do
    P813HoldFixture.with_fixture(fn fixture ->
      request = P813HoldFixture.reviewed_hold(fixture)
      before = P805.account!(fixture.actor.id)
      install_revocation_failure()

      try do
        assert {:error, _} =
                 Ash.update(fixture.grants.release, %{}, action: :revoke, authorize?: false)
      after
        NewYou.Repo.query!("DROP TRIGGER p813_fail_grant_revocation ON identity_grants")
        NewYou.Repo.query!("DROP FUNCTION p813_fail_grant_revocation()")
      end

      assert P805.account!(fixture.actor.id).security_version == before.security_version
      assert session!(fixture.actor).step_up_purpose == :release_security_hold

      assert Ash.get!(Identity.IdentityGrant, fixture.grants.release.id, authorize?: false).state ==
               :active

      assert {:ok, %{status: :released}} = Identity.release_security_hold(request)
    end)
  end

  defp fresh_step_up!(actor) do
    account = P805.account!(actor.id)
    period = max(div(System.os_time(:second), 30), account.mfa_last_accepted_period + 1)
    Process.put(NewYou.Proof.PrivilegedAccessSeam, period * 30)

    try do
      assert {:ok, :ok} =
               Identity.step_up_privileged(
                 actor.credentials,
                 actor.password,
                 NimbleTOTP.verification_code(actor.secret, time: period * 30),
                 :release_security_hold
               )
    after
      Process.delete(NewYou.Proof.PrivilegedAccessSeam)
    end
  end

  defp session!(actor),
    do: Ash.get!(Identity.Session, actor.credentials.session_id, authorize?: false)

  defp admission_count(operation_id) do
    NewYou.Audit.EvidenceRecord
    |> Ash.Query.filter(attempt_id == ^operation_id)
    |> Ash.count!(authorize?: false)
  end

  defp install_revocation_failure do
    NewYou.Repo.query!("""
    CREATE FUNCTION p813_fail_grant_revocation() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.state = 'revoked' THEN
        RAISE EXCEPTION 'injected grant revocation failure';
      END IF;
      RETURN NEW;
    END;
    $$
    """)

    NewYou.Repo.query!("""
    CREATE TRIGGER p813_fail_grant_revocation BEFORE UPDATE ON identity_grants
    FOR EACH ROW EXECUTE FUNCTION p813_fail_grant_revocation()
    """)
  end
end
