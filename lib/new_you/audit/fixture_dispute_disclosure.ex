defmodule NewYou.Audit.FixtureDisputeDisclosure do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Audit,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "audit_fixture_dispute_disclosures"
    repo NewYou.Repo

    check_constraints do
      check_constraint :purpose, "audit_fixture_dispute_disclosures_purpose",
        check: "purpose = 'fixture_dispute_evidence_read'"

      check_constraint :field_set, "audit_fixture_dispute_disclosures_field_set",
        check: "field_set = 'commercial_dispute_v1'"
    end
  end

  actions do
    if Mix.env() == :test do
      read :read do
        primary? true
        public? false
      end

      create :record_disclosure do
        public? false
        accept [:operation_id, :actor_id, :dispute_id, :purpose, :field_set]
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

    attribute :operation_id, :uuid, allow_nil?: false, public?: false
    attribute :actor_id, :uuid, allow_nil?: false, public?: false
    attribute :dispute_id, :uuid, allow_nil?: false, public?: false

    attribute :purpose, :atom do
      allow_nil? false
      constraints one_of: [:fixture_dispute_evidence_read]
      public? false
    end

    attribute :field_set, :string do
      allow_nil? false
      public? false
    end
  end

  identities do
    identity :operation, [:operation_id]
  end
end
