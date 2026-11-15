defmodule NewYou.Content.SignInCopy do
  @moduledoc """
  Content-owned exact EN/AF wording for the bounded WELL-134 development journey.

  Owner decision 5071ff0e-21e4-406c-9c69-0a3e1f6cf498 is preserved with its
  original version and canonical payload digest. The derived artifact pins the
  literal source-table strings and each locale's bytes/digest separately. It
  grants no runtime role, authentication, publication or participant-release
  authority. Changed, withdrawn or missing artifacts stop new consumption.
  """

  @development_build Mix.env() in [:dev, :test]
  @path Path.expand("../../../docs/development/fixtures/well134-c01-v0.1.json", __DIR__)
  @source Path.expand(
            "../../../docs/development/fixtures/well134-c01-owner-approval.json",
            __DIR__
          )
  @external_resource @path
  @external_resource @source
  @digest "4d442f4f7ad861e6d23feb3a23c421889b2f5516bb32963949389759f3d35f6c"
  @source_digest "6e6c592112ee9f1dcbd4fabe7595218a74d941afce2e5aa491a3ea78cce1a6f2"
  @artifact @path |> File.read!() |> Jason.decode!()
  @entries Map.fetch!(@artifact, "entries")

  @doc "Checks the current immutable artifacts and the compile-time development boundary."
  @spec available?() :: boolean()
  def available? do
    :erlang.andalso(
      @development_build,
      current_file?(@path, @digest) and
        current_file?(@source, @source_digest) and valid_artifact?(@artifact)
    )
  end

  @doc "Reads one exact approved locale, without fallback or token interpolation."
  @spec text!(String.t(), String.t()) :: String.t()
  def text!(key, locale) when locale in ["en", "af"] do
    unless available?(), do: raise(ArgumentError, "WELL-134 development copy is unavailable")
    @entries |> Map.fetch!(key) |> Map.fetch!(locale) |> Map.fetch!("text")
  end

  def text!(_, _), do: raise(ArgumentError, "unsupported sign-in locale")

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
