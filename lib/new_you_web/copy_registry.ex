defmodule NewYouWeb.CopyRegistry do
  @moduledoc """
  Compile-time reader for the pinned bilingual copy workspace used by P8-05.

  Plane records bounded-development approval for workspace v0.3.0. Registry status
  is not changed here and does not imply production approval. This module preserves
  semantic copy identity and fails closed when a key, locale, or configured token is
  unavailable; it never falls back to another locale or invents participant wording.
  """

  @pinned_workspace_version "0.3.0"
  @pinned_registry_sha256 "744f1a34ad80c0158c86395f3f66227622714969526f5e9d69ee62314fd48635"
  @registry_path Path.expand(
                   "../../docs/delivery/content-evidence/copy/COPY_REGISTRY.json",
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

  @entries Map.new(@registry["entries"], fn entry -> {Map.fetch!(entry, "key"), entry} end)
  @locales ~w(en af)
  @configured_tokens ~w(platform_name)

  @spec text!(String.t(), String.t() | atom(), map()) :: String.t()
  def text!(key, locale, replacements \\ %{}) when is_binary(key) and is_map(replacements) do
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
