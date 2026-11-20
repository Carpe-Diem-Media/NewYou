defmodule NewYou.ShadowBenchmarkFormatter do
  @moduledoc false
  use GenServer

  @impl true
  def init(options) do
    path = System.fetch_env!("NEWYOU_SHADOW_EVENTS_FILE")
    output = File.open!(path, [:write, :exclusive, :utf8])

    {:ok,
     %{
       output: output,
       starts: %{},
       seed: Keyword.fetch!(options, :seed),
       max_cases: Keyword.fetch!(options, :max_cases)
     }}
  end

  @impl true
  def handle_cast({:module_started, %ExUnit.TestModule{} = module}, state) do
    {:noreply, put_in(state.starts[module.name], System.monotonic_time(:microsecond))}
  end

  def handle_cast({:module_finished, %ExUnit.TestModule{} = module}, state) do
    {started, starts} = Map.pop(state.starts, module.name)

    emit(state, %{
      kind: "module",
      file: Path.relative_to_cwd(module.file),
      module: inspect(module.name),
      status: status(module.state),
      us: System.monotonic_time(:microsecond) - started
    })

    {:noreply, %{state | starts: starts}}
  end

  def handle_cast({:test_finished, %ExUnit.Test{} = test}, state) do
    # The current suite has no parameterized cases. Refuse potentially
    # ambiguous or sensitive parameter values instead of serializing them.
    if map_size(test.parameters) != 0 do
      raise ArgumentError, "parameterized tests need a benchmark identity review"
    end

    emit(state, %{
      kind: "test",
      file: Path.relative_to_cwd(test.tags.file),
      module: inspect(test.module),
      name: Atom.to_string(test.name),
      status: status(test.state),
      us: test.time
    })

    {:noreply, state}
  end

  def handle_cast({:suite_finished, timings}, state) do
    emit(
      state,
      Map.merge(timings, %{kind: "suite", seed: state.seed, max_cases: state.max_cases})
    )

    :ok = File.close(state.output)
    {:noreply, state}
  end

  def handle_cast(_event, state), do: {:noreply, state}

  defp emit(state, event), do: :ok = IO.puts(state.output, JSON.encode!(event))

  defp status(nil), do: "passed"
  defp status({state, _details}), do: Atom.to_string(state)
end
