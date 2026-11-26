defmodule NewYou.Commerce.HostedCheckoutTransportTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import NewYou.Commerce.OfferFixtures

  alias NewYou.Commerce.{HostedCheckout, HostedDispatch, OfferAdmission}
  alias NewYou.Commerce.HostedCheckoutReceiver, as: Receiver
  alias NewYou.Proof.P805

  @scope %{provider: :paystack, integration: :local_fixture, environment: :test, channel: :card}
  @secret_canary "private-provider-error-canary"

  test "mismatched references, invalid capabilities, malformed envelopes and duplicate responses stay unresolved" do
    P805.with_fixture(fn ->
      {payer, recipient} = publish_plan()

      status_cases = [
        {200, successful_data("different-reference", "https://checkout.paystack.invalid/fake"),
         :invalid_binding},
        {200, successful_data(:matching, "https://checkout.paystack.com/fake"),
         :invalid_capability},
        {200, successful_data(:matching, "https://checkout.paystack.invalid/fake?x=1"),
         :invalid_capability},
        {200, successful_data(:matching, "https://checkout.paystack.invalid/other"),
         :invalid_capability},
        {200, %{"status" => "true", "data" => %{}}, :unrecognized_response},
        {400, %{"status" => false, "code" => "duplicate_reference"}, "duplicate_reference"},
        {404, %{"status" => false, "code" => "transaction_not_found"}, "transaction_not_found"},
        {503, %{"status" => false, "code" => @secret_canary}, :unrecognized_response}
      ]

      observe_transport(fn metric ->
        for {status, body, classification} <- status_cases do
          accepted = accept_plan(payer, recipient)

          Receiver.with_receiver(
            fn conn, payload ->
              body =
                case body do
                  %{"data" => %{"reference" => :matching}} ->
                    put_in(body["data"]["reference"], payload["reference"])

                  _ ->
                    Map.put(body, "message", @secret_canary)
                end

              Receiver.json(conn, status, body)
            end,
            fn port, observed ->
              expect_ambiguous(payer, accepted, port, observed, metric, status, classification)
            end
          )
        end
      end)
    end)
  end

  test "oversized and non-JSON response bodies remain ambiguous and stay out of logs" do
    P805.with_fixture(fn ->
      {payer, recipient} = publish_plan()

      observe_transport(fn metric ->
        for {body, classification} <- [
              {String.duplicate(@secret_canary, 2_000), :oversized_response},
              {"not JSON " <> @secret_canary, :unrecognized_response}
            ] do
          accepted = accept_plan(payer, recipient)

          Receiver.with_receiver(
            fn conn, _ -> Plug.Conn.send_resp(conn, 200, body) end,
            fn port, observed ->
              log =
                capture_log(fn ->
                  expect_ambiguous(payer, accepted, port, observed, metric, 200, classification)
                end)

              refute String.contains?(log, @secret_canary)
              refute String.contains?(log, "rk_test_fixture_well218")
            end
          )
        end
      end)
    end)
  end

  test "fixture URL and code are suppressed in inspected outcomes, records and HTTP evidence" do
    P805.with_fixture(fn ->
      {payer, recipient} = publish_plan()
      accepted = accept_plan(payer, recipient)
      code = "fixture-private-redirect-canary"

      observe_transport(fn metric ->
        Receiver.with_receiver(
          fn conn, payload -> Receiver.success(conn, payload, code) end,
          fn port, observed ->
            assert {:ok, %{reference: reference}} =
                     HostedCheckout.prepare(payer.credentials, accepted, @scope)

            log =
              capture_log(fn ->
                assert {:ok, %{status: :retained} = outcome} =
                         HostedCheckout.initialize(payer.credentials, accepted, @scope, port)

                assert outcome.authorization_url == "https://checkout.paystack.invalid/" <> code
                refute String.contains?(inspect(outcome), code)
                refute String.contains?(inspect(attempt!(accepted)), code)
              end)

            for restricted <- [code, reference, "rk_test_fixture_well218"] do
              refute String.contains?(log, restricted)
            end

            assert_receive {^metric, :attempted}

            assert_receive {^metric,
                            {:response, %{http_status: 200, classification: :initialized}}}

            assert_receive {^observed, "POST", "/transaction/initialize", _, _}
            refute_receive {^observed, _, _, _, _}
          end
        )
      end)
    end)
  end

  test "fixed transport ignores global Req overrides, sends once on 503 and never follows a redirect" do
    P805.with_fixture(fn ->
      {payer, recipient} = publish_plan()
      observer = self()
      defaults = Req.default_options()

      Receiver.with_receiver(&Receiver.success/2, fn redirect_port, target ->
        Req.default_options(
          redirect: true,
          retry: :transient,
          retry_delay: 0,
          plug: fn conn ->
            send(observer, :default_plug_invoked)
            Plug.Conn.send_resp(conn, 503, "")
          end,
          connect_options: [proxy: {:http, "127.0.0.1", redirect_port, []}]
        )

        try do
          observe_transport(fn metric ->
            for status <- [307, 503] do
              accepted = accept_plan(payer, recipient)

              Receiver.with_receiver(
                fn conn, _ ->
                  conn
                  |> Plug.Conn.put_resp_header(
                    "location",
                    "http://127.0.0.1:#{redirect_port}/unexpected"
                  )
                  |> Receiver.json(status, %{"status" => false})
                end,
                fn port, observed ->
                  expect_ambiguous(
                    payer,
                    accepted,
                    port,
                    observed,
                    metric,
                    status,
                    :unrecognized_response
                  )
                end
              )
            end
          end)

          refute_receive :default_plug_invoked, 0
          refute_receive {^target, _, _, _, _}, 0
        after
          Req.default_options(defaults)
        end
      end)
    end)
  end

  test "a receiver that stalls after the POST triggers a bounded timeout without an automatic retry" do
    P805.with_fixture(fn ->
      {payer, recipient} = publish_plan()
      accepted = accept_plan(payer, recipient)

      observe_transport(fn metric ->
        Receiver.with_receiver(
          fn conn, _ ->
            Process.sleep(750)
            Plug.Conn.send_resp(conn, 503, "")
          end,
          fn port, observed ->
            start = System.monotonic_time(:millisecond)
            expect_ambiguous(payer, accepted, port, observed, metric, nil, :timeout)
            assert System.monotonic_time(:millisecond) - start < 3_000
          end
        )
      end)
    end)
  end

  def receive_metric(
        [:new_you, :commerce, :hosted_checkout, :checkpoint],
        %{count: 1},
        %{stage: :initialize_attempted},
        {pid, tag}
      )
      when pid == self() do
    send(pid, {tag, :attempted})
  end

  def receive_metric(
        [:new_you, :commerce, :hosted_checkout, :http],
        %{duration: duration},
        metadata,
        {pid, tag}
      )
      when pid == self() and is_integer(duration) do
    send(pid, {tag, {:response, metadata}})
  end

  def receive_metric(_, _, _, _), do: :ok

  defp observe_transport(fun) do
    tag = make_ref()
    handler = {__MODULE__, tag}

    :ok =
      :telemetry.attach_many(
        handler,
        [
          [:new_you, :commerce, :hosted_checkout, :checkpoint],
          [:new_you, :commerce, :hosted_checkout, :http]
        ],
        &__MODULE__.receive_metric/4,
        {self(), tag}
      )

    try do
      fun.(tag)
    after
      :telemetry.detach(handler)
    end
  end

  defp expect_ambiguous(payer, accepted, port, observed, metric, http_status, classification) do
    assert {:ok, %{reference: reference}} =
             HostedCheckout.prepare(payer.credentials, accepted, @scope)

    assert {:ok, %{status: :ambiguous, reference: ^reference, authorization_url: nil} = outcome} =
             HostedCheckout.initialize(payer.credentials, accepted, @scope, port)

    assert_receive {^metric, :attempted}
    assert_receive {^metric, {:response, metadata}}
    assert metadata == %{http_status: http_status, classification: classification}
    assert_receive {^observed, "POST", "/transaction/initialize", _, %{"reference" => ^reference}}

    assert %{claim_id: claim, fixture_code: nil} = attempt!(accepted)
    assert is_binary(claim)

    assert {:ok, ^outcome} = HostedCheckout.initialize(payer.credentials, accepted, @scope, port)
    assert %{claim_id: ^claim, fixture_code: nil} = attempt!(accepted)
    refute_receive {^observed, _, _, _, _}
    refute_receive {^metric, :attempted}, 0
  end

  defp successful_data(reference, url) do
    %{
      "status" => true,
      "data" => %{"reference" => reference, "access_code" => "fake", "authorization_url" => url}
    }
  end

  defp publish_plan do
    publish!(:plan)
    {verified_party(), verified_party()}
  end

  defp accept_plan(payer, recipient) do
    authority = parties(payer, recipient)
    quote = quote!(authority, :plan)
    assert {:ok, accepted} = OfferAdmission.accept(authority, acceptance(quote))
    accepted
  end

  defp attempt!(accepted), do: Ash.get!(HostedDispatch, accepted.attempt_id, authorize?: false)
end
