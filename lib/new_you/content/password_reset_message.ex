defmodule NewYou.Content.PasswordResetMessage do
  @moduledoc """
  Reads exact owner-approved password-reset message bytes for bounded development use.

  Each call rechecks the current delivery route, approval history, Product authority,
  and locale artifacts. The contract grants no runtime or production eligibility.
  """

  @enabled Mix.env() in [:dev, :test] and
             Application.compile_env(:new_you, :verification_development_fixtures, false)

  if @enabled do
    @packet_path "docs/delivery/content-evidence/content_media/password_reset_messages/PASSWORD_RESET_MESSAGE_EVIDENCE_PACKET_v0.2.0.json"
    @candidate_path "docs/delivery/content-evidence/content_media/password_reset_messages/PASSWORD_RESET_MESSAGE_EVIDENCE_PACKET_v0.1.0.json"
    @approvals_path "docs/delivery/content-evidence/content_media/password_reset_messages/OWNER_APPROVALS_v1.json"
    @delivery_router_path "docs/delivery/CURRENT_DELIVERY_ROUTER.json"
    @governance_router_path "docs/governance/CURRENT_GOVERNANCE_ROUTER.json"
    @packet_sha "93330874efbfed68587107a5d33bbce7d3f07461fb90842c72bc1e1dc95c35ec"
    @candidate_sha "7d9df40d8b8ed8ca2c1bf204682a70d88425f4619a7663ac89db401036c01132"
    @approvals_sha "80b95f1f25df5bd67b08792a665965b6ab34cf265f400b389cb90e77df203b4b"
    @repo_root Path.expand("../../..", __DIR__)
    @item_id "NEWYOU-CONTENTITEM-PASSWORD-RESET-MESSAGE-EMAIL"
    @content_version_id "NEWYOU-CONTENTVERSION-PASSWORD-RESET-MESSAGE-EMAIL-V1"
    @translations %{
      "en" => {
        "NEWYOU-CONTENTTRANSLATIONVERSION-PASSWORD-RESET-MESSAGE-EMAIL-EN-V1",
        "docs/delivery/content-evidence/content_media/password_reset_messages/NEWYOU-PASSWORD-RESET-MESSAGE-EMAIL-EN-V1.txt",
        369,
        "71c213c2ae48edf499d7d6d4191d84076a366d6fbd59607c8b842c830d33928c"
      },
      "af" => {
        "NEWYOU-CONTENTTRANSLATIONVERSION-PASSWORD-RESET-MESSAGE-EMAIL-AF-V2",
        "docs/delivery/content-evidence/content_media/password_reset_messages/NEWYOU-PASSWORD-RESET-MESSAGE-EMAIL-AF-V2.txt",
        401,
        "ec1251d149b54692df2751760b72d1766d99537d4fa22b9b06da828bafe9ec93"
      }
    }
    @product_authority [
      %{
        "document_id" => "PLATFORM_PRODUCT_LAW",
        "path" => "docs/governance/product/00_PLATFORM_v1.15.0.md",
        "sha256" => "c7f5510817028d28edd4eb29e71b9150e13d0354cccf1af23666e067e0eed0b8",
        "predecessor" => "docs/governance/product/00_PLATFORM_v1.14.0.md",
        "predecessor_sha256" =>
          "bcec310103319441d12c6efae1c7c779a013a503b3831da630abb4a55187314b",
        "proposal" => "docs/governance/product/proposals/well-98/00_PLATFORM_v1.15.0_PROPOSED.md",
        "proposal_sha256" => "a9ae584bccc984faca20aeed2428edc00a05ad54aead237a57a6d90388eedebb"
      },
      %{
        "document_id" => "PRODUCT_DECISIONS",
        "path" => "docs/governance/product/01_DECISIONS_v1.15.0.md",
        "sha256" => "db57b0b73ed9faf8f3ade458c01d0d4798e4c2401172a35b9a1ad129ce8ae8d4",
        "predecessor" => "docs/governance/product/01_DECISIONS_v1.14.0.md",
        "predecessor_sha256" =>
          "d97cb742deefa744279b47686bf5148cceea4b95839fe5b32ad6bbe7d2b6b1fd",
        "proposal" =>
          "docs/governance/product/proposals/well-98/01_DECISIONS_v1.15.0_PROPOSED.md",
        "proposal_sha256" => "b4374a82d605320fba01733176cc8a57346a97da1a0d03095d79b818926f2017"
      }
    ]

    @current_authority %{
      "PLATFORM_PRODUCT_LAW" =>
        {"docs/governance/product/00_PLATFORM_v1.17.0.md",
         "ad38c25c49ba9d1de40e90d74b494705156605af724bc0e1d5a66d38b81cc39f"},
      "PRODUCT_DECISIONS" =>
        {"docs/governance/product/01_DECISIONS_v1.17.0.md",
         "1d2c3cf6ec3ea4cd318ceccda8fa0a9b2c9797eec8f934a399e8d59f93090d8b"}
    }
    @recovery_proposal "docs/delivery/content-evidence/content_media/recovery_messages/PRODUCT_CLASSIFICATION_PROPOSALS_v0.1.0.md"
    @recovery_proposal_sha "04f41fe344428a9c7cb30398c599c341d6a416af79c51d8446215ef9075e1b64"
    @email_change_proposal "docs/delivery/content-evidence/content_media/email_change_messages/PRODUCT_CLASSIFICATION_PROPOSAL_v1.md"
    @email_change_proposal_sha "5859094922ada891cdca887cf140d457991fa0fe5fcc76ea34ff4dd32ad8a8b1"
    @v1_16_authority %{
      "PLATFORM_PRODUCT_LAW" => {
        "docs/governance/product/00_PLATFORM_v1.16.0.md",
        "bcc26cec59b8157a4d284d6bb533ec16bf41e85b88d7c5c14ff1ec1141019174"
      },
      "PRODUCT_DECISIONS" => {
        "docs/governance/product/01_DECISIONS_v1.16.0.md",
        "1a5d6d7c2bb0ca2a595dd28e2e371340298aa0b62ff613939c5de141831eb7f8"
      }
    }

    @spec binding(String.t()) :: {:ok, map()} | {:error, :content_ineligible}
    def binding(locale) when is_binary(locale) do
      with {:ok, root} <- evidence_root(),
           {:ok, packet, versions} <- current_evidence(root),
           {:ok, {version, _bytes}} <- Map.fetch(versions, locale) do
        {:ok,
         %{
           locale: locale,
           content_item_id: packet["content_item_id"],
           content_version_id: packet["content_version_id"],
           translation_version_id: version["id"],
           content_sha256: version["artifact"]["sha256"]
         }}
      else
        _ -> {:error, :content_ineligible}
      end
    rescue
      _ -> {:error, :content_ineligible}
    end

    def binding(_locale), do: {:error, :content_ineligible}

    @spec eligible(map()) :: {:ok, binary()} | {:error, :content_ineligible}
    def eligible(binding) when is_map(binding) do
      with {:ok, root} <- evidence_root(),
           {:ok, packet, versions} <- current_evidence(root),
           locale when is_binary(locale) <- Map.get(binding, :locale),
           {:ok, {version, bytes}} <- Map.fetch(versions, locale),
           true <- Map.get(binding, :content_item_id) == packet["content_item_id"],
           true <- Map.get(binding, :content_version_id) == packet["content_version_id"],
           true <- Map.get(binding, :translation_version_id) == version["id"],
           true <- Map.get(binding, :content_sha256) == version["artifact"]["sha256"] do
        {:ok, bytes}
      else
        _ -> {:error, :content_ineligible}
      end
    rescue
      _ -> {:error, :content_ineligible}
    end

    def eligible(_binding), do: {:error, :content_ineligible}

    defp current_evidence(root) do
      with {:ok, delivery_router} <- read_json(root, @delivery_router_path),
           {:ok, packet_bytes} <- read_file(root, @packet_path),
           true <- digest(packet_bytes) == @packet_sha,
           {:ok, packet} <- Jason.decode(packet_bytes),
           true <- current_delivery_route?(delivery_router),
           true <- approved_packet?(packet),
           {:ok, candidate_bytes} <- read_file(root, @candidate_path),
           true <- digest(candidate_bytes) == @candidate_sha,
           true <-
             packet["predecessor_packet"] == %{
               "path" => @candidate_path,
               "sha256" => @candidate_sha
             },
           {:ok, approvals} <- read_file(root, @approvals_path),
           true <- digest(approvals) == @approvals_sha,
           true <- packet["approval_source"]["path"] == @approvals_path,
           true <- packet["approval_source"]["sha256"] == @approvals_sha,
           true <- product_authority_current?(root, packet),
           {:ok, versions} <- read_versions(root, packet) do
        {:ok, packet, versions}
      else
        _ -> {:error, :content_ineligible}
      end
    end

    defp current_delivery_route?(router) do
      contracts = Map.get(router, "delivery_contracts", [])

      current =
        Enum.filter(
          contracts,
          &(&1["document_id"] == "PASSWORD_RESET_MESSAGE_DEVELOPMENT_EVIDENCE")
        )

      candidate =
        Enum.filter(
          contracts,
          &(&1["document_id"] == "PASSWORD_RESET_MESSAGE_CANDIDATE_EVIDENCE")
        )

      current == [
        %{
          "document_id" => "PASSWORD_RESET_MESSAGE_DEVELOPMENT_EVIDENCE",
          "canonical_filename" => Path.basename(@packet_path),
          "repository_path" => @packet_path,
          "sha256" => @packet_sha,
          "contract_type" => "content_evidence",
          "status" => "DEVELOPMENT_ONLY_APPROVED; RUNTIME_RELEASE_PROHIBITED"
        }
      ] and
        candidate == [
          %{
            "document_id" => "PASSWORD_RESET_MESSAGE_CANDIDATE_EVIDENCE",
            "canonical_filename" => Path.basename(@candidate_path),
            "repository_path" => @candidate_path,
            "sha256" => @candidate_sha,
            "contract_type" => "content_evidence",
            "status" => "CANDIDATE_NOT_APPROVED"
          }
        ]
    end

    defp approved_packet?(packet),
      do:
        approved_identity?(packet) and approved_eligibility?(packet) and
          approved_security?(packet) and exact_approval_history?(packet)

    defp approved_identity?(packet) do
      packet["packet_id"] == "password-reset-message-email-development-evidence-v0.2.0" and
        packet["status"] == "DEVELOPMENT_ONLY_APPROVED; RUNTIME_RELEASE_PROHIBITED" and
        packet["owner"] == "Content & Media" and packet["content_item_id"] == @item_id and
        packet["content_version_id"] == @content_version_id
    end

    defp approved_eligibility?(packet) do
      packet["lifecycle"]["state"] == "development_approved" and
        packet["eligibility"] == %{
          "development" => true,
          "automated_tests" => true,
          "development_environments" => true,
          "bounded_p8_12_proof" => true,
          "runtime_release" => false,
          "production" => false,
          "public_release" => false,
          "paid_pilot" => false,
          "real_participant_delivery" => false,
          "phase_9" => false
        }
    end

    defp approved_security?(packet) do
      packet["authorization"]["development_implementation_permission"]["status"] ==
        "NOT_GRANTED_BY_WELL-98" and
        packet["authorization"]["runtime_release"] == "NOT_GRANTED" and
        packet["authorization"]["production"] == "PROHIBITED" and
        packet["security"]["runtime_changes"] == false and
        packet["security"]["authentication_input_rebinding"] == false and
        packet["security"]["protected_bearer_retention_extension"] == false
    end

    defp exact_approval_history?(packet) do
      events = packet["approval_events"]

      is_list(events) and length(events) == 5 and
        Enum.map(events, & &1["decision_id"]) == [
          "WELL-98-PRODUCT-APPROVAL-20261109",
          "WELL-98-CONTENT-EN-V1-APPROVAL-20261109",
          "WELL-98-CONTENT-AF-V2-APPROVAL-20261109",
          "WELL-98-LANG-EN-V1-APPROVAL-20261109",
          "WELL-98-LANG-AF-V2-APPROVAL-20261109"
        ] and Enum.all?(events, &(&1["decision"] == "approve")) and
        packet["lifecycle"]["revalidate_current_eligibility_before_new_use"] == true and
        packet["lifecycle"]["conflict"] == "STOP_AND_RECONCILE; never last-write-wins"
    end

    defp product_authority_current?(root, packet) do
      with {:ok, router} <- read_json(root, @governance_router_path),
           authority when is_list(authority) <- packet["promoted_authority"],
           true <- length(authority) == length(@product_authority),
           true <-
             Enum.zip(authority, @product_authority)
             |> Enum.all?(fn {actual, expected} ->
               authority_binding_matches?(actual, expected) and
                 authority_files_match?(root, expected) and
                 routed_authority?(root, router, expected)
             end) do
        true
      else
        _ -> false
      end
    end

    defp authority_binding_matches?(actual, expected) do
      Map.take(actual, [
        "document_id",
        "path",
        "sha256",
        "predecessor",
        "predecessor_sha256",
        "approved_amendment_path",
        "approved_amendment_sha256"
      ]) == %{
        "document_id" => expected["document_id"],
        "path" => expected["path"],
        "sha256" => expected["sha256"],
        "predecessor" => expected["predecessor"],
        "predecessor_sha256" => expected["predecessor_sha256"],
        "approved_amendment_path" => expected["proposal"],
        "approved_amendment_sha256" => expected["proposal_sha256"]
      }
    end

    defp authority_files_match?(root, expected) do
      Enum.all?(
        [
          {expected["path"], expected["sha256"]},
          {expected["predecessor"], expected["predecessor_sha256"]},
          {expected["proposal"], expected["proposal_sha256"]}
        ],
        fn {path, sha} -> file_digest(root, path) == sha end
      )
    end

    defp routed_authority?(root, router, authority) do
      {path, sha} = Map.fetch!(@current_authority, authority["document_id"])

      entries =
        Enum.filter(
          router["governing_documents"],
          &(&1["document_id"] == authority["document_id"])
        )

      case entries do
        [entry] ->
          entry["repository_path"] == path and entry["canonical_filename"] == Path.basename(path) and
            entry["sha256"] == sha and entry["semver"] == "1.17.0" and
            current_authority_files_match?(root, path, sha, authority["path"])

        _ ->
          false
      end
    end

    defp current_authority_files_match?(root, path, sha, predecessor) do
      file_digest(root, path) == sha and
        file_digest(root, @recovery_proposal) == @recovery_proposal_sha and
        file_digest(root, @email_change_proposal) == @email_change_proposal_sha and
        successor_lineage?(root, path, predecessor)
    end

    defp successor_lineage?(root, path, predecessor) do
      {v1_16_path, v1_16_sha} = Map.fetch!(@v1_16_authority, product_document_id(path))

      with {:ok, bytes} <- read_file(root, path),
           {:ok, v1_16_bytes} <- read_file(root, v1_16_path),
           true <- String.contains?(bytes, "**Predecessor:** `#{v1_16_path}`"),
           true <- String.contains?(bytes, "**SemVer transition:** `v1.16.0 → v1.17.0`"),
           true <- digest(v1_16_bytes) == v1_16_sha,
           true <- String.contains?(v1_16_bytes, "**Predecessor:** `#{predecessor}`"),
           true <- String.contains?(v1_16_bytes, "**SemVer transition:** `v1.15.0 → v1.16.0`") do
        true
      else
        _ -> false
      end
    end

    defp product_document_id("docs/governance/product/00_PLATFORM_v1.17.0.md"),
      do: "PLATFORM_PRODUCT_LAW"

    defp product_document_id("docs/governance/product/01_DECISIONS_v1.17.0.md"),
      do: "PRODUCT_DECISIONS"

    defp read_versions(root, packet) do
      versions = packet["locale_versions"]

      with true <- is_list(versions) and Enum.map(versions, & &1["locale"]) == ["en", "af"],
           {:ok, loaded} <- load_versions(root, versions) do
        {:ok, loaded}
      else
        _ -> {:error, :content_ineligible}
      end
    end

    defp load_versions(root, versions) do
      Enum.reduce_while(versions, {:ok, %{}}, fn version, {:ok, acc} ->
        locale = version["locale"]

        with {id, path, size, sha} <- Map.get(@translations, locale),
             true <- version["id"] == id,
             %{"path" => ^path, "bytes" => ^size, "sha256" => ^sha} <- version["artifact"],
             {:ok, bytes} <- read_file(root, path),
             true <- byte_size(bytes) == size and digest(bytes) == sha do
          {:cont, {:ok, Map.put(acc, locale, {version, bytes})}}
        else
          _ -> {:halt, {:error, :content_ineligible}}
        end
      end)
    end

    defp read_json(root, path) do
      with {:ok, bytes} <- read_file(root, path), do: Jason.decode(bytes)
    end

    defp read_file(root, path)
         when path in [
                @packet_path,
                @candidate_path,
                @approvals_path,
                @delivery_router_path,
                @governance_router_path,
                @recovery_proposal,
                @email_change_proposal,
                "docs/governance/product/00_PLATFORM_v1.16.0.md",
                "docs/governance/product/01_DECISIONS_v1.16.0.md",
                "docs/governance/product/00_PLATFORM_v1.17.0.md",
                "docs/governance/product/01_DECISIONS_v1.17.0.md"
              ] do
      read_regular_file(root, path)
    end

    defp read_file(root, path) when is_binary(path) do
      if path in Enum.map(Map.values(@current_authority), &elem(&1, 0)) or
           path in Enum.map(Map.values(@translations), fn {_id, artifact, _size, _sha} ->
             artifact
           end) or
           path in Enum.flat_map(
             @product_authority,
             &[&1["path"], &1["predecessor"], &1["proposal"]]
           ) do
        read_regular_file(root, path)
      else
        {:error, :content_ineligible}
      end
    end

    defp read_file(_root, _path), do: {:error, :content_ineligible}

    # sobelow_skip ["Traversal.FileModule"]
    # Paths are fixed above. Each segment is checked with lstat to reject symlinks.
    defp read_regular_file(root, path) do
      full_path = Path.join(root, path)

      with true <- regular_path_without_symlinks?(root, path),
           {:ok, bytes} <- File.read(full_path) do
        {:ok, bytes}
      else
        _ -> {:error, :content_ineligible}
      end
    end

    defp regular_path_without_symlinks?(root, path) do
      root = Path.expand(root)

      with {:ok, %{type: :directory}} <- File.lstat(root),
           true <- directories_exist?(root, Path.split(Path.dirname(path))),
           {:ok, %{type: :regular}} <- File.lstat(Path.join(root, path)) do
        true
      else
        _ -> false
      end
    rescue
      _ -> false
    end

    defp directories_exist?(_root, []), do: true

    defp directories_exist?(root, [directory | rest]) do
      next = Path.join(root, directory)

      case File.lstat(next) do
        {:ok, %{type: :directory}} -> directories_exist?(next, rest)
        _ -> false
      end
    end

    defp file_digest(root, path) do
      case read_file(root, path) do
        {:ok, bytes} -> digest(bytes)
        _ -> nil
      end
    end

    defp evidence_root do
      root =
        if Mix.env() == :test,
          do: Process.get({__MODULE__, :evidence_root}, @repo_root),
          else: @repo_root

      if is_binary(root), do: {:ok, Path.expand(root)}, else: {:error, :content_ineligible}
    end

    defp digest(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
  else
    @spec binding(String.t()) :: {:error, :content_ineligible}
    def binding(_locale), do: {:error, :content_ineligible}

    @spec eligible(map()) :: {:error, :content_ineligible}
    def eligible(_binding), do: {:error, :content_ineligible}
  end
end
