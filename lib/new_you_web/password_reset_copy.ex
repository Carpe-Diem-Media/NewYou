defmodule NewYouWeb.PasswordResetCopy do
  @moduledoc """
  Keeps historical P8-12 browser wording separate from exact WELL-136 copy.

  The two-argument interface preserves the pre-existing P8-12 text. Ordinary
  WELL-136 templates explicitly select their approved Content artifact through
  the context-aware interface; neither path falls back into the other scope.
  """
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

  @copy %{
    "request.title" => %{"en" => "Reset your password", "af" => "Wysig jou wagwoord"},
    "request.body" => %{
      "en" => "Enter your email address to request a password reset link.",
      "af" => "Voer jou e-posadres in om ’n skakel vir ’n nuwe wagwoord aan te vra."
    },
    "request.action" => %{"en" => "Request reset link", "af" => "Vra wagwoordskakel aan"},
    "request.accepted.body" => %{
      "en" =>
        "If the address can receive a reset link, it will arrive shortly. You can close this page.",
      "af" =>
        "As die adres ’n wagwoordskakel kan ontvang, sal dit binnekort aankom. Jy kan hierdie bladsy toemaak."
    },
    "confirm.title" => %{"en" => "Choose a new password", "af" => "Kies ’n nuwe wagwoord"},
    "confirm.body" => %{
      "en" => "Confirm to change your password and sign out on all devices.",
      "af" => "Bevestig om jou wagwoord te wysig en op alle toestelle af te meld."
    },
    "confirm.action" => %{"en" => "Confirm new password", "af" => "Bevestig nuwe wagwoord"},
    "confirm.complete.title" => %{
      "en" => "Your password has changed",
      "af" => "Jou wagwoord is gewysig"
    },
    "confirm.complete.body" => %{
      "en" => "Sign in again with your new password.",
      "af" => "Meld weer met jou nuwe wagwoord aan."
    },
    "confirm.unavailable.title" => %{
      "en" => "Unable to reset your password",
      "af" => "Jou wagwoord kan nie gewysig word nie"
    },
    "confirm.unavailable.body" => %{
      "en" => "The link may have expired or already been used. Request a new one to continue.",
      "af" =>
        "Die skakel het dalk verval of is reeds gebruik. Vra ’n nuwe skakel aan om voort te gaan."
    }
  }
  @doc "Reads the unchanged historical P8-12 browser wording."
  @spec text!(String.t(), String.t()) :: String.t()
  def text!("request.accepted.title", locale) when locale in ["en", "af"],
    do: NewYouWeb.CopyRegistry.text!("identity.verification.pending.title", locale)

  def text!(key, locale) when locale in ["en", "af"],
    do: @copy |> Map.fetch!(key) |> Map.fetch!(locale)

  @doc "Reads browser wording for the trusted server-selected context, without cross-context fallback."
  @spec text!(String.t(), String.t(), :p8_12 | :well136) :: String.t()
  def text!(key, locale, :p8_12), do: text!(key, locale)

  def text!(key, locale, :well136),
    do: NewYou.Content.PasswordResetBrowserCopy.text!(Map.get(@aliases, key, key), locale)
end
