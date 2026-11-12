defmodule NewYouWeb.DesignSystemInfrastructureTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Mix.Tasks.Design.Check
  alias NewYouWeb.Components.Design.Button
  alias NewYouWeb.Components.Design.Card

  test "lit treatments and raised cards are bounded opt-ins with native semantics" do
    for component <- [&Button.primary_button/1, &Button.secondary_button/1] do
      html =
        render_component(component, %{
          treatment: "lit",
          disabled: true,
          inner_block: [%{inner_block: fn _, _ -> "Continue" end}]
        })

      button = html |> LazyHTML.from_fragment() |> LazyHTML.query("button[data-treatment=lit]")
      assert LazyHTML.attribute(button, "disabled") != []

      assert_raise ArgumentError, ~r/unsupported design button treatment/, fn ->
        render_component(component, %{
          treatment: "glossy",
          inner_block: [%{inner_block: fn _, _ -> "Continue" end}]
        })
      end

      for key <- [:"data-treatment", "data-treatment"] do
        assert_raise ArgumentError, ~r/does not accept caller-provided data-treatment/, fn ->
          render_component(component, %{
            rest: %{key => "lit"},
            inner_block: [%{inner_block: fn _, _ -> "Continue" end}]
          })
        end
      end
    end

    html =
      render_component(&Card.design_card/1, %{
        title: "Raised",
        variant: "raised",
        inner_block: [%{inner_block: fn _, _ -> "Content" end}]
      })

    assert html =~ ~s|data-variant="raised"|
  end

  test "semantic components own bounded variants while preserving native state and metadata" do
    for {component, variant, extra} <- [
          {&Button.primary_button/1, "primary", %{}},
          {&Button.secondary_button/1, "secondary", %{}}
        ],
        disabled <- [false, true] do
      html =
        render_component(
          component,
          Map.merge(extra, %{
            :"aria-busy" => "true",
            :"phx-click" => "save",
            :"data-tracking-id" => "action",
            disabled: disabled,
            type: "submit",
            inner_block: [%{inner_block: fn _, _ -> "Save" end}]
          })
        )

      button = html |> LazyHTML.from_fragment() |> LazyHTML.query("button.ds-design-button")
      assert LazyHTML.attribute(button, "data-variant") == [variant]
      assert LazyHTML.attribute(button, "aria-busy") == ["true"]
      assert LazyHTML.attribute(button, "phx-click") == ["save"]
      assert LazyHTML.attribute(button, "data-tracking-id") == ["action"]
      assert LazyHTML.attribute(button, "disabled") != [] == disabled
      assert LazyHTML.attribute(button, "data-disabled") == []
    end

    html =
      render_component(&Card.design_card/1, %{
        :"aria-label" => "Reference",
        :"data-tracking-id" => "card",
        title: "A card",
        inner_block: [%{inner_block: fn _, _ -> "Content" end}]
      })

    card = html |> LazyHTML.from_fragment() |> LazyHTML.query("article.ds-design-card")
    assert LazyHTML.attribute(card, "data-variant") == ["flat"]
    assert LazyHTML.attribute(card, "aria-label") == ["Reference"]
    assert LazyHTML.attribute(card, "data-tracking-id") == ["card"]
    assert LazyHTML.attribute(card, "role") == []
    assert LazyHTML.attribute(card, "tabindex") == []
  end

  test "callers cannot override controlled variant attributes or classes in forwarded maps" do
    for component <- [&Button.primary_button/1, &Button.secondary_button/1, &Card.design_card/1],
        key <- [:"data-variant", "data-variant", :class, "class"] do
      assert_raise ArgumentError, ~r/does not accept caller-provided/, fn ->
        render_component(component, %{
          title: "A card",
          rest: %{key => "unapproved"},
          inner_block: [%{inner_block: fn _, _ -> "Content" end}]
        })
      end
    end
  end

  test "the card rejects unsupported variants" do
    assert_raise ArgumentError, ~r/unsupported design card variant/, fn ->
      render_component(&Card.design_card/1, %{
        title: "A card",
        variant: "promotional",
        inner_block: [%{inner_block: fn _, _ -> "Content" end}]
      })
    end
  end

  test "attribute-selected utilities retain token and reserved-context enforcement" do
    source =
      ~s|<button class="data-[variant=primary]:bg-design-primary data-[variant=primary]:hover:bg-design-primary-deep"></button>|

    assert [] = Check.violations("lib/new_you_web/components/design/button.ex", source)
    assert [_ | _] = Check.violations("lib/new_you_web/pages/new_page.html.heex", source)

    assert [_ | _] =
             Check.violations(
               "lib/new_you_web/components/design/button.ex",
               ~s|<button class="data-[variant=primary]:bg-red-500"></button>|
             )
  end

  test "identity OKLCH conversion preserves palette authority without accepting color transforms" do
    design = ~s|colors:\n  primary: "#0061ef"\n|

    css = """
    :root { --palette-primary-srgb: #0061ef; --primary: var(--palette-primary-srgb); }
    @supports (color: oklch(from red l c h)) {
      :root { --primary: oklch(from var(--palette-primary-srgb) l c h); }
    }
    @theme static { --color-design-primary: var(--primary); }
    """

    assert [] = Check.token_color_violations(design, css)

    for invalid <- [
          String.replace(css, "#0061ef", "#123456"),
          String.replace(css, "l c h", "calc(l + 0.1) c h"),
          String.replace(css, "l c h", "l c h / 0.5"),
          String.replace(
            css,
            "oklch(from var(--palette-primary-srgb) l c h)",
            "oklch(from var(--missing) l c h)"
          ),
          String.replace(
            css,
            "--palette-primary-srgb: #0061ef",
            "--palette-primary-srgb: var(--primary)"
          )
        ] do
      assert [_ | _] = Check.token_color_violations(design, invalid)
    end
  end

  test "the palette contract resolves shared aliases without accepting unapproved colors" do
    design = ~s|colors:\n  primary: "#0061ef"\n|

    css =
      ":root { --primary: #0061ef; }\n@theme static {\n--color-design-primary: var(--primary);\n}"

    assert [] = Check.token_color_violations(design, css)

    for invalid <- [
          String.replace(css, "#0061ef", "#123456"),
          String.replace(css, "var(--primary)", "var(--missing)"),
          String.replace(css, "#0061ef", "var(--color-design-primary)")
        ] do
      assert [_ | _] = Check.token_color_violations(design, invalid)
    end

    assert [_ | _] =
             Check.token_color_violations(
               design,
               css <> "\n--color-design-surprise: var(--missing);"
             )
  end

  test "CSS can consume declared aliases while unknown references and raw values still fail" do
    path = "assets/css/new-feature.css"

    assert [] =
             Check.violations(
               path,
               ".scope { color: var(--primary); border-radius: var(--radius); box-shadow: var(--box-shadow); }"
             )

    for value <- ["var(--unapproved)", "var(--primary, #123456)", "#0061ef"] do
      assert [_ | _] = Check.violations(path, ".scope { color: #{value}; }")
    end
  end

  test "secondary buttons keep caller semantics without caller-owned visual classes" do
    html =
      render_component(&Button.secondary_button/1, %{
        :"phx-click" => "save",
        :"aria-label" => "Save changes",
        type: "submit",
        disabled: true,
        inner_block: [%{inner_block: fn _, _ -> "Save changes" end}]
      })

    assert html =~ ~s|type="submit"|
    assert html =~ "disabled"
    assert html =~ ~s|phx-click="save"|
    assert html =~ ~s|aria-label="Save changes"|
    assert html =~ "rounded-design-full"

    assert_raise ArgumentError, ~r/does not accept caller-provided classes/, fn ->
      render_component(&Button.secondary_button/1, %{
        class: "bg-red-500",
        inner_block: [%{inner_block: fn _, _ -> "Save" end}]
      })
    end
  end

  test "the main stylesheet imports the executable design token layer" do
    app_css = File.read!(Path.expand("../../assets/css/app.css", __DIR__))
    tokens = File.read!(Path.expand("../../assets/css/design-tokens.css", __DIR__))

    assert app_css =~ ~s|@import "./design-tokens.css";|
    assert tokens =~ "--palette-primary-srgb: #0061ef;"
    assert tokens =~ "--primary: oklch(from var(--palette-primary-srgb) l c h);"
    assert tokens =~ "--palette-primary-hover-srgb: #0000ee;"
    assert tokens =~ "--radius-xl: 32px;"
    assert tokens =~ "--space-md: 12px;"
    assert tokens =~ "--text-display-xl: 64px;"
    assert tokens =~ "--leading-display-xl: 1.05;"
    assert tokens =~ "--breakpoint-design-tablet: 744px;"
    assert tokens =~ "--breakpoint-design-desktop: 1128px;"
    assert tokens =~ "--breakpoint-design-wide: 1441px;"

    design = File.read!(Path.expand("../../DESIGN.md", __DIR__))

    assert [] = Check.token_color_violations(design, tokens)
  end

  test "the enforcement check accepts approved token and layout utilities" do
    source =
      ~s|<button class="inline-flex items-center bg-design-primary text-design-on-primary rounded-design-xl px-design-button-inline hover:bg-design-primary-deep"></button>|

    assert [] = Check.violations("lib/new_you_web/components/design/button.ex", source)
  end

  test "the enforcement check rejects new arbitrary and framework-default design values" do
    source =
      ~s|<div class="bg-[#123456] text-[17px] rounded-[13px] shadow-[0_2px_4px_#000] p-[19px] text-red-500 btn-primary"></div>|

    violations = Check.violations("lib/new_you_web/pages/new_page.html.heex", source)

    assert Enum.any?(violations, &String.contains?(&1, "arbitrary visual utility"))
    assert Enum.any?(violations, &String.contains?(&1, "default Tailwind palette"))
    assert Enum.any?(violations, &String.contains?(&1, "DaisyUI"))

    primary_fills =
      Check.violations(
        "lib/new_you_web/pages/new_page.html.heex",
        ~s|<div class="bg-design-primary bg-design-primary-deep"></div>|
      )

    assert Enum.any?(
             primary_fills,
             &String.contains?(&1, "primary fill is reserved for authorized semantic components")
           )

    assert Enum.any?(primary_fills, &String.contains?(&1, "primary-deep fill is limited"))
  end

  test "the enforcement check scans forbidden classes in multiline HEEx" do
    source = """
    <div
      class={[
        "bg-red-500",
        "rounded-[13px]"
      ]}
    />
    """

    violations = Check.violations("lib/new_you_web/pages/new_page.html.heex", source)

    assert Enum.any?(violations, &String.contains?(&1, "default Tailwind palette"))
    assert Enum.any?(violations, &String.contains?(&1, "arbitrary visual utility"))
    assert Enum.any?(violations, &String.contains?(&1, ":3: default Tailwind palette"))
  end

  test "the enforcement check accepts compliant multiline HEEx" do
    source = """
    <div
      class={[
        "flex",
        "items-center",
        "design-tablet:grid"
      ]}
    />
    """

    assert [] = Check.violations("lib/new_you_web/pages/new_page.html.heex", source)
  end

  test "the enforcement check preserves dynamic class rejection across lines" do
    source = """
    <div
      class={[
        "flex",
        @active && "bg-red-500"
      ]}
    />
    """

    violations = Check.violations("lib/new_you_web/pages/new_page.html.heex", source)

    assert Enum.any?(
             violations,
             &String.contains?(&1, "dynamic classes need a static semantic variant")
           )

    assert Enum.any?(violations, &String.contains?(&1, "default Tailwind palette"))
  end

  test "the class-expression scanner ignores braces inside quoted strings" do
    source = """
    <div
      class={[
        "flex }",
        "rounded-[13px]"
      ]}
    />
    """

    violations = Check.violations("lib/new_you_web/pages/new_page.html.heex", source)

    assert Enum.any?(violations, &String.contains?(&1, "arbitrary visual utility"))
  end

  test "the enforcement check ignores nonvisual data attributes" do
    source = ~s|<div data-class="bg-red-500" data-fill="#abc123" data-style="color: #fff"></div>|

    assert [] = Check.violations("lib/new_you_web/pages/legacy_page.html.heex", source)
  end

  test "the enforcement check tolerates unchanged legacy classes" do
    source = ~s|<div class="bg-red-500 rounded-lg"></div>\n<div class="flex items-center"></div>|

    assert [] =
             Check.new_violations(
               "lib/new_you_web/pages/legacy_page.html.heex",
               source,
               source <> "\n<!-- existing page update -->"
             )

    assert [_violation | _] =
             Check.new_violations(
               "lib/new_you_web/pages/legacy_page.html.heex",
               source,
               source <> "\n<div class=\"bg-red-500\"></div>"
             )

    assert [] =
             Check.new_violations(
               "lib/new_you_web/pages/legacy_page.html.heex",
               source,
               "<section>\n<div class=\"bg-red-500 rounded-lg\"></div>\n<div class=\"flex items-center\"></div>"
             )
  end

  test "the enforcement check rejects framework and arbitrary breakpoints" do
    violations =
      Check.violations(
        "lib/new_you_web/pages/new_page.html.heex",
        ~s|<div class="md:flex min-[700px]:grid"></div>|
      )

    assert Enum.count(violations, &String.contains?(&1, "breakpoint defined by DESIGN.md")) == 2
  end

  test "the enforcement check rejects raw CSS visual values" do
    css =
      ".new-card { color: #abc123; border-radius: 13px; padding: 19px; }\n" <>
        ".new-type { line-height: 1.17; --new-color: #abc123; }"

    violations = Check.violations("assets/css/new-feature.css", css)

    assert Enum.any?(violations, &String.contains?(&1, "raw visual CSS value"))
    assert Enum.any?(violations, &String.contains?(&1, "line-height"))

    assert Enum.any?(
             violations,
             &String.contains?(&1, "new CSS variables require an approved token")
           )

    raw_svg =
      Check.violations("lib/new_you_web/pages/new_page.html.heex", ~s|<svg fill="#abc123"></svg>|)

    assert Enum.any?(raw_svg, &String.contains?(&1, "raw visual CSS value"))

    daisyui_selector =
      Check.violations("assets/css/new-feature.css", ".btn { color: var(--design-ink); }")

    assert Enum.any?(daisyui_selector, &String.contains?(&1, "DaisyUI classes are legacy-only"))

    breakpoint_violations =
      Check.violations("assets/css/new-feature.css", "@media (min-width: 768px) {")

    assert Enum.any?(breakpoint_violations, &String.contains?(&1, "default CSS breakpoint"))

    approved_breakpoint =
      Check.violations(
        "assets/css/new-feature.css",
        "@media (width >= theme(--breakpoint-design-tablet)) {"
      )

    assert approved_breakpoint == []
  end

  test "the enforcement check finds a raw CSS value split across lines" do
    css = """
    .example {
      color:
        #abc123;
    }
    """

    violations = Check.violations("assets/css/new-feature.css", css)

    assert Enum.any?(violations, &String.contains?(&1, "raw visual CSS value"))
    assert Enum.any?(violations, &String.contains?(&1, "#abc123"))
    assert Enum.any?(violations, &String.contains?(&1, "assets/css/new-feature.css:3:"))
  end

  test "changing a grandfathered CSS variable value is a new design violation" do
    baseline = ".legacy { --new-color: #111111; }"
    current = ".legacy { --new-color: #222222; }"

    violations =
      Check.new_violations("assets/css/legacy.css", baseline, current)

    assert Enum.any?(
             violations,
             &String.contains?(&1, "new CSS variables require an approved token")
           )
  end

  test "changing a grandfathered inline style value is a new design violation" do
    baseline = ~s|<div style="color: #111111"></div>|
    current = ~s|<div style="color: #222222"></div>|

    violations = Check.new_violations("lib/new_you_web/pages/legacy.heex", baseline, current)

    assert Enum.any?(
             violations,
             &String.contains?(&1, "inline visual styles bypass project tokens")
           )
  end

  test "the enforcement check scans multiline JavaScript class and style assignments" do
    js = """
    element.classList.add(
      "bg-red-500"
    )
    element.style.color =
      "#abc123";
    """

    violations = Check.violations("assets/js/new-feature.js", js)

    assert Enum.any?(violations, &String.contains?(&1, "default Tailwind palette"))

    assert Enum.any?(
             violations,
             &String.contains?(&1, "inline visual styles bypass project tokens")
           )
  end

  test "primary surface fill is limited to authorized semantic component paths" do
    feature =
      Check.violations(
        "lib/new_you_web/pages/new_page.html.heex",
        ~s|<section class="bg-design-primary"></section>|
      )

    assert Enum.any?(
             feature,
             &String.contains?(&1, "primary fill is reserved for authorized semantic components")
           )

    cta =
      Check.violations(
        "lib/new_you_web/components/design/button.ex",
        ~s|<button class="bg-design-primary"></button>|
      )

    assert cta == []

    enterprise_band =
      Check.violations(
        "lib/new_you_web/components/design/enterprise_band.ex",
        ~s|<section class="bg-design-primary"></section>|
      )

    assert enterprise_band == []
  end

  test "the token contract rejects values that diverge from DESIGN.md" do
    design = File.read!(Path.expand("../../DESIGN.md", __DIR__))
    tokens = File.read!(Path.expand("../../assets/css/design-tokens.css", __DIR__))

    changed_tokens =
      String.replace(
        tokens,
        "--palette-primary-srgb: #0061ef;",
        "--palette-primary-srgb: #123456;"
      )

    assert [_violation | _] = Check.token_color_violations(design, changed_tokens)

    assert [_violation | _] = Check.token_authority_violations(false, true)
  end

  test "the primary button renders approved tokens and preserves semantics and bindings" do
    html =
      render_primary_button(%{
        :"aria-label" => "Continue",
        :"phx-click" => "save",
        type: "submit",
        disabled: true
      })

    assert html =~ "<button"
    assert html =~ "type=\"submit\""
    assert html =~ "disabled"
    assert html =~ "aria-label=\"Continue\""
    assert html =~ "phx-click=\"save\""
    assert html =~ "bg-design-primary"
    assert html =~ "hover:bg-design-primary-deep"
    assert html =~ "focus-visible:outline-design-primary"
    assert html =~ "focus-visible:outline-offset-2"
    assert html =~ "Continue"
  end

  test "the primary button rejects unsupported variants and caller styling" do
    assert_raise ArgumentError, ~r/unsupported design button variant/, fn ->
      render_primary_button(%{variant: "secondary"})
    end

    assert_raise ArgumentError, ~r/does not accept caller-provided classes/, fn ->
      render_primary_button(%{class: "bg-red-500"})
    end
  end

  defp render_primary_button(extra_assigns) do
    component = &Button.primary_button/1

    render_component(
      component,
      Map.merge(
        %{
          variant: "primary",
          type: "button",
          disabled: false,
          inner_block: [%{inner_block: fn _, _ -> "Continue" end}]
        },
        extra_assigns
      )
    )
  end
end
