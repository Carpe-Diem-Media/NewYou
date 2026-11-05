defmodule NewYou.Proof.Scenario do
  @moduledoc false

  defstruct [:controller, :reference, :owner]

  @type t :: %__MODULE__{
          controller: pid(),
          reference: reference(),
          owner: pid()
        }
  @type worker_label :: atom() | binary()

  @request_timeout 5_000
  @cleanup_timeout 5_000
  @forced_cleanup_timeout 1_000
  @max_timeout 30_000
  @cleanup_scope_key {__MODULE__, :cleanup_scope}

  @spec start() :: t()
  @spec start(keyword()) :: t()
  def start(_opts \\ []) do
    owner = self()
    cleanup_scope = Process.get(@cleanup_scope_key)
    parent_controller = if match?(%__MODULE__{}, cleanup_scope), do: cleanup_scope.controller
    parent_reference = if match?(%__MODULE__{}, cleanup_scope), do: cleanup_scope.reference
    reference = make_ref()

    {controller, monitor} =
      spawn_monitor(fn -> init(owner, reference, parent_controller, parent_reference) end)

    scenario =
      receive do
        {:scenario_ready, ^reference} ->
          %__MODULE__{controller: controller, reference: reference, owner: owner}
      after
        @request_timeout ->
          terminate_startup_controller(controller, monitor)
          raise "proof scenario controller did not start"
      end

    result =
      case cleanup_scope do
        %__MODULE__{controller: parent} = scope when parent != controller ->
          case request(scope, {:register_nested_scenario, reference, controller}) do
            :ok ->
              scenario

            {:error, reason} ->
              terminate_startup_controller(controller, monitor)
              raise "could not register nested proof scenario: #{inspect(reason)}"
          end

        _ ->
          scenario
      end

    Process.demonitor(monitor, [:flush])
    result
  end

  @spec spawn(t(), worker_label(), (-> term())) :: {pid(), reference()}
  def spawn(%__MODULE__{} = scenario, label, fun) when is_function(fun, 0) do
    owner!(scenario)

    {pid, monitor} =
      spawn_monitor(fn ->
        worker = self()
        guardian = spawn(fn -> worker_guard(worker, scenario.controller, scenario.owner) end)
        send(scenario.owner, {:scenario_guard_ready, scenario.reference, worker, guardian})

        receive do
          {:scenario_start, reference} when reference == scenario.reference ->
            Process.put(@cleanup_scope_key, scenario)

            try do
              fun.()
            after
              Process.delete(@cleanup_scope_key)
            end

          _ ->
            :ok
        end
      end)

    guardian =
      receive do
        {:scenario_guard_ready, reference, ^pid, guardian} when reference == scenario.reference ->
          guardian
      after
        @request_timeout ->
          Process.exit(pid, :kill)
          raise "proof worker guardian did not start"
      end

    case request(scenario, {:register_worker, label, pid, guardian}) do
      :ok ->
        send(pid, {:scenario_start, scenario.reference})
        {pid, monitor}

      {:error, reason} ->
        Process.demonitor(monitor, [:flush])
        Process.exit(pid, :kill)
        raise "could not register proof worker: #{inspect(reason)}"
    end
  end

  @spec stop(t()) :: :ok | {:error, term()}
  def stop(%__MODULE__{} = scenario) do
    owner!(scenario)
    monitor = Process.monitor(scenario.controller)
    result = request(scenario, :stop, @request_timeout + @cleanup_timeout + 1_000)

    receive do
      {:DOWN, ^monitor, :process, controller, _reason} when controller == scenario.controller ->
        result
    after
      5_000 ->
        Process.demonitor(monitor, [:flush])
        {:error, :cleanup_timeout}
    end
  end

  @spec expect_nested_controller_kill(t()) :: :ok | {:error, term()}
  def expect_nested_controller_kill(%__MODULE__{} = scenario) do
    owner!(scenario)
    request(scenario, :expect_nested_controller_kill)
  end

  @spec confirm_nested_controller_kill(t()) :: :ok | {:error, term()}
  def confirm_nested_controller_kill(%__MODULE__{} = scenario) do
    owner!(scenario)

    case Process.get(@cleanup_scope_key) do
      %__MODULE__{controller: parent} = scope when parent != scenario.controller ->
        request(
          scope,
          {:confirm_nested_controller_kill, scenario.reference, scenario.controller}
        )

      _ ->
        {:error, :not_nested_scenario}
    end
  end

  @spec verify_consumed(t()) :: :ok | {:error, term()}
  def verify_consumed(%__MODULE__{} = scenario), do: request(scenario, :verify_consumed)

  @spec require_assertions(t(), String.t(), [String.t()]) :: :ok | {:error, atom()}
  def require_assertions(%__MODULE__{} = scenario, case_id, assertion_ids),
    do: request(scenario, {:require_assertions, case_id, assertion_ids})

  @spec record_assertion(t(), String.t(), String.t(), term(), term()) :: :ok | {:error, atom()}
  def record_assertion(%__MODULE__{} = scenario, case_id, assertion_id, observed, expected),
    do: request(scenario, {:record_assertion, case_id, assertion_id, observed, expected})

  @spec assertion_snapshot(t()) ::
          %{
            String.t() => %{
              assertion_ids: [String.t()],
              failed_ids: [String.t()],
              count: non_neg_integer()
            }
          }
          | {:error, term()}
  def assertion_snapshot(%__MODULE__{} = scenario), do: request(scenario, :assertion_snapshot)

  @spec owned_processes(t()) :: [{pid(), pid()}] | {:error, term()}
  def owned_processes(%__MODULE__{} = scenario), do: request(scenario, :owned_processes)

  @spec request(t(), term()) :: term()
  @spec request(t(), term(), term()) :: term()
  def request(scenario, operation, timeout \\ @request_timeout)

  def request(%__MODULE__{} = scenario, operation, timeout)
      when is_integer(timeout) and timeout > 0 and timeout <= @max_timeout do
    reference = make_ref()
    monitor = Process.monitor(scenario.controller)

    send(
      scenario.controller,
      {:scenario_request, scenario.reference, reference, self(), operation}
    )

    receive do
      {:scenario_reply, ^reference, result} ->
        Process.demonitor(monitor, [:flush])
        result

      {:DOWN, ^monitor, :process, _pid, _reason} ->
        {:error, :controller_down}
    after
      timeout ->
        Process.demonitor(monitor, [:flush])

        send(
          scenario.controller,
          {:scenario_request, scenario.reference, make_ref(), self(),
           {:record_failure, :lost_reply}}
        )

        {:error, :controller_timeout}
    end
  end

  def request(%__MODULE__{}, _operation, _timeout), do: {:error, :invalid_timeout}

  defp owner!(%__MODULE__{owner: owner}) when owner == self(), do: :ok
  defp owner!(_scenario), do: raise("proof scenario operation must run in its owner")

  defp terminate_startup_controller(controller, monitor) do
    Process.exit(controller, :kill)

    receive do
      {:DOWN, ^monitor, :process, ^controller, _reason} -> :ok
    after
      @forced_cleanup_timeout -> Process.demonitor(monitor, [:flush])
    end
  end

  defp init(owner, reference, parent_controller, parent_reference) do
    owner_monitor = Process.monitor(owner)
    send(owner, {:scenario_ready, reference})

    loop(%{
      owner: owner,
      owner_monitor: owner_monitor,
      parent_controller: parent_controller,
      parent_reference: parent_reference,
      reference: reference,
      workers: %{},
      guardians: %{},
      nested_scenarios: %{},
      cuts: %{},
      failures: [],
      cleanup_failures: [],
      barriers: %{},
      provider_scripts: %{},
      assertions: %{}
    })
  end

  defp loop(state) do
    receive do
      {:scenario_request, reference, request_ref, caller, operation}
      when reference == state.reference ->
        {state, response, stop?} = dispatch(operation, caller, request_ref, state)

        if stop? do
          state = cleanup(state, response)
          response = cleanup_response(state, response)
          send(caller, {:scenario_reply, request_ref, response})

          if is_pid(state.parent_controller) and state.cleanup_failures != [] do
            exit({:cleanup_failed, Enum.reverse(state.cleanup_failures)})
          end
        else
          if response != :deferred, do: send(caller, {:scenario_reply, request_ref, response})
          loop(state)
        end

      {:DOWN, ref, :process, _pid, _reason} when ref == state.owner_monitor ->
        state = cleanup(state, :owner_down)

        if state.cleanup_failures != [] do
          exit({:cleanup_failed, Enum.reverse(state.cleanup_failures)})
        end

      {:barrier_release_timeout, phase, timer_ref} ->
        loop(barrier_release_timeout(state, phase, timer_ref))

      {:DOWN, ref, :process, pid, reason} ->
        state = worker_down(state, ref, pid, reason)
        loop(state)
    end
  end

  defp dispatch({:barrier_arrive, phase, label}, caller, request_ref, state),
    do: handle_barrier_arrive(phase, label, caller, request_ref, state)

  defp dispatch({:barrier_release, phase, timeout}, caller, request_ref, state),
    do: release_barrier(phase, timeout, caller, request_ref, state)

  defp dispatch({:barrier_ack, phase, label}, caller, _request_ref, state),
    do: handle_barrier_ack(phase, label, caller, state)

  defp dispatch({:barrier_define, phase, participants, timeout}, caller, _request_ref, state),
    do: handle_barrier_define(phase, participants, timeout, caller, state)

  defp dispatch({:barrier_status, phase}, _caller, _request_ref, state) do
    case Map.get(state.barriers, phase) do
      nil -> {state, {:error, :unknown_phase}, false}
      barrier -> {state, MapSet.to_list(barrier.arrived) |> Enum.sort(), false}
    end
  end

  defp dispatch({:provider_configure, scripts}, caller, _request_ref, state)
       when caller == state.owner do
    if map_size(state.provider_scripts) > 0 do
      {state, {:error, :scripts_already_configured}, false}
    else
      scripts =
        Map.new(scripts, fn {operation_ref, steps} ->
          {operation_ref, %{steps: steps, index: 0, backlog_released: false}}
        end)

      {%{state | provider_scripts: scripts}, :ok, false}
    end
  end

  defp dispatch({:provider_configure, _scripts}, _caller, _request_ref, state),
    do: {state, {:error, :owner_only}, false}

  defp dispatch({:provider_next, operation_ref, script_step}, _caller, _request_ref, state) do
    case Map.get(state.provider_scripts, operation_ref) do
      nil ->
        {state, {:error, :unknown_script}, false}

      %{steps: steps, index: index} when index >= length(steps) ->
        {state, {:error, :script_exhausted}, false}

      %{steps: steps, index: index} = script ->
        current = Enum.at(steps, index)

        cond do
          current.step != script_step ->
            {state, {:error, :script_step_mismatch}, false}

          current.outcome == :backlog and not script.backlog_released ->
            result = %{
              operation_ref: operation_ref,
              step: current.step,
              outcome: :backlog,
              released: false
            }

            {state, {:ok, result}, false}

          true ->
            result = Map.put(current, :operation_ref, operation_ref)
            updated = %{script | index: index + 1}

            {%{state | provider_scripts: Map.put(state.provider_scripts, operation_ref, updated)},
             {:ok, result}, false}
        end
    end
  end

  defp dispatch({:provider_release_backlog, operation_ref}, caller, _request_ref, state)
       when caller == state.owner do
    case Map.get(state.provider_scripts, operation_ref) do
      nil ->
        {state, {:error, :unknown_script}, false}

      %{steps: steps, index: index} = script when index < length(steps) ->
        current = Enum.at(steps, index)

        if current.outcome == :backlog do
          result = %{
            operation_ref: operation_ref,
            step: current.step,
            outcome: :backlog,
            released: true
          }

          updated = %{script | index: index + 1, backlog_released: false}

          {%{state | provider_scripts: Map.put(state.provider_scripts, operation_ref, updated)},
           {:ok, result}, false}
        else
          {state, {:error, :not_backlogged}, false}
        end

      _ ->
        {state, {:error, :script_exhausted}, false}
    end
  end

  defp dispatch({:provider_release_backlog, _operation_ref}, _caller, _request_ref, state),
    do: {state, {:error, :owner_only}, false}

  defp dispatch({:record_failure, failure}, _caller, _request_ref, state),
    do: fail(state, failure, :ok)

  defp dispatch({:delay_reply, milliseconds}, _caller, _request_ref, state)
       when is_integer(milliseconds) and milliseconds > 0 and milliseconds <= 1_000 do
    Process.sleep(milliseconds)
    {state, :ok, false}
  end

  defp dispatch(operation, caller, _request_ref, state),
    do: handle_operation(operation, caller, state)

  defp handle_operation({:register_worker, label, pid, guardian}, caller, state)
       when caller == state.owner do
    monitor = Process.monitor(pid)
    guardian_monitor = Process.monitor(guardian)

    worker = %{
      label: label,
      monitor: monitor,
      guardian: guardian,
      guardian_monitor: guardian_monitor,
      expected_exit: false,
      worker_down: false,
      guardian_down: false
    }

    workers = Map.put(state.workers, pid, worker)
    guardians = Map.put(state.guardians, guardian, pid)
    {%{state | workers: workers, guardians: guardians}, :ok, false}
  end

  defp handle_operation({:register_worker, _label, _pid, _guardian}, _caller, state),
    do: fail(state, :owner_only, {:error, :owner_only})

  defp handle_operation({:register_nested_scenario, reference, controller}, caller, state) do
    cond do
      not owner_or_worker?(state, caller) ->
        fail(state, :owner_only, {:error, :owner_only})

      not is_reference(reference) or not is_pid(controller) or controller == self() ->
        fail(state, :invalid_nested_scenario, {:error, :invalid_nested_scenario})

      Map.has_key?(state.nested_scenarios, controller) ->
        fail(state, :duplicate_nested_scenario, {:error, :duplicate_nested_scenario})

      true ->
        monitor = Process.monitor(controller)

        nested_scenarios =
          Map.put(state.nested_scenarios, controller, %{
            reference: reference,
            monitor: monitor,
            expected_kill: false,
            down_reason: nil
          })

        {%{state | nested_scenarios: nested_scenarios}, :ok, false}
    end
  end

  defp handle_operation(:expect_nested_controller_kill, caller, state)
       when caller == state.owner do
    cond do
      not is_pid(state.parent_controller) or not is_reference(state.parent_reference) ->
        fail(state, :not_nested_scenario, {:error, :not_nested_scenario})

      map_size(state.workers) > 0 or map_size(state.nested_scenarios) > 0 ->
        fail(state, :nested_scenario_not_empty, {:error, :nested_scenario_not_empty})

      true ->
        parent = %__MODULE__{
          controller: state.parent_controller,
          reference: state.parent_reference,
          owner: self()
        }

        case request(parent, {:expect_nested_controller_kill, state.reference, self()}) do
          :ok -> {state, :ok, false}
          {:error, reason} -> fail(state, reason, {:error, reason})
        end
    end
  end

  defp handle_operation(:expect_nested_controller_kill, _caller, state),
    do: fail(state, :owner_only, {:error, :owner_only})

  defp handle_operation({:expect_nested_controller_kill, reference, controller}, caller, state) do
    case Map.get(state.nested_scenarios, controller) do
      %{reference: ^reference, expected_kill: false} = nested when caller == controller ->
        nested_scenarios =
          Map.put(state.nested_scenarios, controller, %{nested | expected_kill: true})

        {%{state | nested_scenarios: nested_scenarios}, :ok, false}

      _ ->
        fail(state, :invalid_nested_controller_kill, {:error, :invalid_nested_controller_kill})
    end
  end

  defp handle_operation(
         {:confirm_nested_controller_kill, reference, controller},
         caller,
         state
       ) do
    case Map.get(state.nested_scenarios, controller) do
      %{reference: ^reference, expected_kill: true} = nested ->
        cond do
          not owner_or_worker?(state, caller) ->
            fail(state, :owner_only, {:error, :owner_only})

          Process.alive?(controller) ->
            fail(state, :nested_controller_alive, {:error, :nested_controller_alive})

          true ->
            Process.demonitor(nested.monitor, [:flush])

            {%{state | nested_scenarios: Map.delete(state.nested_scenarios, controller)}, :ok,
             false}
        end

      _ ->
        fail(state, :invalid_nested_controller_kill, {:error, :invalid_nested_controller_kill})
    end
  end

  defp handle_operation({:await_owned_down, workers, timeout}, caller, state)
       when caller == state.owner and is_list(workers) and is_integer(timeout) and
              timeout > 0 and timeout <= @max_timeout do
    if Enum.all?(workers, &is_pid/1) do
      # The caller's monitors cannot acknowledge this controller's DOWN ledger.
      # Consume our own monitor signals before confirming the selected cleanup.
      state = await_workers(state, now_ms() + timeout, workers)

      response =
        if Enum.any?(workers, &Map.has_key?(state.workers, &1)),
          do: {:error, :cleanup_timeout},
          else: :ok

      {state, response, false}
    else
      fail(state, :invalid_request, {:error, :invalid_request})
    end
  end

  defp handle_operation(:owned_processes, caller, state) when caller == state.owner do
    children = Enum.map(state.workers, fn {worker, info} -> {worker, info.guardian} end)
    {state, children, false}
  end

  defp handle_operation({:require_assertions, case_id, assertion_ids}, caller, state)
       when caller == state.owner do
    cond do
      not valid_assertion_label?(case_id) or not valid_assertion_ids?(assertion_ids) ->
        fail(state, :invalid_assertion_manifest, {:error, :invalid_assertion_manifest})

      Map.has_key?(state.assertions, case_id) ->
        fail(state, :duplicate_assertion_manifest, {:error, :duplicate_assertion_manifest})

      true ->
        ledger = %{required: assertion_ids, entries: []}
        {%{state | assertions: Map.put(state.assertions, case_id, ledger)}, :ok, false}
    end
  end

  defp handle_operation({:require_assertions, _case_id, _assertion_ids}, _caller, state),
    do: fail(state, :owner_only, {:error, :owner_only})

  defp handle_operation(
         {:record_assertion, case_id, assertion_id, observed, expected},
         caller,
         state
       ) do
    cond do
      not owner_or_worker?(state, caller) ->
        fail(state, :owner_only, {:error, :owner_only})

      not Map.has_key?(state.assertions, case_id) ->
        fail(state, :unknown_assertion_case, {:error, :unknown_assertion_case})

      true ->
        record_required_assertion(state, case_id, assertion_id, observed, expected)
    end
  end

  defp handle_operation(:assertion_snapshot, caller, state) when caller == state.owner do
    snapshot =
      Map.new(state.assertions, fn {case_id, ledger} ->
        matched_ids = for %{id: id, matched: true} <- ledger.entries, do: id
        failed_ids = for %{id: id, matched: false} <- ledger.entries, do: id

        {case_id,
         %{assertion_ids: matched_ids, failed_ids: failed_ids, count: length(ledger.entries)}}
      end)

    {state, snapshot, false}
  end

  defp handle_operation(:assertion_snapshot, _caller, state),
    do: fail(state, :owner_only, {:error, :owner_only})

  defp handle_operation({:arm, name, label, mode}, caller, state) do
    case NewYou.Proof.CutPoints.normalize_name(name) do
      :error ->
        fail(state, :unknown_cut_point, {:error, :unknown_cut_point})

      {:ok, canonical_name} ->
        cond do
          caller != state.owner ->
            fail(state, :owner_only, {:error, :owner_only})

          mode not in [:raise, :terminate] ->
            fail(state, :invalid_mode, {:error, :invalid_mode})

          Map.has_key?(state.cuts, {canonical_name, label}) ->
            fail(state, :duplicate_arm, {:error, :duplicate_arm})

          true ->
            {%{
               state
               | cuts:
                   Map.put(state.cuts, {canonical_name, label}, %{mode: mode, consumed: false})
             }, :ok, false}
        end
    end
  end

  defp handle_operation({:hit, name, label}, caller, state) do
    with {:ok, canonical_name} <- NewYou.Proof.CutPoints.normalize_name(name),
         {:ok, ^label, worker} <- worker_for(state, caller),
         %{mode: mode, consumed: false} = cut <- Map.get(state.cuts, {canonical_name, label}) do
      cuts = Map.put(state.cuts, {canonical_name, label}, %{cut | consumed: true})
      state = %{state | cuts: cuts}

      case mode do
        :raise ->
          {state, {:raise, canonical_name}, false}

        :terminate ->
          workers = Map.update!(state.workers, worker, &%{&1 | expected_exit: true})
          state = %{state | workers: workers}
          Process.exit(worker, :proof_terminated)
          monitor = Map.fetch!(state.workers, worker).monitor

          receive do
            {:DOWN, ^monitor, :process, ^worker, reason} ->
              {worker_down(state, monitor, worker, reason), :terminated, false}
          after
            1_000 -> fail(state, :termination_timeout, {:error, :termination_timeout})
          end
      end
    else
      :error ->
        fail(state, :unknown_cut_point, {:error, :unknown_cut_point})

      {:error, :worker_mismatch} ->
        fail(state, :worker_mismatch, {:error, :worker_mismatch})

      {:ok, _other_label, _worker} ->
        {state, :ok, false}

      nil ->
        {state, :ok, false}

      %{consumed: true} ->
        {state, :ok, false}
    end
  end

  defp handle_operation(:verify_consumed, _caller, state) do
    unreached =
      state.cuts
      |> Enum.filter(fn {_key, cut} -> not cut.consumed end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    cond do
      unreached != [] ->
        failure = {:unreached_cut_points, unreached}
        {%{state | failures: Enum.uniq([failure | state.failures])}, {:error, failure}, false}

      state.failures == [] ->
        {state, :ok, false}

      true ->
        {state, {:error, Enum.reverse(state.failures)}, false}
    end
  end

  defp handle_operation(:stop, caller, state) when caller == state.owner,
    do: begin_stop(state)

  defp handle_operation(:stop_from_parent, caller, state)
       when is_pid(state.parent_controller) and caller == state.parent_controller,
       do: {state, :stop_from_parent, true}

  defp handle_operation(:stop_from_parent, _caller, state),
    do: fail(state, :owner_only, {:error, :owner_only})

  defp handle_operation(_operation, _caller, state),
    do: fail(state, :invalid_request, {:error, :invalid_request})

  defp begin_stop(state) do
    unreached =
      state.cuts
      |> Enum.filter(fn {_key, cut} -> not cut.consumed end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    failures =
      if unreached == [],
        do: state.failures,
        else: [{:unreached_cut_points, unreached} | state.failures]

    {%{state | failures: Enum.uniq(failures)}, :ok, true}
  end

  defp record_required_assertion(state, case_id, assertion_id, observed, expected) do
    ledger = Map.fetch!(state.assertions, case_id)

    cond do
      assertion_id not in ledger.required ->
        fail(state, :unknown_assertion, {:error, :unknown_assertion})

      Enum.any?(ledger.entries, &(&1.id == assertion_id)) ->
        fail(state, :duplicate_assertion, {:error, :duplicate_assertion})

      true ->
        matched = observed === expected
        entry = %{id: assertion_id, matched: matched}
        updated = %{ledger | entries: ledger.entries ++ [entry]}
        state = %{state | assertions: Map.put(state.assertions, case_id, updated)}
        assertion_response(state, matched)
    end
  end

  defp assertion_response(state, true), do: {state, :ok, false}

  defp assertion_response(state, false),
    do: fail(state, :assertion_mismatch, {:error, :assertion_mismatch})

  defp owner_or_worker?(state, caller),
    do: caller == state.owner or match?({:ok, _, _}, worker_for(state, caller))

  defp valid_assertion_ids?(ids) when is_list(ids) and ids != [] do
    Enum.all?(ids, &valid_assertion_label?/1) and length(ids) == length(Enum.uniq(ids))
  end

  defp valid_assertion_ids?(_), do: false

  defp valid_assertion_label?(value) when is_binary(value),
    do: byte_size(value) in 1..128 and Regex.match?(~r/^[A-Za-z0-9_.:-]+$/, value)

  defp valid_assertion_label?(_), do: false

  defp handle_barrier_define(phase, participants, timeout, caller, state) do
    case barrier_definition_error(state, phase, participants, timeout, caller) do
      nil ->
        barrier = new_barrier(participants, timeout)
        {put_barrier(state, phase, barrier), :ok, false}

      {failure, response} ->
        fail(state, failure, response)
    end
  end

  defp barrier_definition_error(state, phase, participants, timeout, caller) do
    cond do
      caller != state.owner ->
        {:owner_only, {:error, :owner_only}}

      Map.has_key?(state.barriers, phase) ->
        {:duplicate_phase, {:error, :duplicate_phase}}

      invalid_participants?(participants) ->
        {:invalid_participants, {:error, :invalid_participants}}

      invalid_timeout?(timeout) ->
        {:invalid_deadline, {:error, :invalid_deadline}}

      true ->
        nil
    end
  end

  defp invalid_participants?(participants) do
    not is_list(participants) or participants == [] or
      length(Enum.uniq(participants)) != length(participants)
  end

  defp invalid_timeout?(timeout),
    do: not is_integer(timeout) or timeout <= 0 or timeout > @max_timeout

  defp new_barrier(participants, timeout) do
    %{
      participants: MapSet.new(participants),
      arrived: MapSet.new(),
      waiters: %{},
      acknowledged: MapSet.new(),
      released: false,
      release_waiter: nil,
      timer_ref: nil,
      timer_handle: nil,
      release_deadline: nil,
      deadline: now_ms() + timeout
    }
  end

  defp handle_barrier_arrive(phase, label, caller, request_ref, state) do
    case {Map.get(state.barriers, phase), worker_for(state, caller)} do
      {nil, _} ->
        fail(state, :unknown_phase, {:error, :unknown_phase})

      {_barrier, {:error, _}} ->
        fail(state, :worker_mismatch, {:error, :worker_mismatch})

      {barrier, {:ok, ^label, _pid}} ->
        cond do
          now_ms() > barrier.deadline ->
            fail(state, :barrier_deadline, {:error, :deadline})

          not MapSet.member?(barrier.participants, label) ->
            fail(state, :unknown_participant, {:error, :unknown_participant})

          MapSet.member?(barrier.arrived, label) ->
            fail(state, :duplicate_arrival, {:error, :duplicate_arrival})

          true ->
            updated = %{
              barrier
              | arrived: MapSet.put(barrier.arrived, label),
                waiters: Map.put(barrier.waiters, label, {caller, request_ref})
            }

            {%{state | barriers: Map.put(state.barriers, phase, updated)}, :deferred, false}
        end

      {_barrier, {:ok, _other, _pid}} ->
        fail(state, :worker_mismatch, {:error, :worker_mismatch})
    end
  end

  defp handle_barrier_ack(phase, label, caller, state) do
    case {Map.get(state.barriers, phase), worker_for(state, caller)} do
      {nil, _} ->
        fail(state, :unknown_phase, {:error, :unknown_phase})

      {_barrier, {:error, _}} ->
        fail(state, :worker_mismatch, {:error, :worker_mismatch})

      {barrier, {:ok, ^label, _pid}} ->
        acknowledge_barrier(state, phase, label, barrier)

      {_barrier, {:ok, _other_label, _pid}} ->
        fail(state, :worker_mismatch, {:error, :worker_mismatch})
    end
  end

  defp acknowledge_barrier(state, phase, label, barrier) do
    cond do
      not MapSet.member?(barrier.participants, label) ->
        fail(state, :unknown_participant, {:error, :unknown_participant})

      not barrier.released or is_nil(barrier.release_waiter) ->
        {state, {:error, :release_failed}, false}

      now_ms() >= barrier.release_deadline ->
        expire_barrier_release(state, phase, barrier)

      MapSet.member?(barrier.acknowledged, label) ->
        fail(state, :duplicate_acknowledgement, {:error, :duplicate_acknowledgement})

      true ->
        record_barrier_ack(state, phase, label, barrier)
    end
  end

  defp record_barrier_ack(state, phase, label, barrier) do
    acknowledged = MapSet.put(barrier.acknowledged, label)
    updated = %{barrier | acknowledged: acknowledged}

    if MapSet.equal?(acknowledged, barrier.participants) do
      {owner, request_ref, _timer_ref} = barrier.release_waiter
      Process.cancel_timer(barrier.timer_handle)
      send(owner, {:scenario_reply, request_ref, :ok})
      updated = %{updated | release_waiter: nil, timer_ref: nil, timer_handle: nil}
      {put_barrier(state, phase, updated), :ok, false}
    else
      {put_barrier(state, phase, updated), :ok, false}
    end
  end

  defp barrier_release_timeout(state, phase, timer_ref) do
    case Map.get(state.barriers, phase) do
      %{timer_ref: ^timer_ref, release_waiter: {owner, request_ref, ^timer_ref}} = barrier ->
        missing =
          MapSet.difference(barrier.participants, barrier.acknowledged)
          |> MapSet.to_list()
          |> Enum.sort()

        response = {:error, {:missing_acknowledgements, missing}}
        send(owner, {:scenario_reply, request_ref, response})

        updated = %{
          barrier
          | released: false,
            release_waiter: nil,
            timer_ref: nil,
            timer_handle: nil
        }

        failure = {:missing_acknowledgements, missing}
        put_barrier(%{state | failures: Enum.uniq([failure | state.failures])}, phase, updated)

      _ ->
        state
    end
  end

  defp expire_barrier_release(state, phase, barrier) do
    {owner, request_ref, _timer_ref} = barrier.release_waiter

    missing =
      MapSet.difference(barrier.participants, barrier.acknowledged)
      |> MapSet.to_list()
      |> Enum.sort()

    response = {:error, {:missing_acknowledgements, missing}}
    send(owner, {:scenario_reply, request_ref, response})
    if barrier.timer_handle, do: Process.cancel_timer(barrier.timer_handle)
    updated = %{barrier | released: false, release_waiter: nil, timer_ref: nil, timer_handle: nil}
    failure = {:missing_acknowledgements, missing}

    {put_barrier(%{state | failures: Enum.uniq([failure | state.failures])}, phase, updated),
     response, false}
  end

  defp put_barrier(state, phase, barrier),
    do: %{state | barriers: Map.put(state.barriers, phase, barrier)}

  defp release_barrier(phase, timeout, caller, request_ref, state) when caller == state.owner do
    case Map.get(state.barriers, phase) do
      nil ->
        fail(state, :unknown_phase, {:error, :unknown_phase})

      barrier ->
        case release_problem(barrier, timeout) do
          :ok ->
            begin_barrier_release(state, phase, timeout, caller, request_ref, barrier)

          {failure, response, notify_arrivals?} ->
            fail_barrier_release(state, barrier, failure, response, notify_arrivals?)
        end
    end
  end

  defp release_barrier(_phase, _timeout, _caller, _request_ref, state),
    do: fail(state, :owner_only, {:error, :owner_only})

  defp release_problem(barrier, timeout) do
    missing =
      MapSet.difference(barrier.participants, barrier.arrived) |> MapSet.to_list() |> Enum.sort()

    missing_acknowledgements =
      barrier.waiters
      |> Enum.filter(fn {_label, {pid, _ref}} -> not Process.alive?(pid) end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    cond do
      not is_integer(timeout) or timeout < 0 or timeout > @max_timeout ->
        {:invalid_deadline, {:error, :invalid_deadline}, false}

      timeout == 0 or now_ms() > barrier.deadline ->
        {:barrier_deadline, {:error, :deadline}, true}

      missing != [] ->
        {{:missing_arrivals, missing}, {:error, {:missing_arrivals, missing}}, true}

      missing_acknowledgements != [] ->
        {{:missing_acknowledgements, missing_acknowledgements},
         {:error, {:missing_acknowledgements, missing_acknowledgements}}, true}

      true ->
        :ok
    end
  end

  defp notify_barrier_waiters(barrier, response),
    do: Enum.each(Map.values(barrier.waiters), &reply_waiter(&1, response))

  defp fail_barrier_release(state, barrier, failure, response, notify_arrivals?) do
    maybe_notify_barrier_waiters(barrier, response, notify_arrivals?)
    fail(state, failure, response)
  end

  defp maybe_notify_barrier_waiters(barrier, response, true),
    do: notify_barrier_waiters(barrier, response)

  defp maybe_notify_barrier_waiters(_barrier, _response, false), do: :ok

  defp begin_barrier_release(state, phase, timeout, caller, request_ref, barrier) do
    wait_ms = min(timeout, max(barrier.deadline - now_ms(), 1))
    timer_ref = make_ref()

    timer_handle =
      Process.send_after(self(), {:barrier_release_timeout, phase, timer_ref}, wait_ms)

    notify_barrier_waiters(barrier, :released)

    updated = %{
      barrier
      | released: true,
        release_waiter: {caller, request_ref, timer_ref},
        timer_ref: timer_ref,
        timer_handle: timer_handle,
        release_deadline: min(barrier.deadline, now_ms() + timeout)
    }

    {put_barrier(state, phase, updated), :deferred, false}
  end

  defp reply_waiter({pid, request_ref}, response),
    do: send(pid, {:scenario_reply, request_ref, response})

  defp worker_for(state, caller) do
    case Map.get(state.workers, caller) do
      %{label: label} -> {:ok, label, caller}
      nil -> {:error, :worker_mismatch}
    end
  end

  defp fail(state, failure, response),
    do: {%{state | failures: Enum.uniq([failure | state.failures])}, response, false}

  defp worker_down(state, ref, pid, reason) do
    case Map.get(state.nested_scenarios, pid) do
      %{monitor: ^ref, expected_kill: true} = nested when reason == :killed ->
        nested_scenarios =
          Map.put(state.nested_scenarios, pid, %{nested | down_reason: reason})

        %{state | nested_scenarios: nested_scenarios}

      %{monitor: ^ref} ->
        nested_scenarios = Map.delete(state.nested_scenarios, pid)

        if reason == :normal do
          %{state | nested_scenarios: nested_scenarios}
        else
          %{
            state
            | nested_scenarios: nested_scenarios,
              failures: Enum.uniq([:nested_controller_failed | state.failures]),
              cleanup_failures: Enum.uniq([:nested_controller_failed | state.cleanup_failures])
          }
        end

      _ ->
        case Map.get(state.workers, pid) do
          %{monitor: ^ref} = worker ->
            handle_worker_down(state, pid, worker, reason)

          _ ->
            handle_guardian_down(state, pid, reason)
        end
    end
  end

  defp handle_worker_down(state, pid, worker, reason) do
    failures =
      if expected_worker_exit?(worker, reason),
        do: state.failures,
        else: [:worker_failed | state.failures]

    state = update_worker(state, pid, %{worker | worker_down: true}, failures)
    fail_barriers_for_worker(state, pid)
  end

  defp expected_worker_exit?(_worker, :normal), do: true

  defp expected_worker_exit?(%{expected_exit: true}, reason),
    do: reason in [:killed, :proof_terminated]

  defp expected_worker_exit?(_worker, _reason), do: false

  defp handle_guardian_down(state, guardian, reason) do
    case Map.get(state.guardians, guardian) do
      nil -> state
      worker_pid -> guardian_process_down(state, worker_pid, reason)
    end
  end

  defp guardian_process_down(state, worker_pid, reason) do
    worker = Map.fetch!(state.workers, worker_pid)
    failures = if reason == :normal, do: state.failures, else: [:guardian_failed | state.failures]

    cleanup_failures =
      if reason == :normal,
        do: state.cleanup_failures,
        else: Enum.uniq([:guardian_failed | state.cleanup_failures])

    if not worker.worker_down, do: Process.exit(worker_pid, :kill)
    state = %{state | cleanup_failures: cleanup_failures}
    update_worker(state, worker_pid, %{worker | guardian_down: true}, failures)
  end

  defp update_worker(state, pid, worker, failures) do
    if worker.worker_down and worker.guardian_down do
      %{
        state
        | workers: Map.delete(state.workers, pid),
          guardians: Map.delete(state.guardians, worker.guardian),
          failures: failures
      }
    else
      %{state | workers: Map.put(state.workers, pid, worker), failures: failures}
    end
  end

  defp fail_barriers_for_worker(state, worker_pid) do
    Enum.reduce(state.barriers, state, fn {phase, barrier}, acc ->
      if waiting_worker?(barrier, worker_pid),
        do: fail_barrier_acknowledgement(acc, phase, barrier),
        else: acc
    end)
  end

  defp waiting_worker?(barrier, worker_pid) do
    case Enum.find(barrier.waiters, fn {_label, {pid, _ref}} -> pid == worker_pid end) do
      {label, _waiter} ->
        not is_nil(barrier.release_waiter) and not MapSet.member?(barrier.acknowledged, label)

      nil ->
        false
    end
  end

  defp fail_barrier_acknowledgement(state, phase, barrier) do
    {owner, request_ref, _timer_ref} = barrier.release_waiter

    missing =
      MapSet.difference(barrier.participants, barrier.acknowledged)
      |> MapSet.to_list()
      |> Enum.sort()

    response = {:error, {:missing_acknowledgements, missing}}
    send(owner, {:scenario_reply, request_ref, response})
    if barrier.timer_handle, do: Process.cancel_timer(barrier.timer_handle)

    updated = %{
      barrier
      | released: false,
        release_waiter: nil,
        timer_ref: nil,
        timer_handle: nil
    }

    failure = {:missing_acknowledgements, missing}
    put_barrier(%{state | failures: Enum.uniq([failure | state.failures])}, phase, updated)
  end

  defp cleanup_workers(state) do
    workers =
      Map.new(state.workers, fn {pid, worker} -> {pid, %{worker | expected_exit: true}} end)

    state = %{state | workers: workers}
    Enum.each(Map.keys(state.workers), &Process.exit(&1, :kill))
    deadline = now_ms() + 5_000
    await_workers(state, deadline)
  end

  defp await_workers(state, deadline), do: await_workers(state, deadline, Map.keys(state.workers))

  defp await_workers(state, deadline, workers) do
    complete? = Enum.all?(workers, &(not Map.has_key?(state.workers, &1)))

    if complete? or now_ms() >= deadline do
      if complete?,
        do: state,
        else: %{
          state
          | failures: Enum.uniq([:cleanup_timeout | state.failures]),
            cleanup_failures: Enum.uniq([:cleanup_timeout | state.cleanup_failures])
        }
    else
      receive do
        {:DOWN, ref, :process, pid, reason} ->
          await_workers(worker_down(state, ref, pid, reason), deadline, workers)
      after
        max(deadline - now_ms(), 0) ->
          %{
            state
            | failures: Enum.uniq([:cleanup_timeout | state.failures]),
              cleanup_failures: Enum.uniq([:cleanup_timeout | state.cleanup_failures])
          }
      end
    end
  end

  defp cleanup(state, _reason) do
    state
    |> cleanup_nested_scenarios()
    |> cleanup_workers()
  end

  defp cleanup_nested_scenarios(state) do
    Enum.reduce(Map.to_list(state.nested_scenarios), state, fn {pid, nested}, state ->
      stop_nested_scenario(state, pid, nested)
    end)
  end

  defp stop_nested_scenario(state, pid, %{expected_kill: true, monitor: monitor}) do
    if Process.alive?(pid) do
      nested = Map.delete(Map.fetch!(state.nested_scenarios, pid), :expected_kill)
      stop_nested_scenario(state, pid, nested)
    else
      remove_nested_scenario(state, pid, monitor)
    end
  end

  defp stop_nested_scenario(state, pid, %{reference: reference, monitor: monitor}) do
    request_ref = make_ref()

    send(
      pid,
      {:scenario_request, reference, request_ref, self(), :stop_from_parent}
    )

    case await_nested_scenario(
           pid,
           monitor,
           request_ref,
           now_ms() + @cleanup_timeout,
           nil,
           nil
         ) do
      {:timeout, nil, :normal} ->
        remove_nested_scenario(state, pid, monitor)

      {:timeout, _response, _reason} ->
        Process.exit(pid, :kill)
        down_reason = await_nested_down(pid, monitor, @forced_cleanup_timeout)
        state = remove_nested_scenario(state, pid, monitor)

        failure =
          if is_nil(down_reason), do: :nested_cleanup_unconfirmed, else: :nested_cleanup_timeout

        %{
          state
          | failures: Enum.uniq([failure | state.failures]),
            cleanup_failures: Enum.uniq([failure | state.cleanup_failures])
        }

      {response, :normal} when response in [:ok, nil] ->
        remove_nested_scenario(state, pid, monitor)

      {_response, :normal} ->
        state = remove_nested_scenario(state, pid, monitor)

        %{
          state
          | failures: Enum.uniq([:nested_cleanup_failed | state.failures]),
            cleanup_failures: Enum.uniq([:nested_cleanup_failed | state.cleanup_failures])
        }

      {_response, _reason} ->
        state = remove_nested_scenario(state, pid, monitor)

        %{
          state
          | failures: Enum.uniq([:nested_controller_failed | state.failures]),
            cleanup_failures: Enum.uniq([:nested_controller_failed | state.cleanup_failures])
        }
    end
  end

  defp await_nested_scenario(pid, monitor, request_ref, deadline, response, down_reason) do
    cond do
      not is_nil(response) and not is_nil(down_reason) ->
        {response, down_reason}

      now_ms() >= deadline ->
        {:timeout, response, down_reason}

      true ->
        receive do
          {:scenario_reply, ^request_ref, result} ->
            await_nested_scenario(pid, monitor, request_ref, deadline, result, down_reason)

          {:DOWN, ^monitor, :process, ^pid, reason} ->
            await_nested_scenario(pid, monitor, request_ref, deadline, response, reason)
        after
          max(deadline - now_ms(), 0) -> {:timeout, response, down_reason}
        end
    end
  end

  defp await_nested_down(pid, monitor, timeout) do
    receive do
      {:DOWN, ^monitor, :process, ^pid, reason} -> reason
    after
      timeout -> if Process.alive?(pid), do: nil, else: :down_unobserved
    end
  end

  defp remove_nested_scenario(state, pid, monitor) do
    Process.demonitor(monitor, [:flush])
    %{state | nested_scenarios: Map.delete(state.nested_scenarios, pid)}
  end

  defp cleanup_response(%{cleanup_failures: []}, :stop_from_parent), do: :ok

  defp cleanup_response(state, :stop_from_parent),
    do: {:error, Enum.reverse(state.cleanup_failures)}

  defp cleanup_response(%{failures: []}, response), do: response
  defp cleanup_response(state, _response), do: {:error, Enum.reverse(state.failures)}

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp worker_guard(worker, controller, owner) do
    worker_monitor = Process.monitor(worker)
    controller_monitor = Process.monitor(controller)
    owner_monitor = Process.monitor(owner)

    receive do
      {:DOWN, ^worker_monitor, :process, ^worker, _reason} ->
        :ok

      {:DOWN, ref, :process, _pid, _reason}
      when ref == controller_monitor or ref == owner_monitor ->
        Process.exit(worker, :kill)

        receive do
          {:DOWN, ^worker_monitor, :process, ^worker, _worker_reason} -> :ok
        after
          1_000 -> :ok
        end
    end
  end
end
