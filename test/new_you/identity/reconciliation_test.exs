defmodule NewYou.Identity.ReconciliationTest do
  use ExUnit.Case, async: false
  import NewYou.Proof.ReconciliationScenarios
  alias NewYou.Identity
  alias NewYou.Proof.{FreshMix, P805, P813HoldFixture}

  test "scoped detection, verified review and apply preserve history and retire the losing PMR" do
    NewYou.Proof.ReconciliationScenarios.scenario_scoped_detection_verified_review_and_apply_preserve_history_and_retire_the_losing_pmr()
  end

  test "detection and demographic similarity cannot substitute for current verified control" do
    NewYou.Proof.ReconciliationScenarios.scenario_detection_and_demographic_similarity_cannot_substitute_for_current_verified_control()
  end

  test "loser-only and survivor-only grants cannot authorize the pair" do
    NewYou.Proof.ReconciliationScenarios.scenario_loser_only_and_survivor_only_grants_cannot_authorize_the_pair()
  end

  test "apply requires both current target grants before admitting E1" do
    NewYou.Proof.ReconciliationScenarios.scenario_apply_requires_both_current_target_grants_before_admitting_e1()
  end

  test "approved rejection preserves approval provenance and is terminal" do
    with_case(fn f ->
      {:ok, approved} = approve(f)

      assert {:error, _} =
               Ash.update(
                 approved,
                 %{
                   status: :review,
                   review: nil,
                   history: approved.history ++ [%{"status" => "review"}],
                   expected_version: approved.version
                 },
                 action: :record_review,
                 authorize?: false
               )

      assert {:ok, rejected} =
               Identity.review_reconciliation(%{
                 review_request(f)
                 | expected_version: approved.version,
                   decision: :rejected
               })

      assert List.last(rejected.history)["superseded_review"] == approved.review
      assert is_nil(rejected.review)

      assert {:error, :reconciliation_unavailable} =
               Identity.review_reconciliation(%{
                 review_request(f)
                 | expected_version: rejected.version,
                   decision: :review
               })
    end)
  end

  test "the pair-scope migration preserves legacy evidence while rejecting new incomplete admissions" do
    with_case(fn f ->
      {:ok, approved} = approve(f)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      request = apply_request(f, approved)
      assert {:ok, _} = Identity.apply_reconciliation(request)

      [[validated, expression]] =
        NewYou.Repo.query!(
          "SELECT convalidated, pg_get_expr(conbin, conrelid) FROM pg_constraint WHERE conname = 'evidence_records_assertion_shape'"
        ).rows

      refute validated

      assert {:error, :proof_complete} =
               NewYou.Repo.transaction(fn ->
                 NewYou.Repo.query!(
                   "CREATE TEMP TABLE well15_legacy_evidence (LIKE evidence_records INCLUDING DEFAULTS) ON COMMIT DROP"
                 )

                 NewYou.Repo.query!(
                   "INSERT INTO well15_legacy_evidence SELECT * FROM evidence_records WHERE attempt_id = $1",
                   [Ecto.UUID.dump!(request.operation_id)]
                 )

                 NewYou.Repo.query!(
                   "UPDATE well15_legacy_evidence SET canonical_grant_id = NULL, canonical_grant_version = NULL"
                 )

                 NewYou.Repo.query!(
                   "ALTER TABLE well15_legacy_evidence ADD CONSTRAINT pair_shape CHECK (" <>
                     expression <> ") NOT VALID"
                 )

                 assert [[1]] =
                          NewYou.Repo.query!("SELECT count(*) FROM well15_legacy_evidence").rows

                 assert_raise Postgrex.Error, fn ->
                   NewYou.Repo.query!(
                     "INSERT INTO well15_legacy_evidence SELECT * FROM well15_legacy_evidence"
                   )
                 end

                 NewYou.Repo.rollback(:proof_complete)
               end)
    end)
  end

  test "owner policies preserve pending message and Audit provenance while current delivery fails closed" do
    NewYou.Proof.ReconciliationScenarios.scenario_owner_policies_preserve_pending_message_and_audit_provenance_while_current_delivery_fails_closed()
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

  test "an approved case can invalidate its approval and obtain fresh review without losing provenance" do
    with_case(fn f ->
      {:ok, approved} = approve(f)
      request = %{review_request(f) | expected_version: approved.version, decision: :review}
      assert {:ok, reopened} = Identity.review_reconciliation(request)
      assert reopened.status == :review
      assert is_nil(reopened.review)
      assert List.last(reopened.history)["superseded_review"] == approved.review
      assert {:error, :reconciliation_unavailable} = Identity.review_reconciliation(request)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)

      assert {:error, :reconciliation_unavailable} =
               Identity.apply_reconciliation(apply_request(f, approved))

      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :review_reconciliation)

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

  @tag timeout: 60_000
  test "expired approval denies retries and a fresh BEAM reconstructs re-review recovery" do
    NewYou.Proof.ReconciliationScenarios.scenario_expired_approval_denies_retries_and_a_fresh_beam_reconstructs_re_review_recovery()
  end

  test "control evidence exactly five minutes old remains eligible" do
    with_case(fn f ->
      {:ok, approved} = approve(f)
      {:ok, checked_at, _} = DateTime.from_iso8601(hd(approved.review["controls"])["verified_at"])
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)

      Process.put(
        {NewYou.Proof.ReconciliationSeam, :control_time},
        DateTime.add(checked_at, 300_000_000, :microsecond)
      )

      try do
        assert {:ok, %{status: :applied}} =
                 Identity.apply_reconciliation(apply_request(f, approved))
      after
        Process.delete({NewYou.Proof.ReconciliationSeam, :control_time})
      end
    end)
  end

  test "control evidence older than exactly five minutes fails closed" do
    with_case(fn f ->
      {:ok, approved} = approve(f)
      {:ok, checked_at, _} = DateTime.from_iso8601(hd(approved.review["controls"])["verified_at"])
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)

      Process.put(
        {NewYou.Proof.ReconciliationSeam, :control_time},
        DateTime.add(checked_at, 300_000_001, :microsecond)
      )

      try do
        assert {:error, :reconciliation_unavailable} =
                 Identity.apply_reconciliation(apply_request(f, approved))
      after
        Process.delete({NewYou.Proof.ReconciliationSeam, :control_time})
      end
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

  for grant_key <- [:reconciliation_grant, :canonical_grant] do
    test "revocation of #{grant_key} after E1 blocks apply under fresh authority" do
      with_case(fn f ->
        {:ok, approved} = approve(f)
        {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
        request = apply_request(f, approved)

        Process.put(NewYou.Proof.ReconciliationSeam, fn
          :after_admission ->
            Ash.update!(
              Map.fetch!(f, unquote(grant_key)),
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
  end

  test "retired PMR and applied provenance cannot be revived or rewritten" do
    NewYou.Proof.ReconciliationScenarios.scenario_retired_pmr_and_applied_provenance_cannot_be_revived_or_rewritten()
  end

  test "compensating case changes the current canonical identity while preserving retired values and original decisions" do
    with_case(fn f ->
      {:ok, approved} = approve(f)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      {:ok, original} = Identity.apply_reconciliation(apply_request(f, approved))
      replacement = P813HoldFixture.member()
      grant = f.canonical_grant

      canonical_grant =
        P813HoldFixture.grant(f.actor, replacement, f.approver, :identity_reconciliation)

      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :review_reconciliation)

      {:ok, correction} =
        Identity.open_reconciliation(%{
          credentials: f.actor.credentials,
          grant_id: grant.id,
          canonical_grant_id: canonical_grant.id,
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
          reconciliation_grant: grant,
          canonical_grant: canonical_grant
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

            canonical_grant =
              P813HoldFixture.grant(second_actor, f.target, f.approver, :identity_reconciliation)

            {:ok, reverse} =
              Identity.open_reconciliation(%{
                credentials: second_actor.credentials,
                grant_id: grant.id,
                canonical_grant_id: canonical_grant.id,
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
                reconciliation_grant: grant,
                canonical_grant: canonical_grant
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

        if unquote(mode) == :overlapping_cases do
          {:ok, :ok} = P813HoldFixture.step_up(second_fixture.actor, :review_reconciliation)

          assert {:ok, %{status: :rejected}} =
                   Identity.review_reconciliation(%{
                     review_request(second_fixture)
                     | expected_version: second_case.version,
                       decision: :rejected
                   })
        end
      end)
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

      {executable, arguments} = FreshMix.command(["run", "test/proof/p8_14_restart.exs"])

      assert %{status: :ok, marker: :p814_reconstructed, cleanup: :confirmed} =
               NewYou.Proof.P815Port.run(executable, arguments, Jason.encode!(input))

      assert Ash.get!(Identity.ReconciliationCase, applied.id, authorize?: false).version ==
               applied.version

      assert Ash.get!(NewYou.Audit.EvidenceObligation, obligation.id, authorize?: false).state ==
               :fulfilled
    end)
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

  @tag timeout: 60_000
  test "Commerce history committed on another connection invalidates the empty owner review" do
    with_case(fn f ->
      {:ok, approved} = approve(f)
      reviews = approved.review["domains"]

      for {owner, policy} <- [
            {"commerce", "empty_commerce_scope"},
            {"entitlements", "empty_entitlements_scope"}
          ] do
        assert reviews[owner] == %{
                 "policy" => policy,
                 "candidate_id" => f.target.id,
                 "canonical_id" => f.survivor.id,
                 "commands" => []
               }
      end

      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)

      task =
        Task.async(fn ->
          receive do: (:start -> :ok)
          :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo, sandbox: false)

          NewYou.Commerce.accept_plan_purchase(f.target.credentials, %{
            operation_id: operation_id,
            price_version: "synthetic-plan-v1"
          })
        end)

      :ok = P805.register_cleanup_worker(task.pid)
      send(task.pid, :start)

      assert {:ok, purchase} = Task.await(task)
      assert purchase.payer_id == f.target.id

      evidence =
        NewYou.Proof.PlanPaymentObservation.produce(%{
          attempt_id: purchase.attempt_id,
          purchase_id: purchase.id,
          amount_minor: 39_900,
          currency: "ZAR",
          environment: :test,
          integration: :synthetic,
          status: :succeeded
        })

      assert {:ok, payment} = NewYou.Commerce.apply_payment_observation(evidence)
      assert {:ok, [consequence_id]} = NewYou.Commerce.open_plan_payment_consequences(purchase.id)
      assert :ok = NewYou.Privacy.SyntheticSuppression.register(f.target.credentials)
      assert {:ok, right} = NewYou.Entitlements.grant_paid_plan(consequence_id)
      assert {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      request = apply_request(f, approved)

      assert {:error, :reconciliation_unavailable} = Identity.apply_reconciliation(request)
      assert {:ok, :ok} = P813HoldFixture.step_up(f.actor, :review_reconciliation)
      review = review_request(f)

      assert {:ok, reopened} =
               Identity.review_reconciliation(%{
                 review
                 | expected_version: approved.version,
                   decision: :review
               })

      assert {:error, :reconciliation_unavailable} =
               Identity.review_reconciliation(%{review | expected_version: reopened.version})

      assert {:ok, conflict} =
               Identity.review_reconciliation(%{
                 review
                 | expected_version: reopened.version,
                   decision: :conflict
               })

      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      assert_conflict_after_restart(apply_request(f, conflict))

      assert P805.account!(f.target.id).pmr_status == :active
      assert P805.account!(f.survivor.id).pmr_status == :active
      assert {:ok, [persisted_right]} = NewYou.Entitlements.plan_rights(f.target.credentials)
      assert persisted_right.id == right.id
      assert persisted_right.purchase_id == purchase.id
      assert persisted_right.payment_id == payment.id
      assert persisted_right.recipient_id == f.target.id
      assert persisted_right.state == :held_unconsumed

      assert {:ok, [^consequence_id]} =
               NewYou.Commerce.open_plan_payment_consequences(purchase.id)

      persisted_purchase = Ash.get!(NewYou.Commerce.Purchase, purchase.id, authorize?: false)
      assert persisted_purchase.payer_id == f.target.id
      assert persisted_purchase.attempt_id == purchase.attempt_id

      assert Ash.get!(NewYou.Commerce.VerifiedPayment, payment.id, authorize?: false).purchase_id ==
               purchase.id

      refute Enum.any?(outcomes(request.operation_id), &(&1.outcome == :succeeded))
    end)
  end

  test "a missing Commerce or Entitlements owner prevents reconciliation approval" do
    with_case(fn f ->
      domains = Application.fetch_env!(:new_you, :ash_domains)
      request = review_request(f)
      {:ok, candidate} = Identity.review_reconciliation(%{request | decision: :candidate})

      {:ok, review} =
        Identity.review_reconciliation(%{
          request
          | expected_version: candidate.version,
            decision: :review
        })

      request = %{request | expected_version: review.version}

      try do
        for missing <- [NewYou.Commerce, NewYou.Entitlements] do
          Application.put_env(:new_you, :ash_domains, List.delete(domains, missing))
          assert {:error, :reconciliation_unavailable} = Identity.review_reconciliation(request)
          assert P805.account!(f.target.id).pmr_status == :active
        end
      after
        Application.put_env(:new_you, :ash_domains, domains)
      end

      assert {:ok, %{status: :approved}} = Identity.review_reconciliation(request)
    end)
  end

  test "an unapplied legacy owner snapshot is denied until a fresh review succeeds" do
    with_case(fn f ->
      {:ok, original} = approve(f)
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :review_reconciliation)
      review = review_request(f)

      assert {:ok, reopened} =
               Identity.review_reconciliation(%{
                 review
                 | expected_version: original.version,
                   decision: :review
               })

      legacy_review =
        Map.update!(original.review, "domains", &Map.drop(&1, ["commerce", "entitlements"]))

      # Create the historical snapshot through the private fixture action, while
      # retaining the database's normal review transition and immutable history guard.
      assert {:ok, legacy} =
               Ash.update(
                 reopened,
                 %{
                   status: :approved,
                   review: legacy_review,
                   history: reopened.history ++ [%{"status" => "approved"}],
                   expected_version: reopened.version
                 },
                 action: :record_review,
                 authorize?: false
               )

      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)
      request = apply_request(f, legacy)
      assert {:error, :reconciliation_unavailable} = Identity.apply_reconciliation(request)
      assert admissions(request.operation_id) == []
      assert P805.account!(f.target.id).pmr_status == :active

      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :review_reconciliation)

      assert {:ok, new_review} =
               Identity.review_reconciliation(%{
                 review
                 | expected_version: legacy.version,
                   decision: :review
               })

      assert {:ok, refreshed} =
               Identity.review_reconciliation(%{review | expected_version: new_review.version})

      assert Map.has_key?(refreshed.review["domains"], "commerce")
      assert Map.has_key?(refreshed.review["domains"], "entitlements")
      {:ok, :ok} = P813HoldFixture.step_up(f.actor, :apply_reconciliation)

      assert {:ok, %{status: :applied}} =
               Identity.apply_reconciliation(apply_request(f, refreshed))
    end)
  end

  defp assert_conflict_after_restart(request) do
    input = %{
      mode: "deny_conflict",
      request: request,
      signing_secret:
        Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))
    }

    {executable, arguments} = FreshMix.command(["run", "test/proof/p8_14_restart.exs"])

    assert %{status: :ok, marker: :p814_conflict_denied, cleanup: :confirmed} =
             NewYou.Proof.P815Port.run(executable, arguments, Jason.encode!(input))
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
    NewYou.Proof.ReconciliationScenarios.scenario_concurrent_registration_cannot_allocate_a_pmr_being_retired_by_reconciliation()
  end
end
