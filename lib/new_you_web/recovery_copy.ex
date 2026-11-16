defmodule NewYouWeb.RecoveryCopy do
  @moduledoc "Class B JIT copy for identity.recovery.family, using existing authentication labels where meanings match. Governed email bytes remain Content-owned."
  @copy %{
    "request.title" => %{"en" => "Recover your account", "af" => "Herstel jou rekening"},
    "request.body" => %{
      "en" => "Enter your email address to request recovery.",
      "af" => "Voer jou e-posadres in om herstel aan te vra."
    },
    "request.action" => %{"en" => "Request recovery link", "af" => "Vra herstelskakel aan"},
    "requested.title" => %{"en" => "Check your email", "af" => "Kyk na jou e-pos"},
    "requested.body" => %{
      "en" => "If recovery is available for this address, the next steps will be sent by email.",
      "af" =>
        "Indien herstel vir hierdie adres beskikbaar is, sal die volgende stappe per e-pos gestuur word."
    },
    "confirmation.title" => %{
      "en" => "Confirm account recovery",
      "af" => "Bevestig rekeningherstel"
    },
    "confirmation.body" => %{
      "en" =>
        "Continue only if you requested recovery. Opening this page does not change your password.",
      "af" =>
        "Gaan slegs voort as jy herstel aangevra het. Om hierdie bladsy oop te maak, verander nie jou wagwoord nie."
    },
    "confirmation.action" => %{"en" => "Continue recovery", "af" => "Gaan voort met herstel"},
    "credential.body" => %{
      "en" =>
        "Completion changes your password and signs out existing sessions. Further verification may be required.",
      "af" =>
        "Voltooiing verander jou wagwoord en meld bestaande sessies af. Verdere verifikasie kan nodig wees."
    },
    "unavailable.title" => %{
      "en" => "Recovery could not continue",
      "af" => "Herstel kon nie voortgaan nie"
    },
    "unavailable.body" => %{
      "en" =>
        "This step could not be completed. Request a new link or contact support for further verification.",
      "af" =>
        "Hierdie stap kon nie voltooi word nie. Vra 'n nuwe skakel aan of kontak ondersteuning vir verdere verifikasie."
    }
  }

  @spec text!(String.t(), String.t()) :: String.t()
  def text!("credential.title", locale),
    do: NewYouWeb.PasswordResetCopy.text!("confirm.title", locale)

  def text!("credential.action", locale),
    do: NewYouWeb.PasswordResetCopy.text!("confirm.action", locale)

  def text!("completed." <> field, locale) when field in ["title", "body"],
    do: NewYouWeb.PasswordResetCopy.text!("confirm.complete." <> field, locale)

  def text!(key, locale) when locale in ["en", "af"],
    do: @copy |> Map.fetch!(key) |> Map.fetch!(locale)
end
