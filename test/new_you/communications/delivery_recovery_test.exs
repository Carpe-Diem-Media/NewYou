defmodule NewYou.Communications.DeliveryRecoveryTest do
  use ExUnit.Case, async: false
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Communications, Identity, Repo}
  alias NewYou.Proof.{CutPoints, DeliverySeam, P805, Provider, Scenario}

  for {point, cut} <- [
        after_admission: :"transaction.after_commit",
        before_invoke: :"provider.before_invoke",
        after_invoke: :"provider.after_invoke_before_persist"
      ] do
    test "process death at #{point} recovers conservatively" do
      P805.with_fixture(fn ->
        {:ok, _} = Identity.register(P805.request())
        [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
        scenario = Scenario.start()
        :ok = Provider.configure(scenario, %{"proof-operation" => [{:submit, :accepted}]})
        :ok = CutPoints.arm(scenario, unquote(cut), :executor, :terminate)

        {pid, monitor} =
          Scenario.spawn(scenario, :executor, fn ->
            Sandbox.unboxed_run(Repo, fn ->
              Process.put(:p810_provider, fn _, _ ->
                {:ok, event} = Provider.next(scenario, "proof-operation", :submit)
                event.outcome
              end)

              Process.put(DeliverySeam, fn point ->
                if point == unquote(point), do: CutPoints.hit(scenario, unquote(cut), :executor)
              end)

              Communications.execute(intent.id)
            end)
          end)

        assert_receive {:DOWN, ^monitor, :process, ^pid, :proof_terminated}, 10_000
        assert :ok = CutPoints.verify_consumed(scenario)
        [admitted] = Ash.read!(Communications.DeliveryAttempt, authorize?: false)
        assert admitted.admission == :admitted

        if unquote(point) == :after_admission,
          do: Process.put(:p810_provider, fn _, _ -> :delivered end)

        assert {:ok, :waiting} = Communications.execute(intent.id)
        recovered = Ash.get!(Communications.DeliveryAttempt, admitted.id, authorize?: false)

        if unquote(point) == :after_admission do
          assert recovered.admission == :closed_before_invocation
          assert recovered.invocation_started_at == nil
          Process.put(:p810_provider, fn _, _ -> :delivered end)
          assert {:ok, :processed} = Communications.execute(intent.id)
          assert length(Ash.read!(Communications.DeliveryAttempt, authorize?: false)) == 2
        else
          assert recovered.provider_observation == :unknown
          assert recovered.active
          Process.put(:p810_provider, fn _, _ -> flunk("unsafe retry") end)
          assert {:ok, :waiting} = Communications.execute(intent.id)
          assert length(Ash.read!(Communications.DeliveryAttempt, authorize?: false)) == 1
        end

        assert :ok = Scenario.stop(scenario)
      end)
    after
      Process.delete(:p810_provider)
    end
  end

  for prerequisite <- [
        :eligible,
        :content_ineligible,
        :capability_unavailable,
        :provider_unavailable
      ] do
    test "pre-invocation crash recovery rechecks #{prerequisite}" do
      P805.with_fixture(fn ->
        {:ok, _} = Identity.register(P805.request())
        [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
        scenario = Scenario.start()
        parent = self()
        reference = make_ref()

        try do
          :ok = Provider.configure(scenario, %{"recovery-operation" => [{:submit, :accepted}]})
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
                  if point == :after_admission,
                    do: CutPoints.hit(scenario, :"transaction.after_commit", :executor)
                end)

                Communications.execute(intent.id)
              end)
            end)

          assert_receive {:DOWN, ^monitor, :process, ^pid, :proof_terminated}, 10_000
          assert :ok = CutPoints.verify_consumed(scenario)
          [admitted] = Ash.read!(Communications.DeliveryAttempt, authorize?: false)
          assert admitted.active and admitted.invocation_started_at == nil

          Process.put(:p810_provider, fn attempt, _ ->
            send(parent, {reference, :submitted, attempt.id})
            :accepted
          end)

          case unquote(prerequisite) do
            :content_ineligible ->
              Repo.query!(
                "UPDATE message_intents SET translation_version_id = $1 WHERE id = $2",
                ["withdrawn-or-unknown", Ecto.UUID.dump!(intent.id)]
              )

            :capability_unavailable ->
              envelope = Ash.get!(Communications.ProtectedEnvelope, intent.id, authorize?: false)
              Ash.destroy!(envelope, action: :clear, authorize?: false)

            :provider_unavailable ->
              Process.delete(:p810_provider)

            :eligible ->
              :ok
          end

          expected = if unquote(prerequisite) == :eligible, do: :waiting, else: :held
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
          assert [recovered] == Ash.read!(Communications.DeliveryAttempt, authorize?: false)
          current = Ash.get!(Communications.MessageIntent, intent.id, authorize?: false)
          expected_disposition = if unquote(prerequisite) == :eligible, do: :open, else: :held
          assert current.dispatch_disposition == expected_disposition
          assert {:ok, ^expected} = result

          if unquote(prerequisite) == :eligible do
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
            assert [recovered] == Ash.read!(Communications.DeliveryAttempt, authorize?: false)
          end
        after
          assert :ok = Scenario.stop(scenario)
        end
      end)
    after
      Process.delete(:p810_provider)
    end
  end

  test "competing real PostgreSQL executors admit only one provider operation" do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      parent = self()

      tasks =
        for _ <- 1..8 do
          Task.async(fn ->
            Sandbox.unboxed_run(Repo, fn ->
              Process.put(:p810_provider, fn attempt, _ ->
                send(parent, {:submitted, attempt.id})
                :accepted
              end)

              Communications.execute(intent.id)
            end)
          end)
        end

      results = Task.await_many(tasks, 15_000)
      assert Enum.all?(results, &match?({:ok, _}, &1))
      submissions = drain_submissions([])
      assert length(submissions) <= 1
      attempts = Ash.read!(Communications.DeliveryAttempt, authorize?: false)
      assert Enum.count(attempts, & &1.active) <= 1
      assert Enum.count(attempts, &(not is_nil(&1.invocation_started_at))) == length(submissions)
      # A racing recovery may fence all pre-invocation admissions. A later run
      # must still make progress once competitors are gone.
      if submissions == [] do
        Process.put(:p810_provider, fn _, _ -> :accepted end)
        assert {:ok, :processed} = Communications.execute(intent.id)
      end
    end)
  after
    Process.delete(:p810_provider)
  end

  test "real AshOban scheduler discovers zero-job intent and recreates deleted and exhausted jobs" do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
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
      for job <- jobs(intent), do: assert(:ok == trigger.worker.perform(job))
      assert length(Ash.read!(Communications.DeliveryAttempt, authorize?: false)) == 1
    end)
  after
    Process.delete(:p810_provider)
  end

  test "admission contenders wait on a real PostgreSQL row lock" do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      parent = self()

      first =
        Task.async(fn ->
          Sandbox.unboxed_run(Repo, fn ->
            Process.put(:p810_provider, fn _, _ -> :accepted end)

            Process.put(DeliverySeam, fn point ->
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
            end)

            Communications.execute(intent.id)
          end)
        end)

      assert_receive {:locked, holder, backend_a, transaction_a}, 2000

      second =
        Task.async(fn ->
          Sandbox.unboxed_run(Repo, fn ->
            %{rows: [[backend]]} = Repo.query!("SELECT pg_backend_pid()")
            send(parent, {:contender, backend})

            Process.put(DeliverySeam, fn point ->
              if point == :before_lock, do: Repo.query!("SELECT pg_current_xact_id()::text")
            end)

            Process.put(:p810_provider, fn _, _ -> :accepted end)
            Communications.execute(intent.id)
          end)
        end)

      assert_receive {:contender, backend_b}, 2000
      assert backend_a != backend_b

      transaction_b =
        wait_for_lock(backend_a, backend_b, System.monotonic_time(:millisecond) + 2000)

      assert is_binary(transaction_b)
      assert transaction_a != transaction_b
      send(holder, :release)
      assert Enum.all?(Task.await_many([first, second], 10_000), &match?({:ok, _}, &1))
    end)
  end

  defp wait_for_lock(holder, contender, deadline) do
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

  @tag timeout: 90_000
  test "fresh BEAM discovers missing jobs and preserves accepted ambiguity across another boot" do
    P805.with_fixture(fn ->
      {:ok, _} = Identity.register(P805.request())
      [intent] = Ash.read!(Communications.MessageIntent, authorize?: false)
      assert jobs(intent) == []
      assert restart(intent.id)
      [attempt] = Ash.read!(Communications.DeliveryAttempt, authorize?: false)
      assert attempt.provider_observation == :accepted
      for job <- jobs(intent), do: Repo.delete!(job)
      assert restart(intent.id)
      assert [same] = Ash.read!(Communications.DeliveryAttempt, authorize?: false)
      assert same.id == attempt.id
      assert same.provider_observation == :accepted

      assert Ash.get!(Communications.MessageIntent, intent.id, authorize?: false).dispatch_disposition ==
               :reconciliation_required
    end)
  end

  defp restart(id) do
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
    restart_output(port, "", System.monotonic_time(:millisecond) + 30_000)
  end

  defp restart_output(port, output, deadline) do
    receive do
      {^port, {:data, bytes}} when byte_size(output) + byte_size(bytes) < 16_384 ->
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

  defp jobs(intent),
    do: Enum.filter(Repo.all(Oban.Job), &(&1.args["primary_key"] == %{"id" => intent.id}))

  defp drain_submissions(acc) do
    receive do
      {:submitted, id} -> drain_submissions([id | acc])
    after
      0 -> acc
    end
  end
end
