defmodule NewYou.Privacy.PurposeAuthority do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Privacy,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "privacy_purpose_authorities"
    repo NewYou.Repo

    check_constraints do
      check_constraint :purpose, "privacy_purpose_authorities_purpose",
        check: "purpose = 'p8_17_protected_mutation'"

      check_constraint :state, "privacy_purpose_authorities_state",
        check: "state IN ('allowed', 'withdrawn')"

      check_constraint :origin, "privacy_purpose_authorities_origin",
        check: "origin = 'p8_17_test_fixture'"

      check_constraint :version, "privacy_purpose_authorities_version", check: "version > 0"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    if Mix.env() in [:dev, :test] do
      create :grant_proof_only do
        public? false
        accept [:subject_id, :source_operation_id, :purpose, :state, :origin, :version]
      end
    end

    if Mix.env() in [:dev, :test] do
      update :withdraw_proof_only do
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
    create_timestamp :created_at
    update_timestamp :updated_at

    attribute :subject_id, :uuid, allow_nil?: false, public?: false
    attribute :source_operation_id, :uuid, allow_nil?: false, public?: false

    attribute :purpose, :atom do
      allow_nil? false
      constraints one_of: [:p8_17_protected_mutation]
      public? false
    end

    attribute :state, :atom do
      allow_nil? false
      constraints one_of: [:allowed, :withdrawn]
      public? false
    end

    attribute :origin, :atom do
      allow_nil? false
      constraints one_of: [:p8_17_test_fixture]
      public? false
    end

    attribute :version, :integer, allow_nil?: false, public?: false
  end

  identities do
    identity :one_operation_purpose, [:subject_id, :purpose, :source_operation_id]
  end
end
