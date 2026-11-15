defmodule NewYouWeb.DesignSystemContent do
  @moduledoc "Scoped content recipes shared with the registration pilot; specimen copy is internal."
  use Phoenix.Component
  import NewYouWeb.DesignSystemComponents, only: [token_value: 1]
  import NewYouWeb.Components.Design.Link, only: [text_link: 1]
  import NewYouWeb.Components.Design.Card, only: [design_card: 1]

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
        <div :for={role <- ~w(content-gap section-space control-gap card-content-gap card-action-gap)}>
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
          <figure id="prose-en-figure">
            <blockquote>
              <p>
                Keep the quotation and its explanation together, even when a longer English description
                wraps across several lines in a narrow column.
              </p>
              <p>The quotation keeps the surrounding prose rhythm.</p>
            </blockquote>
            <figcaption>
              Internal figure specimen. This caption has its own spacing and retains the approved caption size.
            </figcaption>
          </figure>
          <div id="prose-en-nested-frame">
            <section id="prose-en-nested" class="ds-prose" aria-labelledby="prose-en-nested-title">
              <h5 id="prose-en-nested-title">Explicit nested prose</h5>
              <p>This wrapper owns a smaller internal paragraph rhythm.</p>
              <p>The outer prose still owns the space before and after the wrapper.</p>
            </section>
          </div>
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
          <figure id="prose-af-figure">
            <blockquote>
              <p>
                Hou die aanhaling en die verduideliking bymekaar, selfs wanneer 'n langer Afrikaanse
                beskrywing oor verskeie reëls in 'n nou kolom omvou.
              </p>
              <p>Die aanhaling behou die omliggende paragrawe se spasieritme.</p>
            </blockquote>
            <figcaption>
              Interne figuurvoorbeeld. Hierdie byskrif het sy eie spasiëring en behou die goedgekeurde byskrifgrootte.
            </figcaption>
          </figure>
          <div id="prose-af-nested-frame">
            <section id="prose-af-nested" class="ds-prose" aria-labelledby="prose-af-nested-title">
              <h5 id="prose-af-nested-title">Uitdruklik geneste inhoud</h5>
              <p>Hierdie groep het 'n kleiner interne paragraafspasiëring.</p>
              <p>Die buitenste inhoud beheer steeds die ruimte voor en ná die groep.</p>
            </section>
          </div>
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
          <figure>
            <blockquote>
              <p>A local caption input changes only this specimen's caption gap.</p>
            </blockquote>
            <figcaption>Local caption spacing uses the existing smallest spacing token.</figcaption>
          </figure>
        </div>
        <div class="ds-prose">
          <h3>Divider spacing</h3>
          <p>The group owns the line and equal space on either side. Its flex gap is zero.</p>
        </div>
      </div>
      <div id="content-cards" class="ds-content-examples ds-auto-grid">
        <.design_card id="content-card-default" title="Default card spacing" heading_level={3}>
          <div class="ds-prose">
            <p>Card child spacing, action spacing and padding are separate roles.</p>
            <p>Paragraph spacing continues to use the content role.</p>
          </div>
          <:actions>
            <.text_link href="#content">Review content spacing</.text_link>
            <.text_link href="#type-scale">Compare typography</.text_link>
          </:actions>
        </.design_card>
        <.design_card id="content-card-local" title="Local card spacing" heading_level={3}>
          <div class="ds-prose">
            <p>This card uses smaller child gaps and larger gaps between its wrapping actions.</p>
            <p>Its padding and paragraph rhythm keep their defaults.</p>
          </div>
          <:actions>
            <.text_link href="#content">Hersien inhoudspasiëring</.text_link>
            <.text_link href="#type-scale">Vergelyk tipografie</.text_link>
          </:actions>
        </.design_card>
      </div>
      <p class="ds-note mt-design-lg">
        Internal EN/AF specimens. Prose owns block margins; card layouts own gaps. Add an explicit
        flow wrapper around a nested prose scope when changing its local rhythm. Keep form controls outside prose. Local inputs
        live in the canonical token stylesheet.
      </p>
    </section>
    """
  end
end
