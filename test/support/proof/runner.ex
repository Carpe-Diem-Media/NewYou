Code.require_file("../../proof/self_test.exs", __DIR__)

defmodule NewYou.Proof.Runner do
  @external_resource Path.expand("../../proof/self_test.exs", __DIR__)

  @moduledoc """
  Deterministic P8-04 proof runner. Coverage completeness comes from compiled
  manifests, including the bounded P8-05 cases.
  """

  alias NewYou.Proof.{Catalog, CutPoints, FullCatalog, Result, SelfTest}

  @modes %{
    "harness_self_test" => :harness_self_test,
    "tb001" => :tb001,
    "diagnostic" => :diagnostic
  }

  @fixture_cases %{
    broken_invariant: {"cut.raise.transaction.before_commit", "broken_invariant"},
    callback_exception: {"result.callback_failures", "callback_exception"},
    callback_exit: {"result.callback_failures", "callback_exit"},
    callback_throw: {"result.callback_failures", "callback_throw"},
    callback_timeout: {"result.callback_failures", "callback_timeout"},
    cleanup_failure: {"provider.authentication_fixtures", "cleanup_failure"}
  }

  @self_test_options [:root]
  @diagnostic_options [:root, :case_ids, :fixture]

  @spec parse_args([String.t()]) ::
          {:ok,
           %{mode: atom(), output: String.t(), case_ids: [String.t()], fixture: atom() | nil}}
          | {:error, atom()}
  def parse_args(args) when is_list(args) do
    case OptionParser.parse(args,
           strict: [mode: :string, output: :string, case: :keep, fixture: :string]
         ) do
      {options, [], []} -> normalize_options(options)
      _ -> {:error, :invalid_arguments}
    end
  rescue
    _ -> {:error, :invalid_arguments}
  end

  def parse_args(_args), do: {:error, :invalid_arguments}

  @spec run(Result.mode(), keyword()) :: map()
  def run(mode, opts \\ [])

  def run(:tb001, []) do
    case executing_project_root() do
      root when is_binary(root) ->
        run_with_metadata(:tb001, root, fn -> run_full_catalog() end)

      _ ->
        failure_envelope(:tb001, nil, "runner.project_unavailable")
    end
  rescue
    _error -> failure_envelope(:tb001, executing_project_root(), "runner.failure")
  catch
    _kind, _reason -> failure_envelope(:tb001, executing_project_root(), "runner.failure")
  end

  def run(:tb001, _opts),
    do: failure_envelope(:tb001, executing_project_root(), "runner.unsupported_option")

  def run(mode, opts) when mode in [:harness_self_test, :diagnostic] and is_list(opts) do
    root = option_root(opts)

    cond do
      not valid_run_options?(mode, opts) ->
        failure_envelope(mode, root, "runner.unsupported_option")

      not valid_run_fixture?(mode, opts) ->
        failure_envelope(mode, root, "runner.invalid_fixture")

      true ->
        run_mode(mode, opts, root)
    end
  rescue
    _error -> failure_envelope(mode, option_root(opts), "runner.failure")
  catch
    _kind, _reason -> failure_envelope(mode, option_root(opts), "runner.failure")
  end

  def run(mode, _opts) when mode in [:harness_self_test, :diagnostic],
    do: failure_envelope(mode, File.cwd!(), "runner.unsupported_option")

  def run(_mode, _opts), do: failure_envelope(:diagnostic, File.cwd!(), "runner.invalid_mode")

  defp run_with_metadata(mode, root, execute) do
    before = capture_metadata(root)
    {results, cleanup} = execute.()
    after_run = capture_source(root)
    metadata = combine_metadata(before, after_run)
    build_result(mode, results, cleanup, metadata)
  end

  defp run_mode(:harness_self_test, _opts, root) do
    run_with_metadata(:harness_self_test, root, fn ->
      run_self_test(self_test_case_ids(), root)
    end)
  end

  defp run_mode(:diagnostic, opts, root) do
    run_with_metadata(:diagnostic, root, fn ->
      run_self_test(diagnostic_case_ids(opts), root, Keyword.get(opts, :fixture))
    end)
  end

  @doc false
  @spec evaluate_full(map(), [map()], boolean(), map()) :: map()
  def evaluate_full(manifests, observed_cases, metadata_complete?, cleanup)
      when is_map(manifests) and is_list(observed_cases) and is_boolean(metadata_complete?) and
             is_map(cleanup) do
    observations = Enum.group_by(observed_cases, &observation_key/1)
    entries = evaluate_full_entries(manifests, observations, observed_cases)
    checks = Enum.map(entries, &if(&1.verdict == "PASS", do: :pass, else: :fail))
    cleanup_status = if cleanup_confirmed?(cleanup), do: :pass, else: :fail

    outcome =
      Result.verdict(
        mode: :tb001,
        metadata_complete: metadata_complete?,
        checks: checks,
        cleanup: cleanup_status
      )

    reason_codes =
      []
      |> add_reason(not metadata_complete?, "metadata.unavailable")
      |> add_reason(cleanup_status == :fail, "cleanup.failed")
      |> add_reason(outcome.exit_code == 1, "coverage.incomplete")

    %{
      entries: entries,
      verdict: outcome.overall_verdict,
      exit_code: outcome.exit_code,
      reason_codes: reason_codes
    }
  rescue
    _ ->
      %{
        entries: Enum.map(Catalog.coverage_inventory(), &invalid_manifest_entry/1),
        verdict: "FAIL",
        exit_code: 2,
        reason_codes: ["runner.failure"]
      }
  end

  def evaluate_full(_manifests, _observed_cases, _metadata_complete?, _cleanup) do
    %{
      entries: Enum.map(Catalog.coverage_inventory(), &invalid_manifest_entry/1),
      verdict: "FAIL",
      exit_code: 2,
      reason_codes: ["runner.invalid_input"]
    }
  end

  defp evaluate_full_entries(manifests, observations, observed_cases) do
    {entries, _stopped?} =
      Enum.map_reduce(Catalog.coverage_inventory(), false, fn coverage_id, stopped? ->
        evaluate_full_entry(coverage_id, manifests, observations, stopped?)
      end)

    mark_unexpected_observations(entries, manifests, observed_cases)
  end

  defp evaluate_full_entry(coverage_id, manifests, observations, stopped?) do
    case Map.get(manifests, coverage_id) do
      nil ->
        {missing_manifest_entry(coverage_id), stopped?}

      manifest when not is_map(manifest) ->
        {invalid_manifest_entry(coverage_id), stopped?}

      manifest ->
        evaluate_full_manifest_entry(coverage_id, manifest, observations, stopped?)
    end
  end

  defp evaluate_full_manifest_entry(coverage_id, manifest, observations, stopped?) do
    cond do
      not valid_full_manifest?(coverage_id, manifest) ->
        {invalid_manifest_entry(coverage_id), stopped?}

      stopped? ->
        {not_run_entry(coverage_id, manifest), true}

      true ->
        evaluate_full_family(coverage_id, manifest, observations)
    end
  end

  @doc false
  @spec execute_full_catalog(map(), [Catalog.registration()]) :: {[map()], map()}
  def execute_full_catalog(manifests, registrations)
      when is_map(manifests) and is_list(registrations) do
    case FullCatalog.execute(manifests, registrations) do
      {:ok, observed_cases, cleanup} ->
        evaluation = evaluate_full(manifests, observed_cases, true, cleanup)
        {Enum.map(evaluation.entries, &full_entry_document/1), cleanup}

      {:error, _reasons} ->
        invalid_registration_catalog(manifests)
    end
  end

  defp invalid_registration_catalog(manifests) do
    cleanup = failure_cleanup()

    evaluation =
      evaluate_full(
        manifests,
        [],
        false,
        cleanup
      )

    results =
      Enum.map(evaluation.entries, fn entry ->
        full_entry_document(%{
          entry
          | verdict: "FAIL",
            status: if(entry.status == "missing", do: "missing", else: "error"),
            reason_codes: Enum.uniq(entry.reason_codes ++ ["registration.invalid"])
        })
      end)

    {results, cleanup}
  end

  defp run_full_catalog do
    manifests = Catalog.required().business_manifests
    registrations = Catalog.compiled_business_registrations()
    execute_full_catalog(manifests, registrations)
  end

  defp evaluate_full_family(coverage_id, manifest, observations) do
    {cases, stopped?} =
      Enum.map_reduce(Map.get(manifest, :cases), false, fn manifest_case, case_stopped? ->
        evaluate_full_case(coverage_id, manifest_case, observations, case_stopped?)
      end)

    passed? =
      manifest.scope == :complete and cases != [] and Enum.all?(cases, &(&1.verdict == "PASS"))

    executed? = Enum.any?(cases, &(&1.status == "completed"))
    all_not_run? = cases != [] and Enum.all?(cases, &(&1.status == "not_run"))
    status = family_status(all_not_run?, executed?)

    reasons =
      cases
      |> Enum.flat_map(& &1.reason_codes)
      |> Kernel.++(manifest_reasons(manifest))
      |> Enum.uniq()

    entry = %{
      coverage_id: coverage_id,
      manifest_sha256: Map.get(manifest, :digest),
      required_case_ids: Enum.map(Map.get(manifest, :cases), &Map.get(&1, :case_id)),
      status: status,
      verdict: if(passed?, do: "PASS", else: "FAIL"),
      reason_codes: if(passed?, do: [], else: reasons),
      cases: cases
    }

    {entry, stopped?}
  end

  defp evaluate_full_case(_coverage_id, manifest_case, _observations, true),
    do: {not_run_case(manifest_case), true}

  defp evaluate_full_case(coverage_id, manifest_case, observations, false) do
    case Map.get(observations, {coverage_id, Map.get(manifest_case, :case_id)}, []) do
      [] ->
        {missing_case(manifest_case), true}

      [observation] ->
        case_result = evaluate_observed_case(manifest_case, observation)
        {case_result, case_result.verdict == "FAIL"}

      _duplicates ->
        {failed_case(manifest_case, "completed", "case.duplicate"), true}
    end
  end

  defp family_status(true, _executed?), do: "not_run"
  defp family_status(false, true), do: "completed"
  defp family_status(false, false), do: "missing"

  defp evaluate_observed_case(manifest_case, observation) when is_map(observation) do
    observed_status = observation_value(observation, "status")
    observed_verdict = observation_value(observation, "verdict")
    observed_assertions = observation_value(observation, "assertion_ids")
    expected_assertions = Map.get(manifest_case, :assertion_ids)
    reasons = observed_case_reasons(manifest_case, observation, expected_assertions)

    passed? = observed_verdict == "PASS" and reasons == []
    assertion_ids = normalized_assertions(observed_assertions, expected_assertions)

    %{
      case_id: Map.get(manifest_case, :case_id),
      invariant_id: Map.get(manifest_case, :invariant_id),
      boundary: Map.get(manifest_case, :boundary),
      cut_point: Map.get(manifest_case, :cut_point),
      race_id: Map.get(manifest_case, :race_id),
      status: if(observed_status == "completed", do: "completed", else: "error"),
      verdict: if(passed?, do: "PASS", else: "FAIL"),
      expected: Map.get(manifest_case, :expected),
      observations: safe_observations(observation_value(observation, "observations")),
      assertion_ids: assertion_ids,
      assertions_executed: length(assertion_ids),
      duration_ms: non_negative_integer(observation_value(observation, "duration_ms"), 0),
      timeout_ms: positive_integer(Map.get(manifest_case, :timeout_ms), 10_000),
      timeout_override_reason: Map.get(manifest_case, :timeout_override_reason),
      reason_codes: if(passed?, do: [], else: Enum.uniq(reasons))
    }
  end

  defp evaluate_observed_case(manifest_case, _observation),
    do: failed_case(manifest_case, "error", "case.invalid")

  defp observed_case_reasons(manifest_case, observation, expected_assertions) do
    reasons =
      []
      |> add_reason(
        observation_value(observation, "invariant_id") != Map.get(manifest_case, :invariant_id),
        "invariant.mismatch"
      )
      |> add_reason(
        observation_value(observation, "assertion_ids") != expected_assertions or
          observation_value(observation, "assertions_executed") != length(expected_assertions),
        "assertion.mismatch"
      )
      |> add_reason(
        observation_value(observation, "status") != "completed" or
          observation_value(observation, "verdict") not in ["PASS", "FAIL"],
        "case.invalid"
      )

    if observation_value(observation, "verdict") == "FAIL" do
      case safe_reason_codes(observation_value(observation, "reason_codes")) do
        [] -> reasons ++ ["assertion.failed"]
        observed_reasons -> Enum.uniq(reasons ++ observed_reasons)
      end
    else
      reasons
    end
  end

  defp missing_manifest_entry(coverage_id) do
    %{
      coverage_id: coverage_id,
      manifest_sha256: nil,
      required_case_ids: [],
      status: "missing",
      verdict: "FAIL",
      reason_codes: ["missing.manifest"],
      cases: []
    }
  end

  defp invalid_manifest_entry(coverage_id) do
    %{
      coverage_id: coverage_id,
      manifest_sha256: nil,
      required_case_ids: [],
      status: "missing",
      verdict: "FAIL",
      reason_codes: ["manifest.invalid"],
      cases: []
    }
  end

  defp not_run_entry(coverage_id, manifest) do
    cases = Enum.map(Map.get(manifest, :cases), &not_run_case/1)

    %{
      coverage_id: coverage_id,
      manifest_sha256: Map.get(manifest, :digest),
      required_case_ids: Enum.map(Map.get(manifest, :cases), &Map.get(&1, :case_id)),
      status: "not_run",
      verdict: "FAIL",
      reason_codes: ["coverage.not_run" | manifest_reasons(manifest)],
      cases: cases
    }
  end

  # Executability and full-family completeness are separate reviewed facts.
  defp manifest_reasons(%{scope: :partial}), do: ["manifest.partial"]
  defp manifest_reasons(_manifest), do: []

  defp not_run_case(manifest_case) do
    case_from_manifest(manifest_case, "not_run", "FAIL", ["coverage.not_run"], [])
  end

  defp missing_case(manifest_case) do
    case_from_manifest(manifest_case, "missing", "FAIL", ["missing.case"], [])
  end

  defp failed_case(manifest_case, status, reason) do
    case_from_manifest(manifest_case, status, "FAIL", [reason], [])
  end

  defp case_from_manifest(manifest_case, status, verdict, reasons, assertion_ids) do
    %{
      case_id: Map.get(manifest_case, :case_id),
      invariant_id: Map.get(manifest_case, :invariant_id),
      boundary: Map.get(manifest_case, :boundary),
      cut_point: Map.get(manifest_case, :cut_point),
      race_id: Map.get(manifest_case, :race_id),
      status: status,
      verdict: verdict,
      expected: Map.get(manifest_case, :expected),
      observations: [],
      assertion_ids: assertion_ids,
      assertions_executed: length(assertion_ids),
      duration_ms: 0,
      timeout_ms: positive_integer(Map.get(manifest_case, :timeout_ms), 10_000),
      timeout_override_reason: Map.get(manifest_case, :timeout_override_reason),
      reason_codes: reasons
    }
  end

  defp valid_full_manifest?(coverage_id, manifest) when is_map(manifest) do
    case_ids = Enum.map(Map.get(manifest, :cases, []), &Map.get(&1, :case_id))

    Map.get(manifest, :scope) in [:partial, :complete] and
      Map.get(manifest, :coverage_id, coverage_id) == coverage_id and
      is_binary(Map.get(manifest, :version)) and Map.get(manifest, :version) != "" and
      valid_sha256?(Map.get(manifest, :digest)) and is_list(Map.get(manifest, :cases)) and
      case_ids != [] and length(case_ids) == length(Enum.uniq(case_ids)) and
      Enum.all?(Map.get(manifest, :cases), &valid_manifest_case?/1)
  rescue
    _ -> false
  end

  defp valid_full_manifest?(_coverage_id, _manifest), do: false

  defp valid_manifest_case?(manifest_case) when is_map(manifest_case) do
    valid_manifest_case_identity?(manifest_case) and
      valid_manifest_case_cut_point?(manifest_case) and
      valid_manifest_case_assertions?(manifest_case) and
      valid_manifest_case_expected?(manifest_case)
  end

  defp valid_manifest_case?(_manifest_case), do: false

  defp valid_manifest_case_identity?(manifest_case) do
    valid_label?(Map.get(manifest_case, :case_id)) and
      valid_label?(Map.get(manifest_case, :invariant_id)) and
      valid_label?(Map.get(manifest_case, :boundary)) and
      (is_nil(Map.get(manifest_case, :race_id)) or valid_label?(Map.get(manifest_case, :race_id)))
  end

  defp valid_manifest_case_cut_point?(manifest_case) do
    is_nil(Map.get(manifest_case, :cut_point)) or
      Map.get(manifest_case, :cut_point) in CutPoints.names()
  end

  defp valid_manifest_case_assertions?(manifest_case) do
    assertion_ids = Map.get(manifest_case, :assertion_ids)

    is_list(assertion_ids) and assertion_ids != [] and
      length(assertion_ids) == length(Enum.uniq(assertion_ids)) and
      Enum.all?(assertion_ids, &valid_label?/1)
  end

  defp valid_manifest_case_expected?(manifest_case) do
    case Map.get(manifest_case, :expected) do
      expected when is_binary(expected) ->
        String.trim(expected) != "" and byte_size(expected) <= 512

      _ ->
        false
    end
  end

  defp mark_unexpected_observations(entries, manifests, observations) do
    unexpected_families =
      observations
      |> Enum.reject(fn observation ->
        coverage_id = observation_value(observation, "coverage_id")
        case_id = observation_value(observation, "case_id")
        manifest = Map.get(manifests, coverage_id)

        valid_full_manifest?(coverage_id, manifest) and
          Enum.any?(manifest.cases, &(&1.case_id == case_id))
      end)
      |> Enum.map(&observation_value(&1, "coverage_id"))
      |> Enum.uniq()

    mark_unexpected_families(entries, unexpected_families)
  end

  defp mark_unexpected_families(entries, []), do: entries

  defp mark_unexpected_families(entries, unexpected_families) do
    fallback_to_first_family? =
      Enum.any?(unexpected_families, &(&1 not in Catalog.coverage_inventory()))

    Enum.with_index(entries)
    |> Enum.map(&mark_unexpected_entry(&1, unexpected_families, fallback_to_first_family?))
  end

  defp mark_unexpected_entry({entry, index}, unexpected_families, fallback?) do
    if entry.coverage_id in unexpected_families or (fallback? and index == 0) do
      %{
        entry
        | verdict: "FAIL",
          reason_codes: Enum.uniq(entry.reason_codes ++ ["case.unexpected"])
      }
    else
      entry
    end
  end

  defp observation_key(observation) do
    {observation_value(observation, "coverage_id"), observation_value(observation, "case_id")}
  end

  defp observation_value(observation, key) when is_map(observation) do
    Map.get(observation, key, Map.get(observation, String.to_existing_atom(key)))
  rescue
    _ -> Map.get(observation, key)
  end

  defp observation_value(_observation, _key), do: nil

  defp valid_sha256?(value), do: is_binary(value) and Regex.match?(~r/^[0-9a-f]{64}$/, value)

  defp valid_label?(value),
    do: is_binary(value) and Regex.match?(~r/^[A-Za-z0-9_.:-]{1,128}$/, value)

  defp safe_reason_codes(codes) when is_list(codes) do
    Enum.filter(codes, &(is_binary(&1) and valid_label?(&1)))
  end

  defp safe_reason_codes(_codes), do: []

  defp normalized_assertions(assertions, expected) when is_list(assertions),
    do: Enum.filter(expected, &(&1 in assertions))

  defp normalized_assertions(_assertions, _expected), do: []

  defp safe_observations(observations) when is_list(observations) do
    Enum.filter(observations, fn
      %{"code" => code, "value" => value} ->
        valid_label?(code) and
          (is_boolean(value) or is_number(value) or
             (is_binary(value) and byte_size(value) <= 512))

      _ ->
        false
    end)
  end

  defp safe_observations(_observations), do: []

  defp non_negative_integer(value, _default) when is_integer(value) and value >= 0, do: value
  defp non_negative_integer(_value, default), do: default
  defp positive_integer(value, _default) when is_integer(value) and value > 0, do: value
  defp positive_integer(_value, default), do: default

  defp cleanup_confirmed?(cleanup) do
    observation_value(cleanup, "verdict") == "PASS" and
      Enum.all?(
        ~w(workers_stopped connections_released locks_released),
        &(observation_value(cleanup, &1) == true)
      )
  end

  defp full_entry_document(entry) do
    %{
      "coverage_id" => entry.coverage_id,
      "manifest_sha256" => entry.manifest_sha256,
      "required_case_ids" => entry.required_case_ids,
      "status" => entry.status,
      "verdict" => entry.verdict,
      "reason_codes" => entry.reason_codes,
      "cases" => Enum.map(entry.cases, &full_case_document/1)
    }
  end

  defp full_case_document(case_result) do
    %{
      "case_id" => case_result.case_id,
      "invariant_id" => case_result.invariant_id,
      "boundary" => case_result.boundary,
      "cut_point" => case_result.cut_point,
      "race_id" => case_result.race_id,
      "status" => case_result.status,
      "verdict" => case_result.verdict,
      "expected" => case_result.expected,
      "observations" => case_result.observations,
      "assertion_ids" => case_result.assertion_ids,
      "assertions_executed" => case_result.assertions_executed,
      "duration_ms" => case_result.duration_ms,
      "timeout_ms" => case_result.timeout_ms,
      "timeout_override_reason" => case_result.timeout_override_reason,
      "reason_codes" => case_result.reason_codes
    }
  end

  @spec run_cli([String.t()]) :: 0 | 1 | 2
  def run_cli(args) do
    with {:ok, %{mode: mode, output: output, case_ids: case_ids, fixture: fixture}} <-
           parse_args(args),
         true <- Mix.env() == :test do
      result =
        case mode do
          :tb001 -> run(:tb001)
          :harness_self_test -> run(:harness_self_test)
          :diagnostic -> run(:diagnostic, case_ids: case_ids, fixture: fixture)
        end

      case Result.validate(result, mode: mode) do
        :ok ->
          publish_result(output, result)

        {:error, _reasons} ->
          IO.puts(:stderr, "proof result validation failure")
          2
      end
    else
      false ->
        IO.puts(:stderr, "proof runner requires TEST environment")
        2

      {:error, :output_required} ->
        IO.puts(:stderr, "proof output path required")
        2

      {:error, :invalid_mode} ->
        IO.puts(:stderr, "proof mode invalid")
        2

      {:error, :unknown_case} ->
        IO.puts(:stderr, "proof case unknown")
        2

      {:error, :invalid_fixture} ->
        IO.puts(:stderr, "proof fixture invalid")
        2

      {:error, _reason} ->
        IO.puts(:stderr, "proof arguments invalid")
        2
    end
  rescue
    _error ->
      IO.puts(:stderr, "proof runner failure")
      2
  catch
    _kind, _reason ->
      IO.puts(:stderr, "proof runner failure")
      2
  end

  defp normalize_options(options) do
    modes = Keyword.get_values(options, :mode)
    outputs = Keyword.get_values(options, :output)
    case_ids = Keyword.get_values(options, :case)
    fixtures = Keyword.get_values(options, :fixture)

    cond do
      length(modes) != 1 ->
        {:error, :invalid_mode}

      length(outputs) != 1 or not valid_output?(List.first(outputs)) ->
        {:error, :output_required}

      true ->
        with {:ok, mode} <- Map.fetch(@modes, List.first(modes)),
             :ok <- validate_case_selection(mode, case_ids),
             {:ok, fixture} <- validate_fixture_selection(mode, case_ids, fixtures) do
          {:ok, %{mode: mode, output: List.first(outputs), case_ids: case_ids, fixture: fixture}}
        else
          :error -> {:error, :invalid_mode}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp publish_result(output, result) do
    case Result.write_atomic(output, result) do
      :ok ->
        IO.puts("proof result: #{result["overall_verdict"]} (#{result["exit_code"]})")
        result["exit_code"]

      {:error, :output_failure} ->
        IO.puts(:stderr, "proof output failure")
        2
    end
  end

  defp validate_case_selection(:diagnostic, case_ids) do
    required = MapSet.new(Enum.map(Catalog.required().self_test.cases, & &1.case_id))

    cond do
      length(case_ids) != length(Enum.uniq(case_ids)) -> {:error, :duplicate_case}
      Enum.any?(case_ids, &(not MapSet.member?(required, &1))) -> {:error, :unknown_case}
      true -> :ok
    end
  end

  defp validate_case_selection(_mode, []), do: :ok
  defp validate_case_selection(_mode, _case_ids), do: {:error, :invalid_arguments}

  defp validate_fixture_selection(_mode, _case_ids, []), do: {:ok, nil}

  defp validate_fixture_selection(:diagnostic, [case_id], [fixture_name]) do
    case Enum.find(@fixture_cases, fn {_fixture, {expected_case, expected_name}} ->
           case_id == expected_case and fixture_name == expected_name
         end) do
      {fixture, _expected} -> {:ok, fixture}
      nil -> {:error, :invalid_fixture}
    end
  end

  defp validate_fixture_selection(_mode, _case_ids, _fixtures),
    do: {:error, :invalid_fixture}

  defp valid_run_fixture?(mode, opts) do
    case Keyword.get(opts, :fixture) do
      nil ->
        true

      fixture ->
        case Map.get(@fixture_cases, fixture) do
          {case_id, _fixture_name} ->
            mode == :diagnostic and Keyword.get(opts, :case_ids) == [case_id]

          nil ->
            false
        end
    end
  end

  defp valid_run_options?(mode, opts) do
    allowed =
      case mode do
        :harness_self_test -> @self_test_options
        :diagnostic -> @diagnostic_options
      end

    if Keyword.keyword?(opts) do
      keys = Keyword.keys(opts)

      length(keys) == length(Enum.uniq(keys)) and Enum.all?(keys, &(&1 in allowed))
    else
      false
    end
  end

  defp option_root(opts) do
    if Keyword.keyword?(opts), do: Keyword.get(opts, :root, File.cwd!()), else: File.cwd!()
  end

  defp executing_project_root do
    case Mix.Project.project_file() do
      path when is_binary(path) -> path |> Path.dirname() |> Path.expand()
      _ -> nil
    end
  end

  defp valid_output?(path),
    do: is_binary(path) and byte_size(path) in 1..1_024 and String.trim(path) != ""

  defp self_test_case_ids, do: Enum.map(Catalog.required().self_test.cases, & &1.case_id)

  defp run_self_test(case_ids, root, fixture \\ nil) do
    {cases, cleanup} = SelfTest.run(case_ids, root: root, fixture: fixture)

    passed? =
      cases != [] and length(cases) == length(case_ids) and
        Enum.all?(cases, &(&1["verdict"] == "PASS"))

    entry = %{
      "coverage_id" => "harness",
      "manifest_sha256" => Catalog.required().self_test.digest,
      "required_case_ids" => case_ids,
      "status" => if(passed?, do: "completed", else: "error"),
      "verdict" => if(passed?, do: "PASS", else: "FAIL"),
      "reason_codes" => if(passed?, do: [], else: ["self_test.incomplete"]),
      "cases" => cases
    }

    {[entry], cleanup}
  end

  defp diagnostic_case_ids(opts) do
    case Keyword.get(opts, :case_ids, []) do
      [] -> self_test_case_ids()
      case_ids -> case_ids
    end
  end

  defp capture_metadata(root) do
    source = Result.capture_source(root)
    runtime = Result.capture_runtime()

    dependencies =
      case Result.capture_dependencies(root) do
        {:ok, entries} -> entries
        {:error, _reason} -> []
      end

    postgresql =
      case Result.capture_postgresql() do
        {:ok, version} -> version
        {:error, _reason} -> nil
      end

    %{source: source, runtime: runtime, dependencies: dependencies, postgresql: postgresql}
  end

  defp capture_source(root), do: Result.capture_source(root)

  defp combine_metadata(before, after_source) do
    source_before = before.source
    runtime = before.runtime
    dependencies = before.dependencies

    %{
      complete:
        metadata_sources_complete?(source_before, after_source) and
          metadata_dependencies_complete?(dependencies) and
          metadata_postgresql_complete?(before.postgresql) and metadata_runtime_complete?(runtime),
      source_before: source_before,
      source_after: after_source,
      runtime: runtime,
      dependencies: dependencies,
      postgresql: before.postgresql,
      mix_env: if(Mix.env() == :test, do: "test", else: nil)
    }
  end

  defp metadata_sources_complete?(before, after_source),
    do: complete_source?(before) and complete_source?(after_source)

  defp metadata_dependencies_complete?(dependencies),
    do: dependencies != [] and dependency_entries_complete?(dependencies)

  defp metadata_postgresql_complete?(version),
    do: is_binary(version) and valid_version?(version)

  defp metadata_runtime_complete?(runtime),
    do: Enum.all?(Map.values(runtime), &(is_binary(&1) and &1 != "")) and Mix.env() == :test

  defp complete_source?(source),
    do: is_binary(source.head) and is_boolean(source.clean) and is_binary(source.lock_sha256)

  defp dependency_entries_complete?(entries) do
    entries != [] and Enum.all?(entries, &complete_dependency_entry?/1)
  rescue
    _ -> false
  end

  defp complete_dependency_entry?(entry) do
    is_binary(entry.name) and is_binary(entry.source) and is_boolean(entry.runtime_required) and
      case {entry.runtime_required, entry.source, entry.locked_version, entry.loaded_version} do
        {true, "hex", locked_version, loaded_version} when is_binary(loaded_version) ->
          locked_version == loaded_version

        {true, _source, _locked_version, loaded_version} ->
          is_binary(loaded_version)

        {false, _source, _locked_version, nil} ->
          true

        _ ->
          false
      end
  rescue
    _ -> false
  end

  defp valid_version?(version), do: Regex.match?(~r/^\d+(\.\d+)+/, version)

  defp build_result(mode, results, cleanup, metadata) do
    source_changed? =
      metadata.source_before.head != metadata.source_after.head or
        metadata.source_before.lock_sha256 != metadata.source_after.lock_sha256

    dirty_full? =
      mode == :tb001 and
        (metadata.source_before.clean != true or metadata.source_after.clean != true)

    cleanup_ok? = cleanup["verdict"] == "PASS"
    selected_pass? = results != [] and Enum.all?(results, &(&1["verdict"] == "PASS"))
    timed_out? = results_include_timeout?(results)

    {verdict, exit_code} =
      overall_verdict(
        metadata.complete,
        cleanup_ok?,
        source_changed?,
        dirty_full?,
        selected_pass?,
        timed_out?
      )

    reason_codes =
      result_reasons(
        metadata.complete,
        cleanup_ok?,
        source_changed?,
        dirty_full?,
        selected_pass?,
        timed_out?
      )

    result_document(mode, results, cleanup, metadata, verdict, exit_code, reason_codes)
  end

  defp overall_verdict(
         metadata_complete?,
         cleanup_ok?,
         source_changed?,
         dirty_full?,
         selected_pass?,
         timed_out?
       ) do
    cond do
      not metadata_complete? or not cleanup_ok? or source_changed? or dirty_full? -> {"FAIL", 2}
      timed_out? -> {"FAIL", 2}
      not selected_pass? -> {"FAIL", 1}
      true -> {"PASS", 0}
    end
  end

  defp result_reasons(
         metadata_complete?,
         cleanup_ok?,
         source_changed?,
         dirty_full?,
         selected_pass?,
         timed_out?
       ) do
    []
    |> add_reason(not metadata_complete?, "metadata.unavailable")
    |> add_reason(source_changed?, "source.changed")
    |> add_reason(dirty_full?, "source.dirty")
    |> add_reason(not cleanup_ok?, "cleanup.failed")
    |> add_reason(timed_out?, "timeout.expired")
    |> add_reason(not selected_pass?, "coverage.incomplete")
  end

  defp results_include_timeout?(results) do
    Enum.any?(results, fn result ->
      Enum.any?(result["cases"] || [], &(&1["status"] == "timeout"))
    end)
  end

  defp result_document(mode, results, cleanup, metadata, verdict, exit_code, reason_codes) do
    %{
      "schema_version" => "1.0.0",
      "run_id" => run_id(),
      "mode" => Atom.to_string(mode),
      "contract" => "TB-001/v0.1.3",
      "metadata_complete" => metadata.complete,
      "git" => %{
        "head_before" => metadata.source_before.head,
        "head_after" => metadata.source_after.head,
        "clean_before" => metadata.source_before.clean,
        "clean_after" => metadata.source_after.clean,
        "lock_sha256_before" => metadata.source_before.lock_sha256,
        "lock_sha256_after" => metadata.source_after.lock_sha256
      },
      "runtime" => %{
        "elixir" => metadata.runtime.elixir,
        "otp" => metadata.runtime.otp,
        "erts" => metadata.runtime.erts,
        "postgresql" => metadata.postgresql,
        "mix_env" => metadata.mix_env
      },
      "dependencies" => metadata.dependencies,
      "coverage_inventory" => Catalog.coverage_inventory(),
      "results" => results,
      "cleanup" => cleanup,
      "overall_verdict" => verdict,
      "exit_code" => exit_code,
      "reason_codes" => reason_codes
    }
  end

  defp missing_business_results do
    manifests = Catalog.required().business_manifests

    Enum.map(Catalog.coverage_inventory(), fn coverage_id ->
      case Map.fetch(manifests, coverage_id) do
        {:ok, manifest} -> full_entry_document(not_run_entry(coverage_id, manifest))
        :error -> full_entry_document(missing_manifest_entry(coverage_id))
      end
    end)
  end

  defp failure_envelope(mode, root, reason) do
    metadata =
      try do
        before = Result.capture_source(root)
        after_source = Result.capture_source(root)

        %{
          complete: false,
          source_before: before,
          source_after: after_source,
          runtime: Result.capture_runtime(),
          dependencies: [],
          postgresql: nil,
          mix_env: if(Mix.env() == :test, do: "test", else: nil)
        }
      rescue
        _ ->
          empty_metadata()
      end

    failure_results =
      if mode == :tb001,
        do: missing_business_results(),
        else: []

    build_result(mode, failure_results, failure_cleanup(), metadata)
    |> Map.update!("reason_codes", &Enum.uniq([reason | &1]))
    |> Map.put("exit_code", 2)
  rescue
    _ -> %{}
  end

  defp empty_metadata do
    source = %{head: nil, clean: nil, lock_sha256: nil}

    %{
      complete: false,
      source_before: source,
      source_after: source,
      runtime: %{elixir: nil, otp: nil, erts: nil},
      dependencies: [],
      postgresql: nil,
      mix_env: nil
    }
  end

  defp failure_cleanup do
    %{
      "verdict" => "FAIL",
      "workers_stopped" => false,
      "connections_released" => false,
      "locks_released" => false,
      "reason_codes" => ["cleanup.unconfirmed"]
    }
  end

  defp add_reason(reasons, true, reason), do: reasons ++ [reason]
  defp add_reason(reasons, false, _reason), do: reasons

  defp run_id do
    "p8-04-" <> Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
  end
end
