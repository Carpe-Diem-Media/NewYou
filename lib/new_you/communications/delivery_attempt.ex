defmodule NewYou.Communications.DeliveryAttempt do
  @moduledoc """
  One durable admission for one intended provider call. Admission, invocation,
  provider observation and reconciliation remain independent facts. Only the
  Communications executor writes these fields under the parent intent lock.
  The partial unique index prevents two unresolved admissions for one intent.
  """
  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Communications,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "delivery_attempts"
    repo NewYou.Repo

    references do
      reference :message_intent, on_delete: :delete
    end

    custom_indexes do
      index [:message_intent_id],
        unique: true,
        where: "active",
        name: "delivery_attempts_one_active"
    end

    check_constraints do
      check_constraint :admission, "delivery_attempts_admission",
        check: "admission IN ('admitted', 'closed_before_invocation')"

      check_constraint :provider_observation, "delivery_attempts_observation",
        check:
          "provider_observation IN ('pending', 'rejected_before_submission', 'accepted', 'delivered', 'bounced_or_failed', 'unknown')"

      check_constraint :reconciliation, "delivery_attempts_reconciliation",
        check: "reconciliation IN ('none', 'confirmed_no_operation')"

      check_constraint :admission, "delivery_attempts_preinvoke",
        check:
          "admission <> 'closed_before_invocation' OR (invocation_started_at IS NULL AND provider_observation = 'pending' AND reconciliation = 'none' AND NOT active)"

      check_constraint :active, "delivery_attempts_active",
        check:
          "active = (admission = 'admitted' AND reconciliation = 'none' AND provider_observation IN ('pending', 'accepted', 'unknown'))"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :admit do
      public? false

      accept [
        :message_intent_id,
        :locale,
        :content_item_id,
        :content_version_id,
        :translation_version_id,
        :content_sha256,
        :render_schema,
        :render_provenance,
        :render_digest
      ]
    end

    update :record do
      public? false

      accept [
        :admission,
        :invocation_started_at,
        :provider_observation,
        :reconciliation,
        :active,
        :conflict?,
        :evidence_refs,
        :observed_at
      ]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :route, :string, allow_nil?: false, default: "bounded_deterministic_proof"

    attribute :admission, :atom,
      allow_nil?: false,
      default: :admitted,
      constraints: [one_of: [:admitted, :closed_before_invocation]]

    attribute :provider_observation, :atom,
      allow_nil?: false,
      default: :pending,
      constraints: [
        one_of: [
          :pending,
          :rejected_before_submission,
          :accepted,
          :delivered,
          :bounced_or_failed,
          :unknown
        ]
      ]

    attribute :reconciliation, :atom,
      allow_nil?: false,
      default: :none,
      constraints: [one_of: [:none, :confirmed_no_operation]]

    attribute :active, :boolean, allow_nil?: false, default: true
    attribute :conflict?, :boolean, allow_nil?: false, default: false
    attribute :invocation_started_at, AshPostgres.TimestamptzUsec
    attribute :observed_at, AshPostgres.TimestamptzUsec
    attribute :evidence_refs, {:array, :string}, allow_nil?: false, default: []
    attribute :locale, :string, allow_nil?: false
    attribute :content_item_id, :string, allow_nil?: false
    attribute :content_version_id, :string, allow_nil?: false
    attribute :translation_version_id, :string, allow_nil?: false
    attribute :content_sha256, :string, allow_nil?: false
    attribute :render_schema, :string, allow_nil?: false
    attribute :render_provenance, :string, allow_nil?: false
    attribute :render_digest, :string, allow_nil?: false
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :message_intent, NewYou.Communications.MessageIntent do
      allow_nil? false
      public? false
    end
  end
end
