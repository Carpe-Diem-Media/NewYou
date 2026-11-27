defmodule NewYou.Commerce.FixtureDisputeProjection do
  @moduledoc false

  alias NewYou.Audit.FixtureDisputeDisclosureEvidence
  alias NewYou.Audit.FixtureDisputeDisclosure
  alias NewYou.Commerce.{FixtureDispute, FixtureDisputes, OfferAdmission, Purchase}
  alias NewYou.{Identity, Repo}
  alias NewYou.Privacy.{FixtureDisputePurpose, SyntheticSuppression}
  alias NewYou.Proof.PlanPaymentObservation

  @unavailable {:error, :evidence_unavailable}

  @doc """
  Return the source-bound projection after independent visibility of the exact
  Audit assertion. Explicit caller transactions are denied. Finance and Audit
  proofs carry scoped TEST claims. Privacy purpose and canonical sessions
  supply the independently revocable owner state.
  """
  @spec read(map(), Ecto.UUID.t(), term(), term(), term()) ::
          {:ok, map()} | {:error, :evidence_unavailable}
  def read(credentials, dispute_id, finance_grant, privacy_purpose, audit_grant) do
    with {:ok, finance} <- PlanPaymentObservation.verify(finance_grant),
         {:ok, audit} <- PlanPaymentObservation.verify(audit_grant),
         {:ok, privacy} <- PlanPaymentObservation.verify(privacy_purpose),
         true <- exact_grant?(finance, :finance, dispute_id),
         true <- exact_grant?(audit, :audit, dispute_id),
         true <- exact_privacy_purpose?(privacy, dispute_id),
         actor_id = finance.actor_id,
         operation_id = finance.operation_id,
         subject_id = privacy.subject_id,
         true <-
           audit.actor_id == actor_id and audit.operation_id == operation_id and
             privacy.operation_id == operation_id,
         {:ok, operation_id} <- Ecto.UUID.cast(operation_id),
         {:ok, actor_id} <- Ecto.UUID.cast(actor_id),
         {:ok, dispute_id} <- Ecto.UUID.cast(dispute_id),
         false <- Repo.in_transaction?(),
         {:ok, projection} <-
           read_transaction(credentials, dispute_id, actor_id, subject_id, operation_id),
         true <-
           FixtureDisputeDisclosureEvidence.independently_committed?(
             operation_id,
             actor_id,
             dispute_id
           ) do
      projection
    else
      _ -> @unavailable
    end
  rescue
    _ -> @unavailable
  catch
    _, _ -> @unavailable
  end

  defp read_transaction(credentials, dispute_id, actor_id, subject_id, operation_id) do
    Repo.without_query_telemetry(fn ->
      Ash.transact(
        [
          FixtureDispute,
          Purchase,
          NewYou.Privacy.FixtureDisputePurposeAuthority,
          NewYou.Privacy.FixtureDisputePurposeEvent,
          NewYou.Privacy.SyntheticDeletionScope,
          FixtureDisputeDisclosure
        ],
        fn -> read_locked(credentials, dispute_id, actor_id, subject_id, operation_id) end
      )
    end)
  end

  defp read_locked(credentials, dispute_id, actor_id, subject_id, operation_id) do
    with {:ok, %FixtureDispute{} = dispute, %Purchase{} = purchase} <-
           FixtureDisputes.locked_case(dispute_id),
         {:ok, %{account_id: ^actor_id}} <- Identity.authorize_canonical_session(credentials),
         true <- purchase.recipient_id == subject_id,
         :ok <- FixtureDisputePurpose.require_current_locked(subject_id, operation_id, dispute.id),
         :ok <- privacy_allows(purchase),
         {:ok, projection} <- project(dispute, purchase),
         :ok <-
           FixtureDisputeDisclosureEvidence.record_in_transaction(
             operation_id,
             actor_id,
             dispute.id
           ) do
      {:ok, projection}
    else
      _ -> @unavailable
    end
  end

  defp privacy_allows(purchase) do
    with {:ok, :allowed} <- SyntheticSuppression.locked_status(purchase.payer_id),
         {:ok, :allowed} <- SyntheticSuppression.locked_status(purchase.recipient_id) do
      :ok
    else
      _ -> @unavailable
    end
  end

  defp project(dispute, purchase) do
    with {:ok, _accepted_terms} <- OfferAdmission.accepted_terms(purchase),
         {:ok, payment} <-
           Ash.get(NewYou.Commerce.VerifiedPayment, dispute.payment_id, authorize?: false),
         true <- dispute.amount_minor > 0 and purchase.currency == "ZAR" do
      {:ok,
       %{
         purchase_id: purchase.id,
         payment_id: payment.id,
         dispute_id: dispute.dispute_id,
         amount_minor: dispute.amount_minor,
         currency: purchase.currency,
         allocation: dispute.allocation
       }}
    else
      _ -> @unavailable
    end
  end

  defp exact_grant?(grant, role, source_id) do
    MapSet.new(Map.keys(grant)) ==
      MapSet.new([:scope, :role, :source_id, :actor_id, :operation_id]) and
      grant.scope == :fixture_dispute_evidence_read and grant.role == role and
      grant.source_id == source_id and valid_uuid?(grant.actor_id) and
      valid_uuid?(grant.operation_id)
  end

  defp exact_privacy_purpose?(purpose, source_id) do
    MapSet.new(Map.keys(purpose)) ==
      MapSet.new([:scope, :purpose, :source_id, :operation_id, :state, :subject_id]) and
      purpose.scope == :fixture_dispute_privacy_purpose and
      purpose.purpose == :commercial_dispute_evidence and purpose.source_id == source_id and
      purpose.state == :allowed and valid_uuid?(purpose.subject_id) and
      valid_uuid?(purpose.operation_id)
  end

  defp valid_uuid?(value) do
    case Ecto.UUID.cast(value) do
      {:ok, ^value} when is_binary(value) -> true
      _ -> false
    end
  end
end
