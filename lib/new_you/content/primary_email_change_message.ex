defmodule NewYou.Content.PrimaryEmailChangeMessage do
  @moduledoc false

  @enabled Mix.env() in [:dev, :test] and
             Application.compile_env(:new_you, :verification_development_fixtures, false)
  @packet_path "docs/delivery/content-evidence/content_media/email_change_messages/CANDIDATE_EVIDENCE_v1.json"
  @packet_sha "3db7668d20090ec5b53c7ba2213865ab64818e52f87d4da99b2e986ed19355df"
  @root Path.expand("../../..", __DIR__)
  @router_path "docs/delivery/CURRENT_DELIVERY_ROUTER.json"
  @governance_router "docs/governance/CURRENT_GOVERNANCE_ROUTER.json"
  @phase9_path "docs/delivery/content-evidence/content_media/email_change_messages/WELL157_PHASE9_APPLICABILITY_EVIDENCE_v0.1.0.json"
  @phase9_sha "ca5a78f8a6f9073882daaa5a871aa873d72ce17c7953d72866052e16b47465aa"
  @phase9_document "WELL157_PRIMARY_EMAIL_CHANGE_PHASE9_APPLICABILITY_EVIDENCE"

  @doc "Bind one exact approved primary-email-change message version for development evidence."
  @spec binding(atom(), String.t()) :: {:ok, map()} | {:error, :content_ineligible}
  def binding(role, locale), do: binding(role, locale, :p8_16)

  @doc "Bind an exact message in a trusted development context. Delivery remains disabled."
  @spec binding(atom(), String.t(), :p8_16 | :well156) ::
          {:ok, map()} | {:error, :content_ineligible}
  def binding(role, locale, context)
      when role in [:email_change_confirmation, :email_change_old_address_notice] and
             locale in ["en", "af"] do
    with true <- @enabled,
         {:ok, packet_bytes} <- read(@packet_path),
         true <- digest(packet_bytes) == @packet_sha,
         {:ok, packet} <- Jason.decode(packet_bytes),
         true <- development_only?(packet),
         {:ok, router_bytes} <- read(@router_path),
         {:ok, router} <- Jason.decode(router_bytes),
         true <- routed?(router),
         {:ok, message} <- message(packet, role, locale),
         {:ok, message_bytes} <- read(message["path"]),
         true <- byte_size(message_bytes) == message["bytes"],
         true <- digest(message_bytes) == message["sha256"],
         true <- applicable?(context, router, message) do
      {:ok,
       %{
         locale: locale,
         content_item_id: message["content_item_id"],
         content_version_id: message["content_version_id"],
         translation_version_id: message["translation_version_id"],
         content_sha256: message["sha256"]
       }}
    else
      _ -> {:error, :content_ineligible}
    end
  rescue
    _ -> {:error, :content_ineligible}
  end

  def binding(_, _, _), do: {:error, :content_ineligible}

  defp applicable?(:p8_16, _router, _message), do: true

  defp applicable?(:well156, router, message) do
    with [
           %{
             "repository_path" => @phase9_path,
             "sha256" => @phase9_sha,
             "status" => "BOUNDED_WELL156_NONPRODUCTION_PHASE9; DELIVERY_DISABLED"
           }
         ] <-
           entries(router["delivery_contracts"], @phase9_document),
         {:ok, bytes} <- checked_read(@phase9_path, @phase9_sha),
         {:ok, %{"messages" => messages, "current_governing_authority" => authority}} <-
           Jason.decode(bytes),
         true <- Enum.member?(messages, message),
         {:ok, governance} <- read(@governance_router),
         {:ok, %{"governing_documents" => current}} <- Jason.decode(governance) do
      Enum.all?(authority, &current_authority?(&1, current))
    else
      _ -> false
    end
  end

  defp applicable?(_, _, _), do: false

  defp current_authority?(%{"document_id" => id, "path" => path, "sha256" => sha}, current) do
    match?([%{"repository_path" => ^path, "sha256" => ^sha}], entries(current, id)) and
      match?({:ok, _}, checked_read(path, sha))
  end

  defp entries(documents, id), do: Enum.filter(documents, &(&1["document_id"] == id))

  defp checked_read(path, sha) do
    with {:ok, bytes} <- read(path),
         true <- digest(bytes) == sha do
      {:ok, bytes}
    else
      _ -> {:error, :content_ineligible}
    end
  end

  defp development_only?(packet) do
    packet_fields = [
      {"status", "DEVELOPMENT_ONLY_APPROVED"},
      {"delivery_authorized", false},
      {"runtime_release", false},
      {"runtime_release_eligible", false},
      {"support_contact_bound", false}
    ]

    eligibility_fields = [
      {"development", true},
      {"automated_tests", true},
      {"development_environments", true},
      {"bounded_p8_16_proof", true},
      {"real_participant_delivery", false},
      {"production", false}
    ]

    fields_match?(packet, packet_fields) and
      fields_match?(packet["eligibility"], eligibility_fields)
  end

  defp fields_match?(values, expected_fields) when is_map(values) do
    Enum.all?(expected_fields, fn {field, expected} -> values[field] == expected end)
  end

  defp fields_match?(_, _), do: false

  defp routed?(router) do
    Enum.filter(router["delivery_contracts"], fn entry ->
      entry["document_id"] == "PRIMARY_EMAIL_CHANGE_MESSAGE_DEVELOPMENT_EVIDENCE"
    end) ==
      [
        %{
          "document_id" => "PRIMARY_EMAIL_CHANGE_MESSAGE_DEVELOPMENT_EVIDENCE",
          "canonical_filename" => Path.basename(@packet_path),
          "repository_path" => @packet_path,
          "sha256" => @packet_sha,
          "contract_type" => "content_evidence",
          "status" => "DEVELOPMENT_ONLY_APPROVED; DELIVERY_DISABLED"
        }
      ]
  end

  defp message(packet, role, locale) do
    case Enum.filter(packet["messages"], fn entry ->
           entry["communications_role"] == Atom.to_string(role) and
             entry["locale"] == locale and entry["state"] == "development_approved"
         end) do
      [message] -> {:ok, message}
      _ -> {:error, :content_ineligible}
    end
  end

  # The paths are fixed above or come from the digest-pinned packet.
  # sobelow_skip ["Traversal.FileModule"]
  defp read(path) do
    with true <- Path.type(path) == :relative,
         false <- Enum.any?(Path.split(path), &(&1 in ["..", "."])),
         {:ok, %{type: :regular}} <- File.lstat(Path.join(evidence_root(), path)) do
      File.read(Path.join(evidence_root(), path))
    else
      _ -> {:error, :content_ineligible}
    end
  end

  if Mix.env() == :test do
    defp evidence_root, do: Process.get({__MODULE__, :evidence_root}, @root)
  else
    defp evidence_root, do: @root
  end

  defp digest(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
end
