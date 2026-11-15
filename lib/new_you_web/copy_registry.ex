defmodule NewYouWeb.CopyRegistry do
  @moduledoc """
  Web adapter for Content-owned, exact bilingual FP-001 development copy.

  Only keys in the owner-approved registration and pending compositions are
  available. Content eligibility is independent of presentation and grants no
  production authority.
  """

  @doc "Reads an eligible semantic key in the exact requested locale without fallback."
  @spec text!(String.t(), String.t() | atom(), map()) :: String.t()
  def text!(key, locale, replacements \\ %{}),
    do: NewYou.Content.EntryCopy.text!(key, locale, replacements)
end
