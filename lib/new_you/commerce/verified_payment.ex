defmodule NewYou.Commerce.VerifiedPayment do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_verified_payments"
    repo NewYou.Repo
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :apply do
      public? false
      accept [:purchase_id]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    create_timestamp :verified_at
  end

  relationships do
    belongs_to :purchase, NewYou.Commerce.Purchase do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :purchase, [:purchase_id]
  end
end
