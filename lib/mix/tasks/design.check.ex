defmodule Mix.Tasks.Design.Check do
  @moduledoc "Rejects new design bypasses in changed Phoenix frontend and asset source."
  use Mix.Task

  @shortdoc "Checks changed frontend code against DESIGN.md"
  @double_class ~r/(?<![\w:-])class\s*=\s*"((?:\\.|[^"\\])*)"/s
  @single_class ~r/(?<![\w:-])class\s*=\s*'((?:\\.|[^'\\])*)'/s
  @class_expr_start ~r/(?<![\w:-])class\s*=\s*\{/
  @double_quoted ~r/"((?:\\.|[^"\\])*)"/s
  @single_quoted ~r/'((?:\\.|[^'\\])*)'/s
  @apply ~r/@apply\s+([^;{}]+);?/s
  @js_class ~r/(?:classList\.(?:add|remove|toggle)|className\s*=|setAttribute\(\s*["']class["']\s*,)\s*\(?\s*["']([^"']*)["']/

  @class_rules [
    {:arbitrary,
     ~r/^(?:bg|text|border|outline|ring|fill|stroke|font|leading|tracking|rounded|shadow|p|px|py|pt|pr|pb|pl|m|mx|my|mt|mr|mb|ml|gap|gap-x|gap-y|space-x|space-y)-(?:\[[^\]]+\]|\([^)]+\))$/,
     "arbitrary visual utility is forbidden by default"},
    {:palette,
     ~r/^(?:bg|text|border|outline|ring|fill|stroke|divide|from|via|to)-(?:black|white|transparent|current|inherit|(?:red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|slate|gray|zinc|neutral|stone)-(?:50|100|200|300|400|500|600|700|800|900|950))(?:\/\d{1,3})?$/,
     "default Tailwind palette bypasses project tokens"},
    {:daisyui,
     ~r/^(?:btn|card|badge|alert|input|select|textarea|toggle|checkbox|radio|modal|navbar|menu|tabs?|drawer|dropdown|tooltip|toast|join|avatar|form-control|collapse)(?:-|$)/,
     "DaisyUI classes are legacy-only"},
    {:daisyui_color,
     ~r/^(?:bg|text|border)-(?:primary|primary-content|secondary|secondary-content|accent|accent-content|neutral|neutral-content|base-(?:100|200|300|content)|info|info-content|success|success-content|warning|warning-content|error|error-content)$/,
     "DaisyUI colors are legacy-only"},
    {:visual,
     ~r/^(?:text-(?:xs|sm|base|lg|xl|[2-9]xl)|font-(?:sans|serif|mono|thin|extralight|light|normal|medium|semibold|bold|extrabold|black)|leading-(?:none|tight|snug|normal|relaxed|loose|[3-9]|10)|tracking-(?:tighter|tight|normal|wide|wider|widest)|p[xytrblse]?-(?:px|\d+(?:\.\d+)?)|m[xytrblse]?-(?:px|\d+(?:\.\d+)?)|gap(?:-[xy])?-(?:px|\d+(?:\.\d+)?)|space-[xy]-(?:px|\d+(?:\.\d+)?)|rounded(?:-(?:none|sm|md|lg|xl|2xl|3xl|full))?|(?:drop-)?shadow(?:-(?:2xs|xs|sm|md|lg|xl|2xl))?|opacity-\d+|(?:bg|text|border|fill|stroke)-design-[\w-]+\/\d+)$/,
     "default Tailwind visual utility bypasses project tokens"}
  ]

  @default_breakpoint ~r/^(?:sm|md|lg|xl|2xl|min-\[[^\]]+\]|max-\[[^\]]+\])$/
  @css_property ~r/(?:^|[;{])\s*(background(?:-color)?|color|border(?:-(?:top|right|bottom|left|inline|block))?(?:-(?:color|width|radius))?|outline(?:-(?:color|width))?|box-shadow|font-(?:family|size|weight|style)|line-height|letter-spacing|text-transform|padding(?:-(?:top|right|bottom|left|inline|block))?|margin(?:-(?:top|right|bottom|left|inline|block))?|(?:row-|column-)?gap|height|min-height)\s*:\s*([^;}]+)/i
  @css_variable ~r/(--[\w-]+)\s*:\s*([^;]+);/s
  @raw_value ~r/(?:#[0-9a-fA-F]{3,8}\b|\b(?:rgb|rgba|hsl|hsla|oklch|oklab)\s*\(|\b(?:black|white|red|green|blue|orange|purple)\b|(?:^|\s)-?\d+(?:\.\d+)?(?:px|rem|em|vw|vh|%)\b|^\d+(?:\.\d+)?$)/i
  @media_width ~r/(@(?:media|container)\b[^{}]*\b(?:min-width|max-width)\s*:[^{}]*|@(?:media|container)\b[^{}]*\bwidth\s*(?:>=|<=|>|<)[^{}]*)/is
  @style_attribute ~r/(?<![\w:-])style\s*=\s*(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\{)/is
  @raw_color_attribute ~r/(?<![\w:-])(?:fill|stroke|color|bgcolor|background)\s*=\s*["']\s*#[0-9a-fA-F]{3,8}\b/i
  @daisyui_selector ~r/\.(?:btn|card|badge|alert|input|select|textarea|toggle|checkbox|radio|modal|navbar|menu|tabs?|drawer|dropdown|tooltip|toast|join|avatar|form-control|collapse)(?:-|[,:.\s{])/i
  @js_style ~r/\.style\.(color|backgroundColor|borderColor|borderRadius|boxShadow|fontSize|fontFamily|fontWeight|letterSpacing|padding|margin)\s*=\s*["']([^"']*)["']/
  @frozen_token ~r/^[ \t]*(--ny-[\w-]+)\s*:\s*([^\n;]+)/m
  @primary_fill_paths [
    "lib/new_you_web/components/design/button.ex",
    "lib/new_you_web/components/design/enterprise_band.ex"
  ]

  @doc false
  def run(_args) do
    base = base_revision!()
    changed = changed_paths!(base)
    design = File.read!("DESIGN.md")
    tokens = File.read!("assets/css/design-tokens.css")

    errors =
      token_color_violations(design, tokens) ++
        token_authority_violations(
          "DESIGN.md" in changed,
          "assets/css/design-tokens.css" in changed
        ) ++
        Enum.flat_map(Enum.filter(changed, &frontend_source?/1), fn path ->
          new_violations(path, git_file(base, path), File.read!(path))
        end)

    if errors == [] do
      Mix.shell().info("Design-system check passed (base #{String.slice(base, 0, 12)}).")
    else
      Mix.raise("Design-system check failed:\n" <> Enum.map_join(errors, "\n", &"  - #{&1}"))
    end
  end

  @doc false
  def violations(path, source), do: scan(path, source) |> Enum.map(& &1.message) |> Enum.sort()

  @doc false
  def new_violations(path, baseline, current) do
    prior = baseline |> then(&scan(path, &1)) |> Enum.frequencies_by(& &1.key)

    current
    |> then(&scan(path, &1))
    |> Enum.group_by(& &1.key)
    |> Enum.flat_map(fn {key, findings} -> Enum.drop(findings, Map.get(prior, key, 0)) end)
    |> Enum.map(& &1.message)
    |> Enum.sort()
  end

  @doc false
  def token_color_violations(design, css) do
    expected =
      Regex.scan(~r/^  ([\w-]+):\s*"(#[0-9a-fA-F]{3,8})"\s*$/m, design, capture: :all_but_first)
      |> Map.new(fn [name, color] -> {name, String.downcase(color)} end)

    variables =
      Regex.scan(@css_variable, css, capture: :all_but_first)
      |> Map.new(fn [name, value] -> {name, String.trim(value)} end)

    actual =
      variables
      |> Enum.filter(fn {name, _value} -> String.starts_with?(name, "--color-design-") end)
      |> Map.new(fn {name, _value} ->
        {String.replace_prefix(name, "--color-design-", ""), resolve_color(name, variables, [])}
      end)

    missing =
      Enum.flat_map(expected, fn {name, value} ->
        if actual[name] == value, do: [], else: ["color token #{name} does not match DESIGN.md"]
      end)

    missing ++
      Enum.map(
        Map.keys(actual) -- Map.keys(expected),
        &"unapproved color token --color-design-#{&1}"
      )
  end

  defp resolve_color(name, variables, visited) do
    if name in visited do
      nil
    else
      resolve_color_value(Map.get(variables, name), variables, [name | visited])
    end
  end

  defp resolve_color_value(nil, _variables, _visited), do: nil

  defp resolve_color_value(value, variables, visited) do
    reference =
      Regex.run(~r/^var\((--[\w-]+)\)$/, value, capture: :all_but_first) ||
        Regex.run(~r/^oklch\(from var\((--[\w-]+)\) l c h\)$/, value, capture: :all_but_first)

    case reference do
      [name] -> resolve_color(name, variables, visited)
      _ -> String.downcase(value)
    end
  end

  @doc false
  def token_authority_violations(authority_changed?, tokens_changed?) do
    if tokens_changed? and not authority_changed?,
      do: ["design-tokens.css changed without a DESIGN.md authority change"],
      else: []
  end

  defp scan(path, source) do
    classes(path, source) ++ styles(path, source)
  end

  defp classes(path, source) do
    expressions = class_expressions(source)

    static =
      (capture_matches(@double_class, source) ++ capture_matches(@single_class, source))
      |> Enum.reject(fn [{_value, offset}] -> inside_class_expression?(offset, expressions) end)

    static_findings =
      Enum.flat_map(static, fn [{value, offset}] ->
        check_classes(path, value, line_number(source, offset))
      end)

    expression_findings =
      Enum.flat_map(expressions, fn expression ->
        strings = quoted_strings(expression.source)

        class_findings =
          Enum.flat_map(strings, fn {value, offset} ->
            check_classes(path, value, line_number(source, expression.content_offset + offset))
          end)

        rest = strip_quoted_strings(expression.source) |> String.replace(~r/[\s\[\],]/, "")

        dynamic_findings =
          if strings == [] or rest != "" or not expression.closed?,
            do:
              issue(
                :dynamic_class,
                :dynamic_class,
                path,
                line_number(source, expression.attribute_offset)
              ),
            else: []

        class_findings ++ dynamic_findings
      end)

    static_findings ++ expression_findings
  end

  defp check_classes(path, value, number) do
    value
    |> String.split(~r/\s+/, trim: true)
    |> Enum.flat_map(&check_class(path, &1, number))
  end

  defp check_class(path, token, number) do
    [utility | variants] = token |> String.split(":") |> Enum.reverse()
    utility = utility |> String.trim_leading("!") |> String.trim_leading("-")

    rule =
      Enum.find(@class_rules, fn {_kind, pattern, _reason} -> Regex.match?(pattern, utility) end)

    rule_issue = if rule, do: issue(elem(rule, 0), token, path, number), else: []
    state_issue = state_issue(path, token, utility, Enum.reverse(variants), number)
    rule_issue ++ state_issue
  end

  defp state_issue(path, token, utility, variants, number) do
    checks = [
      {Enum.any?(variants, &Regex.match?(@default_breakpoint, &1)), :breakpoint},
      {utility == "outline-none", :focus},
      {primary_fill?(path, utility), :primary_fill},
      {primary_deep?(path, utility, variants), :primary_deep},
      {dark_token?(utility, variants), :dark_token},
      {legacy_token?(utility, variants), :legacy_token}
    ]

    Enum.find_value(checks, [], fn
      {true, state} -> issue(state, token, path, number)
      _ -> nil
    end)
  end

  defp primary_fill?(path, utility),
    do: utility == "bg-design-primary" and path not in @primary_fill_paths

  defp primary_deep?(path, utility, variants),
    do: utility == "bg-design-primary-deep" and not primary_interaction?(path, variants)

  defp dark_token?(utility, variants),
    do:
      "dark" in variants and
        String.starts_with?(utility, ["bg-design-", "text-design-", "border-design-"])

  defp primary_interaction?(path, variants),
    do:
      path == "lib/new_you_web/components/design/button.ex" and
        Enum.any?(variants, &(&1 in ["hover", "active"]))

  defp legacy_token?(utility, variants) do
    case Regex.run(~r/(?:^|-)ny-([a-z][a-z0-9-]*)$/, utility, capture: :all_but_first) do
      [name] ->
        known =
          File.read!("assets/css/tokens.css")
          |> then(
            &Regex.scan(~r/--(?:color|font|text)-ny-([\w-]+):/, &1, capture: :all_but_first)
          )
          |> List.flatten()

        allowed = "dark" in variants or String.contains?(name, ["error", "focus"])
        name not in known or not allowed

      _ ->
        false
    end
  end

  defp styles(path, source) do
    classes =
      if Path.extname(path) == ".css",
        do: capture_matches(@apply, source),
        else: if(Path.extname(path) == ".js", do: capture_matches(@js_class, source), else: [])

    class_findings =
      Enum.flat_map(classes, fn [{value, offset}] ->
        check_classes(path, value, line_number(source, offset))
      end)

    class_findings ++ css_findings(path, source)
  end

  defp css_findings(path, source) do
    raw_css_findings(path, source) ++
      custom_variable_findings(path, source) ++
      inline_style_findings(path, source) ++
      raw_color_attribute_findings(path, source) ++
      daisyui_selector_findings(path, source) ++
      js_style_findings(path, source) ++
      breakpoint_findings(path, source) ++
      frozen_token_findings(path, source)
  end

  defp raw_css_findings(path, source) do
    capture_matches(@css_property, source)
    |> Enum.flat_map(fn [{property, _property_offset}, {value, value_offset}] ->
      value = String.trim(value)

      if path == "assets/css/design-tokens.css" or approved_css?(value),
        do: [],
        else: issue(:raw_css, {property, value}, path, line_number(source, value_offset))
    end)
  end

  defp custom_variable_findings(path, source) do
    if path == "assets/css/design-tokens.css" do
      []
    else
      capture_matches(@css_variable, source)
      |> Enum.flat_map(fn [{name, offset}, {value, _value_offset}] ->
        issue(:raw_css_variable, {name, String.trim(value)}, path, line_number(source, offset))
      end)
    end
  end

  defp inline_style_findings(path, source) do
    full_matches(@style_attribute, source)
    |> Enum.flat_map(fn {match, offset} ->
      value = style_attribute_value(source, match, offset)
      issue(:inline_style, value, path, line_number(source, offset))
    end)
  end

  defp raw_color_attribute_findings(path, source) do
    if Path.extname(path) in [".ex", ".heex"] do
      full_matches(@raw_color_attribute, source)
      |> Enum.flat_map(fn {match, offset} ->
        issue(:raw_css, match, path, line_number(source, offset))
      end)
    else
      []
    end
  end

  defp daisyui_selector_findings(path, source) do
    if Path.extname(path) == ".css" do
      full_matches(@daisyui_selector, source)
      |> Enum.flat_map(fn {match, offset} ->
        issue(:daisyui, match, path, line_number(source, offset))
      end)
    else
      []
    end
  end

  defp js_style_findings(path, source) do
    if Path.extname(path) == ".js" do
      capture_matches(@js_style, source)
      |> Enum.flat_map(fn [{property, offset}, {value, _value_offset}] ->
        issue(:inline_style, {property, value}, path, line_number(source, offset))
      end)
    else
      []
    end
  end

  defp breakpoint_findings(path, source) do
    if Path.extname(path) == ".css" do
      capture_matches(@media_width, source)
      |> Enum.flat_map(&breakpoint_issue(path, source, &1))
    else
      []
    end
  end

  defp breakpoint_issue(path, source, [{query, offset}]) do
    if Regex.match?(~r/--breakpoint-design-(?:tablet|desktop|wide)/, query),
      do: [],
      else: issue(:css_breakpoint, query, path, line_number(source, offset))
  end

  defp frozen_token_findings(path, source) do
    if path == "assets/css/tokens.css" do
      capture_matches(@frozen_token, source)
      |> Enum.flat_map(fn [{name, offset}, {value, _value_offset}] ->
        issue(:legacy_definition, {name, String.trim(value)}, path, line_number(source, offset))
      end)
    else
      []
    end
  end

  defp approved_css?(value) do
    references = Regex.scan(~r/var\((--[\w-]+)/, value, capture: :all_but_first) |> List.flatten()
    tokens = File.read!("assets/css/design-tokens.css")

    value in ["0", "none", "transparent", "currentColor", "inherit"] or
      (references != [] and not Regex.match?(@raw_value, value) and
         Enum.all?(references, fn name ->
           String.starts_with?(name, "--design-") or String.contains?(tokens, name <> ":")
         end))
  end

  defp capture_matches(pattern, source) do
    Regex.scan(pattern, source, capture: :all_but_first, return: :index)
    |> Enum.map(fn captures ->
      Enum.map(captures, fn {offset, length} ->
        {binary_part(source, offset, length), offset}
      end)
    end)
  end

  defp full_matches(pattern, source) do
    Regex.scan(pattern, source, return: :index)
    |> Enum.map(fn [{offset, length} | _] -> {binary_part(source, offset, length), offset} end)
  end

  defp class_expressions(source) do
    full_matches(@class_expr_start, source)
    |> Enum.reduce({[], 0}, fn {match, attribute_offset}, {expressions, consumed_to} ->
      if attribute_offset < consumed_to do
        {expressions, consumed_to}
      else
        open_brace_offset = attribute_offset + byte_size(match) - 1
        content_offset = open_brace_offset + 1
        {expression, end_offset, closed?} = class_expression(source, content_offset)

        entry = %{
          attribute_offset: attribute_offset,
          content_offset: content_offset,
          end_offset: end_offset,
          source: expression,
          closed?: closed?
        }

        {[entry | expressions], end_offset}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp class_expression(source, content_offset) do
    read_class_expression(source, content_offset, content_offset, 1, nil, false)
  end

  defp style_attribute_value(source, match, offset) do
    if String.ends_with?(match, "{") do
      {_expression, end_offset, _closed?} = class_expression(source, offset + byte_size(match))
      binary_part(source, offset, end_offset - offset)
    else
      match
    end
  end

  defp read_class_expression(source, content_offset, position, _depth, _quote, _escaped)
       when position >= byte_size(source) do
    {binary_part(source, content_offset, position - content_offset), position, false}
  end

  defp read_class_expression(source, content_offset, position, depth, quote, escaped) do
    character = :binary.at(source, position)

    case class_expression_step(character, depth, quote, escaped) do
      :close ->
        {binary_part(source, content_offset, position - content_offset), position + 1, true}

      {next_depth, next_quote, next_escaped} ->
        read_class_expression(
          source,
          content_offset,
          position + 1,
          next_depth,
          next_quote,
          next_escaped
        )
    end
  end

  defp class_expression_step(character, depth, quote, escaped) do
    if is_nil(quote),
      do: unquoted_expression_step(character, depth),
      else: quoted_expression_step(character, depth, quote, escaped)
  end

  defp quoted_expression_step(_character, depth, quote, true), do: {depth, quote, false}
  defp quoted_expression_step(92, depth, quote, false), do: {depth, quote, true}

  defp quoted_expression_step(character, depth, quote, false) when character == quote,
    do: {depth, nil, false}

  defp quoted_expression_step(_character, depth, quote, false), do: {depth, quote, false}

  defp unquoted_expression_step(34, depth), do: {depth, 34, false}
  defp unquoted_expression_step(39, depth), do: {depth, 39, false}
  defp unquoted_expression_step(123, depth), do: {depth + 1, nil, false}
  defp unquoted_expression_step(125, 1), do: :close
  defp unquoted_expression_step(125, depth), do: {depth - 1, nil, false}
  defp unquoted_expression_step(_character, depth), do: {depth, nil, false}

  defp inside_class_expression?(offset, expressions) do
    Enum.any?(expressions, fn expression ->
      offset >= expression.attribute_offset and offset < expression.end_offset
    end)
  end

  defp quoted_strings(source) do
    (capture_matches(@double_quoted, source) ++ capture_matches(@single_quoted, source))
    |> Enum.map(fn [{value, offset}] -> {value, offset} end)
    |> Enum.sort_by(&elem(&1, 1))
  end

  defp strip_quoted_strings(source) do
    source
    |> then(&Regex.replace(@double_quoted, &1, ""))
    |> then(&Regex.replace(@single_quoted, &1, ""))
  end

  defp line_number(source, offset) do
    1 + (:binary.matches(binary_part(source, 0, offset), "\n") |> length())
  end

  defp issue(kind, value, path, number),
    do: [%{key: {kind, value}, message: "#{path}:#{number}: #{reason(kind)}: #{inspect(value)}"}]

  defp reason(kind) do
    case Enum.find(@class_rules, fn {rule, _, _} -> rule == kind end) do
      {_, _, message} ->
        message

      _ ->
        Map.fetch!(
          %{
            breakpoint: "use a breakpoint defined by DESIGN.md",
            focus: "preserve visible focus",
            primary_fill: "primary fill is reserved for authorized semantic components",
            primary_deep: "primary-deep fill is limited to the primary CTA hover/pressed state",
            dark_token: "dark mode must use existing compatibility tokens",
            legacy_token: "legacy tokens are limited to existing dark/error compatibility states",
            raw_css: "raw visual CSS value bypasses project tokens",
            raw_css_variable: "new CSS variables require an approved token",
            inline_style: "inline visual styles bypass project tokens",
            css_breakpoint: "default CSS breakpoint bypasses DESIGN.md",
            legacy_definition: "compatibility token definitions are frozen",
            dynamic_class: "dynamic classes need a static semantic variant"
          },
          kind
        )
    end
  end

  defp changed_paths!(base) do
    {changed, 0} = System.cmd("git", ["diff", "--name-only", "-z", "--no-renames", base])
    {untracked, 0} = System.cmd("git", ["ls-files", "--others", "--exclude-standard", "-z"])
    Enum.uniq(String.split(changed <> untracked, <<0>>, trim: true))
  end

  defp frontend_source?(path) do
    web =
      String.starts_with?(path, "lib/") and
        Enum.any?(String.split(path, "/"), &String.ends_with?(&1, "_web"))

    (web or String.starts_with?(path, "assets/")) and
      Path.extname(path) in [".ex", ".heex", ".css", ".js"]
  end

  defp base_revision! do
    base = System.get_env("DESIGN_SYSTEM_BASE_SHA") || merge_base!()

    case System.cmd("git", ["cat-file", "-e", "#{base}^{commit}"], stderr_to_stdout: true) do
      {_output, 0} -> base
      _ -> Mix.raise("DESIGN_SYSTEM_BASE_SHA is not an available commit")
    end
  end

  defp merge_base! do
    case System.cmd("git", ["merge-base", "origin/main", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      _ -> Mix.raise("Unable to resolve origin/main; set DESIGN_SYSTEM_BASE_SHA")
    end
  end

  defp git_file(base, path) do
    case System.cmd("git", ["show", "#{base}:#{path}"], stderr_to_stdout: true) do
      {source, 0} -> source
      {_source, _status} -> ""
    end
  end
end
