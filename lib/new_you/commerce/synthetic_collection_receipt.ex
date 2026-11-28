defmodule NewYou.Commerce.SyntheticCollectionReceipt do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_synthetic_collection_receipts"
    repo NewYou.Repo

    check_constraints do
      check_constraint :fingerprint, "commerce_synthetic_collection_receipts_fingerprint_length",
        check: "octet_length(fingerprint) = 32"
    end

    custom_indexes do
      index [:collection_id]
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :bind do
      public? false
      accept [:receipt_id, :collection_id, :fingerprint]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    attribute :receipt_id, :uuid, primary_key?: true, allow_nil?: false
    attribute :fingerprint, :binary, allow_nil?: false, sensitive?: true
  end

  relationships do
    belongs_to :collection, NewYou.Commerce.SyntheticCollection do
      destination_attribute :collection_id
      attribute_writable? true
      allow_nil? false
    end
  end
end
