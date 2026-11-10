defmodule NewYou.Proof.P812Test do
  use ExUnit.Case, async: false

  alias NewYou.Proof.{Catalog, FullCatalog}

  @case_ids ~w(p812.reset_race p812.stale_login_race p812.interrupted_reset p812.restart)

  test "bounded P8-12 cases register within the partial session and revocation family" do
    manifests = Catalog.required().business_manifests
    registrations = Catalog.compiled_business_registrations()
    family = manifests["session_login_revocation_restart"]

    assert family.scope == :partial

    assert Enum.all?(@case_ids, fn case_id ->
             Enum.any?(family.cases, &(&1.case_id == case_id))
           end)

    assert Enum.all?(@case_ids, fn case_id ->
             Enum.any?(registrations, &(&1.case_id == case_id))
           end)

    assert :ok = Catalog.validate_compiled_registrations(manifests, registrations)
  end

  @tag timeout: 300_000
  test "registered P8-12 cases prove reset boundaries, rollback, contention and restart" do
    family = Catalog.required().business_manifests["session_login_revocation_restart"]
    cases = Enum.filter(family.cases, &String.starts_with?(&1.case_id, "p812."))
    manifests = %{"session_login_revocation_restart" => %{family | cases: cases}}

    registrations =
      Enum.filter(Catalog.compiled_business_registrations(), &(&1.case_id in @case_ids))

    assert {:ok, observations, cleanup} = FullCatalog.execute(manifests, registrations)
    assert cleanup["verdict"] == "PASS"

    assert Enum.map(observations, & &1["case_id"]) == @case_ids,
           inspect(observations, limit: :infinity)

    assert Enum.all?(observations, &(&1["verdict"] == "PASS"))
  end
end
