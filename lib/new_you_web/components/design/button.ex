defmodule NewYouWeb.Components.Design.Button do
  @moduledoc """
  Canonical Phoenix button primitives mapped to the root `DESIGN.md` tokens.

  Visual classes are owned here; callers may provide normal HTML, ARIA, and
  LiveView attributes. The secondary button uses the approved neutral outline.
  """

  use Phoenix.Component

  attr :variant, :string, default: "primary", values: ~w(primary)
  attr :type, :string, default: "button", values: ~w(button submit reset)
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders the approved primary CTA while preserving caller HTML and LiveView attributes."
  def primary_button(%{variant: "primary", rest: rest} = assigns) do
    if Map.has_key?(rest, :class) do
      raise ArgumentError, "design primary_button does not accept caller-provided classes"
    end

    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class="inline-flex items-center justify-center h-design-button-height px-design-button-inline py-design-button-block rounded-design-xl bg-design-primary text-design-on-primary font-design-sans font-design-bold text-design-button-md leading-design-button-md tracking-design-button-md hover:bg-design-primary-deep active:bg-design-primary-deep focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-design-primary"
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  def primary_button(%{variant: variant}) do
    raise ArgumentError, "unsupported design button variant: #{inspect(variant)}"
  end

  attr :type, :string, default: "button", values: ~w(button submit reset)
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders the approved neutral outline button with native button semantics."
  def secondary_button(assigns) do
    if Map.has_key?(assigns.rest, :class) do
      raise ArgumentError, "design secondary_button does not accept caller-provided classes"
    end

    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class="inline-flex items-center justify-center h-design-button-height px-design-button-inline py-design-md rounded-design-full border border-design-ink bg-design-surface text-design-ink font-design-sans font-design-bold text-design-button-md leading-design-button-md tracking-design-button-md focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-design-primary hover:underline active:underline disabled:cursor-not-allowed"
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end
