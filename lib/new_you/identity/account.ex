defmodule NewYou.Identity.Account do
  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Identity,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshCloak]

  authentication do
    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        hash_provider AshAuthentication.Argon2Provider
        registration_enabled? false
        sign_in_enabled? false
        sign_in_tokens_enabled? false
        confirmation_required? false
      end
    end

    tokens do
      enabled? true
      token_resource NewYou.Identity.Token
      signing_secret NewYou.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
      token_lifetime {24, :hours}
    end
  end

  postgres do
    table "accounts"
    repo NewYou.Repo

    unique_index_names [
      {[:pmr], "identity_pmr_reservations_pkey", "is already allocated"}
    ]

    check_constraints do
      check_constraint :pmr_status, "accounts_reconciliation_shape",
        check:
          "(pmr_status = 'active' AND canonical_account_id IS NULL) OR (pmr_status = 'retired' AND canonical_account_id IS NOT NULL AND canonical_account_id <> id AND account_status = 'closed_terminal' AND credential_status = 'revoked')"

      check_constraint :account_status, "accounts_account_status",
        check: "account_status IN ('open', 'closed_recoverable', 'closed_terminal')",
        message: "must be a supported Account lifecycle state"

      check_constraint :security_posture, "accounts_security_posture",
        check: "security_posture IN ('normal', 'held')",
        message: "must be a supported security posture"

      check_constraint :email, "accounts_email_length",
        check: "octet_length(email) <= 254",
        message: "must be a canonical mailbox address"

      check_constraint :pmr, "accounts_pmr_format",
        check: "pmr ~ '^PMR-[0-9A-Z]{16}[0-9A-Z*]$'",
        message: "must be a canonical PMR"

      check_constraint :preferred_language, "accounts_preferred_language",
        check: "preferred_language IN ('af', 'en')",
        message: "must be a supported language"

      check_constraint :acceptance_locale, "accounts_acceptance_locale",
        check: "acceptance_locale IN ('af', 'en')",
        message: "must be a supported locale"

      check_constraint :credential_status, "accounts_credential_status",
        check: "credential_status IN ('active', 'replaced', 'revoked')",
        message: "must be a supported credential state"

      check_constraint :confirmed_age_18?, "accounts_adult_confirmation",
        check: "\"confirmed_age_18?\" IS TRUE",
        message: "must confirm age 18 or older"

      check_constraint :mfa_enrollment_state, "accounts_mfa_enrollment_state",
        check: "mfa_enrollment_state IN ('disabled', 'pending', 'active')",
        message: "must be a supported MFA state"

      check_constraint :hold_version, "accounts_hold_version", check: "hold_version >= 0"

      check_constraint :hold_operations, "accounts_hold_operations",
        check: "jsonb_typeof(hold_operations) = 'object'"
    end
  end

  cloak do
    vault(NewYou.Identity.MfaVault)
    attributes([:totp_secret, :pending_totp_secret])
    decrypt_by_default([])
  end

  actions do
    update :hold_for_recovery do
      public? false
      accept []
      change filter(expr(security_posture == :normal))
      change set_attribute(:security_posture, :held)
      change set_attribute(:hold_review, nil)
      change increment(:hold_version)
      change increment(:security_version)
    end

    action :reset_password, :atom do
      description "Explicit proof-bound password replacement with atomic Account-wide security consequences. Never signs in."
      public? false
      argument :proof, :string, allow_nil?: false, sensitive?: true
      argument :password, :string, allow_nil?: false, sensitive?: true
      argument :operation_id, :uuid, allow_nil?: false, sensitive?: true
      run NewYou.Identity.Actions.ResetPassword
    end

    update :replace_password do
      description "Private credential replacement inside the locked reset transaction."
      public? false
      require_atomic? false
      accept []

      argument :password, :string,
        allow_nil?: false,
        sensitive?: true,
        constraints: [min_length: 1, max_length: 1024]

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
      change increment(:credential_version)
      change increment(:security_version)
    end

    action :authenticate_magic_link, :map do
      description "Explicit participant confirmation consumes one current magic-login proof and issues the shared Session atomically."
      public? false
      argument :proof, :string, allow_nil?: false, sensitive?: true
      run NewYou.Identity.Actions.AuthenticateMagicLink
    end

    action :confirm_email, :atom do
      description "Explicit purpose-bound email verification; no Session issuance"
      public? false
      argument :proof, :string, allow_nil?: false, sensitive?: true
      run NewYou.Identity.Actions.ConfirmEmail
    end

    update :mark_email_verified do
      description "Private write inside the locked Identity confirmation transaction"
      public? false
      accept []
      change set_attribute(:email_verified?, true)
    end

    update :retire_reconciled_identity do
      description "Close the non-surviving Account permanently inside the locked reconciliation apply. The PMR bytes remain reserved forever."
      public? false
      accept [:canonical_account_id]

      change filter(
               expr(
                 account_status == :open and pmr_status == :active and
                   is_nil(canonical_account_id)
               )
             )

      change set_attribute(:account_status, :closed_terminal)
      change set_attribute(:pmr_status, :retired)
      change set_attribute(:credential_status, :revoked)
      change increment(:security_version)
      change increment(:reconciliation_version)
    end

    update :advance_reconciliation_version do
      description "Invalidate overlapping case reviews when this Account participates in a committed decision."
      public? false
      accept []
      change increment(:reconciliation_version)
    end

    update :update_privileged_mfa do
      description "Private MFA transition inside a locked Identity transaction"
      public? false

      accept [
        :totp_secret,
        :pending_totp_secret,
        :mfa_enrollment_state,
        :mfa_confirmed_at,
        :mfa_last_accepted_period,
        :mfa_failed_attempts,
        :mfa_locked_until,
        :mfa_version,
        :security_version
      ]
    end

    update :invalidate_grant_assurance do
      description "Advance current security authority when a scoped grant is revoked."
      public? false
      accept []
      change increment(:security_version)
    end

    update :place_security_hold do
      description "Private conditional containment write inside the current privileged Identity transaction."
      public? false
      accept [:hold_version, :security_version, :hold_operations]
      argument :expected_hold_version, :integer, allow_nil?: false

      change filter(
               expr(security_posture == :normal and hold_version == ^arg(:expected_hold_version))
             )

      change set_attribute(:security_posture, :held)
      change set_attribute(:hold_review, nil)
    end

    update :review_security_hold do
      description "Record independent current security review tied to the held generation."
      public? false
      accept [:hold_review, :hold_operations]
      argument :expected_hold_version, :integer, allow_nil?: false

      change filter(
               expr(security_posture == :held and hold_version == ^arg(:expected_hold_version))
             )
    end

    update :release_security_hold do
      description "Private release write after independently committed E1 admission and fresh current authority checks."
      public? false
      accept [:hold_version, :security_version, :hold_operations]
      argument :expected_hold_version, :integer, allow_nil?: false

      change filter(
               expr(security_posture == :held and hold_version == ^arg(:expected_hold_version))
             )

      change set_attribute(:security_posture, :normal)
      change set_attribute(:hold_review, nil)
    end

    update :record_security_hold_attempt do
      description "Persist an admitted failed source attempt and its E2 obligation without changing posture."
      public? false
      accept [:hold_operations]
      argument :expected_hold_version, :integer, allow_nil?: false
      change filter(expr(hold_version == ^arg(:expected_hold_version)))
    end

    read :read do
      primary? true
      public? false
    end

    read :get_by_subject do
      description "Resolve a framework subject inside Identity"
      argument :subject, :string, allow_nil?: false, sensitive?: true
      get? true
      public? false
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    create :register do
      accept [
        :first_name,
        :surname,
        :email,
        :preferred_language,
        :confirmed_age_18?,
        :terms_version_id,
        :privacy_version_id,
        :legal_accepted_at,
        :acceptance_locale,
        :pmr
      ]

      argument :password, :string, allow_nil?: false, sensitive?: true
      public? false

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
      change set_attribute(:credential_status, :active)
      change set_attribute(:email_verified?, false)
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :account_status, :atom do
      description "Current closure eligibility; verification cannot reopen an Account"
      allow_nil? false
      public? false
      default :open
      constraints one_of: [:open, :closed_recoverable, :closed_terminal]
    end

    attribute :security_posture, :atom do
      description "Current containment eligibility; verification cannot release a hold"
      allow_nil? false
      public? false
      default :normal
      constraints one_of: [:normal, :held]
    end

    attribute :hold_version, :integer,
      allow_nil?: false,
      default: 0,
      constraints: [min: 0],
      public?: false

    attribute :hold_review, :map, sensitive?: true, public?: false

    attribute :hold_operations, :map,
      allow_nil?: false,
      default: %{},
      sensitive?: true,
      public?: false

    attribute :first_name, :string do
      allow_nil? false
      public? false
    end

    attribute :surname, :string do
      allow_nil? false
      public? false
    end

    attribute :email, :string do
      allow_nil? false
      sensitive? true
      public? true
    end

    attribute :preferred_language, :atom do
      allow_nil? false
      constraints one_of: [:af, :en]
      public? false
    end

    attribute :confirmed_age_18?, :boolean do
      allow_nil? false
      public? false
    end

    attribute :terms_version_id, :string do
      allow_nil? false
      public? false
    end

    attribute :privacy_version_id, :string do
      allow_nil? false
      public? false
    end

    attribute :legal_accepted_at, AshPostgres.TimestamptzUsec do
      allow_nil? false
      public? false
    end

    attribute :acceptance_locale, :atom do
      allow_nil? false
      constraints one_of: [:af, :en]
      public? false
    end

    attribute :credential_status, :atom do
      allow_nil? false
      constraints one_of: [:active, :replaced, :revoked]
      public? false
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
      public? false
    end

    attribute :email_verified?, :boolean do
      allow_nil? false
      default false
      public? false
    end

    attribute :pmr_status, :atom,
      allow_nil?: false,
      default: :active,
      constraints: [one_of: [:active, :retired]],
      public?: false

    attribute :canonical_account_id, :uuid, public?: false

    attribute :reconciliation_version, :integer,
      allow_nil?: false,
      default: 0,
      constraints: [min: 0],
      public?: false

    attribute :pmr, :string do
      allow_nil? false
      public? false
    end

    attribute :mfa_enrollment_state, :atom do
      allow_nil? false
      default :disabled
      constraints one_of: [:disabled, :pending, :active]
      public? false
    end

    attribute :totp_secret, :binary do
      allow_nil? true
      sensitive? true
      public? false
    end

    attribute :pending_totp_secret, :binary do
      allow_nil? true
      sensitive? true
      public? false
    end

    attribute :mfa_confirmed_at, :utc_datetime_usec, public?: false
    attribute :mfa_last_accepted_period, :integer, public?: false
    attribute :mfa_failed_attempts, :integer, allow_nil?: false, default: 0, public?: false
    attribute :mfa_locked_until, :utc_datetime_usec, public?: false
    attribute :mfa_version, :integer, allow_nil?: false, default: 1, public?: false
    attribute :security_version, :integer, allow_nil?: false, default: 1, public?: false

    attribute :credential_version, :integer,
      allow_nil?: false,
      default: 1,
      constraints: [min: 1],
      public?: false
  end

  identities do
    identity :canonical_email, [:email], message: "is unavailable"
    identity :permanent_pmr, [:pmr], message: "is already allocated"
  end
end
