defmodule NewYou.Proof.P813Test do
  use ExUnit.Case, async: false

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
