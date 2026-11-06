defmodule NewYou.Audit.EvidenceObligation do
  @moduledoc """
  Durable Audit E2 work, independent of executor jobs. PostgreSQL preserves the
  source provenance and terminal fulfilment. The AshOban scheduler rediscovers
  open obligations every minute, including those with missing or exhausted jobs.
  """
  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Audit,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban]

  postgres do
    table "evidence_obligations"
    repo NewYou.Repo

    check_constraints do
      check_constraint :evidence_type, "evidence_obligations_evidence_type",
        check: "evidence_type = 'account_registration_pmr_assignment'",
        message: "must be a selected registration evidence type"

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

  attributes do
    uuid_v7_primary_key :id

    attribute :evidence_type, :atom do
      allow_nil? false
      constraints one_of: [:account_registration_pmr_assignment]
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
  end

  identities do
    identity :registration_source_operation, [:source_operation_id],
      message: "already has a registration evidence obligation"
  end
end
