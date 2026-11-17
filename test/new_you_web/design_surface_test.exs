defmodule NewYouWeb.DesignSurfaceTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias NewYouWeb.Components.Design.{Card, Surface}

  defp content(text), do: [%{inner_block: fn _, _ -> text end}]

  test "surface owns a finite color boundary and forwards unrelated metadata" do
    for profile <- ~w(plain canvas panel raised) do
      html =
        render_component(&Surface.design_surface/1, %{
          :"data-surface-note" => "metadata",
          :"aria-label" => "Example",
          surface: profile,
          id: "example",
          inner_block: content("Nested content remains in source order")
        })

      assert html =~ ~s|class="ds-surface"|
      assert html =~ ~s|data-surface="#{profile}"|
      assert html =~ ~s|data-surface-note="metadata"|
      assert html =~ ~s|aria-label="Example"|
      assert html =~ "Nested content remains in source order"
      refute html =~ "tabindex="
    end
  end

  test "surface defaults to plain and rejects unsupported profiles" do
    html = render_component(&Surface.design_surface/1, %{inner_block: content("Content")})
    assert html =~ ~s|data-surface="plain"|

    for profile <- ["inverse", "primary", "", nil, 1] do
      assert_raise ArgumentError, ~r/unsupported design surface/, fn ->
        render_component(&Surface.design_surface/1, %{
          surface: profile,
          inner_block: content("Content")
        })
      end
    end
  end

  test "surface rejects visual and interaction ownership collisions in both key forms" do
    for name <-
          ~w(class style data-surface role tabindex onclick onkeydown onkeyup phx-click phx-capture-click phx-keydown phx-keyup),
        key <- [name, String.to_atom(name)] do
      assert_raise ArgumentError, ~r/does not accept caller-provided/, fn ->
        render_component(&Surface.design_surface/1, %{
          rest: %{key => "override"},
          inner_block: content("Content")
        })
      end
    end
  end

  test "card owns its plain or raised pairing and rejects caller surface collisions" do
    for {variant, profile} <- [{"flat", "plain"}, {"raised", "raised"}] do
      html =
        render_component(&Card.design_card/1, %{
          variant: variant,
          title: "Card",
          inner_block: content("Body")
        })

      assert html =~ ~s|data-surface="#{profile}"|
      assert html =~ "ds-design-card ds-surface"
    end

    for key <- ["data-surface", :"data-surface"] do
      assert_raise ArgumentError, ~r/does not accept caller-provided/, fn ->
        render_component(&Card.design_card/1, %{
          title: "Card",
          rest: %{key => "panel"},
          inner_block: content("Body")
        })
      end
    end
  end
end
