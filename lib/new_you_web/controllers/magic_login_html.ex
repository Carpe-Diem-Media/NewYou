defmodule NewYouWeb.MagicLoginHTML do
  use NewYouWeb, :html
  import NewYouWeb.SignInComponents
  alias NewYouWeb.SignInCopy, as: Copy
  embed_templates "magic_login_html/*"
end
