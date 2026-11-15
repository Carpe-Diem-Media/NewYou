defmodule NewYouWeb.DesignSystemContracts do
  @moduledoc "Component contract comparisons for the development guide, using the shared components."
  use Phoenix.Component
  import NewYouWeb.Components.Design.{Button, Card, Icon, Link}

  def component_contracts(assigns) do
    ~H"""
    <section id="contracts" aria-labelledby="contracts-title">
      <div class="ds-section-heading">
        <h2 id="contracts-title">Component contracts</h2>
        <p>Explicit slots and variants. Local tokens. Native actions.</p>
      </div>
      <div class="ds-lighting-cards">
        <.design_card id="contract-card-default" title="Default card">
          <:leading><.design_icon name="hero-book-open" treatment="boxed" /></:leading>
          <:inset>
            <p>Inset corners follow the card edge, border and padding.</p>
          </:inset>
          <p>Flat surface. No hover lift. The article itself never receives focus.</p>
          <:actions><.text_link href="#shape">Inspect shape tokens</.text_link></:actions>
        </.design_card>
        <.design_card id="contract-card-local" title="Local geometry" variant="raised">
          <:leading><.design_icon name="hero-sun" treatment="boxed" /></:leading>
          <:inset>
            <p>One card uses the existing XL radius and smaller per-axis padding.</p>
          </:inset>
          <p>
            Its sibling keeps the default geometry. Raised depth uses the existing light direction.
          </p>
          <:actions><.text_link href="#shape">Compare the radii</.text_link></:actions>
        </.design_card>
      </div>
      <dl class="ds-layout-tokens">
        <div>
          <dt>Default outer radius</dt><dd>
            <output
              data-measure-target="contract-card-default"
              data-measure-property="border-top-left-radius"
            >Measured in browser</output>
          </dd>
        </div>
        <div>
          <dt>Local outer radius</dt><dd>
            <output
              data-measure-target="contract-card-local"
              data-measure-property="border-top-left-radius"
            >Measured in browser</output>
          </dd>
        </div>
      </dl>
      <h3 class="text-design-heading-sm font-design-medium mt-design-xl mb-design-base">
        Icon sizes and meaning
      </h3>
      <div class="ds-icon-list" aria-label="Shared icon variants">
        <div><.design_icon name="hero-heart" size="sm" /><span>Small</span></div>
        <div><.design_icon name="hero-heart" /><span>Medium</span></div>
        <div><.design_icon name="hero-heart" size="lg" /><span>Large</span></div>
        <div><.design_icon name="hero-heart" treatment="boxed" /><span>Boxed</span></div>
        <div>
          <.design_icon id="contract-icon-named" name="hero-heart-solid" label="Saved" /><span>Named image</span>
        </div>
      </div>
      <h3 class="text-design-heading-sm font-design-medium mt-design-xl mb-design-base">
        Native control states
      </h3>
      <div class="ds-lighting-actions">
        <div class="ds-lighting-action">
          <span>Icon-only action</span>
          <.secondary_button
            id="contract-icon-action"
            treatment="lit"
            aria-label="Refresh specimens"
            data-refresh-tokens
          >
            <.design_icon name="hero-arrow-path" size="sm" />
          </.secondary_button>
        </div>
        <div class="ds-lighting-action">
          <span>Default action</span>
          <.primary_button id="contract-idle" treatment="lit" data-demo-action="contract">Save changes</.primary_button>
        </div>
        <div class="ds-lighting-action">
          <span>Pending specimen</span>
          <.primary_button id="contract-busy" treatment="lit" disabled aria-busy="true">Save changes</.primary_button>
        </div>
      </div>
      <p class="ds-note">
        Pending keeps the same label and dimensions. The caller owns the real request and status message. Native disabled blocks activation; aria-busy alone does not.
      </p>
      <details class="ds-code-details">
        <summary>Contract and accessibility rules</summary>
        <ul class="list-disc pl-design-lg space-y-design-sm">
          <li>
            Variants describe appearance. Use native disabled, aria-busy, aria-expanded and aria-pressed for their actual meanings.
          </li>
          <li>
            Cards are articles. Put actions in links or buttons and choose a heading level that fits the page.
          </li>
          <li>
            Decorative icons stay hidden from assistive technology. Name icon-only controls on the native control.
          </li>
          <li>
            Inset content clips its own decoration. Keep interactive controls in the body or action slot so focus remains visible.
          </li>
          <li>
            Local CSS overrides use compatible lengths. Shadows describe visual depth and never set stacking order.
          </li>
        </ul>
      </details>
      <p class="ds-note">
        Candidate presentation contracts for review. Existing production defaults and palette remain unchanged.
      </p>
    </section>
    """
  end
end
