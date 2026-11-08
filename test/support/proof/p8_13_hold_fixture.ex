defmodule NewYou.Proof.P813HoldFixture do
  @moduledoc "Synthetic scoped Support fixtures. Protected hold actions always use real owner interfaces."
  alias NewYou.Identity
  alias NewYou.Proof.{P805, PrivilegedAccessSeam}

  def with_fixture(callback) do
    P805.with_fixture(fn ->
      Application.put_env(:new_you, :identity_mfa_keyring, %{
        active_version: "p813",
        keys: %{"p813" => :crypto.strong_rand_bytes(32)}
      })

      target = member()
      approver = member()
      actor = factor_member()
      reviewer = factor_member()

      grants = %{
        place: grant(actor, target, approver, :security_hold_restriction),
        release: grant(actor, target, approver, :security_hold_release),
        review: grant(reviewer, target, approver, :security_hold_review)
      }

      callback.(%{
        target: target,
        approver: approver,
        actor: actor,
        reviewer: reviewer,
        grants: grants
      })
    end)
  after
    Process.delete(NewYou.Proof.SecurityHoldSeam)
  end

  def member do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
    %{id: registration.account_id, credentials: credentials, password: request.password}
  end

  def factor_member do
    member = member()
    secret = NimbleTOTP.secret()
    account = P805.account!(member.id)

    Ash.update!(
      account,
      %{
        totp_secret: secret,
        mfa_enrollment_state: :active,
        mfa_confirmed_at: DateTime.utc_now(),
        mfa_last_accepted_period: nil
      },
      action: :update_privileged_mfa,
      authorize?: false
    )

    Map.put(member, :secret, secret)
  end

  def grant(subject, target, approver, scope) do
    Ash.create!(
      Identity.IdentityGrant,
      %{
        subject_account_id: subject.id,
        target_account_id: target.id,
        approver_account_id: approver.id,
        role: :support,
        scope: scope,
        reason_code: :security_review,
        starts_at: DateTime.add(DateTime.utc_now(), -60),
        expires_at: DateTime.add(DateTime.utc_now(), 3600)
      },
      action: :provision,
      authorize?: false
    )
  end

  def step_up(member, purpose) do
    # Synthetic fixture seeding avoids sleeping through real TOTP periods when
    # arranging distinct capabilities. No replay marker changes during a race.
    NewYou.Repo.query!("UPDATE accounts SET mfa_last_accepted_period = NULL WHERE id = $1", [
      Ecto.UUID.dump!(member.id)
    ])

    # Password verification can cross a TOTP boundary. Pin only this fixture's
    # test clock so its generated code and the validator use the same instant.
    captured = PrivilegedAccessSeam.timestamp()
    previous = Process.put(PrivilegedAccessSeam, captured)

    try do
      Identity.step_up_privileged(
        member.credentials,
        member.password,
        NimbleTOTP.verification_code(member.secret, time: captured),
        purpose
      )
    after
      if is_nil(previous),
        do: Process.delete(PrivilegedAccessSeam),
        else: Process.put(PrivilegedAccessSeam, previous)
    end
  end

  def request(fixture, kind, version, operation_id \\ Ecto.UUID.generate()) do
    {member, grant} =
      case kind do
        :place -> {fixture.actor, fixture.grants.place}
        :release -> {fixture.actor, fixture.grants.release}
        :review -> {fixture.reviewer, fixture.grants.review}
      end

    %{
      credentials: member.credentials,
      grant_id: grant.id,
      target_id: fixture.target.id,
      expected_version: version,
      operation_id: operation_id,
      reason_code: :security_review
    }
  end

  def reviewed_hold(fixture) do
    {:ok, :ok} = step_up(fixture.actor, :place_security_hold)

    {:ok, %{status: :held, version: 1}} =
      Identity.place_security_hold(request(fixture, :place, 0))

    {:ok, :ok} = step_up(fixture.reviewer, :review_security_hold)

    {:ok, %{status: :reviewed, version: 1}} =
      Identity.review_security_hold(request(fixture, :review, 1))

    {:ok, :ok} = step_up(fixture.actor, :release_security_hold)
    request(fixture, :release, 1)
  end
end
