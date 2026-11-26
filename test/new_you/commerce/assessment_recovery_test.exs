defmodule NewYou.Commerce.AssessmentRecoveryTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.{Commerce, Repo}

  alias NewYou.Commerce.{
    AssessmentAdmission,
    AssessmentAdmissions,
    OfferAdmission,
    PaymentConsequence,
    PurchaseQuote
  }

  alias NewYou.Commerce.SyntheticCorrections
  alias NewYou.Entitlements.SyntheticAssessmentCredit
  alias NewYou.Proof.{FreshMix, P805, P815Port}
  import NewYou.Commerce.OfferFixtures
  require Ash.Query

  test "a failed fence insert rolls back all acceptance, leaving the quoted operation retryable" do
    P805.with_fixture(fn ->
      {payer, recipient} = ready_parties()
      authority = parties(payer, recipient)
      quote = quote!(authority, :assessment)

      P805.with_rejected_insert("commerce_assessment_admissions", fn reached? ->
        assert {:error, :purchase_unavailable} =
                 OfferAdmission.accept(authority, acceptance(quote))

        assert reached?.()
      end)

      assert %{state: :offered} = Ash.get!(PurchaseQuote, quote.quote_id, authorize?: false)

      assert {:ok, false} =
               Ash.exists(Ash.Query.filter(Commerce.Purchase, quote_id == ^quote.quote_id),
                 authorize?: false
               )

      assert {:ok, accepted} = OfferAdmission.accept(authority, acceptance(quote))

      assert %{state: :pending} =
               Ash.get!(AssessmentAdmission, accepted.purchase_id, authorize?: false)
    end)
  end

  test "pending and paid assessment competition survives response loss, grant and acknowledgement" do
    P805.with_fixture(fn ->
      {payer, recipient} = ready_parties()
      other_payer = verified_party()
      authority = parties(payer, recipient)
      quote = quote!(authority, :bundle)
      assert {:ok, accepted} = OfferAdmission.accept(authority, acceptance(quote))
      assert {:ok, ^accepted} = OfferAdmission.accept(authority, acceptance(quote))

      assert {:error, :reconciliation_unavailable} =
               AssessmentAdmissions.confirm_nonpayable(
                 nonpayability(accepted, %{outcome: :timeout})
               )

      assert {:error, :assessment_unavailable} = compete(other_payer, recipient)

      observation = payment(accepted)

      assert {:error, :payment_unavailable} =
               Commerce.apply_payment_observation(proof(%{observation.fields | quote_id: uuid()}))

      assert {:ok, applied} = Commerce.apply_payment_observation(observation)
      assert {:ok, ^applied} = Commerce.apply_payment_observation(observation)
      consequence = consequence_for(accepted)

      assert consequence.delivery_kind == :s1_fixture
      assert {:ok, []} = Commerce.open_plan_payment_consequences(accepted.purchase_id)
      assert {:error, :grant_unavailable} = NewYou.Entitlements.grant_paid_plan(consequence.id)

      assert {:error, :grant_unavailable} =
               NewYou.Entitlements.SyntheticRights.converge(accepted.purchase_id)

      assert {:error, :reconciliation_unavailable} =
               AssessmentAdmissions.acknowledge_credit(consequence.id)

      assert {:error, :assessment_unavailable} = compete(other_payer, recipient)

      assert {:ok, right} = SyntheticAssessmentCredit.grant(consequence.id)
      assert right.recipient_id == recipient.account_id
      assert right.component == :assessment
      assert {:error, :assessment_unavailable} = compete(other_payer, recipient)
      assert :ok = AssessmentAdmissions.acknowledge_credit(consequence.id)
      assert :ok = AssessmentAdmissions.acknowledge_credit(consequence.id)
      assert {:ok, replayed_right} = SyntheticAssessmentCredit.grant(consequence.id)
      assert replayed_right.id == right.id
      assert replayed_right.granted_at == right.granted_at

      assert %{state: :reconciled, resolution_id: id} =
               Ash.get!(AssessmentAdmission, accepted.purchase_id, authorize?: false)

      assert id == right.id
      assert {:error, :assessment_unavailable} = compete(other_payer, recipient)
    end)
  end

  test "only qualified irreversible nonpayability releases an unpaid assessment fence" do
    P805.with_fixture(fn ->
      {payer, recipient} = ready_parties()
      authority = parties(payer, recipient)
      offered = quote!(authority, :assessment)
      assert {:ok, first} = OfferAdmission.accept(authority, acceptance(offered))
      assert {:error, :assessment_unavailable} = compete(payer, recipient)

      assert {:error, :reconciliation_unavailable} =
               AssessmentAdmissions.confirm_nonpayable(
                 nonpayability(first, %{attempt_id: uuid()})
               )

      terminal_proof = nonpayability(first)
      assert :ok = AssessmentAdmissions.confirm_nonpayable(terminal_proof)
      assert :ok = AssessmentAdmissions.confirm_nonpayable(terminal_proof)
      assert {:error, :payment_unavailable} = Commerce.apply_payment_observation(payment(first))
      assert {:ok, second} = compete(payer, recipient)
      refute second.purchase_id == first.purchase_id
      assert {:ok, ^first} = OfferAdmission.accept(authority, acceptance(offered))
    end)
  end

  test "qualified component correction after repricing uses the accepted allocation and keeps an independent right" do
    P805.with_fixture(fn ->
      {payer, recipient} = ready_parties()
      authority = parties(payer, recipient)
      offered = quote!(authority, :bundle)
      assert {:ok, accepted} = OfferAdmission.accept(authority, acceptance(offered))

      publish!(:bundle, %{
        amount_minor: 57_100,
        assessment_discount_minor: 2_800,
        plan_discount_minor: 4_900
      })

      observed = payment(accepted)
      assert {:ok, _} = Commerce.apply_payment_observation(observed)
      consequence = consequence_for(accepted)
      assert {:ok, assessment} = SyntheticAssessmentCredit.grant(consequence.id)

      {:ok, legacy} =
        Commerce.accept_plan_purchase(recipient.credentials, %{
          operation_id: operation(),
          price_version: "synthetic-plan-v1"
        })

      assert {:ok, _} =
               Commerce.apply_payment_observation(
                 proof(%{
                   purchase_id: legacy.id,
                   attempt_id: legacy.attempt_id,
                   amount_minor: legacy.amount_minor,
                   currency: legacy.currency,
                   status: :succeeded,
                   integration: :synthetic,
                   environment: :test
                 })
               )

      assert {:ok, [legacy_consequence]} = Commerce.open_plan_payment_consequences(legacy.id)
      assert {:ok, plan} = Commerce.deliver_plan_payment_consequence(legacy_consequence)

      assert {:ok, %{kind: :unresolved}} =
               SyntheticCorrections.observe_correction(
                 correction(accepted, observed, 22_100, :assessment)
               )

      assert {:ok, %{kind: :component_end, amount_minor: 20_000, id: effect}} =
               SyntheticCorrections.observe_correction(
                 correction(accepted, observed, 20_000, :assessment)
               )

      assert {:ok, _} = SyntheticCorrections.deliver(effect)

      assert {:ok,
              %{kind: :component_end, component: :plan, amount_minor: 34_900, id: plan_effect}} =
               SyntheticCorrections.observe_correction(
                 correction(accepted, observed, 34_900, :plan)
               )

      assert {:ok, _} = SyntheticCorrections.deliver(plan_effect)

      assert %{state: :ended} =
               Ash.get!(NewYou.Entitlements.PlanRight, assessment.id, authorize?: false)

      assert %{state: :held_unconsumed} =
               Ash.get!(NewYou.Entitlements.PlanRight, plan.id, authorize?: false)

      assert {:ok, ^accepted} = OfferAdmission.snapshot(payer.credentials, accepted.purchase_id)
    end)
  end

  test "fresh BEAM replay, grant and acknowledgement converge from committed source facts" do
    P805.with_fixture(fn ->
      {payer, recipient} = ready_parties()
      authority = parties(payer, recipient)
      offered = quote!(authority, :assessment)
      commit_without_response(authority, offered)

      assert {:ok, %Commerce.Purchase{id: id}} =
               Ash.read_one(
                 Ash.Query.filter(Commerce.Purchase, quote_id == ^offered.quote_id),
                 authorize?: false
               )

      assert {:ok, accepted} = OfferAdmission.snapshot(payer.credentials, id)

      payload =
        Jason.encode!(%{
          payer: Map.take(payer.credentials, [:session_id, :token]),
          recipient: Map.take(recipient.credentials, [:session_id, :token]),
          payer_id: payer.account_id,
          recipient_id: recipient.account_id,
          operation_id: offered.operation_id,
          quote_id: offered.quote_id,
          disclosure_fingerprint: Base.encode64(offered.disclosure_fingerprint),
          attempt_id: accepted.attempt_id,
          amount_minor: offered.amount_minor,
          signing_key:
            Base.encode64(Application.fetch_env!(:new_you, :identity_token_signing_secret))
        })

      publish!(:assessment, %{amount_minor: 26_500, assessment_list_minor: 26_500})
      fresh_vm!("replay", accepted.purchase_id, payload)
      assert {:error, :assessment_unavailable} = compete(payer, recipient)

      assert {:ok, _} = Commerce.apply_payment_observation(payment(accepted))
      consequence = consequence_for(accepted)
      assert {:error, :assessment_unavailable} = compete(payer, recipient)
      fresh_vm!("grant", accepted.purchase_id)

      assert %{state: :paid} =
               Ash.get!(AssessmentAdmission, accepted.purchase_id, authorize?: false)

      assert %{fulfilled_at: nil} = consequence_for(accepted)
      assert {:error, :assessment_unavailable} = compete(payer, recipient)

      fresh_vm!("ack", accepted.purchase_id)

      assert %{state: :reconciled, resolution_id: right_id} =
               Ash.get!(AssessmentAdmission, accepted.purchase_id, authorize?: false)

      assert %{fulfilled_at: %DateTime{}} = consequence_for(accepted)
      assert {:ok, %{id: ^right_id}} = SyntheticAssessmentCredit.grant(consequence.id)
      assert {:error, :assessment_unavailable} = compete(payer, recipient)
    end)
  end

  defp commit_without_response(authority, offered) do
    parent = self()

    {worker, monitor} =
      spawn_monitor(fn ->
        receive do: (:start -> :ok)
        :ok = Sandbox.checkout(Repo, sandbox: false)
        {:ok, _discarded_response} = OfferAdmission.accept(authority, acceptance(offered))
        send(parent, :acceptance_committed)
      end)

    :ok = P805.register_cleanup_worker(worker)
    send(worker, :start)
    assert_receive :acceptance_committed, 5_000
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, 5_000
  end

  defp fresh_vm!(stage, id, payload \\ "") do
    {executable, arguments} =
      FreshMix.command(["run", "test/proof/well197_admission_restart.exs", stage, id])

    assert %{status: :ok, marker: :s1_completed, cleanup: :confirmed} =
             P815Port.run(executable, arguments, payload, 60_000)
  end

  defp ready_parties do
    payer = verified_party()
    recipient = verified_party()
    establish_clear_eligibility(recipient)
    publish!(:assessment)
    publish!(:bundle)
    {payer, recipient}
  end

  defp compete(payer, recipient) do
    authority = parties(payer, recipient)
    quote = quote!(authority, :assessment)
    OfferAdmission.accept(authority, acceptance(quote))
  end

  defp nonpayability(accepted, overrides \\ %{}) do
    proof(
      Map.merge(
        %{
          scope: :s1_nonpayability,
          purchase_id: accepted.purchase_id,
          attempt_id: accepted.attempt_id,
          quote_id: accepted.terms.quote_id,
          resolution_id: uuid(),
          outcome: :irreversible_nonpayability
        },
        overrides
      )
    )
  end

  defp correction(accepted, observed, amount, component) do
    observed.fields
    |> Map.merge(%{
      scope: :correction,
      status: :final,
      reason: :unused_component,
      source_id: accepted.purchase_id,
      operation_id: accepted.terms.operation_id,
      component: component,
      amount_minor: amount,
      receipt_id: uuid()
    })
    |> proof()
  end

  defp consequence_for(accepted) do
    Ash.read_one!(Ash.Query.filter(PaymentConsequence, purchase_id == ^accepted.purchase_id),
      authorize?: false
    )
  end
end
