defmodule NewYou.ShadowBenchmarkFormatter do
  @moduledoc false
  use GenServer

  @impl true
  def init(options) do
    output =
      case System.get_env("NEWYOU_SHADOW_EVENTS_FILE") do
        nil -> raise ArgumentError, "missing shadow evidence path"
        path -> File.open!(path, [:write, :exclusive, :utf8])
      end

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
    {:noreply, put_in(state.starts[module_key(module)], System.monotonic_time(:microsecond))}
  end

  def handle_cast({:module_finished, %ExUnit.TestModule{} = module}, state) do
    {started, starts} = Map.pop!(state.starts, module_key(module))
    {name, parameter} = module_key(module)
    file = Path.relative_to_cwd(module.file)

    # Mix dry-run emits the registered tests on module completion, without
    # running test bodies or emitting their individual completion events.
    for test <- module.tests do
      emit(state, %{
        kind: "test",
        file: file,
        module: name,
        name: Atom.to_string(test.name),
        parameter: parameter,
        status: status(test.state),
        us: test.time || 0
      })
    end

    emit(state, %{
      kind: "module",
      file: file,
      module: name,
      parameter: parameter,
      status: status(module.state),
      us: System.monotonic_time(:microsecond) - started
    })

    {:noreply, %{state | starts: starts}}
  end

  def handle_cast({:suite_finished, timings}, state) do
    true = map_size(state.starts) == 0

    emit(
      state,
      Map.merge(timings, %{kind: "suite", seed: state.seed, max_cases: state.max_cases})
    )

    :ok = File.close(state.output)
    {:noreply, state}
  end

  def handle_cast(_event, state), do: {:noreply, state}

  defp module_key(module) do
    parameter =
      case module.parameters do
        params when map_size(params) == 0 ->
          ""

        params ->
          data = :erlang.term_to_binary(params, [:deterministic])
          :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
      end

    {inspect(module.name), parameter}
  end

  defp emit(state, event), do: :ok = IO.puts(state.output, JSON.encode!(event))

  defp status(nil), do: "passed"
  defp status({state, _details}), do: Atom.to_string(state)
end
