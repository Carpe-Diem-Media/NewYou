defmodule NewYou.Content.RecoveryBrowserCopy do
  @moduledoc "Content-owned EN/AF browser wording for bounded WELL-183 Recovery."

  alias NewYou.Content.ProductAuthority

  @enabled Mix.env() in [:dev, :test]
  @root Path.expand("../../..", __DIR__)
  @document "FP001_RECOVERY_PHASE9_BROWSER_COPY_APPROVED"
  @filename "#{@document}_v0.3.0.json"
  @path "docs/delivery/content-evidence/copy/evidence/#{@filename}"
  @sha "eae5ea169d30278a70f97621f559d1669b8a897dcad5e276b74e4d1c9e15a06d"

  @doc "Load the exact approved wording for the requested locale. Missing or changed evidence denies use."
  @spec load(String.t()) :: {:ok, %{String.t() => String.t()}} | {:error, :content_ineligible}
  def load(locale) when locale in ["en", "af"] do
    with true <- @enabled,
         {:ok, delivery} <- json("docs/delivery/CURRENT_DELIVERY_ROUTER.json"),
         true <- routed?(delivery),
         {:ok, governance} <- json("docs/governance/CURRENT_GOVERNANCE_ROUTER.json"),
         {:ok, _} <- ProductAuthority.historical_bindings(governance, &read/1),
         {:ok, bytes} <- read(@path),
         true <- digest(bytes) == @sha,
         {:ok, %{"candidate" => %{"copy_items" => items}}} <- Jason.decode(bytes) do
      # The pinned approval envelope binds all 36 translations and receipts.
      {:ok, Map.new(items, &{&1["key"], &1["locales"][locale]["text"]})}
    else
      _ -> {:error, :content_ineligible}
    end
  rescue
    _ -> {:error, :content_ineligible}
  end

  def load(_), do: {:error, :content_ineligible}

  defp routed?(%{"delivery_contracts" => contracts}) when is_list(contracts) do
    Enum.filter(contracts, &(&1["document_id"] == @document)) == [
      %{
        "document_id" => @document,
        "canonical_filename" => @filename,
        "repository_path" => @path,
        "sha256" => @sha,
        "contract_type" => "content_evidence",
        "status" =>
          "OWNER_APPROVED_BOUNDED_NONPRODUCTION_BROWSER_COPY; NO_IMPLEMENTATION_OR_RELEASE_AUTHORITY"
      }
    ]
  end

  defp routed?(_), do: false

  defp json(path) do
    with {:ok, bytes} <- read(path), do: Jason.decode(bytes)
  end

  # Paths are fixed Content evidence and ProductAuthority module bindings.
  # sobelow_skip ["Traversal.FileModule"]
  defp read(path), do: File.read(Path.join(evidence_root(), path))

  defp evidence_root do
    if Mix.env() == :test, do: Process.get({__MODULE__, :evidence_root}, @root), else: @root
  end

  defp digest(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
end
