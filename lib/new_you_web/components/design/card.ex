defmodule NewYouWeb.Components.Design.Card do
  @moduledoc "Token-owned card with flat default and an opt-in raised lighting specimen."
  use Phoenix.Component

  attr :title, :string, required: true
  attr :variant, :string, default: "flat", values: ~w(flat raised)
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders a noninteractive card; put any actions in its content as native links or buttons."
  def design_card(%{variant: variant} = assigns) when variant in ~w(flat raised) do
    if Map.has_key?(assigns.rest, :class) or Map.has_key?(assigns.rest, "class") do
      raise ArgumentError, "design_card does not accept caller-provided classes"
    end

    if Map.has_key?(assigns.rest, :"data-variant") or Map.has_key?(assigns.rest, "data-variant") do
      raise ArgumentError, "design_card does not accept caller-provided data-variant"
    end

    ~H"""
    <article
      class="ds-design-card flex min-w-0 flex-col gap-design-base rounded-design-md border data-[variant=flat]:border-design-hairline data-[variant=flat]:bg-design-surface p-design-lg text-design-ink font-design-sans data-[variant=flat]:shadow-design"
      data-variant={@variant}
      {@rest}
    >
      <h3 class="text-design-heading-sm font-design-bold leading-design-heading-sm tracking-design-heading-sm">
        {@title}
      </h3>
      <div class="text-design-body-xs leading-design-body-xs">{render_slot(@inner_block)}</div>
    </article>
    """
  end

  def design_card(%{variant: variant}) do
    raise ArgumentError, "unsupported design card variant: #{inspect(variant)}"
  end
end
