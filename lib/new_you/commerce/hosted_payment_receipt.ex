defmodule NewYou.Commerce.HostedPaymentReceipt do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_hosted_payment_receipts"
    repo NewYou.Repo

    check_constraints do
      check_constraint [:provider, :integration, :environment], "hosted_payment_receipt_scope",
        check: "provider = 'paystack' AND integration = 'local_fixture' AND environment = 'test'"

      check_constraint [:digest, :source, :state, :requested_reference],
                       "hosted_payment_receipt_shape",
                       check: """
                       octet_length(digest) = 32 AND state IN ('pending', 'qualified', 'unresolved', 'quarantined') AND
                       ((source = 'webhook' AND requested_reference IS NULL) OR
                        (source = 'verify' AND requested_reference IS NOT NULL))
                       """
    end

    custom_indexes do
      index [:id], where: "state = 'pending'", name: "hosted_payment_receipt_pending"
    end
  end

  if Mix.env() == :test do
    oban do
      triggers do
        trigger :process_fixture_receipt do
          action :process_fixture_receipt
          where expr(state == :pending)
          scheduler_cron "* * * * *"
          queue :commerce_fixture
          log_errors? false
          log_final_error? false
          worker_module_name NewYou.Commerce.Workers.ProcessFixtureReceipt
          scheduler_module_name NewYou.Commerce.Schedulers.ProcessFixtureReceipt
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

    create :receive_evidence do
      public? false

      accept [
        :source,
        :digest,
        :requested_reference,
        :reference,
        :transaction_id,
        :amount_minor,
        :currency,
        :outcome
      ]

      upsert? true
      upsert_identity :source_evidence
      upsert_fields []
      upsert_condition expr(false)
      return_skipped_upsert? true
    end

    update :classify do
      public? false
      accept [:state, :classification]
      change filter(expr(state == :pending))
    end

    action :process_fixture_receipt do
      public? false
      argument :primary_key, :map, allow_nil?: false
      run NewYou.Commerce.ProcessFixtureReceipt
    end
  end

  policies do
    policy action([:read, :process_fixture_receipt]) do
      authorize_if AshOban.Checks.AshObanInteraction
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :provider, :atom, allow_nil?: false, default: :paystack
    attribute :integration, :atom, allow_nil?: false, default: :local_fixture
    attribute :environment, :atom, allow_nil?: false, default: :test
    attribute :source, :atom, allow_nil?: false, constraints: [one_of: [:webhook, :verify]]
    attribute :digest, :binary, allow_nil?: false, sensitive?: true
    attribute :requested_reference, :string, sensitive?: true
    attribute :reference, :string, sensitive?: true
    attribute :transaction_id, :string, sensitive?: true
    attribute :amount_minor, :integer
    attribute :currency, :string
    attribute :outcome, :atom, allow_nil?: false
    attribute :classification, :atom
    attribute :state, :atom, allow_nil?: false, default: :pending
    create_timestamp :received_at
  end

  identities do
    identity :source_evidence,
             [:provider, :integration, :environment, :source, :requested_reference, :digest],
             nils_distinct?: false
  end
end
