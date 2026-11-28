defmodule NewYouWeb.DesignSectionTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias NewYouWeb.Components.Design.Section

  test "split hero keeps copy first and isolates media and actions in their named regions" do
    dom =
      render_component(&Section.split_hero/1, %{
        id: "welcome",
        title: "Welcome",
        heading_level: 1,
        body: slot("Introduction"),
        actions: slot("Explore"),
        media: slot("Illustration")
      })
      |> LazyHTML.from_fragment()

    assert dom
           |> LazyHTML.query(
             "section#welcome[aria-labelledby='welcome-heading'] h1#welcome-heading"
           )
           |> LazyHTML.text()
           |> String.trim() == "Welcome"

    assert dom |> LazyHTML.query(".ds-section-copy + .ds-section-media") |> LazyHTML.text() =~
             "Illustration"

    assert dom |> LazyHTML.query(".ds-section-copy .ds-section-actions") |> LazyHTML.text() =~
             "Explore"
  end

  test "split heroes can coexist without empty wrappers or shared heading ids" do
    first = render_component(&Section.split_hero/1, %{id: "first", title: "First"})
    second = render_component(&Section.split_hero/1, %{id: "second", title: "Second"})
    dom = LazyHTML.from_fragment(first <> second)

    for id <- ~w(first second) do
      assert dom
             |> LazyHTML.query("section##{id}[aria-labelledby='#{id}-heading'] h2##{id}-heading")
             |> Enum.any?()
    end

    assert dom |> LazyHTML.query(".ds-section-media, .ds-section-actions") |> LazyHTML.to_html() ==
             ""
  end

  test "feature grid retains item order and omits the section when there are no items" do
    assigns = %{id: "features", title: "Features"}

    html =
      render_component(
        &Section.feature_grid/1,
        Map.put(assigns, :item, slot("One") ++ slot("Two"))
      )

    items =
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#features > ul[role=list] > li")
      |> Enum.map(&(LazyHTML.text(&1) |> String.trim()))

    assert items == ["One", "Two"]
    assert String.trim(render_component(&Section.feature_grid/1, assigns)) == ""
  end

  test "action section requires actions and never emits a heading outside the HTML outline" do
    assigns = %{id: "next", title: "Next", actions: slot("Continue"), heading_level: 3}
    dom = render_component(&Section.action_section/1, assigns) |> LazyHTML.from_fragment()

    assert dom |> LazyHTML.query("#next h3#next-heading") |> LazyHTML.text() =~ "Next"
    assert dom |> LazyHTML.query("#next .ds-section-actions") |> LazyHTML.text() =~ "Continue"

    assert String.trim(render_component(&Section.action_section/1, %{assigns | actions: []})) ==
             ""

    assert_raise ArgumentError, ~r/heading_level/, fn ->
      render_component(&Section.action_section/1, %{assigns | heading_level: 7})
    end
  end

  defp slot(text), do: [%{inner_block: fn _, _ -> text end}]
end
