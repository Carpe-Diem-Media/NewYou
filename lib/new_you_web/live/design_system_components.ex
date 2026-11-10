defmodule NewYouWeb.DesignSystemComponents do
  @moduledoc "Specimen and measurement markup used only by the development style guide."
  use Phoenix.Component

  @palette [
    {"primary", "Primary", "--primary"},
    {"primary-hover", "Primary interaction", "--primary-hover"},
    {"secondary", "Secondary / ink", "--secondary"},
    {"ink-strong", "Strong ink", "--ink-strong"},
    {"ink-soft", "Soft ink", "--ink-soft"},
    {"ink-muted", "Muted ink", "--ink-muted"},
    {"ink-meta", "Metadata ink", "--ink-meta"},
    {"canvas", "Canvas", "--canvas"},
    {"surface", "Surface", "--surface"},
    {"hairline", "Hairline", "--hairline"},
    {"hairline-cool", "Cool hairline", "--hairline-cool"},
    {"on-primary", "On primary", "--on-primary"},
    {"on-canvas", "Input value", "--on-canvas"},
    {"orb-saffron", "Saffron", "--orb-saffron"},
    {"orb-pink", "Pink", "--orb-pink"},
    {"orb-aqua", "Aqua", "--orb-aqua"},
    {"orb-grass", "Grass", "--orb-grass"},
    {"orb-ultraviolet", "Ultraviolet", "--orb-ultraviolet"}
  ]

  @type_styles [
    {"display-xl", "Display XL", "A little room to grow."},
    {"display-lg", "Display L", "A little room to grow."},
    {"display-md", "Display M", "A little room to grow."},
    {"display-sm", "Display S", "A little room to grow."},
    {"heading-md", "Heading M", "Make space for yourself."},
    {"heading-sm", "Heading S", "Make space for yourself."},
    {"body-lg", "Body L", "Small, thoughtful choices. A consistent experience."},
    {"body-md", "Body M", "Small, thoughtful choices. A consistent experience."},
    {"body-sm", "Body S", "Small, thoughtful choices. A consistent experience."},
    {"body-xs", "Body XS", "Small, thoughtful choices. A consistent experience."},
    {"button-md", "Button", "Explore the system"},
    {"caption", "Caption", "A note, a label, a little context."}
  ]

  attr :name, :string, required: true

  def token_value(assigns) do
    ~H"""
    <output class="ds-token-value" data-token={@name}>CSS value</output>
    """
  end

  attr :name, :string, required: true

  def token_reference(assigns) do
    ~H"""
    <button
      type="button"
      class="ds-token-copy"
      data-copy={@name}
      aria-label={"Copy #{@name}"}
      disabled
    >
      <code>{@name}</code>
      <span class="hero-square-2-stack ds-copy-icon" aria-hidden="true"></span>
    </button>
    """
  end

  def palette(assigns) do
    assigns = assign(assigns, :palette, @palette)

    ~H"""
    <div class="ds-palette">
      <figure :for={{key, label, token} <- @palette} class="ds-palette-item">
        <div class="ds-swatch" data-swatch={key} role="img" aria-label={label}></div>
        <figcaption>
          <span class="ds-swatch-name">{label}</span>
          <.token_value name={token} />
          <.token_reference name={token} />
        </figcaption>
      </figure>
    </div>
    """
  end

  def typography(assigns) do
    assigns = assign(assigns, :styles, @type_styles)

    ~H"""
    <div class="ds-font-specimen">
      <p class="ds-font-alphabet">Aa Bb Cc Dd Ee Ff Gg</p>
      <div class="ds-font-details">
        <p>One shared type family</p>
        <.token_value name="--font-body" />
        <.token_reference name="--font-body" />
      </div>
    </div>
    <p class="ds-note">
      The CSS uses the approved Inter fallback. No font file is bundled; the browser may use sans-serif.
    </p>
    <div class="ds-type-list">
      <div :for={{key, label, sample} <- @styles} class="ds-type-row" data-type={key}>
        <div class="ds-type-label">
          <span>{label}</span>
          <.token_value name={"--text-#{key}"} />
        </div>
        <div class="ds-type-content">
          <p class="ds-type-sample">{sample}</p>
          <div class="ds-type-measurements">
            <.token_reference name={"--text-#{key}"} />
            <span>Line height <.token_value name={"--leading-#{key}"} /></span>
            <span>Tracking <.token_value name={"--tracking-#{key}"} /></span>
          </div>
        </div>
      </div>
    </div>
    <div class="ds-weight-list">
      <p class="font-design-regular">Regular <.token_value name="--weight-regular" /></p>
      <p class="font-design-medium">Medium <.token_value name="--weight-medium" /></p>
      <p class="font-design-bold">Bold <.token_value name="--weight-bold" /></p>
    </div>
    """
  end

  def spacing(assigns) do
    assigns = assign(assigns, :sizes, ~w(xxs xs sm md base lg xl 2xl))

    ~H"""
    <div class="ds-spacing-list">
      <div :for={size <- @sizes} class="ds-spacing-row" data-space={size}>
        <.token_reference name={"--space-#{size}"} />
        <span class="ds-spacing-track"><span class="ds-spacing-bar"></span></span>
        <.token_value name={"--space-#{size}"} />
      </div>
    </div>
    <div class="ds-spacing-example">
      <div class="ds-spacing-example-inner">Padding, content and gap share the same scale.</div>
    </div>
    <p class="ds-note">The outer padding uses --space-lg. The inner padding uses --space-base.</p>
    """
  end

  def relationships(assigns) do
    assigns =
      assign(assigns, :pairs, [
        {"canvas", "Ink on canvas", "--secondary", "--canvas"},
        {"surface", "Ink on surface", "--secondary", "--surface"},
        {"primary", "Primary action", "--on-primary", "--primary"},
        {"saffron", "Ink on saffron", "--secondary", "--orb-saffron"},
        {"pink", "Ink on pink", "--secondary", "--orb-pink"},
        {"aqua", "Ink on aqua", "--secondary", "--orb-aqua"},
        {"grass", "Light on grass", "--on-primary", "--orb-grass"},
        {"ultraviolet", "Light on ultraviolet", "--on-primary", "--orb-ultraviolet"}
      ])

    ~H"""
    <div class="ds-relationships">
      <div :for={{key, label, foreground, background} <- @pairs} class="ds-relationship">
        <div class="ds-color-pair" data-pair={key} data-contrast-sample>
          <span>Aa</span>
        </div>
        <div class="ds-relationship-info">
          <h3>{label}</h3>
          <p><code>{foreground}</code> on <code>{background}</code></p>
          <output data-contrast-result>Measured in browser</output>
        </div>
      </div>
    </div>
    <p class="ds-note">
      WCAG text contrast: AA at 4.5:1, AAA at 7:1. Large text requires 3:1.
      A passing sample does not approve a new component color role.
    </p>
    """
  end
end
