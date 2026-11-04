defmodule NewYouWeb.Security.RequestRenderingTest do
  use NewYouWeb.ConnCase

  setup do
    previous = Application.get_env(:new_you, :p8_05_browser_development_fixtures)
    Application.put_env(:new_you, :p8_05_browser_development_fixtures, true)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:new_you, :p8_05_browser_development_fixtures)
      else
        Application.put_env(:new_you, :p8_05_browser_development_fixtures, previous)
      end
    end)
  end

  test "request keys never become HTML names, while retained form values remain escaped" do
    hostile = ~s|" onmouseover="alert(72)"><script id="well72">&|
    keys = ["onmouseover", "x onmouseover", "x\" onclick", "rest", "attrs", "data", "aria", "phx"]
    injected = Map.new(keys, &{&1, %{"x onmouseover" => "well72-injected"}})

    for locale <- ["en", "af"] do
      params = Map.merge(injected, %{"preferred_language" => locale, "first_name" => hostile})

      # Missing required fields selects the actual validation/rerender path without business writes.
      conn = post(build_conn(), "/register", Map.put(injected, "registration", params))
      html = html_response(conn, 200)

      assert conn.assigns.values == %{"first_name" => hostile, "preferred_language" => locale}
      assert html =~ "&quot; onmouseover=&quot;alert(72)&quot;&gt;&lt;script"
      refute html =~ "well72-injected"
      refute html =~ ~s(<script id="well72")
      refute html =~ ~r/\sonmouseover="/
      refute html =~ ~r/\sonclick="/
      assert html =~ ~s(name="registration[first_name]")
    end
  end

  test "home and registration ignore query attribute maps" do
    for path <- ["/", "/register"] do
      html =
        build_conn()
        |> get(path, %{"rest" => %{"x onmouseover" => "well72-injected"}, "locale" => "en"})
        |> html_response(200)

      refute html =~ "well72-injected"
      refute html =~ ~r/\sonmouseover="/
    end
  end
end
