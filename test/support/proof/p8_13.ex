defmodule NewYou.Proof.P813 do
  @moduledoc "Real E1/source transactions through the existing P8-04 Scenario, CutPoints and Concurrent machinery."
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Audit, Identity, Repo}

  alias NewYou.Proof.{
    AuditSeam,
    Concurrent,
    CutPoints,
    P805,
    P813HoldFixture,
    Scenario,
    SecurityHoldSeam
  }

  require Ash.Query

  def run(id) do
    P813HoldFixture.with_fixture(fn fixture ->
      request = P813HoldFixture.reviewed_hold(fixture)
      execute(id, fixture, request)
    end)
  end

  defp execute("p813.admission_cut" = id, _fixture, request) do
    scenario = Scenario.start()

    try do
      {:error, :security_hold_unavailable} =
        cut_release(scenario, request, :after_admission, "transaction.after_commit", fn ->
          P805.check(
            id,
            "committed_before_effect",
            admission_count(request) == 1 and posture(request.target_id) == :held
          )
        end)

      P805.check(id, "cut_consumed", CutPoints.verify_consumed(scenario) == :ok)
      P805.check(id, "hold_retained", posture(request.target_id) == :held)
      retry = %{request | operation_id: Ecto.UUID.generate()}

      P805.check(
        id,
        "retry_current",
        match?({:ok, %{status: :released}}, Identity.release_security_hold(retry))
      )
    after
      Scenario.stop(scenario)
    end
  end

  defp execute("p813.capture_failure" = id, _fixture, request) do
    scenario = Scenario.start()

    try do
      {:error, :security_hold_unavailable} =
        cut_release(scenario, request, :before_admission, "evidence.before_materialize", fn ->
          :ok
        end)

      P805.check(id, "cut_consumed", CutPoints.verify_consumed(scenario) == :ok)
      P805.check(id, "no_admission", admission_count(request) == 0)
      P805.check(id, "no_release", posture(request.target_id) == :held)
    after
      Scenario.stop(scenario)
    end
  end

  defp execute("p813.source_failure" = id, _fixture, request) do
    scenario = Scenario.start()

    try do
      {:error, :security_hold_unavailable} =
        cut_release(
          scenario,
          request,
          :after_release_before_commit,
          "transaction.before_commit",
          fn -> :ok end
        )

      P805.check(id, "cut_consumed", CutPoints.verify_consumed(scenario) == :ok)
      P805.check(id, "admission_retained", admission_count(request) == 1)
      P805.check(id, "source_rolled_back", posture(request.target_id) == :held)
      obligation = outcome!(request)

      P805.check(
        id,
        "linked_failure",
        obligation.outcome == :failed and not is_nil(obligation.admission_id)
      )

      {:ok, _} =
        Audit.materialize_registration_evidence(%{primary_key: %{id: obligation.id}},
          authorize?: false
        )

      P805.check(
        id,
        "recovery_no_source_replay",
        posture(request.target_id) == :held and
          Audit.get_evidence_obligation!(obligation.id, authorize?: false).state == :fulfilled
      )
    after
      Scenario.stop(scenario)
    end
  end

  defp execute(id, _fixture, request)
       when id in ["p813.same_attempt_race", "p813.distinct_attempt_race"] do
    second =
      if id == "p813.same_attempt_race",
        do: request,
        else: %{request | operation_id: Ecto.UUID.generate()}

    scenario = Scenario.start()
    parent = self()
    ref = make_ref()

    try do
      {_pid, monitor} =
        Scenario.spawn(scenario, :coordinator, fn ->
          nested = Scenario.start()

          result =
            Concurrent.run(
              nested,
              %{
                first: fn -> release_worker(parent, ref, :first, request) end,
                second: fn -> release_worker(parent, ref, :second, second) end
              },
              timeout: 30_000
            )

          Scenario.stop(nested)
          send(parent, {ref, :finished, result})
        end)

      first = await(ref, {:admitted, :first})
      second_worker = await(ref, {:admitted, :second})
      P805.check(id, "independent_connections", first.backend != second_worker.backend)
      send(first.pid, {ref, :source})
      source = await(ref, :source_locked)
      send(second_worker.pid, {ref, :source})
      other_tx = await(ref, :source_started)

      P805.check(
        id,
        "independent_transactions",
        is_binary(source.transaction) and is_binary(other_tx) and source.transaction != other_tx
      )

      P805.check(
        id,
        "contention",
        contention(
          first.backend,
          second_worker.backend,
          System.monotonic_time(:millisecond) + 10_000
        )
      )

      send(first.pid, {ref, :commit})
      {:ok, %{outcomes: outcomes}} = await(ref, :finished)
      results = Enum.map(outcomes, fn {_label, value} -> value.outcome end)

      if id == "p813.same_attempt_race" do
        P805.check(id, "both_replay", results == [:released, :released])
        P805.check(id, "one_admission", admission_count(request) == 1)
      else
        P805.check(id, "one_winner", Enum.sort(results) == [:denied, :released])

        P805.check(
          id,
          "distinct_admissions",
          admission_count(request) == 1 and admission_count(second) == 1
        )
      end

      P805.check(id, "one_transition", P805.account!(request.target_id).hold_version == 2)

      receive do
        {:DOWN, ^monitor, :process, _, :normal} -> :ok
      after
        5_000 -> raise "Support coordinator cleanup deadline"
      end
    after
      Scenario.stop(scenario)
    end
  end

  defp execute("p813.restart" = id, fixture, request) do
    P805.check(id, "first_boot", restart(:authorize, fixture, request) == :authorized)
    P805.check(id, "reconstructed", posture(request.target_id) == :held)
    Ash.update!(fixture.grants.release, %{}, action: :revoke, authorize?: false)
    P805.check(id, "current_revocation", restart(:authorize, fixture, request) == :denied)
    # A different valid named grant provides the next distinct governed attempt.
    grant =
      P813HoldFixture.grant(
        fixture.actor,
        fixture.target,
        fixture.approver,
        :release_security_hold
      )

    request = %{request | grant_id: grant.id}
    {:ok, %{status: :released}} = Identity.release_security_hold(request)
    obligation = outcome!(request)
    before = P805.account!(request.target_id).hold_operations

    P805.check(
      id,
      "second_boot",
      restart({:materialize, obligation.id}, fixture, request) == :materialized
    )

    P805.check(
      id,
      "outcome_recovered",
      Audit.get_evidence_obligation!(obligation.id, authorize?: false).state == :fulfilled
    )

    P805.check(id, "source_unchanged", P805.account!(request.target_id).hold_operations == before)
  end

  defp execute("p813.crash_after_admission" = id, _fixture, request) do
    terminate_at(request, :after_admission, fn scenario ->
      P805.check(id, "admission_committed", admission_count(request) == 1)
      P805.check(id, "cut_consumed", CutPoints.verify_consumed(scenario) == :ok)
      P805.check(id, "hold_retained", posture(request.target_id) == :held)

      P805.check(
        id,
        "same_attempt_retry",
        match?({:ok, %{status: :released}}, Identity.release_security_hold(request))
      )

      P805.check(id, "one_admission", admission_count(request) == 1)
    end)
  end

  defp execute("p813.crash_after_source" = id, fixture, request) do
    terminate_at(request, :after_source_commit, fn scenario ->
      before = P805.account!(request.target_id).hold_operations
      P805.check(id, "source_committed", posture(request.target_id) == :normal)
      P805.check(id, "cut_consumed", CutPoints.verify_consumed(scenario) == :ok)
      obligation = outcome!(request)

      P805.check(
        id,
        "outcome_durable",
        obligation.state == :open and obligation.outcome == :succeeded
      )

      P805.check(
        id,
        "restarted_materialisation",
        restart({:materialize, obligation.id}, fixture, request) == :materialized
      )

      P805.check(
        id,
        "no_source_replay",
        P805.account!(request.target_id).hold_operations == before and
          match?({:ok, %{status: :released, version: 2}}, Identity.release_security_hold(request))
      )
    end)
  end

  defp release_worker(parent, ref, label, request) do
    Process.put(SecurityHoldSeam, fn
      :after_admission ->
        send(
          parent,
          {ref, {:admitted, label},
           %{pid: self(), backend: P805.scalar("SELECT pg_backend_pid()")}}
        )

        receive do
          {^ref, :source} -> :ok
        after
          15_000 -> raise "Support admission deadline"
        end

      :before_release when label == :first ->
        send(
          parent,
          {ref, :source_locked, %{transaction: P805.scalar("SELECT txid_current()::text")}}
        )

        receive do
          {^ref, :commit} -> :ok
        after
          15_000 -> raise "Support source deadline"
        end

      :before_authority when label == :second ->
        send(parent, {ref, :source_started, P805.scalar("SELECT txid_current()::text")})

      _ ->
        :ok
    end)

    try do
      case Identity.release_security_hold(request) do
        {:ok, %{status: :released}} -> :released
        _ -> :denied
      end
    after
      Process.delete(SecurityHoldSeam)
    end
  end

  defp await(ref, phase) do
    receive do
      {^ref, ^phase, result} -> result
    after
      35_000 -> raise "Support proof deadline"
    end
  end

  defp contention(first, second, deadline) do
    case Repo.query!(
           "SELECT $2 = ANY(pg_blocking_pids(pid)) FROM pg_stat_activity WHERE pid = $1",
           [second, first],
           log: false
         ).rows do
      [[true]] ->
        true

      _ ->
        if System.monotonic_time(:millisecond) >= deadline,
          do: raise("Support contention not observed")

        Process.sleep(10)
        contention(first, second, deadline)
    end
  end

  defp admission_count(request),
    do:
      P805.scalar("SELECT count(*) FROM evidence_records WHERE attempt_id = $1", [
        Ecto.UUID.dump!(request.operation_id)
      ])

  defp posture(id), do: P805.account!(id).security_posture

  defp outcome!(request) do
    Audit.EvidenceObligation
    |> Ash.Query.filter(source_operation_id == ^request.operation_id)
    |> Ash.read_one!(authorize?: false)
  end

  defp cut_release(scenario, request, hook, cut, observe) do
    parent = self()
    ref = make_ref()
    :ok = CutPoints.arm(scenario, cut, :effect, :raise)

    {_worker, monitor} =
      Scenario.spawn(scenario, :effect, fn ->
        :ok = Sandbox.checkout(Repo, sandbox: false)
        seam = if hook == :before_admission, do: AuditSeam, else: SecurityHoldSeam

        Process.put(seam, fn point ->
          pause_at_cut(point, hook, scenario, cut, parent, ref)
        end)

        try do
          send(parent, {ref, :cut_result, Identity.release_security_hold(request)})
        after
          Process.delete(seam)
          Sandbox.checkin(Repo)
        end
      end)

    worker = await(ref, :cut_ready)
    observe.()
    send(worker, {ref, :cut})
    result = await(ref, :cut_result)

    receive do
      {:DOWN, ^monitor, :process, _, :normal} -> :ok
    after
      5_000 -> raise "Support cut cleanup deadline"
    end

    result
  end

  defp pause_at_cut(point, hook, scenario, cut, parent, ref) do
    if point == hook do
      send(parent, {ref, :cut_ready, self()})

      receive do
        {^ref, :cut} -> :ok
      after
        15_000 -> raise "Support cut deadline"
      end

      CutPoints.hit(scenario, cut, :effect)
    end
  end

  defp terminate_at(request, hook, verify) do
    parent = self()
    ref = make_ref()
    scenario = Scenario.start()
    :ok = CutPoints.arm(scenario, "transaction.after_commit", :effect, :terminate)

    try do
      {_worker, monitor} =
        Scenario.spawn(scenario, :effect, fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          Process.put(SecurityHoldSeam, fn point ->
            if point == hook do
              send(parent, {ref, :kill_ready, self()})

              receive do
                {^ref, :kill} -> :ok
              after
                15_000 -> raise "Support terminate deadline"
              end

              CutPoints.hit(scenario, "transaction.after_commit", :effect)
            end
          end)

          Identity.release_security_hold(request)
        end)

      worker = await(ref, :kill_ready)
      send(worker, {ref, :kill})

      receive do
        {:DOWN, ^monitor, :process, ^worker, :proof_terminated} -> :ok
      after
        5_000 -> raise "Support worker was not terminated"
      end

      verify.(scenario)
    after
      Scenario.stop(scenario)
    end
  end

  defp restart(mode, fixture, request) do
    input = %{
      mode: mode,
      credentials: fixture.actor.credentials,
      grant_id: request.grant_id,
      target_id: request.target_id,
      signing_secret:
        Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))
    }

    {input, expected} =
      case mode do
        {:materialize, obligation_id} ->
          {%{input | mode: "materialize"} |> Map.put(:obligation_id, obligation_id),
           :materialized}

        :authorize ->
          {%{input | mode: "authorize"}, :authorized}
      end

    executable = System.find_executable("mix") || raise "mix unavailable"

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        args: ["run", "test/proof/p8_13_restart.exs"],
        env: [{~c"MIX_ENV", ~c"test"}, {~c"ERL_FLAGS", ~c"+S 2:2"}]
      ])

    true = Port.command(port, Jason.encode!(input) <> "\n")

    case restart_output(port, "", System.monotonic_time(:millisecond) + 30_000) do
      "P813_AUTHORIZED" -> expected
      "P813_MATERIALIZED" -> :materialized
      _ -> :denied
    end
  end

  defp restart_output(port, output, deadline) do
    receive do
      {^port, {:data, bytes}} when byte_size(output) + byte_size(bytes) < 16_384 ->
        restart_output(port, output <> bytes, deadline)

      {^port, {:exit_status, 0}} ->
        output |> String.split("\n") |> Enum.find("", &String.starts_with?(&1, "P813_"))

      {^port, {:exit_status, _}} ->
        ""
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        Port.close(port)
        ""
    end
  end
end
