defmodule NewYou.Commerce.FixtureDispute do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshOban]

  postgres do
    table "commerce_fixture_disputes"
    repo NewYou.Repo

    references do
      reference :payment, on_delete: :restrict
      reference :purchase, on_delete: :restrict
    end

    check_constraints do
      check_constraint [:state, :allocation, :dispute_id], "fixture_dispute_source_shape",
        check: """
        dispute_id ~ '^[1-9][0-9]{0,19}$' AND amount_minor > 0 AND
        allocation IN ('plan', 'excess', 'unallocated') AND
        state IN ('contested', 'awaiting_feedback', 'under_review', 'unresolved', 'restored', 'lost') AND
        revision > 0 AND effect_version > 0 AND
        acknowledged_version BETWEEN 0 AND effect_version AND
        verify_round BETWEEN 0 AND 6
        """
    end

    custom_indexes do
      index [:payment_id]
      index [:verify_after], where: "verify_after IS NOT NULL", name: "fixture_dispute_read_due"

      index [:id],
        where: "acknowledged_version < effect_version",
        name: "fixture_dispute_effect_due"
    end
  end

  if Mix.env() == :test do
    oban do
      triggers do
        trigger :deliver do
          action :deliver
          where expr(acknowledged_version < effect_version)
          scheduler_cron "* * * * *"
          queue :commerce_fixture_dispute
          log_errors? false
          log_final_error? false
          worker_module_name NewYou.Commerce.Workers.DeliverFixtureDispute
          scheduler_module_name NewYou.Commerce.Schedulers.DeliverFixtureDispute
        end

        trigger :read_due do
          action :read_due
          where expr(verify_after <= now() and (state not in [:lost, :restored] or conflict?))
          scheduler_cron "* * * * *"
          queue :commerce_fixture_dispute
          log_errors? false
          log_final_error? false
          worker_module_name NewYou.Commerce.Workers.ReadFixtureDispute
          scheduler_module_name NewYou.Commerce.Schedulers.ReadFixtureDispute
        end
      end
    end
  end

  actions do
    if Mix.env() == :test do
      read :read do
        primary? true
        public? false
        pagination keyset?: true, required?: false
      end
    end

    if Mix.env() == :test do
      create :bind do
        public? false

        accept [
          :payment_id,
          :purchase_id,
          :dispute_id,
          :amount_minor,
          :allocation,
          :state,
          :revision,
          :conflict?,
          :verify_after
        ]

        upsert? true
        upsert_identity :provider_dispute
        upsert_fields []
        upsert_condition expr(false)
        return_skipped_upsert? true
      end

      update :qualify do
        public? false
        accept [:state, :revision, :conflict?, :effect_version]
        change filter(expr(state not in [:lost, :restored]))
      end

      update :record_conflict do
        public? false
        accept [:effect_version]
        change set_attribute(:conflict?, true)
        change set_attribute(:read_token, nil)
      end

      update :confirm_terminal do
        public? false
        accept [:revision, :effect_version]
        change filter(expr(conflict? and state in [:lost, :restored]))
        change set_attribute(:conflict?, false)
      end

      update :acknowledge do
        public? false
        accept [:acknowledged_version]
      end

      update :reserve_read do
        public? false
        accept [:verify_after, :verify_round, :read_token]
      end

      action :deliver do
        public? false
        argument :primary_key, :map, allow_nil?: false
        run {NewYou.Commerce.FixtureDisputeWork, operation: :deliver}
      end

      action :read_due do
        public? false
        argument :primary_key, :map, allow_nil?: false
        run {NewYou.Commerce.FixtureDisputeWork, operation: :read_due}
      end
    end
  end

  policies do
    if Mix.env() == :test do
      policy action_type(:read) do
        authorize_if AshOban.Checks.AshObanInteraction
      end

      policy action([:deliver, :read_due]) do
        authorize_if AshOban.Checks.AshObanInteraction
      end
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :dispute_id, :string, allow_nil?: false, sensitive?: true
    attribute :amount_minor, :integer, allow_nil?: false

    attribute :allocation, :atom,
      allow_nil?: false,
      constraints: [one_of: [:plan, :excess, :unallocated]]

    attribute :state, :atom,
      allow_nil?: false,
      constraints: [
        one_of: [:contested, :awaiting_feedback, :under_review, :unresolved, :restored, :lost]
      ]

    attribute :revision, :integer, allow_nil?: false
    attribute :effect_version, :integer, allow_nil?: false, default: 1
    attribute :acknowledged_version, :integer, allow_nil?: false, default: 0
    attribute :conflict?, :boolean, allow_nil?: false, default: false
    attribute :verify_round, :integer, allow_nil?: false, default: 0
    attribute :verify_after, :utc_datetime_usec, allow_nil?: false
    attribute :read_token, :uuid
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :purchase, NewYou.Commerce.Purchase, allow_nil?: false, attribute_writable?: true

    belongs_to :payment, NewYou.Commerce.VerifiedPayment,
      allow_nil?: false,
      attribute_writable?: true
  end

  identities do
    identity :provider_dispute, [:dispute_id]
  end
end
