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

    references do
      reference :fixture_receipt, on_delete: :restrict
    end

    check_constraints do
      check_constraint [:fixture_receipt_id, :fixture_transaction_id],
                       "verified_payment_fixture_source",
                       check: """
                       (fixture_receipt_id IS NULL AND fixture_transaction_id IS NULL) OR
                       (fixture_receipt_id IS NOT NULL AND fixture_transaction_id IS NOT NULL AND
                         fixture_transaction_id ~ '^[1-9][0-9]{0,19}$')
                       """
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :apply do
      public? false
      accept [:purchase_id, :fixture_receipt_id, :fixture_transaction_id]
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
    attribute :fixture_transaction_id, :string, sensitive?: true
  end

  relationships do
    belongs_to :fixture_receipt, NewYou.Commerce.HostedPaymentReceipt do
      attribute_writable? true
    end

    belongs_to :purchase, NewYou.Commerce.Purchase do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :purchase, [:purchase_id]
    identity :fixture_transaction, [:fixture_transaction_id]
  end
end
