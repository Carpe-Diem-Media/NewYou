defmodule NewYou.Proof.Concurrent do
  @moduledoc false

  import Bitwise

  alias NewYou.Proof.Scenario

  @default_timeout 5_000
  @cleanup_timeout 5_000
  @observer_response_grace 250
  @observer_query_margin 250

  @spec run(Scenario.t(), %{required(Scenario.worker_label()) => (-> term())}, keyword()) ::
          {:ok, map()} | {:error, map()}
  def run(%Scenario{} = scenario, callbacks, opts \\ []) when is_map(callbacks) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    case valid_callbacks?(callbacks, timeout) do
      :ok ->
        parent = self()

        workers = Enum.map(callbacks, &spawn_callback(scenario, parent, &1))

        await_callbacks(scenario, workers, timeout)

      {:error, reason} ->
        {:error, %{reason: reason, outcomes: %{}}}
    end
  end

  defp valid_callbacks?(callbacks, timeout) do
    if valid_timeout?(timeout) and callbacks != %{} and
         Enum.all?(callbacks, fn {_label, callback} -> is_function(callback, 0) end),
       do: :ok,
       else: {:error, :invalid_options}
  end

  defp spawn_callback(scenario, parent, {label, callback}) do
    Scenario.spawn(scenario, label, fn -> execute_callback(parent, label, callback) end)
  end

  @spec infrastructure_fixture(Scenario.t(), keyword()) :: {:ok, map()} | {:error, map()}
  def infrastructure_fixture(%Scenario{} = scenario, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    fixture = Keyword.get(opts, :fixture, :contention)

    cond do
      not valid_timeout?(timeout) ->
        {:error, %{reason: :invalid_timeout, cleanup: %{confirmed: false}}}

      fixture == :contention ->
        run_contention(scenario, timeout)

      fixture == :nonblocking ->
        run_contention(scenario, timeout, :nonblocking)

      fixture == :shared_connection ->
        shared_connection_fixture(scenario, timeout)

      fixture == :sequential ->
        sequential_fixture(scenario, timeout)

      true ->
        {:error, %{reason: :invalid_fixture, cleanup: %{confirmed: false}}}
    end
  end

  defp shared_connection_fixture(scenario, timeout) do
    parent = self()
    deadline = now_ms() + timeout
    reference_a = make_ref()
    reference_b = make_ref()

    case Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo) do
      :ok ->
        worker_a =
          Scenario.spawn(scenario, :shared_a, fn -> shared_identity(parent, reference_a) end)

        worker_b =
          Scenario.spawn(scenario, :shared_b, fn -> shared_identity(parent, reference_b) end)

        result =
          shared_fixture_result(scenario, worker_a, worker_b, reference_a, reference_b, deadline)

        case Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo) do
          :ok -> result
          _ -> {:error, %{reason: :checkin_failed, cleanup: %{confirmed: false}}}
        end

      {:already, _kind} ->
        {:error, %{reason: :connection_already_owned, cleanup: %{confirmed: false}}}
    end
  end

  defp shared_fixture_result(scenario, worker_a, worker_b, reference_a, reference_b, deadline) do
    case {allow_shared_worker(worker_a), allow_shared_worker(worker_b)} do
      {:ok, :ok} ->
        send(elem(worker_a, 0), {:read_identity, reference_a})
        send(elem(worker_b, 0), {:read_identity, reference_b})

        case shared_identities(worker_a, worker_b, reference_a, reference_b, deadline) do
          {:ok, a, b} -> shared_identity_verdict(a, b)
          {:error, reason} -> failed_shared_fixture(scenario, reason)
        end

      {error, _other} ->
        failed_shared_fixture(scenario, error)
    end
  end

  defp shared_identities(worker_a, worker_b, reference_a, reference_b, deadline) do
    with {:ok, a} <- await_phase(reference_a, deadline),
         {:ok, b} <- await_phase(reference_b, deadline),
         :ok <- await_completion(worker_a, deadline),
         :ok <- await_completion(worker_b, deadline) do
      {:ok, a, b}
    end
  end

  defp shared_identity_verdict(a, b) when a == b do
    {:error,
     %{
       reason: :shared_connection_rejected,
       backend_pids: %{a: a, b: b},
       cleanup: %{confirmed: true, locks_remaining: 0, active_transactions: 0}
     }}
  end

  defp shared_identity_verdict(_a, _b),
    do:
      {:error,
       %{
         reason: :shared_fixture_invalid,
         cleanup: %{confirmed: true, locks_remaining: 0, active_transactions: 0}
       }}

  defp failed_shared_fixture(scenario, reason) do
    cleanup_scenario(scenario)
    {:error, %{reason: safe_reason(reason), cleanup: %{confirmed: false}}}
  end

  defp shared_identity(parent, reference) do
    receive do
      {:read_identity, ^reference} ->
        {:ok, %{rows: [[backend_pid]]}} = NewYou.Repo.query("SELECT pg_backend_pid()")
        send(parent, {reference, backend_pid})
    end
  end

  defp allow_shared_worker({worker, _monitor}) do
    case Ecto.Adapters.SQL.Sandbox.allow(NewYou.Repo, self(), worker) do
      :ok -> :ok
      {:already, _kind} -> {:error, :already_allowed}
      _ -> {:error, :allow_failed}
    end
  end

  defp sequential_fixture(scenario, timeout) do
    parent = self()
    run_id = lock_key(scenario.reference)
    lock_parts = lock_parts(run_id)
    observer_ready = make_ref()
    actor_ready = make_ref()
    result_ref = make_ref()
    deadline = now_ms() + timeout

    observer =
      Scenario.spawn(scenario, :observer, fn -> observer_worker(parent, observer_ready) end)

    actor =
      Scenario.spawn(scenario, :sequential_actor, fn ->
        sequential_actor(parent, run_id, actor_ready, result_ref, deadline)
      end)

    with {:ok, observer_identity} <- await_phase(observer_ready, deadline),
         {:ok, actor_identity} <- await_phase(actor_ready, deadline),
         true <- observer_identity.backend_pid != actor_identity.backend_pid do
      send(actor_identity.pid, {:run_sequential, run_id})

      with {:ok, observations} <- await_phase(result_ref, deadline),
           :ok <- await_completion(actor, deadline),
           false <-
             check_blocking_once(
               observer,
               actor_identity.backend_pid,
               actor_identity.backend_pid,
               deadline
             ),
           :ok <-
             verify_observer_cleanup(
               observer,
               observer_identity.backend_pid,
               lock_parts,
               [actor_identity.backend_pid],
               deadline
             ),
           :ok <- await_completion(observer, deadline) do
        {:error,
         %{
           reason: :sequential_execution_rejected,
           backend_pids: %{a: observations.backend_pid, b: observations.backend_pid},
           transaction_ids: observations.transaction_ids,
           contention_observed: false,
           cleanup: %{confirmed: true, locks_remaining: 0, active_transactions: 0}
         }}
      else
        error ->
          contention_failure(scenario, lock_parts, error, observer, [actor_identity.backend_pid])
      end
    else
      false ->
        contention_failure(scenario, lock_parts, :shared_identity, observer, [])

      error ->
        contention_failure(scenario, lock_parts, error, observer, [])
    end
  end

  defp sequential_actor(parent, run_id, ready_ref, result_ref, deadline) do
    case checkout_worker() do
      :ok ->
        send(parent, {ready_ref, %{backend_pid: backend_pid(), pid: self()}})

        result =
          receive do
            {:run_sequential, ^run_id} ->
              with {:ok, xid_a} <- transaction_with_lock(run_id, deadline),
                   {:ok, xid_b} <- transaction_with_lock(run_id, deadline) do
                {:ok, %{backend_pid: backend_pid(), transaction_ids: %{a: xid_a, b: xid_b}}}
              end
          after
            max(deadline - now_ms(), 0) -> {:error, :start_timeout}
          end

        checkin = Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)

        response =
          case {result, checkin} do
            {{:ok, observations}, :ok} -> observations
            _ -> {:error, :sequential_fixture_failed}
          end

        send(parent, {result_ref, response})

      {:error, reason} ->
        send(parent, {ready_ref, {:error, reason}})
    end
  end

  defp transaction_with_lock(run_id, deadline) do
    remaining = max(deadline - now_ms(), 1)

    NewYou.Repo.transaction(
      fn ->
        :ok = query_ok("SELECT pg_advisory_xact_lock($1::bigint)", [run_id], remaining)
        transaction_identity(remaining)
      end,
      timeout: remaining
    )
    |> case do
      {:ok, xid} -> {:ok, xid}
      {:error, _reason} -> {:error, :transaction_failed}
    end
  end

  defp execute_callback(parent, label, callback) do
    case Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false) do
      :ok ->
        result =
          try do
            {:ok, %{rows: [[backend_pid]]}} =
              NewYou.Repo.query("SELECT pg_backend_pid()")

            case sanitize_outcome(callback.(), 0) do
              {:ok, outcome} -> {:ok, backend_pid, outcome}
              :error -> {:error, :unsafe_callback_outcome}
            end
          rescue
            error -> {:error, safe_error(error)}
          catch
            kind, _reason -> {:error, {:callback, kind}}
          end

        case Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo) do
          :ok ->
            report_callback(parent, label, result)

          _ ->
            send(parent, {:concurrent_error, self(), label, :checkin_failed})
        end

      {:already, _kind} ->
        send(parent, {:concurrent_error, self(), label, :connection_already_owned})
    end
  end

  defp report_callback(parent, label, {:ok, backend_pid, outcome}),
    do: send(parent, {:concurrent_result, self(), label, backend_pid, outcome})

  defp report_callback(parent, label, {:error, reason}),
    do: send(parent, {:concurrent_error, self(), label, reason})

  defp sanitize_outcome(value, _depth)
       when is_atom(value) or is_integer(value) or is_boolean(value),
       do: {:ok, value}

  defp sanitize_outcome(_value, depth) when depth >= 4, do: :error

  defp sanitize_outcome(value, depth) when is_tuple(value) and tuple_size(value) <= 4 do
    sanitize_collection(Tuple.to_list(value), depth + 1)
  end

  defp sanitize_outcome(value, depth) when is_list(value) and length(value) <= 100,
    do: sanitize_collection(value, depth + 1)

  defp sanitize_outcome(value, depth) when is_map(value) and map_size(value) <= 100 do
    if Enum.all?(Map.keys(value), &is_atom/1) do
      sanitize_map(value, depth + 1)
    else
      :error
    end
  end

  defp sanitize_outcome(_value, _depth), do: :error

  defp sanitize_collection(values, depth) do
    Enum.reduce_while(values, {:ok, []}, fn item, {:ok, safe} ->
      case sanitize_outcome(item, depth) do
        {:ok, safe_item} -> {:cont, {:ok, [safe_item | safe]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, safe} -> {:ok, Enum.reverse(safe)}
      :error -> :error
    end
  end

  defp sanitize_map(value, depth) do
    Enum.reduce_while(value, {:ok, %{}}, fn {key, item}, {:ok, safe} ->
      case sanitize_outcome(item, depth) do
        {:ok, safe_item} -> {:cont, {:ok, Map.put(safe, key, safe_item)}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp await_callbacks(scenario, workers, timeout) do
    pending = Map.new(workers, fn {pid, ref} -> {pid, ref} end)
    deadline = now_ms() + timeout

    case collect_callbacks(scenario, pending, %{}, deadline) do
      {:ok, result} ->
        case await_worker_downs(workers, deadline) do
          :ok -> {:ok, result}
          {:error, reason} -> {:error, %{reason: reason, outcomes: result.outcomes}}
        end

      error ->
        error
    end
  end

  defp await_worker_downs(workers, deadline) do
    Enum.reduce_while(workers, :ok, fn {pid, ref}, :ok ->
      remaining = max(deadline - now_ms(), 0)

      receive do
        {:DOWN, ^ref, :process, ^pid, :normal} ->
          {:cont, :ok}

        {:DOWN, ^ref, :process, ^pid, reason} ->
          {:halt, {:error, {:worker_down, safe_reason(reason)}}}
      after
        remaining -> {:halt, {:error, :timeout}}
      end
    end)
  end

  defp collect_callbacks(_scenario, pending, outcomes, _deadline) when map_size(pending) == 0,
    do: {:ok, %{outcomes: outcomes}}

  defp collect_callbacks(scenario, pending, outcomes, deadline) do
    remaining = max(deadline - now_ms(), 0)

    receive do
      {:concurrent_result, pid, label, backend_pid, outcome} when is_map_key(pending, pid) ->
        collect_callbacks(
          scenario,
          Map.delete(pending, pid),
          Map.put(outcomes, label, %{backend_pid: backend_pid, outcome: outcome}),
          deadline
        )

      {:concurrent_error, pid, label, reason} when is_map_key(pending, pid) ->
        cleanup = cleanup_scenario(scenario)

        {:error,
         %{
           reason: reason,
           label: label,
           outcomes: outcomes,
           cleanup: cleanup_observation(cleanup)
         }}

      {:DOWN, ref, :process, pid, reason} when is_map_key(pending, pid) ->
        if Map.fetch!(pending, pid) == ref do
          cleanup = cleanup_scenario(scenario)

          {:error,
           %{
             reason: {:worker_down, safe_reason(reason)},
             outcomes: outcomes,
             cleanup: cleanup_observation(cleanup)
           }}
        else
          collect_callbacks(scenario, pending, outcomes, deadline)
        end
    after
      remaining ->
        cleanup = cleanup_scenario(scenario)
        {:error, %{reason: :timeout, outcomes: outcomes, cleanup: cleanup_observation(cleanup)}}
    end
  end

  defp run_contention(scenario, timeout), do: run_contention(scenario, timeout, :contention)

  defp run_contention(scenario, timeout, fixture) do
    parent = self()
    run_id = lock_key(scenario.reference)
    lock_parts = lock_parts(run_id)
    a_started = make_ref()
    b_started = make_ref()
    a_ready = make_ref()
    b_ready = make_ref()
    observer_ready = make_ref()
    deadline = now_ms() + timeout

    observer =
      Scenario.spawn(scenario, :observer, fn -> observer_worker(parent, observer_ready) end)

    worker_a =
      Scenario.spawn(scenario, :a, fn ->
        contention_owner(parent, run_id, a_started, a_ready, deadline, fixture)
      end)

    worker_b =
      Scenario.spawn(scenario, :b, fn ->
        contention_waiter(parent, run_id, b_started, b_ready, deadline, fixture)
      end)

    with {:ok, observer_identity} <- await_phase(observer_ready, deadline),
         {:ok, a_connection} <- await_phase(a_ready, deadline),
         {:ok, b_connection} <- await_phase(b_ready, deadline),
         true <- distinct_connections?([observer_identity, a_connection, b_connection]) do
      send(a_connection.pid, {:begin_transaction, run_id})

      case await_phase(a_started, deadline) do
        {:ok, a} ->
          send(b_connection.pid, {:begin_transaction, run_id})

          context = %{
            scenario: scenario,
            run_id: run_id,
            lock_parts: lock_parts,
            observer: observer,
            observer_backend_pid: observer_identity.backend_pid,
            actor_backend_pids: [a_connection.backend_pid, b_connection.backend_pid],
            worker_a: worker_a,
            worker_b: worker_b,
            fixture: fixture,
            deadline: deadline
          }

          contention_after_start(context, b_started, a)

        {:error, reason} ->
          contention_failure(
            scenario,
            lock_parts,
            pool_failure_reason(reason),
            observer,
            [a_connection.backend_pid, b_connection.backend_pid]
          )
      end
    else
      false ->
        contention_failure(scenario, lock_parts, :shared_identity, observer, [])

      error ->
        contention_failure(scenario, lock_parts, pool_failure_reason(error), observer, [])
    end
  end

  defp contention_after_start(context, b_started, a) do
    %{scenario: scenario, lock_parts: lock_parts, deadline: deadline} = context
    %{observer: observer} = context
    %{actor_backend_pids: actor_backend_pids} = context

    with {:ok, b} <- await_phase(b_started, deadline),
         true <- a.backend_pid != b.backend_pid,
         true <- a.transaction_id != b.transaction_id do
      case observe_blocking(observer, b.backend_pid, a.backend_pid, deadline) do
        :ok ->
          complete_contention(context, a, b)

        error ->
          contention_observation_failed(context, a, b, error)
      end
    else
      false ->
        contention_failure(scenario, lock_parts, :shared_identity, observer, actor_backend_pids)

      error ->
        contention_failure(scenario, lock_parts, error, observer, actor_backend_pids)
    end
  end

  defp contention_observation_failed(context, a, b, error) do
    if context.fixture == :nonblocking do
      reject_nonblocking_contention(context, a, b, error)
    else
      contention_failure(
        context.scenario,
        context.lock_parts,
        error,
        context.observer,
        context.actor_backend_pids
      )
      |> add_observed_transaction_identity(context, a, b)
    end
  end

  defp complete_contention(context, a, b) do
    %{scenario: scenario, run_id: run_id, lock_parts: lock_parts} = context
    %{observer: observer, observer_backend_pid: observer_backend_pid} = context
    %{actor_backend_pids: actor_backend_pids, deadline: deadline} = context
    %{worker_a: worker_a, worker_b: worker_b} = context

    send(a.pid, {:release_lock, run_id})
    if context.fixture == :nonblocking, do: send(b.pid, {:release_nonblocking, run_id})

    with :ok <- await_transaction(elem(worker_a, 0), :a, {:ok, :released}, deadline),
         :ok <- await_transaction(elem(worker_b, 0), :b, {:ok, :ok}, deadline),
         :ok <- await_completion(worker_a, deadline),
         :ok <- await_completion(worker_b, deadline),
         :ok <-
           verify_observer_cleanup(
             observer,
             observer_backend_pid,
             lock_parts,
             [a.backend_pid, b.backend_pid],
             deadline
           ),
         :ok <- await_completion(observer, deadline) do
      {:ok,
       %{
         contention_observed: true,
         backend_pids: %{a: a.backend_pid, b: b.backend_pid},
         transaction_ids: %{a: a.transaction_id, b: b.transaction_id},
         acquisition_order: [:a, :b],
         cleanup: %{confirmed: true, locks_remaining: 0, active_transactions: 0}
       }}
    else
      error ->
        contention_failure(scenario, lock_parts, error, observer, actor_backend_pids)
    end
  end

  defp reject_nonblocking_contention(context, a, b, observation_error) do
    %{scenario: scenario, run_id: run_id, lock_parts: lock_parts} = context
    %{observer: observer, actor_backend_pids: actor_backend_pids} = context
    %{worker_a: worker_a, worker_b: worker_b} = context
    cleanup_deadline = now_ms() + @cleanup_timeout

    send(a.pid, {:release_lock, run_id})
    send(b.pid, {:release_nonblocking, run_id})

    actor_cleanup =
      with :ok <- await_transaction(elem(worker_a, 0), :a, {:ok, :released}, cleanup_deadline),
           :ok <- await_transaction(elem(worker_b, 0), :b, {:ok, :ok}, cleanup_deadline),
           :ok <- await_completion(worker_a, cleanup_deadline),
           do: await_completion(worker_b, cleanup_deadline)

    reason = if actor_cleanup == :ok, do: observation_error, else: actor_cleanup

    contention_failure(scenario, lock_parts, reason, observer, actor_backend_pids)
    |> add_observed_transaction_identity(context, a, b)
  end

  defp add_observed_transaction_identity({:error, failure}, context, a, b) do
    {:error,
     Map.merge(failure, %{
       backend_pids: %{
         a: a.backend_pid,
         b: b.backend_pid,
         observer: context.observer_backend_pid
       },
       transaction_ids: %{a: a.transaction_id, b: b.transaction_id},
       overlap_observed: true,
       contention_observed: false
     })}
  end

  defp observer_worker(parent, ready_ref) do
    case checkout_worker() do
      :ok ->
        send(parent, {ready_ref, %{backend_pid: backend_pid(), pid: self()}})
        observer_loop(parent)

      {:error, reason} ->
        send(parent, {ready_ref, {:error, reason}})
    end
  end

  defp observer_loop(parent) do
    receive do
      {:observe_blocking, request_ref, blocked_pid, blocker_pid, deadline} ->
        result = poll_blocking(blocked_pid, blocker_pid, deadline)
        send(parent, {request_ref, result})
        observer_loop(parent)

      {:check_blocking, request_ref, blocked_pid, blocker_pid, deadline} ->
        send(parent, {request_ref, blocking_now(blocked_pid, blocker_pid, deadline)})
        observer_loop(parent)

      {:verify_cleanup, request_ref, lock_parts, backend_pids, deadline} ->
        result = assert_no_locks(lock_parts, backend_pids, deadline)
        checkin = Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)

        response =
          if result == :ok and checkin == :ok, do: :ok, else: {:error, :cleanup_unconfirmed}

        send(parent, {request_ref, response})

      {:stop_observer, request_ref} ->
        checkin = Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
        send(parent, {request_ref, if(checkin == :ok, do: :ok, else: {:error, :checkin_failed})})
    after
      30_000 -> Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
    end
  end

  defp distinct_connections?(identities) do
    identities
    |> Enum.map(& &1.backend_pid)
    |> Enum.uniq()
    |> length() == length(identities)
  end

  defp contention_owner(parent, run_id, phase_ref, ready_ref, deadline, fixture) do
    case checkout_worker() do
      :ok ->
        send(parent, {ready_ref, %{backend_pid: backend_pid(), pid: self()}})

        transaction_result =
          receive do
            {:begin_transaction, ^run_id} ->
              transaction_timeout =
                if fixture == :nonblocking, do: 30_000, else: max(deadline - now_ms(), 1)

              NewYou.Repo.transaction(
                fn ->
                  remaining = max(deadline - now_ms(), 1)

                  if fixture == :contention do
                    :ok =
                      query_ok("SELECT pg_advisory_xact_lock($1::bigint)", [run_id], remaining)
                  end

                  identity = transaction_identity(remaining)

                  send(
                    parent,
                    {phase_ref,
                     %{backend_pid: backend_pid(), transaction_id: identity, pid: self()}}
                  )

                  receive do
                    {:release_lock, ^run_id} -> :released
                  after
                    30_000 -> NewYou.Repo.rollback(:owner_timeout)
                  end
                end,
                timeout: transaction_timeout
              )
          after
            max(deadline - now_ms(), 0) -> {:error, :start_timeout}
          end

        checkin_and_report(parent, :a, transaction_result)

      {:error, reason} ->
        send(parent, {ready_ref, {:error, reason}})
    end
  end

  defp contention_waiter(parent, run_id, phase_ref, ready_ref, deadline, fixture) do
    case checkout_worker() do
      :ok ->
        send(parent, {ready_ref, %{backend_pid: backend_pid(), pid: self()}})

        transaction_result =
          receive do
            {:begin_transaction, ^run_id} ->
              transaction_timeout =
                if fixture == :nonblocking, do: 30_000, else: max(deadline - now_ms(), 1)

              NewYou.Repo.transaction(
                fn ->
                  remaining = max(deadline - now_ms(), 1)

                  if fixture == :contention do
                    :ok =
                      query_ok(
                        "SELECT set_config('lock_timeout', $1, true)",
                        ["#{remaining}ms"],
                        remaining
                      )
                  end

                  identity = transaction_identity(remaining)

                  send(
                    parent,
                    {phase_ref,
                     %{backend_pid: backend_pid(), transaction_id: identity, pid: self()}}
                  )

                  if fixture == :contention do
                    :ok =
                      query_ok("SELECT pg_advisory_xact_lock($1::bigint)", [run_id], remaining)
                  else
                    receive do
                      {:release_nonblocking, ^run_id} -> :ok
                    after
                      30_000 -> NewYou.Repo.rollback(:nonblocking_timeout)
                    end
                  end
                end,
                timeout: transaction_timeout
              )
          after
            max(deadline - now_ms(), 0) -> {:error, :start_timeout}
          end

        checkin_and_report(parent, :b, transaction_result)

      {:error, reason} ->
        send(parent, {ready_ref, {:error, reason}})
    end
  end

  defp checkin_and_report(parent, label, transaction_result) do
    result =
      case Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo) do
        :ok -> transaction_result
        _ -> {:error, :checkin_failed}
      end

    send(parent, {:concurrent_tx_done, self(), label, result})
  end

  defp checkout_worker do
    case Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false) do
      :ok -> :ok
      {:already, :owner} -> {:error, :connection_already_owned}
      {:already, :allowed} -> {:error, :connection_already_allowed}
    end
  end

  defp await_phase(reference, deadline) do
    receive do
      {^reference, {:error, reason}} -> {:error, reason}
      {^reference, identity} -> {:ok, identity}
    after
      max(deadline - now_ms(), 0) -> {:error, :phase_timeout}
    end
  end

  defp observe_blocking({observer_pid, _observer_ref}, blocked_pid, blocker_pid, deadline) do
    request_ref = make_ref()
    send(observer_pid, {:observe_blocking, request_ref, blocked_pid, blocker_pid, deadline})

    case await_phase(request_ref, deadline + @observer_response_grace) do
      {:ok, :ok} -> :ok
      {:ok, error} -> error
      error -> error
    end
  end

  defp poll_blocking(blocked_pid, blocker_pid, deadline) do
    if now_ms() >= deadline - @observer_query_margin do
      {:error, :contention_not_observed}
    else
      case blocking_now(blocked_pid, blocker_pid, deadline) do
        true ->
          :ok

        false ->
          Process.sleep(10)
          poll_blocking(blocked_pid, blocker_pid, deadline)

        {:error, :observer_query_failed} = error ->
          error
      end
    end
  end

  defp blocking_now(blocked_pid, blocker_pid, deadline) do
    sql = """
    SELECT EXISTS (
      SELECT 1
      FROM pg_stat_activity AS blocked
      JOIN pg_stat_activity AS blocker ON blocker.pid = $2
      WHERE blocked.pid = $1
        AND $2 = ANY(pg_blocking_pids(blocked.pid))
    )
    """

    case NewYou.Repo.query(sql, [blocked_pid, blocker_pid],
           timeout: max(deadline - now_ms(), 1),
           log: false
         ) do
      {:ok, %{rows: [[result]]}} when is_boolean(result) -> result
      {:error, _} -> {:error, :observer_query_failed}
    end
  end

  defp check_blocking_once({observer_pid, _observer_ref}, blocked_pid, blocker_pid, deadline) do
    request_ref = make_ref()
    send(observer_pid, {:check_blocking, request_ref, blocked_pid, blocker_pid, deadline})

    case await_phase(request_ref, deadline) do
      {:ok, result} -> result
      {:error, _reason} = error -> error
    end
  end

  defp await_completion({pid, ref}, deadline) do
    receive do
      {:DOWN, ^ref, :process, ^pid, :normal} -> :ok
      {:DOWN, ^ref, :process, ^pid, reason} -> {:error, {:worker_down, safe_reason(reason)}}
    after
      max(deadline - now_ms(), 0) -> {:error, :worker_timeout}
    end
  end

  defp await_transaction(worker_pid, label, expected, deadline) do
    receive do
      {:concurrent_tx_done, ^worker_pid, ^label, ^expected} -> :ok
      {:concurrent_tx_done, ^worker_pid, ^label, _other} -> {:error, {:transaction_failed, label}}
    after
      max(deadline - now_ms(), 0) -> {:error, {:transaction_timeout, label}}
    end
  end

  defp verify_observer_cleanup(
         {observer_pid, _observer_ref},
         _observer_backend_pid,
         lock_parts,
         backend_pids,
         deadline
       ) do
    request_ref = make_ref()
    send(observer_pid, {:verify_cleanup, request_ref, lock_parts, backend_pids, deadline})

    case await_phase(request_ref, deadline) do
      {:ok, :ok} -> :ok
      {:ok, error} -> error
      error -> error
    end
  end

  defp assert_no_locks({classid, objid}, backend_pids, deadline) do
    sql = """
    SELECT
      (SELECT count(*) FROM pg_locks
       WHERE locktype = 'advisory' AND classid::bigint = $1
         AND objid::bigint = $2 AND objsubid = 1),
      (SELECT count(*) FROM pg_stat_activity
       WHERE pid = ANY($3::int[]) AND xact_start IS NOT NULL)
    """

    case NewYou.Repo.query(sql, [classid, objid, backend_pids],
           timeout: max(deadline - now_ms(), 1),
           log: false
         ) do
      {:ok, %{rows: [[0, 0]]}} -> :ok
      {:ok, _} -> {:error, :database_cleanup_unconfirmed}
      {:error, _} -> {:error, :observer_failed}
    end
  end

  defp lock_key(reference) do
    <<unsigned::unsigned-64, _rest::binary>> =
      :crypto.hash(:sha256, :erlang.term_to_binary({reference, make_ref()}))

    if unsigned > 9_223_372_036_854_775_807,
      do: unsigned - 18_446_744_073_709_551_616,
      else: unsigned
  end

  defp lock_parts(key) do
    unsigned = if key < 0, do: key + 18_446_744_073_709_551_616, else: key
    {unsigned >>> 32 &&& 4_294_967_295, unsigned &&& 4_294_967_295}
  end

  defp contention_failure(scenario, lock_parts, reason, observer, backend_pids) do
    {observer_pid, _observer_ref} = observer
    workers_stopped = cleanup_scenario(scenario, [observer_pid])
    cleanup_deadline = now_ms() + @cleanup_timeout

    observer_cleanup =
      if workers_stopped == :ok do
        verify_observer_cleanup(observer, nil, lock_parts, backend_pids, cleanup_deadline)
      else
        {:error, :workers_unconfirmed}
      end

    if observer_cleanup != :ok, do: stop_worker(observer_pid)
    observer_stopped = await_completion(observer, cleanup_deadline)

    {:error,
     %{
       reason: safe_reason(reason),
       cleanup: %{
         confirmed: workers_stopped == :ok and observer_cleanup == :ok and observer_stopped == :ok
       }
     }}
  end

  defp cleanup_scenario(scenario, excluded_pids \\ []) do
    case Scenario.owned_processes(scenario) do
      processes when is_list(processes) ->
        workers = Enum.reject(processes, fn {pid, _guardian} -> pid in excluded_pids end)

        Enum.each(workers, fn {pid, _guardian} ->
          stop_worker(pid)
        end)

        await_owned_down(scenario, workers, now_ms() + @cleanup_timeout)

      _ ->
        {:error, :ownership_unavailable}
    end
  end

  defp cleanup_observation(:ok), do: %{confirmed: true}
  defp cleanup_observation(_error), do: %{confirmed: false}

  defp pool_failure_reason(:phase_timeout), do: :pool_unavailable
  defp pool_failure_reason({:error, :phase_timeout}), do: :pool_unavailable
  defp pool_failure_reason(reason), do: reason

  defp stop_worker(pid) do
    if Process.alive?(pid), do: Process.exit(pid, :kill)
  end

  defp await_owned_down(scenario, processes, deadline) do
    refs =
      processes
      |> Enum.flat_map(fn {pid, guardian} -> [pid, guardian] end)
      |> Enum.uniq()
      |> Map.new(fn pid -> {Process.monitor(pid), pid} end)

    with :ok <- await_monitors(refs, deadline) do
      remaining = max(deadline - now_ms(), 1)
      workers = Enum.map(processes, &elem(&1, 0))
      Scenario.request(scenario, {:await_owned_down, workers, remaining}, remaining)
    end
  end

  defp await_monitors(refs, _deadline) when map_size(refs) == 0, do: :ok

  defp await_monitors(refs, deadline) do
    receive do
      {:DOWN, ref, :process, _pid, _reason} -> await_monitors(Map.delete(refs, ref), deadline)
    after
      max(deadline - now_ms(), 0) -> {:error, :cleanup_timeout}
    end
  end

  defp backend_pid do
    {:ok, %{rows: [[pid]]}} = NewYou.Repo.query("SELECT pg_backend_pid()")
    pid
  end

  defp transaction_identity(timeout) do
    {:ok, %{rows: [[xid]]}} =
      NewYou.Repo.query("SELECT pg_current_xact_id()::text", [], timeout: timeout, log: false)

    String.to_integer(xid)
  end

  defp query_ok(sql, params, timeout) do
    case NewYou.Repo.query(sql, params, timeout: timeout, log: false) do
      {:ok, _} -> :ok
      {:error, error} -> raise "proof database query failed: #{inspect(error.__struct__)}"
    end
  end

  defp safe_error(error), do: {:callback_exception, error.__struct__}
  defp safe_reason(reason) when is_atom(reason), do: reason
  defp safe_reason({:error, reason}) when is_atom(reason), do: reason
  defp safe_reason({reason, _}) when is_atom(reason), do: reason
  defp safe_reason(_), do: :worker_failed
  defp valid_timeout?(timeout), do: is_integer(timeout) and timeout > 0 and timeout <= 30_000
  defp now_ms, do: System.monotonic_time(:millisecond)
end
