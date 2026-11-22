defmodule NewYou.Content.ProductAuthority do
  @moduledoc false

  @product_directory "docs/governance/product"
  @routes [
    {"PLATFORM_PRODUCT_LAW", "00_PLATFORM",
     "5308e09f668b4a9762f98fb0bcbddf2f84595703b69c6ed511e8f511c3da36b1",
     "e94fd66f09aa4033fb66ffa3d73ab6f28a650c589dce33c086c746e2e508e9b9"},
    {"PRODUCT_DECISIONS", "01_DECISIONS",
     "7282344c42e850a2683e15dcce21b46bb3ecca28d9fac22b91b01ec7e8f32b16",
     "ed90a1ec6adb201de094f130fc091c10bca6145e142a6e225fc840794553f4c2"}
  ]

  @doc """
  Checks the current v1.20 Product and Decision pair before returning the
  verified v1.19 bindings used by immutable pre-WELL-175 approval evidence.
  """
  @spec historical_bindings(map(), (String.t() -> {:ok, binary()} | {:error, term()})) ::
          {:ok, [map()]} | {:error, :content_ineligible}
  def historical_bindings(%{"governing_documents" => documents}, read)
      when is_list(documents) do
    Enum.reduce_while(@routes, {:ok, []}, fn {id, stem, current_sha, prior_sha},
                                             {:ok, bindings} ->
      current = entry(id, stem, "1.20.0", current_sha)
      prior = entry(id, stem, "1.19.0", prior_sha)

      with [^current] <- Enum.filter(documents, &(&1["document_id"] == id)),
           {:ok, bytes} <- read.(current["repository_path"]),
           true <- digest(bytes) == current_sha,
           true <- String.contains?(bytes, "**Predecessor:** `#{prior["repository_path"]}`"),
           true <- String.contains?(bytes, "**SemVer transition:** `v1.19.0 → v1.20.0`"),
           {:ok, prior_bytes} <- read.(prior["repository_path"]),
           true <- digest(prior_bytes) == prior_sha do
        {:cont, {:ok, [prior | bindings]}}
      else
        _ -> {:halt, {:error, :content_ineligible}}
      end
    end)
  end

  def historical_bindings(_, _), do: {:error, :content_ineligible}

  defp entry(id, stem, version, sha) do
    filename = "#{stem}_v#{version}.md"

    %{
      "document_id" => id,
      "canonical_filename" => filename,
      "repository_path" => "#{@product_directory}/#{filename}",
      "sha256" => sha,
      "semver" => version
    }
  end

  defp digest(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
end
