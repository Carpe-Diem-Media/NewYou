defmodule NewYou.Commerce.OfferFixtures do
  @moduledoc false

  alias NewYou.Commerce.{OfferAdmission, OfferCatalogue}
  alias NewYou.Entitlements.SyntheticAssessmentCredit
  alias NewYou.Identity
  alias NewYou.Privacy.SyntheticSuppression
  alias NewYou.Proof.{P805, PlanPaymentObservation}
  alias NewYou.Temperament.SyntheticAssessmentDelivery

  def proof(fields), do: PlanPaymentObservation.produce(fields)
  def uuid, do: Ecto.UUID.generate()

  def draft_offer(product, overrides \\ %{}) do
    id = operation()

    defaults = %{
      id: id,
      product: product,
      price_version: "offer-" <> id,
      currency: "ZAR",
      amount_minor: 54_900,
      plan_list_minor: 39_900,
      plan_discount_minor: 5_000,
      assessment_list_minor: 24_900,
      assessment_discount_minor: 4_900,
      allocation_version: "allocation-" <> id,
      promotion_version: "promotion-" <> id
    }

    defaults =
      case product do
        :bundle ->
          defaults

        :plan ->
          %{
            defaults
            | amount_minor: 39_900,
              plan_discount_minor: 0,
              assessment_list_minor: 0,
              assessment_discount_minor: 0,
              allocation_version: nil,
              promotion_version: nil
          }

        :assessment ->
          %{
            defaults
            | amount_minor: 24_900,
              plan_list_minor: 0,
              plan_discount_minor: 0,
              assessment_discount_minor: 0,
              allocation_version: nil,
              promotion_version: nil
          }
      end

    OfferCatalogue.draft(proof(%{scope: :s1_offer_draft, terms: Map.merge(defaults, overrides)}))
  end

  def approval(offer, overrides \\ %{}) do
    proof(
      Map.merge(
        %{
          scope: :s1_offer_approval,
          offer_id: offer.id,
          approval_id: uuid(),
          allocation_approval_id: if(offer.product == :bundle, do: uuid()),
          disclosure_en_id: uuid(),
          disclosure_af_id: uuid()
        },
        overrides
      )
    )
  end

  def publish!(product, overrides \\ %{}) do
    {:ok, draft} = draft_offer(product, overrides)
    {:ok, published} = OfferCatalogue.approve(approval(draft))
    published
  end

  def withdrawal(offer),
    do: proof(%{scope: :s1_offer_withdrawal, offer_id: offer.id, withdrawal_id: uuid()})

  def operation do
    id = uuid()
    P805.track_operation(id)
    id
  end

  def verified_party do
    request = P805.request()
    {:ok, registration} = Identity.register(request)
    {:ok, :verified} = Identity.verify_email(registration.verification_proof)
    {:ok, credentials} = Identity.authenticate_password(request.email, request.password)
    :ok = SyntheticSuppression.register(credentials)
    %{account_id: registration.account_id, credentials: credentials}
  end

  def parties(payer, recipient, operation_id \\ operation()) do
    %{
      payer: payer.credentials,
      recipient: recipient.credentials,
      authorization:
        proof(%{
          scope: :s1_purchase_parties,
          operation_id: operation_id,
          payer_id: payer.account_id,
          recipient_id: recipient.account_id
        })
    }
  end

  def quote!(authority, product, language \\ :en) do
    {:ok, quote} = OfferAdmission.quote(authority, %{product: product, language: language})
    quote
  end

  def acceptance(quote), do: Map.take(quote, [:operation_id, :quote_id, :disclosure_fingerprint])

  def payment(accepted) do
    proof(%{
      scope: :s1_payment,
      quote_id: accepted.terms.quote_id,
      purchase_id: accepted.purchase_id,
      attempt_id: accepted.attempt_id,
      amount_minor: accepted.terms.amount_minor,
      currency: accepted.terms.currency,
      price_version: accepted.terms.price_version,
      payer_id: accepted.payer_id,
      recipient_id: accepted.recipient_id,
      collection_id: uuid(),
      receipt_id: uuid(),
      integration: :synthetic,
      environment: :test,
      status: :succeeded
    })
  end

  def establish_clear_eligibility(recipient) do
    {:ok, _} = set_credit(recipient, :none)
    {:ok, _} = set_delivery(recipient, :none)
    :ok
  end

  def set_credit(recipient, state, overrides \\ %{}) do
    SyntheticAssessmentCredit.establish(
      proof(
        Map.merge(
          %{
            scope: :s1_credit_evidence,
            recipient_id: recipient.account_id,
            evidence_id: uuid(),
            prior_evidence_id: nil,
            ordinary_state: state,
            credit_id: nil,
            premium_state: :none
          },
          overrides
        )
      )
    )
  end

  def set_delivery(recipient, state, overrides \\ %{}) do
    SyntheticAssessmentDelivery.establish(
      proof(
        Map.merge(
          %{
            scope: :s1_delivery_evidence,
            recipient_id: recipient.account_id,
            evidence_id: uuid(),
            prior_evidence_id: nil,
            status: state,
            successful_at: nil
          },
          overrides
        )
      )
    )
  end
end
