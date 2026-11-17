defmodule NewYouWeb.Components.Design.Field do
  @moduledoc """
  Native fields and choice groups used by the registration pilot and guide.
  Callers supply localized labels and descriptions. This component owns their
  associations and visual classes, but it does not validate input or translate
  copy. Password values stay omitted, and unchecked checkboxes submit no value.
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text", values: ~w(text email password)
  attr :value, :any, default: nil
  attr :label_placement, :string, default: "stacked", values: ~w(stacked floating)
  attr :help, :string, default: nil
  attr :error, :string, default: nil
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :autofocus, :boolean, default: false
  attr :rest, :global, include: ~w(autocomplete minlength maxlength inputmode pattern readonly)

  @doc """
  Renders a labelled native field with optional associated help and error text.
  `label_placement="floating"` opts into an inside label driven by native focus,
  value and autofill state. Its blank placeholder is component-owned. Stacked
  fields remain the default; password values are never rendered back.
  """
  def design_field(assigns) do
    unless assigns.type in ~w(text email password) do
      raise ArgumentError, "unsupported design_field type"
    end

    unless assigns.label_placement in ~w(stacked floating) do
      raise ArgumentError, "unsupported design_field label placement"
    end

    if assigns.label_placement == "floating" and
         Enum.any?(Map.keys(assigns.rest), &(to_string(&1) == "placeholder")) do
      raise ArgumentError, "floating design_field owns its placeholder"
    end

    for key <- Map.keys(assigns.rest),
        to_string(key) in ~w(class style id name type value required disabled autofocus aria-disabled aria-label aria-labelledby aria-invalid aria-describedby aria-required) do
      raise ArgumentError, "design_field does not accept caller-provided #{key}"
    end

    ~H"""
    <div
      class="ds-design-field"
      data-label-placement={if @label_placement == "floating", do: "floating"}
    >
      <label :if={@label_placement == "stacked"} for={@id}>{@label}</label>
      <label :if={@label_placement == "floating"} for={@id} class="ds-floating-control">
        <span class="ds-floating-label">{@label}</span>
        <.native_field_input {assigns} />
      </label>
      <.native_field_input :if={@label_placement == "stacked"} {assigns} />
      <p :if={@help} id={"#{@id}-help"} class="ds-field-help">{@help}</p>
      <p :if={@error} id={"#{@id}-error"} role="alert" class="ds-field-error">{@error}</p>
    </div>
    """
  end

  defp native_field_input(assigns) do
    ~H"""
    <input
      id={@id}
      name={@name}
      type={@type}
      value={if @type != "password", do: @value}
      required={@required}
      disabled={@disabled}
      autofocus={@autofocus}
      placeholder={if @label_placement == "floating", do: " "}
      aria-required={@required && "true"}
      aria-invalid={@error && "true"}
      aria-describedby={description_ids(@id, @help, @error)}
      class="ds-design-field-input"
      {@rest}
    />
    """
  end

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, default: "true"
  attr :checked, :boolean, default: false
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :help, :string, default: nil
  attr :error, :string, default: nil
  attr :rest, :global
  slot :actions

  @doc "Renders one native checkbox. The caller owns localized text and form state; an unchecked box submits no value."
  def design_checkbox(assigns) do
    assert_no_attribute_collisions!(assigns.rest, checkbox_owned_attributes(), "design_checkbox")

    ~H"""
    <div id={"#{@id}-field"} class="ds-design-field ds-design-choice">
      <div class="ds-row">
        <label for={@id} class="ds-design-check">
          <input
            id={@id}
            name={@name}
            type="checkbox"
            value={@value}
            checked={@checked}
            required={@required}
            disabled={@disabled}
            aria-required={@required && "true"}
            aria-invalid={@error && "true"}
            aria-describedby={description_ids(@id, @help, @error)}
            class="ds-design-checkbox"
            {@rest}
          />
          <span>{@label}</span>
        </label>
        {render_slot(@actions)}
      </div>
      <p :if={@help} id={"#{@id}-help"} class="ds-field-help">{@help}</p>
      <p :if={@error} id={"#{@id}-error"} role="alert" class="ds-field-error">{@error}</p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :legend, :string, required: true
  attr :help, :string, default: nil
  attr :error, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders a native fieldset. The caller supplies its legend, contents and localized descriptions."
  def design_fieldset(assigns) do
    assert_no_attribute_collisions!(assigns.rest, fieldset_owned_attributes(), "design_fieldset")

    ~H"""
    <fieldset
      id={@id}
      class="ds-design-field ds-design-fieldset"
      disabled={@disabled}
      aria-invalid={@error && "true"}
      aria-describedby={description_ids(@id, @help, @error)}
      {@rest}
    >
      <legend id={"#{@id}-legend"} class="font-design-medium">{@legend}</legend>
      {render_slot(@inner_block)}
      <p :if={@help} id={"#{@id}-help"} class="ds-field-help">{@help}</p>
      <p :if={@error} id={"#{@id}-error"} role="alert" class="ds-field-error">{@error}</p>
    </fieldset>
    """
  end

  defp description_ids(id, help, error) do
    [if(help, do: "#{id}-help"), if(error, do: "#{id}-error")]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      ids -> Enum.join(ids, " ")
    end
  end

  defp assert_no_attribute_collisions!(rest, owned, component) do
    for key <- Map.keys(rest), to_string(key) in owned do
      raise ArgumentError, "#{component} does not accept caller-provided #{key}"
    end
  end

  defp checkbox_owned_attributes do
    ~w(class style id name type value checked required disabled role aria-checked aria-disabled aria-label aria-labelledby aria-invalid aria-describedby aria-required)
  end

  defp fieldset_owned_attributes do
    ~w(class style id disabled role aria-disabled aria-label aria-labelledby aria-invalid aria-describedby)
  end
end
