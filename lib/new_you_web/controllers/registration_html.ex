defmodule NewYouWeb.RegistrationHTML do
  use NewYouWeb, :html

  alias NewYouWeb.CopyRegistry

  embed_templates "registration_html/*"

  def copy(key, locale) do
    CopyRegistry.text!(key, locale, %{"platform_name" => NewYou.platform_name()})
  end
end
