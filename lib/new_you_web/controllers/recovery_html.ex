defmodule NewYouWeb.RecoveryHTML do
  use NewYouWeb, :html
  embed_templates "recovery_html/*"

  defp text(nil, "identity.recovery." <> key, locale),
    do: NewYouWeb.RecoveryCopy.text!(key, locale)

  defp text(nil, key, locale), do: NewYouWeb.CopyRegistry.text!(key, locale)
  defp text(copy, key, _locale), do: Map.fetch!(copy, key)
end
