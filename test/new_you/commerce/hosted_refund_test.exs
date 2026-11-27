defmodule NewYou.Commerce.HostedRefundTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: NewYou.Repo

  alias NewYou.Commerce
  alias NewYou.Entitlements
  alias NewYou.Repo
  alias NewYou.Commerce.{HostedCheckout, HostedCheckoutReceiver, HostedPaymentEvidence}
  alias NewYou.Commerce.{FixtureDispute, FixtureDisputeReceipt, FixtureDisputes}
  alias NewYou.Commerce.{OfferAdmission, VerifiedPayment}
  alias NewYou.Proof.{FreshMix, P805, P815Port}
  alias NewYou.Privacy.SyntheticSuppression
  alias Ecto.Adapters.SQL.Sandbox

  import NewYou.Commerce.OfferFixtures

  require Ash.Query

  @scope %{provider: :paystack, integration: :local_fixture, environment: :test, channel: :card}
  @amount 47_500
  @transaction "18446744073709551614"

  test "qualified disputes fence refund dispatch and converge the original right" do
    P805.with_fixture(fn ->
      with_paid_plan(fn accepted, payment, payer, recipient, _listener, tag ->
        assert {:ok, [grant]} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
        assert {:ok, _} = Commerce.deliver_plan_payment_consequence(grant)
        assert [%{id: original}] = plan_rights(recipient)

        assert {:ok, refund} =
                 request(
                   payer.credentials,
                   proof(refund_fields(accepted, payment, payer, recipient))
                 )

        assert {:ok, %{state: :reserved}} =
                 Commerce.reserve_fixture_refund(payer.credentials, refund.id)

        with_signing_key(fn key ->
          data = dispute_data(payment)
          assert 401 == send_event(key, "fixture.dispute", data, authenticated?: false)
          assert 401 == send_event(key, "fixture.dispute", data, modified?: true)

          for invalid <- [
                %{data | reference: String.duplicate("0", 32)},
                %{data | transaction: "17"},
                %{data | amount: @amount + 1},
                %{data | currency: "USD"},
                %{data | id: "099"},
                %{data | scope: "production"},
                %{data | outcome: "success"},
                Map.put(data, :health, "must never persist")
              ] do
            assert 400 == send_event(key, "fixture.dispute", invalid)
          end

          P805.with_rejected_insert("commerce_fixture_dispute_receipts", fn reached? ->
            assert 503 == send_event(key, "fixture.dispute", data)
            assert reached?.()
          end)

          assert 202 == send_event(key, "fixture.dispute", data)
          assert 202 == send_event(key, "fixture.dispute", data)
          assert [_one] = dispute_receipts(payment)
          assert [] = Ash.read!(FixtureDispute, authorize?: false)

          assert {:error, :refund_unavailable} =
                   Commerce.dispatch_fixture_refund(payer.credentials, refund.id)

          dispute = apply_dispute_receipts(payment)
          assert dispute.state == :contested
          assert [] = plan_rights(recipient)

          assert {:error, :refund_unavailable} =
                   Commerce.dispatch_fixture_refund(payer.credentials, refund.id)

          refute_received {^tag, "POST", "/refund", _, _}
          assert :ok = Commerce.deliver_fixture_dispute(dispute.id)

          assert %{state: :suspended} =
                   Ash.get!(NewYou.Entitlements.PlanRight, original, authorize?: false)

          assert 202 ==
                   send_event(key, "fixture.dispute", %{
                     data
                     | revision: 3,
                       outcome: "under_review"
                   })

          assert 202 ==
                   send_event(key, "fixture.dispute", %{
                     data
                     | revision: 2,
                       outcome: "awaiting_feedback"
                   })

          assert %{state: :under_review, revision: 3} = apply_dispute_receipts(payment)

          assert 202 ==
                   send_event(key, "fixture.dispute", %{data | revision: 4, outcome: "restored"})

          assert %{state: :restored} = apply_dispute_receipts(payment)
          assert :ok = Commerce.deliver_fixture_dispute(dispute.id)
          assert [%{id: ^original}] = plan_rights(recipient)
          assert 202 == send_event(key, "fixture.dispute", %{data | revision: 5, outcome: "lost"})
          assert %{state: :restored, conflict?: true} = apply_dispute_receipts(payment)
          assert :ok = Commerce.deliver_fixture_dispute(dispute.id)
          assert [] = plan_rights(recipient)

          assert %{state: :reserved, amount_minor: @amount, claim_id: nil} =
                   read_refund(refund.id)
        end)
      end)
    end)
  end

  test "an outstanding grant uses current dispute truth and cannot resurrect a lost right" do
    P805.with_fixture(fn ->
      with_paid_plan(fn accepted, payment, _payer, recipient, _, _ ->
        with_signing_key(fn key ->
          data = dispute_data(payment)
          assert {:ok, [grant]} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
          assert 202 == send_event(key, "fixture.dispute", data)
          dispute = apply_dispute_receipts(payment)
          assert :ok = Commerce.deliver_fixture_dispute(dispute.id)

          assert {:ok, %{id: id, state: :suspended}} =
                   Commerce.deliver_plan_payment_consequence(grant)

          assert [] = plan_rights(recipient)

          assert 202 == send_event(key, "fixture.dispute", %{data | revision: 4, outcome: "lost"})

          assert 202 ==
                   send_event(key, "fixture.dispute", %{
                     data
                     | revision: 2,
                       outcome: "awaiting_feedback"
                   })

          assert %{state: :lost} = apply_dispute_receipts(payment)

          assert 202 ==
                   send_event(key, "fixture.dispute", %{data | revision: 5, outcome: "restored"})

          assert %{state: :lost, conflict?: true} = apply_dispute_receipts(payment)

          cut_work(:fixture_dispute, :entitlements_committed, fn ->
            Commerce.deliver_fixture_dispute(dispute.id)
          end)

          assert %{state: :ended} = Ash.get!(NewYou.Entitlements.PlanRight, id, authorize?: false)
          assert {:ok, :withheld} = Commerce.deliver_plan_payment_consequence(grant)
          assert :ok = Commerce.deliver_fixture_dispute(dispute.id)
          assert [] = plan_rights(recipient)
          assert Ash.get!(VerifiedPayment, payment.id, authorize?: false) == payment
        end)
      end)
    end)
  end

  test "partial loss retains financial evidence without inferring a component" do
    P805.with_fixture(fn ->
      with_paid_plan(fn accepted, payment, payer, recipient, _, _ ->
        assert {:ok, [grant]} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
        assert {:ok, %{id: id}} = Commerce.deliver_plan_payment_consequence(grant)

        assert {:ok, refund} =
                 request(
                   payer.credentials,
                   proof(refund_fields(accepted, payment, payer, recipient))
                 )

        assert {:ok, _} = Commerce.reserve_fixture_refund(payer.credentials, refund.id)
        assert {:ok, claimed} = Commerce.dispatch_fixture_refund(payer.credentials, refund.id)

        with_signing_key(fn key ->
          data = %{dispute_data(payment) | amount: 24_900, outcome: "lost"}
          assert 202 == send_event(key, "fixture.dispute", data)

          assert %{state: :lost, allocation: :unallocated, amount_minor: 24_900} =
                   dispute =
                   apply_dispute_receipts(payment)

          assert {:ok, :unresolved} = FixtureDisputes.correction_overlap(dispute.id)
          assert :ok = Commerce.deliver_fixture_dispute(dispute.id)
          assert [%{id: ^id}] = plan_rights(recipient)

          assert 202 == send_evidence(key, refund_data(refund), "processed")
          process_evidence(refund.reference)
          assert {:ok, :unresolved} = FixtureDisputes.correction_overlap(dispute.id)

          assert %{state: :processed, claim_id: claim_id, amount_minor: @amount} =
                   read_refund(refund.id)

          assert claim_id == claimed.claim_id
          assert :ok = Commerce.deliver_fixture_refund(refund.id)
          assert [] = plan_rights(recipient)
        end)
      end)
    end)
  end

  test "payment restoration rechecks a verified refund, deletion and current access posture" do
    for block <- [:refund, :deletion, :security_hold] do
      P805.with_fixture(fn ->
        with_paid_plan(fn accepted, payment, payer, recipient, _, _ ->
          assert {:ok, [grant]} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
          assert {:ok, %{id: id}} = Commerce.deliver_plan_payment_consequence(grant)

          refund =
            if block == :refund do
              assert {:ok, owed} =
                       request(
                         payer.credentials,
                         proof(refund_fields(accepted, payment, payer, recipient))
                       )

              assert {:ok, _} = Commerce.reserve_fixture_refund(payer.credentials, owed.id)
              assert {:ok, _} = Commerce.dispatch_fixture_refund(payer.credentials, owed.id)
              owed
            end

          with_signing_key(fn key ->
            data = dispute_data(payment)
            assert 202 == send_event(key, "fixture.dispute", data)
            dispute = apply_dispute_receipts(payment)
            assert :ok = Commerce.deliver_fixture_dispute(dispute.id)

            assert %{state: :suspended} =
                     Ash.get!(NewYou.Entitlements.PlanRight, id, authorize?: false)

            case block do
              :refund ->
                assert 202 == send_evidence(key, refund_data(refund), "processed")
                process_evidence(refund.reference)

              :deletion ->
                assert :ok =
                         SyntheticSuppression.suppress(
                           proof(%{scope: :completed_deletion, subject_id: recipient.account_id})
                         )

              :security_hold ->
                account =
                  Ash.get!(NewYou.Identity.Account, recipient.account_id, authorize?: false)

                assert {:ok, _} =
                         Ash.update(account, %{expected_hold_version: account.hold_version},
                           action: :place_security_hold,
                           authorize?: false
                         )
            end

            assert 202 ==
                     send_event(key, "fixture.dispute", %{data | revision: 2, outcome: "restored"})

            assert %{state: :restored, effect_version: version} = apply_dispute_receipts(payment)

            if block == :security_hold do
              assert {:error, :dispute_unavailable} = Commerce.deliver_fixture_dispute(dispute.id)

              assert Ash.get!(FixtureDispute, dispute.id, authorize?: false).acknowledged_version <
                       version
            else
              assert :ok = Commerce.deliver_fixture_dispute(dispute.id)
              assert [] = plan_rights(recipient)
            end

            expected = if block == :refund, do: :ended, else: :suspended

            assert %{state: ^expected} =
                     Ash.get!(NewYou.Entitlements.PlanRight, id, authorize?: false)
          end)
        end)
      end)
    end
  end

  test "dispute receipt and consequence telemetry exclude source canaries on committed and failed SQL paths" do
    P805.with_fixture(fn ->
      with_paid_plan(fn _accepted, payment, _payer, _, _, _ ->
        with_signing_key(fn key ->
          data = %{dispute_data(payment) | id: "18446744073709549711"}
          needles = [data.reference, data.transaction, data.id, payment.id]

          P805.with_rejected_insert("commerce_fixture_dispute_receipts", fn reached? ->
            assert :clean ==
                     observe_restricted_metadata(
                       needles ++ [key],
                       fn ->
                         assert 503 == send_event(key, "fixture.dispute", data)
                       end,
                       :failed_dispute_receipt
                     )

            assert reached?.()
          end)

          assert :clean ==
                   observe_restricted_metadata(
                     needles ++ [key],
                     fn ->
                       assert 202 == send_event(key, "fixture.dispute", data)
                     end,
                     :committed_dispute_receipt
                   )

          assert [receipt] = dispute_receipts(payment)

          assert :clean ==
                   observe_restricted_metadata(
                     needles ++ [key],
                     fn ->
                       assert :ok = Commerce.apply_fixture_dispute_receipt(receipt.id)
                     end,
                     :qualified_dispute_receipt
                   )

          dispute = apply_dispute_receipts(payment)

          assert :clean ==
                   observe_restricted_metadata(
                     needles ++ [key],
                     fn ->
                       assert :ok = Commerce.deliver_fixture_dispute(dispute.id)
                     end,
                     :dispute_effect
                   )
        end)
      end)
    end)
  end

  test "known dispute read recovers missing work after a capped reservation and evidence failure" do
    P805.with_fixture(fn ->
      reply_data = start_supervised!({Agent, fn -> nil end})

      reply = fn conn, _ ->
        HostedCheckoutReceiver.json(conn, 200, %{data: Agent.get(reply_data, & &1)})
      end

      with_paid_plan(reply, fn accepted, payment, _payer, recipient, _, tag ->
        assert {:ok, [grant]} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
        assert {:ok, %{id: right_id}} = Commerce.deliver_plan_payment_consequence(grant)

        with_signing_key(fn key ->
          data = dispute_data(payment)
          assert 202 == send_event(key, "fixture.dispute", data)
          assert [receipt] = dispute_receipts(payment)

          cut_work(:fixture_dispute, :commerce_committed, fn ->
            Commerce.apply_fixture_dispute_receipt(receipt.id)
          end)

          dispute = apply_dispute_receipts(payment)
          assert :ok = Commerce.deliver_fixture_dispute(dispute.id)
          assert [] = plan_rights(recipient)
          make_dispute_due(dispute.id, 5)

          cut_work(:fixture_dispute, :read_reserved, fn ->
            FixtureDisputes.read_due(dispute.id)
          end)

          assert %{verify_round: 6} = Ash.get!(FixtureDispute, dispute.id, authorize?: false)
          refute_received {^tag, "GET", "/__test/dispute/99", _, _}

          make_dispute_due(dispute.id, 6)
          Agent.update(reply_data, fn _ -> %{data | revision: 2, outcome: "restored"} end)

          P805.with_rejected_insert("commerce_fixture_dispute_receipts", fn reached? ->
            assert %{discard: 1, queues_not_drained: []} =
                     AshOban.Test.schedule_and_run_triggers({FixtureDispute, :read_due})

            assert reached?.()
            assert_receive {^tag, "GET", "/__test/dispute/99", _, _}
          end)

          assert [^receipt] = Enum.map(dispute_receipts(payment), &%{&1 | state: :pending})

          refute_enqueued(
            worker: NewYou.Commerce.Workers.ReadFixtureDispute,
            args: %{"primary_key" => %{"id" => dispute.id}}
          )

          make_dispute_due(dispute.id, 6)

          {executable, arguments} =
            FreshMix.command(["run", "--no-compile", "test/proof/well223_dispute_restart.exs"])

          payload = Jason.encode!(%{id: dispute.id})
          diagnostic = P815Port.run(executable, arguments, payload, 60_000)
          assert_receive {^tag, "GET", "/__test/dispute/99", _, _}
          assert %{status: :ok, cleanup: :confirmed, marker: :well223_completed} = diagnostic
          refute_received {^tag, "GET", "/__test/dispute/99", _, _}
          assert [%{id: ^right_id}] = plan_rights(recipient)
        end)
      end)
    end)
  end

  test "refund and dispute serialize both orders on independent PostgreSQL writers" do
    for winner <- [:dispute, :refund] do
      P805.with_fixture(fn ->
        with_paid_plan(fn accepted, payment, payer, recipient, _, tag ->
          assert {:ok, refund} =
                   request(
                     payer.credentials,
                     proof(refund_fields(accepted, payment, payer, recipient))
                   )

          assert {:ok, _} = Commerce.reserve_fixture_refund(payer.credentials, refund.id)

          with_signing_key(fn key ->
            dispute = fn ->
              send_event(key, "fixture.dispute", dispute_data(payment), track?: false)
            end

            dispatch = fn -> Commerce.dispatch_fixture_refund(payer.credentials, refund.id) end

            case winner do
              :dispute ->
                assert {202, {:error, :refund_unavailable}} =
                         race_corrections(:fixture_dispute, :receipt_written, dispute, dispatch)

                refute_received {^tag, "POST", "/refund", _, _}
                assert %{claim_id: nil, state: :reserved} = read_refund(refund.id)

                assert {:ok, :refund_owed} =
                         FixtureDisputes.correction_overlap(apply_dispute_receipts(payment).id)

              :refund ->
                assert {{:ok, %{state: :unresolved, claim_id: claim}}, 202} =
                         race_corrections(:fixture_refund, :claim_written, dispatch, dispute)

                assert_receive {^tag, "POST", "/refund", _, _}

                assert {:ok, %{claim_id: ^claim}} =
                         Commerce.dispatch_fixture_refund(payer.credentials, refund.id)

                refute_received {^tag, "POST", "/refund", _, _}

                assert {:ok, :unresolved} =
                         FixtureDisputes.correction_overlap(apply_dispute_receipts(payment).id)
            end
          end)
        end)
      end)
    end
  end

  test "a later pinned read can confirm either retained terminal outcome across a restart" do
    reply_data = start_supervised!({Agent, fn -> nil end})

    reply = fn conn, _ ->
      HostedCheckoutReceiver.json(conn, 200, %{data: Agent.get(reply_data, & &1)})
    end

    for {terminal, contrary, right_state} <- [
          {:restored, :lost, :held_unconsumed},
          {:lost, :restored, :ended}
        ] do
      P805.with_fixture(fn ->
        with_paid_plan(reply, fn accepted, payment, payer, recipient, _, tag ->
          assert {:ok, [grant]} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
          assert {:ok, %{id: right_id}} = Commerce.deliver_plan_payment_consequence(grant)

          assert {:ok, refund} =
                   request(
                     payer.credentials,
                     proof(refund_fields(accepted, payment, payer, recipient))
                   )

          assert {:ok, %{state: :reserved}} =
                   Commerce.reserve_fixture_refund(payer.credentials, refund.id)

          with_signing_key(fn key ->
            data = dispute_data(payment)
            retained = Atom.to_string(terminal)
            opposite = Atom.to_string(contrary)

            assert 202 ==
                     send_event(key, "fixture.dispute", %{data | revision: 2, outcome: retained})

            dispute = apply_dispute_receipts(payment)
            assert :ok = Commerce.deliver_fixture_dispute(dispute.id)

            assert 202 ==
                     send_event(key, "fixture.dispute", %{data | revision: 1, outcome: opposite})

            assert %{state: ^terminal, conflict?: true} = apply_dispute_receipts(payment)

            assert 202 ==
                     send_event(key, "fixture.dispute", %{data | revision: 4, outcome: opposite})

            assert %{state: ^terminal, conflict?: true, effect_version: conflict_version} =
                     apply_dispute_receipts(payment)

            assert :ok = Commerce.deliver_fixture_dispute(dispute.id)
            assert [] = plan_rights(recipient)
            interim = if terminal == :restored, do: :suspended, else: :ended

            assert %{state: ^interim} =
                     Ash.get!(NewYou.Entitlements.PlanRight, right_id, authorize?: false)

            assert {:error, :refund_unavailable} =
                     Commerce.dispatch_fixture_refund(payer.credentials, refund.id)

            refute_received {^tag, "POST", "/refund", _, _}

            assert 202 ==
                     send_event(key, "fixture.dispute", %{data | revision: 6, outcome: retained})

            assert %{conflict?: true} = apply_dispute_receipts(payment)

            for observation <- [
                  %{data | revision: 4, outcome: retained},
                  %{data | revision: 7, outcome: opposite},
                  %{data | revision: 6, outcome: retained},
                  %{data | revision: 8, outcome: retained, reference: String.duplicate("0", 32)}
                ] do
              set_due_dispute_reply(dispute.id, reply_data, observation)
              assert :ok = FixtureDisputes.read_due(dispute.id)
              assert_receive {^tag, "GET", "/__test/dispute/99", _, _}

              assert %{state: ^terminal, conflict?: true, effect_version: ^conflict_version} =
                       Ash.get!(FixtureDispute, dispute.id, authorize?: false)
            end

            set_due_dispute_reply(dispute.id, reply_data, %{data | revision: 8, outcome: retained})

            {executable, arguments} =
              FreshMix.command(["run", "--no-compile", "test/proof/well223_dispute_restart.exs"])

            diagnostic =
              P815Port.run(
                executable,
                arguments,
                Jason.encode!(%{id: dispute.id, terminal: retained}),
                60_000
              )

            assert_receive {^tag, "GET", "/__test/dispute/99", _, _}

            assert %{
                     state: ^terminal,
                     conflict?: false,
                     revision: 8,
                     effect_version: effect,
                     acknowledged_version: effect
                   } = Ash.get!(FixtureDispute, dispute.id, authorize?: false)

            assert effect == conflict_version + 1
            assert %{status: :ok, cleanup: :confirmed, marker: :well223_completed} = diagnostic

            assert %{state: ^right_state} =
                     Ash.get!(NewYou.Entitlements.PlanRight, right_id, authorize?: false)

            assert 202 ==
                     send_event(key, "fixture.dispute", %{data | revision: 3, outcome: opposite})

            assert %{state: ^terminal, conflict?: false, effect_version: ^effect} =
                     apply_dispute_receipts(payment)

            assert Enum.frequencies_by(dispute_receipts(payment), & &1.state) ==
                     %{applied: 2, conflict: 3, stale: 4}

            assert %{claim_id: nil, state: :reserved, amount_minor: @amount} =
                     read_refund(refund.id)

            assert {:ok, clear?} =
                     NewYou.Commerce.FixtureCorrectionSource.transact(fn ->
                       {:ok, %NewYou.Commerce.Purchase{}} =
                         NewYou.Commerce.FixtureCorrectionSource.lock_purchase(
                           accepted.purchase_id
                         )

                       {:ok, clear?} = FixtureDisputes.refund_clear?(payment.id)
                       clear?
                     end)

            assert clear? == (terminal == :restored)
            refute_received {^tag, "POST", "/refund", _, _}
          end)
        end)
      end)
    end
  end

  test "a stale read token does not erase a committed opposing revision" do
    reply_data = start_supervised!({Agent, fn -> nil end})
    reply = fn conn, _ -> dispute_read_response(conn, Agent.get(reply_data, & &1)) end

    P805.with_fixture(fn ->
      with_paid_plan(reply, fn accepted, payment, _, recipient, _, tag ->
        assert {:ok, [grant]} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
        assert {:ok, %{id: right_id}} = Commerce.deliver_plan_payment_consequence(grant)

        with_signing_key(fn key ->
          data = dispute_data(payment)

          assert 202 ==
                   send_event(key, "fixture.dispute", %{data | revision: 2, outcome: "restored"})

          dispute = apply_dispute_receipts(payment)
          assert 202 == send_event(key, "fixture.dispute", %{data | revision: 3, outcome: "lost"})
          assert %{conflict?: true} = apply_dispute_receipts(payment)
          assert :ok = Commerce.deliver_fixture_dispute(dispute.id)

          set_due_dispute_reply(dispute.id, reply_data, %{data | revision: 10, outcome: "lost"})

          with_paused_dispute_read(dispute.id, fn ->
            # A later lease supersedes the committed read before its worker classifies it.
            set_due_dispute_reply(dispute.id, reply_data, :miss)
            assert :ok = FixtureDisputes.read_due(dispute.id)
          end)

          assert Enum.any?(dispute_receipts(payment), fn receipt ->
                   receipt.source == :read and receipt.revision == 10 and receipt.state == :stale
                 end)

          for revision <- [4, 10] do
            set_due_dispute_reply(dispute.id, reply_data, %{
              data
              | revision: revision,
                outcome: "restored"
            })

            assert :ok = FixtureDisputes.read_due(dispute.id)
            assert :ok = Commerce.deliver_fixture_dispute(dispute.id)

            assert %{state: :suspended} =
                     Ash.get!(NewYou.Entitlements.PlanRight, right_id, authorize?: false)

            assert {:ok, false} = dispute_refund_clear(accepted.purchase_id, payment.id)
          end

          set_due_dispute_reply(dispute.id, reply_data, %{
            data
            | revision: 11,
              outcome: "restored"
          })

          {executable, arguments} =
            FreshMix.command(["run", "--no-compile", "test/proof/well223_dispute_restart.exs"])

          assert %{status: :ok, cleanup: :confirmed, marker: :well223_completed} =
                   P815Port.run(executable, arguments, Jason.encode!(%{id: dispute.id}), 60_000)

          assert %{state: :restored, revision: 11, conflict?: false} =
                   Ash.get!(FixtureDispute, dispute.id, authorize?: false)

          assert [%{id: ^right_id, state: :held_unconsumed}] = plan_rights(recipient)
          assert {:ok, true} = dispute_refund_clear(accepted.purchase_id, payment.id)
          refute_received {^tag, "POST", "/refund", _, _}
        end)
      end)
    end)
  end

  test "committed contradictory terminal receipts keep the right suspended in both worker orders" do
    reply_data = start_supervised!({Agent, fn -> nil end})
    reply = fn conn, _ -> dispute_read_response(conn, Agent.get(reply_data, & &1)) end

    for initial <- [:under_review, :unbound], first <- [:lost, :restored] do
      P805.with_fixture(fn ->
        with_paid_plan(reply, fn accepted, payment, _, recipient, _, _ ->
          assert {:ok, [grant]} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
          assert {:ok, %{id: right_id}} = Commerce.deliver_plan_payment_consequence(grant)

          with_signing_key(fn key ->
            data = dispute_data(payment)

            if initial == :under_review do
              assert 202 == send_event(key, "fixture.dispute", %{data | outcome: "under_review"})
              dispute = apply_dispute_receipts(payment)
              assert :ok = Commerce.deliver_fixture_dispute(dispute.id)
            end

            assert 202 ==
                     send_event(key, "fixture.dispute", %{data | revision: 2, outcome: "lost"})

            assert 202 ==
                     send_event(key, "fixture.dispute", %{data | revision: 3, outcome: "restored"})

            pending = Enum.filter(dispute_receipts(payment), &(&1.state == :pending))

            assert {[first_receipt], [second_receipt]} =
                     Enum.split_with(pending, &(&1.outcome == first))

            for receipt <- [first_receipt, second_receipt] do
              assert :ok = Commerce.apply_fixture_dispute_receipt(receipt.id)
              state = if initial == :unbound, do: :unresolved, else: initial

              assert {:ok, %{id: id, state: ^state, conflict?: true}} =
                       FixtureDisputes.read_identity(data.id)

              assert :ok = Commerce.deliver_fixture_dispute(id)
              assert [] = plan_rights(recipient)

              assert %{state: :suspended} =
                       Ash.get!(NewYou.Entitlements.PlanRight, right_id, authorize?: false)

              assert {:ok, false} = dispute_refund_clear(accepted.purchase_id, payment.id)
            end

            assert {:ok, %{id: id}} = FixtureDisputes.read_identity(data.id)

            # Equal-revision evidence cannot adjudicate the worker conflict.
            set_due_dispute_reply(id, reply_data, %{data | revision: 3, outcome: "lost"})
            assert :ok = FixtureDisputes.read_due(id)
            assert {:ok, %{conflict?: true}} = FixtureDisputes.read_identity(data.id)

            set_due_dispute_reply(id, reply_data, %{data | revision: 4, outcome: "lost"})
            assert :ok = FixtureDisputes.read_due(id)
            assert :ok = Commerce.deliver_fixture_dispute(id)

            assert {:ok, %{state: :lost, conflict?: false}} =
                     FixtureDisputes.read_identity(data.id)

            assert %{state: :ended} =
                     Ash.get!(NewYou.Entitlements.PlanRight, right_id, authorize?: false)

            assert {:ok, false} = dispute_refund_clear(accepted.purchase_id, payment.id)
          end)
        end)
      end)
    end
  end

  defp with_paused_dispute_read(id, while_paused) do
    parent = self()
    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(
        handler,
        [:new_you, :commerce, :fixture_dispute, :checkpoint],
        fn _, _, metadata, _ ->
          if metadata.stage == :evidence_committed and self() != parent do
            send(parent, {:dispute_read_committed, self()})

            receive do
              :classify_dispute_read -> :ok
            after
              5_000 -> raise "Timed out waiting to classify the dispute read"
            end
          end
        end,
        nil
      )

    reader =
      Task.async(fn -> Sandbox.unboxed_run(Repo, fn -> FixtureDisputes.read_due(id) end) end)

    try do
      assert_receive {:dispute_read_committed, pid}, 3_000
      assert pid == reader.pid
      while_paused.()
      send(pid, :classify_dispute_read)
      assert :ok = Task.await(reader)
    after
      :telemetry.detach(handler)
      Task.shutdown(reader, :brutal_kill)
    end
  end

  defp dispute_refund_clear(purchase_id, payment_id) do
    source = NewYou.Commerce.FixtureCorrectionSource

    source.transact(fn ->
      assert {:ok, %NewYou.Commerce.Purchase{}} = source.lock_purchase(purchase_id)
      assert {:ok, clear?} = FixtureDisputes.refund_clear?(payment_id)
      clear?
    end)
  end

  defp set_due_dispute_reply(id, reply_data, observation) do
    make_dispute_due(id, 6)
    Agent.update(reply_data, fn _ -> observation end)
  end

  test "known reads count one request across contenders and retain a retry after miss and throttle" do
    P805.with_fixture(fn ->
      response = start_supervised!({Agent, fn -> :miss end})
      reply = fn conn, _ -> dispute_read_response(conn, Agent.get(response, & &1)) end

      with_paid_plan(reply, fn _, payment, _, _, _, tag ->
        with_signing_key(fn key ->
          data = dispute_data(payment)
          assert 202 == send_event(key, "fixture.dispute", data)
          dispute = apply_dispute_receipts(payment)

          assert [:ok, :ok] =
                   compete_on_connections(fn -> FixtureDisputes.read_due(dispute.id) end)

          assert_receive {^tag, "GET", "/__test/dispute/99", _, _}
          refute_received {^tag, "GET", "/__test/dispute/99", _, _}

          assert %{verify_round: 1, state: :contested} =
                   Ash.get!(FixtureDispute, dispute.id, authorize?: false)

          cases = [:throttle, :timeout, %{data | id: "55", outcome: "lost", revision: 4}]

          for {kind, round} <- Enum.with_index(cases, 1) do
            Agent.update(response, fn _ -> kind end)
            make_dispute_due(dispute.id, round)
            assert :ok = FixtureDisputes.read_due(dispute.id)
            assert_receive {^tag, "GET", "/__test/dispute/99", _, _}

            assert %{verify_after: due, state: :contested} =
                     Ash.get!(FixtureDispute, dispute.id, authorize?: false)

            if kind == :throttle, do: assert(DateTime.diff(due, DateTime.utc_now()) in 175..180)
          end

          assert [_webhook] = dispute_receipts(payment)
          assert :ok = FixtureDisputes.read_due(dispute.id)
          refute_received {^tag, "GET", "/__test/dispute/99", _, _}
        end)
      end)
    end)
  end

  test "known-dispute GET sends no request to a replacement TLS listener on the original port" do
    P805.with_fixture(fn ->
      {case_id, pin} =
        with_paid_plan(fn _, payment, _, _, listener, _ ->
          with_signing_key(fn key ->
            assert 202 == send_event(key, "fixture.dispute", dispute_data(payment))
            {apply_dispute_receipts(payment).id, listener}
          end)
        end)

      HostedCheckoutReceiver.with_bound_receiver(
        &default_refund_reply/2,
        fn replacement, tag ->
          assert replacement.port == pin.port
          refute replacement.certificate == pin.certificate
          assert :ok = FixtureDisputes.read_due(case_id)

          assert %{state: :contested, verify_round: 1} =
                   Ash.get!(FixtureDispute, case_id, authorize?: false)

          refute_receive {^tag, "GET", "/__test/dispute/99", _, _}, 30
        end,
        port: pin.port
      )
    end)
  end

  test "fixture cleanup removes only its dispute rows and jobs from the shared queue" do
    worker = NewYou.Commerce.Workers.ProcessFixtureDisputeReceipt

    sentinel =
      Sandbox.unboxed_run(Repo, fn ->
        Oban.insert!(worker.new(%{"primary_key" => %{"id" => uuid()}}))
      end)

    try do
      {case_id, receipt_id, job_id} =
        P805.with_fixture(fn ->
          with_paid_plan(fn _, payment, _, _, _, _ ->
            with_signing_key(fn key ->
              assert 202 == send_event(key, "fixture.dispute", dispute_data(payment))
              assert [receipt] = dispute_receipts(payment)
              dispute = apply_dispute_receipts(payment)
              job = Oban.insert!(worker.new(%{"primary_key" => %{"id" => receipt.id}}))
              {dispute.id, receipt.id, job.id}
            end)
          end)
        end)

      Sandbox.unboxed_run(Repo, fn ->
        assert {:ok, nil} = Ash.get(FixtureDispute, case_id, error?: false, authorize?: false)

        assert {:ok, nil} =
                 Ash.get(FixtureDisputeReceipt, receipt_id, error?: false, authorize?: false)

        refute Repo.get(Oban.Job, job_id)
        assert Repo.get(Oban.Job, sentinel.id)
      end)
    after
      Sandbox.unboxed_run(Repo, fn -> Oban.delete_job(sentinel.id) end)
    end
  end

  defp dispute_read_response(conn, :miss), do: Plug.Conn.send_resp(conn, 404, "")

  defp dispute_read_response(conn, :throttle) do
    conn |> Plug.Conn.put_resp_header("retry-after", "180") |> Plug.Conn.send_resp(429, "")
  end

  defp dispute_read_response(conn, :timeout) do
    Process.sleep(750)
    Plug.Conn.send_resp(conn, 200, "{}")
  end

  defp dispute_read_response(conn, data),
    do: HostedCheckoutReceiver.json(conn, 200, %{data: data})

  defp race_corrections(kind, stage, winning_operation, competing_operation) do
    parent = self()
    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(
        handler,
        [:new_you, :commerce, kind, :checkpoint],
        fn _, _, metadata, _ ->
          if metadata.stage == stage do
            send(parent, {:locked_correction, self()})

            receive do
              :release_correction -> :ok
            after
              5_000 -> raise "Timed out while holding the correction lock"
            end
          end
        end,
        nil
      )

    try do
      winner = Task.async(fn -> run_contender(parent, winning_operation) end)
      assert_receive {:contender, first, backend_a}
      send(first, :go)
      assert_receive {:locked_correction, ^first}

      competitor = Task.async(fn -> run_contender(parent, competing_operation) end)
      assert_receive {:contender, second, backend_b}
      refute backend_a == backend_b
      send(second, :go)
      assert blocked_by?(backend_b, backend_a, 80)
      send(first, :release_correction)
      {Task.await(winner), Task.await(competitor)}
    after
      :telemetry.detach(handler)
    end
  end

  defp blocked_by?(_waiter, _blocker, 0), do: false

  defp blocked_by?(waiter, blocker, attempts) do
    case Repo.query!("SELECT $2::integer = ANY(pg_blocking_pids($1))", [waiter, blocker]).rows do
      [[true]] ->
        true

      [[false]] ->
        Process.sleep(20)
        blocked_by?(waiter, blocker, attempts - 1)
    end
  end

  defp make_dispute_due(id, round) do
    Ash.update!(
      Ash.get!(FixtureDispute, id, authorize?: false),
      %{verify_after: DateTime.add(DateTime.utc_now(), -1), verify_round: round},
      action: :reserve_read,
      authorize?: false
    )
  end

  defp dispute_data(payment) do
    %{reference: reference} =
      Ash.get!(NewYou.Commerce.HostedPaymentReceipt, payment.fixture_receipt_id,
        authorize?: false
      )

    %{
      reference: reference,
      transaction: payment.fixture_transaction_id,
      id: "99",
      amount: @amount,
      currency: "ZAR",
      scope: "newyou_dispute_fixture",
      revision: 1,
      outcome: "contested"
    }
  end

  defp plan_rights(recipient) do
    assert {:ok, rights} = Entitlements.plan_rights(recipient.credentials)
    rights
  end

  defp apply_dispute_receipts(payment) do
    payment_id = payment.id

    for receipt <- dispute_receipts(payment) do
      assert :ok = Commerce.apply_fixture_dispute_receipt(receipt.id)
    end

    Ash.read_one!(Ash.Query.filter(FixtureDispute, payment_id == ^payment_id), authorize?: false)
  end

  defp dispute_receipts(payment) do
    FixtureDisputeReceipt
    |> Ash.Query.filter(payment_id == ^payment.id)
    |> Ash.Query.sort(:id)
    |> Ash.read!(authorize?: false)
  end

  test "only qualified authorization of the immutable hosted source establishes owed money" do
    P805.with_fixture(fn ->
      with_paid_plan(fn accepted, payment, payer, recipient, _listener, _tag ->
        fields = refund_fields(accepted, payment, payer, recipient)

        assert {:error, :refund_unavailable} = request(payer.credentials, fields)
        assert {:error, :refund_unavailable} = request(recipient.credentials, proof(fields))

        for change <- [
              %{scope: :synthetic_correction},
              %{payment_id: uuid()},
              %{quote_id: nil},
              %{recipient_id: payer.account_id},
              %{transaction_id: "18446744073709551613"},
              %{amount_minor: @amount - 1},
              %{currency: "USD"},
              %{allocation: :assessment}
            ] do
          assert {:error, :refund_unavailable} =
                   request(payer.credentials, proof(Map.merge(fields, change)))
        end

        assert [{:ok, owed}, {:ok, simultaneous}] =
                 compete_on_connections(fn -> request(payer.credentials, proof(fields)) end)

        assert simultaneous.id == owed.id
        assert owed.state == :owed
        assert owed.payment_id == payment.id
        assert owed.payer_id == payer.account_id
        assert owed.transaction_id == @transaction
        assert owed.amount_minor == @amount

        assert {:ok, replay} = request(payer.credentials, proof(fields))
        assert replay.id == owed.id
        assert replay.reference == owed.reference

        admit_plan = fn -> request(payer.credentials, proof(fields)) end

        for allocation <- [:assessment, :excess] do
          deny_other = fn ->
            request(payer.credentials, proof(%{fields | allocation: allocation}))
          end

          assert [{:ok, %{id: id}}, {:error, :refund_unavailable}] =
                   compete_on_connections([admit_plan, deny_other])

          assert id == owed.id
        end

        assert [%{id: id, allocation: :plan, amount_minor: @amount}] = purchase_refunds(accepted)
        assert id == owed.id
      end)
    end)
  end

  test "independent PostgreSQL dispatch contenders commit one immutable claim before POST" do
    P805.with_fixture(fn ->
      with_paid_plan(fn accepted, payment, payer, recipient, _listener, tag ->
        assert function_exported?(Commerce, :dispatch_fixture_refund, 2)
        fields = refund_fields(accepted, payment, payer, recipient)
        assert {:ok, owed} = request(payer.credentials, proof(fields))

        assert {:ok, %{state: :reserved}} =
                 Commerce.reserve_fixture_refund(payer.credentials, owed.id)

        assert {:error, :refund_unavailable} =
                 Commerce.dispatch_fixture_refund(recipient.credentials, owed.id)

        assert {:ok, :rolled_back} =
                 Ash.transact(NewYou.Commerce.FixtureRefund, fn ->
                   assert {:error, :refund_unavailable} =
                            Commerce.dispatch_fixture_refund(payer.credentials, owed.id)

                   :rolled_back
                 end)

        refute_received {^tag, "POST", "/refund", _, _}

        assert {:error, :refund_unavailable} =
                 Task.async(fn ->
                   :ok = Sandbox.checkout(Repo)

                   try do
                     Commerce.dispatch_fixture_refund(payer.credentials, owed.id)
                   after
                     Sandbox.checkin(Repo)
                   end
                 end)
                 |> Task.await()

        assert %{state: :reserved, claim_id: nil} = read_refund(owed.id)
        refute_received {^tag, "POST", "/refund", _, _}

        assert [{:ok, %{state: :unresolved}}, {:ok, %{state: :unresolved}}] =
                 compete_on_connections(fn ->
                   Commerce.dispatch_fixture_refund(payer.credentials, owed.id)
                 end)

        assert_receive {^tag, "POST", "/refund", _,
                        %{
                          "reference" => reference,
                          "transaction" => @transaction,
                          "amount" => @amount,
                          "currency" => "ZAR"
                        }}

        assert reference == owed.reference
        assert_received {:refund_at_post, %{state: :unresolved, claim_id: claim_id}}
        assert is_binary(claim_id)
        refute_receive {^tag, "POST", "/refund", _, _}, 30

        assert {:ok, %{claim_id: ^claim_id, reference: ^reference}} =
                 Commerce.dispatch_fixture_refund(payer.credentials, owed.id)

        refute_received {^tag, "POST", "/refund", _, _}
      end)
    end)
  end

  test "the same payer can have distinct equal-value purchases and independently bounded refunds" do
    P805.with_fixture(fn ->
      with_paid_plan(fn first, original, payer, recipient, _, _ ->
        first_fields = refund_fields(first, original, payer, recipient)
        assert {:ok, first_owed} = request(payer.credentials, proof(first_fields))

        with_paid_plan(payer, recipient, "18446744073709551612", &default_refund_reply/2, fn
          second, distinct, ^payer, ^recipient, _, _ ->
            second_fields = refund_fields(second, distinct, payer, recipient)

            assert {:error, :refund_unavailable} =
                     request(payer.credentials, proof(%{second_fields | payment_id: original.id}))

            assert {:ok, second_owed} = request(payer.credentials, proof(second_fields))
            assert first_owed.amount_minor == second_owed.amount_minor
            refute first_owed.payment_id == second_owed.payment_id
            refute first_owed.reference == second_owed.reference

            assert {:ok, [first_grant]} =
                     Commerce.open_plan_payment_consequences(first.purchase_id)

            assert {:ok, [second_grant]} =
                     Commerce.open_plan_payment_consequences(second.purchase_id)

            assert {:ok, %{id: first_right}} =
                     Commerce.deliver_plan_payment_consequence(first_grant)

            assert {:ok, %{id: second_right}} =
                     Commerce.deliver_plan_payment_consequence(second_grant)

            with_signing_key(fn key ->
              assert 202 == send_event(key, "fixture.dispute", dispute_data(original))
              dispute = apply_dispute_receipts(original)
              assert :ok = Commerce.deliver_fixture_dispute(dispute.id)

              assert 400 == send_event(key, "fixture.dispute", dispute_data(distinct))
              assert [] = dispute_receipts(distinct)
              assert [%{id: ^second_right}] = plan_rights(recipient)

              assert %{state: :suspended} =
                       Ash.get!(NewYou.Entitlements.PlanRight, first_right, authorize?: false)
            end)
        end)
      end)
    end)
  end

  defp compete_on_connections(fun) when is_function(fun), do: compete_on_connections([fun, fun])

  defp compete_on_connections(funs) do
    funs |> start_independent_contenders() |> Task.await_many()
  end

  defp start_independent_contenders(funs) do
    parent = self()

    contenders = for fun <- funs, do: Task.async(fn -> run_contender(parent, fun) end)

    assert_receive {:contender, first, backend1}
    assert_receive {:contender, second, backend2}
    assert backend1 != backend2
    send(first, :go)
    send(second, :go)

    contenders
  end

  test "provider refund identity bound to one claim quarantines a second claimant's receipt" do
    P805.with_fixture(fn ->
      with_two_claims(fn first, second, recipient ->
        with_signing_key(fn key ->
          original = processed_receipt(key, first)
          conflict = processed_receipt(key, second)
          assert :ok = Commerce.apply_fixture_refund_receipt(original.id)
          assert :ok = Commerce.apply_fixture_refund_receipt(conflict.id)
          assert :ok = Commerce.apply_fixture_refund_receipt(conflict.id)
          assert_one_refund_effect(first, second, original, conflict, recipient)
        end)
      end)
    end)
  end

  test "competing SQL claims sharing a provider refund ID converge on one effect and quarantine" do
    P805.with_fixture(fn ->
      with_two_claims(fn first, second, recipient ->
        with_signing_key(fn key ->
          receipts = [processed_receipt(key, first), processed_receipt(key, second)]

          assert [:ok, :ok] = race_provider_bindings(receipts)

          [{winner, applied}, {loser, conflict}] =
            [first, second]
            |> Enum.zip(receipts)
            |> Enum.sort_by(fn {refund, _} -> read_refund(refund.id).state end)

          assert_one_refund_effect(winner, loser, applied, conflict, recipient)
        end)
      end)
    end)
  end

  defp race_provider_bindings(receipts) do
    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(
        handler,
        [:new_you, :commerce, :fixture_refund, :checkpoint],
        &__MODULE__.pause_provider_binding/4,
        self()
      )

    try do
      tasks = receipts |> Enum.map(&provider_binding/1) |> start_independent_contenders()
      assert_receive {:provider_binding_ready, first}, 3_000
      assert_receive {:provider_binding_ready, second}, 3_000
      assert first != second
      send(first, :bind)
      send(second, :bind)
      Task.await_many(tasks)
    after
      :telemetry.detach(handler)
    end
  end

  defp provider_binding(receipt) do
    fn ->
      Process.put({__MODULE__, :provider_binding}, true)
      Commerce.apply_fixture_refund_receipt(receipt.id)
    end
  end

  @doc false
  def pause_provider_binding(_, _, %{stage: :provider_identity_available}, observer) do
    if Process.get({__MODULE__, :provider_binding}) do
      send(observer, {:provider_binding_ready, self()})

      receive do
        :bind -> :ok
      after
        5_000 -> :timeout
      end
    end
  end

  def pause_provider_binding(_, _, _, _), do: :ok

  defp assert_one_refund_effect(winner, loser, applied, conflict, recipient) do
    assert %{state: :processed, processed_receipt_id: applied_id} = read_refund(winner.id)
    assert applied_id == applied.id

    assert %{state: :unresolved, provider_refund_id: nil, processed_receipt_id: nil} =
             read_refund(loser.id)

    assert [%{state: :quarantined, id: conflict_id}] = refund_receipts(loser.reference)
    assert conflict_id == conflict.id

    assert %{failure: 0, discard: 0} =
             AshOban.Test.schedule_and_run_triggers(
               {NewYou.Commerce.FixtureRefundReceipt, :process}
             )

    assert [] ==
             Repo.query!(
               "SELECT id FROM oban_jobs WHERE worker = $1 AND args->'primary_key'->>'id' = $2",
               ["NewYou.Commerce.Workers.ProcessFixtureRefundReceipt", conflict.id]
             ).rows

    assert :ok = Commerce.deliver_fixture_refund(winner.id)
    assert {:error, :grant_unavailable} = Entitlements.apply_fixture_refund(loser.id)

    assert {:ok, [winner_grant]} = Commerce.open_plan_payment_consequences(winner.purchase_id)
    assert {:ok, [loser_grant]} = Commerce.open_plan_payment_consequences(loser.purchase_id)
    assert {:ok, :withheld} = Commerce.deliver_plan_payment_consequence(winner_grant)
    assert {:ok, %{id: legitimate}} = Commerce.deliver_plan_payment_consequence(loser_grant)

    assert {:ok, [%{id: ^legitimate, payment_id: payment}]} =
             Entitlements.plan_rights(recipient.credentials)

    assert payment == loser.payment_id
  end

  defp with_two_claims(fun) do
    with_paid_plan(fn accepted, payment, payer, recipient, _, first_tag ->
      first = dispatch_claim(accepted, payment, payer, recipient, first_tag)

      with_paid_plan(payer, recipient, "18446744073709551612", &default_refund_reply/2, fn other,
                                                                                           collection,
                                                                                           _,
                                                                                           _,
                                                                                           _,
                                                                                           second_tag ->
        second = dispatch_claim(other, collection, payer, recipient, second_tag)
        fun.(first, second, recipient)
      end)
    end)
  end

  defp dispatch_claim(accepted, payment, payer, recipient, tag) do
    assert {:ok, owed} =
             request(payer.credentials, proof(refund_fields(accepted, payment, payer, recipient)))

    assert {:ok, _} = Commerce.reserve_fixture_refund(payer.credentials, owed.id)
    assert {:ok, claimed} = Commerce.dispatch_fixture_refund(payer.credentials, owed.id)
    assert_receive {^tag, "POST", "/refund", _, _}
    assert_receive {:refund_at_post, _}
    claimed
  end

  defp processed_receipt(key, refund) do
    assert 202 ==
             send_evidence(
               key,
               %{refund_data(refund) | transaction: refund.transaction_id},
               "processed"
             )

    assert [receipt] = refund_receipts(refund.reference)
    receipt
  end

  defp run_contender(parent, fun) do
    Sandbox.unboxed_run(Repo, fn ->
      [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
      send(parent, {:contender, self(), backend})

      receive do
        :go -> fun.()
      end
    end)
  end

  test "process loss before and after commit never leaves another POST opportunity" do
    P805.with_fixture(fn ->
      with_paid_plan(fn accepted, payment, payer, recipient, _listener, tag ->
        fields = refund_fields(accepted, payment, payer, recipient)
        assert {:ok, owed} = request(payer.credentials, proof(fields))
        assert {:ok, _} = Commerce.reserve_fixture_refund(payer.credentials, owed.id)

        cut_dispatch(payer.credentials, owed.id, :claim_written)
        assert %{state: :reserved, claim_id: nil} = read_refund(owed.id)
        refute_received {^tag, "POST", "/refund", _, _}

        cut_dispatch(payer.credentials, owed.id, :claim_committed)
        assert %{state: :unresolved, claim_id: claim, reference: reference} = read_refund(owed.id)
        assert is_binary(claim)

        assert {:ok, %{state: :unresolved, claim_id: ^claim, reference: ^reference}} =
                 Commerce.dispatch_fixture_refund(payer.credentials, owed.id)

        refute_received {^tag, "POST", "/refund", _, _}

        make_refund_due(owed.id)
        assert :ok = NewYou.Commerce.FixtureRefunds.read_due(owed.id)
        assert_receive {^tag, "GET", "/refund/" <> ^reference, _, _}
        assert %{state: :unresolved, claim_id: ^claim} = read_refund(owed.id)
      end)
    end)
  end

  test "a replacement listener on the original port receives neither refund POST nor read" do
    P805.with_fixture(fn ->
      {refund, actor, listener} =
        with_paid_plan(fn accepted, payment, payer, recipient, listener, _ ->
          fields = refund_fields(accepted, payment, payer, recipient)
          assert {:ok, owed} = request(payer.credentials, proof(fields))
          assert {:ok, _} = Commerce.reserve_fixture_refund(payer.credentials, owed.id)
          {owed, payer.credentials, listener}
        end)

      HostedCheckoutReceiver.with_bound_receiver(
        &default_refund_reply/2,
        fn replacement, tag ->
          assert listener.port == replacement.port
          refute listener.certificate == replacement.certificate
          assert {:ok, %{state: :unresolved}} = Commerce.dispatch_fixture_refund(actor, refund.id)
          make_refund_due(refund.id)
          assert :ok = NewYou.Commerce.FixtureRefunds.read_due(refund.id)
          assert %{state: :unresolved, verify_round: 1} = read_refund(refund.id)
          refute_receive {^tag, _, _, _, _}, 40
        end,
        port: listener.port
      )
    end)
  end

  defp cut_dispatch(credentials, refund_id, stage) do
    cut_refund_work(stage, fn -> Commerce.dispatch_fixture_refund(credentials, refund_id) end)
  end

  defp cut_refund_work(stage, work) do
    cut_work(:fixture_refund, stage, work)
  end

  defp cut_work(fixture_kind, stage, work) do
    handler_id = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(
        handler_id,
        [:new_you, :commerce, fixture_kind, :checkpoint],
        &kill_at_checkpoint/4,
        stage
      )

    try do
      {pid, monitor} =
        spawn_monitor(fn ->
          Process.put({__MODULE__, :cut_refund}, true)

          Sandbox.unboxed_run(Repo, work)
        end)

      assert_receive {:DOWN, ^monitor, :process, ^pid, :killed}, 3_000
    after
      :telemetry.detach(handler_id)
    end
  end

  defp kill_at_checkpoint(_, _, %{stage: stage}, expected) do
    if stage == expected and Process.get({__MODULE__, :cut_refund}),
      do: Process.exit(self(), :kill)
  end

  test "durable authenticated evidence is distinct from the single processed effect" do
    P805.with_fixture(fn ->
      with_paid_plan(fn accepted, payment, payer, recipient, _listener, tag ->
        fields = refund_fields(accepted, payment, payer, recipient)
        assert {:ok, owed} = request(payer.credentials, proof(fields))
        assert {:ok, [grant]} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
        assert {:ok, %{id: right_id}} = Commerce.deliver_plan_payment_consequence(grant)
        assert {:ok, _} = Commerce.reserve_fixture_refund(payer.credentials, owed.id)

        assert {:ok, %{state: :unresolved}} =
                 Commerce.dispatch_fixture_refund(payer.credentials, owed.id)

        assert_receive {^tag, "POST", "/refund", _, _}
        assert_receive {:refund_at_post, _}

        key = :crypto.strong_rand_bytes(32)
        previous = Application.get_env(:new_you, :fixture_webhook_key)
        Application.put_env(:new_you, :fixture_webhook_key, key)

        try do
          data = refund_data(owed)
          assert 401 == send_evidence(key, data, "processed", authenticated?: false)

          P805.with_rejected_insert("commerce_fixture_refund_receipts", fn reached? ->
            assert 503 == send_evidence(key, data, "processed")
            assert reached?.()
            assert [] == refund_receipts(owed.reference)
          end)

          assert 202 == send_evidence(key, %{data | amount: @amount - 1}, "processed")
          assert 202 == send_evidence(key, %{data | transaction: "123"}, "processed")
          assert 202 == send_evidence(key, data, "processing")
          assert %{state: :unresolved} = read_refund(owed.id)
          process_evidence(owed.reference)
          assert %{state: :processing, processed_at: nil} = read_refund(owed.id)

          assert 202 == send_evidence(key, data, "pending")
          process_evidence(owed.reference)
          assert %{state: :processing, processed_at: nil} = read_refund(owed.id)

          assert 202 == send_evidence(key, data, "needs_attention")
          process_evidence(owed.reference)
          assert %{state: :needs_attention, processed_at: nil} = read_refund(owed.id)

          assert 202 == send_evidence(key, data, "insufficient_balance")
          process_evidence(owed.reference)

          assert %{state: :insufficient_balance, processed_at: nil, amount_minor: @amount} =
                   read_refund(owed.id)

          assert 202 == send_evidence(key, data, "processed")
          assert 202 == send_evidence(key, data, "processed")
          assert 202 == send_evidence(key, %{data | id: "555"}, "processed")
          process_evidence(owed.reference)

          assert %{state: :processed, processed_at: processed_at, processed_receipt_id: proof_id} =
                   read_refund(owed.id)

          assert %DateTime{} = processed_at
          assert is_binary(proof_id)

          assert {:ok, [%{id: ^right_id, state: :held_unconsumed}]} =
                   Entitlements.plan_rights(recipient.credentials)

          assert :ok =
                   SyntheticSuppression.suppress(
                     proof(%{scope: :completed_deletion, subject_id: recipient.account_id})
                   )

          assert :ok = Entitlements.apply_fixture_refund(owed.id)
          assert %{acknowledged_at: nil} = read_refund(owed.id)
          run_recovery(owed.id, "acknowledge")
          assert %{acknowledged_at: %DateTime{}} = read_refund(owed.id)
          assert {:ok, :withheld} = Commerce.deliver_plan_payment_consequence(grant)
          assert {:ok, []} = Entitlements.plan_rights(recipient.credentials)

          assert %{state: :ended, payment_id: payment_id} =
                   Ash.get!(Entitlements.PlanRight, right_id, authorize?: false)

          assert payment_id == payment.id
          assert :ok = Commerce.apply_hosted_payment_evidence(payment.fixture_receipt_id)
          assert {:ok, []} = Entitlements.plan_rights(recipient.credentials)

          assert 202 == send_evidence(key, data, "failed")
          process_evidence(owed.reference)

          assert %{
                   state: :processed,
                   processed_at: ^processed_at,
                   processed_receipt_id: ^proof_id
                 } =
                   read_refund(owed.id)
        after
          if previous,
            do: Application.put_env(:new_you, :fixture_webhook_key, previous),
            else: Application.delete_env(:new_you, :fixture_webhook_key)
        end
      end)
    end)
  end

  test "fresh owning work reads only the original reference after a committed POST loses its response" do
    P805.with_fixture(fn ->
      provider_id = "18446744073709551615"

      refund_reply = fn
        %{method: "POST"} = conn, _ ->
          Process.sleep(750)
          Plug.Conn.send_resp(conn, 202, "")

        %{method: "GET", path_info: ["refund", reference]} = conn, _ ->
          HostedCheckoutReceiver.json(conn, 200, %{
            status: true,
            data: %{
              reference: reference,
              transaction: @transaction,
              id: provider_id,
              amount: @amount,
              currency: "ZAR",
              provider: "paystack",
              integration: "local_fixture",
              environment: "test",
              status: "processed"
            }
          })
      end

      with_paid_plan(refund_reply, fn accepted, payment, payer, recipient, _, tag ->
        fields = refund_fields(accepted, payment, payer, recipient)
        assert {:ok, owed} = request(payer.credentials, proof(fields))
        assert {:ok, _} = Commerce.reserve_fixture_refund(payer.credentials, owed.id)

        assert {:ok, %{state: :unresolved, reference: reference}} =
                 Commerce.dispatch_fixture_refund(payer.credentials, owed.id)

        assert_receive {^tag, "POST", "/refund", _, %{"reference" => ^reference}}
        assert_receive {:refund_at_post, _}

        assert {:ok, %{claim_id: claim_id}} =
                 Commerce.dispatch_fixture_refund(payer.credentials, owed.id)

        assert Code.ensure_loaded?(NewYou.Commerce.Workers.ReadFixtureRefund)
        read_job_args = %{"primary_key" => %{"id" => owed.id}}
        refute_enqueued(worker: NewYou.Commerce.Workers.ReadFixtureRefund, args: read_job_args)
        make_refund_due(owed.id, %{verify_round: 5})

        cut_refund_work(:read_reserved, fn -> NewYou.Commerce.FixtureRefunds.read_due(owed.id) end)

        assert %{verify_round: 6, verify_after: %DateTime{}, claim_id: ^claim_id} =
                 read_refund(owed.id)

        refute_received {^tag, "GET", "/refund/" <> ^reference, _, _}
        make_refund_due(owed.id)

        P805.with_rejected_insert("commerce_fixture_refund_receipts", fn reached? ->
          assert %{discard: 1, queues_not_drained: []} =
                   AshOban.Test.schedule_and_run_triggers(
                     {NewYou.Commerce.FixtureRefund, :read_due}
                   )

          assert reached?.()
          assert_receive {^tag, "GET", "/refund/" <> ^reference, _, _}
        end)

        assert [] == refund_receipts(reference)

        assert %{state: :unresolved, verify_round: 6, verify_after: %DateTime{}} =
                 read_refund(owed.id)

        make_refund_due(owed.id)
        run_recovery(owed.id)

        assert_receive {^tag, "GET", "/refund/" <> ^reference, _, _}

        assert %{
                 state: :processed,
                 provider_refund_id: ^provider_id,
                 processed_receipt_id: applied,
                 claim_id: ^claim_id,
                 reference: ^reference,
                 verify_after: nil
               } =
                 read_refund(owed.id)

        with_signing_key(fn key ->
          assert 202 == send_evidence(key, refund_data(owed), "processed")
          process_evidence(reference)
          assert %{processed_receipt_id: ^applied} = read_refund(owed.id)

          assert Enum.map(refund_receipts(reference), &{&1.source, &1.state}) ==
                   [{:read, :applied}, {:webhook, :stale}]
        end)

        assert {:ok, [grant]} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
        assert {:ok, :withheld} = Commerce.deliver_plan_payment_consequence(grant)
        assert {:ok, []} = Entitlements.plan_rights(recipient.credentials)
        refute_received {^tag, "POST", "/refund", _, _}
      end)
    end)
  end

  test "independent webhook and pinned-read workers converge on one processed effect" do
    P805.with_fixture(fn ->
      parent = self()

      replies = fn
        %{method: "GET", path_info: ["refund", reference]} = conn, _ ->
          send(parent, {:read_waiting, self()})

          receive do
            :reply ->
              data = refund_data(%{reference: reference}) |> Map.put(:status, "processed")
              HostedCheckoutReceiver.json(conn, 200, %{status: true, data: data})
          after
            500 -> Plug.Conn.send_resp(conn, 500, "")
          end

        conn, data ->
          default_refund_reply(conn, data)
      end

      with_paid_plan(replies, fn accepted, payment, payer, recipient, _, tag ->
        fields = refund_fields(accepted, payment, payer, recipient)
        assert {:ok, owed} = request(payer.credentials, proof(fields))
        assert {:ok, _} = Commerce.reserve_fixture_refund(payer.credentials, owed.id)
        assert {:ok, _} = Commerce.dispatch_fixture_refund(payer.credentials, owed.id)
        assert_receive {^tag, "POST", "/refund", _, _}
        assert_receive {:refund_at_post, _}

        receipt =
          with_signing_key(fn key ->
            assert 202 == send_evidence(key, refund_data(owed), "processed")
            assert [receipt] = refund_receipts(owed.reference)
            receipt
          end)

        make_refund_due(owed.id)

        read =
          Task.async(fn ->
            run_contender(parent, fn -> NewYou.Commerce.FixtureRefunds.read_due(owed.id) end)
          end)

        webhook =
          Task.async(fn ->
            run_contender(parent, fn -> Commerce.apply_fixture_refund_receipt(receipt.id) end)
          end)

        read_pid = read.pid
        webhook_pid = webhook.pid
        assert_receive {:contender, ^read_pid, read_backend}
        assert_receive {:contender, ^webhook_pid, webhook_backend}
        assert read_backend != webhook_backend
        send(read_pid, :go)
        assert_receive {:read_waiting, listener}
        send(webhook_pid, :go)
        send(listener, :reply)
        assert [:ok, :ok] = Task.await_many([read, webhook])

        assert %{state: :processed, processed_receipt_id: applied} = read_refund(owed.id)
        rows = refund_receipts(owed.reference)
        assert Enum.frequencies_by(rows, & &1.state) == %{applied: 1, stale: 1}
        assert Enum.map(rows, & &1.source) == [:webhook, :read]
        assert Enum.find(rows, &(&1.id == applied)).state == :applied
      end)
    end)
  end

  test "a separately qualified excess collection creates one exact payer claim and leaves the paid right" do
    P805.with_fixture(fn ->
      with_paid_plan(fn accepted, payment, payer, recipient, _listener, tag ->
        assert {:ok, [consequence]} =
                 Commerce.open_plan_payment_consequences(accepted.purchase_id)

        assert {:ok, %{id: right_id}} = Commerce.deliver_plan_payment_consequence(consequence)

        original =
          Ash.get!(NewYou.Commerce.HostedPaymentReceipt, payment.fixture_receipt_id,
            authorize?: false
          )

        with_signing_key(fn key ->
          excess_id = "18446744073709551613"

          data = %{
            reference: original.reference,
            id: excess_id,
            amount: @amount,
            currency: "ZAR",
            provider: "paystack",
            integration: "local_fixture",
            environment: "test",
            status: "success"
          }

          assert 202 == send_event(key, "charge.excess", data)
          assert 202 == send_event(key, "charge.excess", data)

          receipts =
            NewYou.Commerce.HostedPaymentReceipt
            |> Ash.Query.filter(reference == ^original.reference and transaction_id == ^excess_id)
            |> Ash.read!(authorize?: false)

          assert [receipt] = receipts
          assert :ok = Commerce.apply_hosted_payment_evidence(receipt.id)
          assert :ok = Commerce.apply_hosted_payment_evidence(receipt.id)

          assert [owed] =
                   NewYou.Commerce.FixtureRefund
                   |> Ash.Query.filter(purchase_id == ^accepted.purchase_id)
                   |> Ash.read!(authorize?: false)

          assert owed.payer_id == payer.account_id
          assert owed.transaction_id == excess_id
          assert owed.amount_minor == @amount
          assert owed.allocation == :excess
          refute owed.payment_id == payment.id

          assert {:ok, _} = Commerce.reserve_fixture_refund(payer.credentials, owed.id)
          assert {:ok, _} = Commerce.dispatch_fixture_refund(payer.credentials, owed.id)
          assert_receive {^tag, "POST", "/refund", _, %{"transaction" => ^excess_id}}
          assert_receive {:refund_at_post, _}

          assert 202 ==
                   send_evidence(key, %{refund_data(owed) | transaction: excess_id}, "processed")

          process_evidence(owed.reference)
          assert %{state: :processed, allocation: :excess} = read_refund(owed.id)
          assert {:error, :grant_unavailable} = Entitlements.apply_fixture_refund(owed.id)

          assert {:ok, [%{id: ^right_id, state: :held_unconsumed}]} =
                   Entitlements.plan_rights(recipient.credentials)

          assert {:ok, []} = Commerce.open_plan_payment_consequences(accepted.purchase_id)

          excess_payment = Ash.get!(VerifiedPayment, owed.payment_id, authorize?: false)
          data = %{dispute_data(excess_payment) | outcome: "lost"}
          assert 202 == send_event(key, "fixture.dispute", data)

          assert %{state: :lost, allocation: :excess} =
                   dispute = apply_dispute_receipts(excess_payment)

          assert {:ok, :unresolved} = FixtureDisputes.correction_overlap(dispute.id)
          assert :ok = Commerce.deliver_fixture_dispute(dispute.id)
          assert [%{id: ^right_id}] = plan_rights(recipient)
        end)
      end)
    end)
  end

  test "known-reference misses, timeouts and rate limits cap backoff with money still owed" do
    P805.with_fixture(fn ->
      calls = :counters.new(1, [:atomics])

      reply = fn
        %{method: "GET"} = conn, _ ->
          :counters.add(calls, 1, 1)

          case :counters.get(calls, 1) do
            1 ->
              Plug.Conn.send_resp(conn, 404, "")

            2 ->
              conn
              |> Plug.Conn.put_resp_header("retry-after", "180")
              |> Plug.Conn.send_resp(429, "")

            3 ->
              Process.sleep(750)
              Plug.Conn.send_resp(conn, 200, "{}")

            _ ->
              Plug.Conn.send_resp(conn, 500, "")
          end

        conn, data ->
          default_refund_reply(conn, data)
      end

      with_paid_plan(reply, fn accepted, payment, payer, recipient, _, tag ->
        assert {:ok, owed} =
                 request(
                   payer.credentials,
                   proof(refund_fields(accepted, payment, payer, recipient))
                 )

        assert {:ok, _} = Commerce.reserve_fixture_refund(payer.credentials, owed.id)

        assert {:ok, %{state: :unresolved, reference: reference}} =
                 Commerce.dispatch_fixture_refund(payer.credentials, owed.id)

        assert_receive {^tag, "POST", "/refund", _, _}
        assert_receive {:refund_at_post, _}

        for round <- 1..6 do
          make_refund_due(owed.id)
          assert :ok = NewYou.Commerce.FixtureRefunds.read_due(owed.id)
          assert_receive {^tag, "GET", "/refund/" <> ^reference, _, _}

          assert %{state: :unresolved, verify_round: ^round, verify_after: due} =
                   read_refund(owed.id)

          if round == 2 do
            assert DateTime.diff(due, DateTime.utc_now()) in 175..180
            assert :ok = NewYou.Commerce.FixtureRefunds.read_due(owed.id)
            refute_received {^tag, "GET", _, _, _}
          end
        end

        assert %{state: :unresolved, verify_round: 6, verify_after: due, amount_minor: @amount} =
                 read_refund(owed.id)

        assert %DateTime{} = due
        assert DateTime.diff(due, DateTime.utc_now()) in 895..900
        assert :ok = NewYou.Commerce.FixtureRefunds.read_due(owed.id)
        assert :counters.get(calls, 1) == 6
        refute_received {^tag, _, _, _, _}

        outcomes =
          NewYou.Commerce.FixtureRefundReceipt
          |> Ash.Query.filter(requested_reference == ^reference)
          |> Ash.read!(authorize?: false)
          |> Enum.map(& &1.outcome)

        assert Enum.sort(outcomes) ==
                 Enum.sort([:not_found, :rate_limited, :timeout, :unavailable])

        # A claim retained under the previous final-round rule has no due time.
        Ash.update!(read_refund(owed.id), %{verify_after: nil},
          action: :defer_read,
          authorize?: false
        )

        assert %{failure: 0, discard: 0} =
                 AshOban.Test.schedule_and_run_triggers(
                   {NewYou.Commerce.FixtureRefund, :read_due}
                 )

        assert_receive {^tag, "GET", "/refund/" <> ^reference, _, _}

        assert %{state: :unresolved, verify_round: 6, verify_after: %DateTime{}} =
                 read_refund(owed.id)

        assert :counters.get(calls, 1) == 7
        refute_received {^tag, "POST", "/refund", _, _}
      end)
    end)
  end

  test "signed excess seen before the primary remains recoverable through its existing worker" do
    P805.with_fixture(fn ->
      with_unpaid_plan(fn accepted, payer, recipient, reference, _listener, tag ->
        with_signing_key(fn key ->
          excess = charge_data(reference, "18446744073709551613")
          assert 202 == send_event(key, "charge.excess", excess)
          assert 202 == send_event(key, "charge.excess", excess)
          assert [receipt] = payment_receipts(reference)
          assert :ok = Commerce.apply_hosted_payment_evidence(receipt.id)

          assert [%{state: :pending, classification: :awaiting_primary}] =
                   payment_receipts(reference)

          assert [] == purchase_refunds(accepted)
          assert {:ok, []} = Commerce.open_plan_payment_consequences(accepted.purchase_id)

          assert 202 == send_event(key, "charge.success", charge_data(reference, @transaction))
          assert primary = Enum.find(payment_receipts(reference), &(&1.id != receipt.id))
          assert :ok = Commerce.apply_hosted_payment_evidence(primary.id)

          refute_enqueued(
            worker: NewYou.Commerce.Workers.ProcessFixtureReceipt,
            args: %{"primary_key" => %{"id" => receipt.id}}
          )

          assert %{failure: 0, discard: 0} =
                   AshOban.Test.schedule_and_run_triggers(
                     {NewYou.Commerce.HostedPaymentReceipt, :process_fixture_receipt}
                   )

          assert [scheduled_owed] = purchase_refunds(accepted)
          assert 202 == send_event(key, "charge.excess", excess)
          assert :ok = Commerce.apply_hosted_payment_evidence(receipt.id)

          assert [
                   %{
                     payer_id: payer_id,
                     transaction_id: transaction,
                     amount_minor: @amount,
                     allocation: :excess,
                     id: obligation_id
                   }
                 ] = purchase_refunds(accepted)

          assert obligation_id == scheduled_owed.id
          assert payer_id == payer.account_id
          assert transaction == excess.id
          assert {:ok, [grant]} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
          assert {:ok, %{id: right}} = Commerce.deliver_plan_payment_consequence(grant)
          assert {:ok, [%{id: ^right}]} = Entitlements.plan_rights(recipient.credentials)
          refute_received {^tag, _, _, _, _}
        end)
      end)
    end)
  end

  test "concurrent primary and excess receipts preserve one benefit and reject genuine conflicts" do
    P805.with_fixture(fn ->
      with_unpaid_plan(fn accepted, payer, recipient, reference, _listener, tag ->
        with_signing_key(fn key ->
          primary = charge_data(reference, @transaction)
          excess = charge_data(reference, "18446744073709551613")
          assert 202 == send_event(key, "charge.success", primary)
          assert 202 == send_event(key, "charge.excess", excess)
          receipts = payment_receipts(reference)
          assert success = Enum.find(receipts, &(&1.outcome == :succeeded))
          assert extra = Enum.find(receipts, &(&1.outcome == :excess))

          assert [:ok, :ok] =
                   compete_on_connections([receipt_work(success), receipt_work(extra)])

          assert 202 == send_event(key, "charge.excess", primary)
          assert 202 == send_event(key, "charge.excess", %{excess | amount: @amount - 1})

          assert 202 ==
                   send_event(key, "charge.excess", %{excess | id: String.to_integer(excess.id)})

          assert %{failure: 0, discard: 0} =
                   AshOban.Test.schedule_and_run_triggers(
                     {NewYou.Commerce.HostedPaymentReceipt, :process_fixture_receipt}
                   )

          assert Enum.frequencies_by(payment_receipts(reference), & &1.classification) == %{
                   applied: 1,
                   excess_recorded: 1,
                   replayed: 1,
                   payment_conflict: 1,
                   source_mismatch: 1
                 }

          assert [%{payer_id: payer_id, amount_minor: @amount, allocation: :excess}] =
                   purchase_refunds(accepted)

          assert payer_id == payer.account_id
          assert {:ok, [grant]} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
          assert {:ok, %{id: right}} = Commerce.deliver_plan_payment_consequence(grant)
          assert {:ok, [%{id: ^right}]} = Entitlements.plan_rights(recipient.credentials)
          refute_received {^tag, _, _, _, _}
        end)
      end)
    end)
  end

  defp receipt_work(receipt), do: fn -> Commerce.apply_hosted_payment_evidence(receipt.id) end

  defp charge_data(reference, transaction) do
    %{
      reference: reference,
      id: transaction,
      amount: @amount,
      currency: "ZAR",
      status: "success",
      provider: "paystack",
      integration: "local_fixture",
      environment: "test"
    }
  end

  defp payment_receipts(reference) do
    NewYou.Commerce.HostedPaymentReceipt
    |> Ash.Query.filter(reference == ^reference)
    |> Ash.read!(authorize?: false)
  end

  defp purchase_refunds(accepted) do
    NewYou.Commerce.FixtureRefund
    |> Ash.Query.filter(purchase_id == ^accepted.purchase_id)
    |> Ash.read!(authorize?: false)
  end

  test "cleanup removes owned negative receipts and jobs while an unrelated sentinel survives" do
    with_signing_key(fn key ->
      {sentinel, sentinel_job} =
        Sandbox.unboxed_run(Repo, fn ->
          observation = put_unknown_receipt(key, false)
          {observation, receipt_job(observation.id)}
        end)

      try do
        {owned, owned_job} =
          P805.with_fixture(fn ->
            observation = put_unknown_receipt(key, true)
            assert :ok = Commerce.apply_fixture_refund_receipt(observation.id)

            assert %{state: :quarantined} =
                     Ash.get!(NewYou.Commerce.FixtureRefundReceipt, observation.id,
                       authorize?: false
                     )

            {observation, receipt_job(observation.id)}
          end)

        Sandbox.unboxed_run(Repo, fn ->
          assert {:ok, nil} =
                   Ash.get(NewYou.Commerce.FixtureRefundReceipt, owned.id,
                     authorize?: false,
                     error?: false
                   )

          refute Repo.get(Oban.Job, owned_job.id)
          assert Ash.get!(NewYou.Commerce.FixtureRefundReceipt, sentinel.id, authorize?: false)
          assert Repo.get(Oban.Job, sentinel_job.id)
        end)
      after
        P805.with_fixture(fn -> P805.track_webhook_receipt_digest(sentinel.digest) end)
      end
    end)
  end

  test "refund correction and retry-after queries keep restricted values out of telemetry" do
    P805.with_fixture(fn ->
      reply = fn
        %{method: "GET"} = conn, _ ->
          conn
          |> Plug.Conn.put_resp_header("retry-after", "180")
          |> Plug.Conn.send_resp(429, "")

        conn, data ->
          default_refund_reply(conn, data)
      end

      with_paid_plan(reply, fn accepted, payment, payer, recipient, _, tag ->
        refund = dispatch_claim(accepted, payment, payer, recipient, tag)

        original =
          Ash.get!(NewYou.Commerce.HostedPaymentReceipt, payment.fixture_receipt_id,
            authorize?: false
          )

        canaries = [
          refund.reference,
          original.reference,
          refund.transaction_id,
          refund_data(refund).id,
          payer.account_id,
          recipient.account_id
        ]

        assert {:ok, [grant]} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
        assert {:ok, %{id: right}} = Commerce.deliver_plan_payment_consequence(grant)

        direct_failure =
          observe_restricted_metadata(
            canaries,
            fn ->
              assert {:error, :grant_unavailable} = Entitlements.apply_fixture_refund(refund.id)
            end,
            :direct_failure
          )

        make_refund_due(refund.id)

        rate_limit_failure =
          P805.with_rejected_insert("commerce_fixture_refund_receipts", fn reached? ->
            leaked? =
              observe_restricted_metadata(
                canaries,
                fn ->
                  assert {:error, :refund_unavailable} =
                           NewYou.Commerce.FixtureRefunds.read_due(refund.id)
                end,
                :rate_limit_failure
              )

            assert reached?.()
            leaked?
          end)

        assert_receive {^tag, "GET", "/refund/" <> _, _, _}
        assert_receive {:refund_event, :rate_limit_failure, {:checkpoint, :read_reserved}}
        assert DateTime.diff(read_refund(refund.id).verify_after, DateTime.utc_now()) in 175..180
        assert [] == refund_receipts(refund.reference)

        with_signing_key(fn key ->
          receipt = processed_receipt(key, refund)
          assert :ok = Commerce.apply_fixture_refund_receipt(receipt.id)
        end)

        direct_effect =
          observe_restricted_metadata(
            canaries,
            fn ->
              assert :ok = Entitlements.apply_fixture_refund(refund.id)
            end,
            :direct_effect
          )

        assert %{state: :ended} = Ash.get!(Entitlements.PlanRight, right, authorize?: false)

        scheduled_delivery =
          observe_restricted_metadata(
            canaries,
            fn ->
              assert %{failure: 0, discard: 0, success: success} =
                       AshOban.Test.schedule_and_run_triggers(
                         {NewYou.Commerce.FixtureRefund, :deliver}
                       )

              assert success > 0
            end,
            :scheduled_delivery
          )

        assert %{acknowledged_at: %DateTime{}} = read_refund(refund.id)

        assert %{
                 direct_failure: :clean,
                 rate_limit_failure: :clean,
                 direct_effect: :clean,
                 scheduled_delivery: :clean
               } ==
                 %{
                   direct_failure: direct_failure,
                   rate_limit_failure: rate_limit_failure,
                   direct_effect: direct_effect,
                   scheduled_delivery: scheduled_delivery
                 }
      end)
    end)
  end

  defp observe_restricted_metadata(values, operation, phase) do
    handler = {__MODULE__, make_ref()}

    needles =
      Enum.flat_map(values, fn value ->
        case Ecto.UUID.dump(value) do
          {:ok, dumped} -> [value, dumped]
          :error -> [value]
        end
      end)

    :ok =
      :telemetry.attach_many(
        handler,
        [
          [:new_you, :repo, :query],
          [:new_you, :commerce, :fixture_refund, :checkpoint]
        ],
        &__MODULE__.capture_refund_metadata/4,
        {self(), phase, needles}
      )

    try do
      Repo.query!("SELECT 1")
      assert_receive {:refund_event, ^phase, :query}
      operation.()

      receive do
        {:refund_event, ^phase, {:restricted, source, keys, command}} -> {source, keys, command}
      after
        0 -> :clean
      end
    after
      :telemetry.detach(handler)
    end
  end

  @doc false
  def capture_refund_metadata(event, _measurements, metadata, {observer, phase, needles}) do
    case {:binary.match(:erlang.term_to_binary(metadata), needles), event} do
      {:nomatch, [:new_you, :repo, :query]} ->
        send(observer, {:refund_event, phase, :query})

      {:nomatch, _} ->
        send(observer, {:refund_event, phase, {:checkpoint, metadata.stage}})

      {{_, _}, _} ->
        keys =
          for {key, value} <- metadata,
              :binary.match(:erlang.term_to_binary(value), needles) != :nomatch,
              do: key

        command = metadata |> Map.get(:query, "") |> String.split(" ", parts: 2) |> hd()
        verb = if command in ["SELECT", "INSERT", "UPDATE", "DELETE"], do: command, else: "other"
        send(observer, {:refund_event, phase, {:restricted, metadata[:source], keys, verb}})
    end
  end

  defp put_unknown_receipt(key, track?) do
    reference = Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
    data = refund_data(%{reference: reference})
    assert 202 == send_evidence(key, data, "processed", track?: track?)

    NewYou.Commerce.FixtureRefundReceipt
    |> Ash.Query.filter(reference == ^reference)
    |> Ash.read_one!(authorize?: false)
  end

  defp receipt_job(id) do
    NewYou.Commerce.Workers.ProcessFixtureRefundReceipt.new(%{"primary_key" => %{"id" => id}})
    |> Oban.insert!()
  end

  defp with_signing_key(fun) do
    key = :crypto.strong_rand_bytes(32)
    previous = Application.get_env(:new_you, :fixture_webhook_key)
    Application.put_env(:new_you, :fixture_webhook_key, key)

    try do
      fun.(key)
    after
      if previous,
        do: Application.put_env(:new_you, :fixture_webhook_key, previous),
        else: Application.delete_env(:new_you, :fixture_webhook_key)
    end
  end

  defp run_recovery(id, phase \\ "read") do
    {executable, arguments} =
      FreshMix.command(["run", "--no-compile", "test/proof/well221_refund_restart.exs"])

    payload = Jason.encode!(%{refund_id: id, phase: phase})

    assert %{status: :ok, cleanup: :confirmed, marker: :well221_completed} =
             P815Port.run(executable, arguments, payload, 60_000)
  end

  defp make_refund_due(id, attrs \\ %{}) do
    Ash.update!(
      read_refund(id),
      Map.put(attrs, :verify_after, DateTime.add(DateTime.utc_now(), -1)),
      action: :defer_read,
      authorize?: false
    )
  end

  defp refund_data(refund) do
    %{
      reference: refund.reference,
      transaction: @transaction,
      id: "18446744073709551615",
      amount: @amount,
      currency: "ZAR",
      provider: "paystack",
      integration: "local_fixture",
      environment: "test"
    }
  end

  defp send_evidence(key, data, status, options \\ []) do
    send_event(key, "refund." <> status, Map.put(data, :status, status), options)
  end

  defp send_event(key, event, data, options \\ []) do
    raw = Jason.encode!(%{event: event, data: data})
    digest = :crypto.hash(:sha256, raw)
    if Keyword.get(options, :track?, true), do: P805.track_webhook_receipt_digest(digest)

    signature =
      if Keyword.get(options, :authenticated?, true),
        do: Base.encode16(:crypto.mac(:hmac, :sha512, key, raw), case: :lower),
        else: String.duplicate("0", 128)

    raw = if Keyword.get(options, :modified?, false), do: raw <> " ", else: raw

    conn =
      Plug.Test.conn(:post, "/__test/commerce/fixture-webhook", raw)
      |> Plug.Conn.put_req_header("content-type", "application/json")
      |> Plug.Conn.put_req_header("x-newyou-fixture-signature", signature)

    NewYouWeb.Endpoint.call(conn, []).status
  end

  defp process_evidence(reference) do
    reference
    |> refund_receipts()
    |> Enum.each(fn receipt -> assert :ok = Commerce.apply_fixture_refund_receipt(receipt.id) end)
  end

  defp refund_receipts(reference) do
    NewYou.Commerce.FixtureRefundReceipt
    |> Ash.Query.filter(reference == ^reference)
    |> Ash.Query.sort(:id)
    |> Ash.read!(authorize?: false)
  end

  defp read_refund(id), do: Ash.get!(NewYou.Commerce.FixtureRefund, id, authorize?: false)

  defp refund_fields(accepted, payment, payer, recipient) do
    %{
      scope: :hosted_refund_authorization,
      purchase_id: accepted.purchase_id,
      quote_id: accepted.terms.quote_id,
      payment_id: payment.id,
      transaction_id: payment.fixture_transaction_id,
      payer_id: payer.account_id,
      recipient_id: recipient.account_id,
      amount_minor: @amount,
      currency: "ZAR",
      allocation: :plan
    }
  end

  # Use the actual commerce qualification and pin, with separate payer and recipient.
  defp with_paid_plan(refund_reply \\ &default_refund_reply/2, fun) do
    with_paid_plan(verified_party(), verified_party(), @transaction, refund_reply, fun)
  end

  defp with_paid_plan(payer, recipient, transaction, refund_reply, fun) do
    with_checkout(payer, recipient, transaction, refund_reply, fn accepted,
                                                                  reference,
                                                                  listener,
                                                                  tag ->
      assert :ok = HostedPaymentEvidence.verify_due(accepted.attempt_id)
      assert_receive {^tag, "GET", "/transaction/verify/" <> ^reference, _, _}

      assert [payment] =
               VerifiedPayment
               |> Ash.Query.filter(purchase_id == ^accepted.purchase_id)
               |> Ash.read!(authorize?: false)

      assert payment.fixture_transaction_id == transaction
      fun.(accepted, payment, payer, recipient, listener, tag)
    end)
  end

  defp with_unpaid_plan(fun) do
    payer = verified_party()
    recipient = verified_party()

    with_checkout(payer, recipient, @transaction, &default_refund_reply/2, fn accepted,
                                                                              reference,
                                                                              listener,
                                                                              tag ->
      fun.(accepted, payer, recipient, reference, listener, tag)
    end)
  end

  defp with_checkout(payer, recipient, transaction, refund_reply, fun) do
    publish!(:plan, %{amount_minor: @amount, plan_list_minor: @amount})
    authority = parties(payer, recipient)
    quote = quote!(authority, :plan)
    assert {:ok, accepted} = OfferAdmission.accept(authority, acceptance(quote))

    assert {:ok, %{reference: reference}} =
             HostedCheckout.prepare(payer.credentials, accepted, @scope)

    parent = self()

    HostedCheckoutReceiver.with_bound_receiver(
      fn
        %{method: "POST", path_info: ["transaction", "initialize"]} = conn, fields ->
          HostedCheckoutReceiver.success(conn, fields)

        %{method: "POST", path_info: ["refund"]} = conn,
        %{"reference" => refund_reference} = data ->
          visible =
            Sandbox.unboxed_run(Repo, fn ->
              NewYou.Commerce.FixtureRefund
              |> Ash.Query.filter(reference == ^refund_reference)
              |> Ash.read_one!(authorize?: false)
            end)

          send(parent, {:refund_at_post, visible})
          refund_reply.(conn, data)

        %{method: "GET", path_info: ["refund", _]} = conn, data ->
          refund_reply.(conn, data)

        %{method: "GET", path_info: ["__test", "dispute", _]} = conn, data ->
          refund_reply.(conn, data)

        %{method: "GET", path_info: ["transaction", "verify", ^reference]} = conn, _ ->
          HostedCheckoutReceiver.json(conn, 200, %{
            status: true,
            data: %{
              reference: reference,
              id: transaction,
              amount: @amount,
              currency: "ZAR",
              status: "success",
              provider: "paystack",
              integration: "local_fixture",
              environment: "test"
            }
          })
      end,
      fn listener, tag ->
        assert {:ok, %{status: :retained}} =
                 HostedCheckout.initialize(payer.credentials, accepted, @scope, listener)

        assert_receive {^tag, "POST", "/transaction/initialize", _, _}
        fun.(accepted, reference, listener, tag)
      end
    )
  end

  defp default_refund_reply(conn, _), do: Plug.Conn.send_resp(conn, 409, "")

  defp request(credentials, authorization) do
    Commerce.authorize_fixture_refund(credentials, authorization)
  end
end
