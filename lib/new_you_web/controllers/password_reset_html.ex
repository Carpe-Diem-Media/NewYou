defmodule NewYouWeb.PasswordResetHTML do
  use NewYouWeb, :html
  import NewYouWeb.SignInComponents
  alias NewYouWeb.PasswordResetCopy, as: Copy
  embed_templates "password_reset_html/*"
end
