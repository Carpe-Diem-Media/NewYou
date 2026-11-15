defmodule NewYouWeb.DesignSystemLiveTest do
  use NewYouWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "the guide renders all requested foundations and semantic examples", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dev/design-system")

    for section <-
          ~w(palette typography spacing buttons cards layout relationships surfaces lighting fluid shape) do
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

    assert has_element?(view, "#buttons button[data-variant=primary][data-treatment=lit]")
    assert has_element?(view, "#buttons button[data-variant=secondary][data-treatment=lit]")
    assert has_element?(view, "#card-grid article[data-variant=flat]")
    assert has_element?(view, "#lighting button[data-treatment=lit][data-variant=primary]")
    assert has_element?(view, "#lighting button[data-treatment=lit][data-variant=secondary]")
    assert has_element?(view, "#lighting article[data-variant=raised]")
    assert has_element?(view, "#lighting button[data-treatment=lit][disabled]")
    assert has_element?(view, "#buttons button[data-treatment=lit][disabled]", "Unavailable")
    assert has_element?(view, "button[disabled] .hero-lock-closed[aria-hidden='true']")
    assert has_element?(view, "#token-status[role='status']")
    assert has_element?(view, "#design-system[phx-hook='DesignSystem']")
  end

  test "component contract specimens use shared components and native states", %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/design-system")
    assert has_element?(view, "section#contracts")
    assert has_element?(view, "nav a[href='#contracts']")
    assert has_element?(view, "#contract-card-default > .ds-design-card-inset")

    assert has_element?(
             view,
             "#contract-card-local[data-variant=raised] > .ds-design-card-actions a[href='#shape']"
           )

    assert has_element?(view, "#contract-icon-named[role=img][aria-label='Saved']")

    assert has_element?(
             view,
             "#contract-icon-action[aria-label='Refresh specimens'] .ds-design-icon[aria-hidden=true]"
           )

    assert has_element?(view, "#contract-busy[aria-busy=true][disabled]")
    assert has_element?(view, "#contract-field-default.ds-design-field-input[type=text]")

    assert has_element?(
             view,
             "#contract-field-error[aria-invalid=true][aria-describedby=contract-field-error-error]"
           )

    assert has_element?(view, "#contract-field-error-error[role=alert]")
    refute has_element?(view, "#contracts article[tabindex]")
    refute has_element?(view, "#contracts [data-disabled], #contracts [data-loading]")
    {:ok, preview, _} = live(conn, "/dev/design-system/preview")
    refute has_element?(preview, "#contracts")
  end

  test "content recipes use semantic prose, separators and live token references", %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/design-system")
    assert has_element?(view, "nav a[href='#content']", "Content")
    assert has_element?(view, "section#content")

    for locale <- ~w(en af) do
      assert has_element?(view, "article#prose-#{locale}.ds-prose[lang=#{locale}]")
      assert has_element?(view, "#prose-#{locale} ul li ul li")
      assert has_element?(view, "#prose-#{locale} blockquote")
      assert has_element?(view, "#prose-#{locale} a[href='#content']")
    end

    assert has_element?(view, "hr#content-divider.ds-divider")
    assert has_element?(view, "#content-divided.ds-divided > div")

    for role <- ~w(content-gap section-space control-gap) do
      assert has_element?(view, "#content output[data-token='--#{role}']")
    end

    {:ok, preview, _} = live(conn, "/dev/design-system/preview")
    refute has_element?(preview, "#content")
  end

  test "content specimens include card roles, native figures and explicit nested prose", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/dev/design-system")

    for role <- ~w(card-content-gap card-action-gap) do
      assert has_element?(view, "#content output[data-token='--#{role}']")
    end

    for locale <- ~w(en af) do
      assert has_element?(view, "#prose-#{locale} figure > blockquote")
      assert has_element?(view, "#prose-#{locale} figure > figcaption")
      assert has_element?(view, "#prose-#{locale} .ds-prose > p + p")
    end

    for scope <- ~w(default local) do
      assert has_element?(view, "#content-card-#{scope}.ds-design-card")
      assert has_element?(view, "#content-card-#{scope} .ds-design-card-actions > a")
    end

    {:ok, preview, _} = live(conn, "/dev/design-system/preview")
    refute has_element?(preview, "#content-card-default")
    refute has_element?(preview, "#prose-en")
  end

  test "modular typography candidates expose scale math and semantic comparisons without adoption",
       %{conn: conn} do
    {:ok, view, _} = live(conn, "/dev/design-system")
    assert has_element?(view, "nav a[href='#type-scale']", "Type scaling")
    assert has_element?(view, "section#type-scale[data-status=candidate]")

    for family <- ~w(body heading), step <- ~w(xs s m l xl xxl) do
      for edge <- ~w(min current max) do
        id = "scale-#{family}-#{step}-#{edge}"
        assert has_element?(view, "##{id}.ds-scale-probe[aria-hidden=true]")

        assert has_element?(
                 view,
                 "output[data-measure-target='#{id}'][data-measure-property=font-size]"
               )
      end
    end

    for role <-
          ~w(display-xl display-lg display-md display-sm heading-md heading-sm body-lg body-md body-sm body-xs button-md caption) do
      assert has_element?(view, "#type-scale [data-role='#{role}'] .ds-scale-current")
      assert has_element?(view, "#type-scale [data-role='#{role}'] .ds-scale-candidate")
    end

    for locale <- ~w(en af) do
      assert has_element?(view, "article#type-reading-#{locale}.ds-prose[lang=#{locale}]")
      assert has_element?(view, "#type-reading-#{locale} ul li ul li")
    end

    assert has_element?(view, "#type-scale-local.ds-type-scope")
    refute has_element?(view, "#type-scale form, #type-scale input")
    {:ok, preview, _} = live(conn, "/dev/design-system/preview")
    refute has_element?(preview, "#type-scale")
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

    assert has_element?(
             preview,
             "button.ds-design-button[data-variant=primary][data-treatment=lit]"
           )

    assert has_element?(
             preview,
             "button.ds-design-button[data-variant=secondary][data-treatment=lit]"
           )

    refute has_element?(preview, "nav[aria-label='Design system sections']")
    refute has_element?(preview, "iframe")
  end

  test "layout foundations render candidate recipes and bounded allocation controls", %{
    conn: conn
  } do
    {:ok, view, _html} =
      live(conn, "/dev/design-system?count=7&alignment=center&allocation=narrow")

    assert has_element?(view, "#layout-lab[data-allocation=narrow]")
    assert has_element?(view, "#layout-allocation option[value=narrow][selected]")
    assert has_element?(view, "#layout-fixed[data-alignment=center] > :nth-child(7)")
    assert has_element?(view, "#layout-auto-fit > :nth-child(7)")
    assert has_element?(view, "#layout-auto-fill > :nth-child(7)")
    assert has_element?(view, "#layout-container .ds-layout-nested")

    for zone <- ~w(content feature feature-max full full-safe) do
      assert has_element?(view, "#layout-breakout > [data-zone='#{zone}']")
    end

    assert has_element?(view, "#layout-lab", "Candidate")
    assert has_element?(view, "#layout-lab [data-measure-target=layout-auto-fit]")

    view
    |> form("#layout-controls", %{
      "layout" => %{"count" => "4", "alignment" => "start", "allocation" => "full"}
    })
    |> render_change()

    assert_patch(view, "/dev/design-system?alignment=start&count=4&viewport=auto")
    assert has_element?(view, "#layout-lab[data-allocation=full]")
    refute has_element?(view, "#layout-auto-fit > :nth-child(5)")
  end

  test "allocation survives guide patches and malformed layout inputs stay bounded", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dev/design-system?allocation=narrow")
    render_click(view, "viewport", %{"viewport" => "phone"})

    assert_patch(
      view,
      "/dev/design-system?alignment=start&allocation=narrow&count=5&viewport=phone"
    )

    assert has_element?(view, "#layout-lab[data-allocation=narrow]")

    render_change(view, "layout", %{
      "layout" => %{"allocation" => %{}, "count" => ["9"], "alignment" => "bad"}
    })

    assert_patch(view, "/dev/design-system?alignment=start&count=5&viewport=phone")
    assert has_element?(view, "#layout-lab[data-allocation=full]")
    render_change(view, "layout", %{"layout" => "bad"})
    render_change(view, "layout", %{})
    assert has_element?(view, "#layout-lab[data-allocation=full]")

    {:ok, invalid, _html} = live(conn, "/dev/design-system?allocation=external")
    assert has_element?(invalid, "#layout-lab[data-allocation=full]")
    {:ok, preview, _html} = live(conn, "/dev/design-system/preview")
    refute has_element?(preview, "#layout-lab")
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
