defmodule NewYou.DialyzerCacheTest do
  use ExUnit.Case, async: false

  setup do
    original = System.get_env("GITHUB_ACTIONS")

    on_exit(fn ->
      if original do
        System.put_env("GITHUB_ACTIONS", original)
      else
        System.delete_env("GITHUB_ACTIONS")
      end
    end)
  end

  test "local core PLTs use Mix home while project PLTs stay local" do
    for value <- [nil, "false"] do
      if value do
        System.put_env("GITHUB_ACTIONS", value)
      else
        System.delete_env("GITHUB_ACTIONS")
      end

      config = NewYou.MixProject.project()[:dialyzer]
      assert config[:plt_core_path] == Mix.Utils.mix_home()
      assert config[:plt_local_path] == "_build/plts"
      assert config[:plt_add_apps] == [:mix, :ex_unit]
    end
  end

  test "GitHub Actions keeps core and project PLTs in the hosted cache" do
    System.put_env("GITHUB_ACTIONS", "true")
    config = NewYou.MixProject.project()[:dialyzer]

    assert config[:plt_core_path] == "_build/plts"
    assert config[:plt_local_path] == "_build/plts"
    assert config[:plt_add_apps] == [:mix, :ex_unit]
  end

  test "deep verification still performs Dialyzer analysis" do
    assert NewYou.MixProject.project()[:aliases][:"check.deep"] == [
             "dialyzer --format dialyxir"
           ]
  end
end
