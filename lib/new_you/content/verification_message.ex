defmodule NewYou.Content.VerificationMessage do
  @moduledoc """
  Content & Media's bounded development verification-message read contract.
  Exact approved development bytes and locale identities are checked together.
  This provides no publication, production or real-participant eligibility.
  Withdrawal or changed bytes fail closed; no latest-version or locale fallback.
  """
  @enabled Application.compile_env(:new_you, :verification_development_fixtures, false)
  @root "docs/delivery/content-evidence/content_media/verification_messages/"
  @external_resource @root <> "VERIFICATION_MESSAGE_EVIDENCE_PACKET_v0.2.0.json"
  @packet @external_resource |> File.read!() |> Jason.decode!()
  @versions (for version <- @packet["locale_versions"], into: %{} do
               path = version["artifact_path"]
               @external_resource path
               {version["locale"], {version, File.read!(path)}}
             end)

  @spec eligible(map()) :: {:ok, String.t()} | {:error, :content_ineligible}
  def eligible(binding) do
    with true <- @enabled,
         {%{} = version, bytes} <- Map.get(@versions, binding.locale),
         true <- binding.content_item_id == @packet["content_item"]["id"],
         true <- binding.content_version_id == @packet["content_version"]["id"],
         true <- binding.translation_version_id == version["id"],
         true <- binding.content_sha256 == version["sha256"],
         true <- digest(bytes) == binding.content_sha256,
         true <- version["development_fixture_status"] == "development_approved",
         true <- version["withdrawal"]["status"] == "NOT_RECORDED" do
      {:ok, bytes}
    else
      _ -> {:error, :content_ineligible}
    end
  end

  defp digest(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end
