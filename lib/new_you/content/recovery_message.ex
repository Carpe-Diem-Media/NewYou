defmodule NewYou.Content.RecoveryMessage do
  @moduledoc """
  Exact WELL-110 recovery content for bounded development proof.

  Every binding and queued use rechecks the pinned approval packet, paired locale
  bytes and current Product/Decision routes. This grants content eligibility only.
  It grants no operational mailbox, sender, provider or production authority.
  """
  @enabled Mix.env() in [:dev, :test] and
             Application.compile_env(:new_you, :verification_development_fixtures, false)

  @directory "docs/delivery/content-evidence/content_media/recovery_messages"
  @packet "#{@directory}/RECOVERY_MESSAGE_DEVELOPMENT_EVIDENCE_PACKET_v0.2.0.json"
  @packet_sha "83a44a10763181f46bbab2d6de99cf67854a18623a174746095628ae55bbeea7"
  @root Path.expand("../../..", __DIR__)
  @roles [:account_recovery, :recovery_security_notice]
  @authority %{
    "PLATFORM_PRODUCT_LAW" =>
      {"docs/governance/product/00_PLATFORM_v1.17.0.md",
       "ad38c25c49ba9d1de40e90d74b494705156605af724bc0e1d5a66d38b81cc39f"},
    "PRODUCT_DECISIONS" =>
      {"docs/governance/product/01_DECISIONS_v1.17.0.md",
       "1d2c3cf6ec3ea4cd318ceccda8fa0a9b2c9797eec8f934a399e8d59f93090d8b"}
  }
  @predecessor_authority %{
    "PLATFORM_PRODUCT_LAW" =>
      {"docs/governance/product/00_PLATFORM_v1.16.0.md",
       "bcc26cec59b8157a4d284d6bb533ec16bf41e85b88d7c5c14ff1ec1141019174"},
    "PRODUCT_DECISIONS" =>
      {"docs/governance/product/01_DECISIONS_v1.16.0.md",
       "1a5d6d7c2bb0ca2a595dd28e2e371340298aa0b62ff613939c5de141831eb7f8"}
  }

  @doc "Resolve one exact role and locale, without fallback or latest-version lookup."
  @spec binding(atom(), term()) :: {:ok, map()} | {:error, :content_ineligible}
  def binding(role, locale) when role in @roles and locale in ["en", "af"] do
    with {:ok, packet, versions} <- evidence(),
         {:ok, message} <- message(packet, role),
         {:ok, {version, _bytes}} <- Map.fetch(versions, {role, locale}) do
      {:ok, fields(message, version)}
    else
      _ -> ineligible()
    end
  rescue
    _ -> ineligible()
  end

  def binding(_, _), do: ineligible()

  @doc "Revalidate the entire current approval and return only the exact bound bytes."
  @spec eligible(map()) :: {:ok, binary()} | {:error, :content_ineligible}
  def eligible(binding) when is_map(binding) do
    with {:ok, packet, versions} <- evidence(),
         {:ok, message} <- message(packet, Map.get(binding, :role)),
         {:ok, {version, bytes}} <-
           Map.fetch(versions, {Map.get(binding, :role), Map.get(binding, :locale)}),
         expected = fields(message, version),
         true <- Map.take(binding, Map.keys(expected)) == expected do
      {:ok, bytes}
    else
      _ -> ineligible()
    end
  rescue
    _ -> ineligible()
  end

  def eligible(_), do: ineligible()

  @doc "Return the approved non-secret development value, without claiming operability."
  @spec support_contact() :: {:ok, String.t()} | {:error, :content_ineligible}
  def support_contact do
    with {:ok, packet, _} <- evidence(), do: {:ok, packet["support_contact"]["value"]}
  end

  defp fields(message, version) do
    %{
      locale: version["locale"],
      content_item_id: message["content_item_id"],
      content_version_id: message["content_version_id"],
      translation_version_id: version["content_translation_version_id"],
      content_sha256: version["artifact"]["sha256"]
    }
  end

  defp message(packet, role) when role in @roles do
    case Enum.filter(packet["messages"], &(&1["communications_role"] == Atom.to_string(role))) do
      [message] -> {:ok, message}
      _ -> ineligible()
    end
  end

  defp message(_, _), do: ineligible()

  defp evidence do
    with true <- @enabled,
         root when is_binary(root) <- evidence_root(),
         {:ok, bytes} <- read_file(root, @packet),
         true <- digest(bytes) == @packet_sha,
         {:ok, packet} <- Jason.decode(bytes),
         {:ok, delivery} <- read_json(root, "docs/delivery/CURRENT_DELIVERY_ROUTER.json"),
         true <- routed_packet?(delivery),
         {:ok, governance} <- read_json(root, "docs/governance/CURRENT_GOVERNANCE_ROUTER.json"),
         true <- current_authority?(root, governance),
         true <- dependencies_match?(root, packet),
         {:ok, versions} <- versions(root, packet) do
      {:ok, packet, versions}
    else
      _ -> ineligible()
    end
  rescue
    _ -> ineligible()
  end

  defp routed_packet?(router) do
    Enum.filter(
      router["delivery_contracts"],
      &(&1["document_id"] == "RECOVERY_MESSAGE_DEVELOPMENT_EVIDENCE")
    ) == [
      %{
        "document_id" => "RECOVERY_MESSAGE_DEVELOPMENT_EVIDENCE",
        "canonical_filename" => Path.basename(@packet),
        "repository_path" => @packet,
        "sha256" => @packet_sha,
        "contract_type" => "content_evidence",
        "status" => "DEVELOPMENT_ONLY_APPROVED; RUNTIME_RELEASE_PROHIBITED"
      }
    ]
  end

  defp current_authority?(root, router) do
    Enum.all?(@authority, fn {id, {path, sha}} ->
      case Enum.filter(router["governing_documents"], &(&1["document_id"] == id)) do
        [entry] ->
          entry["repository_path"] == path and entry["canonical_filename"] == Path.basename(path) and
            entry["semver"] == "1.17.0" and entry["sha256"] == sha and
            file_matches?(root, path, sha) and successor_lineage?(root, id, path)

        _ ->
          false
      end
    end)
  end

  defp successor_lineage?(root, id, current_path) do
    {predecessor_path, predecessor_sha} = Map.fetch!(@predecessor_authority, id)

    with {:ok, current_bytes} <- read_file(root, current_path),
         {:ok, predecessor_bytes} <- read_file(root, predecessor_path),
         true <- digest(predecessor_bytes) == predecessor_sha,
         true <- String.contains?(current_bytes, "**Predecessor:** `#{predecessor_path}`"),
         true <- String.contains?(current_bytes, "**SemVer transition:** `v1.16.0 → v1.17.0`"),
         true <- predecessor_of_v1_16?(predecessor_bytes, id) do
      true
    else
      _ -> false
    end
  end

  defp predecessor_of_v1_16?(bytes, "PLATFORM_PRODUCT_LAW") do
    String.contains?(
      bytes,
      "**Predecessor:** `docs/governance/product/00_PLATFORM_v1.15.0.md`"
    ) and String.contains?(bytes, "**SemVer transition:** `v1.15.0 → v1.16.0`")
  end

  defp predecessor_of_v1_16?(bytes, "PRODUCT_DECISIONS") do
    String.contains?(
      bytes,
      "**Predecessor:** `docs/governance/product/01_DECISIONS_v1.15.0.md`"
    ) and String.contains?(bytes, "**SemVer transition:** `v1.15.0 → v1.16.0`")
  end

  # The packet digest binds all nine individual approvals, exact typed token
  # contracts, historical authority, candidate predecessor and proposal bytes.
  # Any successor or withdrawal requires an explicitly reviewed reader update.
  defp dependencies_match?(root, packet) do
    dependencies =
      [packet["candidate_predecessor"], packet["approval_source"], packet["product_proposal"]] ++
        packet["authority_refs"]

    Enum.all?(dependencies, &file_matches?(root, &1["path"], &1["sha256"]))
  end

  defp versions(root, packet) do
    @roles
    |> Enum.flat_map(fn role ->
      {:ok, message} = message(packet, role)
      Enum.map(message["locale_versions"], &{role, &1})
    end)
    |> Enum.reduce_while({:ok, %{}}, fn {role, version}, {:ok, loaded} ->
      artifact = version["artifact"]

      with {:ok, bytes} <- read_file(root, artifact["path"]),
           true <- byte_size(bytes) == artifact["bytes"] and digest(bytes) == artifact["sha256"] do
        {:cont, {:ok, Map.put(loaded, {role, version["locale"]}, {version, bytes})}}
      else
        _ -> {:halt, ineligible()}
      end
    end)
  end

  defp evidence_root do
    if Mix.env() == :test, do: Process.get({__MODULE__, :evidence_root}, @root), else: @root
  end

  defp file_matches?(root, path, sha) do
    case read_file(root, path) do
      {:ok, bytes} -> digest(bytes) == sha
      _ -> false
    end
  end

  defp read_json(root, path) do
    with {:ok, bytes} <- read_file(root, path), do: Jason.decode(bytes)
  end

  # sobelow_skip ["Traversal.FileModule"]
  # Callers use fixed paths or paths from the exact digest-verified packet.
  # Reject absolute paths, traversal and every symlink segment, including root.
  defp read_file(root, path) do
    with true <- Path.type(path) == :relative,
         false <- Enum.any?(Path.split(path), &(&1 in ["..", "."])),
         {:ok, %{type: :directory}} <- File.lstat(root),
         true <- regular_segments?(root, Path.split(path)) do
      File.read(Path.join(root, path))
    else
      _ -> ineligible()
    end
  end

  defp regular_segments?(root, [file]),
    do: match?({:ok, %{type: :regular}}, File.lstat(Path.join(root, file)))

  defp regular_segments?(root, [directory | rest]) do
    next = Path.join(root, directory)
    match?({:ok, %{type: :directory}}, File.lstat(next)) and regular_segments?(next, rest)
  end

  defp digest(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
  defp ineligible, do: {:error, :content_ineligible}
end
