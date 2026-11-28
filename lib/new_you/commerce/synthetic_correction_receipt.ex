defmodule NewYou.Commerce.SyntheticCorrectionReceipt do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_synthetic_correction_receipts"
    repo NewYou.Repo

    custom_indexes do
      index [:correction_id]
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :bind do
      public? false
      accept [:receipt_id, :fingerprint, :correction_id]
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
    belongs_to :correction, NewYou.Commerce.SyntheticCorrection do
      attribute_writable? true
      allow_nil? false
    end
  end
end
