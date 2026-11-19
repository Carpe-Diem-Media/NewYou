defmodule NewYou.LocalConfig do
  @moduledoc """
  Fail-closed workstation configuration for DevCore's legacy and managed targets.

  Managed identities require a live DevCore job verification, never a database
  prefix alone. Verification reads private allocation metadata and starts no
  database or cleanup operation. CI uses a distinct ephemeral database identity;
  caller-controlled CI flags never permit workstation shared TEST. Production
  uses its separate runtime path.
  """

  @markers ~w(DEVCORE_SLOT_PROJECT DEVCORE_SLOT_LEASE DEVCORE_SLOT_GENERATION DEVCORE_SLOT_JOB DEVCORE_SLOT_WORKTREE)
  @identifier ~r/\A[0-9a-f]{32}\z/
  @type environment_reader :: (String.t() -> String.t() | nil)

  @doc """
  Returns the verified DEV or TEST connection without exposing credentials.

  Partial, expired or substituted managed context raises before Repo startup.
  TEST-origin jobs cannot select DEV. Options provide the external verifier and
  declaration seam for isolated tests; ordinary callers use canonical DevCore.
  """
  @spec repo(:dev | :test, environment_reader(), keyword()) :: keyword()
  def repo(env, get_env \\ &System.get_env/1, options \\ []) when env in [:dev, :test] do
    if env == :test and get_env.("MIX_TEST_PARTITION") not in [nil, ""] do
      raise ArgumentError, "MIX_TEST_PARTITION is unsupported while TEST has NOCREATEDB"
    end

    allocation = allocation(get_env, options)

    validate_repo_context!(env, allocation, get_env)

    case env do
      :dev ->
        validate_binding!("DEV", 55432, "new_you_dev", "new_you_dev", get_env)

      :test when is_map(allocation) ->
        validate_binding!("TEST", 55433, allocation["database"], allocation["role"], get_env)

      :test ->
        # Hosted CI has its own disposable service, never the retained workstation
        # identity. The flags select this exact binding; they authenticate nothing.
        identity =
          if get_env.("NEW_YOU_DATABASE_MODE") == "ci",
            do: "new_you_ci_test",
            else: "new_you_test"

        validate_binding!("TEST", 55433, identity, identity, get_env)
    end
  end

  defp validate_repo_context!(env, allocation, get_env) do
    if is_nil(allocation) and env == :dev and get_env.("NEW_YOU_DATABASE_MODE") == "ci",
      do: invalid_managed!()

    if allocation do
      validate_binding!("TEST", 55433, allocation["database"], allocation["role"], get_env)

      if env == :dev and allocation["profile"] != "dev", do: invalid_managed!()
    end
  end

  @doc """
  Selects the verified managed HTTP assignment or the deliberate legacy port.

  The primary legacy port is 4220. Only a verified managed allocation permits
  slot 20's port 4240. Temporary helper servers retain their own port-0 paths.
  """
  @spec port(boolean(), String.t() | nil, environment_reader(), keyword()) :: pos_integer()
  def port(worktree?, value, get_env \\ &System.get_env/1, options \\ []) do
    case allocation(get_env, options) do
      %{"port" => port} ->
        if value != Integer.to_string(port), do: invalid_managed!()
        port

      nil ->
        legacy_port(worktree?, value)
    end
  end

  defp legacy_port(worktree?, value) do
    case {worktree?, value && Integer.parse(value)} do
      {false, nil} ->
        4220

      {false, {4220, ""}} ->
        4220

      {true, {port, ""}} when port in 4221..4239 ->
        port

      _ ->
        raise ArgumentError,
              "NEW_YOU_PORT must be 4220 in the primary checkout or explicitly 4221..4239 in a worktree"
    end
  end

  defp validate_binding!(prefix, port, database, role, get_env) do
    for {suffix, expected} <- [
          {"HOST", "127.0.0.1"},
          {"PORT", Integer.to_string(port)},
          {"USERNAME", role},
          {"NAME", database}
        ] do
      key = "#{prefix}_DATABASE_#{suffix}"

      unless get_env.(key) == expected do
        raise ArgumentError, "#{key} must match the DevCore contract; run devcore-project doctor"
      end
    end

    password_key = "#{prefix}_DATABASE_PASSWORD"
    password = get_env.(password_key)

    if password in [nil, ""] do
      raise ArgumentError,
            "#{password_key} is missing; use devcore-project run #{String.downcase(prefix)} -- <command>"
    end

    [hostname: "127.0.0.1", port: port, username: role, database: database, password: password]
  end

  defp allocation(get_env, options) do
    markers = Map.new(@markers, &{&1, get_env.(&1)})

    if Enum.any?(markers, fn {_key, value} -> not is_nil(value) end) do
      validate_markers!(markers)

      verify = Keyword.get(options, :verify, &verify_job/1)

      case verify.(markers) do
        {:ok, receipt} when is_map(receipt) -> validate_receipt!(receipt, markers, get_env)
        _ -> invalid_managed!()
      end
    else
      if Keyword.get_lazy(options, :managed_required?, fn -> managed_declared?(get_env) end),
        do: invalid_managed!()

      nil
    end
  end

  defp validate_markers!(markers) do
    unless markers["DEVCORE_SLOT_PROJECT"] == "new_you" and
             Enum.all?(~w(LEASE GENERATION JOB), fn suffix ->
               identifier?(markers["DEVCORE_SLOT_" <> suffix])
             end) and canonical_path?(markers["DEVCORE_SLOT_WORKTREE"]) do
      invalid_managed!()
    end
  end

  defp validate_receipt!(receipt, markers, get_env) do
    slot = receipt["slot"]
    generation = markers["DEVCORE_SLOT_GENERATION"]

    unless is_integer(slot) and slot in 1..20, do: invalid_managed!()

    database =
      "dc_new_you_s" <> String.pad_leading(Integer.to_string(slot), 2, "0") <> "_g" <> generation

    expected = %{
      "project" => "new_you",
      "lease_id" => markers["DEVCORE_SLOT_LEASE"],
      "generation" => generation,
      "worktree" => markers["DEVCORE_SLOT_WORKTREE"],
      "port" => 4220 + slot,
      "test_host" => "127.0.0.1",
      "test_port" => 55433,
      "database" => database,
      "role" => database <> "_r"
    }

    unless Enum.all?(expected, fn {key, value} -> receipt[key] == value end) and
             receipt["profile"] in ["dev", "test"] and
             get_env.("NEW_YOU_PORT") == Integer.to_string(4220 + slot) do
      invalid_managed!()
    end

    receipt
  end

  defp verify_job(markers) do
    executable = Path.join([System.user_home!(), ".local", "bin", "devcore-project"])

    arguments = [
      "slots",
      "verify",
      "--lease",
      markers["DEVCORE_SLOT_LEASE"],
      "--generation",
      markers["DEVCORE_SLOT_GENERATION"],
      "--job",
      markers["DEVCORE_SLOT_JOB"]
    ]

    task =
      Task.async(fn ->
        try do
          System.cmd(executable, arguments, stderr_to_stdout: true)
        rescue
          _ -> {"", 1}
        end
      end)

    case Task.yield(task, 5_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, {output, 0}} -> JSON.decode(output)
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp identifier?(value) when is_binary(value), do: Regex.match?(@identifier, value)
  defp identifier?(_value), do: false

  defp canonical_path?(path) when is_binary(path),
    do: Path.type(path) == :absolute and Path.expand(path) == path

  defp canonical_path?(_path), do: false

  defp managed_declared?(get_env) do
    case get_env.("NEW_YOU_DATABASE_MODE") do
      nil ->
        declared_pool?()

      "ci" ->
        unless get_env.("GITHUB_ACTIONS") == "true" and get_env.("CI") == "true",
          do: invalid_managed!()

        false

      _ ->
        invalid_managed!()
    end
  end

  defp declared_pool? do
    case File.read(Path.expand("../../.devcore/project.conf", __DIR__)) do
      {:ok, declaration} -> Regex.match?(~r/^SLOT_POOL=\S+/m, declaration)
      _ -> invalid_managed!()
    end
  end

  defp invalid_managed!,
    do:
      raise(ArgumentError, "managed DevCore allocation is unavailable or does not match this job")
end
