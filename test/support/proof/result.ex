defmodule NewYou.Proof.Result do
  @moduledoc """
  Runner-owned assertion recording and fail-closed P8-04 result validation.

  Callback observations stay in the scenario controller. This module emits only
  assertion identifiers and fixed reason codes into result artifacts.
  """

  alias NewYou.Proof.{Catalog, Scenario}

  @schema_version "1.0.0"
  @contract "TB-001/v0.1.3"
  @statuses ["completed", "missing", "not_run", "timeout", "error"]
  @verdicts ["PASS", "FAIL"]
  @top_keys ~w(schema_version run_id mode contract metadata_complete git runtime dependencies coverage_inventory results cleanup overall_verdict exit_code reason_codes)
  @git_keys ~w(head_before head_after clean_before clean_after lock_sha256_before lock_sha256_after)
  @runtime_keys ~w(elixir otp erts postgresql mix_env)
  @dependency_keys ~w(name source locked_version loaded_version revision runtime_required)
  @result_keys ~w(coverage_id manifest_sha256 required_case_ids status verdict reason_codes cases)
  @case_keys ~w(case_id invariant_id boundary cut_point race_id status verdict expected observations assertion_ids assertions_executed duration_ms timeout_ms timeout_override_reason reason_codes)
  @cleanup_keys ~w(verdict workers_stopped connections_released locks_released reason_codes)
  @max_artifact_bytes 1_048_576

  @type mode :: :harness_self_test | :tb001 | :diagnostic

  @spec expect!(Scenario.t(), String.t(), String.t(), term(), term()) :: term()
  def expect!(%Scenario{} = scenario, case_id, assertion_id, observed, expected)
      when is_binary(case_id) and is_binary(assertion_id) do
    case Scenario.record_assertion(scenario, case_id, assertion_id, observed, expected) do
      :ok -> observed
      {:error, _reason} -> raise RuntimeError, "proof assertion failed"
    end
  end

  @spec verdict(keyword()) :: %{overall_verdict: String.t(), exit_code: 0 | 1 | 2}
  def verdict(opts) when is_list(opts) do
    mode = Keyword.get(opts, :mode)
    metadata_complete? = Keyword.get(opts, :metadata_complete) == true
    cleanup_ok? = Keyword.get(opts, :cleanup) == :pass
    checks = Keyword.get(opts, :checks, [])

    {verdict, code} =
      cond do
        mode not in [:harness_self_test, :tb001, :diagnostic] -> {"FAIL", 2}
        not metadata_complete? -> {"FAIL", 2}
        not cleanup_ok? -> {"FAIL", 2}
        checks == [] or not Enum.all?(checks, &(&1 == :pass)) -> {"FAIL", 1}
        true -> {"PASS", 0}
      end

    %{overall_verdict: verdict, exit_code: code}
  end

  @spec capture_source(Path.t()) :: %{
          head: String.t() | nil,
          clean: boolean() | nil,
          lock_sha256: String.t() | nil
        }
  def capture_source(root \\ File.cwd!()) when is_binary(root) do
    head = git_value(root, ["rev-parse", "--verify", "HEAD"]) |> valid_output_sha()

    clean =
      case System.cmd("git", ["-C", root, "status", "--porcelain", "--untracked-files=all"],
             stderr_to_stdout: true
           ) do
        {output, 0} -> output == ""
        _ -> nil
      end

    lock_sha256 =
      case File.read(Path.join(root, "mix.lock")) do
        {:ok, contents} -> sha256(contents)
        {:error, _} -> nil
      end

    %{head: head, clean: clean, lock_sha256: lock_sha256}
  end

  @spec capture_runtime() :: %{elixir: String.t(), otp: String.t(), erts: String.t()}
  def capture_runtime do
    %{
      elixir: System.version(),
      otp: List.to_string(:erlang.system_info(:otp_release)),
      erts: List.to_string(:erlang.system_info(:version))
    }
  end

  @spec capture_dependencies(Path.t()) :: {:ok, [map()]} | {:error, atom()}
  def capture_dependencies(root \\ File.cwd!()) when is_binary(root) do
    lock_path = Path.join(root, "mix.lock")

    with {:ok, contents} <- File.read(lock_path),
         true <- String.trim(contents) != "",
         lock when is_map(lock) and map_size(lock) > 0 <- Mix.Dep.Lock.read(lock_path),
         {:ok, runtime_roles} <- expected_runtime_roles(Map.keys(lock)) do
      loaded =
        Map.new(Application.loaded_applications(), fn {app, _description, version} ->
          {Atom.to_string(app), List.to_string(version)}
        end)

      classify_dependencies(Map.to_list(lock), runtime_roles, loaded)
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :lock_invalid}
    end
  rescue
    _ -> {:error, :lock_invalid}
  end

  @doc false
  @spec classify_dependencies([{atom() | String.t(), tuple()}], map(), map()) ::
          {:ok, [map()]} | {:error, atom()}
  def classify_dependencies(lock_entries, runtime_roles, loaded)
      when is_list(lock_entries) and is_map(runtime_roles) and is_map(loaded) do
    names = Enum.map(lock_entries, fn {name, _entry} -> dependency_name(name) end)

    cond do
      lock_entries == [] or Enum.any?(names, &is_nil/1) ->
        {:error, :lock_invalid}

      length(names) != length(Enum.uniq(names)) ->
        {:error, :duplicate_dependency}

      Enum.any?(names, fn name -> not is_boolean(Map.get(runtime_roles, name)) end) ->
        {:error, :runtime_role_unavailable}

      true ->
        entries =
          lock_entries
          |> Enum.sort_by(fn {name, _entry} -> dependency_name(name) end)
          |> Enum.map(fn {name, entry} ->
            name = dependency_name(name)
            dependency_entry(name, entry, Map.fetch!(runtime_roles, name), loaded)
          end)

        if Enum.any?(entries, &is_nil/1),
          do: {:error, :unreproducible_lock_entry},
          else: {:ok, entries}
    end
  rescue
    _ -> {:error, :lock_invalid}
  end

  def classify_dependencies(_lock_entries, _runtime_roles, _loaded),
    do: {:error, :lock_invalid}

  defp expected_runtime_roles(lock_names) do
    dependencies = Mix.Dep.cached()

    case validate_reproducible_dependencies(dependencies, lock_names) do
      :ok -> derive_runtime_roles(dependencies, lock_names)
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:error, :runtime_role_unavailable}
  end

  defp validate_reproducible_dependencies(dependencies, lock_names) do
    flattened = flatten_mix_dependencies(dependencies)
    locked_names = MapSet.new(Enum.map(lock_names, &Atom.to_string/1))

    invalid_source? = Enum.any?(flattened, &local_dependency?/1)

    unlocked_dependency? =
      Enum.any?(flattened, &(not MapSet.member?(locked_names, Atom.to_string(&1.app))))

    if invalid_source? or unlocked_dependency?,
      do: {:error, :unreproducible_dependency},
      else: :ok
  end

  defp derive_runtime_roles(dependencies, lock_names) do
    roles = Map.new(lock_names, &{Atom.to_string(&1), false})

    dependencies
    |> Enum.reduce_while({:ok, roles, MapSet.new()}, &collect_runtime_root/2)
    |> case do
      {:ok, expected, _visited} -> {:ok, expected}
      {:error, reason} -> {:error, reason}
    end
  end

  defp collect_runtime_root(%Mix.Dep{top_level: true} = dependency, {:ok, roles, visited}) do
    if runtime_application?(dependency) do
      case collect_runtime_roles(dependency, roles, visited) do
        {:ok, next_roles, next_visited} -> {:cont, {:ok, next_roles, next_visited}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    else
      {:cont, {:ok, roles, visited}}
    end
  end

  defp collect_runtime_root(_dependency, accumulator), do: {:cont, accumulator}

  defp collect_runtime_roles(dependency, roles, visited) do
    name = Atom.to_string(dependency.app)

    cond do
      not runtime_application?(dependency) ->
        {:ok, roles, visited}

      MapSet.member?(visited, name) ->
        {:ok, roles, visited}

      not Map.has_key?(roles, name) ->
        {:error, :unreproducible_dependency}

      true ->
        roles = Map.put(roles, name, true)
        visited = MapSet.put(visited, name)

        Enum.reduce_while(dependency.deps, {:ok, roles, visited}, &collect_runtime_child/2)
    end
  end

  defp collect_runtime_child(child, {:ok, roles, visited}) do
    case collect_runtime_roles(child, roles, visited) do
      {:ok, next_roles, next_visited} -> {:cont, {:ok, next_roles, next_visited}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp flatten_mix_dependencies(dependencies) do
    Enum.reduce(dependencies, {[], MapSet.new()}, fn dependency, acc ->
      flatten_mix_dependency(dependency, acc)
    end)
    |> elem(0)
  end

  defp flatten_mix_dependency(dependency, {flattened, visited}) do
    name = Atom.to_string(dependency.app)

    if MapSet.member?(visited, name) do
      {flattened, visited}
    else
      visited = MapSet.put(visited, name)
      flattened = [dependency | flattened]

      Enum.reduce(dependency.deps, {flattened, visited}, fn child, acc ->
        flatten_mix_dependency(child, acc)
      end)
    end
  end

  defp local_dependency?(%Mix.Dep{opts: opts}), do: Keyword.has_key?(opts, :path)

  defp runtime_application?(%Mix.Dep{opts: opts}),
    do: Keyword.get(opts, :runtime, true) != false and Keyword.get(opts, :app, true) != false

  defp dependency_name(name) when is_atom(name), do: Atom.to_string(name)
  defp dependency_name(name) when is_binary(name), do: name
  defp dependency_name(_name), do: nil

  @spec capture_postgresql() :: {:ok, String.t()} | {:error, atom()}
  def capture_postgresql do
    if Mix.env() != :test do
      {:error, :test_environment_required}
    else
      config = NewYou.Repo.config()

      case Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false) do
        :ok ->
          release_postgresql_checkout(config)

        _ ->
          {:error, :test_connection_unavailable}
      end
    end
  rescue
    _ -> {:error, :test_database_preflight_failed}
  end

  defp release_postgresql_checkout(config) do
    result = query_postgresql_version(config)

    case Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo) do
      :ok -> result
      _ -> {:error, :test_connection_release_failed}
    end
  end

  defp query_postgresql_version(config) do
    with {:ok, %{rows: [[version, database, username, createdb?]]}} <-
           NewYou.Repo.query(
             "SELECT current_setting('server_version'), current_database(), current_user, rolcreatedb FROM pg_roles WHERE rolname = current_user",
             [],
             log: false
           ),
         true <- is_binary(version),
         true <-
           test_connection_valid?(Mix.env(), config, %{
             database: database,
             username: username,
             role_createdb?: createdb?
           }) do
      {:ok, version}
    else
      _ -> {:error, :test_database_preflight_failed}
    end
  rescue
    _ -> {:error, :test_database_preflight_failed}
  end

  @spec test_connection_valid?(atom(), keyword(), map()) :: boolean()
  def test_connection_valid?(environment, config, server)
      when is_list(config) and is_map(server) do
    expected = NewYou.LocalConfig.repo(:test)
    identity_keys = [:hostname, :port, :database, :username]

    environment == :test and not Keyword.has_key?(config, :url) and
      Enum.all?(identity_keys, &(Keyword.get(config, &1) == Keyword.get(expected, &1))) and
      Map.get(server, :database) == Keyword.get(expected, :database) and
      Map.get(server, :username) == Keyword.get(expected, :username) and
      Map.get(server, :role_createdb?) == false
  rescue
    _ -> false
  end

  def test_connection_valid?(_environment, _config, _server), do: false

  @spec write_atomic(Path.t(), map()) :: :ok | {:error, :output_failure}
  def write_atomic(path, result) when is_binary(path) and is_map(result) do
    encoded = Jason.encode!(result)

    if byte_size(encoded) > @max_artifact_bytes do
      {:error, :output_failure}
    else
      publish_atomic(Path.expand(path), encoded)
    end
  rescue
    _ -> {:error, :output_failure}
  end

  def write_atomic(_path, _result), do: {:error, :output_failure}

  @spec validate(map(), keyword()) :: :ok | {:error, [atom()]}
  def validate(result, opts \\ [])

  def validate(result, opts) when is_map(result) and is_list(opts) do
    mode = Keyword.get(opts, :mode, parse_mode(value(result, "mode")))
    expected_dependencies = locked_dependency_names()
    metadata_complete? = value(result, "metadata_complete") == true

    errors =
      []
      |> add_errors(
        if(Keyword.keys(opts) -- [:mode] == [], do: [], else: [:invalid_validation_options])
      )
      |> add_errors(closed_keys(result, @top_keys, :top))
      |> add_errors(validate_top(result))
      |> add_errors(validate_git(value(result, "git")))
      |> add_errors(validate_runtime(value(result, "runtime")))
      |> add_errors(
        validate_dependencies(
          value(result, "dependencies"),
          expected_dependencies,
          metadata_complete?
        )
      )
      |> add_errors(validate_inventory(value(result, "coverage_inventory")))
      |> add_errors(validate_results(value(result, "results"), mode))
      |> add_errors(validate_cleanup(value(result, "cleanup")))
      |> add_errors(validate_cross_fields(result, mode))
      |> Enum.uniq()

    if errors == [], do: :ok, else: {:error, errors}
  end

  def validate(_result, _opts), do: {:error, [:invalid_result]}

  defp validate_top(result) do
    errors = []
    errors = require_value(result, "schema_version", @schema_version, errors)
    errors = require_label(result, "run_id", errors)
    errors = require_value(result, "contract", @contract, errors)
    errors = require_boolean(result, "metadata_complete", errors)

    errors =
      if value(result, "mode") in ["harness_self_test", "tb001", "diagnostic"],
        do: errors,
        else: [:invalid_mode | errors]

    errors =
      if value(result, "overall_verdict") in @verdicts,
        do: errors,
        else: [:invalid_verdict | errors]

    errors =
      if value(result, "exit_code") in [0, 1, 2], do: errors, else: [:invalid_exit_code | errors]

    errors =
      if valid_reasons?(value(result, "reason_codes")),
        do: errors,
        else: [:invalid_reason_codes | errors]

    errors =
      if is_list(value(result, "dependencies")),
        do: errors,
        else: [:invalid_dependencies | errors]

    errors = if is_list(value(result, "results")), do: errors, else: [:invalid_results | errors]
    errors
  end

  defp validate_git(git) when is_map(git) do
    []
    |> add_errors(closed_keys(git, @git_keys, :git))
    |> add_errors(optional_sha?(value(git, "head_before")))
    |> add_errors(optional_sha?(value(git, "head_after")))
    |> add_errors(optional_sha256?(value(git, "lock_sha256_before")))
    |> add_errors(optional_sha256?(value(git, "lock_sha256_after")))
    |> add_errors(optional_boolean?(value(git, "clean_before")))
    |> add_errors(optional_boolean?(value(git, "clean_after")))
  end

  defp validate_git(_), do: [:invalid_git]

  defp validate_runtime(runtime) when is_map(runtime) do
    errors = closed_keys(runtime, @runtime_keys, :runtime)

    errors =
      Enum.reduce(~w(elixir otp erts postgresql), errors, fn key, acc ->
        if optional_version?(value(runtime, key)), do: acc, else: [:invalid_runtime_version | acc]
      end)

    if value(runtime, "mix_env") in ["test", nil], do: errors, else: [:invalid_mix_env | errors]
  end

  defp validate_runtime(_), do: [:invalid_runtime]

  defp validate_dependencies(dependencies, expected, metadata_complete?)
       when is_list(dependencies) and length(dependencies) <= 256 do
    names = Enum.map(dependencies, &value(&1, "name"))
    errors = validate_dependency_entries(dependencies)
    errors = add_errors(errors, validate_unique_dependency_names(names))
    add_errors(errors, validate_dependency_lock(names, expected, metadata_complete?))
  end

  defp validate_dependencies(_, _, _), do: [:invalid_dependencies]

  defp validate_dependency_entries(dependencies) do
    Enum.reduce(dependencies, [], fn dependency, errors ->
      errors
      |> add_errors(validate_dependency_shape(dependency))
      |> add_errors(validate_dependency(dependency))
    end)
  end

  defp validate_dependency_shape(dependency) when is_map(dependency),
    do: closed_keys(dependency, @dependency_keys, :dependency)

  defp validate_dependency_shape(_dependency), do: [:invalid_dependency]

  defp validate_unique_dependency_names(names) do
    if length(names) == length(Enum.uniq(names)), do: [], else: [:duplicate_dependency]
  end

  defp validate_dependency_lock(names, expected, true) when is_list(expected) do
    if Enum.sort(names) == Enum.sort(expected), do: [], else: [:dependency_lock_mismatch]
  end

  defp validate_dependency_lock(_names, nil, true), do: [:dependency_lock_unavailable]
  defp validate_dependency_lock(_names, _expected, _metadata_complete?), do: []

  defp validate_dependency(dependency) when is_map(dependency) do
    source = value(dependency, "source")
    locked = value(dependency, "locked_version")
    loaded = value(dependency, "loaded_version")
    revision = value(dependency, "revision")
    runtime_required? = value(dependency, "runtime_required")

    []
    |> add_errors(validate_dependency_name(value(dependency, "name")))
    |> add_errors(validate_dependency_source(source, locked, revision))
    |> add_errors(validate_dependency_versions(locked, loaded, runtime_required?, source))
  end

  defp validate_dependency(_), do: [:invalid_dependency]

  defp validate_dependency_name(name),
    do: if(valid_label?(name), do: [], else: [:invalid_dependency_name])

  defp validate_dependency_source(source, locked, revision) do
    []
    |> add_errors(if(source in ["hex", "git"], do: [], else: [:invalid_dependency_source]))
    |> add_errors(
      if(optional_sha_or_nil?(revision), do: [], else: [:invalid_dependency_revision])
    )
    |> add_errors(
      if(source == "hex" and is_nil(locked), do: [:missing_locked_identity], else: [])
    )
    |> add_errors(if(source == "git" and is_nil(revision), do: [:missing_git_revision], else: []))
  end

  defp validate_dependency_versions(locked, loaded, runtime_required?, source) do
    []
    |> add_errors(if(optional_version?(locked), do: [], else: [:invalid_locked_version]))
    |> add_errors(if(optional_version?(loaded), do: [], else: [:invalid_loaded_version]))
    |> add_errors(if(is_boolean(runtime_required?), do: [], else: [:invalid_runtime_required]))
    |> add_errors(validate_loaded_version(runtime_required?, loaded))
    |> add_errors(validate_locked_version(runtime_required?, source, loaded, locked))
  end

  defp validate_loaded_version(true, nil), do: [:missing_loaded_version]

  defp validate_loaded_version(false, loaded) when not is_nil(loaded),
    do: [:unexpected_loaded_version]

  defp validate_loaded_version(_runtime_required?, _loaded), do: []

  defp validate_locked_version(true, "hex", loaded, locked) when loaded != locked,
    do: [:dependency_version_mismatch]

  defp validate_locked_version(_runtime_required?, _source, _loaded, _locked), do: []

  defp validate_inventory(inventory) do
    expected = Catalog.coverage_inventory()

    if is_list(inventory) and inventory == expected and
         length(inventory) == length(Enum.uniq(inventory)),
       do: [],
       else: [:invalid_coverage_inventory]
  end

  defp validate_results(results, mode) when is_list(results) and length(results) <= 256 do
    coverage_ids = Enum.map(results, &value(&1, "coverage_id"))
    errors = validate_result_entries(results)
    errors = add_errors(errors, validate_unique_coverage_ids(coverage_ids))
    add_errors(errors, validate_results_for_mode(results, coverage_ids, mode))
  end

  defp validate_results(_, _), do: [:invalid_results]

  defp validate_result_entries(results) do
    Enum.reduce(results, [], fn entry, errors ->
      errors
      |> add_errors(validate_result_entry_shape(entry))
      |> add_errors(validate_result_entry(entry))
    end)
  end

  defp validate_result_entry_shape(entry) when is_map(entry),
    do: closed_keys(entry, @result_keys, :result)

  defp validate_result_entry_shape(_entry), do: [:invalid_result_entry]

  defp validate_unique_coverage_ids(coverage_ids) do
    if length(coverage_ids) == length(Enum.uniq(coverage_ids)),
      do: [],
      else: [:duplicate_coverage_result]
  end

  defp validate_results_for_mode(_results, coverage_ids, :tb001) do
    if coverage_ids == Catalog.coverage_inventory(), do: [], else: [:incomplete_tb001_results]
  end

  defp validate_results_for_mode(results, _coverage_ids, :harness_self_test) do
    harness = Enum.filter(results, &(value(&1, "coverage_id") == "harness"))
    expected_cases = Enum.map(Catalog.required().self_test.cases, & &1.case_id)

    if valid_harness_result?(harness, expected_cases),
      do: [],
      else: [:incomplete_self_test_manifest]
  end

  defp validate_results_for_mode(_results, _coverage_ids, :diagnostic), do: []
  defp validate_results_for_mode(_results, _coverage_ids, _mode), do: [:invalid_mode]

  defp valid_harness_result?([harness], expected_cases) do
    value(harness, "required_case_ids") == expected_cases and
      Enum.map(value(harness, "cases") || [], &value(&1, "case_id")) == expected_cases
  end

  defp valid_harness_result?(_harness, _expected_cases), do: false

  defp validate_result_entry(entry) when is_map(entry) do
    entry
    |> validate_result_entry_fields()
    |> add_errors(validate_result_entry_cases(entry))
    |> add_errors(validate_result_entry_verdict(entry))
    |> add_errors(validate_result_entry_manifest(entry))
  end

  defp validate_result_entry(_), do: [:invalid_result_entry]

  defp validate_result_entry_fields(entry) do
    []
    |> add_errors(
      if(valid_coverage?(value(entry, "coverage_id")), do: [], else: [:invalid_coverage_id])
    )
    |> add_errors(validate_result_digest(value(entry, "manifest_sha256")))
    |> add_errors(validate_required_case_ids(value(entry, "required_case_ids")))
    |> add_errors(if(value(entry, "status") in @statuses, do: [], else: [:invalid_status]))
    |> add_errors(if(value(entry, "verdict") in @verdicts, do: [], else: [:invalid_verdict]))
  end

  defp validate_result_digest(digest),
    do: if(is_nil(digest) or valid_sha256?(digest), do: [], else: [:invalid_manifest_digest])

  defp validate_required_case_ids(ids) do
    if is_list(ids) and length(ids) == length(Enum.uniq(ids)),
      do: [],
      else: [:invalid_required_case_ids]
  end

  defp validate_result_entry_cases(entry) do
    case value(entry, "cases") do
      cases when is_list(cases) ->
        Enum.reduce(
          cases,
          [],
          &add_errors(
            &2,
            validate_case(&1, value(entry, "coverage_id"), value(entry, "required_case_ids"))
          )
        )

      _ ->
        [:invalid_cases]
    end
  end

  defp validate_result_entry_verdict(entry) do
    []
    |> add_errors(validate_entry_failure_reason(entry))
    |> add_errors(validate_entry_pass(entry))
  end

  defp validate_entry_failure_reason(entry) do
    if value(entry, "verdict") == "FAIL" and
         not valid_reasons?(value(entry, "reason_codes")),
       do: [:missing_failure_reason],
       else: []
  end

  defp validate_entry_pass(entry) do
    cases = value(entry, "cases")

    cases_pass? =
      is_list(cases) and cases != [] and Enum.all?(cases, &(value(&1, "verdict") == "PASS"))

    invalid_pass? =
      value(entry, "verdict") == "PASS" and
        (value(entry, "status") != "completed" or is_nil(value(entry, "manifest_sha256")) or
           value(entry, "required_case_ids") == [] or not cases_pass?)

    if invalid_pass?, do: [:invalid_pass_entry], else: []
  end

  defp validate_result_entry_manifest(entry) do
    coverage = value(entry, "coverage_id")
    digest = value(entry, "manifest_sha256")
    required_ids = value(entry, "required_case_ids")
    status = value(entry, "status")
    verdict = value(entry, "verdict")

    if coverage == "harness" do
      validate_self_test_manifest(digest, required_ids)
    else
      validate_business_manifest(entry, digest, required_ids, status, verdict)
    end
  end

  defp validate_self_test_manifest(digest, required_ids) do
    if not valid_sha256?(digest) or digest != Catalog.required().self_test.digest or
         not is_list(required_ids),
       do: [:invalid_self_test_manifest],
       else: []
  end

  defp validate_business_manifest(entry, digest, required_ids, status, verdict) do
    coverage = value(entry, "coverage_id")

    case Map.get(Catalog.required().business_manifests, coverage) do
      nil ->
        missing_business_manifest_errors(entry, digest, required_ids, status, verdict)

      manifest ->
        validate_compiled_business_manifest(
          entry,
          manifest,
          digest,
          required_ids,
          status,
          verdict
        )
    end
  end

  defp missing_business_manifest_errors(entry, digest, required_ids, status, verdict) do
    if digest == nil and required_ids == [] and status == "missing" and verdict == "FAIL" and
         value(entry, "cases") == [] and
         "missing.manifest" in (value(entry, "reason_codes") || []) do
      []
    else
      [:unavailable_business_manifest]
    end
  end

  defp validate_compiled_business_manifest(entry, manifest, digest, required_ids, status, verdict) do
    partial? = Map.get(manifest, :scope) == :partial
    expected_ids = Enum.map(manifest.cases, & &1.case_id)
    cases = value(entry, "cases") || []
    case_ids = Enum.map(cases, &value(&1, "case_id"))

    errors =
      []
      |> maybe_error(
        Map.get(manifest, :scope) not in [:partial, :complete],
        :invalid_manifest_scope
      )
      |> maybe_error(partial? and verdict == "PASS", :partial_manifest_pass)
      |> maybe_error(
        partial? and "manifest.partial" not in (value(entry, "reason_codes") || []),
        :missing_partial_manifest_reason
      )
      |> maybe_error(digest != manifest.digest, :invalid_business_manifest_digest)
      |> maybe_error(required_ids != expected_ids, :invalid_business_required_cases)
      |> maybe_error(case_ids != expected_ids, :incomplete_business_cases)

    valid_status? =
      (status == "completed" and verdict in ["PASS", "FAIL"]) or
        (status in ["missing", "not_run", "timeout", "error"] and verdict == "FAIL")

    errors
    |> maybe_error(not valid_status?, :invalid_business_result_status)
    |> maybe_error(
      verdict == "PASS" and not Enum.all?(cases, &(value(&1, "verdict") == "PASS")),
      :invalid_pass_entry
    )
    |> maybe_error(
      verdict == "FAIL" and not valid_reasons?(value(entry, "reason_codes")),
      :missing_failure_reason
    )
  end

  defp validate_case(case_data, coverage, required_ids) when is_map(case_data) do
    errors = closed_keys(case_data, @case_keys, :case)
    errors = add_errors(errors, validate_case_identity(case_data))
    errors = add_errors(errors, validate_case_outcome_shape(case_data))
    errors = add_errors(errors, validate_case_assertions(case_data))
    errors = add_errors(errors, validate_case_timing(case_data))
    add_errors(errors, validate_case_verdict(case_data, coverage, required_ids))
  end

  defp validate_case(_, _, _), do: [:invalid_case]

  defp validate_case_identity(case_data) do
    []
    |> add_errors(validate_case_label(value(case_data, "case_id"), :invalid_case_id))
    |> add_errors(validate_case_label(value(case_data, "invariant_id"), :invalid_invariant_id))
    |> add_errors(validate_case_label(value(case_data, "boundary"), :invalid_boundary))
    |> add_errors(validate_case_cut_point(value(case_data, "cut_point")))
    |> add_errors(validate_case_race(value(case_data, "race_id")))
  end

  defp validate_case_label(value, reason), do: if(valid_label?(value), do: [], else: [reason])

  defp validate_case_cut_point(value),
    do: if(value in [nil | cut_points()], do: [], else: [:invalid_cut_point])

  defp validate_case_race(nil), do: []
  defp validate_case_race(value), do: validate_case_label(value, :invalid_race_id)

  defp validate_case_outcome_shape(case_data) do
    []
    |> add_errors(
      if(value(case_data, "status") in @statuses, do: [], else: [:invalid_case_status])
    )
    |> add_errors(
      if(value(case_data, "verdict") in @verdicts, do: [], else: [:invalid_case_verdict])
    )
    |> add_errors(validate_expected(value(case_data, "expected")))
    |> add_errors(validate_observations(value(case_data, "observations")))
    |> add_errors(validate_case_reasons(value(case_data, "reason_codes")))
  end

  defp validate_expected(value),
    do: if(valid_bounded_text?(value, 512), do: [], else: [:invalid_expected])

  defp validate_observations(value),
    do: if(valid_observations?(value), do: [], else: [:invalid_observations])

  defp validate_case_reasons(value),
    do: if(is_list(value) and valid_reasons?(value), do: [], else: [:invalid_case_reasons])

  defp validate_case_assertions(case_data) do
    ids = value(case_data, "assertion_ids")
    count = value(case_data, "assertions_executed")

    []
    |> add_errors(validate_assertion_ids(ids))
    |> add_errors(validate_assertion_count(count, ids))
  end

  defp validate_assertion_ids(ids) do
    if is_list(ids) and length(ids) == length(Enum.uniq(ids)),
      do: [],
      else: [:invalid_assertion_ids]
  end

  defp validate_assertion_count(count, ids) do
    if is_integer(count) and count >= 0 and is_list(ids) and count == length(ids),
      do: [],
      else: [:invalid_assertion_count]
  end

  defp validate_case_timing(case_data) do
    []
    |> add_errors(validate_non_negative_duration(value(case_data, "duration_ms")))
    |> add_errors(validate_positive_timeout(value(case_data, "timeout_ms")))
    |> add_errors(validate_timeout_override(value(case_data, "timeout_override_reason")))
  end

  defp validate_non_negative_duration(value),
    do: if(is_integer(value) and value >= 0, do: [], else: [:invalid_duration])

  defp validate_positive_timeout(value),
    do: if(is_integer(value) and value > 0, do: [], else: [:invalid_timeout])

  defp validate_timeout_override(nil), do: []

  defp validate_timeout_override(value),
    do: if(valid_bounded_text?(value, 256), do: [], else: [:invalid_timeout_override])

  defp validate_case_verdict(case_data, coverage, required_ids) do
    case_id = value(case_data, "case_id")
    manifest = manifest_case(coverage, case_id)

    []
    |> add_errors(validate_case_verdict_fields(case_data, required_ids, manifest))
    |> add_errors(validate_case_manifest_fields(case_data, manifest))
  end

  defp validate_case_verdict_fields(case_data, required_ids, manifest) do
    case_id = value(case_data, "case_id")
    verdict = value(case_data, "verdict")
    assertion_ids = value(case_data, "assertion_ids")
    assertion_manifest = if manifest, do: Map.get(manifest, :assertion_ids), else: nil

    []
    |> maybe_error(
      invalid_case_pass?(
        verdict,
        value(case_data, "status"),
        value(case_data, "assertions_executed"),
        assertion_ids
      ),
      :invalid_case_pass
    )
    |> maybe_error(
      unapproved_assertions?(verdict, assertion_manifest, assertion_ids),
      :unapproved_assertions
    )
    |> maybe_error(unexpected_case_pass?(verdict, case_id, required_ids), :unexpected_case_pass)
    |> maybe_error(
      verdict == "FAIL" and not valid_reasons?(value(case_data, "reason_codes")),
      :missing_case_failure_reason
    )
    |> maybe_error(
      (manifest && verdict == "FAIL") and
        (not is_list(assertion_ids) or not Enum.all?(assertion_ids, &(&1 in assertion_manifest))),
      :unapproved_assertions
    )
  end

  defp validate_case_manifest_fields(_case_data, nil), do: []

  defp validate_case_manifest_fields(case_data, manifest) do
    []
    |> maybe_error(
      value(case_data, "invariant_id") != Map.get(manifest, :invariant_id),
      :case_invariant_mismatch
    )
    |> maybe_error(
      value(case_data, "boundary") != Map.get(manifest, :boundary),
      :case_boundary_mismatch
    )
    |> maybe_error(
      value(case_data, "cut_point") != Map.get(manifest, :cut_point),
      :case_cut_point_mismatch
    )
    |> maybe_error(
      value(case_data, "race_id") != Map.get(manifest, :race_id),
      :case_race_mismatch
    )
    |> maybe_error(
      value(case_data, "timeout_ms") != Map.get(manifest, :timeout_ms),
      :case_timeout_mismatch
    )
    |> maybe_error(
      value(case_data, "timeout_override_reason") !=
        Map.get(manifest, :timeout_override_reason),
      :case_timeout_override_mismatch
    )
  end

  defp invalid_case_pass?("PASS", status, count, assertion_ids),
    do:
      status != "completed" or not is_integer(count) or count < 1 or not is_list(assertion_ids) or
        assertion_ids == [] or count != length(assertion_ids)

  defp invalid_case_pass?(_verdict, _status, _count, _assertion_ids), do: false

  defp unapproved_assertions?("PASS", nil, _assertion_ids), do: true
  defp unapproved_assertions?("PASS", manifest, assertion_ids), do: assertion_ids != manifest
  defp unapproved_assertions?(_verdict, _manifest, _assertion_ids), do: false

  defp unexpected_case_pass?("PASS", case_id, required_ids) when is_list(required_ids),
    do: case_id not in required_ids

  defp unexpected_case_pass?(_verdict, _case_id, _required_ids), do: false

  defp validate_cleanup(cleanup) when is_map(cleanup) do
    errors = closed_keys(cleanup, @cleanup_keys, :cleanup)

    errors =
      if value(cleanup, "verdict") in @verdicts,
        do: errors,
        else: [:invalid_cleanup_verdict | errors]

    errors =
      Enum.reduce(~w(workers_stopped connections_released locks_released), errors, fn key, acc ->
        if is_boolean(value(cleanup, key)), do: acc, else: [:invalid_cleanup_flag | acc]
      end)

    if valid_reasons?(value(cleanup, "reason_codes")),
      do: errors,
      else: [:invalid_cleanup_reasons | errors]
  end

  defp validate_cleanup(_), do: [:invalid_cleanup]

  defp validate_cross_fields(result, mode) do
    []
    |> add_errors(validate_verdict_exit(result))
    |> add_errors(validate_failure_reason(result))
    |> add_errors(validate_metadata_claim(result))
    |> add_errors(validate_cleanup_exit(result))
    |> add_errors(validate_timeout_failure(result))
    |> add_errors(validate_overall_pass(result))
    |> add_errors(validate_source_state(result, mode))
  end

  defp validate_cleanup_exit(result) do
    cleanup = value(result, "cleanup") || %{}

    cleanup_failed? =
      value(cleanup, "verdict") != "PASS" or
        Enum.any?(
          ~w(workers_stopped connections_released locks_released),
          &(value(cleanup, &1) != true)
        )

    if cleanup_failed? and
         (value(result, "overall_verdict") != "FAIL" or value(result, "exit_code") != 2),
       do: [:cleanup_failure_mismatch],
       else: []
  end

  defp validate_timeout_failure(result) do
    timed_out? =
      case value(result, "results") do
        results when is_list(results) -> Enum.any?(results, &contains_timeout_case?/1)
        _ -> false
      end

    if timed_out? and
         (value(result, "overall_verdict") != "FAIL" or value(result, "exit_code") != 2 or
            "timeout.expired" not in (value(result, "reason_codes") || [])),
       do: [:timeout_failure_mismatch],
       else: []
  end

  defp contains_timeout_case?(entry) when is_map(entry) do
    case value(entry, "cases") do
      cases when is_list(cases) -> Enum.any?(cases, &(value(&1, "status") == "timeout"))
      _ -> false
    end
  end

  defp contains_timeout_case?(_entry), do: false

  defp validate_verdict_exit(result) do
    overall = value(result, "overall_verdict")
    code = value(result, "exit_code")

    if (overall == "PASS" and code != 0) or (overall == "FAIL" and code == 0),
      do: [:verdict_exit_mismatch],
      else: []
  end

  defp validate_failure_reason(result) do
    if value(result, "overall_verdict") == "FAIL" and
         not valid_reasons?(value(result, "reason_codes")),
       do: [:missing_overall_failure_reason],
       else: []
  end

  defp validate_metadata_claim(result) do
    if value(result, "metadata_complete") == true and not complete_metadata_fields?(result),
      do: [:incomplete_metadata_claim],
      else: metadata_failure_consistent(result)
  end

  defp complete_metadata_fields?(result) do
    git = value(result, "git") || %{}
    runtime = value(result, "runtime") || %{}
    dependencies = value(result, "dependencies") || []

    fields = [
      value(git, "head_before"),
      value(git, "head_after"),
      value(git, "clean_before"),
      value(git, "clean_after"),
      value(git, "lock_sha256_before"),
      value(git, "lock_sha256_after"),
      value(runtime, "elixir"),
      value(runtime, "otp"),
      value(runtime, "erts"),
      value(runtime, "postgresql")
    ]

    dependencies != [] and Enum.all?(fields, &(not is_nil(&1))) and
      value(runtime, "mix_env") == "test"
  end

  defp metadata_failure_consistent(result) do
    if value(result, "metadata_complete") == false and
         (value(result, "overall_verdict") != "FAIL" or value(result, "exit_code") != 2),
       do: [:metadata_failure_mismatch],
       else: []
  end

  defp validate_overall_pass(result) do
    results = value(result, "results") || []
    passing_checks? = results != [] and Enum.all?(results, &(value(&1, "verdict") == "PASS"))
    cleanup = value(result, "cleanup") || %{}

    cleanup_pass? =
      value(cleanup, "verdict") == "PASS" and
        Enum.all?(
          ~w(workers_stopped connections_released locks_released),
          &(value(cleanup, &1) == true)
        )

    if value(result, "overall_verdict") == "PASS" and
         (value(result, "metadata_complete") != true or not passing_checks? or not cleanup_pass?),
       do: [:invalid_overall_pass],
       else: []
  end

  defp validate_source_state(result, mode) do
    git = value(result, "git") || %{}
    changed? = source_changed?(git)
    dirty_full? = mode == :tb001 and source_dirty?(git)

    if (changed? or dirty_full?) and
         (value(result, "overall_verdict") != "FAIL" or value(result, "exit_code") != 2),
       do: [:source_state_failure_mismatch],
       else: []
  end

  defp source_changed?(git) do
    value(git, "head_before") != value(git, "head_after") or
      value(git, "lock_sha256_before") != value(git, "lock_sha256_after")
  end

  defp source_dirty?(git),
    do: value(git, "clean_before") != true or value(git, "clean_after") != true

  defp manifest_case("harness", case_id) do
    case Catalog.lookup_manifest("harness", case_id) do
      {:ok, manifest} -> manifest
      _ -> nil
    end
  end

  defp manifest_case(coverage, case_id) do
    case Catalog.lookup_manifest(coverage, case_id) do
      {:ok, manifest} -> manifest
      _ -> nil
    end
  end

  defp dependency_entry(
         name,
         {:hex, _package, version, _checksum, _managers, _deps, _repo, _outer_checksum},
         runtime_required?,
         loaded
       ) do
    runtime_dependency(name, "hex", version, nil, runtime_required?, loaded)
  end

  defp dependency_entry(name, {:git, _url, revision, _options}, runtime_required?, loaded)
       when is_binary(revision) do
    source = if Regex.match?(~r/^[0-9a-f]{40}$/, revision), do: "git", else: nil

    if source,
      do: runtime_dependency(name, source, nil, revision, runtime_required?, loaded),
      else: nil
  end

  defp dependency_entry(_name, _entry, _runtime_required?, _loaded), do: nil

  defp runtime_dependency(name, source, locked_version, revision, runtime_required?, loaded) do
    loaded_version = if runtime_required?, do: Map.get(loaded, name), else: nil

    %{
      name: name,
      source: source,
      locked_version: locked_version,
      loaded_version: if(runtime_required?, do: loaded_version, else: nil),
      revision: revision,
      runtime_required: runtime_required?
    }
  end

  defp publish_atomic(path, encoded) do
    directory = Path.dirname(path)

    temporary =
      Path.join(
        directory,
        ".proof-result-#{Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)}.tmp"
      )

    try do
      result =
        case File.open(temporary, [:write, :binary, :exclusive]) do
          {:ok, file} ->
            try do
              with :ok <- File.chmod(temporary, 0o600),
                   :ok <- IO.binwrite(file, encoded) do
                :file.sync(file)
              end
            after
              File.close(file)
            end

          {:error, _reason} ->
            {:error, :output_failure}
        end

      if result == :ok do
        case File.ln(temporary, path) do
          :ok -> :ok
          {:error, _reason} -> {:error, :output_failure}
        end
      else
        {:error, :output_failure}
      end
    after
      File.rm(temporary)
    end
  end

  defp git_value(root, args) do
    case System.cmd("git", ["-C", root | args], stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      _ -> nil
    end
  end

  defp valid_output_sha(value) when is_binary(value),
    do: if(valid_sha?(value), do: value, else: nil)

  defp valid_output_sha(_), do: nil
  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)

  defp locked_dependency_names do
    lock_path = Path.join(File.cwd!(), "mix.lock")

    with {:ok, contents} <- File.read(lock_path),
         true <- String.trim(contents) != "",
         lock when is_map(lock) and map_size(lock) > 0 <- Mix.Dep.Lock.read(lock_path) do
      Enum.map(lock, fn {name, _entry} -> Atom.to_string(name) end)
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp valid_observations?(observations)
       when is_list(observations) and length(observations) <= 64 do
    Enum.all?(observations, fn item ->
      is_map(item) and closed_keys(item, ~w(code value), :observation) == [] and
        valid_label?(value(item, "code")) and valid_observation_value?(value(item, "value"))
    end)
  end

  defp valid_observations?(_), do: false

  defp valid_observation_value?(value) when is_binary(value), do: byte_size(value) <= 256

  defp valid_observation_value?(value)
       when is_integer(value) or is_boolean(value) or is_nil(value), do: true

  defp valid_observation_value?(_), do: false

  defp cut_points do
    [
      "transaction.before_commit",
      "transaction.after_commit",
      "scheduling.before_enqueue",
      "scheduling.after_enqueue",
      "provider.before_invoke",
      "provider.after_invoke_before_persist",
      "evidence.before_materialize",
      "evidence.after_materialize_before_commit"
    ]
  end

  defp valid_coverage?(id), do: id == "harness" or id in Catalog.coverage_inventory()

  defp valid_reasons?(reasons) when is_list(reasons) and length(reasons) <= 32,
    do: length(reasons) == length(Enum.uniq(reasons)) and Enum.all?(reasons, &valid_label?/1)

  defp valid_reasons?(_), do: false
  defp valid_label?(value), do: valid_label_string?(value, 128)

  defp valid_label_string?(value, max) when is_binary(value),
    do: byte_size(value) in 1..max and Regex.match?(~r/^[A-Za-z0-9_.:-]+$/, value)

  defp valid_label_string?(_, _), do: false

  defp valid_bounded_text?(value, max) when is_binary(value),
    do: byte_size(value) in 1..max

  defp valid_bounded_text?(_, _), do: false
  defp valid_sha?(value), do: is_binary(value) and Regex.match?(~r/^[0-9a-f]{40}$/, value)
  defp valid_sha256?(value), do: is_binary(value) and Regex.match?(~r/^[0-9a-f]{64}$/, value)
  defp optional_sha?(nil), do: []
  defp optional_sha?(value), do: if(valid_sha?(value), do: [], else: [:invalid_git_sha])
  defp optional_sha256?(nil), do: []
  defp optional_sha256?(value), do: if(valid_sha256?(value), do: [], else: [:invalid_sha256])
  defp optional_boolean?(value) when is_boolean(value), do: []
  defp optional_boolean?(nil), do: []
  defp optional_boolean?(_), do: [:invalid_boolean]
  defp optional_version?(nil), do: true
  defp optional_version?(value), do: is_binary(value) and byte_size(value) in 1..128
  defp optional_sha_or_nil?(nil), do: true
  defp optional_sha_or_nil?(value), do: valid_sha?(value)

  defp require_value(map, key, expected, errors),
    do: if(value(map, key) == expected, do: errors, else: [:invalid_constant | errors])

  defp require_label(map, key, errors),
    do: if(valid_label?(value(map, key)), do: errors, else: [:invalid_label | errors])

  defp require_boolean(map, key, errors),
    do: if(is_boolean(value(map, key)), do: errors, else: [:invalid_boolean | errors])

  defp closed_keys(map, keys, _scope) do
    got = Map.keys(map) |> Enum.map(&key_name/1)
    if Enum.sort(got) == Enum.sort(keys), do: [], else: [:schema_properties]
  end

  defp add_errors(errors, additions), do: additions ++ errors

  defp maybe_error(errors, true, reason), do: [reason | errors]
  defp maybe_error(errors, _condition, _reason), do: errors

  defp value(map, key) when is_map(map) do
    map
    |> Map.new(fn {candidate, result} -> {key_name(candidate), result} end)
    |> Map.get(key)
  end

  defp value(_, _), do: nil
  defp key_name(key) when is_atom(key), do: Atom.to_string(key)
  defp key_name(key) when is_binary(key), do: key
  defp parse_mode("harness_self_test"), do: :harness_self_test
  defp parse_mode("tb001"), do: :tb001
  defp parse_mode("diagnostic"), do: :diagnostic
  defp parse_mode(_), do: nil
end
