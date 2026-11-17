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

  test "local core PLTs use a private worktree path while project PLTs stay local" do
    for value <- [nil, "false"] do
      if value do
        System.put_env("GITHUB_ACTIONS", value)
      else
        System.delete_env("GITHUB_ACTIONS")
      end

      config = NewYou.MixProject.project()[:dialyzer]
      assert config[:plt_core_path] == "_build/plts/local-core"
      assert config[:plt_local_path] == "_build/plts"
      assert config[:plt_add_apps] == [:mix, :ex_unit, :dialyxir]
    end
  end

  test "GitHub Actions keeps core and project PLTs in the hosted cache" do
    System.put_env("GITHUB_ACTIONS", "true")
    config = NewYou.MixProject.project()[:dialyzer]

    assert config[:plt_core_path] == "_build/plts"
    assert config[:plt_local_path] == "_build/plts"
    assert config[:plt_add_apps] == [:mix, :ex_unit, :dialyxir]
  end

  test "deep verification still performs Dialyzer analysis" do
    aliases = NewYou.MixProject.project()[:aliases]

    assert aliases[:dialyzer] == ["local_dialyzer"]

    assert Keyword.fetch!(aliases, :"check.deep") == [
             "local_dialyzer --format dialyxir"
           ]
  end

  test "local core PLT cache adapter preserves isolation and publication invariants" do
    {output, status} =
      System.cmd(
        "python3",
        ["-m", "unittest", "discover", "-s", "tests", "-p", "test_local_plt_cache.py"],
        cd: File.cwd!(),
        stderr_to_stdout: true
      )

    assert status == 0, output
  end

  test "cache key core plans are JSON encodable" do
    plan = [{"dialyxir_erlang-27.2.plt", ["erts", "kernel"]}]

    assert Jason.decode!(Jason.encode!(Mix.Tasks.LocalDialyzer.normalize_core_apps(plan))) == [
             %{"basename" => "dialyxir_erlang-27.2.plt", "apps" => ["erts", "kernel"]}
           ]
  end

  test "Dialyxir source hashes ignore worktree location" do
    unique = System.unique_integer([:positive])

    roots = [
      Path.join(System.tmp_dir!(), "newyou-plt-source-a-#{unique}"),
      Path.join(System.tmp_dir!(), "newyou-plt-source-b-#{unique}")
    ]

    try do
      hashes =
        Enum.map(roots, fn root ->
          source = Path.join(root, "deps/dialyxir/lib/dialyxir/project.ex")
          File.mkdir_p!(Path.dirname(source))
          File.write!(source, "same pinned source")
          Mix.Tasks.LocalDialyzer.source_hash([source], Path.join(root, "deps/dialyxir"))
        end)

      assert Enum.uniq(hashes) |> length() == 1
    after
      Enum.each(roots, &File.rm_rf!/1)
    end
  end

  test "cache identity rejects missing Dialyxir source and core inputs" do
    root =
      Path.join(System.tmp_dir!(), "newyou-plt-identity-#{System.unique_integer([:positive])}")

    source = Path.join(root, "dialyxir/lib/project.ex")
    beam = Path.join(root, "kernel/kernel.beam")
    app = Path.join(root, "kernel/kernel.app")

    File.mkdir_p!(Path.dirname(source))
    File.mkdir_p!(Path.dirname(beam))
    File.write!(source, "source")
    File.write!(beam, "beam")
    File.write!(app, "app")

    try do
      plan = [{"erlang.plt", ["kernel"]}]
      inputs = %{"kernel" => [beam, app]}

      assert :ok =
               Mix.Tasks.LocalDialyzer.validate_identity_inputs!(
                 plan,
                 [source],
                 inputs,
                 "1.4.8",
                 "29.1.2"
               )

      assert_raise ArgumentError, ~r/source inputs/, fn ->
        Mix.Tasks.LocalDialyzer.validate_identity_inputs!(plan, [], inputs, "1.4.8", "29.1.2")
      end

      for partial <- [[beam], [app], [beam, app <> ".missing"]] do
        assert_raise ArgumentError, ~r/core applications/, fn ->
          Mix.Tasks.LocalDialyzer.validate_identity_inputs!(
            plan,
            [source],
            %{"kernel" => partial},
            "1.4.8",
            "29.1.2"
          )
        end
      end

      assert_raise ArgumentError, ~r/version is unavailable/, fn ->
        Mix.Tasks.LocalDialyzer.validate_identity_inputs!(plan, [source], inputs, "1.4.8", "")
      end

      assert_raise ArgumentError, fn ->
        Mix.Tasks.LocalDialyzer.validate_identity_inputs!(
          [],
          [],
          %{"kernel" => [beam, app]},
          "1.4.8",
          "27.2.1"
        )
      end

      assert_raise ArgumentError, fn ->
        Mix.Tasks.LocalDialyzer.validate_identity_inputs!(
          [{"erlang.plt", ["kernel"]}],
          [source],
          %{},
          "1.4.8",
          "27.2.1"
        )
      end

      assert_raise ArgumentError, fn ->
        Mix.Tasks.LocalDialyzer.validate_identity_inputs!(
          [{"erlang.plt", ["kernel"]}],
          [source],
          %{"kernel" => [beam, app]},
          "",
          "27.2.1"
        )
      end
    after
      File.rm_rf!(root)
    end
  end
end
