defmodule NewYou.Communications.MessageIntent do
  @moduledoc """
  The Communications-owned durable obligation for an Identity proof delivery.
  Destination is sensitive and fixed at issuance; it is not current Identity truth.
  """
  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Communications,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine, AshOban]

  postgres do
    table "message_intents"
    repo NewYou.Repo

    check_constraints do
      check_constraint :locale, "message_intents_locale",
        check: "locale IN ('en', 'af')",
        message: "is unsupported"

      check_constraint :dispatch_disposition, "message_intents_disposition",
        check: "dispatch_disposition IN ('open', 'held', 'reconciliation_required', 'closed')",
        message: "is unsupported"

      check_constraint :role, "message_intents_role",
        check:
          "role IN ('account_verification', 'magic_login', 'password_reset', 'account_recovery', 'recovery_security_notice')",
        message: "is unsupported"

      check_constraint :source_purpose, "message_intents_role_purpose_schema",
        check:
          "(role = 'account_verification' AND source_purpose = 'email_verification' AND render_schema = 'verification-v1') OR (role = 'magic_login' AND source_purpose = 'magic_login' AND render_schema = 'magic-login-v1') OR (role = 'password_reset' AND source_purpose = 'password_reset' AND render_schema = 'password-reset-v1') OR (role = 'account_recovery' AND source_purpose = 'recovery' AND render_schema = 'recovery-v1') OR (role = 'recovery_security_notice' AND source_purpose = 'recovery_completed' AND render_schema = 'recovery-notice-v1')",
        message: "does not match the message role"

      check_constraint :source_reference, "message_intents_source_reference",
        check: "source_reference ~ '^[0-9a-v]{24}$'",
        message: "is invalid"

      check_constraint :content_item_id, "message_intents_content_binding",
        check:
          "((role IN ('account_recovery', 'recovery_security_notice') AND content_item_id IS NULL AND content_version_id IS NULL AND translation_version_id IS NULL AND content_sha256 IS NULL AND platform_name IS NULL AND render_digest IS NULL) OR (role NOT IN ('account_recovery', 'recovery_security_notice') AND content_item_id IS NOT NULL AND content_version_id IS NOT NULL AND translation_version_id IS NOT NULL AND content_sha256 IS NOT NULL AND platform_name IS NOT NULL AND render_digest IS NOT NULL))",
        message: "must be fully bound or recovery content must remain unbound"
    end
  end

  state_machine do
    initial_states [:open]
    default_initial_state :open
    state_attribute :dispatch_disposition

    transitions do
      transition :hold, from: [:open, :held, :reconciliation_required], to: :held
      transition :resume, from: [:open, :held, :reconciliation_required], to: :open

      transition :require_reconciliation,
        from: [:open, :held, :reconciliation_required],
        to: :reconciliation_required

      transition :close, from: [:open, :held, :reconciliation_required, :closed], to: :closed
      # Only a delivery-observed closure may freeze for contradictory evidence.
      # Source-invalid and other terminal closures cannot regain dispatch.
      transition :flag_evidence_conflict,
        from: [:open, :held, :reconciliation_required, :closed],
        to: :reconciliation_required
    end
  end

  oban do
    triggers do
      trigger :delivery do
        action :execute_delivery
        where expr(dispatch_disposition != :closed)
        scheduler_cron "* * * * *"
        queue :communications
        lock_for_update? false
        log_errors? false
        log_final_error? false
        max_attempts 5
        worker_module_name NewYou.Communications.Workers.Delivery
        scheduler_module_name NewYou.Communications.Schedulers.Delivery
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

    action :execute_delivery, :atom do
      description "Revalidate, durably admit and execute outside any provider-spanning transaction."
      argument :primary_key, :map, allow_nil?: false
      public? false
      transaction? false
      run NewYou.Communications.Actions.ExecuteDelivery
    end

    update :hold do
      accept [:terminal_reason]
      public? false
      change transition_state(:held)
    end

    update :resume do
      accept [:terminal_reason]
      public? false
      change transition_state(:open)
    end

    update :require_reconciliation do
      accept [:terminal_reason]
      public? false
      change transition_state(:reconciliation_required)
    end

    update :close do
      accept [:terminal_reason]
      public? false
      change transition_state(:closed)
    end

    update :flag_evidence_conflict do
      description "Freeze live or delivery-observed dispatch for this intent's conflicting attempt."
      accept []
      argument :attempt_id, :uuid, allow_nil?: false
      public? false

      change filter(
               expr(
                 (dispatch_disposition != :closed or terminal_reason == "delivery_observed") and
                   exists(delivery_attempts, id == ^arg(:attempt_id) and conflict?)
               )
             )

      change set_attribute(:terminal_reason, "conflicting_provider_evidence")
      change transition_state(:reconciliation_required)
    end

    create :establish do
      public? false

      accept [
        :id,
        :source_operation_id,
        :source_reference,
        :destination,
        :destination_provenance,
        :destination_authorized_at,
        :locale,
        :content_item_id,
        :content_version_id,
        :translation_version_id,
        :content_sha256,
        :platform_name,
        :render_digest,
        :role,
        :source_purpose,
        :render_schema
      ]
    end

    create :establish_recovery do
      public? false

      accept [
        :source_operation_id,
        :source_reference,
        :destination,
        :destination_provenance,
        :destination_authorized_at,
        :locale
      ]

      change set_attribute(:role, :account_recovery)
      change set_attribute(:source_purpose, "recovery")
      change set_attribute(:render_schema, "recovery-v1")
      change set_attribute(:dispatch_disposition, :held)
      change set_attribute(:terminal_reason, "content_ineligible")
    end

    create :establish_recovery_notice do
      public? false

      accept [
        :source_operation_id,
        :source_reference,
        :destination,
        :destination_provenance,
        :destination_authorized_at,
        :locale
      ]

      change set_attribute(:role, :recovery_security_notice)
      change set_attribute(:source_purpose, "recovery_completed")
      change set_attribute(:render_schema, "recovery-notice-v1")
      change set_attribute(:dispatch_disposition, :held)
      change set_attribute(:terminal_reason, "content_ineligible")
    end
  end

  policies do
    policy action([:read, :execute_delivery]) do
      authorize_if AshOban.Checks.AshObanInteraction
    end

    policy action([
             :establish,
             :establish_recovery,
             :establish_recovery_notice,
             :hold,
             :resume,
             :require_reconciliation,
             :close,
             :flag_evidence_conflict
           ]) do
      forbid_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id, writable?: true
    attribute :source_owner, :string, allow_nil?: false, default: "identity", public?: false
    attribute :source_operation_id, :uuid, allow_nil?: false, public?: false

    attribute :source_reference, :string,
      allow_nil?: false,
      sensitive?: true,
      constraints: [match: ~r/\A[0-9a-v]{24}\z/],
      public?: false

    attribute :role, :atom,
      allow_nil?: false,
      default: :account_verification,
      constraints: [
        one_of: [
          :account_verification,
          :magic_login,
          :password_reset,
          :account_recovery,
          :recovery_security_notice
        ]
      ],
      public?: false

    attribute :source_purpose, :string,
      allow_nil?: false,
      default: "email_verification",
      public?: false

    attribute :destination, :string, allow_nil?: false, sensitive?: true, public?: false

    attribute :destination_provenance, :string,
      allow_nil?: false,
      sensitive?: true,
      public?: false

    attribute :destination_authorized_at, AshPostgres.TimestamptzUsec,
      allow_nil?: false,
      public?: false

    attribute :locale, :string, allow_nil?: false, public?: false
    attribute :content_item_id, :string, allow_nil?: true, public?: false
    attribute :content_version_id, :string, allow_nil?: true, public?: false
    attribute :translation_version_id, :string, allow_nil?: true, public?: false
    attribute :content_sha256, :string, allow_nil?: true, public?: false
    attribute :platform_name, :string, allow_nil?: true, public?: false

    attribute :render_schema, :string,
      allow_nil?: false,
      default: "verification-v1",
      public?: false

    attribute :render_provenance, :string,
      allow_nil?: false,
      default: "application_platform_name",
      public?: false

    attribute :render_digest, :string, allow_nil?: true, public?: false

    attribute :dispatch_disposition, :atom,
      allow_nil?: false,
      default: :open,
      constraints: [one_of: [:open, :held, :reconciliation_required, :closed]],
      public?: false

    attribute :terminal_reason, :string, public?: false
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :delivery_attempts, NewYou.Communications.DeliveryAttempt do
      public? false
      destination_attribute :message_intent_id
    end
  end

  identities do
    identity :causal_obligation, [:source_owner, :source_reference, :role]
  end
end
