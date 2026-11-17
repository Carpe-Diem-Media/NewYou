defmodule NewYouWeb.DesignSystemBorders do
  @moduledoc "Internal border-purpose and divider specimens using the production components."
  use Phoenix.Component
  import NewYouWeb.DesignSystemComponents, only: [token_value: 1]
  import NewYouWeb.Components.Design.Card, only: [design_card: 1]
  import NewYouWeb.Components.Design.Field, only: [design_field: 1]
  import NewYouWeb.Components.Design.Button, only: [primary_button: 1]

  def border_contracts(assigns) do
    ~H"""
    <section id="borders" aria-labelledby="borders-title">
      <div class="ds-section-heading">
        <h2 id="borders-title">Borders & dividers</h2>
        <p>Decorative edges, control boundaries and separators have separate purposes.</p>
      </div>
      <dl class="ds-border-tokens ds-stack">
        <div :for={role <- ~w(decorative control separator)}>
          <dt><code>{"--border-#{role}"}</code></dt>
          <dd><.token_value name={"--border-#{role}"} /></dd>
        </div>
        <div>
          <dt><code>--design-lit-border-width</code></dt>
          <dd><.token_value name="--design-lit-border-width" /></dd>
        </div>
      </dl>
      <dl class="ds-border-tokens ds-stack">
        <div :for={
          {label, target} <- [
            {"Decorative edge", "border-card-decorative"},
            {"Control boundary", "border-field-control"},
            {"Invalid control", "border-field-invalid"},
            {"Lit edge", "border-card-lit"},
            {"Local separator", "border-divider-local"}
          ]
        }>
          <dt>{label}</dt>
          <dd>
            <output data-measure-target={target} data-measure-property="border-top-width">
              Measured in browser
            </output>
          </dd>
        </div>
      </dl>
      <div class="ds-border-examples ds-auto-grid">
        <.design_card id="border-card-decorative" title="Decorative hairline">
          <:inset>
            <p>Inset corners follow the card's actual border and padding.</p>
          </:inset>
          A flat card uses the decorative role. Its edge groups content; it does not identify a control.
        </.design_card>
        <.design_card id="border-card-lit" title="Directional lighting" variant="raised">
          <:inset>
            <p>Light reaches the upper edge first.</p>
          </:inset>
          The raised card uses the lit width and directional edge colours. Its inset uses that same width.
        </.design_card>
      </div>
      <div class="ds-border-examples ds-auto-grid">
        <.design_field
          id="border-field-control"
          name="border-example"
          label="Control boundary"
          value="A native field with a visible boundary"
        />
        <.design_field
          id="border-field-invalid"
          name="border-error-example"
          label="Invalid control"
          error="Internal example: supply a value before continuing."
        />
      </div>
      <p class="ds-note mt-design-lg">
        Controls use a stronger boundary. An invalid field doubles its own control width and associates
        its error text. Keyboard focus uses a separate outline; it does not replace the boundary.
      </p>
      <div class="ds-border-examples ds-auto-grid">
        <div class="ds-stack">
          <h3 class="ds-border-subheading">Native thematic breaks</h3>
          <p class="ds-note">
            A native hr marks a change of topic. Layout gap owns the surrounding space.
          </p>
          <hr id="border-divider-default" class="ds-divider" />
          <p class="ds-note">The default separator uses the shared hairline.</p>
          <hr id="border-divider-local" class="ds-divider" />
          <p class="ds-note">This local example uses a doubled, dashed secondary separator.</p>
        </div>
        <div>
          <h3 class="ds-border-subheading">Decorative groups</h3>
          <div id="border-divided-outer" class="ds-divided mt-design-lg">
            <div>
              <p class="ds-note" lang="en">
                Keep a longer English description readable when a narrow container wraps its content.
                The outer group owns the spacing around its decorative boundary.
              </p>
            </div>
            <div id="border-divided-frame">
              <div id="border-divided-inner" class="ds-divided">
                <div>
                  <p class="ds-note" lang="af">
                    Hou 'n langer Afrikaanse beskrywing leesbaar wanneer die beskikbare ruimte nouer word.
                    Die binneste groep gebruik sy eie kleiner spasiëring.
                  </p>
                </div>
                <div>
                  <p class="ds-note" lang="en">
                    A neutral wrapper keeps this smaller internal rhythm separate from the outer boundary.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="ds-border-actions ds-row mt-design-xl">
        <.primary_button id="border-action-ready" treatment="lit">Continue / Gaan voort</.primary_button>
        <.primary_button id="border-action-pending" treatment="lit" disabled aria-busy="true">
          Continue / Gaan voort
        </.primary_button>
      </div>
      <p class="ds-note mt-design-lg">
        The same label preserves width in this pending comparison. The caller owns pending state and
        native disabled behaviour; aria-busy alone does not prevent activation. The premium gradient,
        short upper shine and pressed border inversion retain their existing treatment.
      </p>
      <p class="ds-note mt-design-lg">
        Optional purpose inputs are edited in the canonical token stylesheet. Decorative lines do not
        carry control meaning. Do not nest a locally overridden divided group directly at an outer
        boundary; use a neutral wrapper as shown here.
      </p>
    </section>
    """
  end
end
