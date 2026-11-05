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

    check_constraints do
      check_constraint :state, "sessions_state",
        check: "state IN ('active', 'expired', 'revoked', 'logged_out')"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :issue do
      public? false
      accept [:account_id, :token_jti, :expires_at, :idle_expires_at, :last_seen_at]
    end

    update :revoke do
      public? false
      accept []
      change filter(expr(state == :active))
      change set_attribute(:state, :revoked)
      change set_attribute(:ended_at, &DateTime.utc_now/0)
    end

    update :logout do
      public? false
      accept []
      change filter(expr(state == :active))
      change set_attribute(:state, :logged_out)
      change set_attribute(:ended_at, &DateTime.utc_now/0)
    end

    update :expire do
      public? false
      accept []
      change filter(expr(state == :active and (expires_at <= now() or idle_expires_at <= now())))
      change set_attribute(:state, :expired)
      change set_attribute(:ended_at, &DateTime.utc_now/0)
    end

    update :touch do
      public? false
      accept [:last_seen_at, :idle_expires_at]
      change filter(expr(state == :active and expires_at > now() and idle_expires_at > now()))
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
  end
end
