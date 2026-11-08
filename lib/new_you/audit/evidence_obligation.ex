defmodule NewYou.Audit.EvidenceObligation do
  @moduledoc """
  Durable selected Audit E2 work, independent of executor jobs. PostgreSQL preserves the
  source provenance and terminal fulfilment. The AshOban scheduler rediscovers
  open obligations every minute, including those with missing or exhausted jobs.
  """
  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Audit,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "evidence_obligations"
    repo NewYou.Repo

    check_constraints do
      check_constraint :evidence_type, "evidence_obligations_evidence_type",
        check:
          "evidence_type IN ('account_registration_pmr_assignment', 'security_hold_placement', 'security_hold_review', 'security_hold_release_result', 'identity_mfa_confirmed', 'identity_grant_revoked')",
        message: "must be a selected evidence type"

      check_constraint :evidence_type, "evidence_obligations_security_shape",
        check:
          "evidence_type = 'account_registration_pmr_assignment' OR (actor_id IS NOT NULL AND target_id IS NOT NULL AND outcome IS NOT NULL AND outcome IN ('succeeded', 'denied', 'failed') AND (evidence_type <> 'security_hold_release_result' OR admission_id IS NOT NULL))"

      check_constraint :state, "evidence_obligations_state",
        check: "state IN ('open', 'fulfilled')",
        message: "must be open or fulfilled"

      check_constraint :fulfilled_at, "evidence_obligations_fulfilment_timestamp",
        check:
          "(state = 'open' AND fulfilled_at IS NULL) OR (state = 'fulfilled' AND fulfilled_at IS NOT NULL)",
        message: "must match the obligation lifecycle state"
    end
  end

  oban do
    triggers do
      trigger :registration_evidence do
        action :materialize_registration_evidence
        where expr(state == :open)
        scheduler_cron "* * * * *"
        queue :audit
        max_attempts 10
        worker_module_name NewYou.Audit.Workers.RegistrationEvidence
        scheduler_module_name NewYou.Audit.Schedulers.RegistrationEvidence
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

    create :establish_registration do
      accept [:source_operation_id, :source_occurred_at]
      public? false

      change set_attribute(:evidence_type, :account_registration_pmr_assignment)
      change set_attribute(:state, :open)
      change NewYou.Audit.Changes.ScheduleRegistrationEvidence
    end

    create :establish_identity_security do
      description "Source-transaction E2 obligation for selected security transitions and linked E1 results."
      public? false

      accept [
        :source_operation_id,
        :source_occurred_at,
        :evidence_type,
        :actor_id,
        :target_id,
        :grant_id,
        :session_id,
        :reason_code,
        :admission_id,
        :outcome
      ]

      change set_attribute(:state, :open)
      change NewYou.Audit.Changes.ScheduleRegistrationEvidence
    end

    update :fulfill do
      accept []
      public? false
      require_atomic? false
      change NewYou.Audit.Changes.FulfillEvidenceObligation
    end

    action :materialize_registration_evidence, :map do
      argument :primary_key, :map, allow_nil?: false, sensitive?: false
      public? false
      transaction? true
      touches_resources [NewYou.Audit.EvidenceRecord]
      run NewYou.Audit.Actions.MaterializeRegistrationEvidence
    end
  end

  policies do
    policy action([:read, :materialize_registration_evidence]) do
      authorize_if AshOban.Checks.AshObanInteraction
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :evidence_type, :atom do
      allow_nil? false

      constraints one_of: [
                    :account_registration_pmr_assignment,
                    :security_hold_placement,
                    :security_hold_review,
                    :security_hold_release_result,
                    :identity_mfa_confirmed,
                    :identity_grant_revoked
                  ]

      public? false
    end

    attribute :source_operation_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :source_occurred_at, AshPostgres.TimestamptzUsec do
      allow_nil? false
      public? false
    end

    attribute :state, :atom do
      allow_nil? false
      default :open
      constraints one_of: [:open, :fulfilled]
      public? false
    end

    attribute :fulfilled_at, AshPostgres.TimestamptzUsec do
      allow_nil? true
      public? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at

    attribute :actor_id, :uuid, public?: false
    attribute :target_id, :uuid, public?: false
    attribute :grant_id, :uuid, public?: false
    attribute :session_id, :uuid, public?: false

    attribute :reason_code, :atom,
      constraints: [
        one_of: [:suspected_compromise, :security_review, :verified_recovery, :mistaken_hold]
      ],
      public?: false

    attribute :outcome, :atom,
      constraints: [one_of: [:succeeded, :denied, :failed]],
      public?: false
  end

  relationships do
    belongs_to :admission, NewYou.Audit.EvidenceRecord do
      allow_nil? true
      attribute_writable? true
      public? false
    end
  end

  identities do
    identity :registration_source_operation, [:source_operation_id],
      message: "already has a registration evidence obligation"
  end
end
