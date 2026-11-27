defmodule NewYou.Commerce.FixtureRefund do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshOban]

  postgres do
    table "commerce_fixture_refunds"
    repo NewYou.Repo

    references do
      reference :payment, on_delete: :restrict
      reference :purchase, on_delete: :restrict
      reference :quote, on_delete: :restrict
    end

    check_constraints do
      check_constraint [:reference, :fingerprint, :transaction_id, :amount_minor, :currency],
                       "fixture_refund_immutable_request",
                       check: """
                       reference ~ '^[0-9a-f]{32}$' AND octet_length(fingerprint) = 32 AND
                       transaction_id ~ '^[1-9][0-9]{0,19}$' AND
                       amount_minor > 0 AND currency = 'ZAR' AND
                       allocation IN ('plan', 'assessment', 'excess')
                       """

      check_constraint [:state, :claim_id, :verify_after, :verify_round],
                       "fixture_refund_dispatch_fence",
                       check: """
                       verify_round BETWEEN 0 AND 6 AND
                       ((state IN ('owed', 'reserved') AND claim_id IS NULL AND
                         verify_after IS NULL AND verify_round = 0) OR
                        (state IN ('unresolved', 'pending', 'processing', 'needs_attention',
                          'failed', 'insufficient_balance', 'processed') AND claim_id IS NOT NULL)) AND
                       ((state = 'processed' AND processed_at IS NOT NULL AND
                         processed_receipt_id IS NOT NULL AND verify_after IS NULL) OR
                        (state <> 'processed' AND processed_at IS NULL AND processed_receipt_id IS NULL)) AND
                       (state IN ('owed', 'reserved', 'unresolved') OR provider_refund_id IS NOT NULL) AND
                       (acknowledged_at IS NULL OR (state = 'processed' AND allocation <> 'excess'))
                       """
    end

    custom_indexes do
      index [:verify_after], where: "verify_after IS NOT NULL", name: "fixture_refund_read_due"

      index [:id],
        where: "state = 'processed' AND allocation <> 'excess' AND acknowledged_at IS NULL",
        name: "fixture_refund_open_consequence"
    end
  end

  if Mix.env() == :test do
    oban do
      triggers do
        trigger :read_due do
          action :read_due

          where expr(
                  state != :processed and
                    (verify_after <= now() or (is_nil(verify_after) and verify_round == 6))
                )

          scheduler_cron "* * * * *"
          queue :commerce_fixture_refund
          log_errors? false
          log_final_error? false
          worker_module_name NewYou.Commerce.Workers.ReadFixtureRefund
          scheduler_module_name NewYou.Commerce.Schedulers.ReadFixtureRefund
        end

        trigger :deliver do
          action :deliver
          where expr(state == :processed and allocation != :excess and is_nil(acknowledged_at))
          scheduler_cron "* * * * *"
          queue :commerce_fixture_refund
          log_errors? false
          log_final_error? false
          worker_module_name NewYou.Commerce.Workers.DeliverFixtureRefund
          scheduler_module_name NewYou.Commerce.Schedulers.DeliverFixtureRefund
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
      create :establish do
        public? false

        accept [
          :purchase_id,
          :quote_id,
          :payment_id,
          :payer_id,
          :transaction_id,
          :reference,
          :fingerprint,
          :amount_minor,
          :currency,
          :allocation
        ]
      end

      update :reserve do
        public? false
        accept []
        change filter(expr(state == :owed))
        change set_attribute(:state, :reserved)
      end

      update :claim do
        public? false
        accept [:claim_id, :verify_after]
        change filter(expr(state == :reserved and is_nil(claim_id)))
        change set_attribute(:state, :unresolved)
        validate present([:claim_id, :verify_after])
      end

      update :record_progress do
        public? false
        accept [:state, :provider_refund_id]
        change filter(expr(not is_nil(claim_id) and state != :processed))
      end

      update :satisfy do
        public? false
        accept [:provider_refund_id, :processed_receipt_id, :processed_at]
        change filter(expr(not is_nil(claim_id) and state != :processed))
        change set_attribute(:state, :processed)
        change set_attribute(:verify_after, nil)
        validate present([:provider_refund_id, :processed_receipt_id, :processed_at])
      end

      update :defer_read do
        public? false
        accept [:verify_after, :verify_round]

        change filter(
                 expr(state != :processed and (not is_nil(verify_after) or verify_round == 6))
               )
      end

      update :respect_retry_after do
        public? false
        accept []
        argument :retry_at, AshPostgres.TimestamptzUsec, allow_nil?: false
        change filter(expr(verify_after < ^arg(:retry_at)))
        change set_attribute(:verify_after, arg(:retry_at))
      end

      update :acknowledge do
        public? false
        accept [:acknowledged_at]

        change filter(
                 expr(state == :processed and allocation != :excess and is_nil(acknowledged_at))
               )

        validate present(:acknowledged_at)
      end

      action :read_due do
        public? false
        argument :primary_key, :map, allow_nil?: false
        run {NewYou.Commerce.FixtureRefundWork, operation: :read_due}
      end

      action :deliver do
        public? false
        argument :primary_key, :map, allow_nil?: false
        run {NewYou.Commerce.FixtureRefundWork, operation: :deliver}
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if AshOban.Checks.AshObanInteraction
    end

    if Mix.env() == :test do
      policy action([:read_due, :deliver]) do
        authorize_if AshOban.Checks.AshObanInteraction
      end
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :payer_id, :uuid, allow_nil?: false
    attribute :transaction_id, :string, allow_nil?: false, sensitive?: true
    attribute :reference, :string, allow_nil?: false, sensitive?: true
    attribute :fingerprint, :binary, allow_nil?: false, sensitive?: true
    attribute :amount_minor, :integer, allow_nil?: false, constraints: [min: 1]
    attribute :currency, :string, allow_nil?: false, constraints: [match: ~r/\AZAR\z/]

    attribute :allocation, :atom,
      allow_nil?: false,
      constraints: [one_of: [:plan, :assessment, :excess]]

    attribute :state, :atom, allow_nil?: false, default: :owed
    attribute :claim_id, :uuid
    attribute :verify_after, AshPostgres.TimestamptzUsec
    attribute :verify_round, :integer, default: 0, allow_nil?: false
    attribute :provider_refund_id, :string, sensitive?: true
    attribute :processed_at, AshPostgres.TimestamptzUsec
    attribute :acknowledged_at, AshPostgres.TimestamptzUsec
    create_timestamp :established_at
  end

  relationships do
    belongs_to :payment, NewYou.Commerce.VerifiedPayment do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :purchase, NewYou.Commerce.Purchase do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :quote, NewYou.Commerce.PurchaseQuote do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :processed_receipt, NewYou.Commerce.FixtureRefundReceipt do
      attribute_writable? true
    end
  end

  identities do
    identity :allocation, [:payment_id, :allocation]
    identity :reference, [:reference]
    identity :provider_refund, [:provider_refund_id]
  end
end
