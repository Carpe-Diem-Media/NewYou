defmodule NewYouWeb.MagicLoginCopy do
  @moduledoc """
  Low-risk browser copy for the bounded P8-09 development login flow.
  """

  @copy %{
    "request.title" => %{
      "en" => "Sign in with an email link",
      "af" => "Meld aan met ’n e-posskakel"
    },
    "request.body" => %{
      "en" => "Enter your email address and we’ll send a sign-in link if it can be used.",
      "af" => "Voer jou e-posadres in. Ons stuur ’n aanmeldskakel as dit gebruik kan word."
    },
    "request.action" => %{"en" => "Send sign-in link", "af" => "Stuur aanmeldskakel"},
    "request.accepted.title" => %{"en" => "Check your email", "af" => "Gaan jou e-pos na"},
    "request.accepted.body" => %{
      "en" =>
        "If the address can receive a sign-in link, it will arrive shortly. You can close this page.",
      "af" =>
        "As die adres ’n aanmeldskakel kan ontvang, sal dit binnekort aankom. Jy kan hierdie bladsy toemaak."
    },
    "confirm.title" => %{"en" => "Confirm sign-in", "af" => "Bevestig aanmelding"},
    "confirm.body" => %{
      "en" => "Continue only if you asked for this link. This will sign you in to your account.",
      "af" =>
        "Gaan net voort as jy hierdie skakel aangevra het. Jy sal by jou rekening aangemeld word."
    },
    "confirm.action" => %{"en" => "Confirm and sign in", "af" => "Bevestig en meld aan"},
    "confirm.unavailable.title" => %{
      "en" => "This sign-in link is unavailable",
      "af" => "Hierdie aanmeldskakel is nie beskikbaar nie"
    },
    "confirm.unavailable.body" => %{
      "en" => "The link may have expired or already been used. Request a new one to continue.",
      "af" =>
        "Die skakel het dalk verval of is reeds gebruik. Vra ’n nuwe skakel aan om voort te gaan."
    }
  }

  @spec text!(String.t(), String.t()) :: String.t()
  def text!(key, locale) when locale in ["en", "af"],
    do: @copy |> Map.fetch!(key) |> Map.fetch!(locale)
end
