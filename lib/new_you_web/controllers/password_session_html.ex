defmodule NewYouWeb.PasswordSessionHTML do
  use NewYouWeb, :html
  import NewYouWeb.SignInComponents
  import NewYouWeb.Components.Design.Button, only: [primary_button: 1, secondary_button: 1]
  alias NewYouWeb.SignInCopy, as: Copy
  embed_templates "password_session_html/*"

  # Mechanical JIT labels for the ticket's bounded development display.
  def member_reference_copy("en") do
    %{
      label: "Platform Member Reference",
      action: "Copy reference",
      copied: "Reference copied.",
      unavailable: "Clipboard unavailable. Select the reference to copy it."
    }
  end

  def member_reference_copy("af") do
    %{
      label: "Platformlidverwysing",
      action: "Kopieer verwysing",
      copied: "Verwysing gekopieer.",
      unavailable: "Knipbord nie beskikbaar nie. Kies die verwysing om dit te kopieer."
    }
  end
end
