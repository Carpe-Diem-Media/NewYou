defmodule NewYou.Content.PasswordResetBrowserCopy do
  @moduledoc """
  Content-owned exact EN/AF wording for the bounded WELL-136 development journey.

  The attributable Product approval preserves the owner's exact five-capacity
  decision and the original packet digest. The derived artifact pins the
  23 literal source-table strings per locale and their UTF-8 bytes/digests.
  It is not a reconstruction of the original approved JSON serialization. It
  grants no runtime role, authentication, publication or participant-release
  authority. Both pinned files are verified before text is embedded; changed,
  withdrawn or missing runtime artifacts stop new consumption.
  """

  @development_build Mix.env() in [:dev, :test]
  @path Path.expand("../../../docs/development/fixtures/well136-c02-v0.1.json", __DIR__)
  @source Path.expand(
            "../../../docs/development/fixtures/well136-c02-owner-approval.json",
            __DIR__
          )
  @external_resource @path
  @external_resource @source
  @digest "2d1c6eda21bedde4e5c4be93e9a5f79a6b34a968025c533a584262e1932554d0"
  @source_digest "2fe86a5655aa2795150bacea67cc2830a8df2aafc23c415c924237a375fcb3cd"
  # Decode the same bytes whose digest was checked, never a second file read.
  artifact_bytes = File.read!(@path)
  source_bytes = File.read!(@source)

  unless Enum.all?(
           [{artifact_bytes, @digest}, {source_bytes, @source_digest}],
           fn {bytes, digest} ->
             Base.encode16(:crypto.hash(:sha256, bytes), case: :lower) == digest
           end
         ) do
    raise ArgumentError, "WELL-136 compile-time copy is not the pinned owner-approved version"
  end

  @artifact Jason.decode!(artifact_bytes)
  @entries Map.fetch!(@artifact, "entries")

  @doc "Checks the current immutable artifacts and the compile-time development boundary."
  @spec available?() :: boolean()
  def available? do
    :erlang.andalso(
      @development_build,
      current_file?(@path, @digest) and current_file?(@source, @source_digest)
    )
  end

  @doc "Reads one exact approved locale, without fallback or token interpolation."
  @spec text!(String.t(), String.t()) :: String.t()
  def text!(key, locale) when locale in ["en", "af"] do
    unless available?(), do: raise(ArgumentError, "WELL-136 development copy is unavailable")
    @entries |> Map.fetch!(key) |> Map.fetch!(locale) |> Map.fetch!("text")
  end

  def text!(_, _), do: raise(ArgumentError, "unsupported password-reset locale")

  @doc false
  @spec artifact_path() :: String.t()
  def artifact_path, do: @path

  @doc false
  @spec valid_artifact?(term()) :: boolean()
  def valid_artifact?(candidate), do: candidate == @artifact

  # Both paths are fixed module attributes, never supplied by a request.
  # sobelow_skip ["Traversal.FileModule"]
  defp current_file?(path, expected) do
    case File.read(path) do
      {:ok, bytes} -> Base.encode16(:crypto.hash(:sha256, bytes), case: :lower) == expected
      _ -> false
    end
  end
end
