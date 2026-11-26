defmodule NewYou.Temperament.AssessmentDeliveryEvidence do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Temperament,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "temperament_assessment_delivery_evidence"
    repo NewYou.Repo

    check_constraints do
      check_constraint [:status, :successful_at], "assessment_delivery_evidence_shape",
        check: """
        (status = 'successful' AND successful_at IS NOT NULL) OR
        (status IN ('none', 'unavailable') AND successful_at IS NULL)
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
      accept [:recipient_id, :evidence_id, :status, :successful_at]
    end

    update :observe_fixture do
      public? false
      accept [:evidence_id, :status, :successful_at]
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

    attribute :status, :atom,
      allow_nil?: false,
      constraints: [one_of: [:none, :successful, :unavailable]]

    attribute :successful_at, AshPostgres.TimestamptzUsec
  end
end
