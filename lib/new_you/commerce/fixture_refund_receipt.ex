defmodule NewYou.Commerce.FixtureRefundReceipt do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshOban]

  postgres do
    table "commerce_fixture_refund_receipts"
    repo NewYou.Repo

    check_constraints do
      check_constraint [:digest, :source, :requested_reference, :state],
                       "fixture_refund_receipt_shape",
                       check: """
                       octet_length(digest) = 32 AND
                       ((source = 'webhook' AND requested_reference IS NULL) OR
                        (source = 'read' AND requested_reference IS NOT NULL)) AND
                       state IN ('pending', 'applied', 'stale', 'quarantined', 'unresolved')
                       """
    end

    custom_indexes do
      index [:id], where: "state = 'pending'", name: "fixture_refund_receipts_pending"
      index [:reference]
      index [:requested_reference]
    end
  end

  if Mix.env() == :test do
    oban do
      triggers do
        trigger :process do
          action :process
          where expr(state == :pending)
          scheduler_cron "* * * * *"
          queue :commerce_fixture_refund
          log_errors? false
          log_final_error? false
          worker_module_name NewYou.Commerce.Workers.ProcessFixtureRefundReceipt
          scheduler_module_name NewYou.Commerce.Schedulers.ProcessFixtureRefundReceipt
        end
      end
    end
  end

  actions do
    read :read do
      primary? true
      public? false

      pagination do
        keyset? true
        required? false
      end
    end

    if Mix.env() == :test do
      create :receive do
        public? false

        accept [
          :source,
          :digest,
          :requested_reference,
          :reference,
          :transaction_id,
          :provider_refund_id,
          :amount_minor,
          :currency,
          :outcome
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
        run {NewYou.Commerce.FixtureRefundWork, operation: :process_receipt}
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
    attribute :source, :atom, allow_nil?: false
    attribute :digest, :binary, allow_nil?: false, sensitive?: true
    attribute :requested_reference, :string, sensitive?: true
    attribute :reference, :string, sensitive?: true
    attribute :transaction_id, :string, sensitive?: true
    attribute :provider_refund_id, :string, sensitive?: true
    attribute :amount_minor, :integer
    attribute :currency, :string
    attribute :outcome, :atom, allow_nil?: false
    attribute :state, :atom, allow_nil?: false, default: :pending
    create_timestamp :received_at
  end

  identities do
    identity :evidence, [:source, :requested_reference, :digest], nils_distinct?: false
  end
end
