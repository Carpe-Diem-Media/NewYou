defmodule NewYouWeb.PasswordSessionHTML do
  use NewYouWeb, :html
  import NewYouWeb.SignInComponents
  alias NewYouWeb.SignInCopy, as: Copy
  embed_templates "password_session_html/*"
end
