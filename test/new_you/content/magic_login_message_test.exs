defmodule NewYou.Content.MagicLoginMessageTest do
  use ExUnit.Case, async: false

  alias NewYou.Content.MagicLoginMessage

  @repo_root Path.expand("../../..", __DIR__)
  @evidence_path "docs/delivery/content-evidence/content_media/magic_login_messages"

  setup do
    root =
      Path.join(System.tmp_dir!(), "magic-login-content-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)
    {:ok, _} = File.cp_r(Path.join(@repo_root, "docs"), Path.join(root, "docs"))
    Process.put({MagicLoginMessage, :evidence_root}, root)

    on_exit(fn ->
      Process.delete({MagicLoginMessage, :evidence_root})
      File.rm_rf!(root)
    end)

    {:ok, root: root}
  end

  test "returns exact approved bindings and artifact bytes for EN and AF" do
    for locale <- ["en", "af"] do
      assert {:ok, binding} = MagicLoginMessage.binding(locale)
      assert binding.content_item_id == "NEWYOU-CONTENTITEM-MAGIC-LOGIN-MESSAGE-EMAIL"
      assert binding.content_version_id == "NEWYOU-CONTENTVERSION-MAGIC-LOGIN-MESSAGE-EMAIL-V1"

      assert binding.translation_version_id ==
               "NEWYOU-CONTENTTRANSLATIONVERSION-MAGIC-LOGIN-MESSAGE-EMAIL-#{String.upcase(locale)}-V1"

      assert {:ok, bytes} = MagicLoginMessage.eligible(binding)
      assert byte_size(bytes) == if(locale == "en", do: 278, else: 327)
      assert :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower) == binding.content_sha256
      refute String.contains?(bytes, "https://")
    end
  end

  test "preserves prior authority lineage under the current Product v1.17 successor", %{
    root: root
  } do
    predecessor_digests = %{
      "docs/governance/product/00_PLATFORM_v1.16.0.md" =>
        "bcc26cec59b8157a4d284d6bb533ec16bf41e85b88d7c5c14ff1ec1141019174",
      "docs/governance/product/01_DECISIONS_v1.16.0.md" =>
        "1a5d6d7c2bb0ca2a595dd28e2e371340298aa0b62ff613939c5de141831eb7f8"
    }

    Enum.each(predecessor_digests, fn {path, expected_sha} ->
      bytes = File.read!(Path.join(root, path))
      assert :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower) == expected_sha
    end)

    for locale <- ["en", "af"] do
      assert {:ok, binding} = MagicLoginMessage.binding(locale)
      assert {:ok, bytes} = MagicLoginMessage.eligible(binding)
      assert byte_size(bytes) == if(locale == "en", do: 278, else: 327)
    end
  end

  test "rejects a wrong current Product successor route", %{root: root} do
    for {field, value} <- [
          {"repository_path", "docs/governance/product/00_PLATFORM_v1.14.0.md"},
          {"canonical_filename", "00_PLATFORM_v1.14.0.md"},
          {"sha256", String.duplicate("0", 64)},
          {"semver", "1.14.0"}
        ] do
      governance_router_path = Path.join(root, "docs/governance/CURRENT_GOVERNANCE_ROUTER.json")
      router = governance_router_path |> File.read!() |> Jason.decode!()

      governing_documents =
        Enum.map(router["governing_documents"], fn
          %{"document_id" => "PLATFORM_PRODUCT_LAW"} = document ->
            Map.put(document, field, value)

          document ->
            document
        end)

      File.write!(
        governance_router_path,
        Jason.encode!(%{router | "governing_documents" => governing_documents})
      )

      assert {:error, :content_ineligible} = MagicLoginMessage.binding("en")

      # Each mutation starts from a fresh copy of the repository evidence.
      if field != "semver" do
        File.rm_rf!(root)
        File.mkdir_p!(root)
        {:ok, _} = File.cp_r(Path.join(@repo_root, "docs"), Path.join(root, "docs"))
      end
    end
  end

  test "rejects a missing current Product successor route", %{root: root} do
    governance_router_path = Path.join(root, "docs/governance/CURRENT_GOVERNANCE_ROUTER.json")
    router = governance_router_path |> File.read!() |> Jason.decode!()

    governing_documents =
      Enum.reject(router["governing_documents"], &(&1["document_id"] == "PRODUCT_DECISIONS"))

    File.write!(
      governance_router_path,
      Jason.encode!(%{router | "governing_documents" => governing_documents})
    )

    assert {:error, :content_ineligible} = MagicLoginMessage.binding("af")
  end

  test "rejects a successor whose bytes change its Product predecessor lineage", %{root: root} do
    path =
      Path.join(root, "docs/governance/product/00_PLATFORM_v1.17.0.md")

    bytes = File.read!(path)

    changed =
      String.replace(
        bytes,
        "**Predecessor:** `docs/governance/product/00_PLATFORM_v1.16.0.md`",
        "**Predecessor:** `docs/governance/product/00_PLATFORM_v1.13.0.md`"
      )

    refute changed == bytes
    File.write!(path, changed)

    governance_router_path = Path.join(root, "docs/governance/CURRENT_GOVERNANCE_ROUTER.json")
    router = governance_router_path |> File.read!() |> Jason.decode!()

    governing_documents =
      Enum.map(router["governing_documents"], fn
        %{"document_id" => "PLATFORM_PRODUCT_LAW"} = document ->
          Map.put(
            document,
            "sha256",
            :crypto.hash(:sha256, changed) |> Base.encode16(case: :lower)
          )

        document ->
          document
      end)

    File.write!(
      governance_router_path,
      Jason.encode!(%{router | "governing_documents" => governing_documents})
    )

    assert {:error, :content_ineligible} = MagicLoginMessage.binding("en")
  end

  test "rejects changed historical v1.14 approval provenance", %{root: root} do
    path =
      Path.join(root, "docs/governance/product/proposals/well-97/00_PLATFORM_v1.14.0_PROPOSED.md")

    File.write!(path, File.read!(path) <> "\n")

    assert {:error, :content_ineligible} = MagicLoginMessage.binding("af")
  end

  test "rejects corrupted recovery approval proposal and previous successor", %{root: root} do
    for path <- [
          "docs/delivery/content-evidence/content_media/recovery_messages/PRODUCT_CLASSIFICATION_PROPOSALS_v0.1.0.md",
          "docs/governance/product/00_PLATFORM_v1.15.0.md",
          "docs/governance/product/proposals/well-98/01_DECISIONS_v1.15.0_PROPOSED.md"
        ] do
      full_path = Path.join(root, path)
      original = File.read!(full_path)
      File.write!(full_path, original <> "\n")
      assert {:error, :content_ineligible} = MagicLoginMessage.binding("af")
      File.write!(full_path, original)
    end
  end

  test "rejects unsupported locales without fallback" do
    assert {:error, :content_ineligible} = MagicLoginMessage.binding("en-GB")
    assert {:error, :content_ineligible} = MagicLoginMessage.binding("zu")
  end

  test "eligible requires the exact current binding" do
    assert {:ok, binding} = MagicLoginMessage.binding("en")

    for changed <- [
          %{binding | locale: "af"},
          %{binding | content_item_id: "another-item"},
          %{binding | content_version_id: "another-version"},
          %{binding | translation_version_id: "another-translation"},
          %{binding | content_sha256: String.duplicate("0", 64)}
        ] do
      assert {:error, :content_ineligible} = MagicLoginMessage.eligible(changed)
    end
  end

  test "fails closed when the packet is withdrawn", %{root: root} do
    update_packet(root, fn packet -> put_in(packet, ["lifecycle", "state"], "withdrawn") end)

    assert {:error, :content_ineligible} = MagicLoginMessage.binding("en")
  end

  test "fails closed when owner history contains a conflicting event", %{root: root} do
    update_packet(root, fn packet ->
      [first | _] = packet["approval_events"]

      put_in(
        packet,
        ["approval_events"],
        packet["approval_events"] ++ [%{first | "decision" => "reject"}]
      )
    end)

    assert {:error, :content_ineligible} = MagicLoginMessage.binding("af")
  end

  test "fails closed when the current delivery route no longer selects the approved packet", %{
    root: root
  } do
    router_path = Path.join(root, "docs/delivery/CURRENT_DELIVERY_ROUTER.json")
    router = router_path |> File.read!() |> Jason.decode!()

    contracts =
      Enum.map(router["delivery_contracts"], fn
        %{"document_id" => "MAGIC_LOGIN_MESSAGE_DEVELOPMENT_EVIDENCE"} = contract ->
          %{contract | "status" => "WITHDRAWN"}

        contract ->
          contract
      end)

    File.write!(router_path, Jason.encode!(%{router | "delivery_contracts" => contracts}))

    assert {:error, :content_ineligible} = MagicLoginMessage.binding("en")
  end

  test "fails closed when the accountable owner record changes", %{root: root} do
    path = Path.join([root, @evidence_path, "OWNER_APPROVALS_v1.json"])
    File.write!(path, File.read!(path) <> "\n")

    assert {:error, :content_ineligible} = MagicLoginMessage.binding("af")
  end

  test "does not fall back to the checkout when the selected packet is missing", %{root: root} do
    File.rm!(
      Path.join(root, @evidence_path <> "/MAGIC_LOGIN_MESSAGE_EVIDENCE_PACKET_v0.2.0.json")
    )

    assert {:error, :content_ineligible} = MagicLoginMessage.binding("en")
  end

  test "does not fall back to the checkout when the selected router is missing", %{root: root} do
    File.rm!(Path.join(root, "docs/delivery/CURRENT_DELIVERY_ROUTER.json"))

    assert {:error, :content_ineligible} = MagicLoginMessage.binding("af")
  end

  test "does not fall back to the checkout for an explicitly empty evidence root" do
    empty_root =
      Path.join(System.tmp_dir!(), "magic-login-empty-#{System.unique_integer([:positive])}")

    File.mkdir_p!(empty_root)
    Process.put({MagicLoginMessage, :evidence_root}, empty_root)

    on_exit(fn -> File.rm_rf!(empty_root) end)

    assert {:error, :content_ineligible} = MagicLoginMessage.binding("en")
  end

  test "fails closed when approved artifact bytes change", %{root: root} do
    assert {:ok, binding} = MagicLoginMessage.binding("en")
    path = Path.join([root, @evidence_path, "NEWYOU-MAGIC-LOGIN-MESSAGE-EMAIL-EN-V1.txt"])
    File.write!(path, File.read!(path) <> "changed")

    assert {:error, :content_ineligible} = MagicLoginMessage.eligible(binding)
  end

  defp update_packet(root, update) do
    path = Path.join([root, @evidence_path, "MAGIC_LOGIN_MESSAGE_EVIDENCE_PACKET_v0.2.0.json"])
    packet = path |> File.read!() |> Jason.decode!() |> update.()
    bytes = Jason.encode!(packet)
    File.write!(path, bytes)

    router_path = Path.join(root, "docs/delivery/CURRENT_DELIVERY_ROUTER.json")
    router = router_path |> File.read!() |> Jason.decode!()

    contracts =
      Enum.map(router["delivery_contracts"], fn
        %{"document_id" => "MAGIC_LOGIN_MESSAGE_DEVELOPMENT_EVIDENCE"} = contract ->
          %{contract | "sha256" => :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)}

        contract ->
          contract
      end)

    File.write!(router_path, Jason.encode!(%{router | "delivery_contracts" => contracts}))
  end
end
