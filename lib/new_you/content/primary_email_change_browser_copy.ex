defmodule NewYou.Content.PrimaryEmailChangeBrowserCopy do
  @moduledoc "Exact routed browser copy for bounded WELL-156 development."

  @enabled Mix.env() in [:dev, :test]
  @root Path.expand("../../..", __DIR__)
  @path "docs/delivery/content-evidence/copy/evidence/FP001_PRIMARY_EMAIL_CHANGE_PHASE9_BROWSER_COPY_APPROVED_v0.1.1.json"
  @sha "41d6ae138c541ea05e1efdcfec42865d3dc019a697aebc2d182333b18ed9edc4"
  @document "FP001_PRIMARY_EMAIL_CHANGE_PHASE9_BROWSER_COPY_APPROVED"

  @doc "Loads the approved wording for one exact locale, or denies consumption."
  @spec load(String.t()) :: {:ok, %{String.t() => String.t()}} | {:error, :content_ineligible}
  def load(locale) when locale in ["en", "af"] do
    with true <- @enabled,
         {:ok, router} <- read("docs/delivery/CURRENT_DELIVERY_ROUTER.json"),
         {:ok, %{"delivery_contracts" => entries}} <- Jason.decode(router),
         [
           %{
             "repository_path" => @path,
             "sha256" => @sha,
             "status" =>
               "OWNER_APPROVED_BOUNDED_NONPRODUCTION_BROWSER_COPY; PHASE9_EMAIL_AND_RELEASE_PROHIBITED"
           }
         ] <-
           Enum.filter(entries, &(&1["document_id"] == @document)),
         {:ok, bytes} <- read(@path),
         true <- Base.encode16(:crypto.hash(:sha256, bytes), case: :lower) == @sha,
         {:ok, %{"copy_items" => items}} <- Jason.decode(bytes) do
      {:ok, Map.new(items, &{&1["semantic_key"], Map.fetch!(&1, locale)})}
    else
      _ -> {:error, :content_ineligible}
    end
  rescue
    _ -> {:error, :content_ineligible}
  end

  def load(_), do: {:error, :content_ineligible}

  # Only fixed module paths reach this reader.
  # sobelow_skip ["Traversal.FileModule"]
  defp read(path), do: File.read(Path.join(@root, path))
end
