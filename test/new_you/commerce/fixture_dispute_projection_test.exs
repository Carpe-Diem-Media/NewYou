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

  alias NewYou.{Commerce, Identity}
  alias NewYou.Identity.IdentityGrant

  import NewYou.Commerce.OfferFixtures
  require Ash.Query

  @scope %{provider: :paystack, integration: :local_fixture, environment: :test, channel: :card}
  @amount 47_500

  test "signed Finance and Audit claims cannot authorize disclosure without current grants" do
    P805.with_fixture(fn ->
      with_dispute(fn payer, recipient, dispute ->
        operation_id = operation()

        assert {:ok, :allowed} =
                 FixtureDisputePurpose.grant(recipient.account_id, operation_id, dispute.id)

        assert {:ok, privacy} =
                 FixtureDisputePurpose.issue_proof(recipient.account_id, operation_id, dispute.id)

        [finance, audit] =
          for role <- [:finance, :audit] do
            PlanPaymentObservation.produce(%{
              scope: :fixture_dispute_evidence_read,
              role: role,
              source_id: dispute.id,
              actor_id: payer.account_id,
              operation_id: operation_id
            })
          end

        result =
          FixtureDisputeProjection.read(payer.credentials, dispute.id, finance, privacy, audit)

        assert {:error, :evidence_unavailable} = result
        assert disclosure_rows(operation_id) == []
      end)
    end)
  end

  test "Finance and Audit grants can each be revoked without withdrawing purpose or revoking the session" do
    for role <- [:finance, :audit_reader] do
      with_disclosure(fn payer, recipient, dispute, scope, privacy, approvers ->
        grants = reader_grants(scope, approvers)
        control_scope = %{scope | source_operation_id: operation()}

        control_privacy =
          allow_purpose(recipient.account_id, control_scope.source_operation_id, dispute.id)

        assert {:ok, _} =
                 read_with_grants(
                   payer,
                   dispute,
                   control_privacy,
                   reader_grants(control_scope, approvers)
                 )

        grant = grants[role]
        other = if role == :finance, do: :audit_reader, else: :finance

        assert {:error, :disclosure_grant_unavailable} =
                 Identity.revoke_fixture_dispute_grant(approvers[other].credentials, grant.id)

        assert {:ok, %{state: :revoked, version: 2, revoked_at: %DateTime{}}} =
                 Identity.revoke_fixture_dispute_grant(approvers[role].credentials, grant.id)

        assert {:ok, %{state: :revoked, version: 2}} =
                 Identity.revoke_fixture_dispute_grant(approvers[role].credentials, grant.id)

        revoker = approvers[role].account_id
        reader = payer.account_id

        assert [_] =
                 NewYou.Audit.EvidenceObligation
                 |> Ash.Query.filter(
                   evidence_type == :identity_grant_revoked and actor_id == ^revoker and
                     target_id == ^reader
                 )
                 |> Ash.read!(authorize?: false)

        assert_current_session_and_purpose(payer, recipient, scope)
        assert {:error, :evidence_unavailable} = read_with_grants(payer, dispute, privacy, grants)
        assert [] = disclosure_rows(scope.source_operation_id)

        replacement = issue_reader!(role, scope, approvers)
        assert replacement.id != grant.id

        assert {:ok, _} =
                 read_with_grants(payer, dispute, privacy, Map.put(grants, role, replacement))

        assert {:error, :evidence_unavailable} = read_with_grants(payer, dispute, privacy, grants)
        assert [_] = disclosure_rows(scope.source_operation_id)
      end)
    end
  end

  test "expired Finance or Audit authority denies a current session and Privacy purpose" do
    for role <- [:finance, :audit_reader] do
      with_disclosure(fn payer, recipient, dispute, scope, privacy, approvers ->
        other = if role == :finance, do: :audit_reader, else: :finance
        other_grant = issue_reader!(other, scope, approvers)
        expiry = DateTime.add(DateTime.utc_now(), 2, :second)
        expiring = issue_reader!(role, %{scope | expires_at: expiry}, approvers)
        grants = %{role => expiring, other => other_grant}

        Process.sleep(
          max(0, DateTime.diff(expiring.expires_at, DateTime.utc_now(), :millisecond)) + 2
        )

        assert DateTime.compare(expiring.expires_at, DateTime.utc_now()) in [:lt, :eq]
        assert_current_session_and_purpose(payer, recipient, scope)
        assert {:error, :evidence_unavailable} = read_with_grants(payer, dispute, privacy, grants)
        assert [] = disclosure_rows(scope.source_operation_id)
      end)
    end
  end

  test "only the matching Domain approver can approve a distinct reader for the exact scope" do
    with_disclosure(fn payer, recipient, dispute, scope, privacy, approvers ->
      support = verified_party()

      {:ok, support_grant} =
        Ash.create(
          IdentityGrant,
          %{
            subject_account_id: support.account_id,
            target_account_id: recipient.account_id,
            approver_account_id: payer.account_id,
            role: :support,
            scope: :identity_lookup,
            reason_code: :security_review,
            starts_at: DateTime.add(DateTime.utc_now(), -60),
            expires_at: scope.expires_at
          },
          action: :provision,
          authorize?: false
        )

      for {role, wrong} <- [finance: :audit_reader, audit_reader: :finance] do
        request = Map.put(scope, :role, role)

        for actor <- [payer, support, approvers[wrong]] do
          assert {:error, :disclosure_grant_unavailable} =
                   Identity.issue_fixture_dispute_grant(actor.credentials, request)
        end

        assert {:error, :disclosure_grant_unavailable} =
                 Identity.issue_fixture_dispute_grant(
                   approvers[role].credentials,
                   %{request | subject_account_id: approvers[role].account_id}
                 )

        assert {:error, :disclosure_grant_unavailable} =
                 Identity.issue_fixture_dispute_grant(
                   approvers[role].credentials,
                   %{request | target_account_id: payer.account_id}
                 )

        assert {:error, :disclosure_grant_unavailable} =
                 Identity.issue_fixture_dispute_grant(
                   approvers[role].credentials,
                   %{request | expires_at: DateTime.add(DateTime.utc_now(), -1)}
                 )
      end

      grants = reader_grants(scope, approvers)

      for {role, grant} <- grants do
        assert grant.approver_account_id == approvers[role].account_id
        assert grant.approval_grant_id == approvers[role].approval_id
        refute IdentityGrant.permits?(grant, :lookup_identity)
      end

      assert IdentityGrant.permits?(support_grant, :lookup_identity)

      assert {:error, :evidence_unavailable} =
               FixtureDisputeProjection.read(
                 payer.credentials,
                 dispute.id,
                 grants.audit_reader.id,
                 privacy,
                 grants.finance.id
               )

      other_privacy = allow_purpose(recipient.account_id, operation(), dispute.id)

      assert {:error, :evidence_unavailable} =
               read_with_grants(payer, dispute, other_privacy, grants)

      assert {:error, :evidence_unavailable} =
               read_with_grants(recipient, dispute, privacy, grants)

      assert [] = disclosure_rows(scope.source_operation_id)
      assert {:ok, _} = read_with_grants(payer, dispute, privacy, grants)
    end)
  end

  test "finance read projects only accepted commercial fields and records minimized Audit evidence" do
    P805.with_fixture(fn ->
      with_dispute(fn payer, recipient, dispute ->
        operation_id = operation()

        assert {:ok, :allowed} =
                 FixtureDisputePurpose.grant(recipient.account_id, operation_id, dispute.id)

        assert {:ok, privacy_purpose} =
                 FixtureDisputePurpose.issue_proof(recipient.account_id, operation_id, dispute.id)

        proofs = proofs(payer, recipient, dispute.id, operation_id, privacy_purpose)

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

        assert FixtureDisputeDisclosureEvidence.independently_committed?(
                 operation_id,
                 payer.account_id,
                 dispute.id
               )

        assert Map.keys(projection) |> Enum.sort() ==
                 [:allocation, :amount_minor, :currency, :dispute_id, :payment_id, :purchase_id]

        assert projection.purchase_id == dispute.purchase_id
        assert projection.payment_id == dispute.payment_id
        assert projection.dispute_id == dispute.dispute_id
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

  test "read fails closed inside an explicitly enclosing transaction" do
    P805.with_fixture(fn ->
      with_dispute(fn payer, recipient, dispute ->
        operation_id = operation()

        assert {:ok, :allowed} =
                 FixtureDisputePurpose.grant(recipient.account_id, operation_id, dispute.id)

        assert {:ok, privacy_purpose} =
                 FixtureDisputePurpose.issue_proof(recipient.account_id, operation_id, dispute.id)

        proofs = proofs(payer, recipient, dispute.id, operation_id, privacy_purpose)

        assert {:error, :enclosing_rollback} =
                 NewYou.Repo.transaction(fn ->
                   assert {:error, :evidence_unavailable} =
                            FixtureDisputeProjection.read(
                              payer.credentials,
                              dispute.id,
                              proofs.finance,
                              proofs.privacy,
                              proofs.audit
                            )

                   assert disclosure_rows(operation_id) == []
                   NewYou.Repo.rollback(:enclosing_rollback)
                 end)

        assert disclosure_rows(operation_id) == []
      end)
    end)
  end

  test "read fails closed inside an implicit Sandbox transaction" do
    P805.with_fixture(fn ->
      with_dispute(fn payer, recipient, dispute ->
        operation_id = operation()

        assert {:ok, :allowed} =
                 FixtureDisputePurpose.grant(recipient.account_id, operation_id, dispute.id)

        assert {:ok, privacy_purpose} =
                 FixtureDisputePurpose.issue_proof(recipient.account_id, operation_id, dispute.id)

        proofs = proofs(payer, recipient, dispute.id, operation_id, privacy_purpose)

        task =
          Task.async(fn ->
            :ok = Ecto.Adapters.SQL.Sandbox.checkout(NewYou.Repo)

            try do
              assert {:error, :evidence_unavailable} =
                       FixtureDisputeProjection.read(
                         payer.credentials,
                         dispute.id,
                         proofs.finance,
                         proofs.privacy,
                         proofs.audit
                       )

              refute FixtureDisputeDisclosureEvidence.independently_committed?(
                       operation_id,
                       payer.account_id,
                       dispute.id
                     )

              :ok
            after
              Ecto.Adapters.SQL.Sandbox.checkin(NewYou.Repo)
            end
          end)

        assert :ok = Task.await(task, 5_000)
        assert disclosure_rows(operation_id) == []
      end)
    end)
  end

  test "read fails closed when the Audit insert is rejected" do
    P805.with_fixture(fn ->
      with_dispute(fn payer, recipient, dispute ->
        operation_id = operation()

        assert {:ok, :allowed} =
                 FixtureDisputePurpose.grant(recipient.account_id, operation_id, dispute.id)

        assert {:ok, privacy_purpose} =
                 FixtureDisputePurpose.issue_proof(recipient.account_id, operation_id, dispute.id)

        proofs = proofs(payer, recipient, dispute.id, operation_id, privacy_purpose)

        P805.with_rejected_insert("audit_fixture_dispute_disclosures", fn reached ->
          assert {:error, :evidence_unavailable} =
                   FixtureDisputeProjection.read(
                     payer.credentials,
                     dispute.id,
                     proofs.finance,
                     proofs.privacy,
                     proofs.audit
                   )

          assert reached.()
          assert disclosure_rows(operation_id) == []
        end)
      end)
    end)
  end

  test "read fails closed for missing or foreign claims, Privacy withdrawal and session denial" do
    P805.with_fixture(fn ->
      with_dispute(fn payer, recipient, dispute ->
        operation_id = operation()

        assert {:ok, :allowed} =
                 FixtureDisputePurpose.grant(recipient.account_id, operation_id, dispute.id)

        assert {:ok, privacy_purpose} =
                 FixtureDisputePurpose.issue_proof(recipient.account_id, operation_id, dispute.id)

        proofs = proofs(payer, recipient, dispute.id, operation_id, privacy_purpose)

        for {finance, privacy, audit} <- [
              {nil, proofs.privacy, proofs.audit},
              {proofs.finance, nil, proofs.audit},
              {proofs.finance, proofs.privacy, nil}
            ] do
          assert {:error, :evidence_unavailable} =
                   FixtureDisputeProjection.read(
                     payer.credentials,
                     dispute.id,
                     finance,
                     privacy,
                     audit
                   )
        end

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
          altered = %{forbidden_key => "must not be retained", grant_id: proofs.finance}

          assert {:error, :evidence_unavailable} =
                   FixtureDisputeProjection.read(
                     payer.credentials,
                     dispute.id,
                     altered,
                     proofs.privacy,
                     proofs.audit
                   )
        end

        foreign_privacy =
          PlanPaymentObservation.produce(%{proofs.privacy.fields | source_id: uuid()})

        for claims <- [
              %{proofs | finance: uuid()},
              %{proofs | audit: uuid()},
              %{proofs | privacy: foreign_privacy}
            ] do
          assert {:error, :evidence_unavailable} =
                   FixtureDisputeProjection.read(
                     payer.credentials,
                     dispute.id,
                     claims.finance,
                     claims.privacy,
                     claims.audit
                   )
        end

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

        proofs = proofs(payer, recipient, dispute.id, operation_id, privacy_purpose)

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
    transaction = large_provider_id()
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
            transaction: transaction,
            id: large_provider_id(payment.id),
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

  defp proofs(payer, recipient, dispute_id, operation_id, privacy_purpose) do
    scope = grant_scope(payer, recipient, dispute_id, operation_id)
    grants = reader_grants(scope, fixture_approvers(recipient))

    %{finance: grants.finance.id, audit: grants.audit_reader.id, privacy: privacy_purpose}
  end

  defp with_disclosure(callback) do
    P805.with_fixture(fn ->
      with_dispute(fn payer, recipient, dispute ->
        operation_id = operation()
        scope = grant_scope(payer, recipient, dispute.id, operation_id)
        privacy = allow_purpose(recipient.account_id, operation_id, dispute.id)
        callback.(payer, recipient, dispute, scope, privacy, fixture_approvers(recipient))
      end)
    end)
  end

  defp allow_purpose(subject, operation, dispute) do
    assert {:ok, :allowed} = FixtureDisputePurpose.grant(subject, operation, dispute)
    assert {:ok, proof} = FixtureDisputePurpose.issue_proof(subject, operation, dispute)
    proof
  end

  defp assert_current_session_and_purpose(payer, recipient, scope) do
    reader_id = payer.account_id

    assert {:ok, %{account_id: ^reader_id}} =
             Identity.authorize_canonical_session(payer.credentials)

    assert {:ok, _} =
             FixtureDisputePurpose.issue_proof(
               recipient.account_id,
               scope.source_operation_id,
               scope.dispute_id
             )
  end

  defp grant_scope(payer, recipient, dispute, operation) do
    %{
      subject_account_id: payer.account_id,
      target_account_id: recipient.account_id,
      dispute_id: dispute,
      source_operation_id: operation,
      expires_at: DateTime.add(DateTime.utc_now(), 3_600)
    }
  end

  defp fixture_approvers(recipient) do
    bootstrap = verified_party()

    for {reader, role, scope} <- [
          {:finance, :finance_disclosure_approver, :approve_finance_dispute_disclosure},
          {:audit_reader, :audit_access_approver, :approve_audit_dispute_evidence}
        ],
        into: %{} do
      approver = verified_party()

      {:ok, grant} =
        Ash.create(
          IdentityGrant,
          %{
            subject_account_id: approver.account_id,
            target_account_id: recipient.account_id,
            approver_account_id: bootstrap.account_id,
            role: role,
            scope: scope,
            reason_code: :security_review,
            starts_at: DateTime.add(DateTime.utc_now(), -60),
            expires_at: DateTime.add(DateTime.utc_now(), 3_600)
          },
          action: :provision_fixture_dispute_approver,
          authorize?: false
        )

      {reader, Map.put(approver, :approval_id, grant.id)}
    end
  end

  defp reader_grants(scope, approvers) do
    %{
      finance: issue_reader!(:finance, scope, approvers),
      audit_reader: issue_reader!(:audit_reader, scope, approvers)
    }
  end

  defp issue_reader!(role, scope, approvers) do
    assert {:ok, grant} =
             Identity.issue_fixture_dispute_grant(
               approvers[role].credentials,
               Map.put(scope, :role, role)
             )

    grant
  end

  defp read_with_grants(payer, dispute, privacy, grants) do
    FixtureDisputeProjection.read(
      payer.credentials,
      dispute.id,
      grants.finance.id,
      privacy,
      grants.audit_reader.id
    )
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
