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
    identity_wheres_to_sql one_active_assignment: "state = 'active'"

    check_constraints do
      check_constraint :role, "identity_grants_role", check: "role = 'support'"

      check_constraint :scope, "identity_grants_scope",
        check:
          "scope IN ('security_hold_restriction', 'security_hold_review', 'security_hold_release', 'identity_reconciliation')"

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

    if Mix.env() in [:dev, :test] do
      create :provision do
        description "Private role/scope assignment for synthetic Phase-8 proof. Absent from production builds; runtime issuance needs its governed approval workflow."
        public? false

        accept [
          :subject_account_id,
          :role,
          :scope,
          :target_account_id,
          :approver_account_id,
          :reason_code,
          :starts_at,
          :expires_at
        ]
      end
    end

    update :revoke do
      description "Revoke once, invalidate elevated Sessions and establish selected Audit E2 work in the same transaction."
      public? false
      require_atomic? false
      accept []

      argument :actor_id, :uuid, allow_nil?: false

      argument :reason_code, :atom do
        allow_nil? false
        constraints one_of: [:suspected_compromise, :security_review]
      end

      touches_resources [
        NewYou.Identity.Account,
        NewYou.Identity.Session,
        NewYou.Audit.EvidenceObligation
      ]

      change NewYou.Identity.Changes.InvalidateGrantAssurance
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

    attribute :scope, :atom do
      allow_nil? false

      constraints one_of: [
                    :security_hold_restriction,
                    :security_hold_review,
                    :security_hold_release,
                    :identity_reconciliation
                  ]

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

  identities do
    identity :one_active_assignment,
             [:subject_account_id, :role, :scope, :target_account_id],
             where: expr(state == :active)
  end

  # Product §15.1A fixes role/scope authority. These bounded Support scopes are
  # JIT names for the selected hold and reconciliation operations; the target Account narrows each
  # assignment. A caller cannot choose an additional per-subject capability.
  @support_scope_capabilities %{
    security_hold_restriction: [:place_security_hold],
    security_hold_review: [:review_security_hold],
    security_hold_release: [:release_security_hold],
    identity_reconciliation: [:review_reconciliation, :apply_reconciliation]
  }

  @doc "Derive protected capabilities from the bounded Support role/scope catalogue. Current grant validity is checked by the owning action."
  @spec permits?(map(), atom()) :: boolean()
  def permits?(%{role: :support, scope: scope}, capability),
    do: capability in Map.get(@support_scope_capabilities, scope, [])

  def permits?(_grant, _capability), do: false
end
