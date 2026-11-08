defmodule NewYou.Identity.ReconciliationTest do
  use ExUnit.Case, async: false
  alias NewYou.Identity
  require Ash.Query
  alias NewYou.Proof.{P805, P813HoldFixture}

  test "scoped detection, verified review and apply preserve history and retire the losing PMR" do
    with_case(fn f ->
      assert f.case.status == :detected
      assert P805.account!(f.target.id).account_status == :open
      assert {:ok, approved} = approve(f)
      assert approved.status == :approved
      assert {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      request = apply_request(f, approved)
      assert {:ok, applied} = Identity.apply_reconciliation(request)
      assert applied.status == :applied
      assert applied.canonical_id == f.survivor.id
      loser = P805.account!(f.target.id)
      assert loser.pmr_status == :retired
      assert loser.pmr == f.old_pmr
      assert loser.canonical_account_id == f.survivor.id
      assert loser.account_status == :closed_terminal
      assert P805.account!(f.survivor.id).pmr_status == :active

      assert {:error, :authentication_unavailable} =
               Identity.authorize_session(f.target.credentials)

      assert {:ok, replay} = Identity.apply_reconciliation(request)
      assert replay.id == applied.id
      assert replay.version == applied.version
      assert [admission] = admissions(request.operation_id)
      assert admission.action_class == :identity_reconciliation
      assert [%{admission_id: admission_id, outcome: :succeeded}] = outcomes(request.operation_id)
      assert admission_id == admission.id
    end)
  end

  test "detection and demographic similarity cannot substitute for current verified control" do
    with_case(fn f ->
      request = review_request(f)

      assert {:error, :reconciliation_unavailable} =
               Identity.review_reconciliation(%{request | controls: [f.target.credentials]})

      assert {:ok, candidate} = Identity.review_reconciliation(%{request | decision: :candidate})
      assert candidate.status == :candidate

      assert {:ok, review} =
               Identity.review_reconciliation(%{
                 request
                 | expected_version: candidate.version,
                   decision: :review
               })

      assert review.status == :review

      assert {:ok, conflict} =
               Identity.review_reconciliation(%{
                 request
                 | expected_version: review.version,
                   decision: :conflict
               })

      assert conflict.status == :conflict

      assert [%{evidence_type: :identity_reconciliation_review, outcome: :denied}] =
               read(NewYou.Audit.EvidenceObligation, "case_id", conflict.id)

      assert {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)

      assert {:error, :reconciliation_unavailable} =
               Identity.apply_reconciliation(apply_request(f, conflict))

      assert admissions_for_target(f.target.id) == []
    end)
  end

  test "wrong scope and stale case version fail closed" do
    with_case(fn f ->
      assert {:error, :reconciliation_unavailable} =
               Identity.review_reconciliation(%{review_request(f) | grant_id: f.grants.review.id})

      assert {:ok, approved} = approve(f)

      assert {:error, :reconciliation_unavailable} =
               Identity.review_reconciliation(review_request(f))

      assert {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)

      assert {:error, :reconciliation_unavailable} =
               Identity.apply_reconciliation(%{apply_request(f, approved) | expected_version: 0})
    end)
  end

  test "revoked control after review cannot authorize apply" do
    with_case(fn f ->
      {:ok, approved} = approve(f)
      :ok = Identity.revoke_session(f.survivor.credentials)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      request = apply_request(f, approved)
      assert {:error, :reconciliation_unavailable} = Identity.apply_reconciliation(request)
      assert admissions(request.operation_id) == []
      assert P805.account!(f.target.id).pmr_status == :active
    end)
  end

  for fault <- [:after_admission, :before_source_commit] do
    test "#{fault} failure retains E1 and rolls back Identity with a linked failed result" do
      with_case(fn f ->
        {:ok, approved} = approve(f)
        {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
        request = apply_request(f, approved)

        Process.put(NewYou.Proof.ReconciliationSeam, fn point ->
          if point == unquote(fault), do: raise("synthetic source failure"), else: :ok
        end)

        try do
          assert {:error, :reconciliation_unavailable} = Identity.apply_reconciliation(request)
        after
          Process.delete(NewYou.Proof.ReconciliationSeam)
        end

        assert P805.account!(f.target.id).pmr_status == :active
        assert P805.account!(f.target.id).account_status == :open
        assert {:ok, _} = Identity.authorize_session(f.target.credentials)
        assert [_] = admissions(request.operation_id)
        assert [%{outcome: :failed}] = outcomes(request.operation_id)
        assert {:error, :reconciliation_unavailable} = Identity.apply_reconciliation(request)
      end)
    end
  end

  test "E1 capture failure cannot retire a PMR" do
    with_case(fn f ->
      {:ok, approved} = approve(f)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      request = apply_request(f, approved)

      Process.put(NewYou.Proof.AuditSeam, fn
        :before_admission -> raise "synthetic Audit failure"
        _ -> :ok
      end)

      try do
        assert {:error, :reconciliation_unavailable} = Identity.apply_reconciliation(request)
      after
        Process.delete(NewYou.Proof.AuditSeam)
      end

      assert admissions(request.operation_id) == []
      assert P805.account!(f.target.id).pmr_status == :active
    end)
  end

  test "revocation after E1 blocks apply under fresh authority" do
    with_case(fn f ->
      {:ok, approved} = approve(f)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      request = apply_request(f, approved)

      Process.put(NewYou.Proof.ReconciliationSeam, fn
        :after_admission ->
          Ash.update!(
            f.reconciliation_grant,
            %{actor_id: f.approver.id, reason_code: :security_review},
            action: :revoke,
            authorize?: false
          )

          :ok

        _ ->
          :ok
      end)

      try do
        assert {:error, :reconciliation_unavailable} = Identity.apply_reconciliation(request)
      after
        Process.delete(NewYou.Proof.ReconciliationSeam)
      end

      assert [_] = admissions(request.operation_id)
      assert [%{outcome: :failed}] = outcomes(request.operation_id)
      assert P805.account!(f.target.id).pmr_status == :active
    end)
  end

  test "retired PMR and applied provenance cannot be revived or rewritten" do
    with_case(fn f ->
      {:ok, approved} = approve(f)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      {:ok, applied} = Identity.apply_reconciliation(apply_request(f, approved))

      assert_raise Postgrex.Error, fn ->
        NewYou.Repo.query!(
          "UPDATE accounts SET pmr_status = 'active', canonical_account_id = NULL, account_status = 'open' WHERE id = $1",
          [Ecto.UUID.dump!(f.target.id)]
        )
      end

      assert_raise Postgrex.Error, fn ->
        NewYou.Repo.query!("UPDATE reconciliation_cases SET review = '{}' WHERE id = $1", [
          Ecto.UUID.dump!(applied.id)
        ])
      end

      assert_raise Postgrex.Error, fn ->
        NewYou.Repo.query!("DELETE FROM reconciliation_cases WHERE id = $1", [
          Ecto.UUID.dump!(applied.id)
        ])
      end

      assert_raise Postgrex.Error, fn -> NewYou.Repo.query!("TRUNCATE reconciliation_cases") end

      assert %{rows: [[1]]} =
               NewYou.Repo.query!(
                 "SELECT count(*) FROM identity_pmr_reservations WHERE pmr = $1",
                 [f.old_pmr]
               )

      input = P805.request()
      # Exercise the actual Account allocation constraint, not an active-only index.
      assert {:error, _} =
               Ash.create(
                 Identity.Account,
                 Map.merge(
                   Map.take(input, [
                     :first_name,
                     :surname,
                     :email,
                     :password,
                     :preferred_language,
                     :confirmed_age_18?,
                     :terms_version_id,
                     :privacy_version_id
                   ]),
                   %{
                     pmr: f.old_pmr,
                     legal_accepted_at: DateTime.utc_now(),
                     acceptance_locale: :af
                   }
                 ),
                 action: :register,
                 authorize?: false
               )
    end)
  end

  test "compensating case changes the current canonical identity while preserving retired values and original decisions" do
    with_case(fn f ->
      {:ok, approved} = approve(f)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      {:ok, original} = Identity.apply_reconciliation(apply_request(f, approved))
      replacement = P813HoldFixture.member()
      grant = P813HoldFixture.grant(f.actor, f.survivor, f.approver, :identity_reconciliation)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :review_reconciliation)

      {:ok, correction} =
        Identity.open_reconciliation(%{
          credentials: f.actor.credentials,
          grant_id: grant.id,
          candidate_id: f.survivor.id,
          canonical_id: replacement.id,
          detection_basis: :verified_control,
          operation_id: Ecto.UUID.generate(),
          compensates_id: original.id
        })

      correction_fixture = %{
        f
        | target: f.survivor,
          survivor: replacement,
          case: correction,
          reconciliation_grant: grant
      }

      {:ok, approved_correction} = approve(correction_fixture)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)

      {:ok, corrected} =
        Identity.apply_reconciliation(apply_request(correction_fixture, approved_correction))

      assert corrected.compensates_id == original.id

      assert Ash.get!(Identity.ReconciliationCase, original.id, authorize?: false).canonical_id ==
               f.survivor.id

      assert P805.account!(f.target.id).pmr_status == :retired
      assert P805.account!(f.target.id).pmr == f.old_pmr
      assert P805.account!(replacement.id).pmr_status == :active
      refute P805.account!(replacement.id).pmr == f.old_pmr
    end)
  end

  for mode <- [:same_attempt, :distinct_attempt, :overlapping_cases] do
    @tag timeout: 60_000
    test "#{mode} uses independent competing transactions with one canonical decision" do
      with_case(fn f ->
        {:ok, first_case} = approve(f)

        second_fixture =
          if unquote(mode) == :overlapping_cases do
            second_actor = f.reviewer
            {:ok, :ok} = P813HoldFixture.step_up(second_actor, :review_reconciliation)

            grant =
              P813HoldFixture.grant(
                second_actor,
                f.survivor,
                f.approver,
                :identity_reconciliation
              )

            {:ok, reverse} =
              Identity.open_reconciliation(%{
                credentials: second_actor.credentials,
                grant_id: grant.id,
                candidate_id: f.survivor.id,
                canonical_id: f.target.id,
                operation_id: Ecto.UUID.generate(),
                detection_basis: :verified_control
              })

            %{
              f
              | actor: second_actor,
                target: f.survivor,
                survivor: f.target,
                case: reverse,
                reconciliation_grant: grant
            }
          else
            f
          end

        second_case =
          if unquote(mode) == :overlapping_cases,
            do: elem(approve(second_fixture), 1),
            else: first_case

        {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)

        if unquote(mode) == :overlapping_cases do
          refute second_fixture.actor.id == f.actor.id
          refute second_fixture.actor.credentials.session_id == f.actor.credentials.session_id
          refute second_fixture.reconciliation_grant.id == f.reconciliation_grant.id
          refute second_case.review["actor_id"] == first_case.review["actor_id"]
          {:ok, :ok} = P813HoldFixture.step_up(second_fixture.actor, :apply_reconciliation)
        end

        first_request = apply_request(f, first_case)

        second_request =
          if unquote(mode) == :same_attempt,
            do: first_request,
            else: apply_request(second_fixture, second_case)

        results = race(first_request, second_request)

        if unquote(mode) == :same_attempt do
          assert results == [:applied, :applied]
          assert length(admissions(first_request.operation_id)) == 1
        else
          assert Enum.sort(results) == [:applied, :denied]
        end

        assert P805.account!(f.target.id).pmr_status == :retired
        assert P805.account!(f.survivor.id).pmr_status == :active
      end)
    end
  end

  defp race(first_request, second_request) do
    alias NewYou.Proof.{Concurrent, Scenario}
    parent = self()
    reference = make_ref()
    scenario = Scenario.start()

    try do
      Scenario.spawn(scenario, :coordinator, fn ->
        nested = Scenario.start()

        try do
          result =
            Concurrent.run(
              nested,
              %{
                first: fn -> race_worker(parent, reference, :first, first_request) end,
                second: fn -> race_worker(parent, reference, :second, second_request) end
              },
              timeout: 30_000
            )

          send(parent, {reference, :done, result})
        after
          Scenario.stop(nested)
        end
      end)

      first = await(reference, {:admitted, :first})
      second = await(reference, {:admitted, :second})
      refute first.backend == second.backend
      send(first.pid, {reference, :go})
      first_tx = await(reference, :locked)
      send(second.pid, {reference, :go})
      second_tx = await(reference, :started)
      refute first_tx == second_tx
      assert blocked?(first.backend, second.backend, System.monotonic_time(:millisecond) + 10_000)
      send(first.pid, {reference, :commit})
      {:ok, %{outcomes: outcomes}} = await(reference, :done)
      Enum.map(outcomes, fn {_label, value} -> value.outcome end)
    after
      Scenario.stop(scenario)
    end
  end

  defp race_worker(parent, reference, label, request) do
    Process.put(NewYou.Proof.ReconciliationSeam, fn
      :after_admission ->
        send(
          parent,
          {reference, {:admitted, label},
           %{pid: self(), backend: P805.scalar("SELECT pg_backend_pid()")}}
        )

        receive do
          {^reference, :go} -> :ok
        after
          15_000 -> raise "admission deadline"
        end

      :before_source_commit when label == :first ->
        send(parent, {reference, :locked, P805.scalar("SELECT txid_current()::text")})

        receive do
          {^reference, :commit} -> :ok
        after
          15_000 -> raise "source deadline"
        end

      :before_source_transaction when label == :second ->
        send(parent, {reference, :started, P805.scalar("SELECT txid_current()::text")})
        :ok

      _ ->
        :ok
    end)

    try do
      case Identity.apply_reconciliation(request) do
        {:ok, %{status: :applied}} -> :applied
        _ -> :denied
      end
    after
      Process.delete(NewYou.Proof.ReconciliationSeam)
    end
  end

  defp await(reference, phase) do
    receive do
      {^reference, ^phase, value} -> value
    after
      35_000 -> raise "reconciliation proof deadline"
    end
  end

  defp blocked?(blocker, blocked, deadline) do
    case NewYou.Repo.query!(
           "SELECT $2 = ANY(pg_blocking_pids(pid)) FROM pg_stat_activity WHERE pid = $1",
           [blocked, blocker],
           log: false
         ).rows do
      [[true]] ->
        true

      _ ->
        if System.monotonic_time(:millisecond) >= deadline, do: raise("contention not observed")
        Process.sleep(10)
        blocked?(blocker, blocked, deadline)
    end
  end

  test "a revoked control bearer cannot stand in for current verified control" do
    with_case(fn f ->
      {:ok, approved} = approve(f)

      NewYou.Repo.query!(
        "UPDATE tokens SET purpose = 'revocation' WHERE purpose = 'user' AND jti = (SELECT token_jti FROM sessions WHERE id = $1)",
        [Ecto.UUID.dump!(f.survivor.credentials.session_id)]
      )

      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)

      assert {:error, :reconciliation_unavailable} =
               Identity.apply_reconciliation(apply_request(f, approved))
    end)
  end

  for cut <- [:after_admission, :after_source_commit] do
    @tag timeout: 60_000
    test "process termination at #{cut} recovers from durable authority" do
      alias NewYou.Proof.{Scenario, CutPoints}

      with_case(fn f ->
        {:ok, approved} = approve(f)
        {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
        request = apply_request(f, approved)
        parent = self()
        reference = make_ref()
        scenario = Scenario.start()
        :ok = CutPoints.arm(scenario, "transaction.after_commit", :effect, :terminate)

        try do
          {worker, monitor} =
            Scenario.spawn(scenario, :effect, fn ->
              :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

              Process.put(NewYou.Proof.ReconciliationSeam, fn point ->
                if point == unquote(cut) do
                  send(parent, {reference, :kill_ready, self()})

                  receive do
                    {^reference, :kill} -> :ok
                  after
                    10_000 -> raise "termination deadline"
                  end

                  CutPoints.hit(scenario, "transaction.after_commit", :effect)
                else
                  :ok
                end
              end)

              Identity.apply_reconciliation(request)
            end)

          assert await(reference, :kill_ready) == worker
          send(worker, {reference, :kill})
          assert_receive {:DOWN, ^monitor, :process, ^worker, :proof_terminated}, 5_000

          if unquote(cut) == :after_admission do
            assert P805.account!(f.target.id).pmr_status == :active
          else
            assert P805.account!(f.target.id).pmr_status == :retired
          end

          assert [_] = admissions(request.operation_id)
          assert {:ok, applied} = Identity.apply_reconciliation(request)
          assert applied.status == :applied
          assert [%{outcome: :succeeded}] = outcomes(request.operation_id)
        after
          Scenario.stop(scenario)
        end
      end)
    end
  end

  @tag timeout: 60_000
  test "a fresh BEAM reconstructs the committed case, PMR and current privileged replay" do
    with_case(fn f ->
      {:ok, approved} = approve(f)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      request = apply_request(f, approved)
      {:ok, applied} = Identity.apply_reconciliation(request)
      [obligation] = outcomes(request.operation_id)

      input = %{
        request: request,
        signing_secret:
          Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret)),
        retired_pmr: f.old_pmr,
        obligation_id: obligation.id
      }

      port =
        Port.open({:spawn_executable, System.find_executable("mix")}, [
          :binary,
          :exit_status,
          args: ["run", "test/proof/p8_14_restart.exs"],
          env: [{~c"MIX_ENV", ~c"test"}, {~c"ERL_FLAGS", ~c"+S 2:2"}]
        ])

      true = Port.command(port, Jason.encode!(input) <> "\n")

      assert restart_output(port, "", System.monotonic_time(:millisecond) + 30_000) ==
               "P814_RECONSTRUCTED"

      assert Ash.get!(Identity.ReconciliationCase, applied.id, authorize?: false).version ==
               applied.version

      assert Ash.get!(NewYou.Audit.EvidenceObligation, obligation.id, authorize?: false).state ==
               :fulfilled
    end)
  end

  defp restart_output(port, output, deadline) do
    receive do
      {^port, {:data, bytes}} when byte_size(output) + byte_size(bytes) < 16_384 ->
        restart_output(port, output <> bytes, deadline)

      {^port, {:exit_status, 0}} ->
        output |> String.split("\n") |> Enum.find("", &String.starts_with?(&1, "P814_"))

      {^port, {:exit_status, _}} ->
        ""
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        Port.close(port)
        ""
    end
  end

  test "material rejection is terminal and records bounded E2 evidence" do
    with_case(fn f ->
      request = %{review_request(f) | decision: :rejected}
      assert {:ok, rejected} = Identity.review_reconciliation(request)
      assert rejected.status == :rejected

      assert [%{evidence_type: :identity_reconciliation_review, outcome: :denied}] =
               read(NewYou.Audit.EvidenceObligation, "case_id", rejected.id)

      assert {:error, :reconciliation_unavailable} =
               Identity.review_reconciliation(%{
                 request
                 | expected_version: rejected.version,
                   decision: :candidate
               })

      assert P805.account!(f.target.id).pmr_status == :active
    end)
  end

  test "an unreviewed new Domain blocks apply instead of assuming its consequences" do
    with_case(fn f ->
      previous = Application.fetch_env!(:new_you, :ash_domains)
      Application.put_env(:new_you, :ash_domains, previous ++ [UnreviewedProofDomain])

      try do
        assert {:error, :reconciliation_unavailable} = approve(f)
        assert P805.account!(f.target.id).pmr_status == :active
      after
        Application.put_env(:new_you, :ash_domains, previous)
      end
    end)
  end

  test "resource policies deny caller-supplied authority and expiry blocks the privileged action" do
    with_case(fn f ->
      assert {:error, _} = Ash.get(Identity.ReconciliationCase, f.case.id)

      assert {:error, _} =
               Ash.update(f.case, %{status: :candidate, history: [], expected_version: 0},
                 action: :record_review
               )

      NewYou.Repo.query!(
        "UPDATE sessions SET step_up_expires_at = now() - interval '1 second' WHERE id = $1",
        [Ecto.UUID.dump!(f.actor.credentials.session_id)]
      )

      assert {:error, :reconciliation_unavailable} =
               Identity.review_reconciliation(%{review_request(f) | decision: :candidate})

      assert P805.account!(f.target.id).pmr_status == :active
    end)
  end

  test "concurrent registration cannot allocate a PMR being retired by reconciliation" do
    alias NewYou.Proof.Scenario

    with_case(fn f ->
      {:ok, approved} = approve(f)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      request = apply_request(f, approved)
      scenario = Scenario.start()
      parent = self()
      reference = make_ref()

      try do
        {worker, monitor} =
          Scenario.spawn(scenario, :source, fn ->
            :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

            try do
              Process.put(NewYou.Proof.ReconciliationSeam, fn
                :before_source_commit ->
                  send(parent, {reference, :retiring, self()})

                  receive do
                    {^reference, :commit} -> :ok
                  after
                    10_000 -> raise "retirement deadline"
                  end

                _ ->
                  :ok
              end)

              send(parent, {reference, :applied, Identity.apply_reconciliation(request)})
            after
              Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
            end
          end)

        assert await(reference, :retiring) == worker
        Application.put_env(:new_you, :identity_pmr_generator, fn -> {:ok, f.old_pmr} end)
        assert {:error, _} = Identity.register(P805.request())
        send(worker, {reference, :commit})
        assert {:ok, %{status: :applied}} = await(reference, :applied)
        assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, 5_000
        assert P805.account!(f.target.id).pmr_status == :retired
        assert {:error, _} = Identity.register(P805.request())
      after
        Scenario.stop(scenario)
      end
    end)
  end

  defp with_case(callback) do
    P813HoldFixture.with_fixture(fn f ->
      survivor = P813HoldFixture.member()
      grant = P813HoldFixture.grant(f.actor, f.target, f.approver, :identity_reconciliation)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :review_reconciliation)

      {:ok, case_record} =
        Identity.open_reconciliation(%{
          credentials: f.actor.credentials,
          grant_id: grant.id,
          candidate_id: f.target.id,
          canonical_id: survivor.id,
          operation_id: Ecto.UUID.generate(),
          detection_basis: :verified_control
        })

      callback.(
        Map.merge(f, %{
          survivor: survivor,
          reconciliation_grant: grant,
          case: case_record,
          old_pmr: P805.account!(f.target.id).pmr
        })
      )
    end)
  end

  defp review_request(f) do
    %{
      credentials: f.actor.credentials,
      grant_id: f.reconciliation_grant.id,
      case_id: f.case.id,
      expected_version: f.case.version,
      controls: [f.target.credentials, f.survivor.credentials],
      decision: :approved
    }
  end

  defp approve(f) do
    request = review_request(f)
    {:ok, candidate} = Identity.review_reconciliation(%{request | decision: :candidate})

    {:ok, review} =
      Identity.review_reconciliation(%{
        request
        | expected_version: candidate.version,
          decision: :review
      })

    Identity.review_reconciliation(%{request | expected_version: review.version})
  end

  defp apply_request(f, record) do
    %{
      credentials: f.actor.credentials,
      grant_id: f.reconciliation_grant.id,
      case_id: record.id,
      expected_version: record.version,
      operation_id: Ecto.UUID.generate()
    }
  end

  defp admissions(id), do: read(NewYou.Audit.EvidenceRecord, "attempt_id", id)
  defp admissions_for_target(id), do: read(NewYou.Audit.EvidenceRecord, "target_id", id)
  defp outcomes(id), do: read(NewYou.Audit.EvidenceObligation, "source_operation_id", id)

  defp read(resource, field, value) do
    resource
    |> Ash.Query.filter(^[{String.to_existing_atom(field), value}])
    |> Ash.read!(authorize?: false)
  end
end
