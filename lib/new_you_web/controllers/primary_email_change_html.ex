defmodule NewYouWeb.PrimaryEmailChangeHTML do
  use NewYouWeb, :html
  import NewYouWeb.SignInComponents
  alias NewYouWeb.CopyRegistry
  embed_templates "primary_email_change_html/*"

  def text(copy, key), do: Map.fetch!(copy, "identity.change_email." <> key)

  def heading(:unavailable, _state), do: "uncertain.title"
  def heading(:applied, _state), do: "applied.title"
  def heading(:signed_out, _state), do: "uncertain.title"
  def heading(:status, :new_address_pending), do: "pending.title"
  def heading(:status, :confirmed), do: "confirmed.title"
  def heading(:status, state) when state in [:delayed, :reviewed], do: "review.title"
  def heading(:status, :applied), do: "applied.title"
  def heading(:status, :cancelled), do: "cancelled.title"

  def heading(:status, state) when state in [:expired, :held, :rejected, :superseded],
    do: "uncertain.title"

  def heading(:status, _state), do: "start.title"

  def body(:unavailable, _state), do: "uncertain.body"
  def body(:signed_out, _state), do: "uncertain.body"
  def body(:applied, _state), do: "applied.body"
  def body(:status, :requested), do: "request.neutral"
  def body(:status, :cancelled), do: nil
  def body(:status, :expired), do: "start.body"
  def body(:status, state), do: String.replace_suffix(heading(:status, state), ".title", ".body")

  def error_key(:request), do: "request.neutral"
  def error_key(_), do: "uncertain.title"

  # The email-change packet has no input or step labels for these controls.
  # These JIT labels describe the control without adding an outcome claim.
  @form_labels %{
    password: %{"en" => "Current password", "af" => "Huidige wagwoord"},
    code: %{"en" => "Code from your verification app", "af" => "Kode uit jou verifikasietoep"},
    reauthenticate: %{"en" => "Confirm your identity", "af" => "Bevestig jou identiteit"},
    review: %{"en" => "Complete security check", "af" => "Voltooi sekuriteitskontrole"},
    apply: %{"en" => "Apply email change", "af" => "Pas e-posverandering toe"}
  }

  def form_label(key, locale), do: @form_labels |> Map.fetch!(key) |> Map.fetch!(locale)

  def advance_label(%{state: :requested}), do: :reauthenticate
  def advance_label(%{state: :delayed, requires_review?: true}), do: :review
  def advance_label(_), do: :apply

  def open_request?(state),
    do: state in [:none, :applied, :cancelled, :expired, :rejected, :superseded]

  def cancellable?(state),
    do:
      state in [
        :requested,
        :reauthenticated,
        :new_address_pending,
        :confirmed,
        :delayed,
        :reviewed
      ]

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
