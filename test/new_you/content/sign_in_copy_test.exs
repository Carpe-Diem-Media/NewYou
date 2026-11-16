defmodule NewYou.Content.SignInCopyTest do
  use ExUnit.Case, async: true

  alias NewYou.Content.SignInCopy

  @moduletag :tmp_dir

  setup %{tmp_dir: root} do
    fixture_dir = Path.join(root, "docs/development/fixtures")
    File.mkdir_p!(fixture_dir)

    for name <- ~w(well134-c01-v0.1.json well134-c01-owner-approval.json) do
      File.cp!(Path.join("docs/development/fixtures", name), Path.join(fixture_dir, name))
    end

    module = Module.concat(__MODULE__, "Isolated#{System.unique_integer([:positive])}")

    source =
      "lib/new_you/content/sign_in_copy.ex"
      |> File.read!()
      |> String.replace(
        "defmodule NewYou.Content.SignInCopy do",
        "defmodule #{inspect(module)} do"
      )

    on_exit(fn ->
      :code.purge(module)
      :code.delete(module)
    end)

    {:ok,
     module: module,
     source: source,
     source_path: Path.join(root, "lib/new_you/content/sign_in_copy.ex"),
     artifact: Path.join(fixture_dir, "well134-c01-v0.1.json"),
     approval: Path.join(fixture_dir, "well134-c01-owner-approval.json")}
  end

  test "modified compile-time text cannot become eligible after the approved file is restored",
       ctx do
    approved = File.read!(ctx.artifact)

    changed =
      approved
      |> Jason.decode!()
      |> put_in(["entries", "identity.login.title", "en", "text"], "UNAPPROVED COMPILED TEXT")
      |> Jason.encode!()

    File.write!(ctx.artifact, changed)

    result =
      try do
        Code.compile_string(ctx.source, ctx.source_path)
        :compiled
      rescue
        error in ArgumentError -> {:rejected, Exception.message(error)}
      after
        File.write!(ctx.artifact, approved)
      end

    assert File.read!(ctx.artifact) == approved

    case result do
      :compiled ->
        refute ctx.module.available?()
        assert_raise ArgumentError, fn -> ctx.module.text!("identity.login.title", "en") end

      {:rejected, message} ->
        assert message == "WELL-134 compile-time copy is not the pinned owner-approved version"
        refute Code.ensure_loaded?(ctx.module)
    end
  end

  test "modified approval bytes are rejected before embedding text", ctx do
    File.write!(ctx.approval, File.read!(ctx.approval) <> "\n")

    assert_raise ArgumentError,
                 "WELL-134 compile-time copy is not the pinned owner-approved version",
                 fn -> Code.compile_string(ctx.source, ctx.source_path) end

    refute Code.ensure_loaded?(ctx.module)
  end

  test "approved compiled text retains current-source eligibility without fallback", ctx do
    Code.compile_string(ctx.source, ctx.source_path)
    assert ctx.module.available?()
    assert ctx.module.text!("identity.login.title", "en") == "Log in to your account"
    assert ctx.module.text!("identity.login.title", "af") == "Meld aan by jou rekening"
    assert_raise KeyError, fn -> ctx.module.text!("missing.key", "en") end
    assert_raise ArgumentError, fn -> ctx.module.text!("identity.login.title", "nl") end

    for path <- [ctx.artifact, ctx.approval], change <- [:missing, :changed, :withdrawn] do
      approved = File.read!(path)

      try do
        case change do
          :missing ->
            File.rm!(path)

          :changed ->
            File.write!(path, approved <> "\n")

          :withdrawn ->
            File.write!(
              path,
              path
              |> File.read!()
              |> Jason.decode!()
              |> Map.put("status", "withdrawn")
              |> Jason.encode!()
            )
        end

        refute ctx.module.available?()
        assert_raise ArgumentError, fn -> ctx.module.text!("identity.login.title", "en") end
      after
        File.write!(path, approved)
      end

      assert ctx.module.available?()
    end
  end

  test "only the exact owner-approved bilingual development version is eligible" do
    assert SignInCopy.available?()
    assert SignInCopy.text!("identity.login.title", "en") == "Log in to your account"
    assert SignInCopy.text!("identity.login.title", "af") == "Meld aan by jou rekening"
    assert SignInCopy.text!("shared.navigation.logout", "af") == "Meld af"

    assert_raise KeyError, fn -> SignInCopy.text!("identity.login.unverified", "en") end
    assert_raise ArgumentError, fn -> SignInCopy.text!("identity.login.title", "nl") end
  end

  test "a changed locale, approval, scope, lifecycle or source digest cannot acquire eligibility" do
    bytes = File.read!(SignInCopy.artifact_path())
    approved = Jason.decode!(bytes)
    assert SignInCopy.valid_artifact?(approved)

    candidates = [
      put_in(approved, ["status"], "withdrawn"),
      put_in(approved, ["status"], "superseded"),
      put_in(approved, ["approval", "comment_id"], Ecto.UUID.generate()),
      put_in(approved, ["approval", "canonical_payload_sha256"], String.duplicate("0", 64)),
      put_in(approved, ["allowed_contexts"], ["production"]),
      put_in(approved, ["prohibited_contexts"], []),
      put_in(approved, ["entries", "identity.login.title", "af", "text"], "Teken in"),
      update_in(approved, ["entries", "identity.login.title"], &Map.delete(&1, "af")),
      Map.delete(approved, "version_id")
    ]

    for candidate <- candidates do
      refute SignInCopy.valid_artifact?(candidate)
    end
  end

  test "all locale strings retain the literal owner table bytes and individual digests" do
    approved = SignInCopy.artifact_path() |> File.read!() |> Jason.decode!()

    source =
      "docs/development/fixtures/well134-c01-owner-approval.json"
      |> File.read!()
      |> Jason.decode!()

    rows = source["comment_html"] |> LazyHTML.from_document() |> LazyHTML.query("tbody tr")
    assert Enum.count(rows) == 37

    keys =
      Enum.map(rows, fn row ->
        [_journey, key, en, af, _security] =
          row |> LazyHTML.query("td") |> Enum.map(&LazyHTML.text/1)

        for {locale, expected} <- [{"en", en}, {"af", af}] do
          entry = approved["entries"][key][locale]
          assert entry["text"] == expected
          assert entry["bytes"] == byte_size(expected)
          assert entry["sha256"] == Base.encode16(:crypto.hash(:sha256, expected), case: :lower)
          assert SignInCopy.text!(key, locale) == expected
        end

        key
      end)

    assert Enum.sort(Enum.uniq(keys)) == Enum.sort(Map.keys(approved["entries"]))
  end
end
