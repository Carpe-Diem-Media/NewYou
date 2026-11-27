defmodule NewYou.Commerce.HostedPaymentEvidenceTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: NewYou.Repo

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Commerce, Entitlements, Repo}

  alias NewYou.Commerce.{
    HostedCheckout,
    HostedDispatch,
    HostedPaymentEvidence,
    HostedPaymentReceipt
  }

  alias NewYou.Commerce.{
    HostedCheckoutReceiver,
    OfferAdmission,
    PaymentConsequence,
    VerifiedPayment
  }

  alias NewYou.Commerce.Workers.VerifyFixtureReference
  alias NewYou.Proof.{FreshMix, P805, P815Port}

  import NewYou.Commerce.OfferFixtures

  require Ash.Query

  @path "/__test/commerce/fixture-webhook"
  @scope %{provider: :paystack, integration: :local_fixture, environment: :test, channel: :card}
  @amount 47_500
  @transaction 18_446_744_073_709_551_614

  setup do
    key = :crypto.strong_rand_bytes(32)
    previous = Application.get_env(:new_you, :fixture_webhook_key)
    Application.put_env(:new_you, :fixture_webhook_key, key)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:new_you, :fixture_webhook_key, previous),
        else: Application.delete_env(:new_you, :fixture_webhook_key)
    end)

    %{key: key}
  end

  test "the endpoint authenticates exact raw bytes before interpreting the body", %{key: key} do
    raw = ~s({"event":"charge.success"})
    signature = signature(key, raw)
    assert post(raw, nil).status == 401
    assert post(raw, String.duplicate("0", 128)).status == 401
    assert post(raw <> " ", signature).status == 401
    assert post(raw, signature).status == 400
    assert post(String.duplicate("x", 8_193), signature).status == 413
  end

  test "a receipt commit failure returns 503 and loss after commit permits authenticated replay",
       %{key: key} do
    P805.with_fixture(fn ->
      with_checkout(fn accepted, _recipient, reference, _observed ->
        raw = webhook(reference)
        signature = signature(key, raw)

        P805.with_rejected_insert("commerce_hosted_payment_receipts", fn reached? ->
          assert post(raw, signature).status == 503
          assert reached?.()
          assert [] == evidence(reference)
        end)

        lost =
          Task.async(fn ->
            Sandbox.unboxed_run(Repo, fn ->
              conn =
                request(raw, signature)
                |> Plug.Conn.register_before_send(fn _ -> throw(:acknowledgement_lost) end)

              catch_throw(NewYouWeb.Endpoint.call(conn, []))
            end)
          end)

        assert Task.await(lost) == :acknowledgement_lost
        assert [%{state: :pending, id: id}] = evidence(reference)
        assert post(raw, signature).status == 202
        assert [%{id: ^id}] = evidence(reference)
        assert [] == payments(accepted)
      end)
    end)
  end

  test "Bandit delivers signed raw bytes to the Phoenix endpoint and receipt jobs rediscover them",
       %{key: key} do
    P805.with_fixture(fn ->
      with_checkout(fn accepted, recipient, reference, _observed ->
        {:ok, listener} =
          Bandit.start_link(plug: __MODULE__, ip: {127, 0, 0, 1}, port: 0, startup_log: false)

        try do
          {:ok, {{127, 0, 0, 1}, port}} = ThousandIsland.listener_info(listener)
          url = "http://127.0.0.1:#{port}" <> @path
          raw = webhook(reference)

          assert %{status: 202} =
                   Req.post!(url,
                     body: raw,
                     headers: [
                       {"content-type", "application/json"},
                       {"x-newyou-fixture-signature", signature(key, raw)}
                     ],
                     retry: false,
                     redirect: false
                   )

          assert [%{source: :webhook, state: :pending}] = evidence(reference)
          assert [] == payments(accepted)

          assert %{success: 2, failure: 0, discard: 0} =
                   AshOban.Test.schedule_and_run_triggers(
                     {HostedPaymentReceipt, :process_fixture_receipt}
                   )

          [payment] = payments(accepted)
          assert source_right(accepted, recipient, payment.id)
        after
          Supervisor.stop(listener)
        end
      end)
    end)
  end

  def init(opts), do: opts

  def call(conn, _opts) do
    Sandbox.unboxed_run(Repo, fn -> NewYouWeb.Endpoint.call(conn, []) end)
  end

  test "signed mismatches and reordered stale evidence cannot pay or replace the attempt", %{
    key: key
  } do
    P805.with_fixture(fn ->
      with_checkout(fn accepted, recipient, reference, _observed ->
        base = data(reference)

        for wrong <- [
              %{"amount" => 39_900},
              %{"currency" => "USD"},
              %{"environment" => "production"},
              %{"provider" => "elsewhere"},
              %{"integration" => "active"},
              %{"status" => "unknown_future_status"}
            ] do
          send_webhook(key, Map.merge(base, wrong))
        end

        send_webhook(key, %{base | "status" => "pending"}, "charge.pending")
        process_receipts(reference)
        assert length(evidence(reference)) == 7

        assert Enum.frequencies_by(evidence(reference), & &1.state) == %{
                 quarantined: 6,
                 unresolved: 1
               }

        assert [] == payments(accepted)
        assert {:ok, []} == Entitlements.plan_rights(recipient.credentials)

        assert {:error, :payment_unavailable} ==
                 Commerce.apply_payment_observation(payment(accepted))

        send_webhook(key, base)
        process_receipts(reference)
        [payment] = payments(accepted)
        assert payment.fixture_transaction_id == Integer.to_string(@transaction)
        assert source_right(accepted, recipient, payment.id)
        send_webhook(key, %{base | "id" => @transaction - 1})

        send_webhook(
          key,
          %{base | "status" => "pending", "id" => @transaction - 1},
          "charge.pending"
        )

        process_receipts(reference)
        assert Enum.any?(evidence(reference), &(&1.classification == :payment_conflict))
        assert [%{id: id}] = payments(accepted)
        assert id == payment.id
        assert %{reference: ^reference, verify_after: nil} = dispatch(accepted)
      end)
    end)
  end

  test "signed pending evidence qualifies the original reference and immutable money", %{key: key} do
    P805.with_fixture(fn ->
      with_checkout(fn accepted, recipient, reference, _observed ->
        matching = %{data(reference) | "status" => "pending"}
        unknown = foreign_reference(reference)

        for {payload, state, reason} <- [
              {matching, :unresolved, :pending},
              {%{matching | "reference" => unknown}, :quarantined, :source_mismatch},
              {%{matching | "amount" => 39_900}, :quarantined, :source_mismatch},
              {%{matching | "currency" => "USD"}, :quarantined, :source_mismatch}
            ] do
          prior_ids = MapSet.new(evidence(payload["reference"]), & &1.id)
          send_webhook(key, payload, "charge.pending")
          process_receipts(payload["reference"])

          assert [%{state: ^state, classification: ^reason}] =
                   Enum.reject(evidence(payload["reference"]), &MapSet.member?(prior_ids, &1.id))
        end

        assert_no_payment_effects(accepted, recipient)
      end)
    end)
  end

  test "Verify qualifies structured pending evidence and preserves transport-only outcomes" do
    P805.with_fixture(fn ->
      replies = :counters.new(1, [:atomics])

      with_checkout(
        fn conn, reference ->
          pending = %{data(reference) | "status" => "pending"}
          :counters.add(replies, 1, 1)

          case :counters.get(replies, 1) do
            1 ->
              verify_reply(conn, pending)

            2 ->
              verify_reply(conn, %{pending | "reference" => foreign_reference(reference)})

            3 ->
              verify_reply(conn, %{pending | "amount" => 39_900})

            4 ->
              verify_reply(conn, %{pending | "currency" => "USD"})

            5 ->
              Plug.Conn.send_resp(conn, 404, "")

            6 ->
              Plug.Conn.send_resp(conn, 429, "")

            7 ->
              Process.sleep(750)
              verify_reply(conn, pending)
          end
        end,
        fn accepted, recipient, reference, observed ->
          for {state, reason} <- [
                {:unresolved, :pending},
                {:quarantined, :source_mismatch},
                {:quarantined, :source_mismatch},
                {:quarantined, :source_mismatch},
                {:unresolved, :not_found},
                {:unresolved, :rate_limited},
                {:unresolved, :timeout}
              ] do
            prior_ids = MapSet.new(evidence(reference), & &1.id)
            assert :ok == HostedPaymentEvidence.verify_due(accepted.attempt_id)
            assert_verify(observed, reference)

            assert [%{state: ^state, classification: ^reason, requested_reference: ^reference}] =
                     Enum.reject(evidence(reference), &MapSet.member?(prior_ids, &1.id))

            assert_no_payment_effects(accepted, recipient)
            make_due(accepted)
          end
        end
      )
    end)
  end

  test "Verify sends only after a durable reservation outside caller transactions" do
    P805.with_fixture(fn ->
      observer = self()

      with_checkout(
        fn conn, reference ->
          read =
            independent(fn ->
              HostedDispatch
              |> Ash.Query.filter(reference == ^reference)
              |> Ash.read_one!(authorize?: false)
            end)

          send(observer, {:reservation_at_get, Task.await(read)})
          Plug.Conn.send_resp(conn, 404, "")
        end,
        fn accepted, recipient, reference, observed ->
          initial = dispatch(accepted)

          sandboxed =
            Task.async(fn ->
              assert :ok == Sandbox.checkout(Repo)
              refute Ash.DataLayer.in_transaction?(HostedDispatch)
              result = HostedPaymentEvidence.verify_due(accepted.attempt_id)
              reservation = dispatch(accepted)
              assert :ok == Sandbox.checkin(Repo)
              {result, reservation}
            end)

          {sandboxed_result, rolled_back} = Task.await(sandboxed)
          refute_receive {^observed, _, _, _, _}, 0
          assert sandboxed_result == {:error, :unavailable}
          assert rolled_back.verify_round == initial.verify_round + 1
          assert DateTime.after?(rolled_back.verify_after, initial.verify_after)
          assert dispatch(accepted).verify_after == initial.verify_after
          assert dispatch(accepted).verify_round == initial.verify_round

          assert {:error, :rollback} ==
                   Repo.transaction(fn ->
                     assert Ash.DataLayer.in_transaction?(HostedDispatch)

                     assert {:error, :unavailable} ==
                              HostedPaymentEvidence.verify_due(accepted.attempt_id)

                     Repo.rollback(:rollback)
                   end)

          refute_receive {^observed, _, _, _, _}, 0
          assert [] == evidence(reference)
          assert_no_payment_effects(accepted, recipient)

          assert :ok == HostedPaymentEvidence.verify_due(accepted.attempt_id)
          assert_verify(observed, reference)
          assert_receive {:reservation_at_get, {:ok, _, reserved}}
          assert reserved.reference == reference
          assert reserved.verify_round == initial.verify_round + 1
          assert reserved.verify_after == dispatch(accepted).verify_after
          assert DateTime.after?(reserved.verify_after, DateTime.utc_now())
          refute_receive {^observed, _, _, _, _}, 0
        end
      )
    end)
  end

  test "known reference scheduling survives missing and exhausted work and honors backoff" do
    P805.with_fixture(fn ->
      replies = :counters.new(1, [:atomics])

      with_checkout(
        fn conn, reference ->
          :counters.add(replies, 1, 1)

          case :counters.get(replies, 1) do
            round when round in [1, 2] ->
              Plug.Conn.send_resp(conn, 404, "")

            3 ->
              conn
              |> Plug.Conn.put_resp_header("retry-after", "150")
              |> Plug.Conn.send_resp(429, "")

            4 ->
              verify_reply(conn, data(foreign_reference(reference)))

            5 ->
              Process.sleep(750)
              verify_reply(conn, data(reference))

            6 ->
              verify_reply(conn, %{data(reference) | "amount" => 39_900})

            7 ->
              verify_reply(conn, %{data(reference) | "currency" => "USD"})

            8 ->
              verify_reply(conn, %{data(reference) | "environment" => "production"})

            9 ->
              verify_reply(conn, %{data(reference) | "status" => "future_status"})

            10 ->
              verify_reply(conn, data(reference))
          end
        end,
        fn accepted, recipient, reference, observed ->
          args = %{"primary_key" => %{"attempt_id" => accepted.attempt_id}}
          refute_enqueued(worker: VerifyFixtureReference, args: args)

          P805.with_rejected_insert("commerce_hosted_payment_receipts", fn reached? ->
            assert %{discard: 1, queues_not_drained: []} =
                     AshOban.Test.schedule_and_run_triggers(
                       {HostedDispatch, :verify_fixture_reference}
                     )

            assert_verify(observed, reference)
            assert reached?.()
            assert [] == evidence(reference)
          end)

          assert [[1, 1]] =
                   Repo.query!(
                     """
                     SELECT attempt, max_attempts FROM oban_jobs
                     WHERE worker = 'NewYou.Commerce.Workers.VerifyFixtureReference'
                       AND state = 'discarded' AND args->'primary_key'->>'attempt_id' = $1
                     """,
                     [accepted.attempt_id]
                   ).rows

          assert %DateTime{} = dispatch(accepted).verify_after
          make_due(accepted)

          for {attempt_number, classification, min_delay} <- [
                {2, :not_found, 60},
                {3, :rate_limited, 150},
                {4, :source_mismatch, 240},
                {5, :timeout, 480},
                {6, :source_mismatch, 900},
                {7, :source_mismatch, 900},
                {8, :scope_mismatch, 900},
                {9, :unknown, 900}
              ] do
            prior_ids = MapSet.new(evidence(reference), & &1.id)
            now = DateTime.utc_now()
            schedule_verify()
            assert_verify(observed, reference)
            assert :counters.get(replies, 1) == attempt_number

            assert [%{classification: ^classification}] =
                     Enum.reject(evidence(reference), &MapSet.member?(prior_ids, &1.id))

            assert DateTime.diff(dispatch(accepted).verify_after, now, :second) >= min_delay - 1
            assert [] == payments(accepted)
            assert {:ok, []} == Entitlements.plan_rights(recipient.credentials)
            schedule_verify()
            refute_receive {^observed, _, _, _, _}, 0
            make_due(accepted)
          end

          schedule_verify()
          assert_verify(observed, reference)
          [payment] = payments(accepted)
          assert source_right(accepted, recipient, payment.id)
          assert %{verify_after: nil} = dispatch(accepted)
          schedule_verify()
          refute_receive {^observed, _, _, _, _}, 0
        end
      )
    end)
  end

  test "Verify leaves the original reference unresolved when another receiver reuses its port" do
    P805.with_fixture(fn ->
      {accepted, recipient, reference, port} =
        with_checkout(fn accepted, recipient, reference, _observed ->
          {accepted, recipient, reference, dispatch(accepted).fixture_port}
        end)

      schedule_verify()
      assert [%{classification: :unavailable}] = evidence(reference)
      assert [] == payments(accepted)
      assert %{verify_round: 1} = dispatch(accepted)

      replacements = [
        &HostedCheckoutReceiver.with_receiver/3,
        &HostedCheckoutReceiver.with_bound_receiver/3
      ]

      for {start_receiver, round} <- Enum.with_index(replacements, 2) do
        make_due(accepted)

        start_receiver.(
          fn conn, _ -> verify_reply(conn, data(reference)) end,
          fn _listener, observed ->
            schedule_verify()
            refute_receive {^observed, _, _, _, _}, 0
            assert [] == payments(accepted)
            assert {:ok, []} == Entitlements.plan_rights(recipient.credentials)
            assert %{verify_round: ^round, verify_after: %DateTime{}} = dispatch(accepted)
          end,
          port: port
        )
      end
    end)
  end

  test "independent connections race duplicate receipts and Verify without multiplying effects",
       %{key: key} do
    P805.with_fixture(fn ->
      observer = self()

      with_checkout(
        fn conn, reference ->
          send(observer, {:verify_waiting, self()})

          receive do
            :release -> verify_reply(conn, data(reference))
          after
            400 -> Plug.Conn.send_resp(conn, 503, "")
          end
        end,
        fn accepted, recipient, reference, observed ->
          [one, two] =
            for _ <- 1..2 do
              independent(fn ->
                send(observer, {:ready_to_ingest, self()})

                receive do
                  :ingest -> send_webhook(key, data(reference))
                after
                  2_000 -> :no_signal
                end
              end)
            end

          assert_receive {:ready_to_ingest, first}
          assert_receive {:ready_to_ingest, second}
          send(first, :ingest)
          send(second, :ingest)
          assert {:ok, first_backend, :ok} = Task.await(one)
          assert {:ok, second_backend, :ok} = Task.await(two)
          assert first_backend != second_backend
          assert [%{id: id}] = evidence(reference)

          receipt_worker =
            independent(fn ->
              send(observer, {:ready_to_apply, self()})

              receive do
                :apply -> Commerce.apply_hosted_payment_evidence(id)
              after
                2_000 -> :no_signal
              end
            end)

          assert_receive {:ready_to_apply, receipt_pid}

          [worker, competing_worker] =
            for _ <- 1..2 do
              independent(fn ->
                send(observer, {:ready_to_verify, self()})

                receive do
                  :verify -> HostedPaymentEvidence.verify_due(accepted.attempt_id)
                after
                  2_000 -> :no_signal
                end
              end)
            end

          assert_receive {:ready_to_verify, first_verify}
          assert_receive {:ready_to_verify, second_verify}
          send(first_verify, :verify)
          send(second_verify, :verify)
          assert_receive {:verify_waiting, listener}
          assert_verify(observed, reference)
          send(receipt_pid, :apply)
          send(listener, :release)
          assert {:ok, verify_backend, :ok} = Task.await(worker)
          assert {:ok, competing_backend, :ok} = Task.await(competing_worker)
          assert verify_backend != competing_backend
          assert {:ok, receipt_backend, :ok} = Task.await(receipt_worker)
          assert verify_backend != receipt_backend

          assert Enum.frequencies_by(evidence(reference), & &1.state) == %{qualified: 2}
          [payment] = payments(accepted)
          assert source_right(accepted, recipient, payment.id)
          refute_receive {^observed, _, _, _, _}, 0
        end
      )
    end)
  end

  test "fresh BEAMs reconcile without ingress and replay an already committed Plan right" do
    P805.with_fixture(fn ->
      with_checkout(fn accepted, recipient, reference, observed ->
        assert [] == evidence(reference)
        assert [] == payments(accepted)
        assert {:ok, []} == Entitlements.plan_rights(recipient.credentials)
        %HostedDispatch{claim_id: original_claim} = dispatch(accepted)

        fresh_recovery(accepted, :verify_then_grant)
        assert_verify(observed, reference)
        assert [%{source: :verify, state: :qualified}] = evidence(reference)
        assert [%{id: payment_id}] = payments(accepted)

        assert {:ok, [%{id: right_id, payment_id: ^payment_id, state: :held_unconsumed}]} =
                 Entitlements.plan_rights(recipient.credentials)

        assert {:ok, [unacknowledged]} =
                 Commerce.open_plan_payment_consequences(accepted.purchase_id)

        fresh_recovery(accepted, :acknowledge)
        assert {:ok, []} = Commerce.open_plan_payment_consequences(accepted.purchase_id)

        assert %{fulfilled_at: %DateTime{}} =
                 Ash.get!(PaymentConsequence, unacknowledged, authorize?: false)

        assert {:ok, [%{id: ^right_id, payment_id: ^payment_id}]} =
                 Entitlements.plan_rights(recipient.credentials)

        assert [%{id: ^payment_id}] = payments(accepted)

        assert %{claim_id: ^original_claim, reference: ^reference, verify_after: nil} =
                 dispatch(accepted)

        refute_receive {^observed, _, _, _, _}, 0
      end)
    end)
  end

  defp fresh_recovery(accepted, phase) do
    {executable, arguments} =
      FreshMix.command(["run", "--no-compile", "test/proof/well219_payment_restart.exs"])

    payload = Jason.encode!(%{purchase_id: accepted.purchase_id, phase: phase})

    assert %{status: :ok, cleanup: :confirmed, marker: :e1bf_completed} =
             P815Port.run(executable, arguments, payload, 60_000)
  end

  defp with_checkout(verify \\ &verify_success/2, fun) do
    payer = verified_party()
    recipient = verified_party()
    publish!(:plan, %{amount_minor: @amount, plan_list_minor: @amount})
    authority = parties(payer, recipient)
    quote = quote!(authority, :plan)
    assert {:ok, accepted} = OfferAdmission.accept(authority, acceptance(quote))

    assert {:ok, %{reference: reference}} =
             HostedCheckout.prepare(payer.credentials, accepted, @scope)

    HostedCheckoutReceiver.with_bound_receiver(
      fn
        %{method: "POST"} = conn, payload ->
          HostedCheckoutReceiver.success(conn, payload)

        %{method: "GET", path_info: ["transaction", "verify", ^reference]} = conn, _ ->
          verify.(conn, reference)
      end,
      fn listener, observed ->
        assert {:ok, %{status: :retained}} =
                 HostedCheckout.initialize(payer.credentials, accepted, @scope, listener)

        assert_receive {^observed, "POST", "/transaction/initialize", _,
                        %{"reference" => ^reference}}

        fun.(accepted, recipient, reference, observed)
      end
    )
  end

  defp independent(fun) do
    Task.async(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
        {:ok, backend, fun.()}
      end)
    end)
  end

  defp source_right(accepted, recipient, payment_id) do
    assert [consequence] =
             PaymentConsequence
             |> Ash.Query.filter(purchase_id == ^accepted.purchase_id)
             |> Ash.read!(authorize?: false)

    assert consequence.payment_id == payment_id

    assert {:ok, %{id: right_id, state: :held_unconsumed}} =
             Commerce.deliver_plan_payment_consequence(consequence.id)

    assert {:ok, [%{id: ^right_id, payment_id: ^payment_id}]} =
             Entitlements.plan_rights(recipient.credentials)

    assert {:ok, %{id: ^right_id}} = Commerce.deliver_plan_payment_consequence(consequence.id)
    right_id
  end

  defp verify_success(conn, reference), do: verify_reply(conn, data(reference))

  defp verify_reply(conn, data),
    do: HostedCheckoutReceiver.json(conn, 200, %{status: true, data: data})

  defp data(reference) do
    %{
      "reference" => reference,
      "id" => @transaction,
      "amount" => @amount,
      "currency" => "ZAR",
      "status" => "success",
      "provider" => "paystack",
      "integration" => "local_fixture",
      "environment" => "test"
    }
  end

  defp foreign_reference(reference), do: String.reverse(reference)

  defp webhook(reference), do: envelope(data(reference), "charge.success")
  defp envelope(data, event), do: Jason.encode!(%{"data" => data, "event" => event})

  defp send_webhook(key, data, event \\ "charge.success") do
    raw = envelope(data, event)
    assert post(raw, signature(key, raw)).status == 202
    :ok
  end

  defp signature(key, raw),
    do: :crypto.mac(:hmac, :sha512, key, raw) |> Base.encode16(case: :lower)

  defp post(raw, signature), do: NewYouWeb.Endpoint.call(request(raw, signature), [])

  defp request(raw, signature) do
    conn =
      Plug.Test.conn(:post, @path, raw)
      |> Plug.Conn.put_req_header("content-type", "application/json")

    if signature,
      do: Plug.Conn.put_req_header(conn, "x-newyou-fixture-signature", signature),
      else: conn
  end

  defp evidence(reference) do
    HostedPaymentReceipt
    |> Ash.Query.filter(reference == ^reference or requested_reference == ^reference)
    |> Ash.read!(authorize?: false)
  end

  defp payments(accepted) do
    VerifiedPayment
    |> Ash.Query.filter(purchase_id == ^accepted.purchase_id)
    |> Ash.read!(authorize?: false)
  end

  defp assert_no_payment_effects(accepted, recipient) do
    assert [] == payments(accepted)

    assert [] ==
             PaymentConsequence
             |> Ash.Query.filter(purchase_id == ^accepted.purchase_id)
             |> Ash.read!(authorize?: false)

    assert {:ok, []} == Entitlements.plan_rights(recipient.credentials)
  end

  defp dispatch(accepted), do: Ash.get!(HostedDispatch, accepted.attempt_id, authorize?: false)

  defp process_receipts(reference) do
    for %{id: id} <- evidence(reference) do
      assert :ok == Commerce.apply_hosted_payment_evidence(id)
    end
  end

  defp make_due(accepted) do
    Ash.update!(dispatch(accepted), %{verify_after: DateTime.add(DateTime.utc_now(), -1)},
      action: :defer_verify,
      authorize?: false
    )
  end

  defp schedule_verify do
    assert %{failure: 0, discard: 0, queues_not_drained: []} =
             AshOban.Test.schedule_and_run_triggers({HostedDispatch, :verify_fixture_reference})
  end

  defp assert_verify(observed, reference) do
    path = "/transaction/verify/" <> reference
    assert_receive {^observed, "GET", ^path, [_fixture_credential], %{}}
  end
end
