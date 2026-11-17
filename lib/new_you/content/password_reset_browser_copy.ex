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

  defmodule UnavailableError do
    @moduledoc false
    defexception message: "WELL-136 development copy is unavailable"
  end

  if Mix.env() in [:dev, :test] do
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
      current_file?(@path, @digest) and current_file?(@source, @source_digest)
    end

    @doc "Reads one exact approved locale, without fallback or token interpolation."
    @spec text!(String.t(), String.t()) :: String.t()
    def text!(key, locale) when locale in ["en", "af"] do
      unless available?(), do: raise(UnavailableError)
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
      with path when is_binary(path) <- current_path(path),
           {:ok, bytes} <- File.read(path) do
        Base.encode16(:crypto.hash(:sha256, bytes), case: :lower) == expected
      else
        _ -> false
      end
    end

    if Mix.env() == :test do
      @repo_root Path.expand("../../..", __DIR__)
      # Mirrors the email reader's isolated TEST evidence scope. DEV and PROD
      # always use the fixed pinned paths; no request can select an evidence root.
      defp current_path(path) do
        case Process.get({__MODULE__, :evidence_root}, @repo_root) do
          root when is_binary(root) -> Path.join(root, Path.relative_to(path, @repo_root))
          _ -> nil
        end
      end
    else
      defp current_path(path), do: path
    end
  else
    @doc "Production builds have no WELL-136 browser Content eligibility."
    @spec available?() :: false
    def available?, do: false

    @doc "Production builds contain no approved WELL-136 browser copy."
    @spec text!(String.t(), String.t()) :: no_return()
    def text!(_key, _locale), do: raise(UnavailableError)

    @doc false
    @spec artifact_path() :: nil
    def artifact_path, do: nil

    @doc false
    @spec valid_artifact?(term()) :: false
    def valid_artifact?(_candidate), do: false
  end
end
