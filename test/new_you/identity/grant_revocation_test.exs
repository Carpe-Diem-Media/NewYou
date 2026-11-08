defmodule NewYou.Identity.GrantRevocationTest do
  use ExUnit.Case, async: false

  alias NewYou.Identity
  alias NewYou.Proof.{Concurrent, P805, P813HoldFixture, Scenario}

  require Ash.Query

  test "a caller-selected hold operation cannot reserve a grant's revocation evidence identity" do
    P813HoldFixture.with_fixture(fn fixture ->
      assert {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :place_security_hold)
      request = P813HoldFixture.request(fixture, :place, 0, fixture.grants.release.id)
      assert {:ok, %{status: :held}} = Identity.place_security_hold(request)
      assert {:ok, revoked} = revoke(fixture.grants.release, fixture.approver.id)
      assert revoked.state == :revoked
    end)
  end

  test "revocation establishes one minimised selected E2 obligation with the source transition" do
    P813HoldFixture.with_fixture(fn fixture ->
      grant = fixture.grants.release
      revoked = revoke!(grant, fixture.approver.id)

      assert [obligation] = revocation_obligations(grant.id)
      assert obligation.evidence_type == :identity_grant_revoked
      assert obligation.actor_id == fixture.approver.id
      assert obligation.target_id == fixture.actor.id
      assert obligation.grant_id == grant.id
      assert obligation.source_occurred_at == revoked.revoked_at
      assert obligation.outcome == :succeeded
      assert obligation.state == :open
      assert obligation.reason_code == :security_review
      assert obligation.session_id == nil
      assert obligation.admission_id == nil

      assert revoke!(grant, fixture.approver.id).revoked_at == revoked.revoked_at
      assert [^obligation] = revocation_obligations(grant.id)

      assert {:ok, %{evidence_record_id: record_id}} =
               NewYou.Audit.materialize_registration_evidence(
                 %{primary_key: %{id: obligation.id}},
                 authorize?: false
               )

      record = Ash.get!(NewYou.Audit.EvidenceRecord, record_id, authorize?: false)
      assert record.assertion_kind == :materialisation
      assert record.obligation_id == obligation.id
    end)
  end

  test "revocation and replacement require fresh assurance on the existing Session" do
    P813HoldFixture.with_fixture(fn fixture ->
      request = P813HoldFixture.reviewed_hold(fixture)
      actor_before = P805.account!(fixture.actor.id)
      old_grant = fixture.grants.release
      assert session!(fixture.actor).step_up_purpose == :release_security_hold

      revoked = revoke!(old_grant, fixture.approver.id)

      replacement =
        P813HoldFixture.grant(
          fixture.actor,
          fixture.target,
          fixture.approver,
          :security_hold_release
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
      replay = revoke!(old_grant, fixture.approver.id)
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
          revoke!(fixture.grants.release, fixture.approver.id)
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
        assert [_obligation] = revocation_obligations(fixture.grants.release.id)
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
                 revoke(fixture.grants.release, fixture.approver.id)
      after
        NewYou.Repo.query!("DROP TRIGGER p813_fail_grant_revocation ON identity_grants")
        NewYou.Repo.query!("DROP FUNCTION p813_fail_grant_revocation()")
      end

      assert P805.account!(fixture.actor.id).security_version == before.security_version
      assert session!(fixture.actor).step_up_purpose == :release_security_hold

      assert Ash.get!(Identity.IdentityGrant, fixture.grants.release.id, authorize?: false).state ==
               :active

      assert revocation_obligations(fixture.grants.release.id) == []

      assert {:ok, %{status: :released}} = Identity.release_security_hold(request)
    end)
  end

  test "revocation requires named evidence provenance" do
    P813HoldFixture.with_fixture(fn fixture ->
      assert {:error, _} =
               Ash.update(fixture.grants.release, %{}, action: :revoke, authorize?: false)

      assert Ash.get!(Identity.IdentityGrant, fixture.grants.release.id, authorize?: false).state ==
               :active

      assert revocation_obligations(fixture.grants.release.id) == []
    end)
  end

  test "materialisation failure preserves revocation and fresh BEAM recovery creates one assertion" do
    P813HoldFixture.with_fixture(fn fixture ->
      revoked = revoke!(fixture.grants.release, fixture.approver.id)
      [obligation] = revocation_obligations(revoked.id)

      Process.put(NewYou.Proof.AuditSeam, fn
        :after_record -> raise "injected grant materialisation failure"
        _ -> :ok
      end)

      try do
        assert_raise Ash.Error.Unknown, fn ->
          NewYou.Audit.materialize_registration_evidence(
            %{primary_key: %{id: obligation.id}},
            authorize?: false
          )
        end
      after
        Process.delete(NewYou.Proof.AuditSeam)
      end

      assert Ash.get!(Identity.IdentityGrant, revoked.id, authorize?: false).state == :revoked

      assert Ash.get!(NewYou.Audit.EvidenceObligation, obligation.id, authorize?: false).state ==
               :open

      assert records_for(obligation.id) == []

      assert NewYou.Proof.P813.materialize_after_restart(obligation.id) == :materialized
      assert NewYou.Proof.P813.materialize_after_restart(obligation.id) == :materialized
      assert [_record] = records_for(obligation.id)

      assert Ash.get!(Identity.IdentityGrant, revoked.id, authorize?: false).version ==
               revoked.version
    end)
  end

  test "failed E2 establishment rolls back the grant and all assurance invalidation" do
    P813HoldFixture.with_fixture(fn fixture ->
      assert {:ok, :ok} = P813HoldFixture.step_up(fixture.actor, :release_security_hold)
      before = P805.account!(fixture.actor.id)
      install_evidence_failure()

      try do
        assert {:error, _} = revoke(fixture.grants.release, fixture.approver.id)
      after
        NewYou.Repo.query!("DROP TRIGGER p813_fail_grant_evidence ON evidence_obligations")
        NewYou.Repo.query!("DROP FUNCTION p813_fail_grant_evidence()")
      end

      assert P805.account!(fixture.actor.id).security_version == before.security_version
      assert session!(fixture.actor).step_up_purpose == :release_security_hold

      assert Ash.get!(Identity.IdentityGrant, fixture.grants.release.id, authorize?: false).state ==
               :active

      assert revocation_obligations(fixture.grants.release.id) == []
    end)
  end

  defp revoke(grant, actor_id),
    do:
      Ash.update(grant, %{actor_id: actor_id, reason_code: :security_review},
        action: :revoke,
        authorize?: false
      )

  defp revoke!(grant, actor_id) do
    {:ok, revoked} = revoke(grant, actor_id)
    revoked
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

  defp revocation_obligations(grant_id) do
    NewYou.Audit.EvidenceObligation
    |> Ash.Query.filter(grant_id == ^grant_id and evidence_type == :identity_grant_revoked)
    |> Ash.read!(authorize?: false)
  end

  defp records_for(obligation_id) do
    NewYou.Audit.EvidenceRecord
    |> Ash.Query.filter(obligation_id == ^obligation_id)
    |> Ash.read!(authorize?: false)
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

  defp install_evidence_failure do
    NewYou.Repo.query!("""
    CREATE FUNCTION p813_fail_grant_evidence() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.evidence_type = 'identity_grant_revoked' THEN
        RAISE EXCEPTION 'injected grant evidence failure';
      END IF;
      RETURN NEW;
    END;
    $$
    """)

    NewYou.Repo.query!("""
    CREATE TRIGGER p813_fail_grant_evidence BEFORE INSERT ON evidence_obligations
    FOR EACH ROW EXECUTE FUNCTION p813_fail_grant_evidence()
    """)
  end
end
