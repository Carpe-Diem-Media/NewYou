defmodule NewYouWeb.Components.Design.Card do
  @moduledoc "Canonical flat card specimen with token-owned typography, border and geometry."
  use Phoenix.Component

  attr :title, :string, required: true
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders a noninteractive card; put any actions in its content as native links or buttons."
  def design_card(assigns) do
    if Map.has_key?(assigns.rest, :class) do
      raise ArgumentError, "design_card does not accept caller-provided classes"
    end

    ~H"""
    <article
      class="ds-design-card flex min-w-0 flex-col gap-design-base rounded-design-md border border-design-hairline bg-design-surface p-design-lg text-design-ink font-design-sans shadow-design"
      {@rest}
    >
      <h3 class="text-design-heading-sm font-design-bold leading-design-heading-sm tracking-design-heading-sm">
        {@title}
      </h3>
      <div class="text-design-body-xs leading-design-body-xs">{render_slot(@inner_block)}</div>
    </article>
    """
  end
end
