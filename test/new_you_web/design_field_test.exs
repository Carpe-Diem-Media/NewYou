defmodule NewYouWeb.DesignFieldTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias NewYouWeb.Components.Design.{Card, Field}

  test "fields own labels and native error associations and never repopulate passwords" do
    for type <- ~w(text email password), error <- [nil, "Required field"] do
      html =
        render_component(&Field.design_field/1, %{
          :"data-tracking-id" => "field",
          :"phx-blur" => "validate",
          id: "first",
          name: "registration[first_name]",
          label: "First name",
          type: type,
          value: "Retained",
          error: error,
          required: true,
          autocomplete: "given-name"
        })

      dom = LazyHTML.from_fragment(html)
      input = LazyHTML.query(dom, "input#first")

      assert LazyHTML.query(dom, "label[for=first]") |> LazyHTML.text() |> String.trim() ==
               "First name"

      assert LazyHTML.attribute(input, "type") == [type]
      assert LazyHTML.attribute(input, "required") != []
      assert LazyHTML.attribute(input, "data-tracking-id") == ["field"]
      assert LazyHTML.attribute(input, "phx-blur") == ["validate"]

      assert LazyHTML.attribute(input, "value") ==
               if(type == "password", do: [], else: ["Retained"])

      assert LazyHTML.attribute(input, "aria-invalid") == if(error, do: ["true"], else: [])

      assert LazyHTML.attribute(input, "aria-describedby") ==
               if(error, do: ["first-error"], else: [])

      assert LazyHTML.query(dom, "#first-error[role=alert]") |> LazyHTML.text() |> String.trim() ==
               (error || "")
    end
  end

  test "field rejects unsupported types and atom or string visual/native-state collisions" do
    for attrs <- [%{type: "checkbox"}, %{type: "file"}, %{type: nil}] do
      assert_raise ArgumentError, fn ->
        render_component(
          &Field.design_field/1,
          Map.merge(%{id: "field", name: "name", label: "Name"}, attrs)
        )
      end
    end

    for key <-
          ~w(class style id name type value required disabled autofocus aria-label aria-labelledby aria-invalid aria-describedby aria-required),
        key <- [key, String.to_atom(key)] do
      assert_raise ArgumentError, fn ->
        render_component(&Field.design_field/1, %{
          id: "field",
          name: "name",
          label: "Name",
          rest: %{key => "override"}
        })
      end
    end
  end

  test "native disabled, readonly and autofocus flags remain explicit" do
    for state <- [false, true] do
      html =
        render_component(&Field.design_field/1, %{
          id: "native",
          name: "native",
          label: "Native field",
          disabled: state,
          autofocus: state,
          readonly: state
        })

      input = html |> LazyHTML.from_fragment() |> LazyHTML.query("input#native")

      for attribute <- ~w(disabled readonly autofocus) do
        assert LazyHTML.attribute(input, attribute) != [] == state
      end
    end
  end

  test "floating fields own their real label, empty cue and native associations" do
    for type <- ~w(text email password) do
      html =
        render_component(&Field.design_field/1, %{
          id: "floating",
          name: "example[value]",
          label: "Long field label",
          type: type,
          value: "Retained",
          label_placement: "floating",
          help: "Useful help",
          error: "Example error",
          required: true,
          readonly: true
        })

      dom = LazyHTML.from_fragment(html)

      assert LazyHTML.query(dom, "label.ds-floating-control[for=floating] > .ds-floating-label")
             |> LazyHTML.text()
             |> String.trim() == "Long field label"

      input = LazyHTML.query(dom, "label.ds-floating-control > input#floating")
      assert LazyHTML.attribute(input, "placeholder") == [" "]
      assert LazyHTML.attribute(input, "aria-describedby") == ["floating-help floating-error"]
      assert LazyHTML.attribute(input, "readonly") != []

      assert LazyHTML.attribute(input, "value") ==
               if(type == "password", do: [], else: ["Retained"])

      assert length(Regex.scan(~r/<input\b/, html)) == 1
    end
  end

  test "floating placement is finite and cannot lose its component-owned empty cue" do
    for placement <- ["unknown", nil] do
      assert_raise ArgumentError, fn ->
        render_component(&Field.design_field/1, %{
          id: "field",
          name: "field",
          label: "Name",
          label_placement: placement
        })
      end
    end

    for key <- [:placeholder, "placeholder"] do
      assert_raise ArgumentError, fn ->
        render_component(&Field.design_field/1, %{
          id: "field",
          name: "field",
          label: "Name",
          label_placement: "floating",
          rest: %{key => "Example"}
        })
      end
    end

    html =
      render_component(&Field.design_field/1, %{id: "default", name: "default", label: "Name"})

    refute html =~ "ds-floating-control"
    refute html =~ "placeholder="
  end

  test "the guide renders the exact shared floating variant and native state examples" do
    html = render_component(&NewYouWeb.DesignSystemForms.native_forms/1, %{})
    dom = LazyHTML.from_fragment(html)

    for id <-
          ~w(floating-name floating-email floating-password floating-long floating-error floating-readonly floating-disabled-empty floating-disabled-filled) do
      assert LazyHTML.attribute(
               LazyHTML.query(dom, "label.ds-floating-control > input##{id}"),
               "placeholder"
             ) == [" "]
    end

    assert LazyHTML.attribute(LazyHTML.query(dom, "#floating-password"), "value") == []
    assert LazyHTML.attribute(LazyHTML.query(dom, "#floating-disabled"), "disabled") != []
    assert LazyHTML.attribute(LazyHTML.query(dom, "#floating-readonly"), "readonly") != []

    assert LazyHTML.attribute(LazyHTML.query(dom, "#floating-error"), "aria-describedby") == [
             "floating-error-help floating-error-error"
           ]
  end

  test "card can name a real section through its heading id" do
    html =
      render_component(&Card.design_card/1, %{
        :"aria-labelledby" => "registration-heading",
        id: "registration",
        title: "Register",
        heading_level: 2,
        heading_id: "registration-heading",
        inner_block: [%{inner_block: fn _, _ -> "Fields" end}]
      })

    dom = LazyHTML.from_fragment(html)

    assert LazyHTML.query(
             dom,
             "article#registration[aria-labelledby=registration-heading] > h2#registration-heading"
           )
           |> LazyHTML.text()
           |> String.trim() == "Register"
  end
end
