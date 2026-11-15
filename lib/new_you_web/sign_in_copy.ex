defmodule NewYouWeb.SignInCopy do
  @moduledoc "Web adapter for Content-owned exact WELL-134 development copy."

  @doc "Reads the exact eligible semantic key and locale through its Content owner."
  @spec text!(String.t(), String.t()) :: String.t()
  defdelegate text!(key, locale), to: NewYou.Content.SignInCopy

  @doc "Checks current development-only content eligibility."
  @spec available?() :: boolean()
  defdelegate available?(), to: NewYou.Content.SignInCopy
end
