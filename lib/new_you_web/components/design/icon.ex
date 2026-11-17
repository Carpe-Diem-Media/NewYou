defmodule NewYouWeb.Components.Design.Icon do
  @moduledoc """
  Token-sized Heroicons presentation. A nil label marks decoration; a nonblank
  label names a standalone image. Put an icon-only action's name on its native
  button or link and leave its icon decorative. Names must be literal Heroicons
  classes present in templates so the existing Tailwind plugin can discover them.
  """
  use Phoenix.Component

  attr :name, :string, required: true
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :treatment, :string, default: "plain", values: ~w(plain boxed)
  attr :label, :string, default: nil
  attr :rest, :global

  @doc "Renders decorative or named artwork without creating an interactive element."
  def design_icon(assigns) do
    unless is_binary(assigns.name) and Regex.match?(~r/^hero-[a-z][a-z0-9-]*$/, assigns.name) do
      raise ArgumentError, "design_icon requires a single Heroicons class name"
    end

    unless assigns.size in ~w(sm md lg) and assigns.treatment in ~w(plain boxed) do
      raise ArgumentError, "unsupported design_icon size or treatment"
    end

    unless is_nil(assigns.label) or
             (is_binary(assigns.label) and String.trim(assigns.label) != "") do
      raise ArgumentError, "design_icon label must be nil or nonblank text"
    end

    for key <- Map.keys(assigns.rest),
        to_string(key) in ~w(class style data-size data-treatment role aria-label aria-labelledby aria-hidden tabindex onclick onkeydown onkeyup phx-click phx-capture-click phx-keydown phx-keyup) do
      raise ArgumentError, "design_icon does not accept caller-provided #{key}"
    end

    ~H"""
    <span
      class="ds-design-icon"
      data-size={@size}
      data-treatment={@treatment}
      aria-hidden={is_nil(@label) && "true"}
      role={@label && "img"}
      aria-label={@label}
      {@rest}
    ><NewYouWeb.CoreComponents.icon name={@name} class="ds-design-icon-glyph size-design-icon-glyph" /></span>
    """
  end
end
