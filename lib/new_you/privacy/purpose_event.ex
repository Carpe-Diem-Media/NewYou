defmodule NewYou.Privacy.PurposeEvent do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Privacy,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "privacy_purpose_events"
    repo NewYou.Repo

    check_constraints do
      check_constraint :purpose, "privacy_purpose_events_purpose",
        check: "purpose = 'p8_17_protected_mutation'"

      check_constraint :transition, "privacy_purpose_events_transition",
        check: "transition IN ('granted', 'withdrawn')"

      check_constraint :origin, "privacy_purpose_events_origin",
        check: "origin = 'p8_17_test_fixture'"

      check_constraint :version, "privacy_purpose_events_version", check: "version > 0"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    if Mix.env() in [:dev, :test] do
      create :record_transition do
        public? false

        accept [
          :authority_id,
          :subject_id,
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
    create_timestamp :created_at

    attribute :authority_id, :uuid, allow_nil?: false, public?: false
    attribute :subject_id, :uuid, allow_nil?: false, public?: false
    attribute :source_operation_id, :uuid, allow_nil?: false, public?: false

    attribute :purpose, :atom do
      allow_nil? false
      constraints one_of: [:p8_17_protected_mutation]
      public? false
    end

    attribute :transition, :atom do
      allow_nil? false
      constraints one_of: [:granted, :withdrawn]
      public? false
    end

    attribute :origin, :atom do
      allow_nil? false
      constraints one_of: [:p8_17_test_fixture]
      public? false
    end

    attribute :version, :integer, allow_nil?: false, public?: false
  end

  relationships do
    belongs_to :authority, NewYou.Privacy.PurposeAuthority do
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
