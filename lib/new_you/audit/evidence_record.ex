defmodule NewYou.Audit.EvidenceRecord do
  @moduledoc "Append-only Audit assertions. E1 admission is independent of subsequent source outcomes."
  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Audit,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "evidence_records"
    repo NewYou.Repo

    check_constraints do
      check_constraint :assertion_kind, "evidence_records_assertion_shape",
        check:
          "(assertion_kind = 'materialisation' AND obligation_id IS NOT NULL AND attempt_id IS NULL AND action_class IS NULL AND actor_id IS NULL AND target_id IS NULL AND grant_id IS NULL AND grant_version IS NULL AND session_id IS NULL AND expected_version IS NULL AND reason_code IS NULL AND admitted_at IS NULL AND outcome IS NULL AND case_id IS NULL AND canonical_grant_id IS NULL AND canonical_grant_version IS NULL) OR (assertion_kind = 'admission' AND obligation_id IS NULL AND attempt_id IS NOT NULL AND action_class IS NOT NULL AND action_class IN ('security_hold_release', 'identity_reconciliation', 'identity_recovery') AND ((action_class = 'security_hold_release' AND case_id IS NULL AND canonical_grant_id IS NULL AND canonical_grant_version IS NULL) OR (action_class = 'identity_reconciliation' AND case_id IS NOT NULL AND canonical_grant_id IS NOT NULL AND canonical_grant_version IS NOT NULL AND canonical_grant_version > 0) OR (action_class = 'identity_recovery' AND case_id IS NOT NULL AND canonical_grant_id IS NULL AND canonical_grant_version IS NULL)) AND actor_id IS NOT NULL AND target_id IS NOT NULL AND grant_id IS NOT NULL AND grant_version IS NOT NULL AND grant_version > 0 AND session_id IS NOT NULL AND expected_version IS NOT NULL AND expected_version >= 0 AND reason_code IS NOT NULL AND reason_code IN ('suspected_compromise', 'security_review', 'verified_recovery', 'mistaken_hold') AND admitted_at IS NOT NULL AND outcome IS NOT NULL AND outcome = 'admitted')"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :materialize do
      accept [:obligation_id]
      public? false
    end

    create :admit_reconciliation do
      description "Immutable E1 admission for one explicitly bound reconciliation case and attempt."
      public? false

      accept [
        :attempt_id,
        :case_id,
        :canonical_grant_id,
        :canonical_grant_version,
        :actor_id,
        :target_id,
        :grant_id,
        :grant_version,
        :session_id,
        :expected_version,
        :reason_code,
        :admitted_at,
        :action_class
      ]

      change set_attribute(:assertion_kind, :admission)
      change set_attribute(:action_class, :identity_reconciliation)
      change set_attribute(:outcome, :admitted)
    end

    create :admit_recovery do
      description "Immutable E1 admission bound to one Identity recovery case and attempt."
      public? false

      accept [
        :attempt_id,
        :case_id,
        :actor_id,
        :target_id,
        :grant_id,
        :grant_version,
        :session_id,
        :expected_version,
        :reason_code,
        :admitted_at,
        :action_class
      ]

      change set_attribute(:assertion_kind, :admission)
      change set_attribute(:action_class, :identity_recovery)
      change set_attribute(:outcome, :admitted)
    end

    create :admit_security_hold_release do
      description "Minimum immutable E1 assertion of an authorised attempt, never a completed release."
      public? false

      accept [
        :action_class,
        :attempt_id,
        :actor_id,
        :target_id,
        :grant_id,
        :grant_version,
        :session_id,
        :expected_version,
        :reason_code,
        :admitted_at
      ]

      change set_attribute(:assertion_kind, :admission)
      change set_attribute(:action_class, :security_hold_release)
      change set_attribute(:outcome, :admitted)
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

    attribute :assertion_kind, :atom,
      allow_nil?: false,
      default: :materialisation,
      constraints: [one_of: [:materialisation, :admission]],
      public?: false

    attribute :case_id, :uuid, public?: false
    attribute :canonical_grant_id, :uuid, public?: false
    attribute :canonical_grant_version, :integer, constraints: [min: 1], public?: false
    attribute :attempt_id, :uuid, public?: false

    attribute :action_class, :atom,
      constraints: [
        one_of: [:security_hold_release, :identity_reconciliation, :identity_recovery]
      ],
      public?: false

    attribute :actor_id, :uuid, public?: false
    attribute :target_id, :uuid, public?: false
    attribute :grant_id, :uuid, public?: false
    attribute :grant_version, :integer, constraints: [min: 1], public?: false
    attribute :session_id, :uuid, public?: false
    attribute :expected_version, :integer, constraints: [min: 0], public?: false

    attribute :reason_code, :atom,
      constraints: [
        one_of: [:suspected_compromise, :security_review, :verified_recovery, :mistaken_hold]
      ],
      public?: false

    attribute :admitted_at, AshPostgres.TimestamptzUsec, public?: false
    attribute :outcome, :atom, constraints: [one_of: [:admitted]], public?: false
  end

  relationships do
    belongs_to :obligation, NewYou.Audit.EvidenceObligation do
      allow_nil? true
      attribute_writable? true
      public? false
    end
  end

  identities do
    identity :one_admission_per_attempt, [:attempt_id]

    identity :one_record_per_obligation, [:obligation_id],
      message: "already has a materialised evidence record"
  end
end
