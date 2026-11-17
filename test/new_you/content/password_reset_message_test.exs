defmodule NewYou.Content.PasswordResetMessageTest do
  use ExUnit.Case, async: false

  alias NewYou.Content.PasswordResetMessage

  @repo_root Path.expand("../../..", __DIR__)

  setup do
    root =
      Path.join(System.tmp_dir!(), "password-reset-content-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)
    {:ok, _} = File.cp_r(Path.join(@repo_root, "docs"), Path.join(root, "docs"))
    Process.put({PasswordResetMessage, :evidence_root}, root)

    on_exit(fn ->
      Process.delete({PasswordResetMessage, :evidence_root})
      File.rm_rf!(root)
    end)

    {:ok, root: root}
  end

  test "current v1.18 authority accepts approved content and rejects changed v1.17 lineage", %{
    root: root
  } do
    assert {:ok, _} = PasswordResetMessage.binding("en")
    path = Path.join(root, "docs/governance/product/00_PLATFORM_v1.17.0.md")
    File.write!(path, File.read!(path) <> "\n")
    assert {:error, :content_ineligible} = PasswordResetMessage.binding("en")
  end

  test "returns exact approved bytes for EN V1 and AF V2" do
    for {locale, suffix, size, digest} <- [
          {"en", "EN-V1", 369,
           "71c213c2ae48edf499d7d6d4191d84076a366d6fbd59607c8b842c830d33928c"},
          {"af", "AF-V2", 401, "ec1251d149b54692df2751760b72d1766d99537d4fa22b9b06da828bafe9ec93"}
        ] do
      assert {:ok, binding} = PasswordResetMessage.binding(locale)
      assert binding.content_item_id == "NEWYOU-CONTENTITEM-PASSWORD-RESET-MESSAGE-EMAIL"
      assert binding.content_version_id == "NEWYOU-CONTENTVERSION-PASSWORD-RESET-MESSAGE-EMAIL-V1"

      assert binding.translation_version_id ==
               "NEWYOU-CONTENTTRANSLATIONVERSION-PASSWORD-RESET-MESSAGE-EMAIL-#{suffix}"

      assert binding.content_sha256 == digest
      assert {:ok, bytes} = PasswordResetMessage.eligible(binding)
      assert byte_size(bytes) == size
      assert :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower) == digest
    end
  end

  test "WELL-136 consumption requires its exact current context and successor evidence", %{
    root: root
  } do
    for locale <- ["en", "af"] do
      assert {:ok, binding} = PasswordResetMessage.binding(locale, :well136)
      assert {:ok, _bytes} = PasswordResetMessage.eligible(binding, :well136)
      assert {:error, :content_ineligible} = PasswordResetMessage.binding(locale, :production)
      assert {:error, :content_ineligible} = PasswordResetMessage.binding(locale, :phase9)
    end

    path =
      Path.join(
        root,
        "docs/delivery/content-evidence/content_media/password_reset_messages/PASSWORD_RESET_MESSAGE_WELL136_PHASE9_ELIGIBILITY_v0.3.0.json"
      )

    original = File.read!(path)
    packet = Jason.decode!(original)

    for altered <- [
          put_in(packet, ["lifecycle", "state"], "withdrawn"),
          Map.put(packet, "new_applicability_events", []),
          put_in(packet, ["eligibility", "other_phase9"], true)
        ] do
      File.write!(path, Jason.encode!(altered))
      assert {:error, :content_ineligible} = PasswordResetMessage.binding("en", :well136)
      assert {:ok, _} = PasswordResetMessage.binding("en")
    end

    File.write!(path, original)
    assert {:ok, _} = PasswordResetMessage.binding("af", :well136)
  end

  test "WELL-136 binding, route and complete historical lineage are rechecked before delivery", %{
    root: root
  } do
    assert {:ok, binding} = PasswordResetMessage.binding("en", :well136)

    for changed <- [
          Map.put(binding, :locale, "af"),
          Map.put(binding, :translation_version_id, "latest"),
          Map.put(binding, :content_sha256, String.duplicate("0", 64))
        ] do
      assert {:error, :content_ineligible} = PasswordResetMessage.eligible(changed, :well136)
    end

    router_path = Path.join(root, "docs/delivery/CURRENT_DELIVERY_ROUTER.json")
    original = File.read!(router_path)
    router = Jason.decode!(original)

    contracts =
      Enum.reject(
        router["delivery_contracts"],
        &(&1["document_id"] == "PASSWORD_RESET_MESSAGE_WELL136_PHASE9_DEVELOPMENT_EVIDENCE")
      )

    File.write!(router_path, Jason.encode!(%{router | "delivery_contracts" => contracts}))
    assert {:error, :content_ineligible} = PasswordResetMessage.eligible(binding, :well136)
    File.write!(router_path, original)
    assert {:ok, _} = PasswordResetMessage.eligible(binding, :well136)

    locale_path =
      Path.join(
        root,
        "docs/delivery/content-evidence/content_media/password_reset_messages/NEWYOU-PASSWORD-RESET-MESSAGE-EMAIL-AF-V2.txt"
      )

    File.write!(locale_path, File.read!(locale_path) <> "\n")
    assert {:error, :content_ineligible} = PasswordResetMessage.eligible(binding, :well136)
  end

  for status <- ["WITHDRAWN", "SUPERSEDED", nil] do
    @status status
    test "WELL-136 denies new binding and delivery with router status #{inspect(status)}", %{
      root: root
    } do
      bindings =
        for locale <- ["en", "af"] do
          assert {:ok, binding} = PasswordResetMessage.binding(locale, :well136)
          {locale, binding}
        end

      path = Path.join(root, "docs/delivery/CURRENT_DELIVERY_ROUTER.json")
      original = File.read!(path)
      router = Jason.decode!(original)

      altered =
        if is_nil(@status),
          do: Map.delete(router, "status"),
          else: Map.put(router, "status", @status)

      File.write!(path, Jason.encode!(altered))

      for {locale, binding} <- bindings do
        assert {:error, :content_ineligible} = PasswordResetMessage.binding(locale, :well136)
        assert {:error, :content_ineligible} = PasswordResetMessage.eligible(binding, :well136)
      end

      File.write!(path, original)

      for {locale, binding} <- bindings do
        assert {:ok, ^binding} = PasswordResetMessage.binding(locale, :well136)
        assert {:ok, _} = PasswordResetMessage.eligible(binding, :well136)
      end
    end
  end

  test "rejects corrupted successor authority and approval proposal", %{root: root} do
    for path <- [
          "docs/governance/product/00_PLATFORM_v1.16.0.md",
          "docs/governance/product/01_DECISIONS_v1.16.0.md",
          "docs/delivery/content-evidence/content_media/recovery_messages/PRODUCT_CLASSIFICATION_PROPOSALS_v0.1.0.md",
          "docs/governance/product/proposals/well-98/00_PLATFORM_v1.15.0_PROPOSED.md"
        ] do
      full_path = Path.join(root, path)
      original = File.read!(full_path)
      File.write!(full_path, original <> "\n")
      assert {:error, :content_ineligible} = PasswordResetMessage.binding("en")
      File.write!(full_path, original)
    end
  end

  test "rejects duplicate, stale, or altered current authority routes", %{root: root} do
    path = Path.join(root, "docs/governance/CURRENT_GOVERNANCE_ROUTER.json")
    original = File.read!(path)
    router = Jason.decode!(original)

    product =
      Enum.find(router["governing_documents"], &(&1["document_id"] == "PLATFORM_PRODUCT_LAW"))

    variants = [
      router["governing_documents"] ++ [product],
      Enum.map(router["governing_documents"], fn item ->
        if item["document_id"] == "PLATFORM_PRODUCT_LAW",
          do: Map.put(item, "semver", "1.15.0"),
          else: item
      end),
      Enum.map(router["governing_documents"], fn item ->
        if item["document_id"] == "PRODUCT_DECISIONS",
          do: Map.put(item, "sha256", String.duplicate("0", 64)),
          else: item
      end)
    ]

    for documents <- variants do
      File.write!(path, Jason.encode!(%{router | "governing_documents" => documents}))
      assert {:error, :content_ineligible} = PasswordResetMessage.binding("af")
    end
  end

  test "rejects unsupported locales without fallback" do
    for locale <- ["en-GB", "af-ZA", "zu", ""] do
      assert {:error, :content_ineligible} = PasswordResetMessage.binding(locale)
    end
  end

  test "eligible requires the exact current binding" do
    assert {:ok, binding} = PasswordResetMessage.binding("en")

    for changed <- [
          %{binding | locale: "af"},
          %{binding | content_item_id: "another-item"},
          %{binding | content_version_id: "another-version"},
          %{binding | translation_version_id: "another-translation"},
          %{binding | content_sha256: String.duplicate("0", 64)}
        ] do
      assert {:error, :content_ineligible} = PasswordResetMessage.eligible(changed)
    end
  end

  test "fails closed when the approved packet is altered or withdrawn", %{root: root} do
    path =
      Path.join(
        root,
        "docs/delivery/content-evidence/content_media/password_reset_messages/PASSWORD_RESET_MESSAGE_EVIDENCE_PACKET_v0.2.0.json"
      )

    packet = path |> File.read!() |> Jason.decode!()
    File.write!(path, Jason.encode!(put_in(packet, ["lifecycle", "state"], "withdrawn")))

    assert {:error, :content_ineligible} = PasswordResetMessage.binding("en")
  end

  test "rejects conflicting approval history", %{root: root} do
    path =
      Path.join(
        root,
        "docs/delivery/content-evidence/content_media/password_reset_messages/PASSWORD_RESET_MESSAGE_EVIDENCE_PACKET_v0.2.0.json"
      )

    packet = path |> File.read!() |> Jason.decode!()
    [first | _] = packet["approval_events"]

    File.write!(
      path,
      Jason.encode!(
        put_in(
          packet,
          ["approval_events"],
          packet["approval_events"] ++ [%{first | "decision" => "reject"}]
        )
      )
    )

    assert {:error, :content_ineligible} = PasswordResetMessage.binding("af")
  end

  test "rechecks the current Product route before use", %{root: root} do
    path = Path.join(root, "docs/governance/CURRENT_GOVERNANCE_ROUTER.json")
    router = path |> File.read!() |> Jason.decode!()

    documents =
      Enum.map(router["governing_documents"], fn
        %{"document_id" => "PLATFORM_PRODUCT_LAW"} = document ->
          Map.put(document, "repository_path", "docs/governance/product/00_PLATFORM_v1.14.0.md")

        document ->
          document
      end)

    File.write!(path, Jason.encode!(%{router | "governing_documents" => documents}))

    assert {:error, :content_ineligible} = PasswordResetMessage.binding("en")
  end

  test "rechecks exact approval history before eligible bytes are returned", %{root: root} do
    assert {:ok, binding} = PasswordResetMessage.binding("en")

    path =
      Path.join(
        root,
        "docs/delivery/content-evidence/content_media/password_reset_messages/OWNER_APPROVALS_v1.json"
      )

    File.write!(path, File.read!(path) <> "\n")

    assert {:error, :content_ineligible} = PasswordResetMessage.eligible(binding)
  end

  test "rejects symlinked evidence files", %{root: root} do
    path =
      Path.join(
        root,
        "docs/delivery/content-evidence/content_media/password_reset_messages/NEWYOU-PASSWORD-RESET-MESSAGE-EMAIL-EN-V1.txt"
      )

    bytes = File.read!(path)
    File.rm!(path)
    target = Path.join(root, "outside.txt")
    File.write!(target, bytes)
    File.ln_s!(target, path)

    assert {:error, :content_ineligible} = PasswordResetMessage.binding("en")
  end
end
