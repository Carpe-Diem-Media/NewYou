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
