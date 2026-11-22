defmodule NewYouWeb.Components.Design.Section do
  @moduledoc """
  Responsive section layouts for existing NewYou content and controls.

  Provide a unique section ID and a heading level that fits the page outline.
  The containing page owns gutters, localization, and action behavior.
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :heading_level, :integer, default: 2, values: [1, 2, 3, 4, 5, 6]
  slot :body, doc: "Optional introductory prose."
  slot :actions, doc: "Optional native links or buttons in tab order."
  slot :media, doc: "Optional noninteractive media with appropriate text alternatives."

  @doc """
  Places optional media at the inline start beside the copy when space permits.
  Copy and actions precede media in source order and when stacked.
  """
  def split_hero(assigns) do
    ~H"""
    <section
      id={@id}
      aria-labelledby={"#{@id}-heading"}
      class="ds-design-section ds-split-hero ds-surface"
      data-surface="canvas"
    >
      <div class="ds-section-copy ds-stack">
        <.section_title id={"#{@id}-heading"} title={@title} level={@heading_level} />
        <div :if={@body != []} class="ds-section-body">{render_slot(@body)}</div>
        <div :if={@actions != []} class="ds-section-actions ds-row">{render_slot(@actions)}</div>
      </div>
      <div :if={@media != []} class="ds-section-media">{render_slot(@media)}</div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :heading_level, :integer, default: 2, values: [1, 2, 3, 4, 5, 6]
  slot :body, doc: "Optional introduction to the list."
  slot :item, doc: "One card per slot. Card heading levels follow the section heading."

  @doc "Renders an intrinsic card grid. An empty list omits the section."
  def feature_grid(assigns) do
    ~H"""
    <section
      :if={@item != []}
      id={@id}
      aria-labelledby={"#{@id}-heading"}
      class="ds-design-section ds-stack ds-surface"
      data-surface="canvas"
    >
      <div class="ds-section-copy ds-stack">
        <.section_title id={"#{@id}-heading"} title={@title} level={@heading_level} />
        <div :if={@body != []} class="ds-section-body">{render_slot(@body)}</div>
      </div>
      <ul class="ds-auto-grid ds-section-items" role="list">
        <li :for={item <- @item}>{render_slot(item)}</li>
      </ul>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :heading_level, :integer, default: 2, values: [1, 2, 3, 4, 5, 6]
  slot :body, doc: "Optional explanation preceding the actions."
  slot :actions, required: true, doc: "Native links, buttons, or a form."

  @doc "Places actions after the copy and wraps the row when the available width is too small."
  def action_section(assigns) do
    ~H"""
    <section
      :if={@actions != []}
      id={@id}
      aria-labelledby={"#{@id}-heading"}
      class="ds-design-section ds-action-section ds-surface"
      data-surface="canvas"
    >
      <div class="ds-section-copy ds-stack">
        <.section_title id={"#{@id}-heading"} title={@title} level={@heading_level} />
        <div :if={@body != []} class="ds-section-body">{render_slot(@body)}</div>
      </div>
      <div class="ds-section-actions ds-row">{render_slot(@actions)}</div>
    </section>
    """
  end

  defp section_title(%{level: level} = assigns) when level in 1..6 do
    ~H"""
    <.dynamic_tag tag_name={"h#{@level}"} id={@id} class="ds-design-section-title">
      {@title}
    </.dynamic_tag>
    """
  end

  defp section_title(_assigns) do
    raise ArgumentError, "section heading_level must be an integer from 1 through 6"
  end
end
