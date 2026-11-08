defmodule NewYou.Identity.ReconciliationCase do
  @moduledoc """
  Identity-owned duplicate review and immutable canonical-decision provenance.
  Original Accounts survive. Compensating cases link a prior applied decision;
  they never revive its retired PMR. Call the Identity reconciliation interfaces.
  """
  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Identity,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "reconciliation_cases"
    repo NewYou.Repo

    custom_indexes do
      index [:candidate_id]
      index [:canonical_id]
      index [:status, :updated_at]
    end

    check_constraints do
      check_constraint :status, "reconciliation_cases_status",
        check:
          "status IN ('detected','candidate','review','approved','rejected','conflict','applied')"

      check_constraint :candidate_id, "reconciliation_cases_distinct_accounts",
        check: "candidate_id <> canonical_id"

      check_constraint :version, "reconciliation_cases_version", check: "version >= 0"

      check_constraint :status, "reconciliation_cases_decision_shape",
        check:
          "(status NOT IN ('approved','applied') OR review IS NOT NULL) AND ((status = 'applied' AND applied_operation_id IS NOT NULL AND applied_at IS NOT NULL AND apply_binding IS NOT NULL) OR (status <> 'applied' AND applied_operation_id IS NULL AND applied_at IS NULL AND apply_binding IS NULL))"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :detect do
      description "Private creation under current scoped Identity authority; no merge effects."
      public? false

      accept [
        :operation_id,
        :candidate_id,
        :canonical_id,
        :detected_by_id,
        :detection_basis,
        :compensates_id
      ]
    end

    update :record_review do
      description "Private version-guarded review transition under locked current authority."
      public? false
      accept [:status, :review, :history]
      argument :expected_version, :integer, allow_nil?: false

      change filter(
               expr(version == ^arg(:expected_version) and status not in [:applied, :rejected])
             )

      change increment(:version)
    end

    update :apply_decision do
      description "Private approved decision commit, atomic with Account retirement and linked E2 evidence."
      public? false
      accept [:applied_operation_id, :applied_at, :apply_binding, :history]
      argument :expected_version, :integer, allow_nil?: false
      change filter(expr(version == ^arg(:expected_version) and status == :approved))
      change set_attribute(:status, :applied)
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
    update_timestamp :updated_at
    attribute :operation_id, :uuid, allow_nil?: false, public?: false

    attribute :detection_basis, :atom,
      allow_nil?: false,
      public?: false,
      constraints: [one_of: [:verified_control, :reported_duplicate, :demographic_similarity]]

    attribute :status, :atom,
      allow_nil?: false,
      default: :detected,
      public?: false,
      constraints: [
        one_of: [:detected, :candidate, :review, :approved, :rejected, :conflict, :applied]
      ]

    attribute :version, :integer, allow_nil?: false, default: 0, public?: false
    attribute :review, :map, sensitive?: true, public?: false

    attribute :history, {:array, :map},
      allow_nil?: false,
      default: [],
      sensitive?: true,
      public?: false

    attribute :applied_operation_id, :uuid, public?: false
    attribute :applied_at, :utc_datetime_usec, public?: false
    attribute :apply_binding, :map, sensitive?: true, public?: false
  end

  relationships do
    belongs_to :candidate, NewYou.Identity.Account do
      source_attribute :candidate_id
      allow_nil? false
      attribute_writable? true
      public? false
    end

    belongs_to :canonical, NewYou.Identity.Account do
      source_attribute :canonical_id
      allow_nil? false
      attribute_writable? true
      public? false
    end

    belongs_to :detected_by, NewYou.Identity.Account do
      source_attribute :detected_by_id
      allow_nil? false
      attribute_writable? true
      public? false
    end

    belongs_to :compensates, __MODULE__ do
      source_attribute :compensates_id
      attribute_writable? true
      public? false
    end
  end

  identities do
    identity :one_detection_operation, [:operation_id]
    identity :one_apply_operation, [:applied_operation_id]
  end
end
