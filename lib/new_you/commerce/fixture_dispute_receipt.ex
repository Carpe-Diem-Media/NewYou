defmodule NewYou.Commerce.FixtureDisputeReceipt do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshOban]

  postgres do
    table "commerce_fixture_dispute_receipts"
    repo NewYou.Repo

    references do
      reference :payment, on_delete: :restrict
    end

    check_constraints do
      check_constraint [:digest, :state, :source, :outcome], "fixture_dispute_receipt_shape",
        check: """
        octet_length(digest) = 32 AND
        dispute_id ~ '^[1-9][0-9]{0,19}$' AND amount_minor > 0 AND revision > 0 AND
        ((source = 'webhook' AND read_token IS NULL) OR (source = 'read' AND read_token IS NOT NULL)) AND
        outcome IN ('contested', 'awaiting_feedback', 'under_review', 'unresolved', 'restored', 'lost') AND
        state IN ('pending', 'applied', 'stale', 'conflict', 'quarantined')
        """
    end

    custom_indexes do
      index [:payment_id]
      index [:id], where: "state = 'pending'", name: "fixture_dispute_receipt_pending"
    end
  end

  if Mix.env() == :test do
    oban do
      triggers do
        trigger :process do
          action :process
          where expr(state == :pending)
          scheduler_cron "* * * * *"
          queue :commerce_fixture_dispute
          log_errors? false
          log_final_error? false
          worker_module_name NewYou.Commerce.Workers.ProcessFixtureDisputeReceipt
          scheduler_module_name NewYou.Commerce.Schedulers.ProcessFixtureDisputeReceipt
        end
      end
    end
  end

  actions do
    read :read do
      primary? true
      public? false
      pagination keyset?: true, required?: false
    end

    if Mix.env() == :test do
      create :receive do
        public? false

        accept [
          :source,
          :digest,
          :payment_id,
          :dispute_id,
          :amount_minor,
          :revision,
          :outcome,
          :read_token
        ]

        upsert? true
        upsert_identity :evidence
        upsert_fields []
        upsert_condition expr(false)
        return_skipped_upsert? true
      end

      update :classify do
        public? false
        accept [:state]
        change filter(expr(state == :pending))
      end

      action :process do
        public? false
        argument :primary_key, :map, allow_nil?: false
        run {NewYou.Commerce.FixtureDisputeWork, operation: :process}
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if AshOban.Checks.AshObanInteraction
    end

    if Mix.env() == :test do
      policy action(:process) do
        authorize_if AshOban.Checks.AshObanInteraction
      end
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :source, :atom, allow_nil?: false, constraints: [one_of: [:webhook, :read]]
    attribute :digest, :binary, allow_nil?: false, sensitive?: true
    attribute :dispute_id, :string, allow_nil?: false, sensitive?: true
    attribute :amount_minor, :integer, allow_nil?: false
    attribute :revision, :integer, allow_nil?: false

    attribute :outcome, :atom,
      allow_nil?: false,
      constraints: [
        one_of: [:contested, :awaiting_feedback, :under_review, :unresolved, :restored, :lost]
      ]

    attribute :state, :atom,
      allow_nil?: false,
      default: :pending,
      constraints: [one_of: [:pending, :applied, :stale, :conflict, :quarantined]]

    attribute :read_token, :uuid
    create_timestamp :received_at
  end

  relationships do
    belongs_to :payment, NewYou.Commerce.VerifiedPayment,
      allow_nil?: false,
      attribute_writable?: true
  end

  identities do
    identity :evidence, [:source, :read_token, :digest], nils_distinct?: false
  end
end
