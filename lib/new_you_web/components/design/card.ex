defmodule NewYouWeb.Components.Design.Card do
  @moduledoc """
  Noninteractive article with flat default and opt-in raised lighting. The leading,
  inset and actions slots are explicit direct children. Inset corners subtract
  the actual flat/raised border and per-axis padding from the outer radius;
  only the inset clips content.
  Put actions in native controls. CSS owns presentation; the article has no click,
  keyboard, role or tabindex API. Heading levels follow the containing page outline.
  Card content/action gaps are separate semantic roles. Padding and prose flow
  retain their own inputs; actions use auto margin for bottom alignment when stretched.
  The card owns a plain/raised surface boundary, so parent foreground outputs reset.
  """
  use Phoenix.Component

  attr :title, :string, required: true
  attr :variant, :string, default: "flat", values: ~w(flat raised)
  attr :heading_level, :integer, default: 3, values: [2, 3, 4, 5, 6]
  attr :heading_id, :string, default: nil
  attr :rest, :global
  slot :leading
  slot :inset
  slot :actions
  slot :inner_block, required: true

  @doc "Renders a noninteractive card; put any actions in its content as native links or buttons."
  def design_card(%{variant: variant} = assigns) when variant in ~w(flat raised) do
    unless assigns.heading_level in 2..6 do
      raise ArgumentError, "design_card heading_level must be an integer from 2 through 6"
    end

    for key <- Map.keys(assigns.rest),
        to_string(key) in ~w(class style data-variant data-surface role tabindex onclick onkeydown onkeyup phx-click phx-capture-click phx-keydown phx-keyup) do
      raise ArgumentError, "design_card does not accept caller-provided #{key}"
    end

    assigns = assign(assigns, :heading_tag, "h#{assigns.heading_level}")

    ~H"""
    <article
      class="ds-design-card ds-surface flex min-w-0 flex-col gap-design-card-content font-design-sans data-[variant=flat]:shadow-design"
      data-variant={@variant}
      data-surface={if @variant == "raised", do: "raised", else: "plain"}
      {@rest}
    >
      <div :if={@leading != []} class="ds-design-card-leading">{render_slot(@leading)}</div>
      <.dynamic_tag
        tag_name={@heading_tag}
        id={@heading_id}
        class="text-design-heading-sm font-design-bold leading-design-heading-sm tracking-design-heading-sm"
      >
        {@title}
      </.dynamic_tag>
      <div :if={@inset != []} class="ds-design-card-inset">{render_slot(@inset)}</div>
      <div class="ds-design-card-body text-design-body-xs leading-design-body-xs">
        {render_slot(@inner_block)}
      </div>
      <div :if={@actions != []} class="ds-design-card-actions">{render_slot(@actions)}</div>
    </article>
    """
  end

  def design_card(%{variant: variant}) do
    raise ArgumentError, "unsupported design card variant: #{inspect(variant)}"
  end
end
