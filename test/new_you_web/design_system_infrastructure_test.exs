defmodule NewYouWeb.DesignSystemInfrastructureTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Mix.Tasks.Design.Check
  alias NewYouWeb.Components.Design.Button

  test "the main stylesheet imports the executable design token layer" do
    app_css = File.read!(Path.expand("../../assets/css/app.css", __DIR__))
    tokens = File.read!(Path.expand("../../assets/css/design-tokens.css", __DIR__))

    assert app_css =~ ~s|@import "./design-tokens.css";|
    assert tokens =~ "--color-design-primary: #0061ef;"
    assert tokens =~ "--color-design-primary-deep: #0000ee;"
    assert tokens =~ "--radius-design-xl: 32px;"
    assert tokens =~ "--spacing-design-md: 12px;"
    assert tokens =~ "--text-design-display-xl: 64px;"
    assert tokens =~ "--leading-design-display-xl: 1.05;"
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
        "--color-design-primary: #0061ef;",
        "--color-design-primary: #123456;"
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
