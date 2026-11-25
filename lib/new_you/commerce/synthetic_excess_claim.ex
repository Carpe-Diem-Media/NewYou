defmodule NewYou.Commerce.SyntheticExcessClaim do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_synthetic_excess_claims"
    repo NewYou.Repo

    check_constraints do
      check_constraint [:amount_minor, :currency], "commerce_synthetic_excess_claims_amount",
        check: "amount_minor > 0 AND currency = 'ZAR'"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :establish do
      public? false
      accept [:source_id, :claimant_id, :amount_minor, :currency, :collection_id]
    end

    update :satisfy do
      public? false
      accept [:satisfied_at]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    attribute :source_id, :uuid, primary_key?: true, allow_nil?: false
    attribute :claimant_id, :uuid, allow_nil?: false
    attribute :amount_minor, :integer, allow_nil?: false
    attribute :currency, :string, allow_nil?: false
    attribute :satisfied_at, AshPostgres.TimestamptzUsec
    create_timestamp :established_at
  end

  relationships do
    belongs_to :collection, NewYou.Commerce.SyntheticCollection do
      destination_attribute :collection_id
      attribute_writable? true
      allow_nil? false
    end
  end

  identities do
    identity :excess_collection, [:collection_id]
  end
end
