defmodule NewYou.Identity.DeviceAssurance do
  @moduledoc """
  Identity-owned consent and terminal trust records. The fingerprint matches
  only an opaque random artifact. Neither the record nor the artifact supplies
  Session, authentication or step-up authority.
  """
  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Identity,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "device_assurances"
    repo NewYou.Repo

    custom_indexes do
      index [:account_id, :id],
        where: "state = 'trusted'",
        name: "device_assurances_trusted_account_page"
    end

    check_constraints do
      check_constraint :state, "device_assurances_state",
        check: "state IN ('pending', 'trusted', 'expired', 'revoked')"

      check_constraint :revoked_at, "device_assurances_revocation",
        check:
          "(state = 'revoked' AND revoked_at IS NOT NULL) OR (state <> 'revoked' AND revoked_at IS NULL)"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :record_consent do
      public? false
      accept [:account_id, :fingerprint, :security_version, :expires_at]
    end

    update :trust do
      public? false
      accept []
      change filter(expr(state == :pending and expires_at > now()))
      change set_attribute(:state, :trusted)
    end

    update :name do
      public? false
      accept [:name]
      change filter(expr(state == :trusted and expires_at > now()))
    end

    update :expire do
      public? false
      accept []
      argument :checked_at, :utc_datetime_usec, allow_nil?: false
      change filter(expr(state == :trusted and expires_at <= ^arg(:checked_at)))
      change set_attribute(:state, :expired)
    end

    update :revoke do
      description "Terminate current device trust inside an Account-locked security transaction. Revocation cannot restore trust."
      public? false
      accept []
      change filter(expr(state == :trusted))
      change set_attribute(:state, :revoked)
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :fingerprint, :binary, allow_nil?: false, sensitive?: true, public?: false

    attribute :name, :string, constraints: [min_length: 1, max_length: 80], public?: false

    attribute :state, :atom,
      allow_nil?: false,
      default: :pending,
      constraints: [one_of: [:pending, :trusted, :expired, :revoked]],
      public?: false

    attribute :security_version, :integer,
      allow_nil?: false,
      constraints: [min: 1],
      public?: false

    attribute :expires_at, :utc_datetime_usec, allow_nil?: false, public?: false
    attribute :revoked_at, :utc_datetime_usec, public?: false
    create_timestamp :created_at
  end

  relationships do
    belongs_to :account, NewYou.Identity.Account do
      allow_nil? false
      public? false
    end
  end

  identities do
    identity :account_artifact, [:account_id, :fingerprint]
  end
end
