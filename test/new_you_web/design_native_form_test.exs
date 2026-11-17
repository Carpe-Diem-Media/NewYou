defmodule NewYouWeb.DesignNativeFormTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias NewYouWeb.Components.Design.Field

  test "field help precedes an error in the native description association" do
    html =
      render_component(&Field.design_field/1, %{
        id: "email",
        name: "email",
        label: "Email",
        help: "Use your work address",
        error: "Enter a valid address"
      })

    assert html =~ ~s(aria-describedby="email-help email-error")
    assert Regex.match?(~r/<p\b[^>]*id="email-help"[^>]*>Use your work address<\/p>/, html)

    assert Regex.match?(
             ~r/<p\b[^>]*id="email-error"[^>]*role="alert"[^>]*>Enter a valid address<\/p>/,
             html
           )
  end

  test "field keeps no-help descriptions and omits password values" do
    for type <- ["text", "password"] do
      html =
        render_component(&Field.design_field/1, %{
          id: "secret",
          name: "secret",
          label: "Secret",
          type: type,
          value: "do not retain",
          error: "Required"
        })

      assert html =~ ~s(aria-describedby="secret-error")
      refute html =~ "secret-help"
      assert html =~ ~s(value="do not retain") == (type == "text")
    end
  end

  test "checkbox owns native state and associations while keeping actions outside its label" do
    html =
      render_component(&Field.design_checkbox/1, %{
        "data-track" => "terms",
        "phx-click" => "track",
        id: "terms",
        name: "registration[terms]",
        label: "I agree",
        checked: true,
        required: true,
        disabled: true,
        help: "Review the terms",
        error: "Consent is required",
        actions: [%{inner_block: fn _, _ -> "Read terms" end}]
      })

    assert Regex.match?(
             ~r/<div\b[^>]*id="terms-field"[^>]*class="ds-design-field ds-design-choice"/,
             html
           )

    assert [input] = Regex.run(~r/<input\b([^>]*)>/, html, capture: :all_but_first)
    assert input =~ ~s(id="terms")
    assert input =~ ~s(name="registration[terms]")
    assert input =~ ~s(type="checkbox")
    assert input =~ ~s(value="true")
    assert input =~ " checked"
    assert input =~ " required"
    assert input =~ " disabled"
    assert input =~ ~s(class="ds-design-checkbox")
    assert input =~ ~s(data-track="terms")
    assert input =~ ~s(phx-click="track")
    assert html =~ ~s(aria-describedby="terms-help terms-error")
    assert Regex.match?(~r/<p\b[^>]*id="terms-help"[^>]*>Review the terms<\/p>/, html)

    assert Regex.match?(
             ~r/<p\b[^>]*id="terms-error"[^>]*role="alert"[^>]*>Consent is required<\/p>/,
             html
           )

    assert [label] = Regex.run(~r/<label\b.*?<\/label>/s, html)
    assert Regex.match?(~r/<span\b[^>]*>I agree<\/span>\s*<\/label>/s, html)
    assert html =~ ~s(Read terms)
    refute label =~ "Read terms"
    refute html =~ ~s(type="hidden")
    assert length(Regex.scan(~r/type="checkbox"/, html)) == 1
  end

  test "checkbox omits false native flags and defaults its value" do
    html =
      render_component(&Field.design_checkbox/1, %{
        id: "updates",
        name: "updates",
        label: "Send updates"
      })

    assert html =~ ~s(type="checkbox" value="true")

    for flag <- ~w(checked required disabled aria-required aria-invalid aria-describedby) do
      refute html =~ flag <> "="
    end
  end

  test "checkbox rejects owned visual, native and ARIA attributes in atom and string keys" do
    for key <-
          ~w(class style id name type value checked required disabled role aria-checked aria-disabled aria-label aria-labelledby aria-invalid aria-describedby aria-required),
        key <- [key, String.to_atom(key)] do
      assert_raise ArgumentError, fn ->
        render_component(&Field.design_checkbox/1, %{
          id: "check",
          name: "check",
          label: "Check",
          rest: %{key => "override"}
        })
      end
    end
  end

  test "fieldset owns legend and disabled semantics and associates help and error" do
    html =
      render_component(&Field.design_fieldset/1, %{
        id: "contact",
        legend: "Contact preferences",
        help: "Choose how we can reach you",
        error: "Choose at least one option",
        disabled: true,
        inner_block: [%{inner_block: fn _, _ -> "Choices" end}]
      })

    assert [fieldset] = Regex.run(~r/<fieldset\b([^>]*)>/, html, capture: :all_but_first)
    assert fieldset =~ ~s(id="contact")
    assert fieldset =~ ~s(class="ds-design-field ds-design-fieldset")
    assert fieldset =~ " disabled"
    assert fieldset =~ ~s(aria-describedby="contact-help contact-error")

    assert Regex.match?(
             ~r/<legend\b[^>]*id="contact-legend"[^>]*class="font-design-medium">Contact preferences<\/legend>/,
             html
           )

    assert html =~ ~s(Choices)

    assert Regex.match?(
             ~r/<p\b[^>]*id="contact-help"[^>]*>Choose how we can reach you<\/p>/,
             html
           )

    assert Regex.match?(
             ~r/<p\b[^>]*id="contact-error"[^>]*role="alert"[^>]*>Choose at least one option<\/p>/,
             html
           )
  end

  test "fieldset rejects owned visual, native and ARIA attributes in atom and string keys" do
    for key <-
          ~w(class style id disabled role aria-disabled aria-label aria-labelledby aria-invalid aria-describedby),
        key <- [key, String.to_atom(key)] do
      assert_raise ArgumentError, fn ->
        render_component(&Field.design_fieldset/1, %{
          id: "set",
          legend: "Set",
          inner_block: [%{inner_block: fn _, _ -> "Choices" end}],
          rest: %{key => "override"}
        })
      end
    end
  end

  test "text field native disabled state cannot be contradicted by forwarded ARIA" do
    for key <- ["aria-disabled", :"aria-disabled"] do
      assert_raise ArgumentError, fn ->
        render_component(&Field.design_field/1, %{
          id: "native",
          name: "native",
          label: "Native field",
          disabled: true,
          rest: %{key => "false"}
        })
      end
    end
  end
end
