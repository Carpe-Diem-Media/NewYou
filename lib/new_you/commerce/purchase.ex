defmodule NewYou.Commerce.Purchase do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_plan_purchases"
    repo NewYou.Repo

    references do
      reference :quote, on_delete: :restrict
    end

    check_constraints do
      check_constraint [:price_version, :amount_minor, :currency],
                       "commerce_plan_purchases_terms",
                       check: """
                       amount_minor > 0 AND currency = 'ZAR' AND
                       (quote_id IS NOT NULL OR
                         (price_version = 'synthetic-plan-v1' AND payer_id = recipient_id))
                       """
    end

    custom_indexes do
      index [:recipient_id]
      index [:payer_id]
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :accept do
      public? false

      accept [
        :operation_id,
        :payer_id,
        :recipient_id,
        :price_version,
        :amount_minor,
        :currency,
        :quote_id
      ]

      argument :acceptance_time, :utc_datetime_usec
      change set_attribute(:accepted_at, arg(:acceptance_time), set_when_nil?: false)
      upsert? true
      upsert_identity :operation
      upsert_fields []
      upsert_condition expr(false)
      return_skipped_upsert? true
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :attempt_id, :uuid, allow_nil?: false, default: &Ash.UUID.generate/0
    attribute :operation_id, :uuid, allow_nil?: false
    attribute :payer_id, :uuid, allow_nil?: false
    attribute :recipient_id, :uuid, allow_nil?: false
    attribute :price_version, :string, allow_nil?: false
    attribute :amount_minor, :integer, allow_nil?: false
    attribute :currency, :string, allow_nil?: false
    create_timestamp :accepted_at
  end

  relationships do
    belongs_to :quote, NewYou.Commerce.PurchaseQuote do
      attribute_writable? true
    end
  end

  identities do
    identity :quote, [:quote_id]
    identity :operation, [:operation_id]
    identity :attempt, [:attempt_id]
  end
end
