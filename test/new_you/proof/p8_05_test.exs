defmodule NewYou.Proof.P805Test do
  use ExUnit.Case, async: false

  alias NewYou.Proof.{Catalog, FullCatalog}

  @case_ids ~w(p805.accepted p805.rejected p805.envelope_rollback p805.audit_schedule_rollback p805.commit_rollback p805.replay_neutrality p805.pmr_collision p805.same_email_race p805.resend p805.resend_binding p805.browser_en p805.browser_af)

  test "P8-05 reviewed cases are compiled without manufacturing future coverage" do
    manifests = Catalog.required().business_manifests
    registrations = Catalog.compiled_business_registrations()
    cases = Enum.flat_map(Map.values(manifests), & &1.cases)
    assert Enum.sort(Enum.map(cases, & &1.case_id)) == Enum.sort(@case_ids)
    assert Enum.sort(Enum.map(registrations, & &1.case_id)) == Enum.sort(@case_ids)
    assert :ok = Catalog.validate_compiled_registrations(manifests, registrations)
    missing = Catalog.validate_registrations(registrations, :tb001).missing_families
    assert "session_login_revocation_restart" in missing
    assert "audit_e1" in missing
    assert "recovery_primary_email_change" in missing
    assert Catalog.coverage_inventory() |> length() == 10
  end

  test "runner executes every owned obligation and retains incomplete overall TB-001" do
    manifests = Catalog.required().business_manifests
    assert map_size(manifests) > 0

    assert {:ok, observations, cleanup} =
             FullCatalog.execute(manifests, Catalog.compiled_business_registrations())

    assert length(observations) == length(@case_ids)
    assert Enum.all?(observations, &(&1["verdict"] == "PASS"))
    assert cleanup["verdict"] == "PASS"

    for observation <- observations do
      manifest =
        manifests[observation["coverage_id"]].cases
        |> Enum.find(&(&1.case_id == observation["case_id"]))

      assert observation["assertion_ids"] == manifest.assertion_ids
      assert observation["assertions_executed"] == length(manifest.assertion_ids)
      assert Enum.all?(observation["observations"], &is_boolean(&1["value"]))
    end

    result = NewYou.Proof.Runner.evaluate_full(manifests, observations, true, cleanup)
    assert result.exit_code == 1
    assert result.verdict == "FAIL"
    assert "coverage.incomplete" in result.reason_codes
  end

  test "fixture cleanup recovers committed browser provenance when operation IDs were not returned" do
    alias NewYou.Proof.P805
    alias Ecto.Adapters.SQL.Sandbox
    :ok = Sandbox.checkout(NewYou.Repo, sandbox: false)
    before_counts = P805.counts()
    :ok = Sandbox.checkin(NewYou.Repo)

    assert_raise RuntimeError, "synthetic browser result lost", fn ->
      P805.with_fixture(fn ->
        input = P805.request()
        # The browser supplies a different operation ID. The fixture owner knows
        # only its pre-registered synthetic email when the result is lost.
        {:ok, _} = NewYou.Identity.register(%{input | operation_id: Ecto.UUID.generate()})
        raise "synthetic browser result lost"
      end)
    end

    :ok = Sandbox.checkout(NewYou.Repo, sandbox: false)
    after_counts = P805.counts()
    :ok = Sandbox.checkin(NewYou.Repo)
    # Permanent PMR reservations are never removed, including fixture teardown.
    assert Enum.drop(after_counts, -1) == Enum.drop(before_counts, -1)
    assert List.last(after_counts) == List.last(before_counts) + 1
  end

  test "missing owned callback remains a missing case and cannot become a passing family" do
    registrations =
      Catalog.compiled_business_registrations() |> Enum.reject(&(&1.case_id == "p805.accepted"))

    {results, _cleanup} =
      NewYou.Proof.Runner.execute_full_catalog(
        Catalog.required().business_manifests,
        registrations
      )

    family = Enum.find(results, &(&1["coverage_id"] == "registration_pmr_reconciliation"))
    assert family["verdict"] == "FAIL"
    assert hd(family["cases"])["reason_codes"] == ["missing.case"]
  end
end
