defmodule NewYou.Proof.P818Test do
  use ExUnit.Case, async: false

  alias NewYou.Privacy
  alias NewYou.Proof.{Catalog, FullCatalog, P805}

  @coverage_id "source_authority_bypass_negatives"
  @case_ids ~w(
    p818.provider_observation
    p818.stale_browser_authority
    p818.audit_evidence_non_authority
    p818.executor_state_non_authority
    p818.signals_coordination_non_authority
    p818.analytics_projection
    p818.arc_029_enforcement
  )

  test "P8-18 registers the complete source-authority negative family" do
    manifests = Catalog.required().business_manifests
    family = manifests[@coverage_id]
    registrations = Catalog.compiled_business_registrations()

    assert family.scope == :complete
    assert Enum.sort(Enum.map(family.cases, & &1.case_id)) == Enum.sort(@case_ids)

    assert Enum.all?(
             family.cases,
             &(is_binary(&1.invariant_id) and &1.invariant_id != &1.case_id)
           )

    assert Enum.sort(
             registrations
             |> Enum.filter(&(&1.coverage_id == @coverage_id))
             |> Enum.map(& &1.case_id)
           ) == Enum.sort(@case_ids)

    assert :ok = Catalog.validate_compiled_registrations(manifests, registrations)
    refute @coverage_id in Catalog.validate_registrations(registrations, :tb001).missing_families
  end

  test "the minimum Analytics projection reads current Privacy authority and stores no identifiers" do
    assert Code.ensure_loaded?(NewYou.Analytics)
    assert Code.ensure_loaded?(NewYou.Analytics.P817PrivacyProjection)
    assert function_exported?(NewYou.Analytics, :rebuild_p817_privacy_projection, 0)

    assert documented_and_typed?(
             NewYou.Analytics,
             :rebuild_p817_privacy_projection,
             0
           )

    assert documented_and_typed?(NewYou.Privacy, :current_p817_proof_purpose_count, 0)

    refute function_exported?(NewYou.Analytics, :verify_identity, 1)
    refute function_exported?(NewYou.Analytics, :complete_recovery, 2)
    refute function_exported?(NewYou.Analytics, :apply_primary_email_change, 1)

    P805.with_fixture(fn ->
      subject_id = Ecto.UUID.generate()
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)

      assert {:ok, :allowed} = Privacy.grant_p817_proof_purpose(subject_id, operation_id)
      assert :ok = NewYou.Analytics.rebuild_p817_privacy_projection()

      projection = only_projection()
      assert projection.current_allowed_count == 1

      refute Enum.any?(
               projection_fields(),
               &(&1 in [:subject_id, :source_operation_id, :account_id])
             )

      assert {:ok, :withdrawn} = Privacy.withdraw_p817_proof_purpose(subject_id, operation_id)
      assert :ok = NewYou.Analytics.rebuild_p817_privacy_projection()
      assert only_projection().current_allowed_count == 0

      assert {:error, :withdrawn} = Privacy.grant_p817_proof_purpose(subject_id, operation_id)
      assert :ok = NewYou.Analytics.rebuild_p817_privacy_projection()
      assert only_projection().current_allowed_count == 0
    end)
  end

  test "the complete P8-18 callbacks pass through the shared P8-04 runner" do
    manifests = Catalog.required().business_manifests

    registrations =
      Catalog.compiled_business_registrations()
      |> Enum.filter(&(&1.coverage_id == @coverage_id))

    assert {:ok, observations, cleanup} =
             FullCatalog.execute(%{@coverage_id => manifests[@coverage_id]}, registrations)

    failures = Enum.reject(observations, &(&1["verdict"] == "PASS"))
    assert failures == [], "P8-18 family failures: #{inspect(failures, limit: :infinity)}"
    assert Enum.sort(Enum.map(observations, & &1["case_id"])) == Enum.sort(@case_ids)
    assert Enum.all?(observations, &(&1["status"] == "completed"))

    for observation <- observations do
      manifest = Enum.find(manifests[@coverage_id].cases, &(&1.case_id == observation["case_id"]))
      assert observation["invariant_id"] == manifest.invariant_id
      assert observation["assertion_ids"] == manifest.assertion_ids
      assert observation["assertions_executed"] == length(manifest.assertion_ids)
    end

    assert cleanup["verdict"] == "PASS"
  end

  defp only_projection do
    resource = NewYou.Analytics.P817PrivacyProjection
    assert [projection] = Ash.read!(resource, authorize?: false)
    projection
  end

  defp projection_fields do
    NewYou.Analytics.P817PrivacyProjection
    |> Ash.Resource.Info.attributes()
    |> Enum.map(& &1.name)
  end

  defp documented_and_typed?(module, function, arity) do
    {:ok, specs} = Code.Typespec.fetch_specs(module)

    has_spec? =
      Enum.any?(specs, fn {{name, spec_arity}, _} ->
        name == function and spec_arity == arity
      end)

    {:docs_v1, _, _, _, moduledoc, _, docs} = Code.fetch_docs(module)
    module_doc? = is_map(moduledoc) and is_binary(Map.get(moduledoc, "en"))

    function_doc? =
      Enum.any?(docs, fn
        {{:function, ^function, ^arity}, _, _, doc, _} ->
          is_map(doc) and is_binary(Map.get(doc, "en"))

        _ ->
          false
      end)

    has_spec? and module_doc? and function_doc?
  end
end
