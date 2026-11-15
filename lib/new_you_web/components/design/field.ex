defmodule NewYouWeb.Components.Design.Field do
  @moduledoc """
  Native text, email and password field used by the registration pilot and guide.
  The caller supplies already-localized labels/errors. This component owns their
  associations and visual classes; it never validates business input or translates
  copy. Password values are always omitted, including after a failed submission.
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text", values: ~w(text email password)
  attr :value, :any, default: nil
  attr :error, :string, default: nil
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :autofocus, :boolean, default: false
  attr :rest, :global, include: ~w(autocomplete minlength maxlength inputmode pattern readonly)

  @doc "Renders a labelled native field with an optional associated error alert."
  def design_field(assigns) do
    unless assigns.type in ~w(text email password) do
      raise ArgumentError, "unsupported design_field type"
    end

    for key <- Map.keys(assigns.rest),
        to_string(key) in ~w(class style id name type value required disabled autofocus aria-label aria-labelledby aria-invalid aria-describedby aria-required) do
      raise ArgumentError, "design_field does not accept caller-provided #{key}"
    end

    ~H"""
    <div class="ds-design-field">
      <label for={@id}>{@label}</label>
      <input
        id={@id}
        name={@name}
        type={@type}
        value={if @type != "password", do: @value}
        required={@required}
        disabled={@disabled}
        autofocus={@autofocus}
        aria-required={@required && "true"}
        aria-invalid={@error && "true"}
        aria-describedby={@error && "#{@id}-error"}
        class="ds-design-field-input"
        {@rest}
      />
      <p :if={@error} id={"#{@id}-error"} role="alert" class="ds-field-error">{@error}</p>
    </div>
    """
  end
end
