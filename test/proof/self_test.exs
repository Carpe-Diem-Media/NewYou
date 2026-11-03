unless Code.ensure_loaded?(NewYou.Proof.ProviderFixtures) do
  Code.require_file("fixtures/provider_fixtures.exs", __DIR__)
end

defmodule NewYou.Proof.SelfTest do
  @moduledoc false

  alias NewYou.Proof.{Catalog, Concurrent, CutPoints, Provider, Result, Scenario}
  alias NewYou.Proof.ProviderFixtures

  @assertion_context_key {__MODULE__, :assertion_context}
  @observations_context_key {__MODULE__, :observations_context}
  @cleanup_context_key {__MODULE__, :cleanup_context}
  @broken_invariant_case "cut.raise.transaction.before_commit"
  @failure_fixture_case "result.callback_failures"

  @doc false
  @spec execute_registered_case(map(), (-> term()) | nil) :: {map(), map()}
  def execute_registered_case(manifest, callback) when is_map(manifest),
    do: execute_case(manifest, callback)

  @doc false
  @spec initial_cleanup_state() :: map()
  def initial_cleanup_state, do: clean_cleanup()

  @doc false
  @spec merge_cleanup_state(map(), map()) :: map()
  def merge_cleanup_state(left, right), do: merge_cleanup(left, right)

  @doc false
  @spec finalize_cleanup(map()) :: map()
  def finalize_cleanup(cleanup) when is_map(cleanup), do: cleanup_result(cleanup)

  @doc false
  @spec expect_manifest!(String.t(), term(), term()) :: term()
  def expect_manifest!(assertion_id, observed, expected) when is_binary(assertion_id) do
    case Process.get(@assertion_context_key) do
      {scenario, case_id, assertion_ids} when is_list(assertion_ids) ->
        Result.expect!(scenario, case_id, assertion_id, observed, expected)

      _ ->
        raise RuntimeError, "proof assertion context missing"
    end
  end

  @doc false
  def observe_manifest!(code, value)
      when is_binary(code) and (is_boolean(value) or is_integer(value)) do
    observations = Process.get(@observations_context_key, [])
    Process.put(@observations_context_key, observations ++ [%{"code" => code, "value" => value}])
    :ok
  end

  @doc false
  def cleanup_manifest!(updates), do: record_cleanup(updates)

  @spec run([String.t()], keyword()) :: {[map()], map()}
  def run(case_ids, opts \\ []) do
    manifests = Map.new(Catalog.required().self_test.cases, &{&1.case_id, &1})
    registrations = register_probes(Catalog.required().self_test.cases)
    registration_map = Map.new(registrations, &{&1.case_id, &1.callback})
    registration_map = Map.merge(registration_map, Keyword.get(opts, :callback_overrides, %{}))
    registration_map = Map.merge(registration_map, fixture_overrides(case_ids, opts[:fixture]))
    {results, cleanup} = execute(case_ids, manifests, registration_map, [], clean_cleanup())

    {results, apply_fixture_cleanup(cleanup, opts[:fixture])}
  end

  defp fixture_overrides([@broken_invariant_case], :broken_invariant),
    do: %{@broken_invariant_case => broken_assertion_callback()}

  defp fixture_overrides([@failure_fixture_case], fixture)
       when fixture in [:callback_exception, :callback_exit, :callback_throw, :callback_timeout],
       do: %{@failure_fixture_case => failure_fixture_callback(fixture)}

  defp fixture_overrides(_case_ids, _fixture), do: %{}

  defp apply_fixture_cleanup(cleanup, :cleanup_failure) do
    %{
      cleanup
      | "verdict" => "FAIL",
        "workers_stopped" => false,
        "reason_codes" => ["cleanup.unconfirmed"]
    }
  end

  defp apply_fixture_cleanup(cleanup, _fixture), do: cleanup

  defp broken_assertion_callback do
    fn ->
      case Process.get(@assertion_context_key) do
        {scenario, case_id, [assertion_id | _]} ->
          Result.expect!(scenario, case_id, assertion_id, :unexpected, :expected)

        {scenario, case_id, assertion_id} ->
          Result.expect!(scenario, case_id, assertion_id, :unexpected, :expected)

        _ ->
          :registration_failure
      end
    end
  end

  defp failure_fixture_callback(:callback_exception),
    do: fn -> raise("synthetic-secret-canary") end

  defp failure_fixture_callback(:callback_exit), do: fn -> exit(:synthetic_exit) end
  defp failure_fixture_callback(:callback_throw), do: fn -> throw(:synthetic_throw) end

  defp failure_fixture_callback(:callback_timeout) do
    fn -> Process.sleep(11_000) end
  end

  defp register_probes(manifests) do
    Enum.reduce(manifests, [], fn manifest, registrations ->
      {:ok, updated} =
        Catalog.register(
          registrations,
          "harness",
          manifest.case_id,
          manifest.invariant_id,
          fn -> run_case(manifest.case_id) end
        )

      updated
    end)
  end

  defp execute([], _manifests, _registrations, results, cleanup),
    do: {Enum.reverse(results), cleanup_result(cleanup)}

  defp execute([case_id | remaining], manifests, registrations, results, cleanup) do
    manifest = Map.fetch!(manifests, case_id)

    callback = Map.get(registrations, case_id)
    {current, case_cleanup} = execute_case(manifest, callback)
    cleanup = merge_cleanup(cleanup, case_cleanup)

    if current["verdict"] == "PASS" do
      execute(remaining, manifests, registrations, [current | results], cleanup)
    else
      remaining_results = Enum.map(remaining, &not_run_case(Map.fetch!(manifests, &1)))
      {Enum.reverse([current | results]) ++ remaining_results, cleanup_result(cleanup)}
    end
  end

  defp execute_case(manifest, callback) do
    ledger = Scenario.start()
    execute_case_with_ledger(manifest, callback, ledger)
  end

  defp execute_case_with_ledger(manifest, callback, ledger) do
    execute_case_with_ledger(manifest, callback, ledger, System.monotonic_time(:millisecond))
  end

  defp execute_case_with_ledger(manifest, callback, ledger, started_at) do
    {outcome, callback_cleanup, observations, snapshot, stop_result, controller_stopped?,
     workers_stopped?} =
      run_registered_case(manifest, callback, ledger, started_at)

    {assertion_ids, failed_ids, assertion_count} = assertion_snapshot(snapshot, manifest.case_id)

    case_cleanup =
      Map.put(
        callback_cleanup,
        :workers_stopped,
        callback_cleanup.workers_stopped and workers_stopped? and controller_stopped? and
          not cleanup_unconfirmed?(stop_result)
      )

    case_cleanup =
      if controller_stopped? and not cleanup_unconfirmed?(stop_result) do
        case_cleanup
      else
        %{case_cleanup | connections_released: false, locks_released: false}
      end

    {verdict, status, reasons} =
      case_outcome(
        manifest,
        outcome,
        stop_result,
        controller_stopped?,
        assertion_ids,
        failed_ids,
        assertion_count
      )

    duration_ms = elapsed_ms(started_at)

    {case_result(manifest, status, verdict, assertion_ids, reasons, observations, duration_ms),
     case_cleanup}
  rescue
    _ ->
      Process.delete(@assertion_context_key)
      Process.delete(@observations_context_key)
      _ = if Process.alive?(ledger.controller), do: Scenario.stop(ledger)
      Process.delete(@cleanup_context_key)

      cleanup = %{
        workers_stopped: false,
        connections_released: false,
        locks_released: false
      }

      duration_ms = elapsed_ms(started_at)
      {case_result(manifest, "error", "FAIL", [], ["probe.failed"], nil, duration_ms), cleanup}
  end

  defp run_registered_case(manifest, callback, ledger, started_at) do
    with true <- manifest_assertion_ids_valid?(manifest),
         :ok <- Scenario.require_assertions(ledger, manifest.case_id, manifest.assertion_ids),
         true <- is_function(callback, 0) do
      run_case_callback(manifest, callback, ledger, started_at)
    else
      _ ->
        {snapshot, stop_result, controller_stopped?, workers_stopped?} =
          finish_case_ledger(ledger)

        {:registration_failure, initial_case_cleanup(manifest.case_id), nil, snapshot,
         stop_result, controller_stopped?, workers_stopped?}
    end
  end

  defp manifest_assertion_ids_valid?(manifest) do
    ids = Map.get(manifest, :assertion_ids, [])

    is_list(ids) and ids != [] and length(ids) == length(Enum.uniq(ids)) and
      Enum.all?(ids, &(is_binary(&1) and byte_size(&1) in 1..128))
  end

  defp run_case_callback(manifest, callback, ledger, started_at) do
    parent = self()
    reference = make_ref()
    cleanup = initial_case_cleanup(manifest.case_id)
    deadline = started_at + manifest.timeout_ms

    {worker, monitor} =
      Scenario.spawn(ledger, :self_test_case, fn ->
        Process.put(@assertion_context_key, {ledger, manifest.case_id, manifest.assertion_ids})
        Process.put(@cleanup_context_key, cleanup)

        outcome =
          try do
            callback.()
            :ok
          rescue
            _ -> :probe_exception
          catch
            _, _ -> :probe_exception
          after
            Process.delete(@assertion_context_key)
          end

        callback_cleanup = Process.delete(@cleanup_context_key) || cleanup
        observations = Process.delete(@observations_context_key)
        completed_at = System.monotonic_time(:millisecond)
        send(parent, {reference, self(), outcome, callback_cleanup, observations, completed_at})

        receive do
          {:case_result_ack, ^reference} -> :ok
        end
      end)

    {outcome, callback_cleanup, observations} =
      receive do
        {^reference, ^worker, outcome, callback_cleanup, observations, completed_at} ->
          if completed_at <= deadline do
            send(worker, {:case_result_ack, reference})
            {outcome, callback_cleanup, observations}
          else
            {:timeout, cleanup, nil}
          end

        {:DOWN, ^monitor, :process, ^worker, _reason} ->
          {:probe_exception, cleanup, nil}
      after
        max(deadline - System.monotonic_time(:millisecond), 0) ->
          {:timeout, cleanup, nil}
      end

    {snapshot, stop_result, controller_stopped?, workers_stopped?} = finish_case_ledger(ledger)
    Process.demonitor(monitor, [:flush])
    flush_case_result(reference, worker)

    {outcome, callback_cleanup, observations, snapshot, stop_result, controller_stopped?,
     workers_stopped?}
  end

  defp flush_case_result(reference, worker) do
    receive do
      {^reference, ^worker, _outcome, _cleanup, _observations, _completed_at} -> :ok
    after
      0 -> :ok
    end
  end

  defp finish_case_ledger(ledger) do
    snapshot = Scenario.assertion_snapshot(ledger)
    owned_processes = Scenario.owned_processes(ledger)
    stop_result = Scenario.stop(ledger)
    controller_stopped? = not Process.alive?(ledger.controller)
    workers_stopped? = owned_processes_stopped?(owned_processes)
    {snapshot, stop_result, controller_stopped?, workers_stopped?}
  end

  defp owned_processes_stopped?(workers) when is_list(workers) do
    Enum.all?(workers, fn {worker, guardian} ->
      not Process.alive?(worker) and not Process.alive?(guardian)
    end)
  end

  defp owned_processes_stopped?(_workers), do: false

  defp cleanup_unconfirmed?({:error, reasons}) when is_list(reasons) do
    Enum.any?(reasons, fn reason ->
      reason in [
        :cleanup_timeout,
        :guardian_failed,
        :nested_cleanup_failed,
        :nested_cleanup_timeout,
        :nested_cleanup_unconfirmed,
        :nested_controller_failed
      ]
    end)
  end

  defp cleanup_unconfirmed?({:error, reason})
       when reason in [:cleanup_timeout, :controller_down, :controller_timeout],
       do: true

  defp cleanup_unconfirmed?(_result), do: false

  defp elapsed_ms(started_at), do: max(System.monotonic_time(:millisecond) - started_at, 0)

  defp case_outcome(
         manifest,
         outcome,
         stop_result,
         controller_stopped?,
         assertion_ids,
         failed_ids,
         assertion_count
       ) do
    assertions_complete? =
      assertion_ids == manifest.assertion_ids and failed_ids == [] and
        assertion_count == length(manifest.assertion_ids)

    reason =
      case_failure_reason(
        manifest,
        outcome,
        stop_result,
        controller_stopped?,
        assertion_ids,
        failed_ids,
        assertions_complete?
      )

    cond do
      is_nil(reason) -> {"PASS", "completed", []}
      reason == "timeout.expired" -> {"FAIL", "timeout", [reason]}
      true -> {"FAIL", "error", [reason]}
    end
  end

  defp case_failure_reason(
         manifest,
         outcome,
         stop_result,
         controller_stopped?,
         assertion_ids,
         failed_ids,
         assertions_complete?
       ) do
    assertion_reason = assertion_failure_reason(failed_ids, assertions_complete?, assertion_ids)

    cond do
      outcome == :registration_failure ->
        "registration.missing"

      not controller_stopped? ->
        "cleanup.unconfirmed"

      outcome == :timeout ->
        "timeout.expired"

      failed_ids != [] ->
        assertion_reason

      true ->
        trailing_case_failure_reason(manifest, outcome, assertion_reason, stop_result)
    end
  end

  defp trailing_case_failure_reason(manifest, outcome, assertion_reason, stop_result) do
    cond do
      outcome == :probe_exception -> "probe.failed"
      not is_nil(assertion_reason) -> assertion_reason
      stop_result != :ok -> "cleanup.unconfirmed"
      outcome != :ok -> "probe.failed"
      manifest.assertion_ids == [] -> "assertion.missing"
      true -> nil
    end
  end

  defp assertion_failure_reason(failed_ids, _complete?, _assertion_ids) when failed_ids != [],
    do: "assertion.failed"

  defp assertion_failure_reason([], false, []), do: "assertion.missing"
  defp assertion_failure_reason([], false, _assertion_ids), do: "assertion.incomplete"
  defp assertion_failure_reason([], true, _assertion_ids), do: nil

  defp assertion_snapshot(snapshot, case_id) when is_map(snapshot) do
    case Map.get(snapshot, case_id) do
      %{assertion_ids: ids, failed_ids: failed, count: count} -> {ids, failed, count}
      _ -> {[], [], 0}
    end
  end

  defp assertion_snapshot(_snapshot, _case_id), do: {[], [], 0}

  defp run_case(<<"cut.raise.", point::binary>>), do: cut_probe(point, :raise)
  defp run_case(<<"cut.terminate.", point::binary>>), do: cut_probe(point, :terminate)
  defp run_case("cut.consume_once"), do: consume_once_probe()
  defp run_case("cut.wrong_worker"), do: wrong_worker_probe()
  defp run_case("cut.unknown_name"), do: cut_error_probe(:unknown)
  defp run_case("cut.duplicate_arm"), do: cut_error_probe(:duplicate)
  defp run_case("cut.unreached"), do: cut_error_probe(:unreached)
  defp run_case("scenario.isolation"), do: scenario_isolation_probe()
  defp run_case("scenario.controller_death"), do: controller_death_probe()
  defp run_case("scenario.lost_reply"), do: lost_reply_probe()
  defp run_case("scenario.parent_crash"), do: parent_crash_probe()
  defp run_case("db.contention"), do: database_probe(:contention)
  defp run_case("db.reject_shared"), do: database_probe(:shared_connection)
  defp run_case("db.reject_sequential"), do: database_probe(:sequential)
  defp run_case("db.timeout_cleanup"), do: database_timeout_probe()
  defp run_case("db.worker_crash_cleanup"), do: database_worker_crash_probe()
  defp run_case("provider.outcomes"), do: provider_outcomes_probe()
  defp run_case("provider.backlog"), do: provider_backlog_probe()
  defp run_case("provider.duplicates_reorder"), do: provider_reorder_probe()
  defp run_case("provider.authentication_fixtures"), do: provider_authentication_probe()
  defp run_case("restart.consumption"), do: restart_consumption_probe()
  defp run_case("restart.fresh_connection"), do: fresh_connection_probe()
  defp run_case("result.missing_manifest"), do: registration_probe(:missing_manifest)
  defp run_case("result.missing_family"), do: registration_probe(:missing_family)
  defp run_case("result.missing_case"), do: registration_probe(:missing_case)
  defp run_case("result.missing_assertion"), do: result_shape_probe(:missing_assertion)
  defp run_case("result.empty_self_test"), do: result_shape_probe(:empty_self_test)
  defp run_case("result.metadata"), do: result_shape_probe(:metadata)
  defp run_case("result.dirty_source"), do: source_state_probe(:dirty)
  defp run_case("result.changed_source"), do: source_state_probe(:changed)
  defp run_case("result.callback_failures"), do: callback_failure_probe(false)
  defp run_case("result.broken_invariant_exit"), do: broken_invariant_probe()
  defp run_case("result.output_failure"), do: output_failure_probe()
  defp run_case("result.cleanup_failure"), do: cleanup_failure_probe()
  defp run_case("production.exclusion"), do: production_exclusion_probe()
  defp run_case("privacy.redaction"), do: callback_failure_probe(true)
  defp run_case(_case_id), do: {:error, "probe.unknown", false}

  defp cut_probe(point, mode) do
    scenario_probe(fn scenario ->
      case CutPoints.arm(scenario, point, :probe_worker, mode) do
        :ok -> run_armed_cut(scenario, point, mode)
        _ -> false
      end
    end)
  end

  defp run_armed_cut(scenario, point, mode) do
    parent = self()
    result_ref = make_ref()

    {pid, monitor} =
      Scenario.spawn(scenario, :probe_worker, fn ->
        result = cut_worker_result(scenario, point)
        send(parent, {result_ref, self(), result})
      end)

    verify_cut_mode(scenario, point, mode, result_ref, pid, monitor)
  end

  defp cut_worker_result(scenario, point) do
    CutPoints.hit(scenario, point, :probe_worker)
    :continued
  rescue
    error in RuntimeError -> {:raised, error.message}
  end

  defp verify_cut_mode(scenario, point, :raise, result_ref, pid, monitor) do
    outcome = receive_result(result_ref, pid)
    down = receive_down(monitor, pid)

    passed?(
      outcome == {:raised, "proof cut point #{point}"} and down == :normal and
        CutPoints.verify_consumed(scenario) == :ok
    )
  end

  defp verify_cut_mode(scenario, _point, :terminate, _result_ref, pid, monitor) do
    down = receive_down(monitor, pid)
    passed?(down == :proof_terminated and CutPoints.verify_consumed(scenario) == :ok)
  end

  defp consume_once_probe do
    scenario_probe(fn scenario ->
      point = "transaction.before_commit"

      case CutPoints.arm(scenario, point, :same_worker, :raise) do
        :ok -> run_consume_once_workers(scenario, point)
        _ -> false
      end
    end)
  end

  defp run_consume_once_workers(scenario, point) do
    parent = self()
    result_ref = make_ref()
    workers = spawn_consume_once_workers(scenario, point, parent, result_ref)
    Enum.each(workers, fn {pid, _monitor} -> send(pid, :hit) end)
    outcomes = Enum.map(workers, &consume_once_outcome(&1, result_ref))

    passed?(
      Enum.sort(Enum.map(outcomes, &elem(&1, 0))) == [:continued, :raised] and
        Enum.all?(outcomes, &(elem(&1, 1) == :normal)) and
        CutPoints.verify_consumed(scenario) == :ok
    )
  end

  defp spawn_consume_once_workers(scenario, point, parent, result_ref) do
    for _ <- 1..2 do
      Scenario.spawn(scenario, :same_worker, fn ->
        await_cut_hit()
        outcome = consume_once_worker_result(scenario, point)
        send(parent, {result_ref, self(), outcome})
      end)
    end
  end

  defp await_cut_hit do
    receive do
      :hit -> :ok
    end
  end

  defp consume_once_worker_result(scenario, point) do
    CutPoints.hit(scenario, point, :same_worker)
    :continued
  rescue
    RuntimeError -> :raised
  end

  defp consume_once_outcome({pid, monitor}, result_ref),
    do: {receive_result(result_ref, pid), receive_down(monitor, pid)}

  defp wrong_worker_probe do
    scenario_probe(fn scenario ->
      point = "transaction.before_commit"

      passed?(verify_wrong_worker_target(scenario, point))
    end)
  end

  defp verify_wrong_worker_target(scenario, point) do
    with :ok <- CutPoints.arm(scenario, point, :target, :raise),
         {:ok, :ok, :normal} <-
           run_worker(scenario, :other, fn -> CutPoints.hit(scenario, point, :other) end),
         {:ok, {:raised, message}, :normal} <-
           run_worker(scenario, :target, fn -> raised_cut_result(scenario, point, :target) end),
         true <- message == "proof cut point #{point}",
         :ok <- CutPoints.verify_consumed(scenario) do
      true
    else
      _ -> false
    end
  end

  defp raised_cut_result(scenario, point, worker) do
    CutPoints.hit(scenario, point, worker)
    :continued
  rescue
    error in RuntimeError -> {:raised, error.message}
  end

  defp cut_error_probe(kind) do
    scenario = Scenario.start()
    owned_processes = Scenario.owned_processes(scenario)
    point = "transaction.before_commit"

    result =
      case kind do
        :unknown ->
          with {:error, :unknown_cut_point} <-
                 CutPoints.arm(scenario, "unknown.cut", :worker, :raise),
               {:error, failures} <- Scenario.stop(scenario),
               true <- :unknown_cut_point in failures do
            :ok
          else
            _ -> :error
          end

        :duplicate ->
          with :ok <- CutPoints.arm(scenario, point, :worker, :raise),
               {:error, :duplicate_arm} <- CutPoints.arm(scenario, point, :worker, :raise),
               {:error, failures} <- Scenario.stop(scenario),
               true <- :duplicate_arm in failures do
            :ok
          else
            _ -> :error
          end

        :unreached ->
          {:ok, canonical_point} = CutPoints.normalize_name(point)

          with :ok <- CutPoints.arm(scenario, point, :worker, :raise),
               {:error, {:unreached_cut_points, [{^canonical_point, :worker}]}} <-
                 CutPoints.verify_consumed(scenario),
               {:error, failures} <- Scenario.stop(scenario),
               true <- failures != [] do
            :ok
          else
            _ -> :error
          end
      end

    workers_stopped? = record_scenario_cleanup(scenario, :down, owned_processes)
    passed?(result == :ok and workers_stopped?)
  end

  defp scenario_isolation_probe do
    first = Scenario.start()
    second = Scenario.start()
    first_processes = Scenario.owned_processes(first)
    second_processes = Scenario.owned_processes(second)
    point = "transaction.before_commit"

    first_result =
      with :ok <- CutPoints.arm(first, point, :worker, :raise),
           {:ok, :ok, :normal} <-
             run_worker(second, :worker, fn -> CutPoints.hit(second, point, :worker) end),
           {:ok, {:raised, message}, :normal} <-
             run_worker(first, :worker, fn ->
               try do
                 CutPoints.hit(first, point, :worker)
                 :continued
               rescue
                 error in RuntimeError -> {:raised, error.message}
               end
             end),
           true <- message == "proof cut point #{point}",
           :ok <- CutPoints.verify_consumed(first),
           :ok <- Scenario.stop(first),
           :ok <- Scenario.stop(second) do
        :ok
      else
        _ -> :error
      end

    first_stopped? = record_scenario_cleanup(first, :down, first_processes)
    second_stopped? = record_scenario_cleanup(second, :down, second_processes)
    stopped? = first_stopped? and second_stopped?
    record_cleanup(workers_stopped: stopped?)

    passed?(first_result == :ok and stopped?)
  end

  defp controller_death_probe do
    scenario = Scenario.start()
    owned_processes = Scenario.owned_processes(scenario)
    monitor = Process.monitor(scenario.controller)
    expected_kill = Scenario.expect_nested_controller_kill(scenario)
    Process.exit(scenario.controller, :kill)

    down = receive_down(monitor, scenario.controller)
    result = Scenario.request(scenario, :verify_consumed)
    confirmed_kill = Scenario.confirm_nested_controller_kill(scenario)
    record_scenario_cleanup(scenario, down, owned_processes)

    passed?(
      expected_kill == :ok and down == :killed and result == {:error, :controller_down} and
        confirmed_kill == :ok
    )
  end

  defp lost_reply_probe do
    scenario = Scenario.start()
    owned_processes = Scenario.owned_processes(scenario)

    verified? =
      with {:error, :invalid_timeout} <- Scenario.request(scenario, :verify_consumed, :infinity),
           {:error, :controller_timeout} <- Scenario.request(scenario, {:delay_reply, 50}, 5),
           true <-
             eventually(fn ->
               Scenario.request(scenario, :verify_consumed) == {:error, [:lost_reply]}
             end),
           {:error, [:lost_reply]} = stop_result <- Scenario.stop(scenario) do
        record_scenario_cleanup(scenario, stop_result, owned_processes)
        true
      else
        _ -> false
      end

    passed?(verified?)
  end

  defp parent_crash_probe do
    parent = self()
    owner_monitor = Process.monitor(spawn(fn -> owner_with_worker(parent) end))
    owner = receive do: ({:owner_ready, pid} -> pid)
    controller = receive do: ({:controller_ready, pid} -> pid)
    worker = receive do: ({:worker_ready, pid} -> pid)
    controller_monitor = Process.monitor(controller)
    worker_monitor = Process.monitor(worker)

    Process.exit(owner, :kill)

    verified? =
      receive_down(owner_monitor, owner) == :killed and
        receive_down(controller_monitor, controller) == :normal and
        receive_down(worker_monitor, worker) == :killed

    record_cleanup(workers_stopped: verified?)
    passed?(verified?)
  end

  defp owner_with_worker(parent) do
    scenario = Scenario.start()
    send(parent, {:owner_ready, self()})
    send(parent, {:controller_ready, scenario.controller})

    {_worker, _monitor} =
      Scenario.spawn(scenario, :waiting, fn ->
        send(parent, {:worker_ready, self()})

        receive do
          :never -> :ok
        end
      end)

    receive do
      :wait -> :ok
    end
  end

  defp database_probe(fixture) do
    scenario_probe(fn scenario ->
      record_database_cleanup_pending()
      result = Concurrent.infrastructure_fixture(scenario, fixture: fixture, timeout: 5_000)
      record_database_cleanup(result)
      passed?(database_fixture_verified?(fixture, result))
    end)
  end

  defp database_fixture_verified?(:contention, {:ok, proof}), do: genuine_contention?(proof)

  defp database_fixture_verified?(:shared_connection, {:error, proof}),
    do: shared_connection_rejected?(proof)

  defp database_fixture_verified?(:sequential, {:error, proof}),
    do: sequential_execution_rejected?(proof)

  defp database_fixture_verified?(_fixture, _result), do: false

  defp genuine_contention?(proof) do
    Map.get(proof, :contention_observed) == true and
      proof.backend_pids.a != proof.backend_pids.b and
      proof.transaction_ids.a != proof.transaction_ids.b and proof.cleanup.confirmed
  end

  defp shared_connection_rejected?(proof) do
    proof.reason == :shared_connection_rejected and
      proof.backend_pids.a == proof.backend_pids.b and proof.cleanup.confirmed
  end

  defp sequential_execution_rejected?(proof) do
    proof.reason == :sequential_execution_rejected and
      proof.backend_pids.a == proof.backend_pids.b and
      proof.transaction_ids.a != proof.transaction_ids.b and
      not proof.contention_observed and proof.cleanup.confirmed
  end

  defp record_database_cleanup(result) do
    database_cleanup_observations(result) |> record_cleanup()
  end

  @doc false
  @spec database_cleanup_observations(term()) :: %{
          required(:connections_released) => boolean(),
          required(:locks_released) => boolean()
        }
  def database_cleanup_observations({status, proof})
      when status in [:ok, :error] and is_map(proof) do
    case Map.get(proof, :cleanup) do
      cleanup when is_map(cleanup) ->
        %{
          connections_released: Map.get(cleanup, :confirmed) == true,
          locks_released:
            Map.get(cleanup, :locks_remaining) == 0 and
              Map.get(cleanup, :active_transactions) == 0
        }

      _ ->
        %{connections_released: false, locks_released: false}
    end
  end

  def database_cleanup_observations(_result),
    do: %{connections_released: false, locks_released: false}

  defp record_database_cleanup_pending do
    record_cleanup(connections_released: false, locks_released: false)
  end

  defp database_timeout_probe do
    scenario_probe(fn scenario ->
      record_database_cleanup_pending()
      parent = self()
      watcher_ref = make_ref()
      lock_key = positive_key()
      watcher = spawn(fn -> timeout_coordinator(parent, watcher_ref) end)

      callbacks = %{
        owner: fn ->
          NewYou.Repo.transaction(fn ->
            {:ok, _} =
              NewYou.Repo.query("SELECT pg_advisory_xact_lock(7319, $1)", [lock_key], log: false)

            send(watcher, {:owner_locked, self()})
            receive do: (:release -> :released)
          end)
        end,
        waiter: fn ->
          send(watcher, {:waiter_ready, self()})
          receive do: (:attempt -> :ok)

          timeout_result =
            NewYou.Repo.transaction(fn ->
              {:ok, _} =
                NewYou.Repo.query("SELECT set_config('lock_timeout', '25ms', true)", [],
                  log: false
                )

              case NewYou.Repo.query("SELECT pg_advisory_xact_lock(7319, $1)", [lock_key],
                     log: false
                   ) do
                {:error, %Postgrex.Error{postgres: %{pg_code: "55P03"}}} ->
                  NewYou.Repo.rollback(:postgres_lock_timeout)

                {:ok, _} ->
                  :unexpected_acquisition

                {:error, _} ->
                  NewYou.Repo.rollback(:unexpected_database_error)
              end
            end)

          send(
            watcher,
            {:waiter_timeout, self(), match?({:error, :postgres_lock_timeout}, timeout_result)}
          )

          timeout_result
        end
      }

      run_result = Concurrent.run(scenario, callbacks, timeout: 2_000)

      release =
        receive do
          {^watcher_ref, :released} -> :ok
        after
          1_000 -> :timeout
        end

      Process.exit(watcher, :kill)

      lock_count = remaining_advisory_locks(lock_key)
      connections_released? = match?({:ok, _}, run_result)
      locks_released? = lock_count == 0

      record_cleanup(
        connections_released: connections_released?,
        locks_released: locks_released?
      )

      passed?(connections_released? and release == :ok and locks_released?)
    end)
  end

  defp timeout_coordinator(parent, reference) do
    receive do
      {:waiter_ready, waiter} ->
        receive do
          {:owner_locked, owner} ->
            send(waiter, :attempt)

            receive do
              {:waiter_timeout, _waiter, true} ->
                send(owner, :release)
                send(parent, {reference, :released})
            after
              1_000 -> send(owner, :release)
            end
        end
    after
      1_000 -> :timeout
    end
  end

  defp remaining_advisory_locks(lock_key) do
    with :ok <- Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false),
         {:ok, %{rows: [[count]]}} <-
           NewYou.Repo.query(
             "SELECT count(*) FROM pg_locks WHERE locktype = 'advisory' AND classid = 7319::oid AND objid = $1::oid AND objsubid = 2",
             [lock_key],
             log: false
           ) do
      Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
      count
    else
      _ ->
        Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
        :unknown
    end
  rescue
    _ -> :unknown
  end

  defp active_backend_count(backend_pid) when is_integer(backend_pid) do
    with :ok <- Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false),
         {:ok, %{rows: [[count]]}} <-
           NewYou.Repo.query(
             "SELECT count(*) FROM pg_stat_activity WHERE pid = $1",
             [backend_pid],
             log: false
           ) do
      Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
      count
    else
      _ ->
        Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
        :unknown
    end
  rescue
    _ -> :unknown
  end

  defp active_backend_count(_backend_pid), do: :unknown

  defp await_backend_closed(backend_pid), do: await_backend_closed(backend_pid, 100)
  defp await_backend_closed(_backend_pid, 0), do: :unknown

  defp await_backend_closed(backend_pid, attempts) do
    case active_backend_count(backend_pid) do
      0 ->
        0

      _ ->
        Process.sleep(10)
        await_backend_closed(backend_pid, attempts - 1)
    end
  end

  defp database_worker_crash_probe do
    record_database_cleanup_pending()
    scenario = Scenario.start()
    parent = self()
    lock_key = positive_key()

    run_result =
      Concurrent.run(
        scenario,
        %{
          transaction: fn ->
            NewYou.Repo.transaction(fn ->
              {:ok, _} =
                NewYou.Repo.query("SELECT pg_advisory_xact_lock(7319, $1)", [lock_key],
                  log: false
                )

              {:ok, %{rows: [[xid]]}} =
                NewYou.Repo.query("SELECT pg_current_xact_id()::text", [], log: false)

              {:ok, %{rows: [[backend_pid]]}} =
                NewYou.Repo.query("SELECT pg_backend_pid()", [], log: false)

              send(parent, {:crashed_transaction, xid, backend_pid, lock_key})
              Process.exit(self(), :kill)
            end)
          end
        },
        timeout: 1_000
      )

    owned_processes = Scenario.owned_processes(scenario)

    {xid, old_backend_pid, lock_key} =
      receive do
        {:crashed_transaction, xid, pid, lock_key} -> {xid, pid, lock_key}
      after
        1_000 -> {nil, nil, nil}
      end

    status = await_aborted_transaction(xid)
    backend_count = await_backend_closed(old_backend_pid)
    lock_count = remaining_advisory_locks(lock_key)
    replacement_pid = replacement_backend_pid()
    stop = Scenario.stop(scenario)
    workers_stopped? = record_scenario_cleanup(scenario, stop, owned_processes)
    connections_released? = backend_count == 0
    locks_released? = lock_count == 0

    record_cleanup(
      connections_released: connections_released?,
      locks_released: locks_released?
    )

    passed?(
      match?({:error, _}, run_result) and status == "aborted" and
        is_integer(replacement_pid) and replacement_pid != old_backend_pid and
        workers_stopped? and connections_released? and locks_released? and
        match?({:error, _}, stop)
    )
  rescue
    _ -> {:error, "database.probe_failed", false}
  end

  defp transaction_status(nil), do: nil

  defp transaction_status(xid) do
    with {transaction_id, ""} <- Integer.parse(xid),
         :ok <- Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false),
         {:ok, %{rows: [[status]]}} <-
           NewYou.Repo.query("SELECT pg_xact_status($1::xid8)", [transaction_id], log: false) do
      Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
      status
    else
      _ ->
        Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
        nil
    end
  rescue
    _ -> nil
  end

  defp await_aborted_transaction(nil), do: nil
  defp await_aborted_transaction(xid), do: await_aborted_transaction(xid, 100)
  defp await_aborted_transaction(_xid, 0), do: nil

  defp await_aborted_transaction(xid, attempts) do
    case transaction_status(xid) do
      "aborted" ->
        "aborted"

      _ ->
        Process.sleep(10)
        await_aborted_transaction(xid, attempts - 1)
    end
  end

  defp replacement_backend_pid do
    scenario = Scenario.start()
    parent = self()

    result =
      case Concurrent.run(
             scenario,
             %{
               replacement: fn ->
                 {:ok, %{rows: [[backend_pid]]}} =
                   NewYou.Repo.query("SELECT pg_backend_pid()", [], log: false)

                 send(parent, {:replacement_backend, backend_pid})
                 :ok
               end
             },
             timeout: 1_000
           ) do
        {:ok, _} ->
          receive do
            {:replacement_backend, backend_pid} -> backend_pid
          after
            1_000 -> nil
          end

        _ ->
          nil
      end

    owned_processes = Scenario.owned_processes(scenario)
    stop_result = if Process.alive?(scenario.controller), do: Scenario.stop(scenario), else: :down
    workers_stopped? = record_scenario_cleanup(scenario, stop_result, owned_processes)
    if workers_stopped?, do: result, else: nil
  end

  defp provider_outcomes_probe do
    scenario_probe(fn scenario ->
      operation = "synthetic-operation"

      outcomes = [
        not_invoked: :not_invoked,
        rejected: :rejected_before_submission,
        accepted: :accepted,
        delivered: :delivered,
        failed: :bounced_or_failed,
        uncertain: :unknown,
        confirmed_absent: :confirmed_no_operation,
        reconciled_rejection: :reconciliation_rejected,
        reconciled_acceptance: :reconciliation_accepted,
        reconciled_delivery: :reconciliation_delivered,
        reconciled_failure: :reconciliation_failed
      ]

      verified? =
        with :ok <- Provider.configure(scenario, %{operation => outcomes}),
             true <- provider_outcomes_match?(scenario, operation, outcomes),
             {:error, :script_exhausted} <- Provider.next(scenario, operation, :uncertain) do
          true
        else
          _ -> false
        end

      passed?(verified?)
    end)
  end

  defp provider_outcomes_match?(scenario, operation, outcomes) do
    Enum.all?(outcomes, fn {step, expected} ->
      match?({:ok, %{outcome: ^expected}}, Provider.next(scenario, operation, step))
    end)
  end

  defp provider_backlog_probe do
    scenario_probe(fn scenario ->
      operation = "synthetic-backlog"

      verified? =
        with :ok <- Provider.configure(scenario, %{operation => [queue: :backlog]}),
             {:ok, %{outcome: :backlog, released: false}} <-
               Provider.next(scenario, operation, :queue),
             {:ok, %{outcome: :backlog, released: true}} <-
               Provider.release_backlog(scenario, operation) do
          true
        else
          _ -> false
        end

      passed?(verified?)
    end)
  end

  defp provider_reorder_probe do
    scenario_probe(fn scenario ->
      operation = "synthetic-order"

      steps = [
        {:event_b, %{outcome: :delivered, event_ref: "event-b", logical_order: 2}},
        {:event_a, %{outcome: :accepted, event_ref: "event-a", logical_order: 1}},
        {:event_a_duplicate, %{outcome: :accepted, event_ref: "event-a", logical_order: 1}}
      ]

      verified? =
        with :ok <- Provider.configure(scenario, %{operation => steps}),
             results <-
               Enum.map(
                 [:event_b, :event_a, :event_a_duplicate],
                 &Provider.next(scenario, operation, &1)
               ),
             true <- Enum.all?(results, &match?({:ok, _}, &1)),
             true <-
               Enum.map(results, fn {:ok, event} -> event.event_ref end) == [
                 "event-b",
                 "event-a",
                 "event-a"
               ] do
          true
        else
          _ -> false
        end

      passed?(verified?)
    end)
  end

  defp provider_authentication_probe do
    operation = "synthetic-auth-operation"
    body = "synthetic reconciliation fixture"
    key = ProviderFixtures.key()
    signature = ProviderFixtures.sign(operation <> "|" <> body, key)
    mismatched_signature = ProviderFixtures.sign("different-operation|" <> body, key)

    passed?(
      Provider.authenticate_fixture({operation, operation, body}, signature, key) ==
        {:ok, :authenticated} and
        Provider.authenticate_fixture({operation, operation, body}, <<0::256>>, key) ==
          {:error, :invalid_signature} and
        Provider.authenticate_fixture(
          {operation, "different-operation", body},
          mismatched_signature,
          key
        ) ==
          {:error, :operation_reference_mismatch}
    )
  end

  defp restart_consumption_probe do
    scenario_probe(fn scenario ->
      point = "transaction.before_commit"

      verified? =
        with :ok <- CutPoints.arm(scenario, point, :application_worker, :raise),
             {:ok, {:raised, message}, :normal} <-
               run_worker(
                 scenario,
                 :application_worker,
                 raised_cut_callback(scenario, point)
               ),
             true <- message == "proof cut point #{point}",
             {:ok, :ok, :normal} <-
               run_worker(scenario, :application_worker, repeat_cut_callback(scenario, point)),
             :ok <- CutPoints.verify_consumed(scenario) do
          true
        else
          _ -> false
        end

      passed?(verified?)
    end)
  end

  defp repeat_cut_point(scenario, point),
    do: CutPoints.hit(scenario, point, :application_worker)

  defp repeat_cut_callback(scenario, point),
    do: fn -> repeat_cut_point(scenario, point) end

  defp raised_cut_callback(scenario, point),
    do: fn -> raised_cut_result(scenario, point, :application_worker) end

  defp fresh_connection_probe do
    scenario_probe(fn _scenario -> execute_fresh_connection_probe() end)
  end

  defp execute_fresh_connection_probe do
    record_database_cleanup_pending()
    parent = self()
    reference = make_ref()
    lock_key = positive_key()
    original_scenario = Scenario.start()
    first_run = start_crashed_database_worker(original_scenario, parent, reference, lock_key)
    {original_pid, observed_lock_key} = receive_original_backend(reference)
    original = clean_original_connection(original_scenario, original_pid, observed_lock_key)
    replacement = start_replacement_connection(parent, reference)

    record_cleanup(
      connections_released: original.backend_closed? and replacement.succeeded?,
      locks_released: original.lock_released?,
      workers_stopped: original.workers_stopped? and replacement.workers_stopped?
    )

    passed?(
      fresh_original_valid?(first_run, original_pid, observed_lock_key, original) and
        fresh_replacement_valid?(original_pid, replacement)
    )
  end

  defp start_crashed_database_worker(scenario, parent, reference, lock_key) do
    Concurrent.run(
      scenario,
      %{
        original_worker: fn ->
          NewYou.Repo.transaction(fn ->
            {:ok, _} =
              NewYou.Repo.query("SELECT pg_advisory_xact_lock(7319, $1)", [lock_key], log: false)

            {:ok, %{rows: [[backend_pid]]}} =
              NewYou.Repo.query("SELECT pg_backend_pid()", [], log: false)

            send(parent, {reference, :original, backend_pid, lock_key})
            Process.exit(self(), :kill)
          end)
        end
      },
      timeout: 1_000
    )
  end

  defp receive_original_backend(reference) do
    receive do
      {^reference, :original, backend_pid, lock_key} -> {backend_pid, lock_key}
    after
      1_000 -> {nil, nil}
    end
  end

  defp clean_original_connection(scenario, backend_pid, lock_key) do
    owned_processes = Scenario.owned_processes(scenario)
    backend_closed? = await_backend_closed(backend_pid) == 0
    lock_released? = remaining_advisory_locks(lock_key) == 0
    stop_result = Scenario.stop(scenario)
    workers_stopped? = record_scenario_cleanup(scenario, stop_result, owned_processes)

    %{
      backend_closed?: backend_closed?,
      lock_released?: lock_released?,
      workers_stopped?: workers_stopped?,
      stop_result: stop_result
    }
  end

  defp start_replacement_connection(parent, reference) do
    scenario = Scenario.start()

    run =
      Concurrent.run(
        scenario,
        %{
          replacement_worker: fn ->
            {:ok, %{rows: [[backend_pid]]}} =
              NewYou.Repo.query("SELECT pg_backend_pid()", [], log: false)

            send(parent, {reference, :replacement, backend_pid})
            :ok
          end
        },
        timeout: 1_000
      )

    backend_pid = receive_replacement_backend(reference)
    owned_processes = Scenario.owned_processes(scenario)
    stop_result = Scenario.stop(scenario)
    workers_stopped? = record_scenario_cleanup(scenario, stop_result, owned_processes)

    %{
      run: run,
      backend_pid: backend_pid,
      succeeded?: match?({:ok, _}, run),
      workers_stopped?: workers_stopped?,
      stop_result: stop_result
    }
  end

  defp receive_replacement_backend(reference) do
    receive do
      {^reference, :replacement, backend_pid} -> backend_pid
    after
      1_000 -> nil
    end
  end

  defp fresh_original_valid?(first_run, original_pid, observed_lock_key, original) do
    match?({:error, _}, first_run) and is_integer(original_pid) and is_integer(observed_lock_key) and
      original.backend_closed? and original.lock_released? and original.workers_stopped? and
      (original.stop_result == :ok or match?({:error, _}, original.stop_result))
  end

  defp fresh_replacement_valid?(original_pid, replacement) do
    replacement.succeeded? and is_integer(replacement.backend_pid) and
      replacement.backend_pid != original_pid and replacement.workers_stopped? and
      replacement.stop_result == :ok
  end

  defp registration_probe(kind) do
    manifests = Catalog.required().self_test.cases
    registrations = Enum.map(manifests, &registration("harness", &1.case_id, &1.invariant_id))

    result =
      case kind do
        :missing_manifest ->
          :missing_manifest in Catalog.validate_registrations([], :tb001).errors

        :missing_family ->
          length(Catalog.validate_registrations([], :tb001).missing_families) ==
            length(Catalog.coverage_inventory()) - map_size(Catalog.required().business_manifests)

        :missing_case ->
          incomplete = List.delete_at(registrations, length(registrations) - 1)

          :missing_self_test_registration in Catalog.validate_registrations(
            incomplete,
            :harness_self_test
          ).errors
      end

    passed?(result)
  end

  defp result_shape_probe(:missing_assertion),
    do: passed?(missing_assertion_rejected?(self_test_result()))

  defp result_shape_probe(:empty_self_test),
    do: passed?(empty_self_test_rejected?(self_test_result()))

  defp result_shape_probe(:metadata),
    do: passed?(incomplete_metadata_rejected?(self_test_result()))

  defp missing_assertion_rejected?(result) do
    [entry] = result["results"]
    [first | rest] = entry["cases"]
    broken = %{first | "assertion_ids" => [], "assertions_executed" => 0}
    result = %{result | "results" => [%{entry | "cases" => [broken | rest]}]}
    result_rejected_for?(result, :invalid_case_pass)
  end

  defp empty_self_test_rejected?(result) do
    [entry] = result["results"]
    empty = %{entry | "required_case_ids" => [], "cases" => []}
    result = %{result | "results" => [empty]}
    result_rejected_for?(result, :incomplete_self_test_manifest)
  end

  defp incomplete_metadata_rejected?(result) do
    result = %{result | "metadata_complete" => true}
    result_rejected_for?(result, :incomplete_metadata_claim)
  end

  defp result_rejected_for?(result, reason) do
    case Result.validate(result, mode: :harness_self_test) do
      {:error, reasons} -> reason in reasons
      :ok -> false
    end
  end

  defp source_state_probe(kind) do
    result = full_result_with_metadata()
    record_cleanup(connections_released: true)
    git = result["git"]

    result =
      case kind do
        :dirty ->
          %{result | "git" => %{git | "clean_before" => false, "clean_after" => false}}

        :changed ->
          %{result | "git" => %{git | "head_after" => String.duplicate("c", 40)}}
      end

    case Result.validate(result, mode: :tb001) do
      {:error, reasons} -> :source_state_failure_mismatch in reasons
      :ok -> false
    end
    |> passed?()
  end

  defp callback_failure_probe(redaction?) do
    scenario = Scenario.start()
    secret = "synthetic-secret-canary"

    callback = fn ->
      if redaction?, do: raise(secret), else: raise("bounded synthetic failure")
    end

    result = Concurrent.run(scenario, %{failure: callback}, timeout: 1_000)
    result_text = inspect(result)
    owned_processes = Scenario.owned_processes(scenario)
    stop = Scenario.stop(scenario)
    workers_stopped? = record_scenario_cleanup(scenario, stop, owned_processes)

    expected = match?({:error, _}, result) and stop == :ok and workers_stopped?
    redacted = not String.contains?(result_text, secret)
    passed?(expected and redacted)
  end

  defp broken_invariant_probe do
    output =
      Path.join(
        System.tmp_dir!(),
        "proof-broken-invariant-#{System.unique_integer([:positive])}.json"
      )

    try do
      {cli_output, exit_code} =
        System.cmd(
          "mix",
          [
            "run",
            "test/proof/run.exs",
            "--mode",
            "diagnostic",
            "--output",
            output,
            "--case",
            @broken_invariant_case,
            "--fixture",
            "broken_invariant"
          ],
          stderr_to_stdout: true,
          env: [{"MIX_ENV", "test"}]
        )

      case_result = read_broken_invariant_case(output)
      record_broken_invariant_observations(exit_code, case_result)

      passed?(exit_code == 1 and cli_output != :error and expected_broken_invariant?(case_result))
    rescue
      _ -> passed?(false)
    after
      File.rm(output)
    end
  end

  defp read_broken_invariant_case(output) do
    artifact =
      case File.read(output) do
        {:ok, contents} -> Jason.decode(contents)
        _ -> {:error, :missing_artifact}
      end

    case broken_invariant_artifact(artifact) do
      {case_result, true} -> case_result
      _ -> %{}
    end
  end

  defp record_broken_invariant_observations(exit_code, case_result) do
    Process.put(@observations_context_key, [
      %{"code" => "broken_invariant.exit_code", "value" => exit_code},
      %{"code" => "broken_invariant.case", "value" => case_result["case_id"]},
      %{"code" => "broken_invariant.invariant", "value" => case_result["invariant_id"]},
      %{"code" => "broken_invariant.cut_point", "value" => case_result["cut_point"]},
      %{
        "code" => "broken_invariant.reason_code",
        "value" => List.first(case_result["reason_codes"] || [])
      }
    ])
  end

  defp expected_broken_invariant?(case_result) do
    Map.take(case_result, ~w(case_id invariant_id cut_point verdict)) == %{
      "case_id" => @broken_invariant_case,
      "invariant_id" => @broken_invariant_case,
      "cut_point" => "transaction.before_commit",
      "verdict" => "FAIL"
    } and "assertion.failed" in (case_result["reason_codes"] || [])
  end

  defp broken_invariant_artifact(
         {:ok, %{"mode" => "diagnostic", "overall_verdict" => "FAIL"} = result}
       ) do
    case result["results"] do
      [%{"coverage_id" => "harness", "cases" => [case_result]}] -> {case_result, true}
      _ -> {%{}, false}
    end
  end

  defp broken_invariant_artifact(_artifact), do: {%{}, false}

  defp output_failure_probe do
    directory = Path.join(System.tmp_dir!(), "p8-04-output-#{System.unique_integer([:positive])}")
    File.mkdir!(directory)
    output = Path.join(directory, "result.json")
    :ok = File.write(output, "existing")

    result = Result.write_atomic(output, %{"overall_verdict" => "PASS"})
    preserved = File.read!(output) == "existing"
    File.rm_rf!(directory)

    passed?(result == {:error, :output_failure} and preserved)
  end

  defp cleanup_failure_probe do
    passed?(
      Result.verdict(
        mode: :harness_self_test,
        metadata_complete: true,
        checks: [:pass],
        cleanup: :fail
      ) == %{overall_verdict: "FAIL", exit_code: 2}
    )
  end

  defp production_exclusion_probe do
    {build_succeeded?, modules_absent?, runtime_ineffective?} = production_build_evidence()

    Process.put(@observations_context_key, [
      %{"code" => "production.build_succeeded", "value" => build_succeeded?},
      %{"code" => "production.modules_absent", "value" => modules_absent?},
      %{"code" => "production.runtime_ineffective", "value" => runtime_ineffective?}
    ])

    passed?(Mix.env() == :test and build_succeeded? and modules_absent? and runtime_ineffective?)
  end

  defp production_build_evidence do
    mix = System.find_executable("mix")
    elixir = System.find_executable("elixir")
    timeout = System.find_executable("timeout")
    root = Path.expand("../..", __DIR__)

    build_path =
      Path.join(System.tmp_dir!(), "new-you-p8-04-prod-#{System.unique_integer([:positive])}")

    if is_binary(mix) and is_binary(elixir) and is_binary(timeout) do
      try do
        env = [{"MIX_ENV", "prod"}, {"MIX_BUILD_PATH", build_path}]

        {_compile_output, compile_status} =
          System.cmd(timeout, ["180", mix, "compile"],
            cd: root,
            env: env,
            stderr_to_stdout: true
          )

        modules_absent? =
          compile_status == 0 and
            Path.wildcard(
              Path.join([build_path, "lib", "new_you", "ebin", "Elixir.NewYou.Proof.*.beam"])
            ) == []

        hook_absent? = production_owner_hook_absent?(build_path)

        expression =
          "Application.put_env(:new_you, :proof, %{enabled: true}); if Application.get_env(:new_you, :proof) != %{enabled: true} or Code.ensure_loaded?(NewYou.Proof.Runner), do: System.halt(1)"

        app_beam_path = Path.join([build_path, "lib", "new_you", "ebin"])

        {_runtime_output, runtime_status} =
          System.cmd(timeout, ["180", elixir, "-pa", app_beam_path, "-e", expression],
            cd: root,
            env: env,
            stderr_to_stdout: true
          )

        {compile_status == 0, modules_absent? and hook_absent?, runtime_status == 0}
      rescue
        _ -> {false, false, false}
      after
        File.rm_rf(build_path)
      end
    else
      {false, false, false}
    end
  end

  defp production_owner_hook_absent?(build_path) do
    owner_beam =
      Path.join([
        build_path,
        "lib",
        "new_you",
        "ebin",
        "Elixir.NewYou.Identity.Actions.AcceptRegistration.beam"
      ])

    case :beam_lib.chunks(String.to_charlist(owner_beam), [:imports]) do
      {:ok, {_module, [imports: imports]}} ->
        Enum.all?(imports, fn {module, _function, _arity} ->
          not String.starts_with?(Atom.to_string(module), "Elixir.NewYou.Proof.") and
            module != Mix
        end)

      _ ->
        false
    end
  end

  defp self_test_result do
    manifests = Catalog.required().self_test.cases

    cases =
      Enum.map(manifests, fn manifest ->
        %{
          "case_id" => manifest.case_id,
          "invariant_id" => manifest.invariant_id,
          "boundary" => manifest.boundary,
          "cut_point" => manifest.cut_point,
          "race_id" => nil,
          "status" => "completed",
          "verdict" => "PASS",
          "expected" => manifest.expected,
          "observations" => [%{"code" => "probe.verified", "value" => true}],
          "assertion_ids" => manifest.assertion_ids,
          "assertions_executed" => length(manifest.assertion_ids),
          "duration_ms" => 0,
          "timeout_ms" => manifest.timeout_ms,
          "timeout_override_reason" => manifest.timeout_override_reason,
          "reason_codes" => []
        }
      end)

    %{
      "schema_version" => "1.0.0",
      "run_id" => "self-test-fixture",
      "mode" => "harness_self_test",
      "contract" => "TB-001/v0.1.2",
      "metadata_complete" => false,
      "git" => %{
        "head_before" => nil,
        "head_after" => nil,
        "clean_before" => nil,
        "clean_after" => nil,
        "lock_sha256_before" => nil,
        "lock_sha256_after" => nil
      },
      "runtime" => %{
        "elixir" => nil,
        "otp" => nil,
        "erts" => nil,
        "postgresql" => nil,
        "mix_env" => nil
      },
      "dependencies" => [],
      "coverage_inventory" => Catalog.coverage_inventory(),
      "results" => [
        %{
          "coverage_id" => "harness",
          "manifest_sha256" => Catalog.required().self_test.digest,
          "required_case_ids" => Enum.map(cases, & &1["case_id"]),
          "status" => "completed",
          "verdict" => "PASS",
          "reason_codes" => [],
          "cases" => cases
        }
      ],
      "cleanup" => %{
        "verdict" => "PASS",
        "workers_stopped" => true,
        "connections_released" => true,
        "locks_released" => true,
        "reason_codes" => []
      },
      "overall_verdict" => "FAIL",
      "exit_code" => 2,
      "reason_codes" => ["metadata.unavailable"]
    }
  end

  defp full_result_with_metadata do
    source = Result.capture_source()
    runtime = Result.capture_runtime()
    {:ok, dependencies} = Result.capture_dependencies()
    {:ok, postgres_version} = Result.capture_postgresql()

    results =
      Enum.map(Catalog.coverage_inventory(), fn coverage_id ->
        %{
          "coverage_id" => coverage_id,
          "manifest_sha256" => nil,
          "required_case_ids" => [],
          "status" => "missing",
          "verdict" => "FAIL",
          "reason_codes" => ["missing.manifest"],
          "cases" => []
        }
      end)

    %{
      "schema_version" => "1.0.0",
      "run_id" => "full-fixture",
      "mode" => "tb001",
      "contract" => "TB-001/v0.1.2",
      "metadata_complete" => true,
      "git" => %{
        "head_before" => source.head,
        "head_after" => source.head,
        "clean_before" => true,
        "clean_after" => true,
        "lock_sha256_before" => source.lock_sha256,
        "lock_sha256_after" => source.lock_sha256
      },
      "runtime" => %{
        "elixir" => runtime.elixir,
        "otp" => runtime.otp,
        "erts" => runtime.erts,
        "postgresql" => postgres_version,
        "mix_env" => "test"
      },
      "dependencies" => dependencies,
      "coverage_inventory" => Catalog.coverage_inventory(),
      "results" => results,
      "cleanup" => %{
        "verdict" => "FAIL",
        "workers_stopped" => false,
        "connections_released" => false,
        "locks_released" => false,
        "reason_codes" => ["missing.coverage"]
      },
      "overall_verdict" => "FAIL",
      "exit_code" => 1,
      "reason_codes" => ["missing.coverage"]
    }
  end

  defp registration(coverage_id, case_id, invariant_id),
    do: %{
      coverage_id: coverage_id,
      case_id: case_id,
      invariant_id: invariant_id,
      callback: fn -> :ok end
    }

  defp case_result(
         manifest,
         status,
         verdict,
         assertion_ids,
         reason_codes,
         observations \\ nil,
         duration_ms \\ 0
       ) do
    %{
      "case_id" => manifest.case_id,
      "invariant_id" => manifest.invariant_id,
      "boundary" => manifest.boundary,
      "cut_point" => manifest.cut_point,
      "race_id" => nil,
      "status" => status,
      "verdict" => verdict,
      "expected" => manifest.expected,
      "observations" => case_observations(verdict, assertion_ids, observations),
      "assertion_ids" => assertion_ids,
      "assertions_executed" => length(assertion_ids),
      "duration_ms" => duration_ms,
      "timeout_ms" => manifest.timeout_ms,
      "timeout_override_reason" => Map.get(manifest, :timeout_override_reason),
      "reason_codes" => reason_codes
    }
  end

  defp case_observations("PASS", _assertion_ids, observations) when is_list(observations),
    do: observations

  defp case_observations("PASS", assertion_ids, _observations),
    do: [%{"code" => "assertions.recorded", "value" => length(assertion_ids)}]

  defp case_observations(_verdict, _assertion_ids, observations) when is_list(observations),
    do: observations

  defp case_observations(_verdict, _assertion_ids, _observations), do: []

  defp not_run_case(manifest),
    do: case_result(manifest, "not_run", "FAIL", [], ["earlier.failure"])

  defp scenario_probe(fun) do
    record_cleanup(workers_stopped: false)
    scenario = Scenario.start()

    outcome =
      try do
        fun.(scenario)
      rescue
        _ -> false
      catch
        _, _ -> false
      end

    owned_processes = Scenario.owned_processes(scenario)
    stop_result = if Process.alive?(scenario.controller), do: Scenario.stop(scenario), else: :down
    workers_stopped? = record_scenario_cleanup(scenario, stop_result, owned_processes)
    workers_stopped? = workers_stopped? and Process.get(@cleanup_context_key).workers_stopped
    record_cleanup(workers_stopped: workers_stopped?)
    cleanup = stop_result == :ok and workers_stopped?

    cond do
      outcome == :ok and cleanup -> :ok
      not cleanup -> {:error, "cleanup.unconfirmed", false}
      true -> {:error, "probe.failed", true}
    end
  end

  defp run_worker(scenario, label, fun) do
    parent = self()
    result_ref = make_ref()

    {pid, monitor} =
      Scenario.spawn(scenario, label, fn ->
        result = fun.()
        send(parent, {result_ref, self(), result})
      end)

    {receive_result(result_ref, pid), receive_down(monitor, pid)}
    |> then(fn {result, reason} -> {:ok, result, reason} end)
  end

  defp receive_result(reference, pid) do
    receive do
      {^reference, ^pid, result} -> result
    after
      1_000 -> :timeout
    end
  end

  defp receive_down(monitor, pid) do
    receive do
      {:DOWN, ^monitor, :process, ^pid, reason} -> reason
    after
      1_000 -> :timeout
    end
  end

  defp eventually(predicate, attempts \\ 100)
  defp eventually(_predicate, 0), do: false

  defp eventually(predicate, attempts) do
    if predicate.() do
      true
    else
      Process.sleep(1)
      eventually(predicate, attempts - 1)
    end
  end

  defp positive_key, do: rem(System.unique_integer([:positive, :monotonic]), 2_000_000_000) + 1

  defp clean_cleanup,
    do: %{workers_stopped: true, connections_released: true, locks_released: true}

  defp initial_case_cleanup("p805." <> _),
    do: %{workers_stopped: true, connections_released: false, locks_released: false}

  defp initial_case_cleanup(_case_id), do: clean_cleanup()

  defp record_cleanup(updates) do
    case Process.get(@cleanup_context_key) do
      cleanup when is_map(cleanup) ->
        Process.put(@cleanup_context_key, Map.merge(cleanup, Map.new(updates)))
        :ok

      _ ->
        :ok
    end
  end

  defp record_scenario_cleanup(scenario, _stop_result, owned_processes) do
    worker_pids =
      case owned_processes do
        workers when is_list(workers) ->
          Enum.flat_map(workers, fn {worker, guardian} -> [worker, guardian] end)

        _ ->
          [:unknown]
      end

    workers_stopped? =
      not Process.alive?(scenario.controller) and
        Enum.all?(worker_pids, fn
          pid when is_pid(pid) -> not Process.alive?(pid)
          _ -> false
        end)

    record_cleanup(workers_stopped: workers_stopped?)
    workers_stopped?
  end

  defp merge_cleanup(left, right) do
    Map.new(left, fn {key, value} -> {key, value and Map.get(right, key, false)} end)
  end

  defp cleanup_result(cleanup) do
    complete? = Enum.all?(Map.values(cleanup), &(&1 == true))

    %{
      "verdict" => if(complete?, do: "PASS", else: "FAIL"),
      "workers_stopped" => cleanup.workers_stopped,
      "connections_released" => cleanup.connections_released,
      "locks_released" => cleanup.locks_released,
      "reason_codes" => if(complete?, do: [], else: ["cleanup.unconfirmed"])
    }
  end

  defp passed?(condition) do
    case Process.get(@assertion_context_key) do
      {_scenario, _case_id, [assertion_id | _]} ->
        expect_manifest!(assertion_id, condition === true, true)
        :ok

      _ ->
        raise RuntimeError, "proof assertion context missing"
    end
  end
end
