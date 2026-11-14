defmodule NewYou.Architecture.MigrationIdentityTest do
  use ExUnit.Case, async: true

  test "repository migration names and modules are unique" do
    entries =
      Path.wildcard(Path.join(File.cwd!(), "priv/repo/migrations/*.exs"))
      |> Enum.map(fn path ->
        source = File.read!(path)

        [timestamp, migration_name] =
          path
          |> Path.basename()
          |> String.replace_suffix(".exs", "")
          |> String.split("_", parts: 2)

        assert String.match?(timestamp, ~r/^\d+$/), "invalid migration version in #{path}"
        [_, migration_module] = Regex.run(~r/^defmodule\s+([A-Za-z0-9_.]+)\s+do/m, source)

        %{path: path, name: migration_name, module: migration_module}
      end)

    duplicate_names = duplicate_values(entries, & &1.name)
    duplicate_modules = duplicate_values(entries, & &1.module)

    assert duplicate_names == [], "duplicate migration names: #{inspect(duplicate_names)}"
    assert duplicate_modules == [], "duplicate migration modules: #{inspect(duplicate_modules)}"
  end

  defp duplicate_values(entries, key_fun) do
    entries
    |> Enum.group_by(key_fun, & &1.path)
    |> Enum.filter(fn {_value, paths} -> length(paths) > 1 end)
  end
end
