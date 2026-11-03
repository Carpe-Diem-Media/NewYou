defmodule Mix.Tasks.Design.Check do
  @moduledoc "Rejects new design bypasses in changed Phoenix frontend and asset source."
  use Mix.Task

  @shortdoc "Checks changed frontend code against DESIGN.md"
  @double_class ~r/(?<![\w:-])class\s*=\s*"([^"]*)"/
  @single_class ~r/(?<![\w:-])class\s*=\s*'([^']*)'/
  @class_expr ~r/(?<![\w:-])class\s*=\s*\{([^}]*)\}/
  @quoted ~r/"([^"]*)"|'([^']*)'/
  @apply ~r/@apply\s+([^;{}]+);?/
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
  @css_variable ~r/--[\w-]+\s*:\s*([^;]+);/
  @raw_value ~r/(?:#[0-9a-fA-F]{3,8}\b|\b(?:rgb|rgba|hsl|hsla|oklch|oklab)\s*\(|\b(?:black|white|red|green|blue|orange|purple)\b|(?:^|\s)-?\d+(?:\.\d+)?(?:px|rem|em|vw|vh|%)\b|^\d+(?:\.\d+)?$)/i
  @media_width ~r/@(?:media|container)\b[^{}]*\b(?:min-width|max-width)\s*:|@(?:media|container)\b[^{}]*\bwidth\s*(?:>=|<=|>|<)/i
  @style_attribute ~r/(?<![\w:-])style\s*=\s*(?:["']|\{)/i
  @raw_color_attribute ~r/(?<![\w:-])(?:fill|stroke|color|bgcolor|background)\s*=\s*["']\s*#[0-9a-fA-F]{3,8}\b/i
  @daisyui_selector ~r/\.(?:btn|card|badge|alert|input|select|textarea|toggle|checkbox|radio|modal|navbar|menu|tabs?|drawer|dropdown|tooltip|toast|join|avatar|form-control|collapse)(?:-|[,:.\s{])/i
  @js_style ~r/\.style\.(?:color|backgroundColor|borderColor|borderRadius|boxShadow|fontSize|fontFamily|fontWeight|letterSpacing|padding|margin)\s*=\s*["']/

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
    colors = fn source, pattern ->
      Regex.scan(pattern, source, capture: :all_but_first)
      |> Map.new(fn [name, color] -> {name, String.downcase(color)} end)
    end

    expected = colors.(design, ~r/^  ([\w-]+):\s*"(#[0-9a-fA-F]{3,8})"\s*$/m)
    actual = colors.(css, ~r/^\s*--color-design-([\w-]+):\s*(#[0-9a-fA-F]{3,8});\s*$/m)

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

  @doc false
  def token_authority_violations(authority_changed?, tokens_changed?) do
    if tokens_changed? and not authority_changed?,
      do: ["design-tokens.css changed without a DESIGN.md authority change"],
      else: []
  end

  defp scan(path, source) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, number} ->
      classes(path, line, number) ++ styles(path, line, number)
    end)
  end

  defp classes(path, line, number) do
    static = captured(@double_class, line) ++ captured(@single_class, line)
    expressions = captured(@class_expr, line)

    dynamic =
      Enum.flat_map(expressions, fn expression ->
        strings = quoted_strings(expression)
        rest = Regex.replace(@quoted, expression, "") |> String.replace(~r/[\s\[\],]/, "")

        if strings == [] or rest != "",
          do: issue(:dynamic_class, :dynamic_class, path, number),
          else: []
      end)

    Enum.flat_map(
      static ++ Enum.flat_map(expressions, &quoted_strings/1),
      &check_classes(path, &1, number)
    ) ++ dynamic
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
    do: utility == "bg-design-primary" and path != "lib/new_you_web/components/design/button.ex"

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

  defp styles(path, line, number) do
    classes =
      if Path.extname(path) == ".css",
        do: captured(@apply, line),
        else: if(Path.extname(path) == ".js", do: captured(@js_class, line), else: [])

    class_findings = Enum.flat_map(classes, &check_classes(path, &1, number))
    class_findings ++ css_findings(path, line, number)
  end

  defp css_findings(path, line, number) do
    raw_css_findings(path, line, number) ++
      custom_variable_findings(path, line, number) ++
      inline_style_findings(path, line, number) ++
      raw_color_attribute_findings(path, line, number) ++
      daisyui_selector_findings(path, line, number) ++
      js_style_findings(path, line, number) ++
      breakpoint_findings(path, line, number) ++
      frozen_token_findings(path, line, number)
  end

  defp raw_css_findings(path, line, number) do
    Regex.scan(@css_property, line, capture: :all_but_first)
    |> Enum.flat_map(fn [property, value] ->
      value = String.trim(value)

      if path == "assets/css/design-tokens.css" or approved_css?(value),
        do: [],
        else: issue(:raw_css, {property, value}, path, number)
    end)
  end

  defp custom_variable_findings(path, line, number) do
    if path != "assets/css/design-tokens.css" and
         Regex.match?(@css_variable, line),
       do: issue(:raw_css_variable, line, path, number),
       else: []
  end

  defp inline_style_findings(path, line, number),
    do:
      if(Regex.match?(@style_attribute, line),
        do: issue(:inline_style, line, path, number),
        else: []
      )

  defp raw_color_attribute_findings(path, line, number) do
    if Path.extname(path) in [".ex", ".heex"] and Regex.match?(@raw_color_attribute, line),
      do: issue(:raw_css, line, path, number),
      else: []
  end

  defp daisyui_selector_findings(path, line, number) do
    if Path.extname(path) == ".css" and Regex.match?(@daisyui_selector, line),
      do: issue(:daisyui, line, path, number),
      else: []
  end

  defp js_style_findings(path, line, number) do
    if Path.extname(path) == ".js" and Regex.match?(@js_style, line),
      do: issue(:inline_style, line, path, number),
      else: []
  end

  defp breakpoint_findings(path, line, number) do
    invalid =
      Path.extname(path) == ".css" and Regex.match?(@media_width, line) and
        not Regex.match?(~r/--breakpoint-design-(?:tablet|desktop|wide)/, line)

    if invalid, do: issue(:css_breakpoint, line, path, number), else: []
  end

  defp frozen_token_findings(path, line, number) do
    if path == "assets/css/tokens.css" and Regex.match?(~r/^\s*--ny-[\w-]+:/, line),
      do: issue(:legacy_definition, line, path, number),
      else: []
  end

  defp approved_css?(value),
    do:
      value in ["0", "none", "transparent", "currentColor", "inherit"] or
        (String.contains?(value, "var(--design-") and not Regex.match?(@raw_value, value))

  defp captured(pattern, line),
    do: Regex.scan(pattern, line, capture: :all_but_first) |> List.flatten()

  defp quoted_strings(expression), do: captured(@quoted, expression)

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
            primary_fill: "primary fill is reserved for the primary CTA",
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
