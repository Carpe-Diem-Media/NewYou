defmodule NewYou.Identity.RegistrationOperation do
  use Ash.Resource, otp_app: :new_you, domain: NewYou.Identity, data_layer: AshPostgres.DataLayer

  postgres do
    table "registration_operations"
    repo NewYou.Repo

    custom_indexes do
      index [:expires_at],
        name: "registration_operations_expiry_index",
        where: "state = 'bound'"
    end

    check_constraints do
      check_constraint :state, "registration_operations_state",
        check: "state IN ('bound', 'tombstoned')",
        message: "must be a supported registration operation state"

      check_constraint :outcome, "registration_operations_outcome",
        check: "outcome IS NULL OR outcome = 'verification_pending'",
        message: "must be a supported terminal outcome"

      check_constraint :request_fingerprint, "registration_operations_binding_complete",
        check:
          "(state = 'tombstoned' AND request_fingerprint IS NULL AND fingerprint_key_version IS NULL AND password_verifier IS NULL AND verifier_provider IS NULL AND verifier_version IS NULL AND outcome IS NULL AND committed_at IS NULL AND expires_at IS NULL AND created_account_id IS NULL) OR (state = 'bound' AND request_fingerprint IS NOT NULL AND octet_length(request_fingerprint) = 32 AND fingerprint_key_version IS NOT NULL AND password_verifier IS NOT NULL AND verifier_provider IS NOT NULL AND verifier_version IS NOT NULL AND outcome IS NOT NULL AND outcome = 'verification_pending' AND committed_at IS NOT NULL AND expires_at IS NOT NULL AND expires_at > committed_at)",
        message: "must have a complete live binding or cleared tombstone"

      check_constraint :state, "registration_operations_tombstone_cleared",
        check:
          "state <> 'tombstoned' OR (request_fingerprint IS NULL AND fingerprint_key_version IS NULL AND password_verifier IS NULL AND verifier_provider IS NULL AND verifier_version IS NULL AND outcome IS NULL AND committed_at IS NULL AND expires_at IS NULL AND created_account_id IS NULL)",
        message: "tombstoned operations cannot retain registration bindings"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    action :accept_registration, :map do
      argument :registration_input, :map, allow_nil?: false, sensitive?: true
      argument :pmr, :string, allow_nil?: false, sensitive?: true
      public? false
      transaction? true

      touches_resources [
        NewYou.Identity.Account,
        NewYou.Identity.Token,
        NewYou.Audit.EvidenceObligation,
        NewYou.Communications.MessageIntent,
        NewYou.Communications.ProtectedEnvelope,
        NewYou.Communications.EnvelopeNonce
      ]

      run NewYou.Identity.Actions.AcceptRegistration
    end

    create :bind do
      accept [
        :operation_id,
        :request_fingerprint,
        :fingerprint_key_version,
        :password_verifier,
        :verifier_provider,
        :verifier_version,
        :outcome,
        :committed_at,
        :expires_at,
        :created_account_id
      ]

      public? false
    end

    update :tombstone do
      accept []
      public? false
      require_atomic? false
      change NewYou.Identity.Changes.TombstoneRegistrationOperation
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :operation_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :request_fingerprint, :binary do
      sensitive? true
      public? false
    end

    attribute :fingerprint_key_version, :string do
      sensitive? true
      public? false
    end

    attribute :password_verifier, :string do
      sensitive? true
      public? false
    end

    attribute :verifier_provider, :string do
      sensitive? true
      public? false
    end

    attribute :verifier_version, :string do
      sensitive? true
      public? false
    end

    attribute :outcome, :atom do
      allow_nil? true
      constraints one_of: [:verification_pending]
      public? false
    end

    attribute :state, :atom do
      allow_nil? false
      default :bound
      constraints one_of: [:bound, :tombstoned]
      public? false
    end

    attribute :committed_at, AshPostgres.TimestamptzUsec do
      allow_nil? true
      public? false
    end

    attribute :expires_at, AshPostgres.TimestamptzUsec do
      allow_nil? true
      public? false
    end
  end

  relationships do
    belongs_to :created_account, NewYou.Identity.Account do
      allow_nil? true
      public? false
    end
  end

  identities do
    identity :opaque_operation_id, [:operation_id], message: "has already been used"
  end
end
