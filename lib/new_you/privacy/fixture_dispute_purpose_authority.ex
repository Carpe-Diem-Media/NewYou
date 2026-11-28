defmodule NewYou.Privacy.FixtureDisputePurposeAuthority do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Privacy,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "privacy_fixture_dispute_purposes"
    repo NewYou.Repo
    identity_index_names one_operation_dispute_purpose: "fixture_dispute_purpose_owner_uidx"

    check_constraints do
      check_constraint :purpose, "fixture_dispute_purpose_authorities_purpose",
        check: "purpose = 'commercial_dispute_evidence'"

      check_constraint :state, "fixture_dispute_purpose_authorities_state",
        check: "state IN ('allowed', 'withdrawn')"

      check_constraint :origin, "fixture_dispute_purpose_authorities_origin",
        check: "origin = 'fp002_dispute_test_fixture'"

      check_constraint :version, "fixture_dispute_purpose_authorities_version",
        check: "version > 0"
    end
  end

  actions do
    if Mix.env() == :test do
      read :read do
        primary? true
        public? false
      end

      create :grant_fixture_only do
        public? false

        accept [
          :subject_id,
          :dispute_id,
          :source_operation_id,
          :purpose,
          :state,
          :origin,
          :version
        ]
      end

      update :withdraw_fixture_only do
        public? false
        require_atomic? false
        accept [:version]
        change set_attribute(:state, :withdrawn)
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
    create_timestamp :inserted_at
    update_timestamp :updated_at

    attribute :subject_id, :uuid, allow_nil?: false, public?: false
    attribute :dispute_id, :uuid, allow_nil?: false, public?: false
    attribute :source_operation_id, :uuid, allow_nil?: false, public?: false

    attribute :purpose, :atom do
      allow_nil? false
      constraints one_of: [:commercial_dispute_evidence]
      public? false
    end

    attribute :state, :atom do
      allow_nil? false
      constraints one_of: [:allowed, :withdrawn]
      public? false
    end

    attribute :origin, :atom do
      allow_nil? false
      constraints one_of: [:fp002_dispute_test_fixture]
      public? false
    end

    attribute :version, :integer, allow_nil?: false, public?: false
  end

  relationships do
    has_many :events, NewYou.Privacy.FixtureDisputePurposeEvent do
      destination_attribute :authority_id
      public? false
    end
  end

  identities do
    identity :one_operation_dispute_purpose, [:subject_id, :dispute_id, :source_operation_id]
  end
end
