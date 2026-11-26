defmodule NewYou.Commerce.AssessmentAdmissionTest do
  use ExUnit.Case, async: false

  alias NewYou.Commerce.{OfferAdmission, PurchaseQuote}
  alias NewYou.Proof.P805
  import NewYou.Commerce.OfferFixtures

  test "available, held and released ordinary credits block Assessment and bundle but leave Plan independent" do
    P805.with_fixture(fn ->
      payer = verified_party()
      recipient = verified_party()
      plan = publish!(:plan)
      publish!(:assessment)
      publish!(:bundle)
      credit_id = uuid()
      assert {:ok, available} = set_credit(recipient, :available_unused, %{credit_id: credit_id})
      assert {:ok, _} = set_delivery(recipient, :none)

      assert {:error, :assessment_unavailable} = buy(payer, recipient, :assessment)

      assert {:error, {:assessment_unavailable, %{product: :plan, price_version: version}}} =
               buy(payer, recipient, :bundle)

      assert version == plan.price_version

      assert {:ok, held} =
               set_credit(recipient, :held_unconsumed, %{
                 credit_id: credit_id,
                 prior_evidence_id: available.evidence_id,
                 premium_state: :available_unused
               })

      assert {:error, :assessment_unavailable} = buy(payer, recipient, :assessment)

      assert {:ok, %{terms: %{components: %{plan: _} = components}}} =
               buy(payer, recipient, :plan)

      refute Map.has_key?(components, :assessment)

      assert {:ok, released} =
               set_credit(recipient, :available_unused, %{
                 credit_id: credit_id,
                 prior_evidence_id: held.evidence_id,
                 premium_state: :available_unused
               })

      assert released.credit_id == credit_id

      assert {:error, {:assessment_unavailable, %{product: :plan}}} =
               buy(payer, recipient, :bundle)

      assert {:error, :credit_evidence_unavailable} =
               set_credit(recipient, :none, %{prior_evidence_id: available.evidence_id})
    end)
  end

  test "missing source facts are reconcilable, and only a successful delivery sets the annual anchor" do
    P805.with_fixture(fn ->
      recipient = verified_party()
      payer = verified_party()
      publish!(:assessment)
      publish!(:bundle)
      publish!(:plan)
      authority = parties(payer, recipient)
      offered = quote!(authority, :assessment)

      assert {:error, :assessment_unavailable} =
               OfferAdmission.accept(authority, acceptance(offered))

      assert %{state: :reconciling, decision: :credit_evidence_unavailable} =
               Ash.get!(PurchaseQuote, offered.quote_id, authorize?: false)

      assert {:ok, _} =
               set_credit(recipient, :consumed, %{
                 credit_id: uuid(),
                 premium_state: :available_unused
               })

      assert {:error, :assessment_unavailable} =
               OfferAdmission.accept(authority, acceptance(offered))

      assert %{state: :reconciling, decision: :delivery_evidence_unavailable} =
               Ash.get!(PurchaseQuote, offered.quote_id, authorize?: false)

      assert {:ok, _} = buy(payer, recipient, :plan)

      assert {:ok, absent} = set_delivery(recipient, :none)

      assert {:error, :assessment_unavailable} =
               OfferAdmission.accept(authority, acceptance(offered))

      assert %{state: :reconciling, decision: :delivery_evidence_unavailable} =
               Ash.get!(PurchaseQuote, offered.quote_id, authorize?: false)

      assert {:ok, _} =
               set_delivery(recipient, :successful, %{
                 prior_evidence_id: absent.evidence_id,
                 successful_at: DateTime.add(DateTime.utc_now(), -1, :day)
               })

      assert {:error, :assessment_unavailable} =
               OfferAdmission.accept(authority, acceptance(offered))

      assert %{state: :rejected, decision: :annual_interval} =
               Ash.get!(PurchaseQuote, offered.quote_id, authorize?: false)

      older = verified_party()

      assert {:ok, _} =
               set_credit(older, :consumed, %{credit_id: uuid(), premium_state: :available_unused})

      assert {:ok, _} =
               set_delivery(older, :successful, %{
                 successful_at: DateTime.shift(DateTime.utc_now(), year: -1)
               })

      assert {:ok, _} = buy(payer, older, :bundle)
    end)
  end

  defp buy(payer, recipient, product) do
    authority = parties(payer, recipient)
    offered = quote!(authority, product)
    OfferAdmission.accept(authority, acceptance(offered))
  end
end
