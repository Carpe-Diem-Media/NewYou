defmodule NewYou.Privacy.FixtureDisputePurposeEvent do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Privacy,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "privacy_fixture_dispute_purpose_events"
    repo NewYou.Repo
    identity_index_names one_transition_per_version: "fixture_dispute_purpose_event_uidx"

    check_constraints do
      check_constraint :purpose, "fixture_dispute_purpose_events_purpose",
        check: "purpose = 'commercial_dispute_evidence'"

      check_constraint :transition, "fixture_dispute_purpose_events_transition",
        check: "transition IN ('granted', 'withdrawn')"

      check_constraint :origin, "fixture_dispute_purpose_events_origin",
        check: "origin = 'fp002_dispute_test_fixture'"

      check_constraint :version, "fixture_dispute_purpose_events_version", check: "version > 0"
    end
  end

  actions do
    if Mix.env() == :test do
      read :read do
        primary? true
        public? false
      end

      create :record_fixture_transition do
        public? false

        accept [
          :authority_id,
          :subject_id,
          :dispute_id,
          :source_operation_id,
          :purpose,
          :transition,
          :origin,
          :version
        ]
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
    create_timestamp :recorded_at

    attribute :authority_id, :uuid, allow_nil?: false, public?: false
    attribute :subject_id, :uuid, allow_nil?: false, public?: false
    attribute :dispute_id, :uuid, allow_nil?: false, public?: false
    attribute :source_operation_id, :uuid, allow_nil?: false, public?: false

    attribute :purpose, :atom do
      allow_nil? false
      constraints one_of: [:commercial_dispute_evidence]
      public? false
    end

    attribute :transition, :atom do
      allow_nil? false
      constraints one_of: [:granted, :withdrawn]
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
    belongs_to :authority, NewYou.Privacy.FixtureDisputePurposeAuthority do
      source_attribute :authority_id
      allow_nil? false
      attribute_writable? true
      public? false
    end
  end

  identities do
    identity :one_transition_per_version, [:authority_id, :version]
  end
end
