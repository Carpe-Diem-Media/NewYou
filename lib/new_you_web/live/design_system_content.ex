defmodule NewYouWeb.DesignSystemContent do
  @moduledoc "Scoped content recipes shared with the registration pilot; specimen copy is internal."
  use Phoenix.Component
  import NewYouWeb.DesignSystemComponents, only: [token_value: 1]
  import NewYouWeb.Components.Design.Link, only: [text_link: 1]

  def content_recipes(assigns) do
    ~H"""
    <section id="content" aria-labelledby="content-title">
      <div class="ds-section-heading">
        <h2 id="content-title">Content rhythm</h2>
        <p>
          Shared spacing roles, readable prose and separators. These recipes also style the registration pilot.
        </p>
      </div>
      <dl class="ds-content-tokens ds-stack">
        <div :for={role <- ~w(content-gap section-space control-gap)}>
          <dt><code>{"--#{role}"}</code></dt>
          <dd><.token_value name={"--#{role}"} /></dd>
        </div>
      </dl>
      <div class="ds-content-examples ds-auto-grid">
        <article id="prose-en" class="ds-prose" lang="en">
          <h3>English content example</h3>
          <p>
            Paragraphs share a readable measure and one spacing rhythm. Headings introduce a larger pause.
          </p>
          <p>
            Longer content should remain readable when text grows or its container becomes narrow.
          </p>
          <h4>Grouped content</h4>
          <ul>
            <li>
              <p>Keep related details together.</p><p>A list item can contain multiple paragraphs.</p>
              <ul>
                <li>Nested lists use their own smaller spacing.</li><li>
                  Preserve the reading order.
                </li>
              </ul>
            </li>
            <li>Let labels and links wrap naturally.</li>
          </ul>
          <blockquote>
            <p>A quotation keeps the same font and uses an inset.</p><p>
              Long quotations retain paragraph spacing.
            </p>
          </blockquote>
          <ol>
            <li>Read the content in order.</li><li>Review its spacing at a narrow width.</li>
          </ol>
          <hr id="prose-en-divider" class="ds-divider" />
          <p><.text_link href="#content">Review the content recipes</.text_link></p>
        </article>
        <article id="prose-af" class="ds-prose" lang="af">
          <h3>Afrikaanse inhoudsvoorbeeld</h3>
          <p>
            Paragrawe deel 'n leesbare teksbreedte en dieselfde spasieritme. Opskrifte skep 'n groter pouse.
          </p>
          <p>
            Langer inhoud moet leesbaar bly wanneer teks vergroot of die beskikbare ruimte nouer word.
          </p>
          <h4>Gegroepeerde inhoud</h4>
          <ul>
            <li>
              <p>Hou verwante besonderhede bymekaar.</p><p>
                Een lysitem kan meer as een paragraaf bevat.
              </p>
              <ul>
                <li>Geneste lyste gebruik hul eie kleiner spasiëring.</li><li>
                  Behou die leesvolgorde.
                </li>
              </ul>
            </li>
            <li>Laat etikette en skakels natuurlik omvou.</li>
          </ul>
          <blockquote>
            <p>'n Aanhaling behou dieselfde lettertipe en gebruik 'n inspringing.</p><p>
              Lang aanhalings behou paragraafspasiëring.
            </p>
          </blockquote>
          <ol>
            <li>Lees die inhoud in volgorde.</li><li>Hersien die spasiëring teen 'n nou breedte.</li>
          </ol>
          <hr id="prose-af-divider" class="ds-divider" />
          <p><.text_link href="#content">Hersien die inhoudsvoorbeelde</.text_link></p>
        </article>
      </div>
      <div class="mt-design-xl"><hr id="content-divider" class="ds-divider" /></div>
      <div id="content-divided" class="ds-divided mt-design-xl">
        <div id="prose-local" class="ds-prose">
          <h3>Local spacing comparison</h3>
          <p>This example uses smaller approved spacing tokens through local prose inputs.</p>
          <p>Its sibling keeps the default content spacing.</p>
        </div>
        <div class="ds-prose">
          <h3>Divider spacing</h3>
          <p>The group owns the line and equal space on either side. Its flex gap is zero.</p>
        </div>
      </div>
      <p class="ds-note mt-design-lg">
        Internal EN/AF specimens. Prose uses block margins; stacks use gap. Keep form controls outside prose. Local inputs live in the canonical token stylesheet.
      </p>
    </section>
    """
  end
end
