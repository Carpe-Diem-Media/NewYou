defmodule NewYou.Commerce.HostedDispatch do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_hosted_dispatches"
    repo NewYou.Repo

    references do
      reference :purchase, on_delete: :restrict
    end

    check_constraints do
      check_constraint [:provider, :integration, :environment, :channel],
                       "commerce_hosted_dispatches_fixture_scope",
                       check: """
                       provider = 'paystack' AND integration = 'local_fixture' AND
                       environment = 'test' AND channel = 'card'
                       """

      check_constraint [:reference, :source_digest],
                       "commerce_hosted_dispatches_binding",
                       check: "reference ~ '^[0-9a-f]{32}$' AND octet_length(source_digest) = 32"

      check_constraint [:claim_id, :fixture_code], "commerce_hosted_dispatches_claim",
        check: """
        fixture_code IS NULL OR
          (claim_id IS NOT NULL AND fixture_code ~ '^[a-zA-Z0-9_-]{1,128}$')
        """
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :bind do
      public? false

      accept [
        :attempt_id,
        :reference,
        :source_digest,
        :provider,
        :integration,
        :environment,
        :channel
      ]
    end

    update :claim do
      public? false
      accept []

      argument :claim_id, :uuid, allow_nil?: false
      change filter(expr(is_nil(claim_id)))
      change set_attribute(:claim_id, arg(:claim_id))
    end

    update :retain do
      public? false
      accept [:fixture_code]

      argument :expected_claim_id, :uuid, allow_nil?: false
      change filter(expr(claim_id == ^arg(:expected_claim_id) and is_nil(fixture_code)))
      validate present(:fixture_code)
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    attribute :reference, :string, allow_nil?: false, sensitive?: true
    attribute :source_digest, :binary, allow_nil?: false, sensitive?: true
    attribute :provider, :atom, allow_nil?: false, constraints: [one_of: [:paystack]]
    attribute :integration, :atom, allow_nil?: false, constraints: [one_of: [:local_fixture]]
    attribute :environment, :atom, allow_nil?: false, constraints: [one_of: [:test]]
    attribute :channel, :atom, allow_nil?: false, constraints: [one_of: [:card]]
    attribute :claim_id, :uuid

    attribute :fixture_code, :string,
      sensitive?: true,
      constraints: [trim?: false, max_length: 128]
  end

  relationships do
    belongs_to :purchase, NewYou.Commerce.Purchase do
      source_attribute :attempt_id
      destination_attribute :attempt_id
      primary_key? true
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :scoped_reference, [:provider, :integration, :environment, :reference]
  end
end
