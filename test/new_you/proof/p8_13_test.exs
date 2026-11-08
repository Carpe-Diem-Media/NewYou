defmodule NewYou.Proof.P813Test do
  use ExUnit.Case, async: false

  alias NewYou.Proof.{P805, P813HoldFixture, PrivilegedAccessSeam}

  test "Support fixture uses its captured TOTP clock and restores the caller's clock" do
    P813HoldFixture.with_fixture(fn fixture ->
      actor = fixture.actor
      now = System.os_time(:second)
      current_code = NimbleTOTP.verification_code(actor.secret, time: now)

      captured =
        Enum.find([now - 30, now - 60, now - 90], fn timestamp ->
          NimbleTOTP.verification_code(actor.secret, time: timestamp) != current_code
        end)

      Process.put(PrivilegedAccessSeam, captured)

      try do
        assert {:ok, :ok} = P813HoldFixture.step_up(actor, :release_security_hold)
        assert Process.get(PrivilegedAccessSeam) == captured
        assert P805.account!(actor.id).mfa_last_accepted_period == div(captured, 30)

        assert {:error, :privileged_access_unavailable} =
                 P813HoldFixture.step_up(%{actor | password: "incorrect"}, :release_security_hold)

        assert Process.get(PrivilegedAccessSeam) == captured
      after
        Process.delete(PrivilegedAccessSeam)
      end

      assert {:ok, :ok} = P813HoldFixture.step_up(actor, :release_security_hold)
      assert Process.get(PrivilegedAccessSeam) == nil
    end)
  end

  for name <-
        ~w(admission_cut capture_failure source_failure same_attempt_race distinct_attempt_race restart crash_after_admission crash_after_source) do
    @tag timeout: 90_000
    test "bounded privileged Support proof: #{name}" do
      assert Code.ensure_loaded?(NewYou.Proof.P813Catalog)

      registration =
        Enum.find(
          NewYou.Proof.P813Catalog.registrations(),
          &(&1.case_id == "p813." <> unquote(name))
        )

      {result, cleanup} =
        NewYou.Proof.SelfTest.execute_registered_case(
          Map.put(registration.manifest, :version, "p8-13.1"),
          registration.callback
        )

      assert result["verdict"] == "PASS", inspect(result)
      assert Enum.all?(cleanup, fn {_key, value} -> value == true end), inspect(cleanup)
    end
  end
end
