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
end
