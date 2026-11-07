defmodule NewYou.Identity.SecurityHoldTest do
  use ExUnit.Case, async: false

  alias NewYou.Identity
  alias NewYou.Proof.{P805, P813HoldFixture}
  require Ash.Query

  test "release without an independent review cannot establish E1 admission" do
    P813HoldFixture.with_fixture(fn f ->
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :place_security_hold)

      {:ok, %{status: :held}} =
        Identity.place_security_hold(P813HoldFixture.request(f, :place, 0))

      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :release_security_hold)
      request = P813HoldFixture.request(f, :release, 1)
      assert {:error, :security_hold_unavailable} = Identity.release_security_hold(request)
      assert admissions(request.operation_id) == []
      assert P805.account!(f.target.id).security_posture == :held
    end)
  end

  test "the release actor cannot supply their own independent security review" do
    P813HoldFixture.with_fixture(fn f ->
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :place_security_hold)

      {:ok, %{status: :held}} =
        Identity.place_security_hold(P813HoldFixture.request(f, :place, 0))

      review_grant = P813HoldFixture.grant(f.actor, f.target, f.approver, :review_security_hold)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :review_security_hold)

      review = %{
        P813HoldFixture.request(f, :review, 1)
        | credentials: f.actor.credentials,
          grant_id: review_grant.id
      }

      {:ok, %{status: :reviewed}} = Identity.review_security_hold(review)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :release_security_hold)
      request = P813HoldFixture.request(f, :release, 1)
      assert {:error, :security_hold_unavailable} = Identity.release_security_hold(request)
      assert admissions(request.operation_id) == []
    end)
  end

  for change <- ~w(reviewer_revoked stepup_expired mfa_disabled review_changed target_closed) do
    test "current #{change} after E1 blocks release and preserves admission" do
      P813HoldFixture.with_fixture(fn f ->
        request = P813HoldFixture.reviewed_hold(f)

        Process.put(NewYou.Proof.SecurityHoldSeam, fn
          :after_admission -> invalidate(unquote(change), f, request)
          _ -> :ok
        end)

        assert {:error, :security_hold_unavailable} = Identity.release_security_hold(request)
        Process.delete(NewYou.Proof.SecurityHoldSeam)
        assert P805.account!(f.target.id).security_posture == :held
        assert length(admissions(request.operation_id)) == 1
        assert [%{outcome: :failed}] = outcomes(request.operation_id)
      end)
    end
  end

  test "scoped placement revokes Sessions and independent reviewed release preserves verification" do
    P813HoldFixture.with_fixture(fn f ->
      request = P813HoldFixture.reviewed_hold(f)

      assert {:error, :authentication_unavailable} =
               Identity.authorize_session(f.target.credentials)

      assert {:ok, %{status: :released, version: 2}} = Identity.release_security_hold(request)
      target = P805.account!(f.target.id)
      assert target.security_posture == :normal
      assert target.email_verified?
      assert {:ok, %{status: :released, version: 2}} = Identity.release_security_hold(request)
      assert P805.account!(f.target.id).hold_version == 2
      assert length(admissions(request.operation_id)) == 1
    end)
  end

  test "source failure after E1 preserves the admission and links an immutable failed outcome" do
    P813HoldFixture.with_fixture(fn f ->
      request = P813HoldFixture.reviewed_hold(f)

      Process.put(NewYou.Proof.SecurityHoldSeam, fn
        :after_release_before_commit -> raise "synthetic source failure"
        _ -> :ok
      end)

      assert {:error, :security_hold_unavailable} = Identity.release_security_hold(request)
      Process.delete(NewYou.Proof.SecurityHoldSeam)
      assert P805.account!(f.target.id).security_posture == :held
      [admission] = admissions(request.operation_id)
      assert admission.outcome == :admitted
      [result] = outcomes(request.operation_id)
      assert result.admission_id == admission.id
      assert result.outcome == :failed
      assert {:error, :security_hold_unavailable} = Identity.release_security_hold(request)
      assert length(admissions(request.operation_id)) == 1
    end)
  end

  test "grant revocation after committed E1 blocks the source release" do
    P813HoldFixture.with_fixture(fn f ->
      request = P813HoldFixture.reviewed_hold(f)

      Process.put(NewYou.Proof.SecurityHoldSeam, fn
        :after_admission -> Ash.update!(f.grants.release, %{}, action: :revoke, authorize?: false)
        _ -> :ok
      end)

      assert {:error, :security_hold_unavailable} = Identity.release_security_hold(request)
      Process.delete(NewYou.Proof.SecurityHoldSeam)
      assert P805.account!(f.target.id).security_posture == :held
      assert length(admissions(request.operation_id)) == 1
      assert [%{outcome: :failed}] = outcomes(request.operation_id)
    end)
  end

  test "a caller claim without current Session, grant and step-up cannot release a hold" do
    request = %{
      credentials: %{account_id: Ecto.UUID.generate(), role: :support, step_up: true},
      grant_id: Ecto.UUID.generate(),
      target_id: Ecto.UUID.generate(),
      expected_version: 1,
      operation_id: Ecto.UUID.generate(),
      reason_code: :security_review
    }

    assert {:error, :security_hold_unavailable} =
             Identity.release_security_hold(request)
  end

  defp admissions(operation_id) do
    NewYou.Audit.EvidenceRecord
    |> Ash.Query.filter(attempt_id == ^operation_id)
    |> Ash.read!(authorize?: false)
  end

  defp invalidate("reviewer_revoked", f, _request),
    do: Ash.update!(f.grants.review, %{}, action: :revoke, authorize?: false)

  defp invalidate("stepup_expired", f, _request) do
    session = Ash.get!(Identity.Session, f.actor.credentials.session_id, authorize?: false)

    Ash.update!(session, %{step_up_expires_at: DateTime.add(DateTime.utc_now(), -1)},
      action: :set_step_up,
      authorize?: false
    )
  end

  defp invalidate("mfa_disabled", f, _request) do
    actor = P805.account!(f.actor.id)

    Ash.update!(actor, %{mfa_enrollment_state: :disabled, mfa_version: actor.mfa_version + 1},
      action: :update_privileged_mfa,
      authorize?: false
    )
  end

  defp invalidate("review_changed", f, _request) do
    target = P805.account!(f.target.id)

    Ash.update!(target, %{hold_review: nil, expected_hold_version: target.hold_version},
      action: :review_security_hold,
      authorize?: false
    )
  end

  defp invalidate("target_closed", f, _request),
    do:
      NewYou.Repo.query!(
        "UPDATE accounts SET account_status = 'closed_recoverable' WHERE id = $1",
        [Ecto.UUID.dump!(f.target.id)]
      )

  defp outcomes(operation_id) do
    NewYou.Audit.EvidenceObligation
    |> Ash.Query.filter(source_operation_id == ^operation_id)
    |> Ash.read!(authorize?: false)
  end
end
