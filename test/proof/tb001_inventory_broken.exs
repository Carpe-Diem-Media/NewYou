# Fresh TEST VM only. Mutate the executable declaration without changing the
# independent inventory, then invoke the ordinary standalone canonical script.
[mutation, output] = System.argv()
true = Mix.env() == :test
true = mutation in ["drop", "substitute", "authority"]
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
        if mutation == "drop" do
          rest
        else
          replacement =
            Macro.prewalk(first, fn
              "p819.reconciliation_apply" -> "p819.unreviewed_substitution"
              node -> node
            end)

          [replacement | rest]
        end

      {:@, meta, [{:obligations, attribute_meta, [obligations]}]}

    node ->
      node
  end)

Code.compiler_options(ignore_module_conflict: true)
Code.compile_quoted(damaged, path)
System.argv(["--mode", "tb001", "--output", output])
Code.eval_file("test/proof/run.exs")
