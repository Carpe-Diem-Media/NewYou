defmodule NewYouWeb.RegistrationController do
  use NewYouWeb, :controller

  @locales ~w(en af)

  def new(conn, %{"locale" => locale}) when locale in @locales do
    if development_fixture_enabled?() do
      render(conn, :new, locale: locale, operation_id: Ecto.UUID.generate())
    else
      not_found(conn)
    end
  end

  def new(conn, _params) do
    if development_fixture_enabled?() do
      render(conn, :choose_language)
    else
      not_found(conn)
    end
  end

  defp development_fixture_enabled? do
    Application.get_env(:new_you, :p8_05_browser_development_fixtures, false) == true
  end

  defp not_found(conn), do: send_resp(conn, 404, "Not Found")
end
