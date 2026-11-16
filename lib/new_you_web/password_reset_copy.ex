defmodule NewYouWeb.PasswordResetCopy do
  @moduledoc "Exact Content-owned WELL-136 browser copy with compatibility aliases for existing templates."

  @aliases %{
    "request.title" => "identity.password_reset.request.title",
    "request.body" => "identity.password_reset.request.body",
    "request.action" => "identity.password_reset.request.action",
    "request.accepted.title" => "identity.password_reset.request.accepted.title",
    "request.accepted.body" => "identity.password_reset.request.accepted.body",
    "confirm.title" => "identity.password_reset.confirm.title",
    "confirm.body" => "identity.password_reset.confirm.body",
    "confirm.action" => "identity.password_reset.confirm.action",
    "confirm.complete.title" => "identity.password_reset.confirm.complete.title",
    "confirm.complete.body" => "identity.password_reset.confirm.complete.body",
    "confirm.unavailable.title" => "identity.password_reset.confirm.unavailable.title",
    "confirm.unavailable.body" => "identity.password_reset.confirm.unavailable.body"
  }

  @doc "Reads exact approved EN/AF text; unsupported locales, keys or unavailable copy fail closed."
  @spec text!(String.t(), String.t()) :: String.t()
  def text!(key, locale),
    do: NewYou.Content.PasswordResetBrowserCopy.text!(Map.get(@aliases, key, key), locale)
end
