# Fresh TEST VM only. Mutate the executable declaration without changing the
# independent inventory, then invoke the ordinary standalone canonical script.
[mutation, output] = System.argv()
true = Mix.env() == :test
true = mutation in ["drop", "substitute", "authority", "callback", "boundary", "cut", "race"]
path = Path.expand("test/support/proof/p8_19_catalog.ex")

damaged =
  path
  |> File.read!()
  |> Code.string_to_quoted!()
  |> Macro.prewalk(fn
    {:@, meta, [{:required_inventory, attribute_meta, [value]}]} when mutation == "authority" ->
      damaged = quote do: Map.put(unquote(value), "source_sha256", String.duplicate("0", 64))
      {:@, meta, [{:required_inventory, attribute_meta, [damaged]}]}

    {:@, meta, [{:obligations, attribute_meta, [[first | rest]]}]} when mutation != "authority" ->
      obligations =
        case mutation do
          "drop" ->
            rest

          "substitute" ->
            replacement =
              Macro.prewalk(first, fn
                "p819.reconciliation_apply" -> "p819.unreviewed_substitution"
                node -> node
              end)

            [replacement | rest]

          "callback" ->
            {:{}, tuple_meta, fields} = first
            # A real, harmless, normally returning application function. The
            # family/case/invariant and expected proof claim stay unchanged.
            true = is_binary(NewYou.platform_name())

            fields =
              fields
              |> List.replace_at(2, quote(do: NewYou))
              |> List.replace_at(3, :platform_name)

            [{:{}, tuple_meta, fields} | rest]

          metadata when metadata in ["cut", "race"] ->
            # Remove a real required cut/race, preserving the owner callback.
            index = if metadata == "cut", do: 5, else: 6

            Enum.map([first | rest], fn {:{}, tuple_meta, fields} ->
              {:{}, tuple_meta, List.replace_at(fields, index, nil)}
            end)

          "boundary" ->
            [first | rest]
        end

      {:@, meta, [{:obligations, attribute_meta, [obligations]}]}

    "owning_ash_postgresql" when mutation == "boundary" ->
      "phoenix_conntest_identity_postgresql"

    node ->
      node
  end)

Code.compiler_options(ignore_module_conflict: true)
Code.compile_quoted(damaged, path)
System.argv(["--mode", "tb001", "--output", output])
Code.eval_file("test/proof/run.exs")
