defmodule NewYou.Identity.Account do
  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Identity,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

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
    end
  end

  actions do
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

    attribute :pmr, :string do
      allow_nil? false
      public? false
    end
  end

  identities do
    identity :canonical_email, [:email], message: "is unavailable"
    identity :permanent_pmr, [:pmr], message: "is already allocated"
  end
end
