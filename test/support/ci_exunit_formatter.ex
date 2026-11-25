defmodule NewYou.CIExUnitFormatter do
  @moduledoc false
  use GenServer

  @impl true
  def init(options) do
    mode = System.fetch_env!("NEWYOU_CI_TEST_MODE")
    true = mode in ["discover", "execute"]
    true = Keyword.get(options, :dry_run, false) == (mode == "discover")

    {:ok,
     %{
       output:
         File.open!(System.fetch_env!("NEWYOU_CI_TEST_EVENTS"), [:write, :exclusive, :utf8]),
       active: %{},
       seed: Keyword.fetch!(options, :seed),
       max_cases: Keyword.fetch!(options, :max_cases),
       mode: mode
     }}
  end

  @impl true
  def handle_cast({:module_started, %ExUnit.TestModule{} = module}, state) do
    key = {module.name, parameter(module.parameters)}
    started = System.monotonic_time(:microsecond)
    file = Path.relative_to_cwd(module.file)

    # This event precedes ExUnit's filtering and is independent of execution.
    for test <- module.tests do
      emit(state, %{kind: "declared", identity: identity(file, key, test.name)})
    end

    {:noreply, put_in(state.active[key], {file, started})}
  end

  def handle_cast({:test_finished, %ExUnit.Test{} = test}, %{mode: "execute"} = state) do
    status = status(test.state)
    key = {test.module, parameter(test.parameters)}

    file =
      case Map.fetch(state.active, key) do
        {:ok, {file, _started}} -> file
        :error -> Path.relative_to_cwd(test.tags.file)
      end

    emit(state, %{
      kind: "finished",
      identity: identity(file, key, test.name),
      status: status,
      us: test.time || 0
    })

    {:noreply, state}
  end

  def handle_cast({:module_finished, %ExUnit.TestModule{} = module}, state) do
    key = {module.name, parameter(module.parameters)}
    {{file, started}, active} = Map.pop!(state.active, key)

    if state.mode == "execute" do
      emit(state, %{
        kind: "module",
        file: file,
        status: status(module.state),
        us: System.monotonic_time(:microsecond) - started
      })
    end

    {:noreply, %{state | active: active}}
  end

  def handle_cast({:suite_finished, timings}, state) do
    true = map_size(state.active) == 0

    emit(state, %{
      kind: "suite",
      mode: state.mode,
      seed: state.seed,
      max_cases: state.max_cases,
      timings: timings
    })

    :ok = File.close(state.output)
    {:noreply, state}
  end

  def handle_cast(_event, state), do: {:noreply, state}

  defp parameter(params) when map_size(params) == 0, do: ""

  defp parameter(params) do
    :crypto.hash(:sha256, :erlang.term_to_binary(params, [:deterministic]))
    |> Base.encode16(case: :lower)
  end

  defp identity(file, {module, parameter}, test) do
    [file, inspect(module), Atom.to_string(test), parameter]
  end

  defp emit(state, event), do: :ok = IO.puts(state.output, JSON.encode!(event))

  defp status(nil), do: "passed"
  defp status({state, _details}), do: Atom.to_string(state)
end
