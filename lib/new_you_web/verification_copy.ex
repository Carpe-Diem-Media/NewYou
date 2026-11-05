defmodule NewYouWeb.VerificationCopy do
  @moduledoc """
  Pinned temporary P8-07 copy authorized for bounded development proof only.
  The fixture records authorship, exact bytes and the owner's scoped permission.
  It records no prior exact-byte review, runtime grant or release approval.
  """

  @development_build Mix.env() in [:dev, :test]
  @version "p8-07-temporary-v1"
  @path Path.expand("../../docs/development/fixtures/p8-07-copy-v1.json", __DIR__)
  @external_resource @path
  @bytes File.read!(@path)
  @digest "146eeb3399c96fd0bc995fc905161a4a70f90bbf21fa77f395b2e427e840b1fa"
  unless Base.encode16(:crypto.hash(:sha256, @bytes), case: :lower) == @digest,
    do: raise("P8-07 temporary copy differs from its pinned version")

  @entries Jason.decode!(@bytes)["entries"]

  @spec enabled?() :: boolean()
  def enabled? do
    Enum.all?([
      @development_build,
      Application.get_env(:new_you, :verification_development_fixtures) == true,
      Application.get_env(:new_you, :p8_07_browser_development_fixtures) == @version
    ])
  end

  @spec text!(String.t(), String.t()) :: String.t()
  def text!(key, locale) when locale in ["en", "af"] do
    unless enabled?(), do: raise(ArgumentError, "P8-07 development copy is unavailable")
    @entries |> Map.fetch!(key) |> Map.fetch!(locale) |> Map.fetch!("text")
  end
end
