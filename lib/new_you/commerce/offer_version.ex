defmodule NewYou.Commerce.OfferVersion do
  @moduledoc false

  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Commerce,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "commerce_offer_versions"
    repo NewYou.Repo

    custom_indexes do
      index [:product],
        unique: true,
        where: "state = 'approved'",
        name: "commerce_offer_versions_one_approved"
    end

    check_constraints do
      check_constraint [:product, :amount_minor], "commerce_offer_versions_amounts",
        check: """
        currency = 'ZAR' AND amount_minor > 0 AND
        plan_list_minor >= 0 AND assessment_list_minor >= 0 AND
        plan_discount_minor >= 0 AND assessment_discount_minor >= 0 AND
        (plan_list_minor = 0 AND plan_discount_minor = 0 OR plan_list_minor > plan_discount_minor) AND
        (assessment_list_minor = 0 AND assessment_discount_minor = 0 OR
          assessment_list_minor > assessment_discount_minor) AND
        (plan_list_minor::numeric - plan_discount_minor) +
          (assessment_list_minor::numeric - assessment_discount_minor) = amount_minor AND
        ((product = 'plan' AND assessment_list_minor = 0 AND allocation_version IS NULL) OR
         (product = 'assessment' AND plan_list_minor = 0 AND allocation_version IS NULL) OR
         (product = 'bundle' AND plan_list_minor > 0 AND assessment_list_minor > 0 AND
          (plan_discount_minor > 0 OR assessment_discount_minor > 0) AND allocation_version IS NOT NULL))
        """

      check_constraint [:state, :approval_id], "commerce_offer_versions_lifecycle",
        check: """
        (state = 'draft' AND approval_id IS NULL AND approved_at IS NULL AND
          disclosure_en_id IS NULL AND disclosure_af_id IS NULL AND allocation_approval_id IS NULL
          AND withdrawal_id IS NULL) OR
        (state IN ('approved', 'superseded', 'withdrawn') AND approval_id IS NOT NULL
          AND approved_at IS NOT NULL AND disclosure_en_id IS NOT NULL AND disclosure_af_id IS NOT NULL
          AND disclosure_en_id <> disclosure_af_id
          AND (expires_at IS NULL OR expires_at > approved_at)
          AND ((product = 'bundle' AND allocation_approval_id IS NOT NULL
            AND allocation_approval_id <> approval_id) OR
            (product <> 'bundle' AND allocation_approval_id IS NULL))
          AND ((state = 'withdrawn') = (withdrawal_id IS NOT NULL)))
        """
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :draft do
      public? false

      accept [
        :id,
        :product,
        :price_version,
        :currency,
        :amount_minor,
        :plan_list_minor,
        :plan_discount_minor,
        :assessment_list_minor,
        :assessment_discount_minor,
        :allocation_version,
        :promotion_version,
        :expires_at
      ]
    end

    update :approve do
      public? false

      accept [
        :approval_id,
        :allocation_approval_id,
        :disclosure_en_id,
        :disclosure_af_id,
        :approved_at
      ]

      change set_attribute(:state, :approved)
      change filter expr(state == :draft)
    end

    update :supersede do
      public? false
      accept []
      change set_attribute(:state, :superseded)
      change filter expr(state == :approved)
    end

    update :withdraw do
      public? false
      accept [:withdrawal_id]
      change set_attribute(:state, :withdrawn)
      change filter expr(state == :approved)
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    attribute :id, :uuid, primary_key?: true, allow_nil?: false

    attribute :product, :atom,
      allow_nil?: false,
      constraints: [one_of: [:plan, :assessment, :bundle]]

    attribute :price_version, :string, allow_nil?: false, constraints: [max_length: 120]
    attribute :currency, :string, allow_nil?: false, constraints: [match: ~r/\AZAR\z/]
    attribute :amount_minor, :integer, allow_nil?: false
    attribute :assessment_list_minor, :integer, allow_nil?: false
    attribute :assessment_discount_minor, :integer, allow_nil?: false
    attribute :plan_list_minor, :integer, allow_nil?: false
    attribute :plan_discount_minor, :integer, allow_nil?: false
    attribute :allocation_version, :string, constraints: [max_length: 120]
    attribute :promotion_version, :string, constraints: [max_length: 120]

    attribute :state, :atom,
      default: :draft,
      allow_nil?: false,
      constraints: [one_of: [:draft, :approved, :superseded, :withdrawn]]

    attribute :approval_id, :uuid
    attribute :allocation_approval_id, :uuid
    attribute :disclosure_en_id, :uuid
    attribute :disclosure_af_id, :uuid
    attribute :withdrawal_id, :uuid
    attribute :approved_at, AshPostgres.TimestamptzUsec
    attribute :expires_at, AshPostgres.TimestamptzUsec
    create_timestamp :created_at
  end

  identities do
    identity :price_version, [:price_version]
  end
end
