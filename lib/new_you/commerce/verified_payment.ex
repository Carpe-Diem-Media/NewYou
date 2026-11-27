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

    identity_wheres_to_sql purchase: "collection_kind = 'primary'"

    check_constraints do
      check_constraint [:fixture_receipt_id, :fixture_transaction_id],
                       "verified_payment_fixture_source",
                       check: """
                       (fixture_receipt_id IS NULL AND fixture_transaction_id IS NULL) OR
                       (fixture_receipt_id IS NOT NULL AND fixture_transaction_id IS NOT NULL AND
                         fixture_transaction_id ~ '^[1-9][0-9]{0,19}$')
                       """

      check_constraint [:collection_kind, :fixture_receipt_id],
                       "verified_payment_collection_kind",
                       check: """
                       collection_kind = 'primary' OR
                         (collection_kind = 'excess' AND fixture_receipt_id IS NOT NULL)
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

    if Mix.env() == :test do
      create :record_excess do
        public? false
        accept [:purchase_id, :fixture_receipt_id, :fixture_transaction_id]
        validate present([:fixture_receipt_id, :fixture_transaction_id])
        change set_attribute(:collection_kind, :excess)
      end
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
    attribute :collection_kind, :atom, default: :primary, allow_nil?: false
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
    identity :purchase, [:purchase_id], where: expr(collection_kind == :primary)
    identity :fixture_transaction, [:fixture_transaction_id]
  end
end
