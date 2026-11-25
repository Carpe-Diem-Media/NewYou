defmodule NewYou.Content.ProductAuthorityTest do
  use ExUnit.Case, async: true

  alias NewYou.Content.ProductAuthority

  @root Path.expand("../../..", __DIR__)
  @platform_v1_21 "docs/governance/product/00_PLATFORM_v1.21.0.md"
  @platform_v1_20 "docs/governance/product/00_PLATFORM_v1.20.0.md"
  @platform_v1_19 "docs/governance/product/00_PLATFORM_v1.19.0.md"
  @decisions_v1_21 "docs/governance/product/01_DECISIONS_v1.21.0.md"
  @decisions_v1_20 "docs/governance/product/01_DECISIONS_v1.20.0.md"

  setup do
    governance =
      @root
      |> Path.join("docs/governance/CURRENT_GOVERNANCE_ROUTER.json")
      |> File.read!()
      |> Jason.decode!()

    %{governance: governance}
  end

  # Reads the repository, except for paths replaced by the test.
  defp reader(replacements \\ %{}) do
    fn path ->
      case Map.fetch(replacements, path) do
        {:ok, bytes} -> {:ok, bytes}
        :error -> File.read(Path.join(@root, path))
      end
    end
  end

  defp tampered(path), do: File.read!(Path.join(@root, path)) <> "\n"

  defp with_router_rows(governance, document_id, change) do
    Map.update!(governance, "governing_documents", fn rows ->
      Enum.map(rows, fn
        %{"document_id" => ^document_id} = row -> change.(row)
        row -> row
      end)
    end)
  end

  test "accepts the current 1.21 chain and returns the verified 1.19 bindings", %{
    governance: governance
  } do
    assert {:ok, bindings} = ProductAuthority.historical_bindings(governance, reader())

    assert Enum.sort(Enum.map(bindings, & &1["document_id"])) ==
             ["PLATFORM_PRODUCT_LAW", "PRODUCT_DECISIONS"]

    assert Enum.all?(bindings, &(&1["semver"] == "1.19.0"))
  end

  test "denies when the current 1.21 Product Law changed", %{governance: governance} do
    replacements = %{@platform_v1_21 => tampered(@platform_v1_21)}

    assert {:error, :content_ineligible} =
             ProductAuthority.historical_bindings(governance, reader(replacements))
  end

  test "denies when the 1.20 predecessor changed, even though 1.21 still matches", %{
    governance: governance
  } do
    replacements = %{@platform_v1_20 => tampered(@platform_v1_20)}

    assert {:error, :content_ineligible} =
             ProductAuthority.historical_bindings(governance, reader(replacements))
  end

  test "denies when the current 1.21 Product Decisions changed", %{governance: governance} do
    replacements = %{@decisions_v1_21 => tampered(@decisions_v1_21)}

    assert {:error, :content_ineligible} =
             ProductAuthority.historical_bindings(governance, reader(replacements))
  end

  test "denies when the 1.20 predecessor Product Decisions changed, even though 1.21 still matches",
       %{governance: governance} do
    replacements = %{@decisions_v1_20 => tampered(@decisions_v1_20)}

    assert {:error, :content_ineligible} =
             ProductAuthority.historical_bindings(governance, reader(replacements))
  end

  test "denies when the 1.20 predecessor cannot be read", %{governance: governance} do
    unreadable = fn path ->
      if path == @platform_v1_20, do: {:error, :enoent}, else: reader().(path)
    end

    assert {:error, :content_ineligible} =
             ProductAuthority.historical_bindings(governance, unreadable)
  end

  test "denies when the 1.19 binding that backs pre-WELL-175 evidence changed", %{
    governance: governance
  } do
    replacements = %{@platform_v1_19 => tampered(@platform_v1_19)}

    assert {:error, :content_ineligible} =
             ProductAuthority.historical_bindings(governance, reader(replacements))
  end

  test "denies a router that still names the superseded 1.20 Product Law", %{
    governance: governance
  } do
    stale =
      with_router_rows(governance, "PLATFORM_PRODUCT_LAW", fn row ->
        %{
          row
          | "canonical_filename" => "00_PLATFORM_v1.20.0.md",
            "repository_path" => @platform_v1_20,
            "semver" => "1.20.0"
        }
      end)

    assert {:error, :content_ineligible} = ProductAuthority.historical_bindings(stale, reader())
  end

  test "denies a router row whose pinned digest is not the 1.21 digest", %{
    governance: governance
  } do
    stale =
      with_router_rows(governance, "PRODUCT_DECISIONS", fn row ->
        %{row | "sha256" => String.duplicate("0", 64)}
      end)

    assert {:error, :content_ineligible} = ProductAuthority.historical_bindings(stale, reader())
  end

  test "denies when a current Product document has no router row", %{governance: governance} do
    missing =
      Map.update!(governance, "governing_documents", fn rows ->
        Enum.reject(rows, &(&1["document_id"] == "PRODUCT_DECISIONS"))
      end)

    assert {:error, :content_ineligible} = ProductAuthority.historical_bindings(missing, reader())
  end

  test "denies malformed router input instead of raising" do
    assert {:error, :content_ineligible} = ProductAuthority.historical_bindings(%{}, reader())
    assert {:error, :content_ineligible} = ProductAuthority.historical_bindings(nil, reader())
  end
end
