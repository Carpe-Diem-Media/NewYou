defmodule NewYouWeb.PrimaryEmailChangeHTML do
  use NewYouWeb, :html
  embed_templates "primary_email_change_html/*"

  def copy(:confirm, :title, "en"), do: "Confirm your new email address"

  def copy(:confirm, :body, "en"),
    do:
      "Confirm that you can access this address. Your current email stays in place until the change is applied."

  def copy(:confirm, :action, "en"), do: "Confirm new email"
  def copy(:confirmed, :title, "en"), do: "New email address confirmed"

  def copy(:confirmed, :body, "en"),
    do: "Your current email remains active until the account change is applied."

  def copy(:unavailable, :title, "en"), do: "This confirmation is unavailable"

  def copy(:unavailable, :body, "en"),
    do: "The link may have expired or been replaced. Sign in to start a new email change."

  def copy(:confirm, :title, "af"), do: "Bevestig jou nuwe e-posadres"

  def copy(:confirm, :body, "af"),
    do:
      "Bevestig dat jy toegang tot hierdie adres het. Jou huidige e-posadres bly aktief totdat die verandering toegepas word."

  def copy(:confirm, :action, "af"), do: "Bevestig nuwe e-posadres"
  def copy(:confirmed, :title, "af"), do: "Nuwe e-posadres bevestig"

  def copy(:confirmed, :body, "af"),
    do: "Jou huidige e-posadres bly aktief totdat die rekeningverandering toegepas word."

  def copy(:unavailable, :title, "af"), do: "Hierdie bevestiging is nie beskikbaar nie"

  def copy(:unavailable, :body, "af"),
    do: "Die skakel het dalk verval of is vervang. Meld aan om 'n nuwe e-posverandering te begin."
end
