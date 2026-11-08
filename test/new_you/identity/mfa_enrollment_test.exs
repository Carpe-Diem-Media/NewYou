defmodule NewYou.Identity.MfaEnrollmentTest do
  use ExUnit.Case, async: false

  alias NewYou.Identity
  alias NewYou.Proof.{Concurrent, P805, P813HoldFixture, Scenario}

  test "wrong enrollment passwords consume durable admission and survive a fresh BEAM" do
    P805.with_fixture(fn ->
      member = P813HoldFixture.member()

      for _ <- 1..5 do
        assert_denied(Identity.enroll_privileged_mfa(member.credentials, "incorrect password"))
      end

      account = P805.account!(member.id)
      assert account.mfa_failed_attempts == 5
      assert DateTime.compare(account.mfa_locked_until, DateTime.utc_now()) == :gt
      assert account.mfa_enrollment_state == :disabled
      assert pending_ciphertext_absent?(member.id)
      assert fresh_enrollment(member, nil) == "P813_DENIED"
      assert P805.account!(member.id).mfa_failed_attempts == 5
      assert pending_ciphertext_absent?(member.id)

      Ash.update!(account, %{mfa_locked_until: DateTime.add(DateTime.utc_now(), -1)},
        action: :update_privileged_mfa,
        authorize?: false
      )

      assert is_binary(setup_secret!(member))
      assert P805.account!(member.id).mfa_enrollment_state == :pending
    end)
  end

  test "lost pending setup can resume after reauthentication and process restart" do
    P805.with_fixture(fn ->
      member = P813HoldFixture.member()
      secret = setup_secret!(member)
      before = P805.account!(member.id)
      ciphertext = pending_ciphertext(member.id)

      assert_denied(Identity.enroll_privileged_mfa(member.credentials, "incorrect password"))
      assert P805.account!(member.id).mfa_failed_attempts == 1
      unchanged? = pending_ciphertext(member.id) == ciphertext
      assert unchanged?
      resumed = setup_secret!(member)
      same_factor? = same_secret?(secret, resumed)
      assert same_factor?
      assert fresh_enrollment(member, secret) == "P813_ENROLLMENT_RESUMED"
      after_resume = P805.account!(member.id)
      assert after_resume.mfa_enrollment_state == :pending
      assert after_resume.mfa_version == before.mfa_version
      assert after_resume.security_version == before.security_version
      unchanged? = pending_ciphertext(member.id) == ciphertext
      assert unchanged?
    end)
  end

  test "concurrent setup retries converge on the same pending factor" do
    P805.with_fixture(fn ->
      member = P813HoldFixture.member()
      secret = setup_secret!(member)
      before = P805.account!(member.id)
      scenario = Scenario.start()

      try do
        callback = fn ->
          if same_secret?(secret, setup_secret!(member)), do: :same_factor, else: :wrong_factor
        end

        assert {:ok, %{outcomes: outcomes}} =
                 Concurrent.run(scenario, %{first: callback, second: callback}, timeout: 15_000)

        assert outcomes.first.backend_pid != outcomes.second.backend_pid
        assert Enum.all?(outcomes, fn {_label, result} -> result.outcome == :same_factor end)
        assert P805.account!(member.id).mfa_version == before.mfa_version
      after
        Scenario.stop(scenario)
      end
    end)
  end

  test "pending retries require a live unexpired Session and do not replace the factor" do
    P805.with_fixture(fn ->
      member = P813HoldFixture.member()
      _secret = setup_secret!(member)
      ciphertext = pending_ciphertext(member.id)
      assert :ok = Identity.logout(member.credentials)
      assert_denied(Identity.enroll_privileged_mfa(member.credentials, member.password))
      assert fresh_enrollment(member, nil) == "P813_DENIED"

      account = P805.account!(member.id)
      {:ok, credentials} = Identity.authenticate_password(account.email, member.password)

      NewYou.Repo.query!(
        "UPDATE sessions SET expires_at = now() - interval '1 second' WHERE id = $1",
        [
          Ecto.UUID.dump!(credentials.session_id)
        ]
      )

      assert_denied(Identity.enroll_privileged_mfa(credentials, member.password))
      unchanged? = pending_ciphertext(member.id) == ciphertext
      assert unchanged?
      assert P805.account!(member.id).mfa_enrollment_state == :pending
    end)
  end

  test "an active factor cannot return its setup secret or restart enrollment" do
    P805.with_fixture(fn ->
      member = P813HoldFixture.member()
      secret = setup_secret!(member)

      assert {:ok, :ok} =
               Identity.confirm_privileged_mfa(
                 member.credentials,
                 member.password,
                 NimbleTOTP.verification_code(secret)
               )

      account = P805.account!(member.id)
      assert_denied(Identity.enroll_privileged_mfa(member.credentials, member.password))
      assert fresh_enrollment(member, secret) == "P813_DENIED"
      assert P805.account!(member.id).mfa_version == account.mfa_version
      assert pending_factor_removed?(member.id)
    end)
  end

  defp setup_secret!(member) do
    case Identity.enroll_privileged_mfa(member.credentials, member.password) do
      {:ok, %{secret: secret}} when is_binary(secret) -> secret
      _ -> flunk("setup secret unavailable")
    end
  end

  defp assert_denied(result) do
    unless result == {:error, :privileged_access_unavailable},
      do: flunk("enrollment should deny without returning setup material")
  end

  defp same_secret?(left, right), do: :crypto.hash(:sha256, left) == :crypto.hash(:sha256, right)

  defp pending_factor_removed?(id) do
    account = Ash.get!(Identity.Account, id, load: [:pending_totp_secret], authorize?: false)
    is_nil(account.pending_totp_secret)
  end

  defp pending_ciphertext_absent?(id), do: is_nil(pending_ciphertext(id))

  defp pending_ciphertext(id) do
    %{rows: [[ciphertext]]} =
      NewYou.Repo.query!("SELECT encrypted_pending_totp_secret FROM accounts WHERE id = $1", [
        Ecto.UUID.dump!(id)
      ])

    ciphertext
  end

  defp fresh_enrollment(member, expected_secret) do
    keyring = Application.fetch_env!(:new_you, :identity_mfa_keyring)

    input = %{
      mode: "mfa_enroll",
      credentials: member.credentials,
      password: member.password,
      expected_digest:
        if(expected_secret, do: Base.encode64(:crypto.hash(:sha256, expected_secret))),
      signing_secret:
        Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret)),
      keyring: %{
        active_version: keyring.active_version,
        keys: Map.new(keyring.keys, fn {k, v} -> {k, Base.encode64(v)} end)
      }
    }

    executable = System.find_executable("mix") || flunk("mix unavailable")

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        args: ["run", "test/proof/p8_13_restart.exs"],
        env: [{~c"MIX_ENV", ~c"test"}, {~c"ERL_FLAGS", ~c"+S 2:2"}]
      ])

    true = Port.command(port, Jason.encode!(input) <> "\n")
    read_restart(port, "", System.monotonic_time(:millisecond) + 30_000)
  end

  defp read_restart(port, output, deadline) do
    receive do
      {^port, {:data, bytes}} when byte_size(output) + byte_size(bytes) < 16_384 ->
        read_restart(port, output <> bytes, deadline)

      {^port, {:exit_status, 0}} ->
        output |> String.split("\n") |> Enum.find("", &String.starts_with?(&1, "P813_"))

      {^port, {:exit_status, _}} ->
        flunk("fresh enrollment BEAM failed")
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        Port.close(port)
        flunk("fresh enrollment BEAM timed out")
    end
  end
end
