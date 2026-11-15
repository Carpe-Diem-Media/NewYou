defmodule NewYouWeb.Components.Design.Link do
  @moduledoc "Canonical underlined link; defaults to charcoal and reads the nearest surface's link roles."
  use Phoenix.Component

  attr :href, :string, required: true
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders an underlined native link with a visible keyboard focus indicator."
  def text_link(assigns) do
    if Map.has_key?(assigns.rest, :class) or Map.has_key?(assigns.rest, "class") do
      raise ArgumentError, "design text_link does not accept caller-provided classes"
    end

    ~H"""
    <a
      href={@href}
      class="ds-design-link font-design-sans underline underline-offset-4 hover:decoration-2 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-design-primary"
      {@rest}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end
end
