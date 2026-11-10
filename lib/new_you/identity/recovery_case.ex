defmodule NewYou.Identity.RecoveryCase do
  @moduledoc """
  Identity-owned graduated recovery authority. Call the Identity recovery interfaces.
  State and assurance are separate. Account locks arbitrate every transition; the
  database prevents assurance reduction, history rewrite and terminal reopening.
  History contains only transition provenance, never submitted recovery material.
  """
  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Identity,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  postgres do
    table "recovery_cases"
    repo NewYou.Repo

    identity_wheres_to_sql active_account:
                             "state NOT IN ('completed','failed','expired','cancelled')"

    custom_indexes do
      index [:account_id, :state, :expires_at]
      index [:state, :updated_at]
    end

    check_constraints do
      check_constraint :proof_jti, "recovery_cases_proof_shape",
        check:
          "(state NOT IN ('proof_pending','additional_assurance','completed') OR proof_jti IS NOT NULL) AND (satisfied_assurance = 0 OR proof_acceptance_id IS NOT NULL) AND (required_assurance <> 2 OR state <> 'completed' OR review IS NOT NULL)"

      check_constraint :locale, "recovery_cases_locale", check: "locale IN ('en','af')"
      check_constraint :version, "recovery_cases_version", check: "version >= 0"

      check_constraint :state, "recovery_cases_state",
        check:
          "state IN ('requested','proof_pending','additional_assurance','held_manual_review','completed','failed','expired','cancelled')"

      check_constraint :required_assurance, "recovery_cases_assurance",
        check:
          "required_assurance IN (1,2) AND satisfied_assurance >= 0 AND satisfied_assurance <= 2"

      check_constraint :state, "recovery_cases_terminal",
        check:
          "(state IN ('completed','failed','expired','cancelled')) = (terminated_at IS NOT NULL) AND (state = 'completed') = (completed_at IS NOT NULL AND completion_id IS NOT NULL)"

      check_constraint :state, "recovery_cases_completion",
        check: "state <> 'completed' OR satisfied_assurance >= required_assurance"
    end
  end

  state_machine do
    initial_states [:requested]
    default_initial_state :requested
    state_attribute :state

    transitions do
      transition :await_proof, from: :requested, to: :proof_pending
      transition :accept_proof, from: :proof_pending, to: :additional_assurance

      transition :require_review,
        from: [:requested, :proof_pending, :additional_assurance],
        to: :held_manual_review

      transition :finish, from: [:additional_assurance, :held_manual_review], to: :completed

      transition :cancel,
        from: [:requested, :proof_pending, :additional_assurance, :held_manual_review],
        to: :cancelled

      transition :expire,
        from: [:requested, :proof_pending, :additional_assurance, :held_manual_review],
        to: :expired

      transition :fail,
        from: [:requested, :proof_pending, :additional_assurance, :held_manual_review],
        to: :failed
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :request do
      public? false

      accept [
        :operation_id,
        :account_id,
        :required_assurance,
        :account_binding,
        :expires_at,
        :locale,
        :history
      ]
    end

    for {name, destination} <- [
          await_proof: :proof_pending,
          accept_proof: :additional_assurance,
          require_review: :held_manual_review,
          finish: :completed,
          cancel: :cancelled,
          expire: :expired,
          fail: :failed
        ] do
      update name do
        public? false

        accept [
          :proof_jti,
          :required_assurance,
          :satisfied_assurance,
          :account_binding,
          :proof_acceptance_id,
          :review,
          :completed_at,
          :completion_id,
          :terminated_at,
          :history
        ]

        change increment(:version)
        change transition_state(destination)
      end
    end

    update :record_review do
      public? false
      accept [:review, :history, :account_binding]
      change filter(expr(state == :held_manual_review))
      change increment(:version)
    end

    for name <- [
          :submit_recovery_proof,
          :complete_recovery,
          :approve_manual_recovery,
          :complete_manual_recovery,
          :cancel_recovery
        ] do
      action name, if(name == :approve_manual_recovery, do: :map, else: :atom) do
        public? false
        transaction? false
        argument :request, :map, allow_nil?: false, sensitive?: true
        run {NewYou.Identity.Actions.Recovery, operation: name}
      end
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :operation_id, :uuid, allow_nil?: false, public?: false

    attribute :state, :atom,
      allow_nil?: false,
      default: :requested,
      public?: false,
      constraints: [
        one_of: [
          :requested,
          :proof_pending,
          :additional_assurance,
          :held_manual_review,
          :completed,
          :failed,
          :expired,
          :cancelled
        ]
      ]

    attribute :required_assurance, :integer,
      allow_nil?: false,
      constraints: [min: 1, max: 2],
      public?: false

    attribute :satisfied_assurance, :integer,
      allow_nil?: false,
      default: 0,
      constraints: [min: 0, max: 2],
      public?: false

    attribute :version, :integer, allow_nil?: false, default: 0, public?: false
    attribute :account_binding, :binary, allow_nil?: false, sensitive?: true, public?: false
    attribute :proof_jti, :string, sensitive?: true, public?: false
    attribute :proof_acceptance_id, :uuid, public?: false
    attribute :completion_id, :uuid, public?: false
    attribute :review, :map, sensitive?: true, public?: false

    attribute :history, {:array, :map},
      allow_nil?: false,
      default: [],
      sensitive?: true,
      public?: false

    attribute :locale, :string,
      allow_nil?: false,
      constraints: [match: ~r/\A(en|af)\z/],
      public?: false

    attribute :expires_at, :utc_datetime_usec, allow_nil?: false, public?: false
    attribute :completed_at, :utc_datetime_usec, public?: false
    attribute :terminated_at, :utc_datetime_usec, public?: false
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :account, NewYou.Identity.Account do
      allow_nil? false
      attribute_writable? true
      public? false
    end
  end

  identities do
    identity :request_operation, [:operation_id]
    identity :completion_operation, [:completion_id]

    identity :active_account, [:account_id],
      where: expr(state not in [:completed, :failed, :expired, :cancelled])
  end
end
