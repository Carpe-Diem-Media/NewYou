defmodule NewYou.Architecture.AshWriteBoundary do
  @moduledoc """
  Mechanical enforcement of ARC-029 (`docs/governance/architecture/references/ARCHITECTURE_LAW_WORKING_v0.36.0.md`):
  ordinary business code does not use `Ecto.Repo` as a second business API.

  This is deliberately narrow. It rejects only the clear persistence bypasses
  that would route business state around owning Ash actions:

    * `:repo_write` - a mutating `NewYou.Repo` call (`insert`, `update`, `delete`, ...)
    * `:raw_sql_write` - raw SQL that is mutating, function-calling, commented or non-literal
    * `:ecto_multi_write` - a persisting `Ecto.Multi` operation or callback
    * `:parallel_ecto_schema` - `use Ecto.Schema`, a second business model beside Ash resources
    * `:outer_layer_ash_write` - a generic Ash mutation in web or worker code
    * `:analytics_foreign_command` - Analytics calls another NewYou module outside its approved Privacy read
    * `:analytics_foreign_ash_write` - Analytics mutates a foreign or dynamically selected Resource
    * `:parse_error` - a file in scope that cannot be parsed, failing closed

  Ordinary reads, owning application Ash actions, Sandbox configuration, migrations and the Repo
  module itself are not rejected. Qualified calls and statically imported local calls use the same
  checks. The analysis uses the compiler's own parser (`Code.string_to_quoted/2`), so no general
  static-analysis engine is involved.
  """

  @repo [:NewYou, :Repo]

  # Repo functions that persist. `transaction` is intentionally absent: writes
  # inside a transaction are themselves Repo calls and are caught individually.
  @repo_write_functions [
    :insert,
    :insert!,
    :insert_or_update,
    :insert_or_update!,
    :insert_all,
    :update,
    :update!,
    :update_all,
    :delete,
    :delete!,
    :delete_all
  ]

  @ash_write_functions [
    :create,
    :create!,
    :update,
    :update!,
    :destroy,
    :destroy!,
    :bulk_create,
    :bulk_create!,
    :bulk_update,
    :bulk_update!,
    :bulk_destroy,
    :bulk_destroy!
  ]

  @raw_sql_functions [:query, :query!, :query_many, :query_many!]
  @raw_sql_modules [@repo, [:Ecto, :Adapters, :SQL]]

  @multi_write_functions [
    :run,
    :insert,
    :insert_all,
    :insert_or_update,
    :update,
    :update_all,
    :delete,
    :delete_all
  ]

  # Only literal read statements with no SQL function calls may run through raw SQL.
  @read_only_prefix ~r/\A\s*(select|with|show|values|explain)\b/i
  @write_keyword ~r/\b(insert|update|delete|merge|truncate|alter|drop|create|grant|revoke|copy|do|call|set|reset|lock|vacuum|reindex|cluster|refresh|into|for\s+update)\b/i
  @sql_comment ~r/--|\/\*/
  @sql_string_literal ~r/
                        (?<![\p{L}\p{N}_$])
                        (?:
                          [eE]'(?:''|\\.|[^'])*'
                          |
                          [uU]&'(?:''|[^'])*'
                          |
                          '(?:''|[^'])*'
                        )
                        |
                        (?<![\p{L}\p{N}_$])\$([\p{L}_][\p{L}\p{N}_]*)\$.*?\$\1\$
                        |
                        (?<![\p{L}\p{N}_$])\$\$.*?\$\$
                      /sux
  @sql_quoted_identifier ~r/"(?:""|[^"])*"/s
  @sql_function_call ~r/
                        (?<![\p{L}\p{N}_$])
                        (?!(?:
                          select|from|where|and|or|not|in|exists|as|with|values|show|explain|
                            case|when|then|else|end|over|filter|distinct|all|any|some|on|
                            using|having|limit|offset|order|group|union|intersect|except|
                            fetch|for|join|lateral|recursive|sets|rollup|cube|array|row
                        )\b)
                        (?:[_\p{L}][\p{L}\p{N}_$]*|"(?:[^"]|"")+")
                        (?:\s*\.\s*(?:[_\p{L}][\p{L}\p{N}_$]*|"(?:[^"]|"")+"))*
                        \s*\(
                      /ixu

  # Infrastructure exceptions. Each entry must name the exact file and the
  # reason it may touch the Repo. Keep this list short; prefer Ash actions.
  @infrastructure_allowlist %{
    "lib/new_you/repo.ex" => "Repo module definition and configuration"
  }

  @typedoc "A single architecture violation."
  @type violation :: %{
          required(:file) => String.t(),
          required(:line) => non_neg_integer(),
          required(:rule) => atom(),
          required(:message) => String.t()
        }

  @doc """
  Returns `:application` for files this rule governs, `:infrastructure` for
  allowlisted infrastructure files, and `:out_of_scope` for everything else
  (migrations, tests, sandbox configuration and other non-application code).
  """
  @spec scope(String.t()) :: :application | :infrastructure | :out_of_scope
  def scope(path) do
    normalized = String.replace(path, "\\", "/")

    cond do
      Map.has_key?(@infrastructure_allowlist, normalized) ->
        :infrastructure

      String.starts_with?(normalized, "lib/") and String.ends_with?(normalized, ".ex") ->
        :application

      true ->
        :out_of_scope
    end
  end

  @doc "Checks every governed application file under `root` and returns all violations."
  @spec check_app(String.t()) :: [violation()]
  def check_app(root \\ File.cwd!()) do
    root
    |> Path.join("lib/**/*.ex")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.flat_map(fn absolute ->
      relative = Path.relative_to(absolute, root)

      case scope(relative) do
        :application -> check_source(File.read!(absolute), relative)
        _ -> []
      end
    end)
  end

  @doc """
  Checks one source string as if it lived at `path`. Returns `[]` when the
  file is out of scope or allowlisted.
  """
  @spec check_source(String.t(), String.t()) :: [violation()]
  def check_source(source, path) do
    case scope(path) do
      :application -> analyse(source, path)
      _ -> []
    end
  end

  defp analyse(source, path) do
    case Code.string_to_quoted(source, file: path, columns: false) do
      {:ok, ast} ->
        aliases = collect_aliases(ast)
        imports = collect_imports(ast, aliases)
        repo_variables = collect_repo_variables(ast, aliases)
        repo_attributes = collect_repo_attributes(ast, aliases)
        analytics_violations = analytics_violations(ast, path, aliases, imports)

        context =
          if String.starts_with?(path, "lib/new_you_web/"),
            do: "web layer",
            else: "application code"

        {_, violations} =
          Macro.prewalk(ast, [], fn node, acc ->
            {node,
             violations_for(
               node,
               aliases,
               imports,
               repo_variables,
               repo_attributes,
               path,
               context
             ) ++ acc}
          end)

        (violations ++ analytics_violations)
        |> Enum.reverse()
        |> Enum.uniq()

      {:error, {meta, message, token}} ->
        line = if is_list(meta), do: Keyword.get(meta, :line, 0), else: 0

        [
          violation(
            path,
            line,
            :parse_error,
            "cannot parse governed file: #{inspect(message)} #{token}"
          )
        ]
    end
  end

  defp analytics_violations(ast, path, aliases, imports) do
    if analytics_file?(path) do
      variables = collect_module_variables(ast, aliases)
      attributes = collect_module_attributes(ast, aliases)

      {_, violations} =
        Macro.prewalk(ast, [], fn
          {{:., meta, [receiver, function]}, _, args} = node, acc
          when is_atom(function) and is_list(args) ->
            module = analytics_receiver(receiver, aliases, variables, attributes)

            found =
              analytics_call_violation(
                module,
                function,
                args,
                Keyword.get(meta, :line, 0),
                path,
                aliases
              )

            {node, found ++ acc}

          {:&, meta, [{:/, _, [{function, _, context}, arity]}]} = node, acc
          when is_atom(function) and is_atom(context) and is_integer(arity) ->
            found =
              analytics_import_violations(
                imports,
                function,
                List.duplicate(nil, arity),
                meta,
                path,
                aliases
              )

            {node, found ++ acc}

          {:apply, meta, args} = node, acc when length(args) == 3 ->
            found =
              analytics_call_violation(
                [:Kernel],
                :apply,
                args,
                Keyword.get(meta, :line, 0),
                path,
                aliases
              )

            {node, found ++ acc}

          {function, meta, args} = node, acc when is_atom(function) and is_list(args) ->
            found = analytics_import_violations(imports, function, args, meta, path, aliases)

            {node, found ++ acc}

          node, acc ->
            {node, acc}
        end)

      Enum.reverse(violations)
    else
      []
    end
  end

  defp analytics_import_violations(imports, function, args, meta, path, aliases) do
    imports
    |> Enum.filter(&imported_function?(&1, function, length(args)))
    |> Enum.flat_map(
      &analytics_call_violation(
        &1.module,
        function,
        args,
        Keyword.get(meta, :line, 0),
        path,
        aliases
      )
    )
  end

  defp analytics_call_violation(
         module,
         :apply,
         [receiver, function, args],
         line,
         path,
         aliases
       )
       when module in [[:Kernel], [:erlang]] and is_atom(function) and is_list(args) do
    case analytics_receiver(receiver, aliases, %{}, %{}) do
      nil ->
        [
          violation(
            path,
            line,
            :analytics_foreign_command,
            "Analytics apply target must be statically owned or an approved read"
          )
        ]

      module ->
        analytics_call_violation(module, function, args, line, path, aliases)
    end
  end

  defp analytics_call_violation(module, :apply, _args, line, path, _aliases)
       when module in [[:Kernel], [:erlang]],
       do: [
         violation(
           path,
           line,
           :analytics_foreign_command,
           "Analytics apply target must be statically owned or an approved read"
         )
       ]

  defp analytics_call_violation([:NewYou | _] = module, function, args, line, path, _aliases) do
    cond do
      List.starts_with?(module, [:NewYou, :Analytics]) ->
        []

      module == [:NewYou, :Privacy] and function == :current_p817_proof_purpose_snapshot and
          args == [] ->
        []

      true ->
        [
          violation(
            path,
            line,
            :analytics_foreign_command,
            "Analytics cannot call another NewYou module's command; use an owner-approved read interface"
          )
        ]
    end
  end

  defp analytics_call_violation([:Ash], function, args, line, path, aliases)
       when function in @ash_write_functions do
    case List.first(args) do
      {:__aliases__, _, _} = resource ->
        if List.starts_with?(resolve(resource, aliases), [:NewYou, :Analytics]),
          do: [],
          else: [
            violation(
              path,
              line,
              :analytics_foreign_ash_write,
              "Analytics Ash mutations must target a statically resolved Analytics resource"
            )
          ]

      _ ->
        [
          violation(
            path,
            line,
            :analytics_foreign_ash_write,
            "Analytics Ash mutations must target a statically resolved Analytics resource"
          )
        ]
    end
  end

  defp analytics_call_violation(_, _, _, _, _, _), do: []

  defp analytics_file?(path) do
    path = String.replace(path, "\\", "/")
    path == "lib/new_you/analytics.ex" or String.starts_with?(path, "lib/new_you/analytics/")
  end

  defp analytics_receiver(:erlang, _aliases, _variables, _attributes), do: [:erlang]

  defp analytics_receiver({:__aliases__, _, _} = receiver, aliases, _variables, _attributes),
    do: resolve(receiver, aliases)

  defp analytics_receiver({:@, _, [{name, _, _}]}, _aliases, _variables, attributes)
       when is_atom(name), do: Map.get(attributes, name)

  defp analytics_receiver({name, _, _}, _aliases, variables, _attributes) when is_atom(name),
    do: Map.get(variables, name)

  defp analytics_receiver(_, _, _, _), do: nil

  defp collect_module_variables(ast, aliases) do
    {_, values} =
      Macro.prewalk(ast, %{}, fn
        {:=, _, [{name, _, _}, {:__aliases__, _, _} = target]} = node, acc when is_atom(name) ->
          {node, Map.put(acc, name, resolve(target, aliases))}

        node, acc ->
          {node, acc}
      end)

    values
  end

  defp collect_module_attributes(ast, aliases) do
    {_, values} =
      Macro.prewalk(ast, %{}, fn
        {:@, _, [{name, _, [{:__aliases__, _, _} = target]}]} = node, acc when is_atom(name) ->
          {node, Map.put(acc, name, resolve(target, aliases))}

        node, acc ->
          {node, acc}
      end)

    values
  end

  defp violations_for(
         {:use, meta, [{:__aliases__, _, _} = target | _]} = _node,
         aliases,
         _imports,
         _repo_variables,
         _repo_attributes,
         path,
         _context
       ) do
    case resolve(target, aliases) do
      [:Ecto, :Schema] ->
        [
          violation(
            path,
            Keyword.get(meta, :line, 0),
            :parallel_ecto_schema,
            "`use Ecto.Schema` creates a parallel business model; model business state as an Ash resource"
          )
        ]

      _ ->
        []
    end
  end

  defp violations_for(
         {{:., meta, [receiver, function]}, _call_meta, args},
         aliases,
         _imports,
         repo_variables,
         repo_attributes,
         path,
         context
       )
       when is_atom(function) and (is_list(args) or is_nil(args)) do
    line = Keyword.get(meta, :line, 0)
    module = receiver_module(receiver, aliases, repo_variables, repo_attributes)

    if module do
      call_violations(module, function, args || [], line, path, context)
    else
      []
    end
  end

  # Imported calls appear as local calls in the AST. Resolve only imports whose
  # module and function signatures are statically known, then reuse the same
  # rules as qualified calls. Import scopes are file-wide, like aliases above.
  defp violations_for(
         {function, meta, args},
         _aliases,
         imports,
         _repo_variables,
         _repo_attributes,
         path,
         context
       )
       when is_atom(function) and (is_list(args) or is_nil(args)) do
    line = Keyword.get(meta, :line, 0)
    args = args || []
    arity = length(args)

    imports
    |> Enum.filter(&imported_function?(&1, function, arity))
    |> Enum.flat_map(&call_violations(&1.module, function, args, line, path, context))
  end

  defp violations_for(
         _node,
         _aliases,
         _imports,
         _repo_variables,
         _repo_attributes,
         _path,
         _context
       ),
       do: []

  defp receiver_module(
         {:__aliases__, _, _} = receiver,
         aliases,
         _repo_variables,
         _repo_attributes
       ),
       do: resolve(receiver, aliases)

  defp receiver_module({:@, _, [{name, _, _}]}, _aliases, _repo_variables, repo_attributes)
       when is_atom(name) do
    if MapSet.member?(repo_attributes, name), do: @repo
  end

  defp receiver_module({name, _, _context}, _aliases, repo_variables, _repo_attributes)
       when is_atom(name) do
    if MapSet.member?(repo_variables, name), do: @repo
  end

  defp receiver_module(_receiver, _aliases, _repo_variables, _repo_attributes), do: nil

  defp call_violations(module, function, args, line, path, context) do
    cond do
      outer_layer_ash_write?(module, function, path) ->
        [
          violation(
            path,
            line,
            :outer_layer_ash_write,
            "`Ash.#{function}` persists directly from web or worker code; use the owning Domain/application interface"
          )
        ]

      module == @repo and function in @repo_write_functions ->
        [
          violation(
            path,
            line,
            :repo_write,
            "`NewYou.Repo.#{function}` persists business state directly from #{context}; use an owning Ash action"
          )
        ]

      module in @raw_sql_modules and function in @raw_sql_functions ->
        raw_sql_violations(module, args, line, path, context, function)

      module == [:Ecto, :Multi] and function in @multi_write_functions ->
        [
          violation(
            path,
            line,
            :ecto_multi_write,
            multi_write_message(function)
          )
        ]

      true ->
        []
    end
  end

  defp multi_write_message(:run),
    do: "`Ecto.Multi.run` can execute Repo writes outside an Ash action"

  defp multi_write_message(function),
    do: "`Ecto.Multi.#{function}` persists business state outside an Ash action"

  defp outer_layer_ash_write?(module, function, path) do
    module == [:Ash] and function in @ash_write_functions and outer_layer?(path)
  end

  # Web code and conventional worker/job paths are outer layers. Owning
  # application modules remain free to implement their interfaces with Ash.
  defp outer_layer?(path) do
    normalized = String.replace(path, "\\", "/")

    String.starts_with?(normalized, "lib/new_you_web/") or
      (String.starts_with?(normalized, "lib/new_you/") and
         (Enum.any?(Path.split(normalized), &(&1 in ["workers", "jobs"])) or
            String.ends_with?(normalized, ["_worker.ex", "_job.ex", "/worker.ex", "/job.ex"])))
  end

  defp raw_sql_violations(module, args, line, path, _context, function) do
    statement_index = if module == @repo, do: 0, else: 1

    case Enum.fetch(args, statement_index) do
      {:ok, statement} when is_binary(statement) ->
        # Ignore string contents so SQL-looking text in literals does not
        # affect write-keyword, comment or function-call checks. Quoted
        # identifiers are removed only for keyword and comment checks because
        # a quoted function name still needs to be checked as a function call.
        sql = Regex.replace(@sql_string_literal, statement, " ")
        sql_tokens = Regex.replace(@sql_quoted_identifier, sql, " ")

        if Regex.match?(@read_only_prefix, sql) and
             not Regex.match?(@write_keyword, sql_tokens) and
             not Regex.match?(@sql_comment, sql_tokens) and
             not Regex.match?(@sql_function_call, sql) do
          []
        else
          [
            violation(
              path,
              line,
              :raw_sql_write,
              "mutating, function-calling, commented or non-read-only raw SQL via `#{function}` bypasses Ash actions"
            )
          ]
        end

      _ ->
        [
          violation(
            path,
            line,
            :raw_sql_write,
            "non-literal raw SQL via `#{function}` cannot be proven read-only; use an Ash read or an allowlisted infrastructure path"
          )
        ]
    end
  end

  # Collects `alias A.B`, `alias A.B, as: C` and `alias A.{B, C}` into a
  # short-name -> full-name map. Scope is file-wide; this is a conservative
  # approximation that is sufficient for the boundary rule.
  defp collect_aliases(ast) do
    {_, aliases} =
      Macro.prewalk(ast, %{}, fn
        {:alias, _, [{:__aliases__, _, parts}]} = node, acc ->
          {node, Map.put(acc, List.last(parts), parts)}

        {:alias, _, [{:__aliases__, _, parts}, opts]} = node, acc when is_list(opts) ->
          name = Keyword.get(opts, :as, {:__aliases__, [], [List.last(parts)]})
          {:__aliases__, _, [as]} = name
          {node, Map.put(acc, as, parts)}

        {:alias, _, [{{:., _, [{:__aliases__, _, base}, :{}]}, _, subs}]} = node, acc ->
          acc =
            Enum.reduce(subs, acc, fn {:__aliases__, _, sub}, inner ->
              Map.put(inner, List.last(sub), base ++ sub)
            end)

          {node, acc}

        node, acc ->
          {node, acc}
      end)

    aliases
  end

  defp collect_imports(ast, aliases) do
    {_, imports} =
      Macro.prewalk(ast, [], fn
        {:import, _, [{:__aliases__, _, _} = target]} = node, acc ->
          {node, [%{module: resolve(target, aliases), functions: :all} | acc]}

        {:import, _, [{:__aliases__, _, _} = target, opts]} = node, acc when is_list(opts) ->
          import = %{
            module: resolve(target, aliases),
            functions: imported_functions(opts)
          }

          {node, [import | acc]}

        node, acc ->
          {node, acc}
      end)

    imports
  end

  # Track only local variables assigned a resolved Repo module. This closes
  # calls such as `repo.query!(...)` without following arbitrary values or
  # attempting general data-flow analysis.
  defp collect_repo_variables(ast, aliases) do
    {_, variables} =
      Macro.prewalk(ast, MapSet.new(), fn
        {:=, _, [{name, _, _context}, {:__aliases__, _, _} = target]} = node, acc
        when is_atom(name) ->
          if resolve(target, aliases) == @repo do
            {node, MapSet.put(acc, name)}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    variables
  end

  # Track module attributes assigned a resolved Repo module so calls through
  # `@repo` use the same persistence checks as aliases and local variables.
  defp collect_repo_attributes(ast, aliases) do
    {_, attributes} =
      Macro.prewalk(ast, MapSet.new(), fn
        {:@, _, [{name, _, [{:__aliases__, _, _} = target]}]} = node, acc
        when is_atom(name) ->
          if resolve(target, aliases) == @repo do
            {node, MapSet.put(acc, name)}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    attributes
  end

  defp imported_functions(opts) do
    case Keyword.fetch(opts, :only) do
      {:ok, :functions} ->
        :all

      {:ok, :macros} ->
        :none

      {:ok, only} when is_list(only) ->
        {:only, MapSet.new(only)}

      {:ok, _unknown} ->
        :all

      :error ->
        case Keyword.fetch(opts, :except) do
          {:ok, except} when is_list(except) -> {:except, MapSet.new(except)}
          _ -> :all
        end
    end
  end

  defp imported_function?(%{functions: :all}, _function, _arity), do: true
  defp imported_function?(%{functions: :none}, _function, _arity), do: false

  defp imported_function?(%{functions: {:only, functions}}, function, arity),
    do: MapSet.member?(functions, {function, arity})

  defp imported_function?(%{functions: {:except, functions}}, function, arity),
    do: not MapSet.member?(functions, {function, arity})

  defp resolve({:__aliases__, _, [head | tail]}, aliases) do
    case Map.fetch(aliases, head) do
      {:ok, full} -> full ++ tail
      :error -> [head | tail]
    end
  end

  defp violation(path, line, rule, message) do
    %{file: path, line: line, rule: rule, message: message}
  end
end
