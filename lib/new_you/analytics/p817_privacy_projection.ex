defmodule NewYou.Analytics.P817PrivacyProjection do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Analytics,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "p817_privacy_projections"
    repo NewYou.Repo

    check_constraints do
      check_constraint :projection_key, "p817_privacy_projections_valid_key",
        check:
          "projection_key = 'p817_current_privacy_aggregate' OR projection_key ~ '^p817_test_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'"

      check_constraint :current_allowed_count, "p817_privacy_projections_non_negative_count",
        check: "current_allowed_count >= 0"

      check_constraint :privacy_revision, "p817_privacy_projections_non_negative_revision",
        check: "privacy_revision >= 0"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    if Mix.env() in [:dev, :test] do
      create :rebuild do
        description "Rebuild one minimized aggregate through the Analytics owner interface."
        public? false
        accept [:projection_key, :current_allowed_count, :privacy_revision]
        upsert_condition expr(privacy_revision <= upsert_conflict(:privacy_revision))
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

    attribute :projection_key, :string do
      allow_nil? false
      public? false
    end

    attribute :current_allowed_count, :integer do
      allow_nil? false
      constraints min: 0
      public? false
    end

    attribute :privacy_revision, :integer do
      allow_nil? false
      constraints min: 0
      default 0
      public? false
    end
  end

  identities do
    identity :single_projection, [:projection_key]
  end
end
