defmodule NewYou.Proof.ReconciliationScenarios do
  @moduledoc false

  import ExUnit.Assertions

  alias NewYou.Identity

  require Ash.Query

  alias NewYou.Proof.{P805, P813HoldFixture}

  def scenario_scoped_detection_verified_review_and_apply_preserve_history_and_retire_the_losing_pmr() do
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
      assert admission.canonical_grant_id == f.canonical_grant.id
      assert admission.canonical_grant_version == f.canonical_grant.version
      assert [%{admission_id: admission_id, outcome: :succeeded}] = outcomes(request.operation_id)
      assert admission_id == admission.id
    end)
  end

  def scenario_detection_and_demographic_similarity_cannot_substitute_for_current_verified_control() do
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

  def scenario_loser_only_and_survivor_only_grants_cannot_authorize_the_pair() do
    with_case(fn f ->
      assert {:error, :reconciliation_unavailable} =
               Identity.review_reconciliation(
                 review_request(f)
                 |> Map.delete(:canonical_grant_id)
                 |> Map.put(:decision, :candidate)
               )

      assert {:error, :reconciliation_unavailable} =
               Identity.review_reconciliation(%{
                 review_request(f)
                 | grant_id: f.canonical_grant.id,
                   decision: :candidate
               })

      request = review_request(f) |> Map.put(:canonical_grant_id, f.reconciliation_grant.id)

      assert {:error, :reconciliation_unavailable} =
               Identity.review_reconciliation(%{request | decision: :candidate})

      assert P805.account!(f.target.id).pmr_status == :active
      assert P805.account!(f.survivor.id).reconciliation_version == 0
    end)
  end

  def scenario_apply_requires_both_current_target_grants_before_admitting_e1() do
    with_case(fn f ->
      {:ok, approved} = approve(f)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      request = apply_request(f, approved)

      for invalid <- [
            Map.delete(request, :canonical_grant_id),
            %{request | canonical_grant_id: f.reconciliation_grant.id},
            %{request | grant_id: f.canonical_grant.id},
            %{request | canonical_grant_id: f.grants.review.id}
          ] do
        assert {:error, :reconciliation_unavailable} = Identity.apply_reconciliation(invalid)
      end

      assert admissions(request.operation_id) == []
      assert outcomes(request.operation_id) == []
      assert P805.account!(f.target.id).pmr_status == :active
      assert P805.account!(f.survivor.id).reconciliation_version == 0
    end)
  end

  def scenario_owner_policies_preserve_pending_message_and_audit_provenance_while_current_delivery_fails_closed() do
    with_case(fn f ->
      accounts = Enum.map([f.target, f.survivor], &P805.account!(&1.id))

      Enum.each(accounts, fn account ->
        operation = Ecto.UUID.generate()
        P805.track_operation(operation)
        assert :ok = Identity.request_magic_login(to_string(account.email), "af", operation)
      end)

      destinations = Enum.map(accounts, &to_string(&1.email))

      intents =
        NewYou.Communications.MessageIntent
        |> Ash.Query.filter(destination in ^destinations)
        |> Ash.read!(authorize?: false)

      assert Enum.sort(Enum.uniq(Enum.map(intents, & &1.role))) == [
               :account_verification,
               :magic_login
             ]

      loser_magic =
        Enum.find(
          intents,
          &(&1.role == :magic_login and &1.destination == to_string(hd(accounts).email))
        )

      assert {:ok, {:ok, _}} =
               Ash.transact([Identity.Account, Identity.Token], fn ->
                 Identity.magic_login_delivery(
                   loser_magic.source_reference,
                   loser_magic.destination,
                   "af"
                 )
               end)

      operations =
        Identity.RegistrationOperation
        |> Ash.Query.filter(created_account_id in ^Enum.map(accounts, & &1.id))
        |> Ash.read!(authorize?: false)

      obligations =
        Enum.flat_map(
          operations,
          &read(NewYou.Audit.EvidenceObligation, "source_operation_id", &1.operation_id)
        )

      assert length(obligations) == 2

      Enum.each(obligations, fn obligation ->
        assert {:ok, _} =
                 NewYou.Audit.materialize_registration_evidence(
                   %{primary_key: %{id: obligation.id}},
                   authorize?: false
                 )
      end)

      evidence =
        Enum.flat_map(obligations, &read(NewYou.Audit.EvidenceRecord, "obligation_id", &1.id))

      assert length(evidence) == 2
      {:ok, approved} = approve(f)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      assert {:ok, _} = Identity.apply_reconciliation(apply_request(f, approved))
      Process.put(:p810_provider, fn _, _ -> flunk("retired Identity invoked provider") end)

      try do
        Enum.each(intents, fn intent ->
          current = Ash.get!(NewYou.Communications.MessageIntent, intent.id, authorize?: false)
          assert current.source_operation_id == intent.source_operation_id
          assert current.source_reference == intent.source_reference
          assert current.destination == intent.destination

          if current.destination == loser_magic.destination do
            assert {:ok, :source_invalid} = NewYou.Communications.execute(current.id)
            assert {:ok, :closed} = NewYou.Communications.execute(current.id)

            assert read(NewYou.Communications.DeliveryAttempt, "message_intent_id", current.id) ==
                     []
          end
        end)
      after
        Process.delete(:p810_provider)
      end

      assert Enum.flat_map(
               obligations,
               &read(NewYou.Audit.EvidenceRecord, "obligation_id", &1.id)
             ) == evidence

      Enum.each(obligations, fn original ->
        current = Ash.get!(NewYou.Audit.EvidenceObligation, original.id, authorize?: false)
        assert current.source_operation_id == original.source_operation_id
      end)
    end)
  end

  def scenario_expired_approval_denies_retries_and_a_fresh_beam_reconstructs_re_review_recovery() do
    with_case(fn f ->
      Process.put(
        {NewYou.Proof.ReconciliationSeam, :control_time},
        DateTime.add(DateTime.utc_now(), -301, :second)
      )

      approved =
        try do
          {:ok, record} = approve(f)
          record
        after
          Process.delete({NewYou.Proof.ReconciliationSeam, :control_time})
        end

      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      stale_request = apply_request(f, approved)

      for _ <- 1..2 do
        assert {:error, :reconciliation_unavailable} =
                 Identity.apply_reconciliation(stale_request)
      end

      assert admissions(stale_request.operation_id) == []
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :review_reconciliation)

      input = %{
        mode: "recover_review",
        request: %{review_request(f) | expected_version: approved.version, decision: :review},
        signing_secret:
          Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))
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
               "P814_REVIEW_RECOVERED"

      reopened = Ash.get!(Identity.ReconciliationCase, approved.id, authorize?: false)
      assert reopened.status == :review
      assert List.last(reopened.history)["superseded_review"] == approved.review

      assert {:ok, refreshed} =
               Identity.review_reconciliation(%{
                 review_request(f)
                 | expected_version: reopened.version
               })

      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)

      assert {:ok, %{status: :applied}} =
               Identity.apply_reconciliation(apply_request(f, refreshed))
    end)
  end

  def scenario_retired_pmr_and_applied_provenance_cannot_be_revived_or_rewritten() do
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

  def scenario_concurrent_registration_cannot_allocate_a_pmr_being_retired_by_reconciliation() do
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

  def race(first_request, second_request) do
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

  def race_worker(parent, reference, label, request) do
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

  def await(reference, phase) do
    receive do
      {^reference, ^phase, value} -> value
    after
      35_000 -> raise "reconciliation proof deadline"
    end
  end

  def blocked?(blocker, blocked, deadline) do
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

  def restart_output(port, output, deadline) do
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

  def with_case(callback) do
    P813HoldFixture.with_fixture(fn f ->
      survivor = P813HoldFixture.member()
      grant = P813HoldFixture.grant(f.actor, f.target, f.approver, :identity_reconciliation)

      canonical_grant =
        P813HoldFixture.grant(f.actor, survivor, f.approver, :identity_reconciliation)

      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :review_reconciliation)

      {:ok, case_record} =
        Identity.open_reconciliation(%{
          credentials: f.actor.credentials,
          grant_id: grant.id,
          canonical_grant_id: canonical_grant.id,
          candidate_id: f.target.id,
          canonical_id: survivor.id,
          operation_id: Ecto.UUID.generate(),
          detection_basis: :verified_control
        })

      callback.(
        Map.merge(f, %{
          survivor: survivor,
          reconciliation_grant: grant,
          canonical_grant: canonical_grant,
          case: case_record,
          old_pmr: P805.account!(f.target.id).pmr
        })
      )
    end)
  end

  def review_request(f) do
    %{
      credentials: f.actor.credentials,
      grant_id: f.reconciliation_grant.id,
      canonical_grant_id: f.canonical_grant.id,
      case_id: f.case.id,
      expected_version: f.case.version,
      controls: [f.target.credentials, f.survivor.credentials],
      decision: :approved
    }
  end

  def approve(f) do
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

  def apply_request(f, record) do
    %{
      credentials: f.actor.credentials,
      grant_id: f.reconciliation_grant.id,
      canonical_grant_id: f.canonical_grant.id,
      case_id: record.id,
      expected_version: record.version,
      operation_id: Ecto.UUID.generate()
    }
  end

  def admissions(id), do: read(NewYou.Audit.EvidenceRecord, "attempt_id", id)

  def admissions_for_target(id), do: read(NewYou.Audit.EvidenceRecord, "target_id", id)

  def outcomes(id), do: read(NewYou.Audit.EvidenceObligation, "source_operation_id", id)

  def read(resource, field, value) do
    resource
    |> Ash.Query.filter(^[{String.to_existing_atom(field), value}])
    |> Ash.read!(authorize?: false)
  end
end
