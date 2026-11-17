defmodule Mix.Tasks.LocalDialyzer do
  use Mix.Task

  @moduledoc """
  Prepares a versioned local core baseline and private copies before Dialyxir.

  Shared locking ends after baseline validation or publication. Dialyxir then
  mutates only the worktree's copies. CI keeps its existing cache paths and
  delegates directly to Dialyxir with the original command arguments.
  """

  @shortdoc "Prepares private local core PLTs before Dialyxir analysis"

  @impl Mix.Task
  def run(args) do
    if System.get_env("GITHUB_ACTIONS") != "true" do
      prepare_local_core_plts()
    end

    Mix.Tasks.Dialyzer.run(args)
  end

  defp prepare_local_core_plts do
    Mix.Tasks.Deps.Loadpaths.run([])
    Mix.Task.run("compile", [])
    _ = Application.load(:dialyxir)

    plans = Dialyxir.Project.plts_list([], false)

    plt_plan =
      Enum.map(plans, fn {path, apps} ->
        {Path.basename(path), Enum.map(apps, &Atom.to_string/1)}
      end)

    plt_names = Enum.map(plt_plan, &elem(&1, 0))
    key = cache_key(plt_plan)
    dialyxir_ebin = :code.which(Dialyxir.Project) |> List.to_string() |> Path.dirname()
    producer = ["mise", "exec", "--", "elixir", "-pa", dialyxir_ebin, "tools/local_plt_core.exs"]
    cache_root = Path.join(cache_home(), "newyou/local-plt/v1")
    destination = Path.expand("_build/plts/local-core")
    request_id = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    request_path = Path.join(System.tmp_dir!(), "newyou-local-plt-#{request_id}.json")

    request = %{
      cache_root: cache_root,
      work_root: Path.expand("_build/plts"),
      destination: destination,
      key: key,
      plt_names: plt_names,
      producer_plan: Base.encode64(:erlang.term_to_binary(plt_plan)),
      producer: producer
    }

    try do
      request_json = Jason.encode!(request)

      case System.cmd("python3", ["tools/local_plt_cache.py", "--request-json", request_path],
             env: [{"NEWYOU_PLT_REQUEST", request_json}],
             stderr_to_stdout: true
           ) do
        {output, 0} ->
          if output != "", do: Mix.shell().info(String.trim(output))

        {output, status} ->
          Mix.raise(
            "Local core PLT preparation failed with status #{status}: #{String.trim(output)}"
          )
      end
    after
      File.rm(request_path)
    end
  end

  defp cache_key(plt_plan) do
    otp_major = :erlang.system_info(:otp_release) |> List.to_string()
    otp_version_path = Path.join([:code.root_dir(), "releases", otp_major, "OTP_VERSION"])
    otp_version = File.read!(otp_version_path) |> String.trim()
    architecture = :erlang.system_info(:system_architecture) |> List.to_string()

    source_root = Map.get(Mix.Project.deps_paths(), :dialyxir)
    {source_root, source_paths} = dialyxir_source_inputs(source_root)
    core_inputs = core_input_paths(plt_plan)
    dialyxir_version = Application.spec(:dialyxir, :vsn) |> to_string()

    validate_identity_inputs!(plt_plan, source_paths, core_inputs, dialyxir_version, otp_version)
    source_hash = source_hash(source_paths, source_root)

    %{
      format_revision: 1,
      otp: %{full_version: otp_version, architecture: architecture},
      elixir: System.version(),
      dialyxir: %{version: dialyxir_version, source_sha256: source_hash},
      core_apps: normalize_core_apps(plt_plan),
      core_inputs: tree_hash(core_inputs |> Map.values() |> List.flatten())
    }
  end

  @doc false
  @spec normalize_core_apps([{String.t(), [String.t()]}]) ::
          [%{basename: String.t(), apps: [String.t()]}]
  def normalize_core_apps(plt_plan) do
    Enum.map(plt_plan, fn {basename, apps} -> %{basename: basename, apps: apps} end)
  end

  @doc false
  @spec dialyxir_source_inputs(String.t() | nil) :: {String.t(), [String.t()]}
  def dialyxir_source_inputs(source_root) when is_binary(source_root) do
    source_paths = Path.wildcard(Path.join(source_root, "lib/**/*.ex"))

    if source_paths == [] or not Enum.all?(source_paths, &File.regular?/1) do
      raise ArgumentError, "selected Dialyxir dependency has no readable source inputs"
    end

    {source_root, source_paths}
  end

  def dialyxir_source_inputs(_source_root) do
    raise ArgumentError, "selected Dialyxir dependency path is unavailable"
  end

  @doc false
  @spec validate_identity_inputs!(
          [{String.t(), [String.t()]}],
          [String.t()],
          %{String.t() => [String.t()]},
          String.t(),
          String.t()
        ) :: :ok
  def validate_identity_inputs!(
        plt_plan,
        source_paths,
        core_inputs,
        dialyxir_version,
        otp_version
      ) do
    planned_apps = plt_plan |> Enum.flat_map(&elem(&1, 1)) |> Enum.uniq()

    valid_core_inputs? =
      Map.keys(core_inputs) |> Enum.sort() == Enum.sort(planned_apps) and
        Enum.all?(planned_apps, fn app ->
          inputs = Map.get(core_inputs, app, [])

          Enum.any?(inputs, &String.ends_with?(&1, ".beam")) and
            Enum.any?(inputs, &String.ends_with?(&1, ".app")) and
            Enum.all?(inputs, &File.regular?/1)
        end)

    cond do
      plt_plan == [] or Enum.any?(plt_plan, fn {name, apps} -> name == "" or apps == [] end) ->
        raise ArgumentError, "Dialyxir returned an empty core PLT plan"

      source_paths == [] or not Enum.all?(source_paths, &File.regular?/1) ->
        raise ArgumentError, "pinned Dialyxir source inputs are missing"

      not valid_core_inputs? ->
        raise ArgumentError,
              "one or more pinned core applications lack BEAM or application inputs"

      dialyxir_version == "" or otp_version == "" ->
        raise ArgumentError, "pinned Dialyxir or OTP version is unavailable"

      true ->
        :ok
    end
  end

  defp core_input_paths(plt_plan) do
    plt_plan
    |> Enum.flat_map(&elem(&1, 1))
    |> Enum.uniq()
    |> Map.new(fn app ->
      case :code.lib_dir(String.to_existing_atom(app)) do
        path when is_list(path) ->
          app_path = List.to_string(path)

          inputs =
            Path.wildcard(Path.join(app_path, "**/*.beam")) ++
              Path.wildcard(Path.join(app_path, "ebin/*.app"))

          {app, inputs}

        _ ->
          {app, []}
      end
    end)
  end

  defp tree_hash(paths), do: tree_hash(paths, nil)

  @doc false
  @spec source_hash([String.t()], String.t()) :: String.t()
  def source_hash(paths, root), do: tree_hash(paths, root)

  defp tree_hash(paths, root) do
    paths
    |> Enum.sort()
    |> Enum.map(fn path ->
      {stable_input_path(path, root),
       :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)}
    end)
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp stable_input_path(path, root) when is_binary(root) do
    Path.relative_to(path, root)
  end

  defp stable_input_path(path, nil) do
    parts = Path.split(path)

    case Enum.find_index(Enum.reverse(parts), &(&1 == "lib")) do
      nil -> Path.basename(path)
      reverse_index -> parts |> Enum.drop(length(parts) - reverse_index - 1) |> Path.join()
    end
  end

  defp cache_home do
    case System.get_env("XDG_CACHE_HOME") do
      nil -> Path.join(System.user_home!(), ".cache")
      path -> path
    end
  end
end
