defmodule NewYou.Commerce.SyntheticCorrectionsTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Commerce, Entitlements, Identity, Repo}
  alias NewYou.Commerce.{SyntheticCorrection, SyntheticCorrections, SyntheticExcessClaim}
  alias NewYou.Entitlements.SyntheticRights
  alias NewYou.Privacy.SyntheticSuppression
  alias NewYou.Proof.{P805, PlanPaymentObservation}

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

      fresh_vm!("deliver", effect)
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

      assert right_states(source) == [
               ["assessment", "held_unconsumed"],
               ["plan", "held_unconsumed"]
             ]

      fresh_vm!("apply", effect)
      assert right_states(source) == [["assessment", "held_unconsumed"], ["plan", "ended"]]
      assert {:ok, [^effect]} = SyntheticCorrections.open_consequences(source.id)
      fresh_vm!("deliver", effect)
      assert {:ok, []} = SyntheticCorrections.open_consequences(source.id)
      assert right_states(source) == [["assessment", "held_unconsumed"], ["plan", "ended"]]
    end)
  end

  test "independent SQL transactions converge on one owed claim and one component end" do
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

      assert [_] = claims(source)
      receipt = correction(source, payment, %{component: :plan, amount_minor: 3_500})
      assert {:ok, %{id: effect}} = SyntheticCorrections.observe_correction(receipt)

      racers =
        for name <- [:apply_one, :apply_two] do
          race_worker(parent, name, fn -> SyntheticRights.apply_correction(effect) end)
        end

      try do
        assert_receive {:apply_one, apply_one}, 5_000
        assert_receive {:apply_two, apply_two}, 5_000
        refute apply_one == apply_two
        Enum.each(racers, &send(&1.pid, :run))
        assert Enum.map(racers, &Task.await/1) == [:ok, :ok]
      after
        Enum.each(racers, &send(&1.pid, :run))
        Task.yield_many(racers, 5_000)
      end

      assert {:ok, [^effect]} = SyntheticCorrections.open_consequences(source.id)
      assert {:ok, _} = SyntheticCorrections.deliver(effect)
      assert right_states(source) == [["assessment", "held_unconsumed"], ["plan", "ended"]]
      assert {:ok, []} = SyntheticCorrections.open_consequences(source.id)
    end)
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

  defp race_worker(parent, name, action) do
    Task.async(fn ->
      :ok = Sandbox.checkout(Repo, sandbox: false)

      Repo.checkout(fn ->
        [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
        send(parent, {name, backend})
        await(:run)
        action.()
      end)
    end)
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
    case Repo.query!("SELECT $2 = ANY(pg_blocking_pids($1))", [waiter, blocker]).rows do
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

  defp collection(source) do
    PlanPaymentObservation.produce(%{
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
    })
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
