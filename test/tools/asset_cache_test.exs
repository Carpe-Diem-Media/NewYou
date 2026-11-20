defmodule NewYou.AssetCacheTest do
  use ExUnit.Case, async: false

  test "asset binaries stay inside each selected worktree build directory" do
    previous_build = System.get_env("MIX_BUILD_PATH")
    previous_paths = Map.new([:esbuild, :tailwind], &{&1, Application.fetch_env(&1, :path)})

    root =
      Path.join(System.tmp_dir!(), "newyou-asset-cache-#{System.unique_integer([:positive])}")

    try do
      for suffix <- ["_build", "_build/test"] do
        build = Path.join(root, suffix)
        System.put_env("MIX_BUILD_PATH", build)
        config = Config.Reader.read!("config/config.exs", env: :test)

        for tool <- [:esbuild, :tailwind] do
          path = config |> Keyword.fetch!(tool) |> Keyword.fetch!(:path)
          Application.put_env(tool, :path, path)
          module = tool_module(tool)
          assert Path.dirname(module.bin_path()) == build
          refute File.exists?(path)
        end
      end
    after
      if previous_build,
        do: System.put_env("MIX_BUILD_PATH", previous_build),
        else: System.delete_env("MIX_BUILD_PATH")

      for {tool, value} <- previous_paths do
        case value do
          {:ok, path} -> Application.put_env(tool, :path, path)
          :error -> Application.delete_env(tool, :path)
        end
      end
    end
  end

  defp tool_module(:esbuild), do: Esbuild
  defp tool_module(:tailwind), do: Tailwind
end
