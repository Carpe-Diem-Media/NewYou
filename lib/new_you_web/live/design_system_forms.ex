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
