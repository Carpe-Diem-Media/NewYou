# Fresh TEST VM only. Mutate the executable declaration without changing the
# independent inventory, then invoke the ordinary standalone canonical script.
[mutation, output] = System.argv()
true = Mix.env() == :test
true = mutation in ["drop", "substitute"]
path = Path.expand("test/support/proof/p8_19_catalog.ex")

damaged =
  path
  |> File.read!()
  |> Code.string_to_quoted!()
  |> Macro.prewalk(fn
    {:@, meta, [{:obligations, attribute_meta, [[first | rest]]}]} ->
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
