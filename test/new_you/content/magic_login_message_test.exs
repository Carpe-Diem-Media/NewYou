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
