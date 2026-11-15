defmodule NewYouWeb.MagicLoginCopy do
  @moduledoc "Compatibility adapter from existing magic UI keys to approved C-01 semantic keys."

  @keys %{
    "request.title" => "identity.magic.request.title",
    "request.body" => "identity.magic.request.body",
    "request.action" => "identity.magic.request.action",
    "request.accepted.title" => "identity.magic.request.result.title",
    "request.accepted.body" => "identity.magic.request.result.body",
    "confirm.title" => "identity.magic.confirm.title",
    "confirm.body" => "identity.magic.confirm.body",
    "confirm.action" => "identity.magic.confirm.action",
    "confirm.unavailable.title" => "identity.magic.confirm.unavailable.title",
    "confirm.unavailable.body" => "identity.magic.confirm.unavailable.body"
  }

  @doc "Reads current exact Content-owned C-01 wording, without locale fallback."
  @spec text!(String.t(), String.t()) :: String.t()
  def text!(key, locale), do: NewYouWeb.SignInCopy.text!(Map.fetch!(@keys, key), locale)
end
