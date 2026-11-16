defmodule NewYouWeb.DesignSystemForms do
  @moduledoc "Internal native-form specimens rendered with the production field helpers."
  use Phoenix.Component
  import NewYouWeb.Components.Design.Field
  import NewYouWeb.Components.Design.Link

  def native_forms(assigns) do
    ~H"""
    <section id="native-forms" aria-labelledby="native-forms-title">
      <div class="ds-section-heading">
        <h2 id="native-forms-title">Native form contracts</h2>
        <p>Shared labels, descriptions and native states, using the registration components.</p>
      </div>
      <div class="ds-form-examples ds-auto-grid">
        <div class="ds-form-example">
          <.design_fieldset
            id="forms-ready"
            legend="Labels and descriptions"
            help="Each control keeps its own label and descriptions."
          >
            <.design_checkbox
              id="forms-choice"
              name="example[choice]"
              label="Review this longer English practice option before selecting it. The complete label remains clickable as it wraps."
              help="This is an internal example with a required native checkbox."
              required
            >
              <:actions>
                <.text_link id="forms-choice-action" href="#native-forms">Review example</.text_link>
              </:actions>
            </.design_checkbox>
            <div lang="af">
              <.design_checkbox
                id="forms-choice-checked"
                name="example[checked]"
                label="Hierdie voorbeeld is reeds gemerk. Die blaaier beheer die merkie en sleutelbordgedrag."
                checked
              />
              <.design_checkbox
                id="forms-choice-invalid"
                name="example[invalid]"
                label="Merk hierdie oefenopsie nadat jy die langer Afrikaanse beskrywing gelees het."
                help="Hulp bly voor die fout in die beskrywingvolgorde."
                error="Hierdie voorbeeld wys 'n verpligte opsie wat nog nie gemerk is nie."
                required
              />
            </div>
            <.design_field
              id="forms-email"
              name="example[email]"
              label="Email example"
              type="email"
              help="Associated help uses the same shared field contract."
            />
          </.design_fieldset>
        </div>
        <div class="ds-form-example">
          <.design_fieldset
            id="forms-busy"
            legend="Caller-owned busy state"
            help="The caller disables this group while its own operation is busy."
            disabled
            aria-busy="true"
          >
            <.design_checkbox
              id="forms-busy-choice"
              name="example[busy_choice]"
              label="The native fieldset disables this checkbox without an extra per-control flag."
              checked
            />
            <.design_field
              id="forms-busy-text"
              name="example[busy_text]"
              label="Disabled through the fieldset"
              value="Existing text remains visible"
            />
          </.design_fieldset>
        </div>
        <div class="ds-form-example">
          <.design_fieldset
            id="forms-local"
            legend="Local spacing inputs"
            help="This example changes existing field and choice gaps independently."
          >
            <.design_checkbox
              id="forms-local-choice"
              name="example[local]"
              label="A local description gap uses another existing spacing token."
              help="The choice gap stays separate from fieldset and control-row spacing."
              error="Example error text remains associated with this checkbox."
            />
          </.design_fieldset>
        </div>
      </div>
      <section id="floating-labels" aria-labelledby="floating-labels-title" class="mt-design-xl">
        <div class="ds-section-heading">
          <h3 id="floating-labels-title">Floating labels</h3>
          <p>
            Guide-only variant. Focus a field, enter a value, then leave it to compare label positions.
          </p>
        </div>
        <div class="ds-form-examples ds-auto-grid">
          <div class="ds-form-example">
            <.design_fieldset
              id="floating-en"
              legend="English"
              help="Empty labels rest inside. Filled labels stay raised."
            >
              <.design_field
                id="floating-name"
                name="floating[name]"
                label="Full name"
                label_placement="floating"
                autocomplete="name"
              />
              <.design_field
                id="floating-email"
                name="floating[email]"
                label="Email address"
                type="email"
                label_placement="floating"
                autocomplete="email"
                value="example@example.com"
                help="The label remains visible after focus leaves."
              />
              <.design_field
                id="floating-password"
                name="floating[password]"
                label="Password"
                type="password"
                label_placement="floating"
                autocomplete="new-password"
                help="Passwords are never rendered back from server values."
              />
            </.design_fieldset>
          </div>
          <div class="ds-form-example" lang="af">
            <.design_fieldset
              id="floating-af"
              legend="Afrikaans"
              help="Lang etikette behou hul eie plek bo die waarde."
            >
              <.design_field
                id="floating-long"
                name="floating[long]"
                label="Volledige naam soos jy dit op jou rekening wil sien"
                label_placement="floating"
                value="Voorbeeldnaam"
              />
              <.design_field
                id="floating-error"
                name="floating[error]"
                label="E-posadres"
                type="email"
                label_placement="floating"
                help="Hierdie is slegs 'n voorbeeld in die stylgids."
                error="Voer 'n geldige e-posadres in."
                required
              />
              <.design_field
                id="floating-readonly"
                name="floating[readonly]"
                label="Leesalleen-voorbeeld"
                label_placement="floating"
                value="Bestaande waarde"
                readonly
              />
            </.design_fieldset>
          </div>
          <div class="ds-form-example">
            <.design_fieldset id="floating-disabled" legend="Disabled group" disabled aria-busy="true">
              <.design_field
                id="floating-disabled-empty"
                name="floating[disabled_empty]"
                label="Empty disabled field"
                label_placement="floating"
              />
              <.design_field
                id="floating-disabled-filled"
                name="floating[disabled_filled]"
                label="Filled disabled field"
                label_placement="floating"
                value="Existing value"
              />
            </.design_fieldset>
          </div>
        </div>
        <p class="ds-note mt-design-lg">
          Use <code>label_placement="floating"</code>
          on the shared field component. Stacked labels
          remain the default. Edit <code>--field-label-size</code>, <code>--field-padding-inline</code>,
          <code>--field-padding-block</code>
          and <code>--field-label-duration</code>
          in canonical CSS.
          Labels remain real labels; the blank placeholder only supplies an empty-value cue.
          Long labels grow the control. Reduced motion removes label transitions.
        </p>
      </section>
      <dl class="ds-form-readouts mt-design-lg">
        <div>
          <dt><code>--field-gap</code> local fieldset</dt><dd>
            <output data-measure-target="forms-local" data-measure-property="row-gap">Measured in browser</output>
          </dd>
        </div>
        <div>
          <dt><code>--choice-gap</code> local descriptions</dt><dd>
            <output data-measure-target="forms-local-choice-field" data-measure-property="row-gap">Measured in browser</output>
          </dd>
        </div>
        <div>
          <dt>Native checkbox width</dt><dd>
            <output data-measure-target="forms-choice" data-measure-property="width">Measured in browser</output>
          </dd>
        </div>
      </dl>
      <p class="ds-note mt-design-lg">
        These examples use native checked, required and disabled behavior. Busy state is a caller-owned
        projection, not a new component lifecycle. Labels and help/error text are supplied by callers.
        Related links stay outside checkbox labels. Unchecked boxes have no hidden companion value.
      </p>
      <p class="ds-note mt-design-lg">
        The current registration consumer needs checkboxes and a fieldset. Radios, selects, textareas
        and an error-summary contract remain deferred until a real consumer requires them.
      </p>
    </section>
    """
  end
end
