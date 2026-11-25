defmodule NewYou.Content.RecoveryBrowserCopyTest do
  use ExUnit.Case, async: true

  alias NewYou.Content.RecoveryBrowserCopy

  @root Path.expand("../../..", __DIR__)
  @route_id "FP001_RECOVERY_PHASE9_BROWSER_COPY_APPROVED"
  @delivery "docs/delivery/CURRENT_DELIVERY_ROUTER.json"
  @governance "docs/governance/CURRENT_GOVERNANCE_ROUTER.json"
  @packet "docs/delivery/content-evidence/copy/evidence/FP001_RECOVERY_PHASE9_BROWSER_COPY_APPROVED_v0.3.0.json"
  @candidate "docs/delivery/content-evidence/copy/evidence/WELL183_RECOVERY_PHASE9_BROWSER_COPY_CANDIDATE_v0.3.0.json"
  @product_documents [
    "docs/governance/product/00_PLATFORM_v1.19.0.md",
    "docs/governance/product/00_PLATFORM_v1.20.0.md",
    "docs/governance/product/00_PLATFORM_v1.21.0.md",
    "docs/governance/product/01_DECISIONS_v1.19.0.md",
    "docs/governance/product/01_DECISIONS_v1.20.0.md",
    "docs/governance/product/01_DECISIONS_v1.21.0.md"
  ]

  # Evidence is copied into a temporary root and read through the test-only seam.
  # Repository evidence is never modified.
  setup do
    root =
      Path.join(System.tmp_dir!(), "recovery_browser_copy_#{System.unique_integer([:positive])}")

    for relative <- [@delivery, @governance, @packet | @product_documents] do
      destination = Path.join(root, relative)
      File.mkdir_p!(Path.dirname(destination))
      File.cp!(Path.join(@root, relative), destination)
    end

    Process.put({RecoveryBrowserCopy, :evidence_root}, root)
    on_exit(fn -> File.rm_rf!(root) end)

    %{root: root}
  end

  test "loads the approved EN and AF wording from the routed packet" do
    assert {:ok, en} = RecoveryBrowserCopy.load("en")
    assert map_size(en) == 18
    assert en["identity.recovery.request.title"] == "Recover your account"

    assert {:ok, af} = RecoveryBrowserCopy.load("af")
    assert af["identity.recovery.request.title"] == "Herstel jou rekening"
  end

  test "denies an unsupported locale instead of falling back" do
    assert {:error, :content_ineligible} = RecoveryBrowserCopy.load("fr")
  end

  test "denies when the approved packet is missing", %{root: root} do
    File.rm!(Path.join(root, @packet))

    assert {:error, :content_ineligible} = RecoveryBrowserCopy.load("en")
  end

  test "denies when the approved packet bytes changed", %{root: root} do
    edit(root, @packet, &(&1 <> "\n"))

    assert {:error, :content_ineligible} = RecoveryBrowserCopy.load("en")
    assert {:error, :content_ineligible} = RecoveryBrowserCopy.load("af")
  end

  test "denies when the delivery route row is missing", %{root: root} do
    edit_json(root, @delivery, fn doc ->
      Map.update!(doc, "delivery_contracts", fn rows ->
        Enum.reject(rows, &(&1["document_id"] == @route_id))
      end)
    end)

    assert {:error, :content_ineligible} = RecoveryBrowserCopy.load("en")
  end

  test "denies when the delivery route pins a different digest", %{root: root} do
    edit_json(
      root,
      @delivery,
      &update_route(&1, fn row -> Map.put(row, "sha256", String.duplicate("0", 64)) end)
    )

    assert {:error, :content_ineligible} = RecoveryBrowserCopy.load("en")
  end

  test "denies when a current Product document changed under the packet", %{root: root} do
    edit(root, "docs/governance/product/00_PLATFORM_v1.21.0.md", &(&1 <> "\n"))

    assert {:error, :content_ineligible} = RecoveryBrowserCopy.load("en")
  end

  test "denies a candidate file at the served path by its unpinned digest", %{root: root} do
    File.cp!(Path.join(@root, @candidate), Path.join(root, @packet))

    assert {:error, :content_ineligible} = RecoveryBrowserCopy.load("en")
  end

  defp edit(root, relative, change) do
    path = Path.join(root, relative)
    File.write!(path, change.(File.read!(path)))
  end

  defp edit_json(root, relative, change) do
    edit(root, relative, &(&1 |> Jason.decode!() |> change.() |> Jason.encode!()))
  end

  defp update_route(doc, change) do
    Map.update!(doc, "delivery_contracts", fn rows ->
      Enum.map(rows, fn
        %{"document_id" => @route_id} = row -> change.(row)
        row -> row
      end)
    end)
  end
end
