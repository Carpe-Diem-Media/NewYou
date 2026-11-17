defmodule NewYouWeb.Components.Design.Surface do
  @moduledoc """
  Opaque color boundary with complete foreground roles. It owns no layout,
  elevation or interaction. Callers supply semantic content and existing layout
  wrappers. Every nested surface recomputes its complete profile; profile inputs
  in canonical CSS are inherited intentionally, while resolved outputs reset.
  """
  use Phoenix.Component

  attr :surface, :string, default: "plain", values: ~w(plain canvas panel raised)
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders a noninteractive color boundary using an existing opaque background."
  def design_surface(assigns) do
    unless assigns.surface in ~w(plain canvas panel raised) do
      raise ArgumentError, "unsupported design surface: #{inspect(assigns.surface)}"
    end

    for key <- Map.keys(assigns.rest),
        to_string(key) in ~w(class style data-surface role tabindex onclick onkeydown onkeyup phx-click phx-capture-click phx-keydown phx-keyup) do
      raise ArgumentError, "design_surface does not accept caller-provided #{key}"
    end

    ~H"""
    <div class="ds-surface" data-surface={@surface} {@rest}>{render_slot(@inner_block)}</div>
    """
  end
end
