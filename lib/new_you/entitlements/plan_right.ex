defmodule NewYou.Entitlements.PlanRight do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Entitlements,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "entitlements_plan_rights"
    repo NewYou.Repo

    check_constraints do
      check_constraint :component, "entitlements_plan_rights_component",
        check: "component IN ('assessment', 'plan')"

      check_constraint :state, "entitlements_plan_rights_state",
        check: "state IN ('held_unconsumed', 'suspended', 'ended')"
    end

    custom_indexes do
      index [:recipient_id]
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :grant do
      public? false
      accept [:purchase_id, :payment_id, :recipient_id, :component]
      upsert? true
      upsert_identity :purchase_component
      upsert_fields []
      return_skipped_upsert? true
    end

    update :end_component do
      public? false
      accept []
      change atomic_update(:state, :ended)
    end

    if Mix.env() == :test do
      update :suspend_component do
        public? false
        accept []
        change filter(expr(state == :held_unconsumed))
        change atomic_update(:state, :suspended)
      end

      update :restore_component do
        public? false
        accept []
        change filter(expr(state == :suspended))
        change atomic_update(:state, :held_unconsumed)
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
    attribute :purchase_id, :uuid, allow_nil?: false
    attribute :payment_id, :uuid, allow_nil?: false
    attribute :recipient_id, :uuid, allow_nil?: false

    attribute :component, :atom,
      allow_nil?: false,
      default: :plan,
      constraints: [one_of: [:assessment, :plan]]

    attribute :state, :atom,
      default: :held_unconsumed,
      allow_nil?: false,
      constraints: [one_of: [:held_unconsumed, :suspended, :ended]]

    create_timestamp :granted_at
  end

  identities do
    identity :purchase_component, [:purchase_id, :component]
  end
end
