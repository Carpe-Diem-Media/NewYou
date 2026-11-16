defmodule NewYou.Proof.DeliveryRecoveryScenarios do
  @moduledoc false
  import ExUnit.Assertions
  import Ecto.Query, only: [from: 2]
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Communications, Identity, Repo}
  alias NewYou.Proof.{CutPoints, DeliverySeam, P805, Provider, Scenario}

  def scenario_competing_real_postgresql_executors_admit_only_one_provider_operation() do
    P805.with_fixture(fn ->
      scenario_competing_real_postgresql_executors_admit_only_one_provider_operation_fixture()
    end)
  after
    Process.delete(:p810_provider)
  end

  defp scenario_competing_real_postgresql_executors_admit_only_one_provider_operation_fixture() do
    {:ok, _} = Identity.register(P805.request())
    [intent] = P805.read(Communications.MessageIntent, Communications)
    parent = self()

    tasks =
      for _ <- 1..8 do
        Task.async(fn -> execute_competing_delivery(intent, parent) end)
      end

    results = Task.await_many(tasks, 15000)
    assert Enum.all?(results, &match?({:ok, _}, &1))
    submissions = drain_submissions([])
    assert length(submissions) <= 1
    attempts = P805.read(Communications.DeliveryAttempt, Communications)
    assert Enum.count(attempts, & &1.active) <= 1
    assert Enum.count(attempts, &(not is_nil(&1.invocation_started_at))) == length(submissions)

    if submissions == [] do
      Process.put(:p810_provider, fn _, _ -> :accepted end)
      assert {:ok, :processed} = Communications.execute(intent.id)
    end
  end

  def scenario_real_ashoban_scheduler_discovers_zero_job_intent_and_recreates_deleted_and_exhausted_jobs() do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = P805.read(Communications.MessageIntent, Communications)
      trigger = AshOban.Info.oban_trigger(Communications.MessageIntent, :delivery)
      assert jobs(intent) == []
      assert :ok = trigger.scheduler.perform(%Oban.Job{args: %{}})
      [job] = jobs(intent)
      assert job.args["primary_key"] == %{"id" => intent.id}

      assert Map.keys(job.args) --
               ["primary_key", "metadata", "action_arguments", "tenant", "actor"] == []

      assert job.args["action_arguments"] in [nil, %{}]
      assert job.args["metadata"] in [nil, %{}]
      assert job.args["actor"] == nil
      Repo.delete!(job)
      assert :ok = trigger.scheduler.perform(%Oban.Job{args: %{}})
      [replacement] = jobs(intent)
      Repo.query!("UPDATE oban_jobs SET state = 'discarded' WHERE id = $1", [replacement.id])
      assert :ok = trigger.scheduler.perform(%Oban.Job{args: %{}})
      assert Enum.count(jobs(intent), &(&1.state == "available")) == 1
      Process.put(:p810_provider, fn _, _ -> :delivered end)

      for job <- jobs(intent) do
        assert :ok == trigger.worker.perform(job)
      end

      assert length(P805.read(Communications.DeliveryAttempt, Communications)) == 1
    end)
  after
    Process.delete(:p810_provider)
  end

  def scenario_admission_contenders_wait_on_a_real_postgresql_row_lock() do
    P805.with_fixture(fn ->
      scenario_admission_contenders_wait_on_a_real_postgresql_row_lock_fixture()
    end)
  end

  defp scenario_admission_contenders_wait_on_a_real_postgresql_row_lock_fixture() do
    {:ok, _} = Identity.register(P805.request())
    [intent] = P805.read(Communications.MessageIntent, Communications)
    parent = self()
    first = Task.async(fn -> execute_lock_holder(intent, parent) end)
    assert_receive {:locked, holder, backend_a, transaction_a}, 2000
    second = Task.async(fn -> execute_lock_contender(intent, parent) end)
    assert_receive {:contender, backend_b}, 2000
    assert backend_a != backend_b

    transaction_b =
      wait_for_lock(backend_a, backend_b, System.monotonic_time(:millisecond) + 2000)

    assert is_binary(transaction_b)
    assert transaction_a != transaction_b
    send(holder, :release)
    assert Enum.all?(Task.await_many([first, second], 10000), &match?({:ok, _}, &1))
  end

  def scenario_fresh_beam_discovers_missing_jobs_and_preserves_accepted_ambiguity_across_another_boot() do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = P805.read(Communications.MessageIntent, Communications)
      assert jobs(intent) == []
      assert restart(intent.id)
      [attempt] = P805.read(Communications.DeliveryAttempt, Communications)
      assert attempt.provider_observation == :accepted

      for job <- jobs(intent) do
        Repo.delete!(job)
      end

      assert restart(intent.id)
      assert [same] = P805.read(Communications.DeliveryAttempt, Communications)
      assert same.id == attempt.id
      assert same.provider_observation == :accepted

      assert Ash.get!(Communications.MessageIntent, intent.id, authorize?: false).dispatch_disposition ==
               :reconciliation_required
    end)
  end

  def wait_for_lock(holder, contender, deadline) do
    %{rows: rows} =
      Repo.query!(
        "SELECT backend_xid::text FROM pg_stat_activity WHERE pid = $1 AND $2 = ANY(pg_blocking_pids(pid))",
        [contender, holder]
      )

    case rows do
      [[tx]] when is_binary(tx) ->
        tx

      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          receive do
          after
            10 -> :ok
          end

          wait_for_lock(holder, contender, deadline)
        else
          nil
        end
    end
  end

  def restart(id) do
    keyring = Application.fetch_env!(:new_you, :communications_keyring)

    input =
      Jason.encode!(%{
        intent_id: id,
        key_version: keyring.active,
        envelope_key: Base.encode64(keyring.keys[keyring.active])
      })

    port =
      Port.open({:spawn_executable, System.find_executable("mix")}, [
        :binary,
        :exit_status,
        args: ["run", "test/proof/p8_10_restart.exs"],
        env: [{~c"MIX_ENV", ~c"test"}, {~c"ERL_FLAGS", ~c"+S 2:2"}]
      ])

    true = Port.command(port, input <> "\n")
    restart_output(port, "", System.monotonic_time(:millisecond) + 30000)
  end

  def restart_output(port, output, deadline) do
    receive do
      {^port, {:data, bytes}} when byte_size(output) + byte_size(bytes) < 16384 ->
        restart_output(port, output <> bytes, deadline)

      {^port, {:exit_status, 0}} ->
        String.contains?(output, "P810_RESTART_OK")

      {^port, {:exit_status, _}} ->
        false
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        Port.close(port)
        false
    end
  end

  def jobs(intent) do
    primary_key = %{"id" => intent.id}

    Repo.all(
      from job in Oban.Job, where: fragment("?->'primary_key' = ?::jsonb", job.args, ^primary_key)
    )
  end

  def drain_submissions(acc) do
    receive do
      {:submitted, id} -> drain_submissions([id | acc])
    after
      0 -> acc
    end
  end

  def process_death(cut_at, cut) do
    P805.with_fixture(fn -> process_death_fixture(cut_at, cut) end)
  after
    Process.delete(:p810_provider)
  end

  defp process_death_fixture(cut_at, cut) do
    {:ok, _} = Identity.register(P805.request())
    [intent] = P805.read(Communications.MessageIntent, Communications)
    scenario = Scenario.start()
    :ok = Provider.configure(scenario, %{"proof-operation" => [submit: :accepted]})
    :ok = CutPoints.arm(scenario, cut, :executor, :terminate)

    {pid, monitor} =
      Scenario.spawn(scenario, :executor, fn ->
        execute_crash_boundary(intent, scenario, cut_at, cut)
      end)

    assert_receive {:DOWN, ^monitor, :process, ^pid, :proof_terminated}, 10000
    assert :ok = CutPoints.verify_consumed(scenario)
    [admitted] = P805.read(Communications.DeliveryAttempt, Communications)
    assert admitted.admission == :admitted

    if cut_at == :after_admission do
      Process.put(:p810_provider, fn _, _ -> :delivered end)
    end

    assert {:ok, :waiting} = Communications.execute(intent.id)
    recovered = Ash.get!(Communications.DeliveryAttempt, admitted.id, authorize?: false)

    if cut_at == :after_admission do
      assert recovered.admission == :closed_before_invocation
      assert recovered.invocation_started_at == nil
      Process.put(:p810_provider, fn _, _ -> :delivered end)
      assert {:ok, :processed} = Communications.execute(intent.id)
      assert length(P805.read(Communications.DeliveryAttempt, Communications)) == 2
    else
      assert recovered.provider_observation == :unknown
      assert recovered.active
      Process.put(:p810_provider, &unsafe_retry_provider/2)
      assert {:ok, :waiting} = Communications.execute(intent.id)
      assert length(P805.read(Communications.DeliveryAttempt, Communications)) == 1
    end

    assert :ok = Scenario.stop(scenario)
  end

  def pre_invocation_recheck(prerequisite) do
    P805.with_fixture(fn -> pre_invocation_recheck_fixture(prerequisite) end)
  after
    Process.delete(:p810_provider)
  end

  defp pre_invocation_recheck_fixture(prerequisite) do
    {:ok, _} = Identity.register(P805.request())
    [intent] = P805.read(Communications.MessageIntent, Communications)
    scenario = Scenario.start()
    parent = self()
    reference = make_ref()

    try do
      :ok = Provider.configure(scenario, %{"recovery-operation" => [submit: :accepted]})
      :ok = CutPoints.arm(scenario, :"transaction.after_commit", :executor, :terminate)

      {pid, monitor} =
        Scenario.spawn(scenario, :executor, fn ->
          Sandbox.unboxed_run(Repo, fn ->
            Process.put(:p810_provider, fn attempt, _ ->
              send(parent, {reference, :submitted, attempt.id})
              {:ok, event} = Provider.next(scenario, "recovery-operation", :submit)
              event.outcome
            end)

            Process.put(DeliverySeam, fn point ->
              if point == :after_admission do
                CutPoints.hit(scenario, :"transaction.after_commit", :executor)
              end
            end)

            Communications.execute(intent.id)
          end)
        end)

      assert_receive {:DOWN, ^monitor, :process, ^pid, :proof_terminated}, 10000
      assert :ok = CutPoints.verify_consumed(scenario)
      [admitted] = P805.read(Communications.DeliveryAttempt, Communications)
      assert admitted.active and admitted.invocation_started_at == nil

      Process.put(:p810_provider, fn attempt, _ ->
        send(parent, {reference, :submitted, attempt.id})
        :accepted
      end)

      alter_prerequisite(prerequisite, intent)

      expected =
        if prerequisite == :eligible do
          :waiting
        else
          :held
        end

      result = Communications.execute(intent.id)
      recovered = Ash.get!(Communications.DeliveryAttempt, admitted.id, authorize?: false)
      assert recovered.admission == :closed_before_invocation
      refute recovered.active
      assert recovered.invocation_started_at == nil
      assert recovered.provider_observation == :pending
      assert recovered.reconciliation == :none
      assert recovered.locale == admitted.locale
      assert recovered.render_digest == admitted.render_digest
      refute_receive {^reference, :submitted, _}
      assert [recovered] == P805.read(Communications.DeliveryAttempt, Communications)
      current = Ash.get!(Communications.MessageIntent, intent.id, authorize?: false)

      expected_disposition =
        if prerequisite == :eligible do
          :open
        else
          :held
        end

      assert current.dispatch_disposition == expected_disposition
      assert {:ok, ^expected} = result

      if prerequisite == :eligible do
        assert current.dispatch_disposition == :open
        assert {:ok, :processed} = Communications.execute(intent.id)
        assert_receive {^reference, :submitted, new_id}
        refute new_id == admitted.id

        assert recovered ==
                 Ash.get!(Communications.DeliveryAttempt, admitted.id, authorize?: false)
      else
        assert current.dispatch_disposition == :held
        assert {:ok, :held} = Communications.execute(intent.id)
        refute_receive {^reference, :submitted, _}
        assert [recovered] == P805.read(Communications.DeliveryAttempt, Communications)
      end
    after
      assert :ok = Scenario.stop(scenario)
    end
  end

  defp execute_competing_delivery(intent, parent) do
    Sandbox.unboxed_run(Repo, fn ->
      Process.put(:p810_provider, fn attempt, _ ->
        send(parent, {:submitted, attempt.id})
        :accepted
      end)

      Communications.execute(intent.id)
    end)
  end

  defp execute_lock_holder(intent, parent) do
    Sandbox.unboxed_run(Repo, fn ->
      Process.put(:p810_provider, fn _, _ -> :accepted end)
      Process.put(DeliverySeam, fn point -> pause_lock_holder(point, parent) end)
      Communications.execute(intent.id)
    end)
  end

  defp execute_lock_contender(intent, parent) do
    Sandbox.unboxed_run(Repo, fn ->
      %{rows: [[backend]]} = Repo.query!("SELECT pg_backend_pid()")
      send(parent, {:contender, backend})
      Process.put(DeliverySeam, fn point -> observe_contender_transaction(point) end)
      Process.put(:p810_provider, fn _, _ -> :accepted end)
      Communications.execute(intent.id)
    end)
  end

  defp execute_crash_boundary(intent, scenario, cut_at, cut) do
    Sandbox.unboxed_run(Repo, fn ->
      Process.put(:p810_provider, fn _, _ ->
        {:ok, event} = Provider.next(scenario, "proof-operation", :submit)
        event.outcome
      end)

      Process.put(DeliverySeam, fn point -> hit_delivery_cut(point, cut_at, scenario, cut) end)
      Communications.execute(intent.id)
    end)
  end

  defp pause_lock_holder(point, parent) do
    if point == :after_lock and not Process.get(:locked_once, false) do
      Process.put(:locked_once, true)

      %{rows: [[backend, tx]]} =
        Repo.query!("SELECT pg_backend_pid(), pg_current_xact_id()::text")

      send(parent, {:locked, self(), backend, tx})

      receive do
        :release -> :ok
      after
        5000 -> raise "lock release deadline"
      end
    end
  end

  defp observe_contender_transaction(point) do
    if point == :before_lock do
      Repo.query!("SELECT pg_current_xact_id()::text")
    end
  end

  defp hit_delivery_cut(point, cut_at, scenario, cut) do
    if point == cut_at do
      CutPoints.hit(scenario, cut, :executor)
    end
  end

  defp alter_prerequisite(prerequisite, intent) do
    case prerequisite do
      :content_ineligible ->
        Repo.query!("UPDATE message_intents SET translation_version_id = $1 WHERE id = $2", [
          "withdrawn-or-unknown",
          Ecto.UUID.dump!(intent.id)
        ])

      :capability_unavailable ->
        envelope = Ash.get!(Communications.ProtectedEnvelope, intent.id, authorize?: false)
        Ash.destroy!(envelope, action: :clear, authorize?: false)

      :provider_unavailable ->
        Process.delete(:p810_provider)

      :eligible ->
        :ok
    end
  end

  @spec unsafe_retry_provider(term(), term()) :: no_return()
  defp unsafe_retry_provider(_, _), do: flunk("unsafe retry")
end
