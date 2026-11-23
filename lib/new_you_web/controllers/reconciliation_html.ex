defmodule NewYouWeb.ReconciliationHTML do
  @moduledoc false
  use NewYouWeb, :html

  import NewYouWeb.SignInComponents
  import NewYouWeb.Components.Design.Button, only: [primary_button: 1, secondary_button: 1]

  embed_templates "reconciliation_html/*"

  attr :prefix, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :maximum, :integer, default: 36

  defp field(assigns) do
    ~H"""
    <div class="grid min-w-0 gap-design-xs">
      <label for={@prefix <> "-" <> @name} class="text-design-body-sm font-design-bold">
        {@label}
      </label>
      <input
        id={@prefix <> "-" <> @name}
        name={@name}
        type={@type}
        maxlength={@maximum}
        autocomplete="off"
        inputmode={if @name == "code", do: "numeric"}
        pattern={if @name == "code", do: "[0-9]{6}"}
        spellcheck="false"
        required
        class="h-design-input-height w-full min-w-0 rounded-design-sm border border-design-ink-muted bg-design-surface px-design-base py-design-sm text-design-body-sm text-design-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-design-primary"
      />
    </div>
    """
  end

  attr :prefix, :string, required: true

  defp step_up_fields(assigns) do
    ~H"""
    <.field prefix={@prefix} name="password" label="Your password" type="password" maximum={1024} />
    <.field prefix={@prefix} name="code" label="Your authenticator code" maximum={6} />
    """
  end

  attr :prefix, :string, required: true

  defp grant_fields(assigns) do
    ~H"""
    <.field prefix={@prefix} name="grant_id" label="Candidate Support grant ID" />
    <.field prefix={@prefix} name="canonical_grant_id" label="Canonical Support grant ID" />
    """
  end

  defp status_label(:detected), do: "Detected"
  defp status_label(:candidate), do: "Candidate"
  defp status_label(:review), do: "In review"
  defp status_label(:approved), do: "Approved"
  defp status_label(:conflict), do: "Conflict recorded"
  defp status_label(:rejected), do: "Rejected"
  defp status_label(:applied), do: "Applied"
end
