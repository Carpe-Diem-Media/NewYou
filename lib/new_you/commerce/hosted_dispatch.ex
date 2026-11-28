defmodule NewYou.Commerce.HostedDispatch do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban],
    authorizers: [Ash.Policy.Authorizer]

  def source_digest(snapshot),
    do: :crypto.hash(:sha256, :erlang.term_to_binary(snapshot, [:deterministic]))

  postgres do
    table "commerce_hosted_dispatches"
    repo NewYou.Repo

    references do
      reference :purchase, on_delete: :restrict
    end

    custom_indexes do
      index [:verify_after], where: "verify_after IS NOT NULL", name: "hosted_dispatch_verify_due"
    end

    check_constraints do
      check_constraint [
                         :fixture_port,
                         :fixture_certificate,
                         :claim_id,
                         :verify_round,
                         :verify_after
                       ],
                       "hosted_dispatch_verify_schedule",
                       check: """
                       verify_round BETWEEN 0 AND 6 AND
                       (fixture_port IS NULL OR (fixture_port BETWEEN 1 AND 65535 AND claim_id IS NOT NULL)) AND
                       (fixture_certificate IS NULL OR
                         (fixture_port IS NOT NULL AND octet_length(fixture_certificate) BETWEEN 1 AND 8192)) AND
                       (verify_after IS NULL OR fixture_port IS NOT NULL)
                       """

      check_constraint [:provider, :integration, :environment, :channel],
                       "commerce_hosted_dispatches_test_scope",
                       check: """
                       provider = 'paystack' AND integration IN ('local_fixture', 'voelgoedwinkel') AND
                       environment = 'test' AND channel = 'card'
                       """

      check_constraint [:integration, :provider_capability],
                       "commerce_hosted_dispatches_integration_isolation",
                       check: """
                       (integration = 'local_fixture' AND provider_capability IS NULL) OR
                       (integration = 'voelgoedwinkel' AND fixture_code IS NULL AND fixture_port IS NULL AND
                         fixture_certificate IS NULL AND verify_after IS NULL AND verify_round = 0 AND
                         (provider_capability IS NULL OR
                           (claim_id IS NOT NULL AND length(provider_capability) <= 504 AND provider_capability ~ '^XCP[.][A-Za-z0-9_-]+$')))
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

  if Mix.env() == :test do
    oban do
      triggers do
        trigger :verify_fixture_reference do
          action :verify_fixture_reference
          where expr(not is_nil(fixture_certificate) and verify_after <= now())
          scheduler_cron "* * * * *"
          queue :commerce_fixture
          log_errors? false
          log_final_error? false
          worker_module_name NewYou.Commerce.Workers.VerifyFixtureReference
          scheduler_module_name NewYou.Commerce.Schedulers.VerifyFixtureReference
        end
      end
    end
  end

  actions do
    read :read do
      primary? true
      public? false

      pagination do
        keyset? true
        required? false
      end
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

      accept if(Mix.env() == :test,
               do: [:fixture_port, :fixture_certificate, :verify_after],
               else: []
             )

      argument :claim_id, :uuid, allow_nil?: false
      change filter(expr(is_nil(claim_id)))
      change set_attribute(:claim_id, arg(:claim_id))
    end

    if Mix.env() == :test do
      update :defer_verify do
        public? false
        accept [:verify_after, :verify_round]
        change filter(expr(not is_nil(verify_after)))
      end

      update :respect_retry_after do
        public? false
        accept []
        argument :retry_after, AshPostgres.TimestamptzUsec, allow_nil?: false
        change filter(expr(verify_after < ^arg(:retry_after)))
        change set_attribute(:verify_after, arg(:retry_after))
      end

      update :close_verify do
        public? false
        accept []
        change set_attribute(:verify_after, nil)
      end

      action :verify_fixture_reference do
        public? false
        argument :primary_key, :map, allow_nil?: false
        run NewYou.Commerce.VerifyFixtureReference
      end

      update :retain do
        public? false
        accept [:fixture_code]

        argument :expected_claim_id, :uuid, allow_nil?: false
        change filter(expr(claim_id == ^arg(:expected_claim_id) and is_nil(fixture_code)))
        validate present(:fixture_code)
      end
    end

    update :retain_provider_capability do
      public? false
      accept [:provider_capability]

      argument :expected_claim_id, :uuid, allow_nil?: false

      change filter(
               expr(
                 integration == :voelgoedwinkel and claim_id == ^arg(:expected_claim_id) and
                   is_nil(provider_capability)
               )
             )

      validate present(:provider_capability)
    end
  end

  policies do
    if Mix.env() == :test do
      policy action([:read, :verify_fixture_reference]) do
        authorize_if AshOban.Checks.AshObanInteraction
      end
    else
      policy always() do
        forbid_if always()
      end
    end
  end

  attributes do
    attribute :reference, :string, allow_nil?: false, sensitive?: true
    attribute :source_digest, :binary, allow_nil?: false, sensitive?: true
    attribute :provider, :atom, allow_nil?: false, constraints: [one_of: [:paystack]]

    attribute :integration, :atom,
      allow_nil?: false,
      constraints: [one_of: [:local_fixture, :voelgoedwinkel]]

    attribute :environment, :atom, allow_nil?: false, constraints: [one_of: [:test]]
    attribute :channel, :atom, allow_nil?: false, constraints: [one_of: [:card]]
    attribute :claim_id, :uuid
    attribute :fixture_port, :integer, constraints: [min: 1, max: 65_535]
    attribute :fixture_certificate, :binary, sensitive?: true
    attribute :verify_after, AshPostgres.TimestamptzUsec

    attribute :verify_round, :integer,
      default: 0,
      allow_nil?: false,
      constraints: [min: 0, max: 6]

    attribute :fixture_code, :string,
      sensitive?: true,
      constraints: [trim?: false, max_length: 128]

    attribute :provider_capability, :string,
      sensitive?: true,
      constraints: [trim?: false, max_length: 504]
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
