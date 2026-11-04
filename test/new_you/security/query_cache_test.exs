defmodule NewYou.Security.QueryCacheTest do
  use ExUnit.Case, async: true

  import Ecto.Query

  # Exercise the planner used by AshPostgres without issuing business writes.
  # Distinct request values must never accumulate permanent query cache keys.
  test "interpolated JSON paths do not produce cache keys" do
    for path <- [["first"], ["second", "nested"]] do
      query = from(row in "cache_probe", select: json_extract_path(row.meta, ^path))
      assert cache_key(query) == :nocache
    end
  end

  test "splice list lengths do not produce cache keys" do
    for values <- [[1], [1, 2, 3]] do
      query = from(row in "cache_probe", where: fragment("? IN (?)", row.id, splice(^values)))
      assert cache_key(query) == :nocache
    end
  end

  test "interpolated constants do not produce cache keys" do
    for value <- [1, 2] do
      query = from(row in "cache_probe", select: fragment("?", constant(^value)))
      assert cache_key(query) == :nocache
    end
  end

  test "ordinary bound values remain cacheable" do
    value = 1
    query = from(row in "cache_probe", where: row.id == ^value, select: row.id)
    refute cache_key(query) == :nocache
  end

  defp cache_key(query) do
    {_query, _params, key} = Ecto.Query.Planner.plan(query, :all, Ecto.Adapters.Postgres)
    key
  end
end
