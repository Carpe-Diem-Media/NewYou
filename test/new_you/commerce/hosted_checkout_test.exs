defmodule NewYou.Commerce.HostedCheckoutTest do
  use ExUnit.Case, async: false

  alias NewYou.{Commerce, Identity}

  alias NewYou.Commerce.{
    AssessmentAdmission,
    AssessmentAdmissions,
    HostedCheckout,
    HostedDispatch,
    OfferAdmission,
    PaymentConsequence,
    Purchase,
    SyntheticCorrections,
    VerifiedPayment
  }

  alias NewYou.Commerce.HostedCheckoutReceiver, as: Receiver
  alias NewYou.Entitlements.{PlanRight, SyntheticRights}
  alias NewYou.Privacy.SyntheticSuppression
  alias NewYou.Proof.P805

  require Ash.Query

  import NewYou.Commerce.OfferFixtures

  @scope %{provider: :paystack, integration: :local_fixture, environment: :test, channel: :card}
  @fixture_url "https://checkout.paystack.invalid/fixture-checkout-canary"

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
