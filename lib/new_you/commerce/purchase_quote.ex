defmodule NewYou.Commerce.PurchaseQuote do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_purchase_quotes"
    repo NewYou.Repo

    check_constraints do
      check_constraint [:state, :decision], "commerce_purchase_quotes_state",
        check: """
        (state IN ('offered', 'accepted') AND decision IS NULL) OR
        (state = 'stale' AND decision IS NOT NULL AND decision = 'offer_changed') OR
        (state = 'rejected' AND decision IS NOT NULL AND decision IN ('unused_credit', 'annual_interval', 'competing_purchase')) OR
        (state = 'reconciling' AND decision IS NOT NULL AND decision IN ('credit_evidence_unavailable', 'delivery_evidence_unavailable'))
        """

      check_constraint [:language, :disclosure_fingerprint],
                       "commerce_purchase_quotes_disclosure",
                       check:
                         "language IN ('en', 'af') AND octet_length(disclosure_fingerprint) = 32"
    end

    references do
      reference :offer, on_delete: :restrict
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :offer do
      public? false

      accept [
        :operation_id,
        :payer_id,
        :recipient_id,
        :offer_id,
        :language,
        :disclosure_id,
        :disclosure_fingerprint
      ]

      upsert? true
      upsert_identity :operation
      upsert_fields []
      upsert_condition expr(false)
      return_skipped_upsert? true
    end

    update :decide do
      public? false
      accept [:state, :decision]
      change filter expr(state in [:offered, :reconciling])
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :operation_id, :uuid, allow_nil?: false
    attribute :payer_id, :uuid, allow_nil?: false
    attribute :recipient_id, :uuid, allow_nil?: false
    attribute :language, :atom, allow_nil?: false, constraints: [one_of: [:en, :af]]
    attribute :disclosure_id, :uuid, allow_nil?: false
    attribute :disclosure_fingerprint, :binary, allow_nil?: false

    attribute :state, :atom,
      default: :offered,
      allow_nil?: false,
      constraints: [one_of: [:offered, :accepted, :stale, :rejected, :reconciling]]

    attribute :decision, :atom,
      constraints: [
        one_of: [
          :offer_changed,
          :unused_credit,
          :annual_interval,
          :competing_purchase,
          :credit_evidence_unavailable,
          :delivery_evidence_unavailable
        ]
      ]

    create_timestamp :offered_at
  end

  relationships do
    belongs_to :offer, NewYou.Commerce.OfferVersion do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :operation, [:operation_id]
  end
end
