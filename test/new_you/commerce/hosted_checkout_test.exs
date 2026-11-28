defmodule NewYou.Commerce.HostedCheckoutTest do
  use ExUnit.Case, async: false

  alias NewYou.{Commerce, Identity, Repo}

  alias NewYou.Commerce.{
    AssessmentAdmission,
    AssessmentAdmissions,
    HostedCheckout,
    HostedDispatch,
    OfferAdmission,
    PaystackCheckout,
    PaystackTestIntegration,
    PaymentConsequence,
    Purchase,
    SyntheticCorrections,
    VerifiedPayment
  }

  alias NewYou.Commerce.HostedCheckoutReceiver, as: Receiver
  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Entitlements.{PlanRight, SyntheticRights}
  alias NewYou.Privacy.SyntheticSuppression
  alias NewYou.Proof.P805
  alias NewYou.Proof.{FreshMix, P815Port}

  require Ash.Query

  import NewYou.Commerce.OfferFixtures

  @scope %{provider: :paystack, integration: :local_fixture, environment: :test, channel: :card}
  @fixture_url "https://checkout.paystack.invalid/fixture-checkout-canary"
  @provider_scope %{@scope | integration: :voelgoedwinkel}
  @provider_url "https://checkout.paystack.com/provider-checkout-canary"

  test "runtime activation still requires the current payer and exact accepted source" do
    P805.with_fixture(fn ->
      {payer, recipient, accepted} = accept(:plan, %{})
      key = "rk_test_runtime_credential_canary"
      email = "runtime-email-canary@example.test"
      capability_key = Base.encode64(:binary.copy(<<113>>, 32))

      settings = %{
        "NEW_YOU_PAYSTACK_TEST_ENABLED" => "true",
        "NEW_YOU_PAYSTACK_TEST_APPROVED_ATTEMPT_ID" => accepted.attempt_id,
        "NEW_YOU_PAYSTACK_TEST_RESTRICTED_KEY" => key,
        "NEW_YOU_PAYSTACK_TEST_EMAIL" => email,
        "NEW_YOU_PAYSTACK_TEST_CAPABILITY_KEY" => capability_key
      }

      with_environment(settings, fn ->
        assert {:error, :checkout_unavailable} =
                 HostedCheckout.prepare(recipient.credentials, accepted, @provider_scope)

        altered = put_in(accepted.terms.amount_minor, accepted.terms.amount_minor + 1)

        assert {:error, :checkout_unavailable} =
                 HostedCheckout.prepare(payer.credentials, altered, @provider_scope)

        assert {:ok, nil} =
                 Ash.get(HostedDispatch, accepted.attempt_id, authorize?: false, error?: false)

        assert {:ok, %{status: :prepared, reference: reference} = prepared} =
                 HostedCheckout.prepare(payer.credentials, accepted, @provider_scope)

        assert {:ok, configured} = PaystackTestIntegration.settings(accepted.attempt_id)
        request = PaystackCheckout.build_provider(accepted.terms, reference, configured)
        assert request.method == :post
        assert URI.to_string(request.url) == "https://api.paystack.co/transaction/initialize"
        assert request.options.retry == false
        assert request.options.redirect == false
        assert request.options.connect_options[:protocols] == [:http1]
        assert request.options.connect_options[:transport_opts][:verify] == :verify_peer

        for private <- [key, email, reference, capability_key] do
          refute inspect(request) =~ private
        end

        assert {:ok, ^prepared} =
                 HostedCheckout.recover(payer.credentials, accepted, @provider_scope)

        refute inspect(prepared) =~ reference

        observer = self()
        handler = make_ref()

        :ok =
          :telemetry.attach_many(
            handler,
            [[:finch, :send, :start], [:finch, :recv, :stop]],
            fn event, _, _, pid -> send(pid, {:raw_transport_event, event}) end,
            observer
          )

        try do
          log =
            ExUnit.CaptureLog.capture_log(fn ->
              assert {:error, :checkout_unavailable} =
                       HostedCheckout.initialize(payer.credentials, accepted, @provider_scope)
            end)

          for canary <- [key, email, capability_key, reference] do
            refute log =~ canary
          end

          refute_received {:raw_transport_event, _}
        after
          :telemetry.detach(handler)
        end

        assert %{claim_id: nil, verify_after: nil, provider_capability: nil} = attempt!(accepted)
      end)
    end)
  end

  defp with_environment(settings, run) do
    previous = Map.new(settings, fn {key, _} -> {key, System.get_env(key)} end)
    System.put_env(settings)

    try do
      run.()
    after
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end
  end

  test "the scoped TEST integration initializes once and recovers an encrypted capability" do
    P805.with_fixture(fn ->
      {payer, _recipient, accepted} =
        accept(:plan, %{amount_minor: 39_900, plan_list_minor: 39_900})

      response = fn conn, payload ->
        Plug.Conn.send_resp(
          conn,
          200,
          Jason.encode!(%{
            status: true,
            data: %{
              reference: payload["reference"],
              access_code: "provider-checkout-canary",
              authorization_url: @provider_url
            }
          })
        )
      end

      Receiver.with_bound_receiver(response, fn listener, observed ->
        Application.put_env(:new_you, :paystack_test_checkout, %{
          attempt_id: accepted.attempt_id,
          restricted_key: "rk_test_local_e1a",
          email: "checkout@example.com",
          capability_key: :crypto.strong_rand_bytes(32),
          listener: listener
        })

        try do
          assert {:ok, %{status: :prepared, reference: reference}} =
                   HostedCheckout.prepare(payer.credentials, accepted, @provider_scope)

          assert {:error, :checkout_unavailable} =
                   HostedCheckout.prepare(payer.credentials, accepted, @scope)

          result = HostedCheckout.initialize(payer.credentials, accepted, @provider_scope)

          assert_receive {^observed, "POST", "/transaction/initialize",
                          ["Bearer rk_test_local_e1a"], payload}

          assert {:ok,
                  %{status: :retained, reference: ^reference, authorization_url: @provider_url}} =
                   result

          assert payload == %{
                   "amount" => 39_900,
                   "currency" => "ZAR",
                   "channels" => ["card"],
                   "email" => "checkout@example.com",
                   "reference" => reference
                 }

          assert %{fixture_code: nil, verify_after: nil, provider_capability: ciphertext} =
                   attempt!(accepted)

          assert is_binary(ciphertext)
          refute ciphertext =~ "provider-checkout-canary"

          assert {:ok, %{status: :retained, authorization_url: @provider_url}} =
                   HostedCheckout.recover(payer.credentials, accepted, @provider_scope)

          fresh_provider_recovery!(payer.credentials, accepted, reference, listener)

          settings = Application.fetch_env!(:new_you, :paystack_test_checkout)

          Application.put_env(:new_you, :paystack_test_checkout, %{
            settings
            | capability_key: <<0::256>>
          })

          assert {:ok, %{status: :ambiguous, reference: ^reference, authorization_url: nil}} =
                   HostedCheckout.initialize(payer.credentials, accepted, @provider_scope)

          refute_receive {^observed, _, _, _, _}
          assert_no_financial_effects(accepted.purchase_id)
        after
          Application.delete_env(:new_you, :paystack_test_checkout)
        end
      end)
    end)
  end

  test "a raw HTTP event handler blocks dispatch before the durable claim is consumed" do
    P805.with_fixture(fn ->
      {payer, _, accepted} = accept(:plan, %{})

      Receiver.with_bound_receiver(&Receiver.success/2, fn listener, observed ->
        with_provider_settings(accepted, listener, fn ->
          assert {:ok, %{status: :prepared}} =
                   HostedCheckout.prepare(payer.credentials, accepted, @provider_scope)

          handler = make_ref()

          :ok =
            :telemetry.attach(
              handler,
              [:finch, :send, :start],
              fn _, _, _, _ ->
                send(self(), :unexpected_raw_request)
              end,
              nil
            )

          try do
            assert {:error, :checkout_unavailable} =
                     HostedCheckout.initialize(payer.credentials, accepted, @provider_scope)

            assert %{claim_id: nil, provider_capability: nil} = attempt!(accepted)
            refute_receive {^observed, _, _, _, _}
            refute_receive :unexpected_raw_request
          after
            :telemetry.detach(handler)
          end
        end)
      end)
    end)
  end

  test "provider transport stops after 503 or a redirect and keeps response data out of evidence" do
    P805.with_fixture(fn ->
      for status <- [503, 302] do
        {payer, _, accepted} = accept(:plan, %{})
        canary = "private-provider-response-canary"

        response = fn conn, _ ->
          conn
          |> Plug.Conn.put_resp_header("location", @provider_url)
          |> Plug.Conn.send_resp(status, canary)
        end

        Receiver.with_bound_receiver(response, fn listener, observed ->
          with_provider_settings(accepted, listener, fn ->
            assert {:ok, %{status: :prepared, reference: reference}} =
                     HostedCheckout.prepare(payer.credentials, accepted, @provider_scope)

            observer = self()
            handler = make_ref()

            :ok =
              :telemetry.attach(
                handler,
                [:new_you, :commerce, :hosted_checkout, :http],
                fn _, measurements, metadata, pid ->
                  send(pid, {:provider_evidence, measurements, metadata})
                end,
                observer
              )

            try do
              log =
                ExUnit.CaptureLog.capture_log(fn ->
                  assert {:ok, %{status: :ambiguous, reference: ^reference} = result} =
                           HostedCheckout.initialize(payer.credentials, accepted, @provider_scope)

                  refute inspect(result) =~ reference
                  refute inspect(result) =~ @provider_url
                end)

              assert_receive {^observed, "POST", "/transaction/initialize", _,
                              %{"reference" => ^reference}}

              assert_receive {:provider_evidence, %{duration: duration}, metadata}
              assert is_integer(duration)
              assert metadata.http_status == status
              assert Map.keys(metadata) |> Enum.sort() == [:classification, :http_status]
              assert %{provider_capability: nil, verify_after: nil} = attempt!(accepted)
              refute_receive {^observed, _, _, _, _}
              refute_receive {:provider_evidence, _, _}

              for secret <- [
                    reference,
                    canary,
                    @provider_url,
                    "rk_test_local_e1a",
                    "checkout@example.com"
                  ] do
                refute log =~ secret
              end
            after
              :telemetry.detach(handler)
            end
          end)
        end)
      end
    end)
  end

  test "a lost provider response across racing processes keeps the first reference fenced" do
    P805.with_fixture(fn ->
      {payer, _, accepted} = accept(:plan, %{})
      drop = fn _conn, _payload -> Process.exit(self(), :kill) end

      Receiver.with_bound_receiver(drop, fn listener, observed ->
        with_provider_settings(accepted, listener, fn ->
          assert {:ok, %{status: :prepared, reference: reference}} =
                   HostedCheckout.prepare(payer.credentials, accepted, @provider_scope)

          results =
            1..2
            |> Task.async_stream(fn _ ->
              Sandbox.unboxed_run(Repo, fn ->
                HostedCheckout.initialize(payer.credentials, accepted, @provider_scope)
              end)
            end)
            |> Enum.to_list()

          assert [
                   {:ok, {:ok, %{status: :ambiguous, reference: ^reference}}},
                   {:ok, {:ok, %{status: :ambiguous, reference: ^reference}}}
                 ] = results

          assert_receive {^observed, "POST", "/transaction/initialize", _,
                          %{"reference" => ^reference}}

          assert %{claim_id: claim, provider_capability: nil, verify_after: nil} =
                   attempt!(accepted)

          assert is_binary(claim)

          assert {:ok, %{status: :ambiguous, reference: ^reference}} =
                   HostedCheckout.recover(payer.credentials, accepted, @provider_scope)

          assert {:ok, %{status: :ambiguous, reference: ^reference}} =
                   HostedCheckout.initialize(payer.credentials, accepted, @provider_scope)

          assert %{claim_id: ^claim} = attempt!(accepted)
          refute_receive {^observed, _, _, _, _}
          assert_no_financial_effects(accepted.purchase_id)
        end)
      end)
    end)
  end

  defp with_provider_settings(accepted, listener, run) do
    Application.put_env(:new_you, :paystack_test_checkout, %{
      attempt_id: accepted.attempt_id,
      restricted_key: "rk_test_local_e1a",
      email: "checkout@example.com",
      capability_key: :crypto.strong_rand_bytes(32),
      listener: listener
    })

    try do
      run.()
    after
      Application.delete_env(:new_you, :paystack_test_checkout)
    end
  end

  defp fresh_provider_recovery!(credentials, accepted, reference, listener) do
    {program, args} =
      FreshMix.command(["run", "--no-compile", "test/proof/well218_hosted_checkout_restart.exs"])

    settings = Application.fetch_env!(:new_you, :paystack_test_checkout)

    body =
      Jason.encode!(%{
        credentials: credentials,
        signing_key:
          Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret)),
        purchase_id: accepted.purchase_id,
        attempt_id: accepted.attempt_id,
        reference: reference,
        status: :retained,
        url: @provider_url,
        integration: :voelgoedwinkel,
        capability_key: Base.encode64(settings.capability_key),
        certificate: Base.encode64(listener.certificate),
        port: listener.port
      })

    assert %{status: :ok, cleanup: :confirmed, marker: :e1af_completed} =
             P815Port.run(program, args, body, 60_000)
  end

  test "initializes hosted checkout once using the durable reference and accepted money" do
    P805.with_fixture(fn ->
      {payer, _recipient, accepted} =
        accept(:plan, %{amount_minor: 41_700, plan_list_minor: 41_700})

      Receiver.with_receiver(&Receiver.success/2, fn port, observed ->
        assert {:ok, %{status: :prepared, reference: reference}} =
                 HostedCheckout.prepare(payer.credentials, accepted, @scope)

        assert {:ok, %{status: :retained, reference: ^reference, authorization_url: @fixture_url}} =
                 HostedCheckout.initialize(payer.credentials, accepted, @scope, port)

        assert_receive {^observed, "POST", "/transaction/initialize",
                        ["Bearer rk_test_fixture_well218"], payload}

        assert payload == %{
                 "amount" => 41_700,
                 "currency" => "ZAR",
                 "reference" => reference,
                 "email" => "checkout-fixture@example.com",
                 "channels" => ["card"]
               }

        assert {:ok, %{status: :retained, reference: ^reference, authorization_url: @fixture_url}} =
                 HostedCheckout.initialize(payer.credentials, accepted, @scope, port)

        refute_receive {^observed, _, _, _, _}
      end)
    end)
  end

  test "the adapter has no independent wire entry around Commerce admission" do
    assert Code.ensure_loaded?(NewYou.Commerce.PaystackCheckout)
    refute function_exported?(NewYou.Commerce.PaystackCheckout, :initialize, 3)
  end

  test "rejects changed terms, attempt, disclosure and provider scope without consuming the claim" do
    P805.with_fixture(fn ->
      {payer, _recipient, accepted} = accept(:plan, %{})
      credentials = payer.credentials

      Receiver.with_receiver(&Receiver.success/2, fn port, observed ->
        assert {:error, :checkout_unavailable} =
                 HostedCheckout.initialize(credentials, accepted, @scope, port)

        assert {:ok, %{status: :prepared, reference: reference}} =
                 HostedCheckout.prepare(credentials, accepted, @scope)

        for changed <- [
              %{accepted | attempt_id: uuid()},
              %{accepted | recipient_id: uuid()},
              put_in(accepted.terms.amount_minor, 39_901),
              put_in(accepted.terms.components.plan.amount_minor, 39_901),
              put_in(accepted.terms.currency, "USD"),
              put_in(accepted.terms.price_version, "other-offer"),
              put_in(accepted.terms.disclosure_fingerprint, <<0::256>>),
              put_in(accepted.terms.quote_id, uuid())
            ] do
          assert {:error, :checkout_unavailable} =
                   HostedCheckout.prepare(credentials, changed, @scope)

          assert {:error, :checkout_unavailable} =
                   HostedCheckout.initialize(credentials, changed, @scope, port)

          assert {:error, :checkout_unavailable} =
                   HostedCheckout.recover(credentials, changed, @scope)
        end

        for {field, value} <- [
              provider: :other,
              integration: :other,
              environment: :live,
              channel: :eft
            ] do
          scope = Map.put(@scope, field, value)

          assert {:error, :checkout_unavailable} =
                   HostedCheckout.prepare(credentials, accepted, scope)

          assert {:error, :checkout_unavailable} =
                   HostedCheckout.initialize(credentials, accepted, scope, port)
        end

        assert %{claim_id: nil, reference: ^reference} = attempt!(accepted)
        refute_receive {^observed, _, _, _, _}, 0

        assert {:ok, %{status: :retained, reference: ^reference}} =
                 HostedCheckout.initialize(credentials, accepted, @scope, port)

        assert_receive {^observed, "POST", "/transaction/initialize", _,
                        %{"reference" => ^reference}}
      end)
    end)
  end

  test "purchase observation does not authorize recipient or third party initiation or capability recovery" do
    P805.with_fixture(fn ->
      {payer, recipient, accepted} = accept(:plan, %{})
      outsider = verified_party()

      assert {:ok, ^accepted} =
               OfferAdmission.snapshot(recipient.credentials, accepted.purchase_id)

      Receiver.with_receiver(&Receiver.success/2, fn port, observed ->
        for credentials <- [recipient.credentials, outsider.credentials, %{}] do
          assert {:error, :checkout_unavailable} =
                   HostedCheckout.prepare(credentials, accepted, @scope)
        end

        assert {:ok, %{status: :prepared}} =
                 HostedCheckout.prepare(payer.credentials, accepted, @scope)

        for credentials <- [recipient.credentials, outsider.credentials, %{}] do
          assert {:error, :checkout_unavailable} =
                   HostedCheckout.initialize(credentials, accepted, @scope, port)
        end

        assert %{claim_id: nil} = attempt!(accepted)
        refute_receive {^observed, _, _, _, _}, 0

        assert {:ok, %{status: :retained}} =
                 HostedCheckout.initialize(payer.credentials, accepted, @scope, port)

        for credentials <- [recipient.credentials, outsider.credentials, %{}] do
          assert {:error, :checkout_unavailable} =
                   HostedCheckout.recover(credentials, accepted, @scope)
        end

        assert :ok = Identity.revoke_session(payer.credentials)

        assert {:error, :checkout_unavailable} =
                 HostedCheckout.recover(payer.credentials, accepted, @scope)

        assert {:error, :checkout_unavailable} =
                 HostedCheckout.initialize(payer.credentials, accepted, @scope, port)

        assert_receive {^observed, "POST", "/transaction/initialize", _, _}
        refute_receive {^observed, _, _, _, _}
      end)
    end)
  end

  test "rechecks revoked payer and recipient suppression before the claim" do
    P805.with_fixture(fn ->
      {payer, _recipient, accepted} = accept(:plan, %{})
      other_payer = verified_party()
      other_recipient = verified_party()
      other = accept_purchase(other_payer, other_recipient, :plan)

      assert {:ok, _} = HostedCheckout.prepare(payer.credentials, accepted, @scope)
      assert {:ok, _} = HostedCheckout.prepare(other_payer.credentials, other, @scope)
      assert :ok = Identity.revoke_session(payer.credentials)

      assert :ok =
               SyntheticSuppression.suppress(
                 proof(%{scope: :completed_deletion, subject_id: other_recipient.account_id})
               )

      Receiver.with_receiver(&Receiver.success/2, fn port, observed ->
        assert {:error, :checkout_unavailable} =
                 HostedCheckout.initialize(payer.credentials, accepted, @scope, port)

        assert {:error, :checkout_unavailable} =
                 HostedCheckout.initialize(other_payer.credentials, other, @scope, port)

        assert %{claim_id: nil} = attempt!(accepted)
        assert %{claim_id: nil} = attempt!(other)
        refute_receive {^observed, _, _, _, _}
      end)
    end)
  end

  test "rejects quote-less P1, paid and corrected Plan, and authoritatively closed Assessment" do
    P805.with_fixture(fn ->
      {payer, recipient, paid} = accept(:plan, %{})
      credentials = payer.credentials

      assert {:ok, %Purchase{quote_id: nil} = legacy} =
               Commerce.accept_plan_purchase(credentials, %{
                 operation_id: operation(),
                 price_version: "synthetic-plan-v1"
               })

      spoofed = %{
        paid
        | purchase_id: legacy.id,
          attempt_id: legacy.attempt_id,
          recipient_id: legacy.recipient_id
      }

      assert {:error, :checkout_unavailable} =
               HostedCheckout.prepare(credentials, spoofed, @scope)

      assert {:ok, nil} =
               Ash.get(HostedDispatch, legacy.attempt_id, authorize?: false, error?: false)

      observed = payment(paid)
      assert {:ok, _} = Commerce.apply_payment_observation(observed)
      assert {:error, :checkout_unavailable} = HostedCheckout.prepare(credentials, paid, @scope)

      correction =
        observed.fields
        |> Map.merge(%{
          scope: :correction,
          status: :final,
          reason: :unused_component,
          source_id: paid.purchase_id,
          operation_id: paid.terms.operation_id,
          component: :plan,
          receipt_id: uuid()
        })
        |> proof()

      assert {:ok, %{kind: :component_end}} = SyntheticCorrections.observe_correction(correction)
      assert {:error, :checkout_unavailable} = HostedCheckout.prepare(credentials, paid, @scope)

      establish_clear_eligibility(recipient)
      publish!(:assessment)
      closed = accept_purchase(payer, recipient, :assessment)

      assert :ok =
               AssessmentAdmissions.confirm_nonpayable(
                 proof(%{
                   scope: :s1_nonpayability,
                   purchase_id: closed.purchase_id,
                   attempt_id: closed.attempt_id,
                   quote_id: closed.terms.quote_id,
                   resolution_id: uuid(),
                   outcome: :irreversible_nonpayability
                 })
               )

      assert %{state: :nonpayable} =
               Ash.get!(AssessmentAdmission, closed.purchase_id, authorize?: false)

      for snapshot <- [paid, closed] do
        assert {:error, :checkout_unavailable} =
                 HostedCheckout.prepare(credentials, snapshot, @scope)

        assert {:ok, nil} =
                 Ash.get(HostedDispatch, snapshot.attempt_id, authorize?: false, error?: false)
      end
    end)
  end

  test "local capabilities and synthetic evidence stay isolated from payments, rights and the Assessment interlock" do
    P805.with_fixture(fn ->
      {payer, recipient, accepted} = accept(:plan, %{})
      establish_clear_eligibility(recipient)
      publish!(:assessment)
      publish!(:bundle)
      assessment = accept_purchase(payer, recipient, :assessment)

      assert {:error, :checkout_unavailable} =
               HostedCheckout.prepare(payer.credentials, assessment, @scope)

      assert {:ok, _} = HostedCheckout.prepare(payer.credentials, accepted, @scope)
      s1_evidence = payment(accepted)
      p1_evidence = proof(Map.delete(s1_evidence.fields, :scope))

      assert {:error, :payment_unavailable} = Commerce.apply_payment_observation(s1_evidence)
      assert {:error, :payment_unavailable} = Commerce.apply_payment_observation(p1_evidence)

      Receiver.with_receiver(&Receiver.success/2, fn port, observed ->
        assert {:ok, %{status: :retained} = capability} =
                 HostedCheckout.initialize(payer.credentials, accepted, @scope, port)

        assert {:error, :payment_unavailable} = Commerce.apply_payment_observation(capability)
        assert {:error, :payment_unavailable} = Commerce.apply_payment_observation(s1_evidence)
        assert {:error, :grant_unavailable} = SyntheticRights.converge(accepted.purchase_id)
        assert_no_financial_effects(accepted.purchase_id)

        assert %{state: :pending} =
                 Ash.get!(AssessmentAdmission, assessment.purchase_id, authorize?: false)

        authority = parties(payer, recipient)
        bundle = quote!(authority, :bundle)

        assert {:error, {:assessment_unavailable, %{product: :plan}}} =
                 OfferAdmission.accept(authority, acceptance(bundle))

        assert_receive {^observed, "POST", "/transaction/initialize", _, _}
        refute_receive {^observed, _, _, _, _}
      end)

      unrelated = accept_purchase(payer, recipient, :plan)

      assert {:ok, %VerifiedPayment{purchase_id: id}} =
               Commerce.apply_payment_observation(payment(unrelated))

      assert id == unrelated.purchase_id
    end)
  end

  defp assert_no_financial_effects(id) do
    for resource <- [VerifiedPayment, PaymentConsequence, PlanRight] do
      assert {:ok, false} =
               Ash.exists(Ash.Query.filter(resource, purchase_id == ^id), authorize?: false)
    end
  end

  defp attempt!(accepted), do: Ash.get!(HostedDispatch, accepted.attempt_id, authorize?: false)

  defp accept(product, overrides) do
    payer = verified_party()
    recipient = verified_party()
    publish!(product, overrides)
    {payer, recipient, accept_purchase(payer, recipient, product)}
  end

  defp accept_purchase(payer, recipient, product) do
    authority = parties(payer, recipient)
    quote = quote!(authority, product)
    assert {:ok, accepted} = OfferAdmission.accept(authority, acceptance(quote))
    accepted
  end
end
