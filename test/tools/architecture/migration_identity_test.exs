defmodule NewYou.Architecture.MigrationIdentityTest do
  use ExUnit.Case, async: true

  test "repository migration names and modules are unique" do
    entries =
      Path.wildcard(Path.join(File.cwd!(), "priv/repo/migrations/*.exs"))
      |> Enum.map(fn path ->
        source = File.read!(path)
        {timestamp, migration_name} = migration_identity(path)
        migration_module = migration_module(source, path)

        %{
          path: path,
          timestamp: String.to_integer(timestamp),
          name: migration_name,
          module: migration_module
        }
      end)

    assert_unique(entries, & &1.timestamp, "migration timestamps")
    assert_unique(entries, & &1.name, "migration names")
    assert_unique(entries, & &1.module, "migration modules")
  end

  test "malformed migration filename reports its path" do
    path = "priv/repo/migrations/malformed_migration.exs"

    assert_raise ExUnit.AssertionError, ~r/invalid repository migration filename: #{path}/, fn ->
      migration_identity(path)
    end
  end

  test "migration module identity accepts indentation before defmodule" do
    assert migration_module("  defmodule NewYou.Repo.Migrations.Indented do\nend", "indented.exs") ==
             "NewYou.Repo.Migrations.Indented"
  end

  test "same migration timestamp is duplicated even when suffixes differ" do
    entries = [
      %{path: "20261114154132_analytics.exs", timestamp: 20_261_114_154_132},
      %{path: "20261114154132_analytics_revision.exs", timestamp: 20_261_114_154_132}
    ]

    assert duplicate_values(entries, & &1.timestamp) == [
             {20_261_114_154_132,
              ["20261114154132_analytics.exs", "20261114154132_analytics_revision.exs"]}
           ]

    assert_raise ExUnit.AssertionError, ~r/duplicate migration timestamps/, fn ->
      assert_unique(entries, & &1.timestamp, "migration timestamps")
    end
  end

  defp duplicate_values(entries, key_fun) do
    entries
    |> Enum.group_by(key_fun, & &1.path)
    |> Enum.filter(fn {_value, paths} -> length(paths) > 1 end)
  end

  defp assert_unique(entries, key_fun, label) do
    duplicates = duplicate_values(entries, key_fun)
    assert duplicates == [], "duplicate #{label}: #{inspect(duplicates)}"
  end

  defp migration_identity(path) do
    case Regex.run(~r/^([0-9]{14})_(.+)\.exs$/, Path.basename(path)) do
      [_, timestamp, migration_name] -> {timestamp, migration_name}
      _ -> flunk("invalid repository migration filename: #{path}")
    end
  end

  defp migration_module(source, path) do
    case Regex.run(~r/^[ \t]*defmodule\s+([A-Za-z0-9_.]+)\s+do/m, source) do
      [_, module] -> module
      _ -> flunk("missing migration module declaration: #{path}")
    end
  end
end
