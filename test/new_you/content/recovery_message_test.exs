defmodule NewYou.Content.RecoveryMessageTest do
  use ExUnit.Case, async: false

  alias NewYou.Content.RecoveryMessage
  @root Path.expand("../../..", __DIR__)
  @directory "docs/delivery/content-evidence/content_media/recovery_messages"

  setup do
    root = Path.join(System.tmp_dir!(), "recovery-content-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    File.cp_r!(Path.join(@root, "docs"), Path.join(root, "docs"))
    Process.put({RecoveryMessage, :evidence_root}, root)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, root: root}
  end

  test "both roles bind all exact approved EN and AF immutable versions" do
    for {role, stem} <- [
          {:account_recovery, "PROOF-MESSAGE"},
          {:recovery_security_notice, "COMPLETION-NOTICE"}
        ],
        locale <- ["en", "af"] do
      assert {:ok, binding} = RecoveryMessage.binding(role, locale)

      expected =
        File.read!(
          Path.join(
            @root,
            "#{@directory}/NEWYOU-ACCOUNT-RECOVERY-#{stem}-EMAIL-#{String.upcase(locale)}-V1.txt"
          )
        )

      assert binding.translation_version_id ==
               "NEWYOU-CONTENTTRANSLATIONVERSION-ACCOUNT-RECOVERY-#{stem}-EMAIL-#{String.upcase(locale)}-V1"

      assert binding.content_sha256 ==
               Base.encode16(:crypto.hash(:sha256, expected), case: :lower)

      assert {:ok, ^expected} = RecoveryMessage.eligible(Map.put(binding, :role, role))
    end

    assert {:ok, "jc@carpediem.co.za"} = RecoveryMessage.support_contact()
  end

  test "unknown locales, roles and altered exact bindings fail without fallback" do
    for locale <- ["af-ZA", "en-GB", "zu", nil],
        do:
          assert(
            {:error, :content_ineligible} = RecoveryMessage.binding(:account_recovery, locale)
          )

    assert {:error, :content_ineligible} = RecoveryMessage.binding(:password_reset, "en")
    assert {:ok, binding} = RecoveryMessage.binding(:account_recovery, "en")

    for changed <- [
          %{role: :recovery_security_notice},
          %{locale: "af"},
          %{translation_version_id: "latest"},
          %{content_sha256: String.duplicate("0", 64)}
        ] do
      assert {:error, :content_ineligible} =
               RecoveryMessage.eligible(
                 Map.merge(Map.put(binding, :role, :account_recovery), changed)
               )
    end
  end

  test "withdrawal, conflicting approval, missing paired locale and changed authority stop queued use",
       %{root: root} do
    assert {:ok, binding} = RecoveryMessage.binding(:account_recovery, "en")

    for path <- [
          "#{@directory}/RECOVERY_MESSAGE_DEVELOPMENT_EVIDENCE_PACKET_v0.2.0.json",
          "#{@directory}/OWNER_APPROVALS_v1.json",
          "#{@directory}/NEWYOU-ACCOUNT-RECOVERY-PROOF-MESSAGE-EMAIL-AF-V1.txt",
          "docs/governance/product/00_PLATFORM_v1.16.0.md"
        ] do
      full = Path.join(root, path)
      bytes = File.read!(full)
      File.write!(full, bytes <> "\n")
      assert {:error, :content_ineligible} = RecoveryMessage.binding(:account_recovery, "en")

      assert {:error, :content_ineligible} =
               RecoveryMessage.eligible(Map.put(binding, :role, :account_recovery))

      File.write!(full, bytes)
    end

    full =
      Path.join(root, "#{@directory}/RECOVERY_MESSAGE_DEVELOPMENT_EVIDENCE_PACKET_v0.2.0.json")

    packet = full |> File.read!() |> Jason.decode!()
    File.write!(full, Jason.encode!(put_in(packet, ["lifecycle", "state"], "withdrawn")))
    assert {:error, :content_ineligible} = RecoveryMessage.binding(:account_recovery, "en")
  end

  test "duplicate routes and symlink evidence fail closed", %{root: root} do
    path = Path.join(root, "docs/delivery/CURRENT_DELIVERY_ROUTER.json")
    bytes = File.read!(path)
    router = Jason.decode!(bytes)

    entry =
      Enum.find(
        router["delivery_contracts"],
        &(&1["document_id"] == "RECOVERY_MESSAGE_DEVELOPMENT_EVIDENCE")
      )

    File.write!(
      path,
      Jason.encode!(%{router | "delivery_contracts" => router["delivery_contracts"] ++ [entry]})
    )

    assert {:error, :content_ineligible} = RecoveryMessage.binding(:account_recovery, "en")
    File.write!(path, bytes)

    artifact =
      Path.join(root, "#{@directory}/NEWYOU-ACCOUNT-RECOVERY-PROOF-MESSAGE-EMAIL-EN-V1.txt")

    File.rm!(artifact)

    File.ln_s!(
      Path.join(@root, "#{@directory}/NEWYOU-ACCOUNT-RECOVERY-PROOF-MESSAGE-EMAIL-EN-V1.txt"),
      artifact
    )

    assert {:error, :content_ineligible} = RecoveryMessage.binding(:account_recovery, "en")
  end
end
