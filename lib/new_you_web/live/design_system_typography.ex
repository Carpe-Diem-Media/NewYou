defmodule NewYouWeb.DesignSystemTypography do
  @moduledoc """
  Development-only modular typography comparisons. All sizes and interpolation
  belong to canonical CSS; this helper supplies internal specimens and locators
  for the existing computed-style measurement hook. No production role is adopted.
  """
  use Phoenix.Component

  import NewYouWeb.DesignSystemComponents, only: [token_value: 1, token_reference: 1]
  import NewYouWeb.Components.Design.Button, only: [primary_button: 1]

  @steps [{"xs", -2}, {"s", -1}, {"m", 0}, {"l", 1}, {"xl", 2}, {"xxl", 3}]
  @roles [
    {"display-xl", "Display XL", "A little room to grow."},
    {"display-lg", "Display L", "A little room to grow."},
    {"display-md", "Display M", "A little room to grow."},
    {"display-sm", "Display S", "A little room to grow."},
    {"heading-md", "Heading M", "Make space for yourself."},
    {"heading-sm", "Heading S", "Make space for yourself."},
    {"body-lg", "Body L", "Longer content needs room to wrap naturally."},
    {"body-md", "Body M", "Longer content needs room to wrap naturally."},
    {"body-sm", "Body S", "Longer content needs room to wrap naturally."},
    {"body-xs", "Body XS", "Longer content needs room to wrap naturally."},
    {"button-md", "Button exception", "Review typography"},
    {"caption", "Caption exception", "A note with a deliberate size."}
  ]

  def typography_scale(assigns) do
    assigns = assign(assigns, steps: @steps, roles: @roles)

    ~H"""
    <section id="type-scale" aria-labelledby="type-scale-title" data-status="candidate">
      <div class="ds-section-heading">
        <h2 id="type-scale-title">Typography scaling</h2>
        <p>
          Compare the current hierarchy with a modular scale. Candidate values need review before adoption.
        </p>
      </div>
      <p class="ds-note">
        Each mobile and desktop endpoint is calculated first. The shared fluid engine interpolates
        between them. Body roles retain the current body-xs minimum; captions and controls keep their
        existing sizes. Small mathematical steps are not automatically readable body styles.
      </p>
      <dl class="ds-fluid-bounds">
        <div>
          <dt>Viewport start</dt><dd><.token_value name="--fluid-vmin" /></dd>
        </div>
        <div>
          <dt>Viewport end</dt><dd><.token_value name="--fluid-vmax" /></dd>
        </div>
        <div>
          <dt>Active method</dt><dd><.token_value name="--fluid-method" /></dd>
        </div>
      </dl>
      <div class="ds-scale-grid">
        <div :for={family <- ~w(body heading)} class="ds-scale-inputs">
          <h3>{if family == "body", do: "Body scale inputs", else: "Heading scale inputs"}</h3>
          <dl>
            <div :for={
              {kind, edge, label} <- [
                {"base", "min", "Mobile base"},
                {"base", "max", "Desktop base"},
                {"ratio", "min", "Mobile ratio"},
                {"ratio", "max", "Desktop ratio"}
              ]
            }>
              <dt>{label}</dt>
              <dd>
                <.token_value name={"--type-#{family}-#{kind}-#{edge}"} />
                <.token_reference name={"--type-#{family}-#{kind}-#{edge}"} />
              </dd>
            </div>
          </dl>
        </div>
      </div>

      <details class="ds-code-details">
        <summary>Scale endpoints and current computed sizes</summary>
        <p class="ds-note">
          Steps -2 and -1 divide by the ratio. Step 0 is the base. Higher steps multiply.
        </p>
        <div class="ds-scale-grid">
          <div :for={family <- ~w(body heading)}>
            <h3>{if family == "body", do: "Body mathematics", else: "Heading mathematics"}</h3>
            <div :for={{step, power} <- @steps} class="ds-scale-math">
              <p><code>{"--type-#{family}-#{step}"}</code> <span>{"Step #{power}"}</span></p>
              <dl class="ds-fluid-measurements">
                <div :for={
                  {edge, label} <- [{"min", "Mobile"}, {"current", "Current"}, {"max", "Desktop"}]
                }>
                  <dt>{label}</dt>
                  <dd>
                    <span
                      id={"scale-#{family}-#{step}-#{edge}"}
                      class="ds-scale-probe"
                      data-family={family}
                      data-step={step}
                      data-edge={edge}
                      aria-hidden="true"
                    ></span>
                    <output
                      data-measure-target={"scale-#{family}-#{step}-#{edge}"}
                      data-measure-property="font-size"
                    >Measured in browser</output>
                  </dd>
                </div>
              </dl>
            </div>
          </div>
        </div>
      </details>

      <div class="ds-scale-roles">
        <article :for={{role, label, sample} <- @roles} class="ds-scale-role" data-role={role}>
          <h3>{label}</h3>
          <div class="ds-scale-grid">
            <div>
              <p class="ds-note">Current production role</p>
              <p id={"type-current-#{role}"} class="ds-scale-current">{sample}</p>
              <code>{"--text-#{role}"}</code>
              <output data-measure-target={"type-current-#{role}"} data-measure-property="font-size">Measured in browser</output>
            </div>
            <div>
              <p class="ds-note">Candidate size</p>
              <p id={"type-candidate-#{role}"} class="ds-scale-candidate">{sample}</p>
              <code>{"--type-candidate-#{role}"}</code>
              <output data-measure-target={"type-candidate-#{role}"} data-measure-property="font-size">Measured in browser</output>
            </div>
          </div>
          <dl class="ds-type-measurements">
            <div>
              <dt>Unitless line height</dt><dd><.token_value name={"--leading-#{role}"} /></dd>
            </div>
            <div>
              <dt>Tracking</dt><dd><.token_value name={"--tracking-#{role}"} /></dd>
            </div>
          </dl>
        </article>
      </div>

      <div class="ds-scale-grid">
        <article id="type-scale-local" class="ds-type-scope" data-type-example="local">
          <h3>One endpoint overridden locally</h3>
          <p id="type-scale-local-sample" class="ds-scale-local-sample">
            A different display endpoint.
          </p>
          <p id="type-scale-local-body" class="ds-scale-local-body">
            Body text uses this scope's scale inputs.
          </p>
          <p class="ds-note">
            This scope sets --design-type-heading-xxl-max to the existing --text-display-md value.
            Its mobile endpoint and sibling scopes keep their defaults.
          </p>
          <output data-measure-target="type-scale-local-sample" data-measure-property="font-size">Measured in browser</output>
        </article>
        <article id="type-scale-default" class="ds-type-scope">
          <h3>Default sibling</h3>
          <p id="type-scale-default-sample" class="ds-scale-local-sample">
            The original scale relationship.
          </p>
          <p id="type-scale-default-body" class="ds-scale-local-body">
            Body text keeps the default scale inputs.
          </p>
          <p class="ds-note">Edit the root base or ratio to update every scale scope.</p>
        </article>
      </div>

      <div class="ds-scale-grid ds-scale-readings">
        <article id="type-reading-en" class="ds-prose ds-scale-reading" lang="en">
          <h3>Room for a longer English heading and a thoughtful reading rhythm</h3>
          <p>
            This internal specimen compares how a shared type system handles longer sentences,
            different word lengths and a narrower reading area. Its wording is an example for
            design review and is not approved participant copy.
          </p>
          <p>Read the same content after resizing the viewport or changing the font token.</p>
          <ul>
            <li>
              Keep related details together.<ul>
                <li>Nested content keeps its reading order.</li>
              </ul>
            </li><li>Let every line wrap without clipping.</li>
          </ul>
          <blockquote>
            <p>A larger font must leave enough space for accents, punctuation and several lines.</p>
          </blockquote>
        </article>
        <article id="type-reading-af" class="ds-prose ds-scale-reading" lang="af">
          <h3>Ruimte vir 'n langer Afrikaanse opskrif en 'n gemaklike leesritme</h3>
          <p>
            Hierdie interne voorbeeld wys hoe 'n gedeelde teksstelsel langer sinne,
            verskillende woordlengtes en 'n nouer leesruimte hanteer. Die bewoording is slegs
            vir ontwerphersiening en is nie goedgekeurde deelnemerinhoud nie.
          </p>
          <p>Lees dieselfde inhoud nadat jy die vensterbreedte of lettertipe verander het.</p>
          <ul>
            <li>
              Hou verwante besonderhede bymekaar.<ul>
                <li>Geneste inhoud behou sy leesvolgorde.</li>
              </ul>
            </li><li>Laat elke reël omvou sonder om teks af te sny.</li>
          </ul>
          <blockquote>
            <p>'n Groter lettertipe moet ruimte laat vir aksente, leestekens en verskeie reëls.</p>
          </blockquote>
        </article>
      </div>
      <div class="ds-scale-control">
        <.primary_button treatment="lit" data-demo-action="typography">Review typography</.primary_button>
        <p class="ds-note">The actual shared button keeps its approved size, borders and shine.</p>
      </div>
      <p class="ds-note">
        Line heights and tracking in the comparisons retain their existing role values.
        Review them with the new sizes before adoption. Font selection remains in --font-body
        and --font-display; changing a family also requires checking wrapping and font metrics.
      </p>
    </section>
    """
  end
end
