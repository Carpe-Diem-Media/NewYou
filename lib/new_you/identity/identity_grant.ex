defmodule NewYou.Identity.IdentityGrant do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Identity,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "identity_grants"
    repo NewYou.Repo

    check_constraints do
      check_constraint :role, "identity_grants_role", check: "role = 'support'"

      check_constraint :capability, "identity_grants_capability",
        check:
          "capability IN ('place_security_hold', 'review_security_hold', 'release_security_hold')"

      check_constraint :state, "identity_grants_state", check: "state IN ('active', 'revoked')"

      check_constraint :revoked_at, "identity_grants_revocation_timestamp",
        check:
          "(state = 'active' AND revoked_at IS NULL) OR (state = 'revoked' AND revoked_at IS NOT NULL)"

      check_constraint :subject_account_id, "identity_grants_independent_approval",
        check: "subject_account_id <> approver_account_id"

      check_constraint :expires_at, "identity_grants_bounded_period",
        check: "expires_at > starts_at"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :provision do
      description "Private provisioning action for a named, independently approved Support grant"
      public? false

      accept [
        :subject_account_id,
        :role,
        :capability,
        :target_account_id,
        :approver_account_id,
        :reason_code,
        :starts_at,
        :expires_at
      ]
    end

    update :revoke do
      public? false
      accept []
      change set_attribute(:state, :revoked)
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
      change increment(:version)
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

    attribute :role, :atom do
      allow_nil? false
      constraints one_of: [:support]
      public? false
    end

    attribute :capability, :atom do
      allow_nil? false
      constraints one_of: [:place_security_hold, :review_security_hold, :release_security_hold]
      public? false
    end

    attribute :reason_code, :atom do
      allow_nil? false
      constraints one_of: [:suspected_compromise, :recovery_assistance, :security_review]
      public? false
    end

    attribute :state, :atom do
      allow_nil? false
      default :active
      constraints one_of: [:active, :revoked]
      public? false
    end

    attribute :starts_at, :utc_datetime_usec, allow_nil?: false, public?: false
    attribute :expires_at, :utc_datetime_usec, allow_nil?: false, public?: false
    attribute :revoked_at, :utc_datetime_usec, public?: false
    attribute :version, :integer, allow_nil?: false, default: 1, public?: false
  end

  relationships do
    belongs_to :subject, NewYou.Identity.Account do
      source_attribute :subject_account_id
      allow_nil? false
      attribute_writable? true
      public? false
    end

    belongs_to :target, NewYou.Identity.Account do
      source_attribute :target_account_id
      allow_nil? false
      attribute_writable? true
      public? false
    end

    belongs_to :approver, NewYou.Identity.Account do
      source_attribute :approver_account_id
      allow_nil? false
      attribute_writable? true
      public? false
    end
  end
end
