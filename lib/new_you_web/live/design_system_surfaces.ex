defmodule NewYouWeb.DesignSystemSurfaces do
  @moduledoc "Internal opaque pairing specimens using the shared surface, card and link components."
  use Phoenix.Component
  import NewYouWeb.Components.Design.Surface, only: [design_surface: 1]
  import NewYouWeb.Components.Design.Card, only: [design_card: 1]
  import NewYouWeb.Components.Design.Link, only: [text_link: 1]

  def surface_pairings(assigns) do
    ~H"""
    <section id="surface-pairings" aria-labelledby="surface-pairings-title">
      <div class="ds-section-heading">
        <h2 id="surface-pairings-title">Surface pairings</h2>
        <p>
          Each opaque background supplies its heading, body, muted, link and focus colours together.
        </p>
      </div>
      <div class="ds-pair-examples ds-auto-grid">
        <.design_surface
          :for={profile <- ~w(plain canvas panel raised)}
          surface={profile}
          id={"pair-#{profile}"}
        >
          <div class="ds-pair-example">
            <div class="ds-stack">
              <h3 id={"pair-#{profile}-heading"}>{String.capitalize(profile)} pairing</h3>
              <p id={"pair-#{profile}-body"} lang="en">
                Keep a longer English description readable when its container becomes narrow or its
                text grows. The surface supplies the complete foreground pairing.
              </p>
              <p class="ds-context-muted" id={"pair-#{profile}-muted"} lang="af">
                Bykomende besonderhede bly leesbaar wanneer 'n langer Afrikaanse beskrywing oor
                verskeie reëls omvou. Gedempte teks gebruik sy eie kleurrol.
              </p>
              <.text_link href="#surface-pairings" id={"pair-#{profile}-link"}>
                Review / Hersien
              </.text_link>
              <details class="ds-pair-readouts" open>
                <summary>Computed pairings</summary>
                <dl>
                  <div>
                    <dt>Background</dt>
                    <dd>
                      <output
                        data-measure-target={"pair-#{profile}"}
                        data-measure-property="background-color"
                      >Measured in browser</output>
                    </dd>
                  </div>
                  <div :for={role <- ~w(heading body muted link link-hover focus)}>
                    <dt><code>{"--context-#{role}"}</code></dt>
                    <dd>
                      <span
                        id={"pair-#{profile}-probe-#{role}"}
                        class="ds-pair-probe"
                        data-pair-role={role}
                        data-contrast-sample
                        data-contrast-kind={if role == "focus", do: "focus", else: "text"}
                        data-contrast-background={"pair-#{profile}"}
                        aria-hidden={role == "focus" && "true"}
                      >{if role != "focus", do: role}</span>
                      <output data-contrast-result>Measured in browser</output>
                    </dd>
                  </div>
                </dl>
              </details>
            </div>
          </div>
        </.design_surface>
      </div>
      <div class="ds-pair-examples ds-auto-grid">
        <.design_surface surface="canvas" id="pair-local">
          <div class="ds-pair-example ds-stack">
            <h3>Local profile inputs</h3>
            <p class="ds-context-muted">
              This canvas uses existing primary ink for links/focus and existing body ink for muted text.
              Its nested plain surface resets every resolved role.
            </p>
            <.text_link href="#surface-pairings" id="pair-local-link">Review local links</.text_link>
            <.design_surface surface="plain" id="pair-nested">
              <div class="ds-pair-example ds-stack">
                <h3 id="pair-nested-heading">Nested plain surface</h3>
                <p id="pair-nested-body">This body uses its own profile.</p>
                <p class="ds-context-muted" id="pair-nested-muted">Muted text resets too.</p>
                <.text_link href="#surface-pairings" id="pair-nested-link">Review the reset</.text_link>
              </div>
            </.design_surface>
          </div>
        </.design_surface>
        <.design_surface surface="panel" id="pair-card-parent">
          <div class="ds-pair-example ds-stack">
            <h3>Shared cards own their pairing</h3>
            <p>
              A card resets parent foreground outputs and retains its existing surface and lighting.
            </p>
            <.design_card id="pair-card-plain" title="Plain card">
              The production component owns data-surface="plain".
              <:actions>
                <.text_link href="#surface-pairings" id="pair-card-link">Review card pairing</.text_link>
              </:actions>
            </.design_card>
            <.design_card id="pair-card-raised" title="Raised card" variant="raised">
              The same raised background, directional edges and shadow remain in place.
            </.design_card>
          </div>
        </.design_surface>
      </div>
      <p class="ds-note mt-design-lg">
        These profiles use existing opaque colours. Plain cards retain their existing approved values;
        guide combinations and local overrides are comparisons. A surface owns colour only. Layout
        wrappers own spacing. Profile inputs inherit intentionally; each new boundary resets resolved outputs.
      </p>
      <p class="ds-note mt-design-lg">
        Readouts compare role colours against the selected opaque background. Focus colour is measured
        separately from keyboard outline geometry. Gradients, noise and overlays remain decorative
        candidates in Surface treatments. No whole-gradient or text-over-overlay contrast is implied.
      </p>
    </section>
    """
  end
end
