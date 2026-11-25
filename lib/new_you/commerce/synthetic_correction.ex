defmodule NewYou.Commerce.SyntheticCorrection do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_synthetic_corrections"
    repo NewYou.Repo

    check_constraints do
      check_constraint [:kind, :component, :amount_minor], "commerce_synthetic_correction_shape",
        check: """
        (kind = 'unresolved' AND component IS NULL AND amount_minor IS NULL AND acknowledged_at IS NULL) OR
        (kind = 'component_end' AND component IS NOT NULL AND component IN ('plan', 'assessment')
          AND amount_minor IS NOT NULL AND amount_minor > 0) OR
        (kind = 'excess_satisfied' AND component IS NULL AND amount_minor IS NOT NULL AND amount_minor > 0)
        """
    end

    custom_indexes do
      index [:source_id, :component],
        unique: true,
        where: "kind = 'component_end'",
        name: "commerce_synthetic_corrections_component_key"

      index [:source_id],
        unique: true,
        where: "kind = 'excess_satisfied'",
        name: "commerce_synthetic_corrections_excess_key"

      index [:source_id, :id],
        where: "acknowledged_at IS NULL AND kind <> 'unresolved'",
        name: "commerce_synthetic_corrections_open"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :record do
      public? false
      accept [:source_id, :receipt_id, :kind, :component, :amount_minor]
    end

    update :acknowledge do
      public? false
      accept [:acknowledged_at]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :source_id, :uuid, allow_nil?: false
    attribute :receipt_id, :uuid, allow_nil?: false

    attribute :kind, :atom,
      constraints: [one_of: [:unresolved, :component_end, :excess_satisfied]],
      allow_nil?: false

    attribute :component, :atom, constraints: [one_of: [:assessment, :plan]]
    attribute :amount_minor, :integer
    attribute :acknowledged_at, AshPostgres.TimestamptzUsec
    create_timestamp :recorded_at
  end

  identities do
    identity :receipt, [:receipt_id]
  end
end
