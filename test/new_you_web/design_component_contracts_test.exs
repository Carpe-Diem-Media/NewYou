defmodule NewYouWeb.DesignComponentContractsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias NewYouWeb.Components.Design.{Card, Icon, Link}

  defp content(text), do: [%{inner_block: fn _, _ -> text end}]

  test "card layout owns contextual content spacing and an independently wrapping action row" do
    html =
      render_component(&Card.design_card/1, %{
        title: "Spacing contract",
        inner_block: content("Body"),
        actions: content("Actions")
      })

    dom = LazyHTML.from_fragment(html)
    assert LazyHTML.query(dom, "article.gap-design-card-content") |> Enum.any?()
    refute LazyHTML.query(dom, "article.gap-design-base") |> Enum.any?()
    assert LazyHTML.query(dom, "article > .ds-design-card-actions") |> Enum.any?()
  end

  test "card slots retain a noninteractive article and a configurable heading" do
    for level <- 2..6 do
      html =
        render_component(&Card.design_card/1, %{
          :"data-tracking-id" => "card",
          :"phx-hook" => "CardTelemetry",
          title: "Details",
          heading_level: level,
          leading: content("Icon"),
          inset: content("Inset"),
          actions: content("Actions"),
          inner_block: content("Body"),
          id: "card"
        })

      card = LazyHTML.from_fragment(html)

      assert LazyHTML.query(card, "article > h#{level}") |> LazyHTML.text() |> String.trim() ==
               "Details"

      for part <- ~w(leading inset body actions) do
        assert LazyHTML.query(card, "article > .ds-design-card-#{part}") |> LazyHTML.text() != ""
      end

      assert html =~ ~s|data-tracking-id="card"|
      assert html =~ ~s|phx-hook="CardTelemetry"|
      refute html =~ "tabindex="
    end
  end

  test "cards omit empty optional regions and retain the default heading" do
    html = render_component(&Card.design_card/1, %{title: "Card", inner_block: content("Body")})
    dom = LazyHTML.from_fragment(html)
    assert LazyHTML.query(dom, "article > h3") |> LazyHTML.text() |> String.trim() == "Card"

    for part <- ~w(leading inset actions) do
      assert LazyHTML.query(dom, ".ds-design-card-#{part}") |> LazyHTML.to_html() == ""
    end
  end

  test "card rejects invalid heading and interactive or visual root overrides" do
    for level <- [1, 7, "3", nil] do
      assert_raise ArgumentError, ~r/heading_level/, fn ->
        render_component(&Card.design_card/1, %{
          title: "Card",
          heading_level: level,
          inner_block: content("Body")
        })
      end
    end

    for key <-
          ~w(class style data-variant role tabindex onclick onkeydown onkeyup phx-click phx-capture-click phx-keydown phx-keyup) do
      for key <- [key, String.to_atom(key)] do
        assert_raise ArgumentError, ~r/does not accept caller-provided/, fn ->
          render_component(&Card.design_card/1, %{
            title: "Card",
            rest: %{key => "override"},
            inner_block: content("Body")
          })
        end
      end
    end
  end

  test "icon owns finite presentation variants and decorative versus named semantics" do
    for size <- ~w(sm md lg), treatment <- ~w(plain boxed) do
      html =
        render_component(&Icon.design_icon/1, %{
          :"data-tracking-id" => "icon",
          name: "hero-heart",
          size: size,
          treatment: treatment
        })

      icon = html |> LazyHTML.from_fragment() |> LazyHTML.query(".ds-design-icon")
      assert LazyHTML.attribute(icon, "aria-hidden") == ["true"]
      assert LazyHTML.attribute(icon, "data-size") == [size]
      assert LazyHTML.attribute(icon, "data-treatment") == [treatment]
      assert LazyHTML.attribute(icon, "data-tracking-id") == ["icon"]
      refute html =~ "role="

      assert LazyHTML.query(icon, ".hero-heart") |> LazyHTML.attribute("class") == [
               "hero-heart ds-design-icon-glyph size-design-icon-glyph"
             ]
    end

    html = render_component(&Icon.design_icon/1, %{name: "hero-heart", label: "Saved"})
    assert html =~ ~s|role="img"|
    assert html =~ ~s|aria-label="Saved"|
    icon = html |> LazyHTML.from_fragment() |> LazyHTML.query(".ds-design-icon")
    assert LazyHTML.attribute(icon, "aria-hidden") == []
  end

  test "icons reject invalid inputs and owned attribute collisions" do
    for attrs <- [
          %{size: "xxl"},
          %{treatment: "raised"},
          %{name: "hero-heart other"},
          %{name: "heart"},
          %{label: " "}
        ] do
      assert_raise ArgumentError, fn ->
        render_component(&Icon.design_icon/1, Map.merge(%{name: "hero-heart"}, attrs))
      end
    end

    for key <-
          ~w(class style data-size data-treatment role aria-label aria-labelledby aria-hidden tabindex onclick onkeydown onkeyup phx-click phx-capture-click phx-keydown phx-keyup),
        key <- [key, String.to_atom(key)] do
      assert_raise ArgumentError, ~r/does not accept caller-provided/, fn ->
        render_component(&Icon.design_icon/1, %{name: "hero-heart", rest: %{key => "override"}})
      end
    end
  end

  test "links reject class collisions for string and atom keys and preserve native metadata" do
    for key <- [:class, "class"] do
      assert_raise ArgumentError, fn ->
        render_component(&Link.text_link/1, %{
          href: "#cards",
          rest: %{key => "override"},
          inner_block: content("Cards")
        })
      end
    end

    html =
      render_component(&Link.text_link/1, %{
        :"aria-current" => "location",
        :"data-tracking-id" => "link",
        :"phx-click" => "track",
        href: "#cards",
        inner_block: content("Cards")
      })

    assert html =~ ~s|aria-current="location"|
    assert html =~ ~s|phx-click="track"|
  end
end
