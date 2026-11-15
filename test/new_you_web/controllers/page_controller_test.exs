defmodule NewYouWeb.PageControllerTest do
  use NewYouWeb.ConnCase

  alias NewYouWeb.CopyRegistry

  setup do
    keys = [:fp001_development_entry, :p8_05_browser_development_fixtures]
    previous = Map.new(keys, &{&1, Application.fetch_env(:new_you, &1)})
    Application.put_env(:new_you, :fp001_development_entry, true)
    Application.put_env(:new_you, :p8_05_browser_development_fixtures, false)

    on_exit(fn ->
      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:new_you, key, value)
        {key, :error} -> Application.delete_env(:new_you, key)
      end)
    end)

    :ok
  end

  test "normal entry presents the existing bilingual journey without proof browser flags" do
    for locale <- ~w(en af) do
      html = build_conn() |> get("/?locale=#{locale}") |> html_response(200)

      assert html =~ ~s(lang="#{locale}")
      assert text_nodes(html) |> Enum.member?(rendered_copy("public.entry.launch.title", locale))
      assert text_nodes(html) |> Enum.member?(rendered_copy("public.entry.safety.body", locale))
      assert html =~ ~s(action="/register")
      assert html =~ ~s(href="/register?locale=af")
      assert html =~ ~s(href="/register?locale=en")
      refute html =~ "Peace of mind from prototype to production"
    end
  end

  test "normal entry rejects unsupported locales and disabled development access" do
    assert build_conn() |> get("/?locale=fr") |> response(404) == ""
    Application.put_env(:new_you, :fp001_development_entry, false)
    assert build_conn() |> get("/") |> response(404) == ""
  end

  test "unapproved registry entries cannot be consumed through the web copy reader" do
    assert_raise KeyError, fn -> CopyRegistry.text!("shared.navigation.home", "en") end
  end

  test "normal entry is not cacheable or exposed through endpoint telemetry" do
    parent = self()
    handler = "well131-entry-#{System.unique_integer([:positive])}"
    marker = "private-entry-#{Ecto.UUID.generate()}@example.test"

    :ok =
      :telemetry.attach_many(
        handler,
        [[:phoenix, :endpoint, :start], [:phoenix, :endpoint, :stop]],
        fn event, _, metadata, _ -> send(parent, {:entry_telemetry, event, metadata}) end,
        nil
      )

    try do
      conn = get(build_conn(), "/?" <> URI.encode_query(%{locale: "af", email: marker}))
      assert conn.status == 200
      assert get_resp_header(conn, "cache-control") == ["no-store"]
      assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]

      for _ <- 1..2 do
        assert_receive {:entry_telemetry, _event, metadata}
        refute inspect(metadata) =~ marker
      end
    after
      :telemetry.detach(handler)
    end
  end

  defp text_nodes(html) do
    Regex.scan(~r/>([^<>]*)</s, html, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.trim/1)
  end

  defp rendered_copy(key, locale) do
    key
    |> CopyRegistry.text!(locale, %{"platform_name" => NewYou.platform_name()})
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
