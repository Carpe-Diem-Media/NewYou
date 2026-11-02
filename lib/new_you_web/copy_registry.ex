defmodule NewYouWeb.CopyRegistry do
  @moduledoc """
  Compile-time reader for the approved bilingual copy workspace used by P8-05.

  The registry owns semantic copy identity. This module deliberately fails closed
  when a requested semantic key, locale, or governed token is unavailable rather
  than falling back to another locale or inventing participant-facing wording.
  """

  @approved_workspace_version "0.3.0"
  @registry_path Path.expand("../../docs/delivery/content-evidence/copy/COPY_REGISTRY.json", __DIR__)
  @external_resource @registry_path
  @registry @registry_path |> File.read!() |> Jason.decode!()

  unless @registry["workspace_version"] == @approved_workspace_version do
    raise "P8-05 copy workspace version is not the approved #{@approved_workspace_version}"
  end

  @entries Map.new(@registry["entries"], fn entry -> {Map.fetch!(entry, "key"), entry} end)
  @locales ~w(en af)

  @spec text!(String.t(), String.t() | atom(), map()) :: String.t()
  def text!(key, locale, replacements \\ %{}) when is_binary(key) and is_map(replacements) do
    locale = to_string(locale)

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
        String.replace(copy, "{{#{token}}}", to_string(value))
      end)

    if Regex.match?(~r/\{\{[^}]+\}\}/, rendered) do
      raise ArgumentError, "unresolved governed copy token for #{key}/#{locale}"
    end

    rendered
  end
end
