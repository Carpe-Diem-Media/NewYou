defmodule NewYou.Commerce.HostedCheckoutRecoveryTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Commerce.{HostedCheckout, HostedDispatch, OfferAdmission, Purchase}
  alias NewYou.Commerce.HostedCheckoutReceiver, as: Receiver
  alias NewYou.Proof.{FreshMix, P805, P815Port}
  alias NewYou.{Identity, Repo}

  import NewYou.Commerce.OfferFixtures

  @scope %{provider: :paystack, integration: :local_fixture, environment: :test, channel: :card}
  @checkpoint [:new_you, :commerce, :hosted_checkout, :checkpoint]
  @fixture_url "https://checkout.paystack.invalid/fixture-checkout-canary"

  test "two independent PostgreSQL connections allow one committed claim and one receiver-observed POST" do
    P805.with_fixture(fn ->
      {credentials, accepted, reference} = prepared_plan()
      parent = self()

      Receiver.with_receiver(
        fn conn, payload ->
          send(parent, {:wire_waiting, self()})

          receive do
            :reply -> Receiver.success(conn, payload)
          after
            2_000 -> Plug.Conn.send_resp(conn, 503, "")
          end
        end,
        fn port, observed ->
          work = fn -> HostedCheckout.initialize(credentials, accepted, @scope, port) end
          winner = start(work)
          loser = start(work)
          assert winner.backend != loser.backend
          assert [[observer_backend]] = Repo.query!("SELECT pg_backend_pid()").rows
          refute observer_backend in [winner.backend, loser.backend]

          with_cut(winner, :claim_written, fn ->
            send(winner.pid, :run)
            await_cut(winner, :claim_written)
            assert %{claim_id: nil, reference: ^reference} = attempt!(accepted)
            refute_receive {^observed, _, _, _, _}, 0

            send(loser.pid, :run)
            assert blocked_on?(loser.backend, winner.backend, 120)
            assert %{claim_id: nil} = attempt!(accepted)
            refute_receive {^observed, _, _, _, _}, 0

            send(winner.pid, :release)

            assert_receive {^observed, "POST", "/transaction/initialize", _,
                            %{"reference" => ^reference}}

            assert_receive {:wire_waiting, receiver}
            assert %{claim_id: claim, fixture_code: nil} = attempt!(accepted)
            assert is_binary(claim)
            send(receiver, :reply)

            assert {:ok, %{status: :retained, reference: ^reference}} = result(winner)
            assert {:ok, %{status: status, reference: ^reference}} = result(loser)
            assert status in [:ambiguous, :retained]
            assert %{claim_id: ^claim} = attempt!(accepted)
            refute_receive {^observed, _, _, _, _}
          end)
        end
      )
    end)
  end

  test "refuses to dispatch inside an outer transaction before the claim can commit" do
    P805.with_fixture(fn ->
      {credentials, accepted, reference} = prepared_plan()

      Receiver.with_receiver(&Receiver.success/2, fn port, observed ->
        assert {:ok, :did_not_send} =
                 Ash.transact(Purchase, fn ->
                   assert {:error, :checkout_unavailable} =
                            HostedCheckout.initialize(credentials, accepted, @scope, port)

                   assert %{claim_id: nil, reference: ^reference} = attempt!(accepted)
                   refute_receive {^observed, _, _, _, _}, 0
                   :did_not_send
                 end)

        assert {:ok, %{status: :retained, reference: ^reference}} =
                 HostedCheckout.initialize(credentials, accepted, @scope, port)

        assert_receive {^observed, "POST", "/transaction/initialize", _, _}
        refute_receive {^observed, _, _, _, _}
      end)
    end)
  end

  test "an implicit SQL sandbox transaction cannot send a claim invisible to another connection" do
    P805.with_fixture(fn ->
      {credentials, accepted, reference} = prepared_plan()

      Receiver.with_receiver(&Receiver.success/2, fn port, observed ->
        worker =
          start(
            fn ->
              refute Repo.in_transaction?()
              HostedCheckout.initialize(credentials, accepted, @scope, port)
            end,
            sandbox: true
          )

        send(worker.pid, :run)
        assert {:error, :checkout_unavailable} = result(worker)
        assert %{claim_id: nil, reference: ^reference} = attempt!(accepted)
        refute_receive {^observed, _, _, _, _}, 0

        assert {:ok, %{status: :retained, reference: ^reference}} =
                 HostedCheckout.initialize(credentials, accepted, @scope, port)

        assert_receive {^observed, "POST", "/transaction/initialize", _, _}
        refute_receive {^observed, _, _, _, _}
      end)
    end)
  end

  test "death before claim commit rolls back the claim and preserves the prepared reference across BEAMs" do
    P805.with_fixture(fn ->
      {credentials, accepted, reference} = prepared_plan()

      Receiver.with_receiver(&Receiver.success/2, fn port, observed ->
        interrupt(credentials, accepted, port, :claim_written)
        fresh_recovery!(credentials, accepted, reference, :prepared, port)
        assert %{claim_id: nil, reference: ^reference} = attempt!(accepted)
        refute_receive {^observed, _, _, _, _}, 0

        assert {:ok, %{status: :retained, reference: ^reference}} =
                 HostedCheckout.initialize(credentials, accepted, @scope, port)

        assert_receive {^observed, "POST", "/transaction/initialize", _,
                        %{"reference" => ^reference}}

        refute_receive {^observed, _, _, _, _}
      end)
    end)
  end

  test "death after commitment never releases the claim even when the receiver saw zero requests" do
    P805.with_fixture(fn ->
      {credentials, accepted, reference} = prepared_plan()

      Receiver.with_receiver(&Receiver.success/2, fn port, observed ->
        interrupt(credentials, accepted, port, :claim_committed)
        assert %{claim_id: claim, fixture_code: nil, reference: ^reference} = attempt!(accepted)
        assert is_binary(claim)
        fresh_recovery!(credentials, accepted, reference, :ambiguous, port)
        assert %{claim_id: ^claim, fixture_code: nil} = attempt!(accepted)
        refute_receive {^observed, _, _, _, _}
      end)
    end)
  end

  test "loss at the receiver preserves ambiguity and never resends from a fresh BEAM" do
    P805.with_fixture(fn ->
      {credentials, accepted, reference} = prepared_plan()

      Receiver.with_receiver(
        fn conn, _ ->
          Process.sleep(750)
          Plug.Conn.send_resp(conn, 503, "")
        end,
        fn port, observed ->
          assert {:ok, %{status: :ambiguous, reference: ^reference, authorization_url: nil}} =
                   HostedCheckout.initialize(credentials, accepted, @scope, port)

          assert_receive {^observed, "POST", "/transaction/initialize", _,
                          %{"reference" => ^reference}}

          assert %{claim_id: claim, fixture_code: nil} = attempt!(accepted)
          assert is_binary(claim)
          fresh_recovery!(credentials, accepted, reference, :ambiguous, port)
          assert %{claim_id: ^claim, fixture_code: nil} = attempt!(accepted)
          refute_receive {^observed, _, _, _, _}
        end
      )
    end)
  end

  test "death after capability commit recovers the original URL from a fresh BEAM with no retry" do
    P805.with_fixture(fn ->
      {credentials, accepted, reference} = prepared_plan()

      Receiver.with_receiver(&Receiver.success/2, fn port, observed ->
        interrupt(credentials, accepted, port, :capability_committed)

        assert_receive {^observed, "POST", "/transaction/initialize", _,
                        %{"reference" => ^reference}}

        assert %{claim_id: claim, fixture_code: "fixture-checkout-canary"} = attempt!(accepted)
        fresh_recovery!(credentials, accepted, reference, :retained, port)
        assert %{claim_id: ^claim} = attempt!(accepted)
        refute_receive {^observed, _, _, _, _}
      end)
    end)
  end

  test "authorization lost after admission prevents presentation of a retained fixture capability" do
    P805.with_fixture(fn ->
      {credentials, accepted, reference} = prepared_plan()

      Receiver.with_receiver(&Receiver.success/2, fn port, observed ->
        worker = start(fn -> HostedCheckout.initialize(credentials, accepted, @scope, port) end)

        with_cut(worker, :claim_committed, fn ->
          send(worker.pid, :run)
          await_cut(worker, :claim_committed)
          assert :ok = Identity.revoke_session(credentials)
          send(worker.pid, :release)

          assert {:error, :checkout_unavailable} = result(worker)

          assert_receive {^observed, "POST", "/transaction/initialize", _,
                          %{"reference" => ^reference}}

          assert %{fixture_code: "fixture-checkout-canary"} = attempt!(accepted)

          assert {:error, :checkout_unavailable} =
                   HostedCheckout.recover(credentials, accepted, @scope)

          refute_receive {^observed, _, _, _, _}
        end)
      end)
    end)
  end

  defp prepared_plan do
    payer = verified_party()
    publish!(:plan)
    authority = parties(payer, verified_party())
    quote = quote!(authority, :plan)
    assert {:ok, accepted} = OfferAdmission.accept(authority, acceptance(quote))

    assert {:ok, %{status: :prepared, reference: reference}} =
             HostedCheckout.prepare(payer.credentials, accepted, @scope)

    {payer.credentials, accepted, reference}
  end

  defp interrupt(credentials, accepted, port, stage) do
    observer = self()

    # A tracked witness confirms this one intentional death. Unexpected worker
    # exits still fail the fixture cleanup contract.
    {witness, monitor} =
      spawn_monitor(fn ->
        receive do: (:start -> :ok)

        {pid, worker_monitor} =
          spawn_monitor(fn ->
            receive do: (:run -> :ok)
            :ok = Sandbox.checkout(Repo, sandbox: false)
            HostedCheckout.initialize(credentials, accepted, @scope, port)
          end)

        send(observer, {:interruptible_worker, self(), pid})

        receive do
          {:DOWN, ^worker_monitor, :process, ^pid, :killed} -> :ok
          {:DOWN, ^worker_monitor, :process, ^pid, _} -> exit(:expected_cut_not_observed)
        end
      end)

    :ok = P805.register_cleanup_worker(witness)
    send(witness, :start)
    assert_receive {:interruptible_worker, ^witness, pid}, 5_000

    with_cut(%{pid: pid}, stage, fn ->
      try do
        send(pid, :run)
        await_cut(%{pid: pid}, stage)
      after
        Process.exit(pid, :kill)
      end

      assert_receive {:DOWN, ^monitor, :process, ^witness, :normal}, 5_000
    end)
  end

  defp start(work, sandbox \\ [sandbox: false]) do
    test = self()

    {pid, monitor} =
      spawn_monitor(fn ->
        receive do: (:connect -> :ok)
        :ok = Sandbox.checkout(Repo, sandbox)

        try do
          [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
          send(test, {:connected, self(), backend})
          receive do: (:run -> :ok)
          send(test, {:result, self(), work.()})
        after
          Sandbox.checkin(Repo)
        end
      end)

    :ok = P805.register_cleanup_worker(pid)
    send(pid, :connect)
    assert_receive {:connected, ^pid, backend}, 5_000
    %{pid: pid, monitor: monitor, backend: backend}
  end

  defp result(%{pid: pid, monitor: monitor}) do
    assert_receive {:result, ^pid, value}, 5_000
    assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, 5_000
    value
  end

  defp await_cut(%{pid: pid}, stage) do
    assert_receive {:checkout_cut, ^pid, ^stage}, 5_000
  end

  defp with_cut(worker, stage, fun) do
    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(handler, @checkpoint, &__MODULE__.pause/4, {self(), worker.pid, stage})

    try do
      fun.()
    after
      :telemetry.detach(handler)
    end
  end

  def pause(_, _, %{stage: stage}, {observer, pid, stage}) when pid == self() do
    send(observer, {:checkout_cut, pid, stage})

    receive do
      :release -> :ok
    after
      10_000 -> Process.exit(self(), :kill)
    end
  end

  def pause(_, _, _, _), do: :ok

  defp blocked_on?(_, _, 0), do: false

  defp blocked_on?(waiter, holder, attempts) do
    case Repo.query!("SELECT $2::integer = ANY(pg_blocking_pids($1::integer))", [waiter, holder]).rows do
      [[true]] ->
        true

      [[false]] ->
        Process.sleep(20)
        blocked_on?(waiter, holder, attempts - 1)
    end
  end

  defp attempt!(accepted), do: Ash.get!(HostedDispatch, accepted.attempt_id, authorize?: false)

  defp fresh_recovery!(credentials, accepted, reference, status, port) do
    {executable, arguments} =
      FreshMix.command(["run", "--no-compile", "test/proof/well218_hosted_checkout_restart.exs"])

    payload =
      Jason.encode!(%{
        credentials: credentials,
        signing_key:
          Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret)),
        purchase_id: accepted.purchase_id,
        attempt_id: accepted.attempt_id,
        reference: reference,
        status: status,
        url: if(status == :retained, do: @fixture_url),
        port: port
      })

    assert %{status: :ok, cleanup: :confirmed, marker: :e1af_completed} =
             P815Port.run(executable, arguments, payload, 60_000)
  end
end
