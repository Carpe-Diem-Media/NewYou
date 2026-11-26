defmodule NewYou.Entitlements.AssessmentCreditEvidence do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Entitlements,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "entitlements_assessment_credit_evidence"
    repo NewYou.Repo

    check_constraints do
      check_constraint [:ordinary_state, :credit_id], "assessment_credit_evidence_shape",
        check: """
        ((ordinary_state IN ('none', 'unavailable') AND credit_id IS NULL) OR
          (ordinary_state IN ('available_unused', 'held_unconsumed', 'consumed', 'closed') AND credit_id IS NOT NULL))
        AND premium_state IN ('none', 'available_unused', 'expired')
        """
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :establish_fixture do
      public? false
      accept [:recipient_id, :evidence_id, :ordinary_state, :credit_id, :premium_state]
    end

    update :observe_fixture do
      public? false
      accept [:evidence_id, :ordinary_state, :credit_id, :premium_state]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    attribute :recipient_id, :uuid, primary_key?: true, allow_nil?: false
    attribute :evidence_id, :uuid, allow_nil?: false

    attribute :ordinary_state, :atom,
      allow_nil?: false,
      constraints: [
        one_of: [:none, :unavailable, :available_unused, :held_unconsumed, :consumed, :closed]
      ]

    attribute :credit_id, :uuid

    attribute :premium_state, :atom,
      allow_nil?: false,
      constraints: [one_of: [:none, :available_unused, :expired]]
  end
end
