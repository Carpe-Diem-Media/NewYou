defmodule NewYou.Identity.Session do
  @moduledoc "Identity-owned durable authentication session."

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Identity,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "sessions"
    repo NewYou.Repo

    references do
      # Token cleanup must retain Session history and its original identifier.
      reference :token, ignore?: true
    end

    check_constraints do
      check_constraint :state, "sessions_state",
        check: "state IN ('active', 'expired', 'revoked', 'logged_out')"

      check_constraint :authentication_method, "sessions_authentication_provenance",
        check:
          "(authentication_method = 'password' AND authentication_proof_jti IS NULL) OR (authentication_method = 'magic_login' AND authentication_proof_jti IS NOT NULL)"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :issue do
      public? false

      accept [
        :account_id,
        :token_jti,
        :expires_at,
        :idle_expires_at,
        :last_seen_at,
        :authentication_method,
        :authentication_proof_jti
      ]
    end

    update :revoke do
      public? false
      accept []
      change filter(expr(state == :active))
      change set_attribute(:state, :revoked)
      change set_attribute(:ended_at, &DateTime.utc_now/0)
      change set_attribute(:step_up_purpose, nil)
      change set_attribute(:step_up_at, nil)
      change set_attribute(:step_up_expires_at, nil)
      change set_attribute(:step_up_mfa_version, nil)
      change set_attribute(:step_up_security_version, nil)
    end

    update :logout do
      public? false
      accept []
      change filter(expr(state == :active))
      change set_attribute(:state, :logged_out)
      change set_attribute(:ended_at, &DateTime.utc_now/0)
      change set_attribute(:step_up_purpose, nil)
      change set_attribute(:step_up_at, nil)
      change set_attribute(:step_up_expires_at, nil)
      change set_attribute(:step_up_mfa_version, nil)
      change set_attribute(:step_up_security_version, nil)
    end

    update :expire do
      public? false
      accept []
      change filter(expr(state == :active and (expires_at <= now() or idle_expires_at <= now())))
      change set_attribute(:state, :expired)
      change set_attribute(:ended_at, &DateTime.utc_now/0)
      change set_attribute(:step_up_purpose, nil)
      change set_attribute(:step_up_at, nil)
      change set_attribute(:step_up_expires_at, nil)
      change set_attribute(:step_up_mfa_version, nil)
      change set_attribute(:step_up_security_version, nil)
    end

    update :touch do
      public? false
      accept [:last_seen_at, :idle_expires_at]
      change filter(expr(state == :active and expires_at > now() and idle_expires_at > now()))
    end

    update :set_step_up do
      public? false

      accept [
        :step_up_purpose,
        :step_up_at,
        :step_up_expires_at,
        :step_up_mfa_version,
        :step_up_security_version
      ]
    end

    update :clear_step_up do
      description "Clear elevated assurance atomically with a current Identity security change."
      public? false
      accept []
      change set_attribute(:step_up_purpose, nil)
      change set_attribute(:step_up_at, nil)
      change set_attribute(:step_up_expires_at, nil)
      change set_attribute(:step_up_mfa_version, nil)
      change set_attribute(:step_up_security_version, nil)
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    create_timestamp :created_at

    attribute :authentication_method, :atom,
      allow_nil?: false,
      default: :password,
      constraints: [one_of: [:password, :magic_login]],
      public?: false

    attribute :authentication_proof_jti, :string, sensitive?: true, public?: false

    attribute :ended_at, :utc_datetime do
      public? false
    end

    attribute :token_jti, :string do
      allow_nil? false
      sensitive? true
      public? false
    end

    attribute :state, :atom do
      allow_nil? false
      default :active
      constraints one_of: [:active, :expired, :revoked, :logged_out]
      public? false
    end

    attribute :expires_at, :utc_datetime do
      allow_nil? false
      public? false
    end

    attribute :idle_expires_at, :utc_datetime do
      allow_nil? false
      public? false
    end

    attribute :step_up_purpose, :atom do
      constraints one_of: [
                    :place_security_hold,
                    :review_security_hold,
                    :release_security_hold,
                    :review_reconciliation,
                    :apply_reconciliation,
                    :change_primary_email,
                    :approve_manual_recovery,
                    :complete_manual_recovery,
                    :lookup_identity
                  ]

      public? false
    end

    attribute :step_up_at, :utc_datetime_usec, public?: false
    attribute :step_up_expires_at, :utc_datetime_usec, public?: false
    attribute :step_up_mfa_version, :integer, public?: false
    attribute :step_up_security_version, :integer, public?: false

    attribute :last_seen_at, :utc_datetime do
      allow_nil? false
      public? false
    end
  end

  relationships do
    belongs_to :account, NewYou.Identity.Account do
      allow_nil? false
      attribute_writable? true
      public? false
    end

    belongs_to :token, NewYou.Identity.Token do
      source_attribute :token_jti
      destination_attribute :jti
      define_attribute? false
      allow_nil? false
      attribute_writable? true
      public? false
    end
  end

  identities do
    identity :one_session_per_token, [:token_jti]
    identity :one_session_per_magic_proof, [:authentication_proof_jti]
  end
end
