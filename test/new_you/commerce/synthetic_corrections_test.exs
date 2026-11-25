defmodule NewYou.Commerce.SyntheticCorrectionsTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Commerce, Entitlements, Identity, Repo}
  alias NewYou.Commerce.{SyntheticCorrection, SyntheticCorrections, SyntheticExcessClaim}
  alias NewYou.Commerce.{SyntheticCorrectionReceipt, SyntheticOrder}
  alias NewYou.Entitlements.PlanRight
  alias NewYou.Entitlements.SyntheticRights
  alias NewYou.Privacy.SyntheticSuppression
  alias NewYou.Proof.{P805, PlanPaymentObservation}
  require Ash.Query

  test "the authorized payer keeps the exact excess claim on one intended purchase" do
    P805.with_fixture(fn ->
      payer = verified_session()
      recipient = verified_session()
      foreign = verified_session()
      admission = admission(payer, recipient)

      assert {:error, :source_unavailable} =
               SyntheticCorrections.accept(foreign.credentials, recipient.credentials, admission)

      assert {:ok, source} =
               SyntheticCorrections.accept(payer.credentials, recipient.credentials, admission)

      assert {:ok, %{id: replayed_id}} =
               SyntheticCorrections.accept(payer.credentials, recipient.credentials, admission)

      assert replayed_id == source.id

      assert {:error, :commerce_scope_unavailable} =
               Commerce.review_identity_reconciliation(payer.id, foreign.id)

      assert {:error, :commerce_scope_unavailable} =
               Commerce.review_identity_reconciliation(recipient.id, foreign.id)

      changed = PlanPaymentObservation.produce(%{admission.fields | recipient_id: foreign.id})

      assert {:error, :source_unavailable} =
               SyntheticCorrections.accept(payer.credentials, foreign.credentials, changed)

      original = collection(source)
      second = collection(source)
      assert {:ok, %{id: application_id}} = SyntheticCorrections.observe_collection(original)
      assert {:ok, %{id: ^application_id}} = SyntheticCorrections.observe_collection(second)
      assert {:ok, %{id: ^application_id}} = SyntheticCorrections.observe_collection(original)

      claimant = payer.id
      excess_collection = second.fields.collection_id

      assert [[^claimant, ^excess_collection, 5_100, "ZAR", nil]] = claims(source)
      refute claimant == recipient.id

      assert {:ok, independent} =
               SyntheticCorrections.accept(
                 payer.credentials,
                 recipient.credentials,
                 admission(payer, recipient)
               )

      assert independent.id != source.id

      assert {:ok, %{id: independent_payment}} =
               SyntheticCorrections.observe_collection(collection(independent))

      refute independent_payment == application_id
      assert claims(independent) == []
    end)
  end

  test "bundle collection receipts are immutable across observations and accepted sources" do
    P805.with_fixture(fn ->
      payer = verified_session()
      recipient = verified_session()
      source = accept_fixture(payer, recipient)
      independent = accept_fixture(payer, recipient)
      original = collection(source)
      receipt_id = original.fields.receipt_id
      assert {:ok, %{id: applied}} = SyntheticCorrections.observe_collection(original)

      for changed_source <- [source, independent] do
        changed = collection(changed_source, receipt_id: receipt_id)
        assert {:error, :payment_unavailable} = SyntheticCorrections.observe_collection(changed)
        assert claims(changed_source) == []
      end

      assert {:ok, %{id: ^applied}} = SyntheticCorrections.observe_collection(original)
      another_receipt = collection(source, collection_id: applied)
      assert {:ok, %{id: ^applied}} = SyntheticCorrections.observe_collection(another_receipt)
      assert claims(source) == []
      assert collection_count(source.id) == 1
      assert collection_count(independent.id) == 0

      assert {:ok, %{id: other}} =
               SyntheticCorrections.observe_collection(collection(independent))

      refute other == applied
    end)
  end

  test "failed bundle receipt binding rolls back the proposed excess collection and claim" do
    P805.with_fixture(fn ->
      payer = verified_session()
      recipient = verified_session()
      source = accept_fixture(payer, recipient)
      assert {:ok, %{id: payment}} = SyntheticCorrections.observe_collection(collection(source))
      excess = collection(source)

      P805.with_rejected_insert("commerce_synthetic_collection_receipts", fn reached? ->
        assert {:error, :payment_unavailable} = SyntheticCorrections.observe_collection(excess)
        assert reached?.()
      end)

      assert collection_count(source.id) == 1
      assert claims(source) == []
      assert {:ok, %{id: ^payment}} = SyntheticCorrections.observe_collection(excess)
      assert collection_count(source.id) == 2
      assert [[_, _, 5_100, "ZAR", nil]] = claims(source)
    end)
  end

  test "the receipt primary key arbitrates conflicting evidence across independent sources" do
    P805.with_fixture(fn ->
      payer = verified_session()
      recipient = verified_session()
      source = accept_fixture(payer, recipient)
      independent = accept_fixture(payer, recipient)
      assert {:ok, %{id: payment}} = SyntheticCorrections.observe_collection(collection(source))
      assert {:ok, _} = SyntheticCorrections.observe_collection(collection(independent))
      accepted = collection(source)
      conflict = collection(independent, receipt_id: accepted.fields.receipt_id)
      parent = self()

      first =
        race_worker(parent, :first, fn ->
          Ash.transact(SyntheticExcessClaim, fn ->
            {:ok, result} = SyntheticCorrections.observe_collection(accepted)
            send(parent, :receipt_bound)
            await(:commit)
            result
          end)
        end)

      second =
        race_worker(parent, :second, fn -> SyntheticCorrections.observe_collection(conflict) end)

      try do
        assert_receive {:first, backend_one}, 5_000
        assert_receive {:second, backend_two}, 5_000
        refute backend_one == backend_two
        send(first.pid, :run)
        assert_receive :receipt_bound, 5_000
        send(second.pid, :run)
        assert blocked_by?(backend_two, backend_one, 100)
        assert collection_count(source.id) == 1
        assert collection_count(independent.id) == 1
        assert claims(source) == []
        assert claims(independent) == []
        send(first.pid, :commit)
        assert {:ok, %{id: ^payment}} = Task.await(first)
        assert {:error, :payment_unavailable} = Task.await(second)
      after
        finish_race([first, second])
      end

      assert {:ok, %{id: ^payment}} = SyntheticCorrections.observe_collection(accepted)
      assert [[_, _, 5_100, "ZAR", nil]] = claims(source)
      assert claims(independent) == []
      assert collection_count(source.id) == 2
      assert collection_count(independent.id) == 1
    end)
  end

  test "only the frozen authorized component ends, and an original grant cannot revive it" do
    P805.with_fixture(fn ->
      payer = verified_session()
      recipient = verified_session()
      source = accept_fixture(payer, recipient)
      independent = accept_fixture(payer, recipient)
      assert :ok = SyntheticSuppression.register(recipient.credentials)
      original = collection(source)
      assert {:ok, %{id: payment}} = SyntheticCorrections.observe_collection(original)
      assert {:ok, _} = SyntheticCorrections.observe_collection(collection(independent))
      assert {:ok, _} = SyntheticRights.converge(independent.id)

      # The later synthetic catalogue makes the incorrect component appear to
      # match the exact money, while the accepted snapshot still controls.
      assert {:ok, repriced} =
               SyntheticCorrections.accept(
                 payer.credentials,
                 recipient.credentials,
                 reprice(admission(payer, recipient), 1_600, 3_500)
               )

      assert repriced.plan_list_minor == 1_600

      assert {:ok, [%{component: :assessment}, %{component: :plan}]} =
               SyntheticRights.converge(source.id)

      assert {:ok, %{kind: :unresolved}} =
               SyntheticCorrections.observe_correction(
                 correction(source, payment, %{component: :plan, amount_minor: 1_600})
               )

      assert {:ok, []} = SyntheticCorrections.open_consequences(source.id)
      assert Enum.all?(right_states(source), fn [_, state] -> state == "held_unconsumed" end)

      exact = correction(source, payment, %{component: :plan, amount_minor: 3_500})

      assert {:ok, %{id: effect, kind: :component_end}} =
               SyntheticCorrections.observe_correction(exact)

      equivalent = correction(source, payment, %{component: :plan, amount_minor: 3_500})
      assert {:ok, %{id: ^effect}} = SyntheticCorrections.observe_correction(equivalent)

      changed =
        PlanPaymentObservation.produce(%{
          equivalent.fields
          | component: :assessment,
            amount_minor: 1_600
        })

      assert {:error, :correction_unavailable} = SyntheticCorrections.observe_correction(changed)

      assert {:ok, [^effect]} = SyntheticCorrections.open_consequences(source.id)
      assert {:ok, _} = SyntheticCorrections.deliver(effect)
      assert {:ok, %{id: ^payment}} = SyntheticCorrections.observe_collection(original)
      assert {:ok, %{id: ^effect}} = SyntheticCorrections.observe_correction(exact)
      assert {:ok, _} = SyntheticRights.converge(source.id)
      assert {:ok, []} = SyntheticCorrections.open_consequences(source.id)
      assert right_states(source) == [["assessment", "held_unconsumed"], ["plan", "ended"]]

      assert right_states(independent) == [
               ["assessment", "held_unconsumed"],
               ["plan", "held_unconsumed"]
             ]
    end)
  end

  test "late payment and correction retain only commercial evidence after suppression" do
    P805.with_fixture(fn ->
      payer = verified_session()
      recipient = verified_session()
      source = accept_fixture(payer, recipient)
      original = collection(source)
      late_source = accept_fixture(payer, recipient)
      assert {:ok, %{id: payment}} = SyntheticCorrections.observe_collection(original)
      assert {:error, :grant_unavailable} = SyntheticRights.converge(source.id)
      assert right_states(source) == []

      assert :ok = SyntheticSuppression.register(recipient.credentials)
      assert :ok = SyntheticSuppression.suppress(completed_deletion(recipient))
      assert :ok = SyntheticSuppression.register(recipient.credentials)
      assert {:ok, _} = SyntheticCorrections.observe_collection(collection(late_source))
      assert {:ok, []} = SyntheticRights.converge(late_source.id)
      assert right_states(late_source) == []
      excess = collection(source)
      assert {:ok, %{id: ^payment}} = SyntheticCorrections.observe_collection(excess)

      assert {:ok, %{id: effect}} =
               SyntheticCorrections.observe_correction(
                 correction(source, payment, %{component: :plan, amount_minor: 3_500})
               )

      assert_correction_job_absent(effect)
      fresh_vm!("deliver", source.id)
      assert {:ok, %{id: ^payment}} = SyntheticCorrections.observe_collection(original)
      assert {:ok, []} = SyntheticRights.converge(source.id)
      assert {:ok, []} = Entitlements.plan_rights(recipient.credentials)
      assert {:ok, []} = SyntheticCorrections.open_consequences(source.id)
      assert right_states(source) == []

      claimant = payer.id
      excess_id = excess.fields.collection_id
      assert [[^claimant, ^excess_id, 5_100, "ZAR", nil]] = claims(source)
    end)
  end

  test "a fresh BEAM recovers the exact pending consequence on both sides of the Entitlements cut" do
    P805.with_fixture(fn ->
      payer = verified_session()
      recipient = verified_session()
      source = accept_fixture(payer, recipient)
      assert :ok = SyntheticSuppression.register(recipient.credentials)
      assert {:ok, %{id: payment}} = SyntheticCorrections.observe_collection(collection(source))
      excess = collection(source)
      assert {:ok, %{id: ^payment}} = SyntheticCorrections.observe_collection(excess)
      assert {:ok, _} = SyntheticRights.converge(source.id)
      receipt = correction(source, payment, %{component: :plan, amount_minor: 3_500})
      parent = self()

      {pid, monitor} =
        spawn_monitor(fn ->
          :ok = Sandbox.checkout(Repo, sandbox: false)

          Ash.transact(SyntheticCorrection, fn ->
            {:ok, %{id: uncommitted}} = SyntheticCorrections.observe_correction(receipt)
            send(parent, {:uncommitted, uncommitted})

            receive do
              :commit -> :ok
            end
          end)
        end)

      try do
        assert_receive {:uncommitted, _}, 5_000
        assert {:ok, []} = SyntheticCorrections.open_consequences(source.id)
      after
        Process.exit(pid, :kill)
        assert_receive {:DOWN, ^monitor, :process, ^pid, :killed}, 5_000
      end

      assert {:ok, %{id: effect}} = SyntheticCorrections.observe_correction(receipt)
      assert {:ok, [^effect]} = SyntheticCorrections.open_consequences(source.id)
      assert_correction_job_absent(effect)
      claimant = payer.id
      excess_id = excess.fields.collection_id
      assert [[^claimant, ^excess_id, 5_100, "ZAR", nil]] = claims(source)

      assert right_states(source) == [
               ["assessment", "held_unconsumed"],
               ["plan", "held_unconsumed"]
             ]

      recover_while_source_is_locked(source.id)
      assert right_states(source) == [["assessment", "held_unconsumed"], ["plan", "ended"]]
      assert {:ok, [^effect]} = SyntheticCorrections.open_consequences(source.id)
      assert_correction_job_absent(effect)
      fresh_vm!("deliver", source.id)
      assert {:ok, []} = SyntheticCorrections.open_consequences(source.id)
      committed = Ash.get!(SyntheticCorrection, effect, authorize?: false)
      assert committed.component == :plan
      assert committed.amount_minor == 3_500
      assert committed.acknowledged_at
      fresh_vm!("replay", source.id)
      replayed = Ash.get!(SyntheticCorrection, effect, authorize?: false)
      assert replayed.acknowledged_at == committed.acknowledged_at
      assert [[^claimant, ^excess_id, 5_100, "ZAR", nil]] = claims(source)
      assert right_states(source) == [["assessment", "held_unconsumed"], ["plan", "ended"]]
    end)
  end

  test "a suppressed component is ended before acknowledgement, including after failed delivery" do
    P805.with_fixture(fn ->
      fixture = paid_correction_sources()
      %{source: source, independent: independent, payer: payer, recipient: recipient} = fixture
      [assessment, plan] = fixture.rights
      claim = [[payer.id, fixture.excess, 5_100, "ZAR", nil]]
      assert claims(source) == claim
      assert :ok = SyntheticSuppression.suppress(completed_deletion(recipient))
      assert {:ok, []} = Entitlements.plan_rights(recipient.credentials)

      refund = correction(source, fixture.payment, %{component: :plan, amount_minor: 3_500})

      assert {:ok, %{id: effect, kind: :component_end}} =
               SyntheticCorrections.observe_correction(refund)

      assert_suppressed_delivery_waits_for_update(effect, plan.id)
      assert %PlanRight{state: :held_unconsumed} = Ash.get!(PlanRight, plan.id, authorize?: false)

      assert %SyntheticCorrection{acknowledged_at: nil} =
               Ash.get!(SyntheticCorrection, effect, authorize?: false)

      assert {:ok, [^effect]} = SyntheticCorrections.open_consequences(source.id)
      assert claims(source) == claim

      fresh_vm!("apply", source.id)
      assert %PlanRight{state: :ended} = Ash.get!(PlanRight, plan.id, authorize?: false)
      assert {:ok, [^effect]} = SyntheticCorrections.open_consequences(source.id)

      fresh_vm!("deliver", source.id)

      assert %SyntheticCorrection{acknowledged_at: acknowledged_at} =
               Ash.get!(SyntheticCorrection, effect, authorize?: false)

      assert acknowledged_at
      assert {:ok, []} = SyntheticCorrections.open_consequences(source.id)
      assert {:ok, %{id: ^effect}} = SyntheticCorrections.observe_correction(refund)
      assert {:ok, %{acknowledged_at: ^acknowledged_at}} = SyntheticCorrections.deliver(effect)
      assert {:ok, []} = SyntheticRights.converge(source.id)
      assert {:ok, []} = Entitlements.plan_rights(recipient.credentials)

      assert %PlanRight{state: :held_unconsumed} =
               Ash.get!(PlanRight, assessment.id, authorize?: false)

      assert right_states(source) == [["assessment", "held_unconsumed"], ["plan", "ended"]]
      assert_unchanged_rights(fixture.independent_rights)

      assert right_states(independent) == [
               ["assessment", "held_unconsumed"],
               ["plan", "held_unconsumed"]
             ]

      assert claims(source) == claim
      assert claims(independent) == []
      assert collection_count(source.id) == 2
      assert {:ok, %{id: payment}} = SyntheticCorrections.observe_collection(fixture.original)
      assert payment == fixture.payment
    end)
  end

  test "qualified but unattributable correction receipts remain unresolved for both effect kinds" do
    P805.with_fixture(fn ->
      fixture = paid_correction_sources()

      mismatches = [
        status: :pending,
        status: :unknown,
        payer_id: fixture.recipient.id,
        recipient_id: fixture.payer.id,
        price_version: "synthetic-bundle-v2",
        currency: "USD",
        collection_id: fixture.independent_payment
      ]

      for control <- final_correction_controls(fixture), {field, value} <- mismatches do
        receipt =
          PlanPaymentObservation.produce(
            control.fields
            |> Map.put(:receipt_id, Ecto.UUID.generate())
            |> Map.put(field, value)
          )

        assert_unresolved_receipt(receipt, fixture.source.id)
      end

      count = 2 * length(mismatches)
      assert correction_counts(fixture.source.id) == {count, count}
      assert_no_correction_effects(fixture)
      assert_final_controls(fixture)
    end)
  end

  test "forged and unbound correction receipts persist neither a disposition nor a binding" do
    P805.with_fixture(fn ->
      fixture = paid_correction_sources()
      unknown_source = Ecto.UUID.generate()

      for control <- final_correction_controls(fixture) do
        forged = %{control | signature: corrupt_signature(control.signature)}

        unbound =
          for overrides <- [
                %{source_id: unknown_source},
                %{source_id: fixture.independent.id},
                %{operation_id: fixture.independent.operation_id},
                %{operation_id: Ecto.UUID.generate()}
              ] do
            PlanPaymentObservation.produce(
              control.fields
              |> Map.put(:receipt_id, Ecto.UUID.generate())
              |> Map.merge(overrides)
            )
          end

        Enum.each([forged | unbound], &assert_rejected_receipt/1)
      end

      assert correction_counts(unknown_source) == {0, 0}
      assert correction_counts(fixture.source.id) == {0, 0}
      assert_no_correction_effects(fixture)
      assert_final_controls(fixture)
    end)
  end

  test "independent SQL transactions contend and converge on one owed claim" do
    P805.with_fixture(fn ->
      payer = verified_session()
      recipient = verified_session()
      source = accept_fixture(payer, recipient)
      assert :ok = SyntheticSuppression.register(recipient.credentials)
      assert {:ok, %{id: payment}} = SyntheticCorrections.observe_collection(collection(source))
      assert {:ok, _} = SyntheticRights.converge(source.id)
      request = collection(source)
      parent = self()

      first =
        race_worker(parent, :first, fn ->
          Ash.transact(SyntheticExcessClaim, fn ->
            {:ok, result} = SyntheticCorrections.observe_collection(request)
            send(parent, :inserted)
            await(:commit)
            result
          end)
        end)

      second =
        race_worker(parent, :second, fn -> SyntheticCorrections.observe_collection(request) end)

      try do
        assert_receive {:first, backend_one}, 5_000
        assert_receive {:second, backend_two}, 5_000
        refute backend_one == backend_two
        send(first.pid, :run)
        assert_receive :inserted, 5_000
        assert claims(source) == []
        send(second.pid, :run)
        assert blocked_by?(backend_two, backend_one, 100)
        send(first.pid, :commit)
        assert {:ok, %{id: ^payment}} = Task.await(first)
        assert {:ok, %{id: ^payment}} = Task.await(second)
      after
        send(first.pid, :commit)
        send(second.pid, :run)
        Task.yield_many([first, second], 5_000)
      end

      assert [[_, _, 5_100, "ZAR", nil]] = claims(source)
      assert collection_count(source.id) == 2

      assert right_states(source) == [
               ["assessment", "held_unconsumed"],
               ["plan", "held_unconsumed"]
             ]
    end)
  end

  test "equivalent correction receipts wait for the winning Commerce transaction" do
    P805.with_fixture(fn ->
      payer = verified_session()
      recipient = verified_session()
      source = accept_fixture(payer, recipient)
      independent = accept_fixture(payer, recipient)
      assert :ok = SyntheticSuppression.register(recipient.credentials)
      assert {:ok, %{id: payment}} = SyntheticCorrections.observe_collection(collection(source))
      assert {:ok, _} = SyntheticCorrections.observe_collection(collection(independent))
      assert {:ok, _} = SyntheticRights.converge(source.id)
      assert {:ok, _} = SyntheticRights.converge(independent.id)

      original = correction(source, payment, %{component: :plan, amount_minor: 3_500})
      equivalent = correction(source, payment, %{component: :plan, amount_minor: 3_500})
      parent = self()

      first =
        race_worker(parent, :first, fn ->
          Ash.transact(SyntheticCorrection, fn ->
            {:ok, effect} = SyntheticCorrections.observe_correction(original)
            send(parent, {:effect_uncommitted, effect.id})
            await(:commit)
            effect
          end)
        end)

      second =
        race_worker(parent, :same, fn -> SyntheticCorrections.observe_correction(original) end)

      third =
        race_worker(parent, :fresh, fn -> SyntheticCorrections.observe_correction(equivalent) end)

      try do
        assert_receive {:first, first_backend}, 5_000
        assert_receive {:same, second_backend}, 5_000
        assert_receive {:fresh, third_backend}, 5_000
        assert MapSet.size(MapSet.new([first_backend, second_backend, third_backend])) == 3

        send(first.pid, :run)
        assert_receive {:effect_uncommitted, effect}, 5_000
        assert {:ok, []} = SyntheticCorrections.open_consequences(source.id)
        send(second.pid, :run)
        assert blocked_by?(second_backend, first_backend, 100)
        send(third.pid, :run)
        assert blocked_by?(third_backend, [first_backend, second_backend], 100)
        send(first.pid, :commit)

        for task <- [first, second, third] do
          assert {:ok, %{id: ^effect, component: :plan, amount_minor: 3_500}} = Task.await(task)
        end

        assert {:ok, [^effect]} = SyntheticCorrections.open_consequences(source.id)
        assert correction_counts(source.id) == {1, 2}
        assert correction_counts(independent.id) == {0, 0}

        assert right_states(source) == [
                 ["assessment", "held_unconsumed"],
                 ["plan", "held_unconsumed"]
               ]

        assert right_states(independent) == right_states(source)
      after
        finish_race([first, second, third])
      end
    end)
  end

  test "Entitlements contenders wait in PostgreSQL and end only the original Plan right" do
    P805.with_fixture(fn ->
      payer = verified_session()
      recipient = verified_session()
      source = accept_fixture(payer, recipient)
      independent = accept_fixture(payer, recipient)
      assert :ok = SyntheticSuppression.register(recipient.credentials)
      assert {:ok, %{id: payment}} = SyntheticCorrections.observe_collection(collection(source))
      assert {:ok, _} = SyntheticCorrections.observe_collection(collection(independent))
      assert {:ok, [assessment, plan]} = SyntheticRights.converge(source.id)
      assert {:ok, independent_rights} = SyntheticRights.converge(independent.id)

      receipt = correction(source, payment, %{component: :plan, amount_minor: 3_500})
      assert {:ok, %{id: effect}} = SyntheticCorrections.observe_correction(receipt)
      race_entitlements(effect, plan.id)

      assert Ash.get!(PlanRight, plan.id, authorize?: false).state == :ended
      assert Ash.get!(PlanRight, assessment.id, authorize?: false).state == :held_unconsumed

      for right <- independent_rights do
        assert Ash.get!(PlanRight, right.id, authorize?: false).state == :held_unconsumed
      end

      assert right_states(source) == [["assessment", "held_unconsumed"], ["plan", "ended"]]

      assert right_states(independent) == [
               ["assessment", "held_unconsumed"],
               ["plan", "held_unconsumed"]
             ]

      assert {:ok, [^effect]} = SyntheticCorrections.open_consequences(source.id)
      assert {:ok, _} = SyntheticCorrections.deliver(effect)
      assert {:ok, []} = SyntheticCorrections.open_consequences(source.id)
      assert correction_counts(source.id) == {1, 1}
    end)
  end

  defp race_entitlements(effect, right_id) do
    parent = self()

    holder =
      race_worker(parent, :holder, fn ->
        Ash.transact(PlanRight, fn ->
          query = PlanRight |> Ash.Query.filter(id == ^right_id) |> Ash.Query.lock(:for_update)
          assert %PlanRight{state: :held_unconsumed} = Ash.read_one!(query, authorize?: false)
          send(parent, :right_locked)
          await(:commit)
        end)
      end)

    first = race_worker(parent, :first_apply, fn -> SyntheticRights.apply_correction(effect) end)

    second =
      race_worker(parent, :second_apply, fn -> SyntheticRights.apply_correction(effect) end)

    try do
      assert_receive {:holder, holder_backend}, 5_000
      assert_receive {:first_apply, first_backend}, 5_000
      assert_receive {:second_apply, second_backend}, 5_000
      assert MapSet.size(MapSet.new([holder_backend, first_backend, second_backend])) == 3

      send(holder.pid, :run)
      assert_receive :right_locked, 5_000
      send(first.pid, :run)
      assert blocked_by?(first_backend, holder_backend, 100)
      send(second.pid, :run)
      assert blocked_by?(second_backend, first_backend, 100)
      assert Ash.get!(PlanRight, right_id, authorize?: false).state == :held_unconsumed

      send(holder.pid, :commit)
      assert {:ok, :ok} = Task.await(holder)
      assert :ok = Task.await(first)
      assert :ok = Task.await(second)
    after
      finish_race([holder, first, second])
    end
  end

  test "qualified return settles the excess once and scoped readers see only their projection" do
    P805.with_fixture(fn ->
      payer = verified_session()
      recipient = verified_session()
      staff = verified_session()
      source = accept_fixture(payer, recipient)
      assert :ok = SyntheticSuppression.register(recipient.credentials)
      assert {:ok, _} = SyntheticCorrections.observe_collection(collection(source))
      excess = collection(source)
      assert {:ok, _} = SyntheticCorrections.observe_collection(excess)
      assert {:ok, _} = SyntheticRights.converge(source.id)

      partial =
        correction(source, excess.fields.collection_id, %{
          reason: :excess_returned,
          amount_minor: 5_099
        })

      assert {:ok, %{kind: :unresolved}} = SyntheticCorrections.observe_correction(partial)
      assert [[_, _, 5_100, "ZAR", nil]] = claims(source)

      final =
        correction(source, excess.fields.collection_id, %{
          reason: :excess_returned,
          amount_minor: 5_100
        })

      assert {:ok, %{kind: :excess_satisfied, id: effect}} =
               SyntheticCorrections.observe_correction(final)

      assert [[_, _, 5_100, "ZAR", first_settlement]] = claims(source)
      assert first_settlement
      assert {:ok, _} = SyntheticCorrections.deliver(effect)
      assert {:ok, %{id: ^effect}} = SyntheticCorrections.observe_correction(final)
      assert [[_, _, 5_100, "ZAR", ^first_settlement]] = claims(source)

      assert right_states(source) == [
               ["assessment", "held_unconsumed"],
               ["plan", "held_unconsumed"]
             ]

      finance = read_grant(staff, source, :finance)
      support = read_grant(staff, source, :support)
      audit = read_grant(staff, source, :audit)

      assert {:error, :read_unavailable} =
               SyntheticCorrections.read_evidence(staff.credentials, source.id, :finance, nil)

      assert {:error, :read_unavailable} =
               SyntheticCorrections.read_evidence(staff.credentials, source.id, :support, nil)

      assert {:error, :read_unavailable} =
               SyntheticCorrections.read_evidence(
                 recipient.credentials,
                 source.id,
                 :finance,
                 finance
               )

      assert {:error, :read_unavailable} =
               SyntheticCorrections.read_evidence(
                 staff.credentials,
                 Ecto.UUID.generate(),
                 :finance,
                 finance
               )

      claimant = payer.id

      assert {:ok,
              %{amount_minor: 5_100, claimant_id: ^claimant, status: :satisfied, currency: "ZAR"}} =
               SyntheticCorrections.read_evidence(staff.credentials, source.id, :finance, finance)

      assert {:ok, %{status: :satisfied}} ==
               SyntheticCorrections.read_evidence(staff.credentials, source.id, :support, support)

      assert {:ok, %{correction_kinds: [:excess_satisfied, :unresolved]}} ==
               NewYou.Audit.SyntheticCorrectionEvidence.read(staff.credentials, source.id, audit)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.create(
                 SyntheticExcessClaim,
                 %{
                   source_id: source.id,
                   claimant_id: staff.id,
                   amount_minor: 1,
                   currency: "ZAR",
                   collection_id: excess.fields.collection_id
                 },
                 action: :establish,
                 actor: %{role: :finance}
               )

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.create(
                 Entitlements.PlanRight,
                 %{
                   purchase_id: source.id,
                   payment_id: excess.fields.collection_id,
                   recipient_id: staff.id
                 },
                 action: :grant,
                 actor: %{role: :finance}
               )
    end)
  end

  defp paid_correction_sources do
    payer = verified_session()
    recipient = verified_session()
    source = accept_fixture(payer, recipient)
    independent = accept_fixture(payer, recipient)
    assert :ok = SyntheticSuppression.register(recipient.credentials)

    original = collection(source)
    assert {:ok, %{id: payment}} = SyntheticCorrections.observe_collection(original)
    excess = collection(source)
    assert {:ok, %{id: ^payment}} = SyntheticCorrections.observe_collection(excess)

    assert {:ok, %{id: independent_payment}} =
             SyntheticCorrections.observe_collection(collection(independent))

    assert {:ok, rights} = SyntheticRights.converge(source.id)
    assert {:ok, independent_rights} = SyntheticRights.converge(independent.id)

    %{
      payer: payer,
      recipient: recipient,
      source: source,
      independent: independent,
      original: original,
      payment: payment,
      excess: excess.fields.collection_id,
      independent_payment: independent_payment,
      rights: rights,
      independent_rights: independent_rights
    }
  end

  defp final_correction_controls(fixture) do
    [
      correction(fixture.source, fixture.payment, %{component: :plan, amount_minor: 3_500}),
      correction(fixture.source, fixture.excess, %{reason: :excess_returned, amount_minor: 5_100})
    ]
  end

  defp assert_unresolved_receipt(receipt, source_id) do
    assert {:ok, %SyntheticCorrection{id: id, source_id: ^source_id, kind: :unresolved}} =
             SyntheticCorrections.observe_correction(receipt)

    assert {:ok, %{id: ^id}} = SyntheticCorrections.observe_correction(receipt)
    assert {:error, :delivery_unavailable} = SyntheticCorrections.deliver(id)

    assert %SyntheticCorrection{
             kind: :unresolved,
             component: nil,
             amount_minor: nil,
             acknowledged_at: nil
           } =
             Ash.get!(SyntheticCorrection, id, authorize?: false)

    assert %SyntheticCorrectionReceipt{correction_id: ^id} =
             Ash.get!(SyntheticCorrectionReceipt, receipt.fields.receipt_id, authorize?: false)
  end

  defp assert_rejected_receipt(receipt) do
    assert {:error, :correction_unavailable} = SyntheticCorrections.observe_correction(receipt)

    assert {:ok, nil} =
             Ash.get(SyntheticCorrectionReceipt, receipt.fields.receipt_id,
               authorize?: false,
               error?: false
             )
  end

  defp assert_no_correction_effects(fixture) do
    assert {:ok, []} = SyntheticCorrections.open_consequences(fixture.source.id)
    assert {:ok, []} = SyntheticCorrections.open_consequences(fixture.independent.id)
    assert correction_counts(fixture.independent.id) == {0, 0}
    assert claims(fixture.source) == [[fixture.payer.id, fixture.excess, 5_100, "ZAR", nil]]
    assert claims(fixture.independent) == []
    assert_unchanged_rights(fixture.rights ++ fixture.independent_rights)
  end

  defp assert_unchanged_rights(rights) do
    for right <- rights do
      persisted = Ash.get!(PlanRight, right.id, authorize?: false)
      assert persisted.state == :held_unconsumed
      assert persisted.payment_id == right.payment_id
      assert persisted.recipient_id == right.recipient_id
    end
  end

  defp assert_final_controls(fixture) do
    [refund, returned] = final_correction_controls(fixture)

    assert {:ok, %{id: end_effect, kind: :component_end, amount_minor: 3_500, component: :plan}} =
             SyntheticCorrections.observe_correction(refund)

    assert {:ok, %{id: money_effect, kind: :excess_satisfied, amount_minor: 5_100}} =
             SyntheticCorrections.observe_correction(returned)

    assert {:ok, _} = SyntheticCorrections.deliver(end_effect)
    assert {:ok, _} = SyntheticCorrections.deliver(money_effect)
    assert right_states(fixture.source) == [["assessment", "held_unconsumed"], ["plan", "ended"]]
    assert {:ok, []} = SyntheticCorrections.open_consequences(fixture.source.id)
    assert_unchanged_rights(fixture.independent_rights)
    assert [[payer, collection, 5_100, "ZAR", satisfied_at]] = claims(fixture.source)
    assert payer == fixture.payer.id
    assert collection == fixture.excess
    assert satisfied_at
  end

  defp corrupt_signature(<<first, rest::binary>>), do: <<Bitwise.bxor(first, 1), rest::binary>>

  defp assert_suppressed_delivery_waits_for_update(effect, right_id) do
    parent = self()

    holder =
      race_worker(parent, :suppressed_right_holder, fn ->
        Ash.transact(PlanRight, fn ->
          query = PlanRight |> Ash.Query.filter(id == ^right_id) |> Ash.Query.lock(:for_update)
          assert %PlanRight{state: :held_unconsumed} = Ash.read_one!(query, authorize?: false)
          send(parent, :suppressed_right_locked)
          await(:commit)
        end)
      end)

    delivery =
      race_worker(parent, :suppressed_delivery, fn ->
        [[previous]] = Repo.query!("SELECT current_setting('lock_timeout')").rows
        Repo.query!("SELECT set_config('lock_timeout', '1500ms', false)")

        try do
          SyntheticCorrections.deliver(effect)
        after
          Repo.query!("SELECT set_config('lock_timeout', $1, false)", [previous])
        end
      end)

    try do
      assert_receive {:suppressed_right_holder, blocker}, 5_000
      assert_receive {:suppressed_delivery, waiter}, 5_000
      send(holder.pid, :run)
      assert_receive :suppressed_right_locked, 5_000
      send(delivery.pid, :run)
      assert blocked_by?(waiter, blocker, 50)
      assert {:error, :delivery_unavailable} = Task.await(delivery)
      send(holder.pid, :commit)
      assert {:ok, :ok} = Task.await(holder)
    after
      finish_race([holder, delivery])
    end
  end

  defp read_grant(staff, source, role) do
    PlanPaymentObservation.produce(%{
      scope: :synthetic_correction_read,
      staff_id: staff.id,
      source_id: source.id,
      role: role
    })
  end

  defp completed_deletion(recipient),
    do: PlanPaymentObservation.produce(%{scope: :completed_deletion, subject_id: recipient.id})

  defp fresh_vm!(stage, id) do
    {executable, arguments} =
      NewYou.Proof.FreshMix.command([
        "run",
        "test/proof/well192_correction_restart.exs",
        stage,
        id
      ])

    result = NewYou.Proof.P815Port.run(executable, arguments, "", 60_000)
    assert %{status: :ok, marker: :e2a_completed, cleanup: :confirmed} = result
  end

  defp recover_while_source_is_locked(source_id) do
    parent = self()

    holder =
      race_worker(parent, :recovery_holder, fn ->
        Ash.transact(SyntheticOrder, fn ->
          query =
            SyntheticOrder |> Ash.Query.filter(id == ^source_id) |> Ash.Query.lock(:for_update)

          assert %SyntheticOrder{} = Ash.read_one!(query, authorize?: false)
          [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
          send(parent, :recovery_source_locked)
          has_waiter?(backend, System.monotonic_time(:millisecond) + 12_000)
        end)
      end)

    assert_receive {:recovery_holder, _}, 5_000
    send(holder.pid, :run)
    assert_receive :recovery_source_locked, 5_000
    fresh_vm!("apply", source_id)
    assert {:ok, true} = Task.await(holder)
  end

  defp has_waiter?(holder, deadline) do
    # PostgreSQL retains the activity snapshot within a transaction. Include
    # the fresh BEAM's backend even if it connected after the first observation.
    Repo.query!("SELECT pg_stat_clear_snapshot()")

    case Repo.query!(
           "SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE $1::integer = ANY(pg_blocking_pids(pid)))",
           [holder]
         ).rows do
      [[true]] ->
        true

      [[false]] ->
        Process.sleep(20)
        System.monotonic_time(:millisecond) < deadline and has_waiter?(holder, deadline)
    end
  end

  defp assert_correction_job_absent(effect) do
    assert [[0]] =
             Repo.query!(
               "SELECT count(*) FROM oban_jobs WHERE args->'primary_key'->>'id' = $1",
               [effect]
             ).rows
  end

  defp race_worker(parent, name, action) do
    task =
      Task.async(fn ->
        :ok = Sandbox.checkout(Repo, sandbox: false)

        Repo.checkout(fn ->
          [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
          send(parent, {name, backend})
          await(:run)
          action.()
        end)
      end)

    :ok = P805.register_cleanup_worker(task.pid)
    task
  end

  defp finish_race(tasks) do
    Enum.each(tasks, fn task ->
      send(task.pid, :run)
      send(task.pid, :commit)
    end)

    Task.yield_many(tasks, 5_000)
  end

  defp await(message) do
    receive do
      ^message -> :ok
    after
      10_000 -> raise "synthetic correction checkpoint expired"
    end
  end

  defp blocked_by?(_waiter, _blocker, 0), do: false

  defp blocked_by?(waiter, blocker, attempts) do
    case Repo.query!("SELECT pg_blocking_pids($1) && $2::integer[]", [
           waiter,
           List.wrap(blocker)
         ]).rows do
      [[true]] ->
        true

      [[false]] ->
        Process.sleep(20)
        blocked_by?(waiter, blocker, attempts - 1)
    end
  end

  defp accept_fixture(payer, recipient) do
    {:ok, source} =
      SyntheticCorrections.accept(
        payer.credentials,
        recipient.credentials,
        admission(payer, recipient)
      )

    source
  end

  defp reprice(admission, plan, assessment) do
    PlanPaymentObservation.produce(%{
      admission.fields
      | price_version: "synthetic-bundle-v2",
        plan_list_minor: plan,
        assessment_list_minor: assessment,
        plan_discount_minor: 0,
        assessment_discount_minor: 0
    })
  end

  defp correction(source, payment, overrides) do
    original = collection(source)

    original.fields
    |> Map.merge(%{
      scope: :correction,
      status: :final,
      reason: :unused_component,
      collection_id: payment
    })
    |> Map.merge(overrides)
    |> PlanPaymentObservation.produce()
  end

  defp right_states(source) do
    Repo.query!(
      """
      SELECT component, state FROM entitlements_plan_rights
      WHERE purchase_id = $1::text::uuid ORDER BY component
      """,
      [source.id]
    ).rows
  end

  defp admission(payer, recipient) do
    operation_id = Ecto.UUID.generate()
    P805.track_operation(operation_id)

    PlanPaymentObservation.produce(%{
      scope: :accepted_correction_fixture,
      operation_id: operation_id,
      payer_id: payer.id,
      recipient_id: recipient.id,
      price_version: "synthetic-bundle-v1",
      currency: "ZAR",
      amount_minor: 5_100,
      plan_list_minor: 4_000,
      plan_discount_minor: 500,
      assessment_list_minor: 2_000,
      assessment_discount_minor: 400
    })
  end

  defp collection(source, overrides \\ []) do
    fields = %{
      scope: :collection,
      integration: :synthetic,
      environment: :test,
      status: :succeeded,
      source_id: source.id,
      operation_id: source.operation_id,
      payer_id: source.payer_id,
      recipient_id: source.recipient_id,
      price_version: source.price_version,
      currency: source.currency,
      amount_minor: source.amount_minor,
      collection_id: Ecto.UUID.generate(),
      receipt_id: Ecto.UUID.generate()
    }

    PlanPaymentObservation.produce(Map.merge(fields, Map.new(overrides)))
  end

  defp collection_count(id) do
    [[count]] =
      Repo.query!("SELECT count(*) FROM commerce_synthetic_collections WHERE source_id = $1", [
        Ecto.UUID.dump!(id)
      ]).rows

    count
  end

  defp correction_counts(id) do
    [[effects, receipts]] =
      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM commerce_synthetic_corrections WHERE source_id = $1),
          (SELECT count(*) FROM commerce_synthetic_correction_receipts receipt
          JOIN commerce_synthetic_corrections effect ON effect.id = receipt.correction_id
          WHERE effect.source_id = $1)
        """,
        [Ecto.UUID.dump!(id)]
      ).rows

    {effects, receipts}
  end

  defp claims(source) do
    Repo.query!(
      """
      SELECT claimant_id::text, collection_id::text, amount_minor, currency, satisfied_at
      FROM commerce_synthetic_excess_claims WHERE source_id = $1::text::uuid
      """,
      [source.id]
    ).rows
  end

  defp verified_session do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
    %{id: registration.account_id, credentials: credentials}
  end
end
