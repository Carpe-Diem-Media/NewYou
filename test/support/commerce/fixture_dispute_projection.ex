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
  Audit assertion. Explicit caller transactions are denied. Identity supplies
  both current scoped grants and the canonical session. Privacy owns purpose
  withdrawal and suppression.
  """
  @spec read(map(), Ecto.UUID.t(), term(), term(), term()) ::
          {:ok, map()} | {:error, :evidence_unavailable}
  def read(credentials, dispute_id, finance_grant_id, privacy_purpose, audit_grant_id) do
    with {:ok, privacy} <- PlanPaymentObservation.verify(privacy_purpose),
         true <- exact_privacy_purpose?(privacy, dispute_id),
         {:ok, finance_grant_id} <- Ecto.UUID.cast(finance_grant_id),
         {:ok, audit_grant_id} <- Ecto.UUID.cast(audit_grant_id),
         operation_id = privacy.operation_id,
         scope =
           Map.merge(privacy, %{
             finance_grant_id: finance_grant_id,
             audit_grant_id: audit_grant_id
           }),
         false <- Repo.in_transaction?(),
         {:ok, {actor_id, projection}} <- read_transaction(credentials, scope),
         true <-
           FixtureDisputeDisclosureEvidence.independently_committed?(
             operation_id,
             actor_id,
             dispute_id
           ) do
      {:ok, projection}
    else
      _ -> @unavailable
    end
  rescue
    _ -> @unavailable
  catch
    _, _ -> @unavailable
  end

  defp read_transaction(credentials, scope) do
    Repo.without_query_telemetry(fn ->
      Ash.transact(
        [
          FixtureDispute,
          Purchase,
          NewYou.Identity.IdentityGrant,
          NewYou.Privacy.FixtureDisputePurposeAuthority,
          NewYou.Privacy.FixtureDisputePurposeEvent,
          NewYou.Privacy.SyntheticDeletionScope,
          FixtureDisputeDisclosure
        ],
        fn -> read_locked(credentials, scope) end
      )
    end)
  end

  defp read_locked(
         credentials,
         %{source_id: dispute_id, subject_id: subject_id, operation_id: operation_id} = scope
       ) do
    with {:ok, %FixtureDispute{} = dispute, %Purchase{} = purchase} <-
           FixtureDisputes.locked_case(dispute_id),
         {:ok, %{account_id: actor_id}} <- Identity.authorize_canonical_session(credentials),
         true <- purchase.recipient_id == subject_id,
         :ok <- Identity.require_fixture_dispute_grants(Map.put(scope, :actor_id, actor_id)),
         :ok <- FixtureDisputePurpose.require_current_locked(subject_id, operation_id, dispute.id),
         :ok <- privacy_allows(purchase),
         {:ok, projection} <- project(dispute, purchase),
         :ok <-
           FixtureDisputeDisclosureEvidence.record_in_transaction(
             operation_id,
             actor_id,
             dispute.id
           ) do
      {actor_id, projection}
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

  defp exact_privacy_purpose?(purpose, source_id) do
    MapSet.new(Map.keys(purpose)) ==
      MapSet.new([:scope, :purpose, :source_id, :operation_id, :state, :subject_id]) and
      purpose.scope == :fixture_dispute_privacy_purpose and
      purpose.purpose == :commercial_dispute_evidence and purpose.source_id == source_id and
      purpose.state == :allowed and valid_uuid?(source_id) and valid_uuid?(purpose.subject_id) and
      valid_uuid?(purpose.operation_id)
  end

  defp valid_uuid?(value) do
    case Ecto.UUID.cast(value) do
      {:ok, ^value} when is_binary(value) -> true
      _ -> false
    end
  end
end
