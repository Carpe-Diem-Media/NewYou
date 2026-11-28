defmodule NewYouWeb.SupportLookupHTML do
  @moduledoc false
  use NewYouWeb, :html
  import NewYouWeb.SignInComponents, only: [auth_shell: 1]

  embed_templates "support_lookup_html/*"
end
