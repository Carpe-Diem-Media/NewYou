defmodule NewYouWeb.Components.Design.Button do
  @moduledoc """
  Canonical Phoenix button primitives mapped to the root `DESIGN.md` tokens.

  Visual classes, `data-variant` and `data-treatment` are owned here. Callers may provide normal
  HTML, ARIA, LiveView and unrelated data attributes. Native `disabled` controls
  availability. Flat is the default; lit opts into the guide lighting treatment.
  The secondary button uses the approved neutral outline.
  """

  use Phoenix.Component

  attr :variant, :string, default: "primary", values: ~w(primary)
  attr :treatment, :string, default: "flat", values: ~w(flat lit)
  attr :type, :string, default: "button", values: ~w(button submit reset)
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders the approved primary CTA while preserving caller HTML and LiveView attributes."
  def primary_button(%{variant: "primary", rest: rest} = assigns) do
    validate_rest!(rest, "design primary_button", assigns.treatment)

    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class="ds-design-button inline-flex items-center justify-center min-h-design-button-height data-[treatment=flat]:h-design-button-height px-design-button-inline py-design-button-block rounded-design-xl data-[treatment=flat]:data-[variant=primary]:bg-design-primary data-[treatment=flat]:data-[variant=primary]:text-design-on-primary font-design-sans font-design-bold text-design-button-md leading-design-button-md tracking-design-button-md data-[treatment=flat]:data-[variant=primary]:hover:bg-design-primary-deep data-[treatment=flat]:data-[variant=primary]:active:bg-design-primary-deep focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-design-primary"
      data-variant="primary"
      data-treatment={@treatment}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  def primary_button(%{variant: variant}) do
    raise ArgumentError, "unsupported design button variant: #{inspect(variant)}"
  end

  attr :treatment, :string, default: "flat", values: ~w(flat lit)
  attr :type, :string, default: "button", values: ~w(button submit reset)
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders the approved neutral outline button with native button semantics."
  def secondary_button(assigns) do
    validate_rest!(assigns.rest, "design secondary_button", assigns.treatment)

    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class="ds-design-button inline-flex items-center justify-center min-h-design-button-height data-[treatment=flat]:h-design-button-height px-design-button-inline py-design-md rounded-design-full border data-[treatment=flat]:data-[variant=secondary]:border-design-ink data-[treatment=flat]:data-[variant=secondary]:bg-design-surface data-[treatment=flat]:data-[variant=secondary]:text-design-ink font-design-sans font-design-bold text-design-button-md leading-design-button-md tracking-design-button-md focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-design-primary hover:underline active:underline disabled:cursor-not-allowed"
      data-variant="secondary"
      data-treatment={@treatment}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp validate_rest!(rest, component, treatment) do
    if treatment not in ~w(flat lit) do
      raise ArgumentError, "unsupported design button treatment: #{inspect(treatment)}"
    end

    if Map.has_key?(rest, :"data-treatment") or Map.has_key?(rest, "data-treatment") do
      raise ArgumentError, "#{component} does not accept caller-provided data-treatment"
    end

    if Map.has_key?(rest, :class) or Map.has_key?(rest, "class") do
      raise ArgumentError, "#{component} does not accept caller-provided classes"
    end

    if Map.has_key?(rest, :"data-variant") or Map.has_key?(rest, "data-variant") do
      raise ArgumentError, "#{component} does not accept caller-provided data-variant"
    end
  end
end
