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

    check_constraints do
      check_constraint [:payer_id, :recipient_id], "commerce_plan_purchases_same_account",
        check: "payer_id = recipient_id"

      check_constraint [:price_version, :amount_minor, :currency],
                       "commerce_plan_purchases_price",
                       check:
                         "price_version = 'synthetic-plan-v1' AND amount_minor = 39900 AND currency = 'ZAR'"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :accept do
      public? false
      accept [:operation_id, :payer_id, :recipient_id, :price_version, :amount_minor, :currency]
      upsert? true
      upsert_identity :operation
      upsert_fields []
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

  identities do
    identity :operation, [:operation_id]
    identity :attempt, [:attempt_id]
  end
end
