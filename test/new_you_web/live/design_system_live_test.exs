defmodule NewYouWeb.DesignSystemLiveTest do
  use NewYouWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "the guide renders all requested foundations and semantic examples", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dev/design-system")

    for section <-
          ~w(palette typography spacing buttons cards layout relationships surfaces fluid shape) do
      assert has_element?(view, "section##{section}")
      assert has_element?(view, "nav a[href='##{section}']")
    end

    assert has_element?(view, "h1", "Design system")
    assert has_element?(view, "[data-token='--primary']")
    assert has_element?(view, "[data-token='--secondary']")
    assert has_element?(view, "[data-token='--radius']")
    assert has_element?(view, "[data-token='--box-shadow']")

    assert has_element?(
             view,
             "#surfaces .ds-treatment[data-treatment='gradient'][aria-hidden='true']"
           )

    assert has_element?(
             view,
             "#surfaces .ds-treatment[data-treatment='noise'][aria-hidden='true']"
           )

    assert has_element?(
             view,
             "#surfaces .ds-treatment[data-treatment='overlay'][aria-hidden='true']"
           )

    assert has_element?(view, "#surfaces [data-pair='tint'][data-contrast-sample]")
    assert has_element?(view, "#fluid .ds-fluid-display#fluid-display")
    assert has_element?(view, "#fluid .ds-fluid-body#fluid-body")
    assert has_element?(view, "#fluid .ds-fluid-space#fluid-space")
    assert has_element?(view, "#fluid .ds-fluid-gutter#fluid-gutter")

    assert has_element?(
             view,
             "#fluid [data-measure-target='fluid-display'][data-measure-property='font-size']"
           )

    assert has_element?(view, "#fluid [data-fluid-value='display-min']")

    for kind <- ~w(display body space gutter), edge <- ~w(min max) do
      target = "fluid-#{kind}-#{edge}"

      assert has_element?(
               view,
               "#fluid span##{target}[data-bound='#{kind}-#{edge}'][aria-hidden='true']"
             )

      assert has_element?(
               view,
               "#fluid output[data-measure-target='#{target}'][data-measure-property='font-size']"
             )
    end

    assert has_element?(view, "button[disabled]", "Unavailable")
    assert has_element?(view, "button[disabled] .hero-lock-closed[aria-hidden='true']")
    assert has_element?(view, "#token-status[role='status']")
    assert has_element?(view, "#design-system[phx-hook='DesignSystem']")
  end

  test "grid choices are bounded and survive reload through query parameters", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dev/design-system")

    view
    |> form("#grid-controls", %{"grid" => %{"count" => "4", "alignment" => "center"}})
    |> render_change()

    assert_patch(view, "/dev/design-system?alignment=center&count=4&viewport=auto")
    assert has_element?(view, "#card-grid[data-alignment='center']")
    assert view |> element("#card-grid") |> render() |> count_articles() == 4

    {:ok, reloaded, _html} = live(conn, "/dev/design-system?alignment=center&count=4")
    assert has_element?(reloaded, "#grid-count option[value='4'][selected]")
    assert reloaded |> element("#card-grid") |> render() |> count_articles() == 4
  end

  test "invalid display parameters fall back without crashing", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, "/dev/design-system?count=999999&alignment=unsafe&viewport=external")

    assert has_element?(view, "#grid-count option[value='5'][selected]")
    assert has_element?(view, "#card-grid[data-alignment='start']")
    assert has_element?(view, "#responsive-preview[data-viewport='auto']")

    render_change(view, "grid", %{"grid" => %{"count" => %{}, "alignment" => ["center"]}})
    assert has_element?(view, "#grid-count option[value='5'][selected]")
  end

  test "preview uses the same app components in an isolated real viewport", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dev/design-system?viewport=phone")

    assert has_element?(view, "#responsive-preview[data-viewport='phone']")
    assert has_element?(view, "iframe[title='Responsive component preview']")

    {:ok, preview, _html} = live(conn, "/dev/design-system/preview")
    assert has_element?(preview, "#preview-content")
    assert has_element?(preview, "button.bg-design-primary")
    refute has_element?(preview, "nav[aria-label='Design system sections']")
    refute has_element?(preview, "iframe")
  end

  test "the production router excludes both guide routes" do
    source = File.read!("lib/new_you_web/router.ex")

    ast =
      source
      |> Code.string_to_quoted!()
      |> Macro.prewalk(fn
        {:defmodule, meta, [_name, body]} ->
          {:defmodule, meta, [NewYouWeb.DesignSystemProductionRouter, body]}

        {{:., _, [{:__aliases__, _, [:Mix]}, :env]}, _, []} ->
          :prod

        node ->
          node
      end)

    Code.compile_quoted(ast)

    refute Enum.any?(Phoenix.Router.routes(NewYouWeb.DesignSystemProductionRouter), fn route ->
             String.starts_with?(route.path, "/dev/design-system")
           end)
  end

  defp count_articles(html), do: length(Regex.scan(~r/<article\b/, html))
end
