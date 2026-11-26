defmodule NewYou.Commerce.VersionedOfferTest do
  use ExUnit.Case, async: false

  alias NewYou.Commerce.{OfferAdmission, OfferCatalogue}
  alias NewYou.Proof.P805
  import NewYou.Commerce.OfferFixtures

  test "publication is scoped to the exact immutable draft and its independently approved allocation" do
    P805.with_fixture(fn ->
      assert {:ok, draft} = draft_offer(:bundle)
      assert {:error, :offer_unavailable} = OfferCatalogue.approve(draft.id)

      assert {:error, :offer_unavailable} =
               OfferCatalogue.approve(approval(draft, %{allocation_approval_id: nil}))

      assert {:error, :offer_unavailable} = OfferCatalogue.effective(:bundle)

      assert {:ok, approved} = OfferCatalogue.approve(approval(draft))

      assert {:ok, %{price_version: version, amount_minor: 54_900}} =
               OfferCatalogue.effective(:bundle)

      assert approved.price_version == version
      assert {:ok, %{state: :withdrawn}} = OfferCatalogue.withdraw(withdrawal(approved))
      assert {:error, :offer_unavailable} = OfferCatalogue.effective(:bundle)
      assert {:error, :offer_unavailable} = OfferCatalogue.approve(approval(draft))
    end)
  end

  test "repricing changes the active quote and proposed split while preserving an accepted bundle" do
    P805.with_fixture(fn ->
      payer = verified_party()
      recipient = verified_party()
      other_recipient = verified_party()
      establish_clear_eligibility(recipient)
      establish_clear_eligibility(other_recipient)
      old_offer = publish!(:bundle)
      authorization = parties(payer, recipient)
      stale_authorization = parties(payer, other_recipient)
      original = quote!(authorization, :bundle, :af)
      stale = quote!(stale_authorization, :bundle, :en)

      assert original.language == :af
      assert original.price_version == old_offer.price_version
      assert original.discount_minor == 9_900

      assert original.components.assessment == %{
               list_minor: 24_900,
               discount_minor: 4_900,
               amount_minor: 20_000
             }

      assert original.components.plan == %{
               list_minor: 39_900,
               discount_minor: 5_000,
               amount_minor: 34_900
             }

      assert {:error, :acceptance_conflict} =
               OfferAdmission.accept(authorization, %{
                 acceptance(original)
                 | disclosure_fingerprint: original.price_version
               })

      assert {:ok, accepted} = OfferAdmission.accept(authorization, acceptance(original))
      assert accepted.terms == original
      assert accepted.payer_id == payer.account_id
      assert accepted.recipient_id == recipient.account_id

      newer =
        publish!(:bundle, %{
          amount_minor: 57_100,
          assessment_discount_minor: 2_800,
          plan_discount_minor: 4_900
        })

      assert {:error, :stale_quote} =
               OfferAdmission.accept(stale_authorization, acceptance(stale))

      assert {:ok, current} = OfferCatalogue.effective(:bundle)
      assert current.price_version == newer.price_version
      replacement_authority = parties(payer, other_recipient)
      replacement = quote!(replacement_authority, :bundle, :en)
      assert replacement.components.assessment.amount_minor == 22_100
      assert replacement.components.plan.amount_minor == 35_000
      assert replacement.amount_minor == 57_100
      refute replacement.allocation_version == original.allocation_version

      assert {:ok, %{terms: ^replacement}} =
               OfferAdmission.accept(replacement_authority, acceptance(replacement))

      assert {:ok, ^accepted} = OfferAdmission.accept(authorization, acceptance(original))

      assert {:ok, ^accepted} =
               OfferAdmission.snapshot(recipient.credentials, accepted.purchase_id)

      assert {:error, :purchase_unavailable} =
               OfferAdmission.snapshot(other_recipient.credentials, accepted.purchase_id)
    end)
  end

  test "withdrawn and promotion-replaced disclosures cannot be accepted even at an identical total" do
    P805.with_fixture(fn ->
      payer = verified_party()
      approved = publish!(:plan, %{promotion_version: "first-promotion"})
      original_authority = parties(payer, payer)
      original = quote!(original_authority, :plan)

      next = publish!(:plan, %{promotion_version: "second-promotion"})
      assert next.amount_minor == original.amount_minor

      assert {:error, :stale_quote} =
               OfferAdmission.accept(original_authority, acceptance(original))

      successor_authority = parties(payer, payer)
      successor = quote!(successor_authority, :plan)
      assert {:ok, _} = OfferCatalogue.withdraw(withdrawal(next))

      assert {:error, :stale_quote} =
               OfferAdmission.accept(successor_authority, acceptance(successor))

      assert {:error, :offer_unavailable} = OfferCatalogue.effective(:plan)
      assert approved.id == original.offer_id
    end)
  end

  test "expired pricing and incomplete allocations or disclosures fail closed" do
    P805.with_fixture(fn ->
      payer = verified_party()
      assert {:error, :offer_unavailable} = draft_offer(:bundle, %{amount_minor: 54_901})
      assert {:error, :offer_unavailable} = draft_offer(:bundle, %{currency: "USD"})
      assert {:error, :offer_unavailable} = draft_offer(:bundle, %{allocation_version: nil})

      assert {:ok, proposed} = draft_offer(:bundle)

      assert {:error, :offer_unavailable} =
               OfferCatalogue.approve(approval(proposed, %{disclosure_af_id: nil}))

      assert {:error, :offer_unavailable} = OfferCatalogue.effective(:bundle)

      expiry = DateTime.add(DateTime.utc_now(), 3, :second)
      publish!(:plan, %{expires_at: expiry})
      authority = parties(payer, payer)
      quoted = quote!(authority, :plan)
      Process.sleep(max(DateTime.diff(expiry, DateTime.utc_now(), :millisecond), 0) + 10)
      assert {:error, :offer_unavailable} = OfferCatalogue.effective(:plan)
      assert {:error, :stale_quote} = OfferAdmission.accept(authority, acceptance(quoted))
    end)
  end

  test "only authenticated bound parties and a quote-specific owner grant see their permitted data" do
    P805.with_fixture(fn ->
      payer = verified_party()
      recipient = verified_party()
      outsider = verified_party()
      reviewer = verified_party()
      unverified = P805.request()
      assert {:ok, _} = NewYou.Identity.register(unverified)

      assert {:error, _} =
               NewYou.Identity.authenticate_password(unverified.email, unverified.password)

      publish!(:plan)
      authority = parties(payer, recipient)
      offered = quote!(authority, :plan)

      assert {:ok, ^offered} = OfferAdmission.read_quote(payer.credentials, offered.quote_id)
      assert {:ok, ^offered} = OfferAdmission.read_quote(recipient.credentials, offered.quote_id)

      assert {:error, :purchase_unavailable} =
               OfferAdmission.read_quote(outsider.credentials, offered.quote_id)

      assert {:error, :purchase_unavailable} =
               OfferAdmission.accept(
                 %{authority | payer: outsider.credentials},
                 acceptance(offered)
               )

      assert {:error, :purchase_unavailable} =
               OfferAdmission.accept(
                 %{authority | recipient: outsider.credentials},
                 acceptance(offered)
               )

      assert {:error, :purchase_unavailable} =
               OfferAdmission.accept(
                 %{authority | authorization: offered.operation_id},
                 acceptance(offered)
               )

      assert {:error, :acceptance_conflict} =
               OfferAdmission.accept(authority, %{acceptance(offered) | quote_id: uuid()})

      assert {:error, :acceptance_conflict} =
               OfferAdmission.quote(authority, %{product: :plan, language: :af})

      grant =
        proof(%{
          scope: :s1_admission_review,
          quote_id: offered.quote_id,
          account_id: reviewer.account_id
        })

      assert {:ok, %{quote_id: _, state: :offered, decision: nil} = evidence} =
               OfferAdmission.review_admission(reviewer.credentials, grant)

      assert map_size(evidence) == 3

      assert {:error, :purchase_unavailable} =
               OfferAdmission.review_admission(outsider.credentials, grant)

      assert {:error, :purchase_unavailable} =
               OfferAdmission.review_admission(reviewer.credentials, offered.quote_id)

      assert {:error, _} = Ash.get(NewYou.Commerce.PurchaseQuote, offered.quote_id)

      assert {:ok, _} = OfferAdmission.accept(authority, acceptance(offered))
      assert :ok = NewYou.Identity.revoke_session(recipient.credentials)

      assert {:error, :purchase_unavailable} =
               OfferAdmission.accept(authority, acceptance(offered))

      assert {:error, :purchase_unavailable} =
               OfferAdmission.read_quote(recipient.credentials, offered.quote_id)

      assert {:ok, ^offered} = OfferAdmission.read_quote(payer.credentials, offered.quote_id)
    end)
  end
end
