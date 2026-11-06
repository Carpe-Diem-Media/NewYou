defmodule NewYou.Audit.E2RecoveryTest do
  use ExUnit.Case, async: false

  for name <-
        ~w(interrupted_materialisation existing_assertion concurrent_execution restart_backlog) do
    @tag timeout: 90_000
    test "deterministic Audit E2 proof: #{name}" do
      id = "p811." <> unquote(name)
      registration = Enum.find(NewYou.Proof.P811Catalog.registrations(), &(&1.case_id == id))

      {result, cleanup} =
        NewYou.Proof.SelfTest.execute_registered_case(
          Map.put(registration.manifest, :version, "p8-11.1"),
          registration.callback
        )

      assert result["verdict"] == "PASS", inspect(result)
      assert Enum.all?(cleanup, fn {_key, value} -> value == true end), inspect(cleanup)
    end
  end
end
