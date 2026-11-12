defmodule KnowledgeSymbols do
  def run(old_path, new_path) do
    old = parse(File.read!(old_path))
    new = parse(File.read!(new_path))
    IO.write(:json.encode(%{"old" => old, "new" => new}))
  end

  defp parse(source) do
    case Code.string_to_quoted(source, columns: true, token_metadata: false) do
      {:ok, ast} ->
        state = %{
          modules: %{},
          module_names: MapSet.new(),
          unknown: [],
          namespace_unknown: false,
          unresolved_module: false
        }

        result = walk(ast, nil, state)

        functions =
          result.modules
          |> Enum.flat_map(fn {{module, name, arity}, clauses} ->
            [
              %{
                "module" => module,
                "name" => name,
                "arity" => arity,
                "sha256" => digest(Enum.reverse(clauses))
              }
            ]
          end)
          |> Enum.sort_by(&{&1["module"], &1["name"], &1["arity"]})

        %{
          "status" => if(result.unresolved_module, do: "unknown", else: "parsed"),
          "modules" => Enum.sort(result.module_names),
          "functions" => functions,
          "unknown" => result.unknown
        }

      {:error, error} ->
        %{
          "status" => "unknown",
          "modules" => [],
          "functions" => [],
          "unknown" => [%{"reason" => "Elixir syntax parse failed: #{inspect(error)}"}]
        }
    end
  end

  defp walk({:__block__, _, expressions}, module, state),
    do: Enum.reduce(expressions, state, &walk(&1, module, &2))

  defp walk({:defmodule, _, [name_ast, body]}, module, state) do
    absolute = is_atom(name_ast) or match?({:__aliases__, _, [:"Elixir" | _]}, name_ast)

    name =
      if state.namespace_unknown and not absolute,
        do: :ambiguous,
        else: module_name(name_ast, module)

    case name do
      {:ok, nested} ->
        result =
          walk(keyword_body(body), nested, %{
            state
            | module_names: MapSet.put(state.module_names, nested)
          })

        %{result | namespace_unknown: state.namespace_unknown}

      :ambiguous ->
        state = %{state | unresolved_module: true}
        add_unknown(state, "module namespace may depend on aliases or macro expansion")

      :error ->
        add_unknown(state, "dynamic or ambiguous module name")
    end
  end

  defp walk({kind, _, [head, _body]} = node, module, state)
       when kind in [:def, :defp, :defmacro, :defmacrop] do
    case {module, function_head(head)} do
      {nil, _} -> add_unknown(state, "function declared outside a literal module")
      {_, :error} -> add_unknown(state, "dynamic or ambiguous function head")
      {name, {function, args}} -> add_function(state, name, function, args, node)
    end
  end

  defp walk({:quote, _, _}, _module, state), do: state
  defp walk({:alias, _, _}, _module, state), do: %{state | namespace_unknown: true}

  defp walk({name, _, args}, module, state) when is_atom(name) and is_list(args) do
    state = %{state | namespace_unknown: true}

    cond do
      is_nil(module) ->
        add_unknown(
          state,
          "top-level expression may generate declarations; expressions are not evaluated"
        )

      name in [:unquote, :defdelegate, :defguard, :defguardp] ->
        add_unknown(state, "macro-generated or dynamic declarations are not evaluated")

      true ->
        add_unknown(
          state,
          "module expression may generate declarations; expressions are not evaluated"
        )
    end
  end

  defp walk(list, module, state) when is_list(list),
    do: Enum.reduce(list, state, &walk(&1, module, &2))

  defp walk(_other, _module, state), do: state

  defp keyword_body(do: body), do: body
  defp keyword_body(body), do: body

  defp module_name({:__aliases__, _, parts}, parent) when is_list(parts) and parts != [] do
    if Enum.all?(parts, &is_atom/1) do
      names = Enum.map(parts, &Atom.to_string/1)

      names =
        if hd(parts) == :"Elixir",
          do: tl(names),
          else: if(parent, do: [parent | names], else: names)

      {:ok, Enum.join(names, ".")}
    else
      :error
    end
  end

  defp module_name(name, _parent) when is_atom(name) do
    {:ok, name |> Atom.to_string() |> String.trim_leading("Elixir.")}
  end

  defp module_name(_, _), do: :error

  defp function_head({:when, _, [call | _]}), do: function_head(call)

  defp function_head({name, _, args}) when is_atom(name) and is_list(args),
    do: {Atom.to_string(name), args}

  defp function_head({name, _, nil}) when is_atom(name), do: {Atom.to_string(name), []}
  defp function_head(_), do: :error

  defp add_function(state, module, name, args, node) do
    arity = length(args)
    defaults = Enum.count(args, &match?({:\\, _, _}, &1))

    normalized =
      node
      |> Macro.prewalk(fn
        {form, metadata, children} when is_list(metadata) -> {form, [], children}
        other -> other
      end)
      |> Macro.to_string()

    Enum.reduce((arity - defaults)..arity, state, fn effective_arity, acc ->
      key = {module, name, effective_arity}
      update_in(acc.modules[key], fn clauses -> [normalized | clauses || []] end)
    end)
  end

  defp add_unknown(state, reason),
    do: %{state | unknown: state.unknown ++ [%{"reason" => reason}]}

  defp digest(values),
    do: :crypto.hash(:sha256, Enum.join(values, "\n")) |> Base.encode16(case: :lower)
end

KnowledgeSymbols.run(hd(System.argv()), Enum.at(System.argv(), 1))
