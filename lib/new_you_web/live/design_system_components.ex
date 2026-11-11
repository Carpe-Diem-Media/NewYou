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

  def surfaces(assigns) do
    ~H"""
    <div class="ds-treatment-list">
      <figure class="ds-treatment-item">
        <div class="ds-treatment" data-treatment="gradient" aria-hidden="true"></div>
        <figcaption>
          <strong>Gradient wash</strong>
          <p>Decorative only. Do not use the gradient as a text or control background.</p>
          <.token_reference name="--design-gradient-soft" />
          <.token_reference name="--background-image-design-wash" />
        </figcaption>
      </figure>
      <figure class="ds-treatment-item">
        <div class="ds-treatment" data-treatment="noise" aria-hidden="true"></div>
        <figcaption>
          <strong>Noise texture</strong>
          <p>Decorative only. Keep text and controls outside the texture layer.</p>
          <.token_reference name="--design-noise-image" />
          <.token_reference name="--design-noise-opacity" />
        </figcaption>
      </figure>
      <figure class="ds-treatment-item">
        <div class="ds-treatment" data-treatment="overlay" aria-hidden="true"></div>
        <figcaption>
          <strong>Static scrim</strong>
          <p>Candidate overlay token. This sample has no text and makes no contrast claim.</p>
          <.token_reference name="--design-overlay" />
        </figcaption>
      </figure>
    </div>
    <p class="ds-note">
      These surface treatments are candidates for review, not approved global component styles.
      Contrast values belong to the opaque color pairs above. The guide does not score a whole gradient.
    </p>
    """
  end

  attr :kind, :string, required: true
  attr :edge, :string, required: true
  attr :token, :string, required: true

  def fluid_bound(assigns) do
    ~H"""
    <.token_value name={@token} />
    <span
      id={"fluid-#{@kind}-#{@edge}"}
      class="ds-fluid-bound-probe"
      data-bound={"#{@kind}-#{@edge}"}
      aria-hidden="true"
    ></span>
    <output
      data-measure-target={"fluid-#{@kind}-#{@edge}"}
      data-measure-property="font-size"
    >Resolved size measured in browser</output>
    """
  end

  def fluid(assigns) do
    ~H"""
    <p class="ds-note">
      These fluid values are comparison candidates. Existing app typography stays fixed at its approved tokens.
    </p>
    <dl class="ds-fluid-bounds">
      <div>
        <dt>Viewport start</dt><dd><.token_value name="--fluid-vmin" /></dd>
      </div>
      <div>
        <dt>Viewport end</dt><dd><.token_value name="--fluid-vmax" /></dd>
      </div>
      <div>
        <dt>Method</dt><dd><.token_value name="--fluid-method" /></dd>
      </div>
      <div>
        <dt>Relative OKLCH</dt><dd>
          <output data-css-support="oklch">Checking relative OKLCH support</output>
        </dd>
      </div>
      <div>
        <dt>Color mixing</dt><dd>
          <output data-css-support="color-mix">Checking color-mix support</output>
        </dd>
      </div>
      <div>
        <dt>Native progress()</dt><dd>
          <output data-css-support="progress">Checking progress() support</output>
        </dd>
      </div>
    </dl>
    <div class="ds-fluid-list">
      <article class="ds-fluid-item">
        <div id="fluid-display" class="ds-fluid-display">A little room to grow.</div>
        <h3>Display size</h3>
        <.token_reference name="--fluid-display-min" />
        <.token_reference name="--fluid-display-max" />
        <dl class="ds-fluid-measurements">
          <div>
            <dt>Minimum</dt><dd data-fluid-value="display-min">
              <.fluid_bound kind="display" edge="min" token="--fluid-display-min" />
            </dd>
          </div>
          <div>
            <dt>Current</dt><dd>
              <output data-measure-target="fluid-display" data-measure-property="font-size">Current size measured in browser</output>
            </dd>
          </div>
          <div>
            <dt>Maximum</dt><dd data-fluid-value="display-max">
              <.fluid_bound kind="display" edge="max" token="--fluid-display-max" />
            </dd>
          </div>
        </dl>
      </article>
      <article class="ds-fluid-item">
        <p id="fluid-body" class="ds-fluid-body">
          The browser reports the computed size of this paragraph.
        </p>
        <h3>Body size</h3>
        <dl class="ds-fluid-measurements">
          <div>
            <dt>Minimum</dt><dd data-fluid-value="body-min">
              <.fluid_bound kind="body" edge="min" token="--fluid-body-min" />
            </dd>
          </div>
          <div>
            <dt>Current</dt><dd>
              <output data-measure-target="fluid-body" data-measure-property="font-size">Current size measured in browser</output>
            </dd>
          </div>
          <div>
            <dt>Maximum</dt><dd data-fluid-value="body-max">
              <.fluid_bound kind="body" edge="max" token="--fluid-body-max" />
            </dd>
          </div>
        </dl>
      </article>
      <article class="ds-fluid-item">
        <div id="fluid-space" class="ds-fluid-space">Block spacing sample</div>
        <h3>Block spacing</h3>
        <dl class="ds-fluid-measurements">
          <div>
            <dt>Minimum</dt><dd data-fluid-value="space-min">
              <.fluid_bound kind="space" edge="min" token="--fluid-space-min" />
            </dd>
          </div>
          <div>
            <dt>Current</dt><dd>
              <output data-measure-target="fluid-space" data-measure-property="padding-block-start">Current spacing measured in browser</output>
            </dd>
          </div>
          <div>
            <dt>Maximum</dt><dd data-fluid-value="space-max">
              <.fluid_bound kind="space" edge="max" token="--fluid-space-max" />
            </dd>
          </div>
        </dl>
      </article>
      <article class="ds-fluid-item">
        <div id="fluid-gutter" class="ds-fluid-gutter"><span>Inline gutter sample</span></div>
        <h3>Inline gutter</h3>
        <dl class="ds-fluid-measurements">
          <div>
            <dt>Minimum</dt><dd data-fluid-value="gutter-min">
              <.fluid_bound kind="gutter" edge="min" token="--fluid-gutter-min" />
            </dd>
          </div>
          <div>
            <dt>Current</dt><dd>
              <output data-measure-target="fluid-gutter" data-measure-property="padding-inline-start">Current gutter measured in browser</output>
            </dd>
          </div>
          <div>
            <dt>Maximum</dt><dd data-fluid-value="gutter-max">
              <.fluid_bound kind="gutter" edge="max" token="--fluid-gutter-max" />
            </dd>
          </div>
        </dl>
      </article>
    </div>
    """
  end

  attr :surface_only?, :boolean, default: false

  def relationships(assigns) do
    pairs = [
      {"canvas", "Ink on canvas", "--secondary", "--canvas"},
      {"surface", "Ink on surface", "--secondary", "--surface"},
      {"primary", "Primary action", "--on-primary", "--primary"},
      {"saffron", "Ink on saffron", "--secondary", "--orb-saffron"},
      {"pink", "Ink on pink", "--secondary", "--orb-pink"},
      {"aqua", "Ink on aqua", "--secondary", "--orb-aqua"},
      {"grass", "Light on grass", "--on-primary", "--orb-grass"},
      {"ultraviolet", "Light on ultraviolet", "--on-primary", "--orb-ultraviolet"},
      {"tint", "Surface tint", "--secondary", "--design-surface-tint"},
      {"shade", "Surface shade", "--secondary", "--design-surface-shade"}
    ]

    pairs = if assigns.surface_only?, do: Enum.take(pairs, -2), else: pairs
    assigns = assign(assigns, :pairs, pairs)

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
