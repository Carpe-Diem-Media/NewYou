defmodule NewYou.Content.MagicLoginMessage do
  @moduledoc """
  Reads exact owner-approved magic-login message bytes for bounded development use.

  Each call rechecks the current delivery route, approved evidence and locale
  artifacts. The contract grants no production or participant delivery eligibility.
  """

  @enabled Mix.env() in [:dev, :test] and
             Application.compile_env(:new_you, :verification_development_fixtures, false)

  if @enabled do
    @packet_path "docs/delivery/content-evidence/content_media/magic_login_messages/MAGIC_LOGIN_MESSAGE_EVIDENCE_PACKET_v0.2.0.json"
    @candidate_path "docs/delivery/content-evidence/content_media/magic_login_messages/MAGIC_LOGIN_MESSAGE_EVIDENCE_PACKET_v0.1.0.json"
    @approvals_path "docs/delivery/content-evidence/content_media/magic_login_messages/OWNER_APPROVALS_v1.json"
    @delivery_router_path "docs/delivery/CURRENT_DELIVERY_ROUTER.json"
    @governance_router_path "docs/governance/CURRENT_GOVERNANCE_ROUTER.json"
    @packet_sha "9ef29d3417acabc32a4cf0757150ef5bc5ed2510c968b3effc9618b7f44073ba"
    @candidate_sha "096401942a84e8c002d9f67d30537e70e1479e8bb2e521814b98e706b262b517"
    @approvals_sha "ee4bb9d52d05c2c897334ead20b5d27fbcfd2174810c3be2c93a17321c2d8e41"
    @repo_root Path.expand("../../..", __DIR__)
    @item_id "NEWYOU-CONTENTITEM-MAGIC-LOGIN-MESSAGE-EMAIL"
    @version_id "NEWYOU-CONTENTVERSION-MAGIC-LOGIN-MESSAGE-EMAIL-V1"
    @allowed_scope [
      "local development",
      "automated tests",
      "development environments",
      "bounded P8-09 Phase-8 proof"
    ]
    @prohibited_scope ["production", "public release", "paid pilot", "real-participant delivery"]
    @translations %{
      "en" => {
        "NEWYOU-CONTENTTRANSLATIONVERSION-MAGIC-LOGIN-MESSAGE-EMAIL-EN-V1",
        "docs/delivery/content-evidence/content_media/magic_login_messages/NEWYOU-MAGIC-LOGIN-MESSAGE-EMAIL-EN-V1.txt",
        278,
        "3527fcea7813b4348dd9c2ff06ed0c617c7a8eb6a356e16c4afa63c6b168707b"
      },
      "af" => {
        "NEWYOU-CONTENTTRANSLATIONVERSION-MAGIC-LOGIN-MESSAGE-EMAIL-AF-V1",
        "docs/delivery/content-evidence/content_media/magic_login_messages/NEWYOU-MAGIC-LOGIN-MESSAGE-EMAIL-AF-V1.txt",
        327,
        "05c09bd18c805572f7bbc75717f5f6a09d3b5eca44f6bb08959ae2bd4fdc3f89"
      }
    }
    @historical_promoted_authority [
      %{
        "document_id" => "PLATFORM_PRODUCT_LAW",
        "path" => "docs/governance/product/00_PLATFORM_v1.14.0.md",
        "sha256" => "bcec310103319441d12c6efae1c7c779a013a503b3831da630abb4a55187314b",
        "predecessor" => "docs/governance/product/00_PLATFORM_v1.13.0.md",
        "predecessor_sha256" =>
          "eac45fab280eaa157bb3e3268463f879c1c09648566c5c84a900bcbc25215413",
        "approved_amendment_path" =>
          "docs/governance/product/proposals/well-97/00_PLATFORM_v1.14.0_PROPOSED.md",
        "approved_amendment_sha256" =>
          "7502b74167737cdcb84e7b819539243f4472021532ce475843aa4b5315bf5f99",
        "version" => "1.14.0"
      },
      %{
        "document_id" => "PRODUCT_DECISIONS",
        "path" => "docs/governance/product/01_DECISIONS_v1.14.0.md",
        "sha256" => "d97cb742deefa744279b47686bf5148cceea4b95839fe5b32ad6bbe7d2b6b1fd",
        "predecessor" => "docs/governance/product/01_DECISIONS_v1.13.0.md",
        "predecessor_sha256" =>
          "fbe84ea762b1ff298080d3938307938b69c85f85284d6b6104a8da1bf093aa9d",
        "approved_amendment_path" =>
          "docs/governance/product/proposals/well-97/01_DECISIONS_v1.14.0_PROPOSED.md",
        "approved_amendment_sha256" =>
          "560ba5438ee15dc1e8bc8a4e849e067382244d5531116ab5ff445742180684da",
        "version" => "1.14.0"
      }
    ]
    @current_successor_authority [
      %{
        "document_id" => "PLATFORM_PRODUCT_LAW",
        "canonical_filename" => "00_PLATFORM_v1.15.0.md",
        "repository_path" => "docs/governance/product/00_PLATFORM_v1.15.0.md",
        "sha256" => "c7f5510817028d28edd4eb29e71b9150e13d0354cccf1af23666e067e0eed0b8",
        "semver" => "1.15.0",
        "predecessor_path" => "docs/governance/product/00_PLATFORM_v1.14.0.md",
        "predecessor_sha256" =>
          "bcec310103319441d12c6efae1c7c779a013a503b3831da630abb4a55187314b",
        "approved_amendment_path" =>
          "docs/governance/product/proposals/well-98/00_PLATFORM_v1.15.0_PROPOSED.md",
        "approved_amendment_sha256" =>
          "a9ae584bccc984faca20aeed2428edc00a05ad54aead237a57a6d90388eedebb"
      },
      %{
        "document_id" => "PRODUCT_DECISIONS",
        "canonical_filename" => "01_DECISIONS_v1.15.0.md",
        "repository_path" => "docs/governance/product/01_DECISIONS_v1.15.0.md",
        "sha256" => "db57b0b73ed9faf8f3ade458c01d0d4798e4c2401172a35b9a1ad129ce8ae8d4",
        "semver" => "1.15.0",
        "predecessor_path" => "docs/governance/product/01_DECISIONS_v1.14.0.md",
        "predecessor_sha256" =>
          "d97cb742deefa744279b47686bf5148cceea4b95839fe5b32ad6bbe7d2b6b1fd",
        "approved_amendment_path" =>
          "docs/governance/product/proposals/well-98/01_DECISIONS_v1.15.0_PROPOSED.md",
        "approved_amendment_sha256" =>
          "b4374a82d605320fba01733176cc8a57346a97da1a0d03095d79b818926f2017"
      }
    ]

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
           true <- current_route?(delivery_router),
           true <- approved_packet?(packet),
           {:ok, candidate_bytes} <- read_file(root, @candidate_path),
           true <- digest(candidate_bytes) == @candidate_sha,
           true <- candidate_bound?(packet, candidate_bytes),
           {:ok, approvals} <- read_file(root, @approvals_path),
           true <- digest(approvals) == @approvals_sha,
           true <- approval_bound?(packet, approvals),
           true <- promoted_authority_current?(root, packet),
           {:ok, versions} <- read_versions(root, packet) do
        {:ok, packet, versions}
      else
        _ -> {:error, :content_ineligible}
      end
    end

    defp current_route?(router) do
      contracts = Map.get(router, "delivery_contracts", [])

      current =
        Enum.filter(contracts, &(&1["document_id"] == "MAGIC_LOGIN_MESSAGE_DEVELOPMENT_EVIDENCE"))

      candidate =
        Enum.filter(contracts, &(&1["document_id"] == "MAGIC_LOGIN_MESSAGE_CANDIDATE_EVIDENCE"))

      current == [
        %{
          "document_id" => "MAGIC_LOGIN_MESSAGE_DEVELOPMENT_EVIDENCE",
          "canonical_filename" => "MAGIC_LOGIN_MESSAGE_EVIDENCE_PACKET_v0.2.0.json",
          "repository_path" => @packet_path,
          "sha256" => @packet_sha,
          "contract_type" => "content_evidence",
          "status" => "DEVELOPMENT_ONLY_APPROVED; RUNTIME_RELEASE_PROHIBITED"
        }
      ] and
        candidate == [
          %{
            "document_id" => "MAGIC_LOGIN_MESSAGE_CANDIDATE_EVIDENCE",
            "canonical_filename" => "MAGIC_LOGIN_MESSAGE_EVIDENCE_PACKET_v0.1.0.json",
            "repository_path" => @candidate_path,
            "sha256" => @candidate_sha,
            "contract_type" => "content_evidence",
            "status" => "CANDIDATE_NOT_APPROVED"
          }
        ]
    end

    defp approved_packet?(packet) do
      packet_identity?(packet) and approved_scope?(packet) and approved_lifecycle?(packet) and
        approved_security_boundary?(packet) and approved_owner_decisions?(packet)
    end

    defp packet_identity?(packet) do
      packet["packet_id"] == "magic-login-message-email-development-evidence-v0.2.0" and
        packet["status"] == "DEVELOPMENT_ONLY_APPROVED; RUNTIME_RELEASE_PROHIBITED" and
        packet["owner"] == "Content & Media" and packet["content_item_id"] == @item_id and
        packet["content_version_id"] == @version_id
    end

    defp approved_scope?(packet),
      do: packet["scope"] == %{"allowed" => @allowed_scope, "prohibited" => @prohibited_scope}

    defp approved_lifecycle?(packet) do
      packet["lifecycle"]["state"] == "development_approved" and
        packet["eligibility"] == %{
          "development" => true,
          "runtime_release" => false,
          "production" => false,
          "public_release" => false,
          "paid_pilot" => false,
          "real_participant_delivery" => false
        }
    end

    defp approved_security_boundary?(packet) do
      security = packet["security"]

      security["runtime_changes"] == false and
        security["authentication_input_rebinding"] == false and
        security["protected_bearer_retention_extension"] == false
    end

    defp approved_owner_decisions?(packet) do
      Enum.map(packet["approval_events"], &{&1["owner"], &1["decision"]}) ==
        [{"Product", "approve"}, {"Content & Media", "approve"}]
    end

    defp candidate_bound?(packet, bytes) do
      case Jason.decode(bytes) do
        {:ok, _candidate} ->
          packet["predecessor_packet"] == %{"path" => @candidate_path, "sha256" => @candidate_sha}

        _ ->
          false
      end
    end

    defp approval_bound?(packet, bytes) do
      case Jason.decode(bytes) do
        {:ok, _approvals} ->
          packet["approval_source"] == %{"path" => @approvals_path, "sha256" => @approvals_sha}

        _ ->
          false
      end
    end

    defp promoted_authority_current?(root, packet) do
      with {:ok, router} <- read_json(root, @governance_router_path),
           true <- packet["promoted_authority"] == @historical_promoted_authority,
           true <- historical_promoted_authority_matches?(root),
           true <- current_successor_authority_matches?(root, router) do
        true
      else
        _ -> false
      end
    end

    defp historical_promoted_authority_matches?(root) do
      Enum.all?(@historical_promoted_authority, fn authority ->
        file_digest(root, authority["path"]) == authority["sha256"] and
          file_digest(root, authority["predecessor"]) == authority["predecessor_sha256"] and
          file_digest(root, authority["approved_amendment_path"]) ==
            authority["approved_amendment_sha256"]
      end)
    end

    defp current_successor_authority_matches?(root, router) do
      Enum.all?(@current_successor_authority, fn authority ->
        promoted_authority_matches?(root, router, authority)
      end)
    end

    defp promoted_authority_matches?(root, router, authority) do
      entries =
        router
        |> Map.get("governing_documents", [])
        |> Enum.filter(&(&1["document_id"] == authority["document_id"]))

      case entries do
        [entry] ->
          route =
            Map.take(entry, [
              "document_id",
              "canonical_filename",
              "repository_path",
              "sha256",
              "semver"
            ])

          expected_route =
            Map.take(authority, [
              "document_id",
              "canonical_filename",
              "repository_path",
              "sha256",
              "semver"
            ])

          route == expected_route and successor_lineage_matches?(root, authority)

        _ ->
          false
      end
    end

    defp successor_lineage_matches?(root, authority) do
      path = authority["repository_path"]
      predecessor_path = authority["predecessor_path"]

      with {:ok, bytes} <- read_file(root, path),
           true <- digest(bytes) == authority["sha256"],
           true <- file_digest(root, predecessor_path) == authority["predecessor_sha256"],
           true <-
             file_digest(root, authority["approved_amendment_path"]) ==
               authority["approved_amendment_sha256"],
           true <-
             String.contains?(bytes, "**Predecessor:** `#{predecessor_path}`"),
           true <- String.contains?(bytes, "**SemVer transition:** `v1.14.0 → v1.15.0`") do
        true
      else
        _ -> false
      end
    end

    defp read_versions(root, packet) do
      with versions when is_list(versions) <- packet["locale_versions"],
           true <- Enum.map(versions, & &1["locale"]) |> Enum.sort() == ["af", "en"],
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
                "docs/delivery/content-evidence/content_media/magic_login_messages/WELL-12-candidate-comment.json",
                "docs/governance/product/00_PLATFORM_v1.14.0.md",
                "docs/governance/product/01_DECISIONS_v1.14.0.md",
                "docs/governance/product/00_PLATFORM_v1.13.0.md",
                "docs/governance/product/01_DECISIONS_v1.13.0.md",
                "docs/governance/product/00_PLATFORM_v1.15.0.md",
                "docs/governance/product/01_DECISIONS_v1.15.0.md",
                "docs/governance/product/proposals/well-97/00_PLATFORM_v1.14.0_PROPOSED.md",
                "docs/governance/product/proposals/well-97/01_DECISIONS_v1.14.0_PROPOSED.md",
                "docs/governance/product/proposals/well-98/00_PLATFORM_v1.15.0_PROPOSED.md",
                "docs/governance/product/proposals/well-98/01_DECISIONS_v1.15.0_PROPOSED.md"
              ] do
      read_regular_file(root, path)
    end

    defp read_file(root, path) when is_binary(path) do
      if path in Enum.map(Map.values(@translations), fn {_id, artifact, _size, _sha} ->
           artifact
         end) do
        read_regular_file(root, path)
      else
        {:error, :content_ineligible}
      end
    end

    defp read_file(_root, _path), do: {:error, :content_ineligible}

    # sobelow_skip ["Traversal.FileModule"]
    # The caller permits only fixed repository evidence paths. Production never
    # selects a request path or root; TEST alone may select a fixture root. Every
    # path segment is checked with lstat to reject symlinks before the read.
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
      directories = Path.split(Path.dirname(path))

      with {:ok, %{type: :directory}} <- File.lstat(root),
           true <- directories_exist?(root, directories),
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
        if Mix.env() == :test do
          Process.get({__MODULE__, :evidence_root}, @repo_root)
        else
          @repo_root
        end

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
