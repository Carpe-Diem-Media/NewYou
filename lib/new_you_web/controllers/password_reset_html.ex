defmodule NewYouWeb.PasswordResetHTML do
  use NewYouWeb, :html
  import NewYouWeb.SignInComponents
  alias NewYouWeb.PasswordResetCopy, as: Copy
  embed_templates "password_reset_html/*"
  embed_templates "password_reset_historical_html/*", suffix: "_p8_12"
end
