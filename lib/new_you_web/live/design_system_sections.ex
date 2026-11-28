defmodule NewYouWeb.DesignSystemSections do
  @moduledoc "Examples of reusable section layouts for the development-only design guide."
  use Phoenix.Component

  import NewYouWeb.Components.Design.Button, only: [primary_button: 1]
  import NewYouWeb.Components.Design.Card, only: [design_card: 1]
  import NewYouWeb.Components.Design.Link, only: [text_link: 1]

  import NewYouWeb.Components.Design.Section,
    only: [action_section: 1, feature_grid: 1, split_hero: 1]

  @doc "Shows the section functions composed with their existing content and controls."
  def section_layouts(assigns) do
    ~H"""
    <section id="section-layouts" aria-labelledby="section-layouts-heading">
      <div class="ds-section-heading">
        <h2 id="section-layouts-heading">Section layouts</h2>
        <p>Reusable layouts for an introduction, a list of cards, and a next action.</p>
      </div>

      <.split_hero id="layout-hero" title="Split introduction" heading_level={3}>
        <:body>
          <p>Copy and actions come first as the layout stacks on narrower screens.</p>
        </:body>
        <:actions><.text_link href="#layout-features">See the feature cards</.text_link></:actions>
        <:media>
          <figure class="ds-layout-cell grid aspect-video place-items-center">
            <img src="/images/logo.svg" alt="Phoenix Framework logo" width="142" height="96" />
          </figure>
        </:media>
      </.split_hero>

      <.feature_grid id="layout-features" title="Feature cards" heading_level={3}>
        <:item>
          <.design_card title="Native elements" heading_level={4}>
            <p>Each card is an article inside one list item.</p>
          </.design_card>
        </:item>
        <:item>
          <.design_card title="Flexible columns" heading_level={4}>
            <p>The grid fits the space available in its container.</p>
          </.design_card>
        </:item>
        <:item>
          <.design_card title="Shared controls" heading_level={4}>
            <p>Cards can reuse the same links and buttons as other sections.</p>
          </.design_card>
        </:item>
      </.feature_grid>

      <.action_section id="layout-action" title="Open the viewport preview" heading_level={3}>
        <:body>
          <p>See how the design system responds in a separate viewport.</p>
        </:body>
        <:actions>
          <form action="/dev/design-system/preview" method="get">
            <.primary_button type="submit" adaptive>Open preview</.primary_button>
          </form>
        </:actions>
      </.action_section>
    </section>
    """
  end
end
