defmodule NewYou.Proof.Catalog do
  @moduledoc """
  Fixed P8-04 coverage inventory, infrastructure self-tests and bounded P8-05 mappings.

  Registrations supply callbacks only. They cannot add required coverage or turn
  unavailable future TB-001 business manifests into approved manifests.
  """

  @coverage_inventory [
    "registration_pmr_reconciliation",
    "proof_capability_scanner_replay_supersession",
    "session_login_revocation_restart",
    "communications_durability_backlog_ambiguity",
    "audit_e2",
    "audit_e1",
    "recovery_primary_email_change",
    "non_enumeration_current_privacy",
    "source_authority_bypass_negatives",
    "browser_spine"
  ]

  @cuts [
    "transaction.before_commit",
    "transaction.after_commit",
    "scheduling.before_enqueue",
    "scheduling.after_enqueue",
    "provider.before_invoke",
    "provider.after_invoke_before_persist",
    "evidence.before_materialize",
    "evidence.after_materialize_before_commit"
  ]

  @other_self_tests [
    "cut.consume_once",
    "cut.wrong_worker",
    "cut.unknown_name",
    "cut.duplicate_arm",
    "cut.unreached",
    "scenario.isolation",
    "scenario.controller_death",
    "scenario.lost_reply",
    "scenario.parent_crash",
    "db.contention",
    "db.reject_shared",
    "db.reject_sequential",
    "db.timeout_cleanup",
    "db.worker_crash_cleanup",
    "provider.outcomes",
    "provider.backlog",
    "provider.duplicates_reorder",
    "provider.authentication_fixtures",
    "restart.consumption",
    "restart.fresh_connection",
    "result.missing_manifest",
    "result.missing_family",
    "result.missing_case",
    "result.missing_assertion",
    "result.empty_self_test",
    "result.metadata",
    "result.dirty_source",
    "result.changed_source",
    "result.callback_failures",
    "result.broken_invariant_exit",
    "result.output_failure",
    "result.cleanup_failure",
    "production.exclusion",
    "privacy.redaction"
  ]

  @type business_manifest :: %{
          required(:scope) => :partial | :complete,
          required(:version) => String.t(),
          required(:digest) => String.t(),
          required(:cases) => [map()]
        }

  @spec coverage_inventory() :: [String.t()]
  def coverage_inventory, do: @coverage_inventory

  @spec required() :: %{
          coverage_inventory: [String.t()],
          business_manifests: %{optional(String.t()) => business_manifest()},
          self_test: %{version: String.t(), digest: String.t(), cases: [map()]}
        }
  @spec compiled_business_registrations() :: [registration()]
  def compiled_business_registrations,
    do:
      NewYou.Proof.P805Catalog.registrations() ++
        NewYou.Proof.P807Catalog.registrations() ++
        NewYou.Proof.P809Catalog.registrations() ++
        NewYou.Proof.P809MagicCatalog.registrations() ++
        NewYou.Proof.P811Catalog.registrations() ++
        NewYou.Proof.P813Catalog.registrations()

  @spec validate_compiled_registrations(map(), [registration()]) :: :ok | {:error, [atom()]}
  def validate_compiled_registrations(manifests, registrations)
      when is_map(manifests) and is_list(registrations) do
    ids = Enum.map(registrations, &{&1.coverage_id, &1.case_id})

    errors =
      []
      |> maybe_add(duplicate?(ids), :duplicate_case)
      |> maybe_add(duplicate?(Enum.map(registrations, & &1.invariant_id)), :duplicate_invariant)
      |> Kernel.++(compiled_registration_errors(manifests, registrations))

    if errors == [], do: :ok, else: {:error, Enum.uniq(errors)}
  end

  def validate_compiled_registrations(_manifests, _registrations),
    do: {:error, [:invalid_registration]}

  defp compiled_registration_errors(manifests, registrations) do
    Enum.flat_map(registrations, fn registration ->
      case compiled_registration_error(manifests, registration) do
        nil -> []
        reason -> [reason]
      end
    end)
  end

  defp compiled_registration_error(manifests, registration) do
    case Map.get(manifests, registration.coverage_id) do
      %{cases: cases} when is_list(cases) ->
        case Enum.find(cases, &(&1.case_id == registration.case_id)) do
          %{invariant_id: invariant_id} when invariant_id == registration.invariant_id -> nil
          %{invariant_id: _other} -> :unknown_invariant
          nil -> :unknown_case
        end

      _ ->
        :unknown_case
    end
  end

  def required do
    cases =
      for(cut <- @cuts, mode <- ["raise", "terminate"], do: {"cut.#{mode}.#{cut}", cut}) ++
        Enum.map(@other_self_tests, &{&1, nil})

    manifests =
      Enum.map(cases, fn {case_id, cut_point} -> self_test_manifest(case_id, cut_point) end)

    %{
      coverage_inventory: @coverage_inventory,
      business_manifests: business_manifests(),
      self_test: %{version: "1.0.0", digest: digest(manifests), cases: manifests}
    }
  end

  @spec lookup_manifest(String.t(), String.t()) ::
          {:ok, map()} | {:error, :unknown_coverage | :missing_manifest | :unknown_case}
  def lookup_manifest(coverage_id, case_id)
      when is_binary(coverage_id) and is_binary(case_id) do
    cond do
      coverage_id not in ["harness" | @coverage_inventory] ->
        {:error, :unknown_coverage}

      coverage_id != "harness" and
          not Map.has_key?(required().business_manifests, coverage_id) ->
        {:error, :missing_manifest}

      manifest = known_manifest(coverage_id, case_id) ->
        {:ok, manifest}

      true ->
        {:error, :unknown_case}
    end
  end

  def lookup_manifest(_coverage_id, _case_id), do: {:error, :unknown_coverage}

  @spec register([registration()], String.t(), String.t(), String.t(), (-> term())) ::
          {:ok, [registration()]} | {:error, atom()}
  def register(registrations, coverage_id, case_id, invariant_id, callback)
      when is_list(registrations) and is_binary(coverage_id) and is_binary(case_id) and
             is_binary(invariant_id) and is_function(callback, 0) do
    with {:ok, manifest} <- lookup_manifest(coverage_id, case_id),
         :ok <- validate_unique_case(registrations, coverage_id, case_id),
         :ok <- validate_registration_invariant(manifest, invariant_id),
         :ok <- validate_unique_invariant(registrations, invariant_id) do
      registration = %{
        coverage_id: coverage_id,
        case_id: case_id,
        invariant_id: invariant_id,
        callback: callback,
        manifest: manifest
      }

      {:ok, registrations ++ [registration]}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def register(_registrations, _coverage_id, _case_id, _invariant_id, _callback),
    do: {:error, :invalid_registration}

  defp validate_unique_case(registrations, coverage_id, case_id) do
    if Enum.any?(registrations, &(&1.coverage_id == coverage_id and &1.case_id == case_id)),
      do: {:error, :duplicate_case},
      else: :ok
  end

  defp validate_registration_invariant(manifest, invariant_id) do
    cond do
      manifest.invariant_id != invariant_id -> {:error, :unknown_invariant}
      not valid_label?(invariant_id) -> {:error, :invalid_invariant}
      true -> :ok
    end
  end

  defp validate_unique_invariant(registrations, invariant_id) do
    if Enum.any?(registrations, &(&1.invariant_id == invariant_id)),
      do: {:error, :duplicate_invariant},
      else: :ok
  end

  @spec validate_registrations([registration()], :harness_self_test | :tb001 | :diagnostic) ::
          %{errors: [atom()], missing_cases: [String.t()], missing_families: [String.t()]}
  def validate_registrations(registrations, mode) when is_list(registrations) do
    ids = Enum.map(registrations, &{&1.coverage_id, &1.case_id})

    missing_families =
      if mode == :tb001,
        do:
          Enum.reject(
            @coverage_inventory,
            &(get_in(required().business_manifests, [&1, :scope]) == :complete)
          ),
        else: []

    business_manifests = required().business_manifests

    expected_cases = expected_registration_cases(mode, business_manifests)

    missing_cases = Enum.reject(expected_cases, &(&1 in ids)) |> Enum.map(&elem(&1, 1))

    errors =
      coverage_registration_errors(mode, missing_families, missing_cases) ++
        registration_identity_errors(registrations) ++
        duplicate_registration_errors(ids, registrations)

    %{
      errors: Enum.uniq(errors),
      missing_cases: missing_cases,
      missing_families: missing_families
    }
  end

  defp expected_registration_cases(:harness_self_test, _business_manifests),
    do: Enum.map(required().self_test.cases, &{"harness", &1.case_id})

  defp expected_registration_cases(:tb001, business_manifests) do
    Enum.flat_map(@coverage_inventory, &compiled_case_ids(&1, business_manifests))
  end

  defp expected_registration_cases(:diagnostic, _business_manifests), do: []

  defp compiled_case_ids(coverage_id, business_manifests) do
    case Map.get(business_manifests, coverage_id) do
      %{cases: cases} -> Enum.map(cases, &{coverage_id, &1.case_id})
      _ -> []
    end
  end

  defp coverage_registration_errors(mode, missing_families, missing_cases) do
    []
    |> maybe_add(mode == :tb001 and missing_families != [], :missing_manifest)
    |> maybe_add(mode == :tb001 and missing_families != [], :missing_family)
    |> maybe_add(
      mode == :harness_self_test and missing_cases != [],
      :missing_self_test_registration
    )
  end

  defp registration_identity_errors(registrations) do
    unknown_case? = Enum.any?(registrations, &registration_manifest_missing?/1)
    unknown_invariant? = Enum.any?(registrations, &registration_invariant_invalid?/1)

    []
    |> maybe_add(unknown_case?, :unknown_case)
    |> maybe_add(unknown_invariant?, :unknown_invariant)
  end

  defp registration_manifest_missing?(registration) do
    match?(
      {:error, reason} when reason in [:unknown_coverage, :missing_manifest, :unknown_case],
      lookup_manifest(registration.coverage_id, registration.case_id)
    )
  end

  defp registration_invariant_invalid?(registration) do
    case known_manifest(registration.coverage_id, registration.case_id) do
      nil -> false
      manifest -> registration.invariant_id != manifest.invariant_id
    end
  end

  defp duplicate_registration_errors(ids, registrations) do
    []
    |> maybe_add(duplicate?(ids), :duplicate_case)
    |> maybe_add(duplicate?(Enum.map(registrations, & &1.invariant_id)), :duplicate_invariant)
  end

  defp self_test_manifest(case_id, cut_point) do
    {timeout_ms, timeout_override_reason} = self_test_timeout(case_id)

    base = %{
      coverage_id: "harness",
      case_id: case_id,
      invariant_id: case_id,
      source:
        if(
          String.starts_with?(case_id, "cut.raise") or
            String.starts_with?(case_id, "cut.terminate"),
          do: "P8-04 failure seam model",
          else: "P8-04 infrastructure self-test manifest"
        ),
      version: "1.0.0",
      boundary: "test_infrastructure",
      cut_point: cut_point,
      assertion_ids: [case_id <> ".verified"],
      timeout_ms: timeout_ms,
      timeout_override_reason: timeout_override_reason,
      expected:
        "the registered P8-04 infrastructure check completes and its required assertion matches"
    }

    Map.put(base, :digest, digest(base))
  end

  defp self_test_timeout("result.broken_invariant_exit"),
    do: {60_000, "nested proof CLI subprocess"}

  defp self_test_timeout("production.exclusion"),
    do: {240_000, "isolated production build and runtime probe"}

  defp self_test_timeout(_case_id), do: {10_000, nil}

  defp known_manifest("harness", case_id),
    do: Enum.find(required().self_test.cases, &(&1.case_id == case_id))

  defp known_manifest(coverage_id, case_id) do
    case Map.get(business_manifests(), coverage_id) do
      %{cases: cases} when is_list(cases) -> Enum.find(cases, &(&1.case_id == case_id))
      _ -> nil
    end
  end

  defp business_manifests,
    do:
      NewYou.Proof.P805Catalog.manifests()
      |> Map.merge(NewYou.Proof.P807Catalog.manifests())
      |> Map.merge(NewYou.Proof.P809Catalog.manifests())
      |> Map.merge(NewYou.Proof.P809MagicCatalog.manifests())
      |> Map.merge(NewYou.Proof.P811Catalog.manifests())
      |> Map.merge(NewYou.Proof.P813Catalog.manifests())

  defp digest(term) do
    :crypto.hash(:sha256, :erlang.term_to_binary(term, [:deterministic]))
    |> Base.encode16(case: :lower)
  end

  defp valid_label?(value),
    do: byte_size(value) in 1..128 and Regex.match?(~r/^[A-Za-z0-9_.:-]+$/, value)

  defp duplicate?(values), do: length(values) != length(Enum.uniq(values))
  defp maybe_add(errors, true, reason), do: [reason | errors]
  defp maybe_add(errors, false, _reason), do: errors

  @type registration :: %{
          required(:coverage_id) => String.t(),
          required(:case_id) => String.t(),
          required(:invariant_id) => String.t(),
          required(:callback) => (-> term()),
          required(:manifest) => map()
        }
end
