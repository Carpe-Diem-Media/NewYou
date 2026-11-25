defmodule NewYou.Commerce.SyntheticOrder do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_synthetic_correction_orders"
    repo NewYou.Repo

    check_constraints do
      check_constraint [:amount_minor, :currency], "commerce_synthetic_order_allocation",
        check: """
        currency = 'ZAR' AND amount_minor > 0 AND
        plan_discount_minor >= 0 AND plan_list_minor > plan_discount_minor AND
        assessment_discount_minor >= 0 AND assessment_list_minor > assessment_discount_minor AND
        (plan_list_minor - plan_discount_minor) +
          (assessment_list_minor - assessment_discount_minor) = amount_minor
        """
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :accept_fixture do
      public? false

      accept [
        :operation_id,
        :payer_id,
        :recipient_id,
        :price_version,
        :currency,
        :amount_minor,
        :plan_list_minor,
        :plan_discount_minor,
        :assessment_list_minor,
        :assessment_discount_minor
      ]

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
    attribute :operation_id, :uuid, allow_nil?: false
    attribute :payer_id, :uuid, allow_nil?: false
    attribute :recipient_id, :uuid, allow_nil?: false
    attribute :price_version, :string, allow_nil?: false
    attribute :currency, :string, allow_nil?: false
    attribute :amount_minor, :integer, allow_nil?: false
    attribute :plan_list_minor, :integer, allow_nil?: false
    attribute :plan_discount_minor, :integer, allow_nil?: false
    attribute :assessment_list_minor, :integer, allow_nil?: false
    attribute :assessment_discount_minor, :integer, allow_nil?: false
    create_timestamp :accepted_at
  end

  identities do
    identity :operation, [:operation_id]
  end
end
