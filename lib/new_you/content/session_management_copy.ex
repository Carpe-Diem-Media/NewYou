defmodule NewYou.Content.SessionManagementCopy do
  @moduledoc "Loads the exact routed WELL-163 development copy for individual Session management."

  @enabled Mix.env() in [:dev, :test]
  @root Path.expand("../../..", __DIR__)
  @path "docs/delivery/content-evidence/copy/evidence/FP001_SESSION_AND_TRUSTED_DEVICE_BROWSER_COPY_APPROVED_v0.1.1.json"
  @document "FP001_SESSION_AND_TRUSTED_DEVICE_BROWSER_COPY_APPROVED"
  @digest "db49143d725bc09a16ca31490e438370377393632ebba5850ded318e67a381ef"
  @status "OWNER_APPROVED_BOUNDED_NONPRODUCTION_BROWSER_COPY; NO_IMPLEMENTATION_OR_RELEASE_AUTHORITY"

  @doc "Returns only the eligible individual-session strings for the requested locale."
  @spec load(String.t()) :: {:ok, %{String.t() => String.t()}} | {:error, :content_ineligible}
  def load(locale), do: load(locale, &read/1)

  defp load(locale, read) when locale in ["en", "af"] do
    with true <- @enabled,
         {:ok, router} <- read.("docs/delivery/CURRENT_DELIVERY_ROUTER.json"),
         {:ok, %{"delivery_contracts" => entries}} <- Jason.decode(router),
         [%{"repository_path" => @path, "sha256" => @digest, "status" => @status}] <-
           Enum.filter(entries, &(&1["document_id"] == @document)),
         {:ok, bytes} <- read.(@path),
         true <- digest(bytes) == @digest,
         {:ok, %{"copy_items" => items}} <- Jason.decode(bytes) do
      items
      |> Enum.filter(&individual_session_key?/1)
      |> Enum.reduce_while({:ok, %{}}, &collect_string(&1, &2, locale))
    else
      _ -> {:error, :content_ineligible}
    end
  end

  defp load(_locale, _read), do: {:error, :content_ineligible}

  if Mix.env() == :test do
    @doc false
    def load_for_proof(locale, read), do: load(locale, read)
  end

  defp collect_string(%{"key" => key} = item, {:ok, copy}, locale) do
    case item[locale] do
      %{"text" => text, "sha256" => expected} when is_binary(text) ->
        if digest(text) == expected,
          do: {:cont, {:ok, Map.put(copy, key, text)}},
          else: {:halt, {:error, :content_ineligible}}

      _ ->
        {:halt, {:error, :content_ineligible}}
    end
  end

  defp individual_session_key?(%{"key" => "identity.sessions.all." <> _}), do: false
  defp individual_session_key?(%{"key" => "identity.sessions." <> _}), do: true
  defp individual_session_key?(_item), do: false

  defp digest(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)

  # The caller selects only fixed router and packet paths.
  # sobelow_skip ["Traversal.FileModule"]
  defp read(path), do: File.read(Path.join(@root, path))
end
