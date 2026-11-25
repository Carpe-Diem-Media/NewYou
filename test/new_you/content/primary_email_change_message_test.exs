defmodule NewYou.Content.PrimaryEmailChangeMessageTest do
  use ExUnit.Case, async: true

  alias NewYou.Content.PrimaryEmailChangeMessage

  test "WELL-156 binds both exact locale versions for each approved purpose" do
    for role <- [:email_change_confirmation, :email_change_old_address_notice],
        locale <- ["en", "af"] do
      assert {:ok, original} = PrimaryEmailChangeMessage.binding(role, locale)
      assert {:ok, ^original} = PrimaryEmailChangeMessage.binding(role, locale, :well156)
    end
  end

  test "WELL-156 rejects unsupported locales, purposes and contexts" do
    for {role, locale, context} <- [
          {:email_change_confirmation, "fr", :well156},
          {:password_reset, "en", :well156},
          {:email_change_confirmation, "en", :release}
        ] do
      assert {:error, :content_ineligible} =
               PrimaryEmailChangeMessage.binding(role, locale, context)
    end
  end

  @tag :tmp_dir
  test "changed applicability denies every new Phase-9 use", %{tmp_dir: root} do
    approved = "docs/delivery/content-evidence/content_media/email_change_messages"

    for path <- [
          "docs/delivery/CURRENT_DELIVERY_ROUTER.json",
          "docs/governance/CURRENT_GOVERNANCE_ROUTER.json",
          "docs/governance/product/00_PLATFORM_v1.21.0.md",
          "docs/governance/product/01_DECISIONS_v1.21.0.md",
          "docs/governance/product/00_PLATFORM_v1.20.0.md",
          "docs/governance/product/01_DECISIONS_v1.20.0.md",
          "docs/governance/product/00_PLATFORM_v1.19.0.md",
          "docs/governance/product/01_DECISIONS_v1.19.0.md"
        ] do
      destination = Path.join(root, path)
      File.mkdir_p!(Path.dirname(destination))
      File.cp!(path, destination)
    end

    destination = Path.join(root, approved)
    File.mkdir_p!(Path.dirname(destination))
    File.cp_r!(approved, destination)
    Process.put({PrimaryEmailChangeMessage, :evidence_root}, root)
    packet = Path.join(destination, "WELL157_PHASE9_APPLICABILITY_EVIDENCE_v0.1.0.json")

    assert {:ok, _} =
             PrimaryEmailChangeMessage.binding(:email_change_confirmation, "af", :well156)

    law = Path.join(root, "docs/governance/product/00_PLATFORM_v1.21.0.md")
    bytes = File.read!(law)
    File.write!(law, bytes <> "\n")

    assert {:error, :content_ineligible} =
             PrimaryEmailChangeMessage.binding(:email_change_confirmation, "af", :well156)

    File.write!(law, bytes)

    assert {:ok, _} =
             PrimaryEmailChangeMessage.binding(:email_change_confirmation, "af", :well156)

    withdrawn =
      packet |> File.read!() |> Jason.decode!() |> put_in(["lifecycle", "state"], "withdrawn")

    File.write!(packet, Jason.encode!(withdrawn))

    assert {:error, :content_ineligible} =
             PrimaryEmailChangeMessage.binding(:email_change_confirmation, "af", :well156)

    assert {:error, :content_ineligible} =
             PrimaryEmailChangeMessage.binding(:email_change_old_address_notice, "en", :well156)

    assert {:ok, _} = PrimaryEmailChangeMessage.binding(:email_change_confirmation, "af")
  end
end
