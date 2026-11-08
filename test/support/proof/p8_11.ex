defmodule NewYou.Proof.P811 do
  @moduledoc """
  WELL-11 probes use the P8-04 runner, Scenario workers and named CutPoints.
  P805 fixtures commit real owner actions. SQL observes state and tears down
  synthetic fixtures; no SQL implements an Audit business mutation.
  """
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Audit, Identity, Repo}
  alias NewYou.Proof.{AuditSeam, CutPoints, P805, Scenario}
  require Ash.Query

  def run(id) do
    P805.with_fixture(fn ->
      request = P805.request()
      {:ok, %{account_id: account}} = Identity.register(request)

      [obligation] =
        Audit.EvidenceObligation
        |> Ash.Query.filter(source_operation_id == ^request.operation_id)
        |> Ash.read!(domain: Audit, authorize?: false)

      source = source_snapshot(account)
      execute(id, obligation, account, source)
      :ok
    end)
  end

  defp execute("p811.existing_assertion" = id, obligation, account, source) do
    # A committed record beside an open obligation is a recovery input, not a
    # claim that the current atomic executor can commit half its transaction.
    record =
      Ash.create!(Audit.EvidenceRecord, %{obligation_id: obligation.id},
        action: :materialize,
        domain: Audit,
        authorize?: false
      )

    P805.check(id, "open_with_record", refresh(obligation).state == :open)
    {:ok, result} = materialize(obligation)

    P805.check(
      id,
      "same_assertion",
      result.evidence_record_id == record.id and record_count(obligation) == 1
    )

    P805.check(id, "fulfilled", refresh(obligation).state == :fulfilled)

    P805.check(
      id,
      "terminal_replay",
      materialize(obligation) == {:ok, result} and record_count(obligation) == 1
    )

    P805.check(id, "source_unchanged", source_snapshot(account) == source)
    refreshed = refresh(obligation)

    P805.check(
      id,
      "truthful_timing",
      refreshed.source_occurred_at == obligation.source_occurred_at and
        DateTime.compare(record.created_at, obligation.source_occurred_at) != :lt and
        DateTime.compare(refreshed.fulfilled_at, record.created_at) != :lt
    )

    P805.check(id, "minimum_envelope", minimum_envelope?(obligation))
  end

  defp execute("p811.interrupted_materialisation" = id, obligation, account, source) do
    scenario = Scenario.start()
    parent = self()
    reference = make_ref()

    try do
      :ok =
        CutPoints.arm(scenario, "evidence.after_materialize_before_commit", :executor, :terminate)

      {worker, monitor} =
        Scenario.spawn(scenario, :executor, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          Process.put(AuditSeam, fn point ->
            if point == :after_record do
              send(parent, {reference, :record_inserted, P805.scalar("SELECT pg_backend_pid()")})
              CutPoints.hit(scenario, "evidence.after_materialize_before_commit", :executor)
            end
          end)

          try do
            materialize(obligation)
          after
            Sandbox.checkin(Repo)
          end
        end)

      old_backend =
        receive do
          {^reference, :record_inserted, backend} -> backend
        after
          15_000 -> raise "Audit record cut deadline"
        end

      receive do
        {:DOWN, ^monitor, :process, ^worker, :proof_terminated} -> :ok
      after
        15_000 -> raise "Audit worker termination deadline"
      end

      P805.check(id, "cut_consumed", CutPoints.verify_consumed(scenario) == :ok)
      # The next lock waits for PostgreSQL to finish aborting the killed worker.
      {backend, result} =
        fresh(fn ->
          open = refresh(obligation).state == :open
          absent = record_count(obligation) == 0
          {open, absent, materialize(obligation)}
        end)

      {open, absent, outcome} = result
      P805.check(id, "record_rolled_back", absent)
      P805.check(id, "obligation_open", open)
      P805.check(id, "source_unchanged", source_snapshot(account) == source)

      P805.check(
        id,
        "fresh_retry",
        backend != old_backend and match?({:ok, _}, outcome) and record_count(obligation) == 1
      )
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp execute("p811.concurrent_execution" = id, obligation, account, source) do
    scenario = Scenario.start()
    parent = self()
    reference = make_ref()

    try do
      {first, monitor_a} =
        Scenario.spawn(scenario, :first, fn ->
          worker_connection(fn ->
            Process.put(AuditSeam, fn
              :after_record ->
                %{rows: [[backend, tx]]} =
                  Repo.query!("SELECT pg_backend_pid(), txid_current()::text")

                send(parent, {reference, :locked, backend, tx})

                receive do
                  {^reference, :release} -> :ok
                after
                  15_000 -> raise "Audit lock release deadline"
                end

              _ ->
                :ok
            end)

            send(parent, {reference, :first_result, materialize(obligation)})
          end)
        end)

      {backend_a, tx_a} =
        receive do
          {^reference, :locked, backend, tx} -> {backend, tx}
        after
          15_000 -> raise "Audit lock acquisition deadline"
        end

      {_second, monitor_b} =
        Scenario.spawn(scenario, :second, fn ->
          worker_connection(fn ->
            Process.put(AuditSeam, fn
              :before_lock ->
                P805.scalar("SELECT txid_current()::text")
                send(parent, {reference, :second_backend, P805.scalar("SELECT pg_backend_pid()")})

              _ ->
                :ok
            end)

            [job] = jobs(obligation)
            :ok = NewYou.Audit.Workers.RegistrationEvidence.perform(job)
            send(parent, {reference, :second_result, :ok})
          end)
        end)

      backend_b =
        receive do
          {^reference, :second_backend, backend} -> backend
        after
          15_000 -> raise "Audit second connection deadline"
        end

      tx_b = await_contention(backend_a, backend_b, System.monotonic_time(:millisecond) + 10_000)
      P805.check(id, "independent_connections", backend_a != backend_b)
      P805.check(id, "independent_transactions", tx_a != tx_b and is_binary(tx_b))
      P805.check(id, "contention", is_binary(tx_b))
      send(first, {reference, :release})

      result_a =
        receive do
          {^reference, :first_result, result} -> result
        after
          15_000 -> raise "Audit first result deadline"
        end

      receive do
        {^reference, :second_result, :ok} -> :ok
      after
        15_000 -> raise "Audit duplicate result deadline"
      end

      for monitor <- [monitor_a, monitor_b] do
        receive do
          {:DOWN, ^monitor, :process, _, :normal} -> :ok
        after
          5_000 -> raise "Audit race cleanup deadline"
        end
      end

      P805.check(id, "both_succeed", match?({:ok, _}, result_a))

      P805.check(
        id,
        "single_assertion",
        record_count(obligation) == 1 and refresh(obligation).state == :fulfilled
      )

      P805.check(id, "source_unchanged", source_snapshot(account) == source)
    after
      :ok = Scenario.stop(scenario)
    end
  end

  defp execute("p811.restart_backlog" = id, obligation, account, source) do
    # Jobs are execution machinery. Remove the original and reconstruct it in
    # independently booted BEAMs, without passing any source/Identity secrets.
    Repo.query!("DELETE FROM oban_jobs WHERE args->'primary_key'->>'id' = $1", [obligation.id])
    P805.check(id, "first_boot", restart_process(:schedule, obligation.id))
    P805.check(id, "jobs_recreated", length(jobs(obligation)) == 1)

    P805.check(
      id,
      "duplicate_schedule_safe",
      restart_process(:schedule, obligation.id) and record_count(obligation) == 0
    )

    [job] = jobs(obligation)
    Repo.query!("UPDATE oban_jobs SET state = 'discarded' WHERE id = $1", [job.id])
    P805.check(id, "second_boot", restart_process(:execute, obligation.id))

    P805.check(
      id,
      "recovered",
      refresh(obligation).state == :fulfilled and record_count(obligation) == 1
    )

    P805.check(id, "source_unchanged", source_snapshot(account) == source)

    P805.check(
      id,
      "original_correlation",
      refresh(obligation).source_operation_id == obligation.source_operation_id and
        refresh(obligation).source_occurred_at == obligation.source_occurred_at
    )
  end

  defp materialize(obligation),
    do:
      Audit.materialize_registration_evidence(
        %{primary_key: %{id: obligation.id}},
        authorize?: false
      )

  defp refresh(obligation), do: Audit.get_evidence_obligation!(obligation.id, authorize?: false)

  defp record_count(obligation),
    do:
      P805.scalar("SELECT count(*) FROM evidence_records WHERE obligation_id = $1", [
        Ecto.UUID.dump!(obligation.id)
      ])

  defp jobs(obligation),
    do: Repo.all(Oban.Job) |> Enum.filter(&(&1.args["primary_key"] == %{"id" => obligation.id}))

  defp minimum_envelope?(obligation) do
    fields =
      Ash.Resource.Info.attributes(Audit.EvidenceRecord) |> Enum.map(& &1.name) |> Enum.sort()

    fields ==
      Enum.sort([
        :id,
        :obligation_id,
        :created_at,
        :assertion_kind,
        :attempt_id,
        :action_class,
        :actor_id,
        :target_id,
        :grant_id,
        :grant_version,
        :session_id,
        :expected_version,
        :reason_code,
        :admitted_at,
        :outcome
      ]) and
      Enum.all?(
        jobs(obligation),
        &(&1.args == %{
            "primary_key" => %{"id" => obligation.id},
            "metadata" => %{},
            "action_arguments" => %{},
            "tenant" => nil
          })
      )
  end

  defp source_snapshot(account) do
    # Compare in memory only. Never include sensitive source values in reports.
    {Repo.query!("SELECT * FROM accounts WHERE id = $1", [Ecto.UUID.dump!(account)]).rows,
     Repo.query!("SELECT * FROM registration_operations WHERE created_account_id = $1", [
       Ecto.UUID.dump!(account)
     ]).rows,
     Repo.query!("SELECT * FROM tokens WHERE account_id = $1", [Ecto.UUID.dump!(account)]).rows}
  end

  defp fresh(callback) do
    Task.async(fn ->
      worker_connection(fn -> {P805.scalar("SELECT pg_backend_pid()"), callback.()} end)
    end)
    |> Task.await(20_000)
  end

  defp worker_connection(callback) do
    :ok = Sandbox.checkout(Repo, sandbox: false)

    try do
      callback.()
    after
      Process.delete(AuditSeam)
      Sandbox.checkin(Repo)
    end
  end

  defp await_contention(blocker, blocked, deadline) do
    %{rows: [[waiting, tx]]} =
      Repo.query!(
        """
        SELECT $1 = ANY(pg_blocking_pids(pid)), backend_xid::text
        FROM pg_stat_activity WHERE pid = $2
        """,
        [blocker, blocked],
        log: false
      )

    cond do
      waiting and is_binary(tx) ->
        tx

      System.monotonic_time(:millisecond) >= deadline ->
        raise "Audit contention not observed"

      true ->
        Process.sleep(10)
        await_contention(blocker, blocked, deadline)
    end
  end

  defp restart_process(mode, obligation_id) do
    executable = System.find_executable("mix") || raise "mix unavailable"

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        args: ["run", "test/proof/p8_11_restart.exs", Atom.to_string(mode), obligation_id],
        env: [{~c"MIX_ENV", ~c"test"}, {~c"ERL_FLAGS", ~c"+S 2:2"}]
      ])

    restart_output(port, "", System.monotonic_time(:millisecond) + 30_000)
  end

  defp restart_output(port, output, deadline) do
    receive do
      {^port, {:data, bytes}} when byte_size(output) + byte_size(bytes) < 16_384 ->
        restart_output(port, output <> bytes, deadline)

      {^port, {:exit_status, 0}} ->
        String.contains?(output, "P811_RESTART_OK")

      {^port, {:exit_status, _}} ->
        false
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        Port.close(port)
        false
    end
  end
end
