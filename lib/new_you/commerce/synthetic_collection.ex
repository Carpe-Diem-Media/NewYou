defmodule NewYou.Commerce.SyntheticCollection do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_synthetic_collections"
    repo NewYou.Repo

    check_constraints do
      check_constraint :amount_minor, "commerce_synthetic_collections_positive_amount",
        check: "amount_minor > 0"
    end

    custom_indexes do
      index [:source_id]
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :record do
      public? false
      accept [:collection_id, :source_id, :amount_minor]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    attribute :collection_id, :uuid, primary_key?: true, allow_nil?: false
    attribute :source_id, :uuid, allow_nil?: false
    attribute :amount_minor, :integer, allow_nil?: false
    create_timestamp :recorded_at
  end
end
