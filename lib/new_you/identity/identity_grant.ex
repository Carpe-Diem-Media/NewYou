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

    identity_wheres_to_sql one_active_assignment: "state = 'active' AND dispute_id IS NULL",
                           one_active_disclosure: "state = 'active' AND dispute_id IS NOT NULL"

    check_constraints do
      check_constraint :role, "identity_grants_role",
        check: """
        role IN ('support', 'finance', 'audit_reader', 'finance_disclosure_approver', 'audit_access_approver')
        """

      check_constraint :scope, "identity_grants_scope",
        check: """
        (
          dispute_id IS NULL AND source_operation_id IS NULL AND approval_grant_id IS NULL
          AND (
            (role = 'support' AND scope IN ('security_hold_restriction', 'security_hold_review', 'security_hold_release', 'identity_reconciliation', 'identity_recovery', 'identity_lookup'))
            OR (role, scope) IN (
              ('finance_disclosure_approver', 'approve_finance_dispute_disclosure'),
              ('audit_access_approver', 'approve_audit_dispute_evidence')
            )
          )
        ) OR (
          dispute_id IS NOT NULL AND source_operation_id IS NOT NULL AND approval_grant_id IS NOT NULL
          AND (role, scope) IN (
            ('finance', 'finance_dispute_disclosure'),
            ('audit_reader', 'audit_dispute_evidence')
          )
        )
        """

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

        validate attribute_equals(:role, :support)
      end
    end

    if Mix.env() == :test do
      create :provision_fixture_dispute_approver do
        description "Seed a recipient-scoped Domain approval role using isolated TEST authority."
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

        validate one_of(:role, [:finance_disclosure_approver, :audit_access_approver])
      end

      create :approve_fixture_dispute_disclosure do
        description "Record the approved exact disclosure scope and the active Domain approver grant used for approval."
        public? false

        accept [
          :subject_account_id,
          :role,
          :scope,
          :target_account_id,
          :approver_account_id,
          :approval_grant_id,
          :dispute_id,
          :source_operation_id,
          :reason_code,
          :starts_at,
          :expires_at
        ]

        validate one_of(:role, [:finance, :audit_reader])
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

      constraints one_of: [
                    :support,
                    :finance,
                    :audit_reader,
                    :finance_disclosure_approver,
                    :audit_access_approver
                  ]

      public? false
    end

    attribute :scope, :atom do
      allow_nil? false

      constraints one_of: [
                    :security_hold_restriction,
                    :security_hold_review,
                    :security_hold_release,
                    :identity_reconciliation,
                    :identity_recovery,
                    :identity_lookup,
                    :finance_dispute_disclosure,
                    :audit_dispute_evidence,
                    :approve_finance_dispute_disclosure,
                    :approve_audit_dispute_evidence
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
    attribute :dispute_id, :uuid, public?: false
    attribute :source_operation_id, :uuid, public?: false
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

    belongs_to :approval_grant, NewYou.Identity.IdentityGrant do
      allow_nil? true
      attribute_writable? true
      public? false
    end
  end

  identities do
    identity :one_active_assignment,
             [:subject_account_id, :role, :scope, :target_account_id],
             where: expr(state == :active and is_nil(dispute_id))

    identity :one_active_disclosure,
             [:subject_account_id, :role, :scope, :dispute_id, :source_operation_id],
             where: expr(state == :active and not is_nil(dispute_id))
  end

  # Product §15.1A fixes role/scope authority. These bounded Support scopes are
  # JIT names for selected bounded Support operations; the target Account
  # narrows each assignment. A caller cannot choose a per-subject capability.
  @support_scope_capabilities %{
    security_hold_restriction: [:place_security_hold],
    security_hold_review: [:review_security_hold],
    security_hold_release: [:release_security_hold],
    identity_reconciliation: [:review_reconciliation, :apply_reconciliation],
    identity_recovery: [:approve_manual_recovery, :complete_manual_recovery]
  }

  def permits?(
        %{role: :support, scope: :identity_lookup, reason_code: :security_review},
        :lookup_identity
      ),
      do: true

  def permits?(%{role: :support, scope: :identity_lookup}, _capability), do: false

  @doc "Derive protected capabilities from the bounded Support role/scope catalogue. Current grant validity is checked by the owning action."
  @spec permits?(map(), atom()) :: boolean()
  def permits?(%{role: :support, scope: scope}, capability),
    do: capability in Map.get(@support_scope_capabilities, scope, [])

  def permits?(_grant, _capability), do: false
end
