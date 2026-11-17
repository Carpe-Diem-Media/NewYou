defmodule NewYouWeb.DesignSystemLayouts do
  @moduledoc """
  Development-only layout candidates for inspecting actual allocated space.

  The guide supplies bounded display choices. CSS owns all dimensions and track
  calculations; these specimens do not admit a production layout API.
  """
  use Phoenix.Component

  import NewYouWeb.DesignSystemComponents, only: [token_value: 1]

  attr :count, :string, required: true
  attr :card_count, :integer, required: true
  attr :counts, :list, required: true
  attr :alignment, :string, required: true
  attr :allocation, :string, required: true

  def layout_foundations(assigns) do
    ~H"""
    <div id="layout-lab" class="ds-layout-lab" data-allocation={@allocation}>
      <h3>Layout lab</h3>
      <p class="ds-candidate-note">
        Candidate recipes. Change available width without changing the viewport.
        Application layouts keep their existing defaults.
      </p>
      <form id="layout-controls" class="ds-controls" phx-change="layout">
        <label for="layout-allocation">
          Available space
          <select id="layout-allocation" name="layout[allocation]">
            <option value="full" selected={@allocation == "full"}>Full allocation</option>
            <option value="narrow" selected={@allocation == "narrow"}>Narrow allocation</option>
          </select>
        </label>
        <label for="layout-count">
          Items
          <select id="layout-count" name="layout[count]">
            <option :for={count <- @counts} value={count} selected={count == @count}>{count}</option>
          </select>
        </label>
        <label for="layout-alignment">
          Fixed-grid remainder
          <select id="layout-alignment" name="layout[alignment]">
            <option value="start" selected={@alignment == "start"}>Align to start</option>
            <option value="center" selected={@alignment == "center"}>Centre the row</option>
          </select>
        </label>
      </form>

      <div class="ds-layout-example">
        <h4>Fixed grid</h4>
        <p>Uses the project viewport breakpoints. Narrow allocation keeps the column count.</p>
        <div class="ds-layout-stage">
          <div id="layout-fixed" class="ds-card-grid" data-alignment={@alignment}>
            <.cells count={@card_count} />
          </div>
        </div>
        <.measurement target="layout-fixed" />
      </div>

      <div class="ds-layout-example">
        <h4>Auto-fit</h4>
        <p>Fits the available space, up to the token column limit. Empty tracks collapse.</p>
        <div class="ds-layout-stage">
          <div id="layout-auto-fit" class="ds-layout-auto" data-flow="fit">
            <.cells count={@card_count} />
          </div>
        </div>
        <.measurement target="layout-auto-fit" />
      </div>

      <div class="ds-layout-example">
        <h4>Auto-fill</h4>
        <p>Keeps empty tracks. Try one item at full width to compare its size with Auto-fit.</p>
        <div class="ds-layout-stage">
          <div id="layout-auto-fill" class="ds-layout-auto" data-flow="fill">
            <.cells count={@card_count} />
          </div>
        </div>
        <.measurement target="layout-auto-fill" />
        <p class="ds-note">
          Intrinsic grids start incomplete rows at the leading edge. The fixed grid demonstrates
          deliberate centring with equal item widths.
        </p>
      </div>

      <div class="ds-layout-example">
        <h4>Container & gutters</h4>
        <p>The cap includes both gutters. Nested content adds no second gutter.</p>
        <div class="ds-layout-stage ds-layout-container-stage">
          <div id="layout-container" class="ds-layout-container">
            <div class="ds-layout-nested">
              <p>One wrapper owns the inline padding.</p>
              <p lang="af">Langer inhoud moet binne die beskikbare ruimte bly.</p>
            </div>
          </div>
        </div>
        <.measurement target="layout-container" property="padding-inline-start" label="Each gutter" />
      </div>

      <div class="ds-layout-example">
        <h4>Breakout zones</h4>
        <p>Seven tracks, four zones. Feature lanes collapse when space is limited.</p>
        <div class="ds-layout-stage">
          <div id="layout-breakout" class="ds-layout-breakout">
            <div class="ds-layout-band" data-zone="content">Content</div>
            <div class="ds-layout-band" data-zone="feature">Feature</div>
            <div class="ds-layout-band" data-zone="feature-max">Feature max</div>
            <div class="ds-layout-band" data-zone="full">Full</div>
            <div class="ds-layout-band" data-zone="full-safe">Full with safe gutters</div>
            <div class="ds-layout-band">
              Default content <span data-zone="full">Nested labels do not escape their parent.</span>
            </div>
          </div>
        </div>
        <.measurement target="layout-breakout" />
        <p class="ds-note">
          This comparison uses half the content-width token to expose the lanes inside the guide.
          It does not change the application cap or convert sections to breakout grids.
        </p>
      </div>

      <details class="ds-code-details">
        <summary>Layout inputs & formulas</summary>
        <p>
          Candidate inputs are in assets/css/design-tokens.css. Recipes are in design-layouts.css.
        </p>
        <dl class="ds-layout-inputs">
          <div>
            <dt>Minimum item</dt><dd><.token_value name="--design-layout-min" /></dd>
          </div>
          <div>
            <dt>Column limit</dt><dd><.token_value name="--design-layout-columns" /></dd>
          </div>
          <div>
            <dt>Narrow allocation</dt><dd><.token_value name="--design-layout-narrow" /></dd>
          </div>
          <div>
            <dt>Demo cap ratio</dt><dd><.token_value name="--design-layout-content-ratio" /></dd>
          </div>
        </dl>
        <pre><code>{"Track minimum = min(available width, max(item minimum, (available width - (columns - 1) * gap) / columns))\nFit threshold = count * item minimum + (count - 1) * gap\nSafe content = min(demo cap, available width - 2 * gutter)\nFeature = content + 2 * inner lane\nFeature max = content + 2 * inner lane + 2 * outer lane"}</code></pre>
      </details>
    </div>
    """
  end

  attr :count, :integer, required: true

  defp cells(assigns) do
    ~H"""
    <div :for={n <- 1..@count} class="ds-layout-cell">
      <span>Item {n}</span>
      <p>Room to wrap.</p>
    </div>
    """
  end

  attr :target, :string, required: true
  attr :property, :string, default: "column-gap"
  attr :label, :string, default: "Gap"

  defp measurement(assigns) do
    ~H"""
    <dl class="ds-layout-measurement">
      <div>
        <dt>Allocated width</dt>
        <dd>
          <output data-measure-target={@target} data-measure-property="width">Not measured</output>
        </dd>
      </div>
      <div>
        <dt>{@label}</dt>
        <dd>
          <output data-measure-target={@target} data-measure-property={@property}>Not measured</output>
        </dd>
      </div>
    </dl>
    """
  end
end
