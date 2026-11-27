defmodule NewYou.Commerce.FixtureDisputeProjectionTest do
  use ExUnit.Case, async: false

  alias NewYou.Audit.{
    FixtureDisputeDisclosure,
    FixtureDisputeDisclosureEvidence
  }

  alias NewYou.Commerce.{
    FixtureDisputeProjection,
    HostedCheckout,
    HostedCheckoutReceiver,
    HostedPaymentEvidence,
    OfferAdmission,
    VerifiedPayment
  }

  alias NewYou.Proof.{P805, PlanPaymentObservation}

  alias NewYou.Privacy.{
    FixtureDisputePurpose,
    FixtureDisputePurposeAuthority,
    FixtureDisputePurposeEvent
  }

  alias NewYou.Commerce

  import NewYou.Commerce.OfferFixtures
  require Ash.Query

  @scope %{provider: :paystack, integration: :local_fixture, environment: :test, channel: :card}
  @transaction "18446744073709551613"
  @amount 47_500

  test "finance read projects only accepted commercial fields and records minimized Audit evidence" do
    P805.with_fixture(fn ->
      with_dispute(fn payer, recipient, dispute ->
        operation_id = operation()

        assert {:ok, :allowed} =
                 FixtureDisputePurpose.grant(recipient.account_id, operation_id, dispute.id)

        assert {:ok, privacy_purpose} =
                 FixtureDisputePurpose.issue_proof(recipient.account_id, operation_id, dispute.id)

        proofs = proofs(payer.account_id, dispute.id, operation_id, privacy_purpose)

        assert {:error, :disclosure_unavailable} =
                 FixtureDisputeDisclosureEvidence.record_in_transaction(
                   operation_id,
                   payer.account_id,
                   dispute.id
                 )

        assert disclosure_rows(operation_id) == []

        assert {:ok, projection} =
                 FixtureDisputeProjection.read(
                   payer.credentials,
                   dispute.id,
                   proofs.finance,
                   proofs.privacy,
                   proofs.audit
                 )

        assert Map.keys(projection) |> Enum.sort() ==
                 [:allocation, :amount_minor, :currency, :dispute_id, :payment_id, :purchase_id]

        assert projection.purchase_id == dispute.purchase_id
        assert projection.payment_id == dispute.payment_id
        assert projection.dispute_id == "991"
        assert projection.amount_minor == @amount
        assert projection.currency == "ZAR"
        assert projection.allocation == :plan

        assert Ash.get!(NewYou.Commerce.FixtureDispute, dispute.id, authorize?: false).state ==
                 :contested

        [audit] = disclosure_rows(operation_id)
        assert audit.actor_id == payer.account_id
        assert audit.dispute_id == dispute.id
        assert audit.purpose == :fixture_dispute_evidence_read
        assert audit.field_set == "commercial_dispute_v1"

        [authority] =
          FixtureDisputePurposeAuthority
          |> Ash.Query.filter(
            subject_id == ^recipient.account_id and dispute_id == ^dispute.id and
              source_operation_id == ^operation_id
          )
          |> Ash.read!(authorize?: false)

        assert [%{transition: :granted, version: 1}] =
                 FixtureDisputePurposeEvent
                 |> Ash.Query.filter(authority_id == ^authority.id)
                 |> Ash.Query.sort(version: :asc)
                 |> Ash.read!(authorize?: false)

        assert {:ok, ^projection} =
                 FixtureDisputeProjection.read(
                   payer.credentials,
                   dispute.id,
                   proofs.finance,
                   proofs.privacy,
                   proofs.audit
                 )

        assert length(disclosure_rows(operation_id)) == 1
      end)
    end)
  end

  test "read fails closed for missing, altered, foreign, revoked and wrong-session authority" do
    P805.with_fixture(fn ->
      with_dispute(fn payer, recipient, dispute ->
        operation_id = operation()

        assert {:ok, :allowed} =
                 FixtureDisputePurpose.grant(recipient.account_id, operation_id, dispute.id)

        assert {:ok, privacy_purpose} =
                 FixtureDisputePurpose.issue_proof(recipient.account_id, operation_id, dispute.id)

        proofs = proofs(payer.account_id, dispute.id, operation_id, privacy_purpose)

        assert {:error, :evidence_unavailable} =
                 FixtureDisputeProjection.read(
                   payer.credentials,
                   dispute.id,
                   nil,
                   proofs.privacy,
                   proofs.audit
                 )

        for forbidden_key <- [
              :health_safety_notes,
              :temperament_result,
              :raw_assessment,
              :personalized_plan,
              :journal_entries,
              :private_support_notes,
              :clinical_notes,
              :unrelated_account_history,
              :credentials,
              :attachments,
              :contact_details
            ] do
          altered =
            PlanPaymentObservation.produce(
              Map.put(proofs.finance.fields, forbidden_key, "must not be retained")
            )

          assert {:error, :evidence_unavailable} =
                   FixtureDisputeProjection.read(
                     payer.credentials,
                     dispute.id,
                     altered,
                     proofs.privacy,
                     proofs.audit
                   )
        end

        foreign =
          PlanPaymentObservation.produce(%{
            proofs.finance.fields
            | source_id: uuid()
          })

        assert {:error, :evidence_unavailable} =
                 FixtureDisputeProjection.read(
                   payer.credentials,
                   dispute.id,
                   foreign,
                   proofs.privacy,
                   proofs.audit
                 )

        assert {:ok, :withdrawn} =
                 FixtureDisputePurpose.withdraw(recipient.account_id, operation_id, dispute.id)

        assert {:error, :withdrawn} =
                 FixtureDisputePurpose.grant(recipient.account_id, operation_id, dispute.id)

        assert {:error, :evidence_unavailable} =
                 FixtureDisputeProjection.read(
                   payer.credentials,
                   dispute.id,
                   proofs.finance,
                   privacy_purpose,
                   proofs.audit
                 )

        assert {:error, :privacy_authority_denied} =
                 FixtureDisputePurpose.issue_proof(recipient.account_id, operation_id, dispute.id)

        authority_id =
          privacy_authority_id(recipient.account_id, operation_id, dispute.id)

        assert [%{transition: :granted, version: 1}, %{transition: :withdrawn, version: 2}] =
                 FixtureDisputePurposeEvent
                 |> Ash.Query.filter(authority_id == ^authority_id)
                 |> Ash.Query.sort(version: :asc)
                 |> Ash.read!(authorize?: false)

        assert {:error, :evidence_unavailable} =
                 FixtureDisputeProjection.read(
                   recipient.credentials,
                   dispute.id,
                   proofs.finance,
                   proofs.privacy,
                   proofs.audit
                 )

        assert disclosure_rows(operation_id) == []
      end)
    end)
  end

  test "current Privacy suppression prevents projection and creates no Audit disclosure" do
    P805.with_fixture(fn ->
      with_dispute(fn payer, recipient, dispute ->
        operation_id = operation()

        assert {:ok, :allowed} =
                 FixtureDisputePurpose.grant(recipient.account_id, operation_id, dispute.id)

        assert {:ok, privacy_purpose} =
                 FixtureDisputePurpose.issue_proof(recipient.account_id, operation_id, dispute.id)

        proofs = proofs(payer.account_id, dispute.id, operation_id, privacy_purpose)

        assert :ok =
                 NewYou.Privacy.SyntheticSuppression.suppress(
                   PlanPaymentObservation.produce(%{
                     scope: :completed_deletion,
                     subject_id: recipient.account_id
                   })
                 )

        assert {:error, :evidence_unavailable} =
                 FixtureDisputeProjection.read(
                   payer.credentials,
                   dispute.id,
                   proofs.finance,
                   proofs.privacy,
                   proofs.audit
                 )

        assert disclosure_rows(operation_id) == []
      end)
    end)
  end

  defp with_dispute(callback) do
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
        %{method: "POST", path_info: ["transaction", "initialize"]} = conn, fields ->
          HostedCheckoutReceiver.success(conn, fields)

        %{method: "GET", path_info: ["transaction", "verify", ^reference]} = conn, _fields ->
          HostedCheckoutReceiver.json(conn, 200, %{
            status: true,
            data: %{
              reference: reference,
              id: @transaction,
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

        payment =
          VerifiedPayment
          |> Ash.Query.filter(purchase_id == ^accepted.purchase_id)
          |> Ash.read_one!(authorize?: false)

        webhook_key = :crypto.strong_rand_bytes(32)
        previous_key = Application.get_env(:new_you, :fixture_webhook_key)
        Application.put_env(:new_you, :fixture_webhook_key, webhook_key)

        try do
          data = %{
            scope: "newyou_dispute_fixture",
            reference: reference,
            transaction: @transaction,
            id: "991",
            amount: @amount,
            currency: "ZAR",
            revision: 1,
            outcome: "contested"
          }

          raw = Jason.encode!(%{event: "fixture.dispute", data: data})
          signature = :crypto.mac(:hmac, :sha512, webhook_key, raw) |> Base.encode16(case: :lower)
          assert :ok = HostedPaymentEvidence.ingest(raw, [signature])

          receipts =
            NewYou.Commerce.FixtureDisputeReceipt
            |> Ash.Query.filter(payment_id == ^payment.id)
            |> Ash.read!(authorize?: false)

          Enum.each(receipts, fn receipt ->
            assert :ok = Commerce.apply_fixture_dispute_receipt(receipt.id)
          end)

          dispute =
            NewYou.Commerce.FixtureDispute
            |> Ash.Query.filter(payment_id == ^payment.id)
            |> Ash.read_one!(authorize?: false)

          callback.(payer, recipient, dispute)
        after
          if is_nil(previous_key),
            do: Application.delete_env(:new_you, :fixture_webhook_key),
            else: Application.put_env(:new_you, :fixture_webhook_key, previous_key)
        end
      end
    )
  end

  defp proofs(actor_id, dispute_id, operation_id, privacy_purpose) do
    %{
      finance:
        PlanPaymentObservation.produce(%{
          scope: :fixture_dispute_evidence_read,
          role: :finance,
          source_id: dispute_id,
          actor_id: actor_id,
          operation_id: operation_id
        }),
      privacy: privacy_purpose,
      audit:
        PlanPaymentObservation.produce(%{
          scope: :fixture_dispute_evidence_read,
          role: :audit,
          source_id: dispute_id,
          actor_id: actor_id,
          operation_id: operation_id
        })
    }
  end

  defp disclosure_rows(operation_id) do
    FixtureDisputeDisclosure
    |> Ash.Query.filter(operation_id == ^operation_id)
    |> Ash.read!(authorize?: false)
  end

  defp privacy_authority_id(subject_id, operation_id, dispute_id) do
    FixtureDisputePurposeAuthority
    |> Ash.Query.filter(
      subject_id == ^subject_id and dispute_id == ^dispute_id and
        source_operation_id == ^operation_id
    )
    |> Ash.read_one!(authorize?: false)
    |> Map.fetch!(:id)
  end
end
