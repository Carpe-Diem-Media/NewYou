defmodule NewYouWeb.EmailVerificationHTML do
  use NewYouWeb, :html
  embed_templates "email_verification_html/*"

  def copy(state, part, locale),
    do: NewYouWeb.VerificationCopy.text!("identity.verification.result.#{state}.#{part}", locale)
end
