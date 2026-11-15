# Isolated negative fixture. A fresh TEST VM recompiles only the proof callback;
# the canonical Runner, fixed manifests, result schema and CLI remain unchanged.
# No fixture selection is accepted by ordinary tb001 mode.
[output] = System.argv()
true = Mix.env() == :test
source = File.read!("test/support/proof/p8_05.ex")
original = "def run(case_id), do: with_fixture(fn -> execute(case_id) end)"
true = String.contains?(source, original)

broken = """
def run("p805.post_commit_recovery") do
  with_fixture(fn ->
    NewYou.Proof.SelfTest.expect_manifest!("p805.post_commit_recovery.cut_consumed", false, true)
  end)
end
#{original}
"""

Code.compiler_options(ignore_module_conflict: true)

Code.compile_string(
  String.replace(source, original, broken, global: false),
  "test/proof/tb001_broken.exs"
)

System.halt(NewYou.Proof.Runner.run_cli(["--mode", "tb001", "--output", output]))
