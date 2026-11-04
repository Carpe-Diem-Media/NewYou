defmodule NewYouWeb.Security.HTMLAttributesTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML, only: [attributes_escape: 1, safe_to_string: 1]

  @invalid_names ["", "x onmouseover", "x\"", "x'", "x>", "x/", "x="] ++
                   Enum.map(0..31, &"x#{<<&1>>}y") ++ ["x\x7Fy"]

  test "the direct requirement excludes the vulnerable 4.x line" do
    {:phoenix_html, requirement} = List.keyfind(Mix.Project.config()[:deps], :phoenix_html, 0)
    assert Version.match?("4.4.0", requirement)
    refute Version.match?("4.3.0", requirement)
    refute Version.match?("4.0.0", requirement)
  end

  test "malformed binary and iodata names fail closed, including nested namespaces" do
    for name <- @invalid_names,
        key <- if(name in ["x\"", "x'", "x>"], do: [name], else: [name, [name]]),
        attrs <- [
          [{key, "payload"}],
          [{key, true}],
          [data: [{key, "payload"}]],
          [aria: [{key, true}]],
          [phx: [value: [{key, "payload"}]]],
          [{"data", [{key, [child: "payload"]}]}],
          [{"aria", [{key, "payload"}]}],
          [{"phx", [{key, "payload"}]}]
        ] do
      assert_raise ArgumentError, ~r/expected attribute name/, fn -> attributes_escape(attrs) end
    end
  end

  test "iodata quote and closing-delimiter names render as escaped name bytes" do
    # The Safe protocol escapes these bytes before upstream name validation.
    for {name, escaped} <- [{"x\"", "x&quot;"}, {"x'", "x&#39;"}, {"x>", "x&gt;"}] do
      assert safe_to_string(attributes_escape([{[name], "value"}])) ==
               ~s( #{escaped}="value")

      assert safe_to_string(attributes_escape(data: [{[name], "value"}])) ==
               ~s( data-#{escaped}="value")
    end
  end

  test "valid binary, iodata and nested names render while hostile values are escaped" do
    hostile = ~s("'><script>&)
    escaped = "&quot;&#39;&gt;&lt;script&gt;&amp;"

    for key <- ["title", ["ti", ~c"tle"]] do
      assert safe_to_string(attributes_escape([{key, hostile}])) == ~s( title="#{escaped}")
    end

    assert safe_to_string(
             attributes_escape(
               data: [user_id: "42"],
               aria: [label: hostile],
               phx: [value: [id: "42"]]
             )
           ) ==
             ~s( data-user-id="42" aria-label="#{escaped}" phx-value-id="42")
  end

  test "trusted atom and explicit safe names bypass upstream validation" do
    # These are literal test fixtures, never names derived from a request.
    # NewYou's request-boundary tests cover exclusion of untrusted names.
    for key <- [:"x onmouseover", {:safe, "x onmouseover"}] do
      assert safe_to_string(attributes_escape([{key, "payload"}])) ==
               ~s( x onmouseover="payload")
    end
  end
end
