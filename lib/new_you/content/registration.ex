defmodule NewYou.Content.Registration do
  @moduledoc """
  Reads the immutable English legal development baselines used by Identity registration.

  Content and Media owns these source snapshots. This module exposes their pinned
  identifiers and bytes only when the manifest and artifact remain eligible for
  local development, automated tests, and development environments.
  """

  @development_environment Mix.env() in [:dev, :test]
  @repo_root Path.expand("../../..", __DIR__)
  @manifest_path Path.join([
                   @repo_root,
                   "docs/delivery/content-evidence/content_media/LEGAL_BASELINE_CONTENT_MANIFEST_v0.1.0.json"
                 ])

  @specs %{
    terms: %{
      version_id: "NEWYOU-TERMS-EN-DEV-2026-10-27-001",
      document_type: "terms",
      artifact_path:
        "docs/delivery/content-evidence/content_media/legal_baselines/NEWYOU-TERMS-EN-DEV-BASELINE-2026-10-27-001.html",
      source_content_sha256: "8d54af7ac0c2a68d3d100cca987551877f4f89ca231ae95254cd1903a2eca062",
      artifact_sha256: "6feb2d016f30e889c08995990a863429db0034af49fc6b6bd3467b90cda03937"
    },
    privacy: %{
      version_id: "NEWYOU-PRIVACY-EN-DEV-2026-10-27-001",
      document_type: "privacy",
      artifact_path:
        "docs/delivery/content-evidence/content_media/legal_baselines/NEWYOU-PRIVACY-EN-DEV-BASELINE-2026-10-27-001.html",
      source_content_sha256: "21aecdf9fafe95f513de2ce04a266e8e7726efb406aabae0bbd4d0e19f6ba333",
      artifact_sha256: "ac603377eaafce20bf5e425f64cfc97fbc855b20bd66deca481401f0f6efd43e"
    }
  }

  @allowed_contexts ~w(
    local_development
    automated_tests
    development_environments
    bounded_phase_8_architectural_proof
  )

  @doc "Returns the pinned terms and privacy version identifiers when eligible."
  @spec legal_versions() ::
          {:ok, %{terms_version_id: String.t(), privacy_version_id: String.t()}}
          | {:error, :content_ineligible}
  def legal_versions do
    if @development_environment and configured_versions_match?() and eligible_documents?() do
      {:ok, configured_versions()}
    else
      {:error, :content_ineligible}
    end
  end

  @doc "Returns the exact pinned English HTML for an eligible legal document."
  @spec legal_document(:terms | :privacy) :: {:ok, binary()} | {:error, :content_ineligible}
  # sobelow_skip ["Traversal.FileModule"]
  # The two guarded atoms select compile-time @specs paths. Participant input
  # and manifest artifact_path values never choose the file that is opened.
  def legal_document(document) when document in [:terms, :privacy] do
    with true <- @development_environment,
         true <- configured_versions_match?(),
         {:ok, entry} <- eligible_entry(document),
         {:ok, body} <- File.read(artifact_file(document)),
         true <- legal_baseline_valid?(document, entry, body) do
      {:ok, body}
    else
      _ -> {:error, :content_ineligible}
    end
  end

  def legal_document(_), do: {:error, :content_ineligible}

  @doc "Validates a manifest entry and its exact artifact bytes against the pinned baseline."
  @spec legal_baseline_valid?(atom(), map(), binary()) :: boolean()
  def legal_baseline_valid?(document, entry, body)
      when document in [:terms, :privacy] and is_map(entry) and is_binary(body) do
    if @development_environment and configured_versions_match?() do
      spec = Map.fetch!(@specs, document)
      manifest_entry_valid?(entry, spec) and artifact_valid?(body, spec)
    else
      false
    end
  end

  def legal_baseline_valid?(_, _, _), do: false

  defp eligible_documents? do
    Enum.all?([:terms, :privacy], fn document -> match?({:ok, _}, legal_document(document)) end)
  end

  defp eligible_entry(document) do
    with {:ok, manifest_body} <- File.read(@manifest_path),
         {:ok, %{"versions" => versions}} when is_list(versions) <- Jason.decode(manifest_body),
         spec <- Map.fetch!(@specs, document),
         [entry] <-
           Enum.filter(versions, fn
             %{"content_version_id" => version_id} -> version_id == spec.version_id
             _ -> false
           end),
         true <- manifest_entry_valid?(entry, spec) do
      {:ok, entry}
    else
      _ -> {:error, :content_ineligible}
    end
  end

  defp manifest_entry_valid?(entry, spec) do
    Enum.all?(
      [
        {"content_version_id", spec.version_id},
        {"artifact_path", spec.artifact_path},
        {"document_type", spec.document_type},
        {"document_locale", "en"},
        {"exact_content_sha256", spec.source_content_sha256},
        {"applicability_status", "DEVELOPMENT_ONLY_CURRENT"},
        {"effective_for_participants", false},
        {"approval_state", "NOT_LEGALLY_APPROVED"}
      ],
      fn {key, value} -> entry[key] == value end
    ) and entry["withdrawal"]["status"] == "NOT_WITHDRAWN" and
      match?(%{"superseded_by" => nil}, entry["supersession"]) and
      Enum.all?(@allowed_contexts, &(&1 in entry["allowed_contexts"]))
  rescue
    _ -> false
  end

  defp artifact_valid?(body, spec) do
    Enum.all?(
      [
        {"newyou-content-version-id", spec.version_id},
        {"newyou-document-type", spec.document_type},
        {"newyou-document-locale", "en"},
        {"newyou-content-sha256", spec.source_content_sha256}
      ],
      fn {name, value} -> html_meta_content(body, name) == value end
    ) and artifact_sha256(body) == spec.artifact_sha256
  end

  defp configured_versions do
    Application.get_env(:new_you, :identity_registration_legal_versions)
  end

  defp configured_versions_match? do
    configured_versions() == %{
      terms_version_id: @specs.terms.version_id,
      privacy_version_id: @specs.privacy.version_id
    }
  end

  defp artifact_file(document),
    do: Path.join(@repo_root, Map.fetch!(@specs, document).artifact_path)

  defp html_meta_content(body, name) do
    pattern = ~r/<meta name="#{Regex.escape(name)}" content="([^"]+)">/

    case Regex.run(pattern, body, capture: :all_but_first) do
      [content] -> content
      _ -> nil
    end
  end

  defp artifact_sha256(body),
    do: Base.encode16(:crypto.hash(:sha256, body), case: :lower)
end
