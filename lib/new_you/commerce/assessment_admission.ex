defmodule NewYou.Commerce.AssessmentAdmission do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_assessment_admissions"
    repo NewYou.Repo

    references do
      reference :purchase, on_delete: :restrict
    end

    custom_indexes do
      index [:recipient_id],
        unique: true,
        where: "state IN ('pending', 'paid')",
        name: "commerce_assessment_admissions_active_recipient"
    end

    check_constraints do
      check_constraint [:state, :resolved_at], "commerce_assessment_admissions_lifecycle",
        check: """
        (state IN ('pending', 'paid') AND resolved_at IS NULL AND resolution_id IS NULL) OR
        (state IN ('nonpayable', 'reconciled') AND resolved_at IS NOT NULL AND resolution_id IS NOT NULL)
        """
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :admit do
      public? false
      accept [:purchase_id, :recipient_id]
    end

    update :record_payment do
      public? false
      accept []
      change set_attribute(:state, :paid)
      change filter expr(state == :pending)
    end

    update :confirm_nonpayable do
      public? false
      accept [:resolved_at, :resolution_id]
      change set_attribute(:state, :nonpayable)
      change filter expr(state == :pending)
    end

    update :acknowledge_credit do
      public? false
      accept [:resolved_at, :resolution_id]
      change set_attribute(:state, :reconciled)
      change filter expr(state == :paid)
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    attribute :purchase_id, :uuid, primary_key?: true, allow_nil?: false
    attribute :recipient_id, :uuid, allow_nil?: false

    attribute :state, :atom,
      default: :pending,
      allow_nil?: false,
      constraints: [one_of: [:pending, :paid, :nonpayable, :reconciled]]

    attribute :resolved_at, AshPostgres.TimestamptzUsec
    attribute :resolution_id, :uuid
    create_timestamp :admitted_at
  end

  relationships do
    belongs_to :purchase, NewYou.Commerce.Purchase do
      define_attribute? false
      allow_nil? false
    end
  end
end
