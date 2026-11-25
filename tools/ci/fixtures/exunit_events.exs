profile = System.fetch_env!("NEWYOU_FIXTURE_PROFILE")
discover? = System.fetch_env!("NEWYOU_CI_TEST_MODE") == "discover"

ExUnit.start(
  seed: 17,
  max_cases: 2,
  dry_run: discover?,
  exclude: if(profile == "filtered", do: [hidden: true], else: []),
  formatters: [NewYou.CIExUnitFormatter]
)

source = ~S"""
defmodule MODULE_NAME do
  use ExUnit.Case, async: true, parameterize: [%{variant: :one}, %{variant: :two}]

  for example <- [:first, :second] do
    test "generated #{example}", %{variant: variant} do
      assert variant in [:one, :two]
    end
  end

  @tag hidden: true
  test "independently declared filtered case", do: assert(true)

  if System.get_env("NEWYOU_FIXTURE_PROFILE") == "filtered" do
    @tag skip: true
    test "declared skipped case", do: flunk("unexpected execution")
  end

  if System.get_env("NEWYOU_FIXTURE_PROFILE") == "invalid" do
    setup_all do
      raise "intentional invalid setup fixture"
    end
  end
end
"""

for name <- String.split(System.get_env("NEWYOU_FIXTURE_NAMES", "only"), ",") do
  Code.compile_string(
    String.replace(source, "MODULE_NAME", "EventFixture.#{Macro.camelize(name)}"),
    "test/ci_exunit_#{name}_test.exs"
  )
end
