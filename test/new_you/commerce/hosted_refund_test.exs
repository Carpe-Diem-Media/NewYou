defmodule NewYou.Commerce.HostedRefundTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: NewYou.Repo

  alias NewYou.Commerce
  alias NewYou.Entitlements
  alias NewYou.Repo
  alias NewYou.Commerce.{HostedCheckout, HostedCheckoutReceiver, HostedPaymentEvidence}
  alias NewYou.Commerce.{OfferAdmission, VerifiedPayment}
  alias NewYou.Proof.{FreshMix, P805, P815Port}
  alias NewYou.Privacy.SyntheticSuppression
  alias Ecto.Adapters.SQL.Sandbox

  import NewYou.Commerce.OfferFixtures

  require Ash.Query

  @scope %{provider: :paystack, integration: :local_fixture, environment: :test, channel: :card}
  @amount 47_500
  @transaction "18446744073709551614"

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
        end)
      end)
    end)
  end

  defp compete_on_connections(fun) do
    parent = self()

    contenders = for _ <- 1..2, do: Task.async(fn -> run_contender(parent, fun) end)

    assert_receive {:contender, first, backend1}
    assert_receive {:contender, second, backend2}
    assert backend1 != backend2
    send(first, :go)
    send(second, :go)

    Task.await_many(contenders)
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
        end, port: listener.port)
    end)
  end

  defp cut_dispatch(credentials, refund_id, stage) do
    handler_id = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(
        handler_id,
        [:new_you, :commerce, :fixture_refund, :checkpoint],
        &kill_at_checkpoint/4,
        stage
      )

    try do
      {pid, monitor} =
        spawn_monitor(fn ->
          Process.put({__MODULE__, :cut_refund}, true)

          Sandbox.unboxed_run(Repo, fn ->
            Commerce.dispatch_fixture_refund(credentials, refund_id)
          end)
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
        assert {:ok, _} = Commerce.dispatch_fixture_refund(payer.credentials, owed.id)

        assert Code.ensure_loaded?(NewYou.Commerce.Workers.ReadFixtureRefund)
        make_refund_due(owed.id)
        run_recovery(owed.id)

        assert_receive {^tag, "GET", "/refund/" <> ^reference, _, _}

        assert %{
                 state: :processed,
                 provider_refund_id: ^provider_id,
                 processed_receipt_id: applied
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
        end)
      end)
    end)
  end

  test "known-reference misses, timeouts and rate limits exhaust bounded reads with money still owed" do
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

        assert %{state: :unresolved, verify_round: 6, verify_after: nil, amount_minor: @amount} =
                 read_refund(owed.id)

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
      end)
    end)
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

  defp make_refund_due(id) do
    Ash.update!(read_refund(id), %{verify_after: DateTime.add(DateTime.utc_now(), -1)},
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
        assert :ok = HostedPaymentEvidence.verify_due(accepted.attempt_id)
        assert_receive {^tag, "GET", "/transaction/verify/" <> ^reference, _, _}

        assert [payment] =
                 VerifiedPayment
                 |> Ash.Query.filter(purchase_id == ^accepted.purchase_id)
                 |> Ash.read!(authorize?: false)

        assert payment.fixture_transaction_id == transaction
        fun.(accepted, payment, payer, recipient, listener, tag)
      end
    )
  end

  defp default_refund_reply(conn, _), do: Plug.Conn.send_resp(conn, 409, "")

  defp request(credentials, authorization) do
    Commerce.authorize_fixture_refund(credentials, authorization)
  end
end
