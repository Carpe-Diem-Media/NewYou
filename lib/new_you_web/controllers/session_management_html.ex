defmodule NewYouWeb.SessionManagementHTML do
  @moduledoc false
  use NewYouWeb, :html
  import NewYouWeb.SignInComponents

  embed_templates "session_management_html/*"

  def device_text(copy, key), do: Map.fetch!(copy, "identity.trusted_devices." <> key)

  def text(copy, key), do: Map.fetch!(copy, "identity.sessions." <> key)
end
