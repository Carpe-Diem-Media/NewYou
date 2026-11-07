defmodule NewYou.Proof.CatalogTest do
  use ExUnit.Case, async: true

  alias NewYou.Proof.Catalog

  test "required catalog is fixed and has the complete infrastructure manifest" do
    required = Catalog.required()

    assert length(required.coverage_inventory) == 10
    assert required.coverage_inventory == Catalog.coverage_inventory()

    assert Map.keys(required.business_manifests) |> Enum.sort() ==
             Enum.sort(
               ~w(registration_pmr_reconciliation audit_e1 audit_e2 browser_spine proof_capability_scanner_replay_supersession session_login_revocation_restart)
             )

    assert length(required.self_test.cases) == 50

    assert Enum.all?(required.self_test.cases, fn manifest ->
             manifest.assertion_ids == [manifest.case_id <> ".verified"] and
               is_binary(manifest.digest) and byte_size(manifest.digest) == 64
           end)

    assert Enum.count(required.self_test.cases, &(&1.coverage_id == "harness")) == 50

    assert Enum.find(
             required.self_test.cases,
             &(&1.case_id == "cut.raise.transaction.before_commit")
           )
  end

  test "compiled self-test manifests use schema labels and expose a stable aggregate digest" do
    self_test = Catalog.required().self_test

    assert String.match?(self_test.digest, ~r/^[0-9a-f]{64}$/)

    assert Enum.all?(self_test.cases, fn manifest ->
             Enum.all?(
               [manifest.invariant_id, manifest.boundary | manifest.assertion_ids],
               &String.match?(&1, ~r/^[A-Za-z0-9_.:-]{1,128}$/)
             )
           end)
  end

  test "slow self-test subprocesses declare explicit bounded timeout overrides" do
    manifests = Map.new(Catalog.required().self_test.cases, &{&1.case_id, &1})

    assert manifests["result.broken_invariant_exit"].timeout_ms == 60_000

    assert manifests["result.broken_invariant_exit"].timeout_override_reason ==
             "nested proof CLI subprocess"

    assert manifests["production.exclusion"].timeout_ms == 240_000

    assert manifests["production.exclusion"].timeout_override_reason ==
             "isolated production build and runtime probe"

    assert manifests["cut.raise.transaction.before_commit"].timeout_ms == 10_000
    assert manifests["cut.raise.transaction.before_commit"].timeout_override_reason == nil
  end

  test "manifest lookup distinguishes unavailable inventory from unknown identifiers" do
    assert {:error, :unknown_coverage} = Catalog.lookup_manifest("unknown", "case.one")

    assert {:error, :missing_manifest} =
             Catalog.lookup_manifest("recovery_primary_email_change", "case.one")

    assert {:error, :unknown_case} = Catalog.lookup_manifest("harness", "unknown.case")
    assert {:error, :unknown_case} = Catalog.lookup_manifest("audit_e1", "unknown.case")

    manifest = hd(Catalog.required().self_test.cases)
    assert {:ok, ^manifest} = Catalog.lookup_manifest("harness", manifest.case_id)
  end

  test "caller registrations cannot establish any business family as available" do
    registrations =
      Enum.map(Catalog.coverage_inventory(), fn coverage_id ->
        registration(coverage_id, "forged.case", "forged.invariant")
      end)

    result = Catalog.validate_registrations(registrations, :tb001)

    assert result.missing_families ==
             Enum.reject(
               Catalog.coverage_inventory(),
               &(get_in(Catalog.required().business_manifests, [&1, :scope]) == :complete)
             )

    assert :missing_manifest in result.errors
    assert :missing_family in result.errors
    assert :unknown_case in result.errors
  end

  test "registrations reject unknown and duplicate coverage, case and invariant ids" do
    assert {:error, :unknown_coverage} =
             Catalog.register([], "unknown", "case.one", "inv.one", fn -> :ok end)

    case_id = "cut.raise.transaction.before_commit"
    registrations = [registration("harness", case_id, "inv.one")]

    assert {:error, :duplicate_case} =
             Catalog.register(registrations, "harness", case_id, "inv.two", fn -> :ok end)

    assert {:error, :unknown_invariant} =
             Catalog.register(
               registrations,
               "harness",
               "cut.raise.transaction.after_commit",
               "inv.one",
               fn -> :ok end
             )
  end

  test "registration validation reports missing family, case and self-test independently" do
    registrations = [
      registration("registration_pmr_reconciliation", "arbitrary", "arbitrary.invariant")
    ]

    result = Catalog.validate_registrations(registrations, :tb001)

    assert :missing_manifest in result.errors
    assert :missing_family in result.errors

    self_test = Catalog.validate_registrations([], :harness_self_test)
    assert :missing_self_test_registration in self_test.errors
    refute :missing_family in self_test.errors
  end

  test "a complete infrastructure self-test does not require business families" do
    registrations =
      Enum.map(Catalog.required().self_test.cases, fn manifest ->
        registration("harness", manifest.case_id, manifest.invariant_id)
      end)

    assert %{errors: [], missing_cases: [], missing_families: []} =
             Catalog.validate_registrations(registrations, :harness_self_test)
  end

  defp registration(coverage_id, case_id, invariant_id) do
    %{
      coverage_id: coverage_id,
      case_id: case_id,
      invariant_id: invariant_id,
      callback: fn -> :ok end
    }
  end
end
