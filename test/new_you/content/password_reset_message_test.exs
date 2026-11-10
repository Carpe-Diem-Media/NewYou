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
