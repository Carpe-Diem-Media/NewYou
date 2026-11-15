defmodule NewYou.Content.EntryCopy do
  @moduledoc """
  Content-owned reader for the exact FP-001 bilingual development copy subset.

  WELL-45 owner decision 2e55960d-6bfb-4fe1-a033-b1a435c028bc approves the
  registration and pending compositions at tree 707a555f16a137fdd2c4f62ec7a0551120f2b316.
  The registry's other candidates are not eligible through this interface.
  These immutable bytes grant no production or real-participant eligibility.
  """

  @development_build Mix.env() in [:dev, :test]
  @repo_root Path.expand("../../..", __DIR__)
  @composition_sources %{
    "docs/delivery/content-evidence/copy/pages/public/registration.yaml" =>
      "09ea540487523e9ac236fef4c706378540ea4b07fef7ca5a5b745624d41a8dd8",
    "docs/delivery/content-evidence/copy/pages/public/verification-pending.yaml" =>
      "6d433ead78a86cf58510f4a028b1a94b40d3e631a5e8fc3feb221eb0806c679b"
  }
  @composition_keys Enum.flat_map(@composition_sources, fn {path, digest} ->
                      source = Path.join(@repo_root, path)
                      @external_resource source
                      bytes = File.read!(source)

                      unless Base.encode16(:crypto.hash(:sha256, bytes), case: :lower) == digest,
                        do: raise("FP-001 composition differs from its approved source")

                      Regex.scan(~r/^  - (\S+)$/m, bytes, capture: :all_but_first)
                      |> List.flatten()
                    end)
  @ui_keys @composition_keys --
             ~w(legal.terms.development_baseline legal.privacy.development_baseline)
  @pinned_workspace_version "0.3.0"
  @pinned_registry_sha256 "744f1a34ad80c0158c86395f3f66227622714969526f5e9d69ee62314fd48635"
  @registry_path Path.expand(
                   "../../../docs/delivery/content-evidence/copy/COPY_REGISTRY.json",
                   __DIR__
                 )
  @external_resource @registry_path
  @registry_bytes File.read!(@registry_path)
  @registry_sha256 :crypto.hash(:sha256, @registry_bytes) |> Base.encode16(case: :lower)

  unless @registry_sha256 == @pinned_registry_sha256 do
    raise "P8-05 copy registry bytes do not match the pinned bounded-development source"
  end

  @registry Jason.decode!(@registry_bytes)

  unless @registry["workspace_version"] == @pinned_workspace_version do
    raise "P8-05 copy workspace version is not the pinned #{@pinned_workspace_version}"
  end

  @entries @registry["entries"]
           |> Map.new(fn entry -> {Map.fetch!(entry, "key"), entry} end)
           |> Map.take(@ui_keys)
  @locales ~w(en af)
  @configured_tokens ~w(platform_name)

  @doc "Checks exact current artifact bytes and the development-build boundary."
  @spec available?() :: boolean()
  # sobelow_skip ["Traversal.FileModule"]
  # Paths come only from the pinned module-attribute inventory above. No request,
  # registry entry or runtime setting can select a file to read.
  def available? do
    :erlang.andalso(
      @development_build,
      Enum.all?(
        Map.put(
          @composition_sources,
          "docs/delivery/content-evidence/copy/COPY_REGISTRY.json",
          @pinned_registry_sha256
        ),
        fn {path, digest} ->
          case File.read(Path.join(@repo_root, path)) do
            {:ok, bytes} -> Base.encode16(:crypto.hash(:sha256, bytes), case: :lower) == digest
            _ -> false
          end
        end
      )
    )
  end

  @doc "Reads one approved semantic key and exact locale, without fallback or new wording."
  @spec text!(String.t(), String.t() | atom(), map()) :: String.t()
  def text!(key, locale, replacements \\ %{}) when is_binary(key) and is_map(replacements) do
    unless available?(), do: raise(ArgumentError, "FP-001 development copy is unavailable")
    locale = to_string(locale)

    unless Map.keys(replacements) |> Enum.all?(&(&1 in @configured_tokens)) do
      raise ArgumentError, "unsupported governed copy token replacement"
    end

    unless locale in @locales do
      raise ArgumentError, "unsupported governed copy locale: #{inspect(locale)}"
    end

    text =
      @entries
      |> Map.fetch!(key)
      |> Map.fetch!(locale)
      |> Map.fetch!("text")

    rendered =
      Enum.reduce(replacements, text, fn {token, value}, copy ->
        String.replace(copy, "{{#{token}}}", token_value!(token, value))
      end)

    if Regex.match?(~r/\{\{[^}]+\}\}/, rendered) do
      raise ArgumentError, "unresolved governed copy token for #{key}/#{locale}"
    end

    rendered
  end

  defp token_value!(token, value) when is_binary(value) do
    if String.trim(value) == "" do
      raise ArgumentError, "missing governed copy token value: #{token}"
    end

    value
  end

  defp token_value!(token, _value) do
    raise ArgumentError, "invalid governed copy token value: #{token}"
  end
end
