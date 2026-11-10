defmodule NewYouWeb.PasswordResetCopy do
  @moduledoc "Low-risk bilingual form copy for the bounded development reset flow. Governed email content remains Content-owned."
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
  @spec text!(String.t(), String.t()) :: String.t()
  def text!("request.accepted.title", locale) when locale in ["en", "af"],
    do: NewYouWeb.CopyRegistry.text!("identity.verification.pending.title", locale)

  def text!(key, locale) when locale in ["en", "af"],
    do: @copy |> Map.fetch!(key) |> Map.fetch!(locale)
end
