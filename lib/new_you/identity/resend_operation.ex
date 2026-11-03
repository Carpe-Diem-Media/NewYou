defmodule NewYou.Identity.ResendOperation do
  @moduledoc """
  Durable Identity-owned terminal binding for every valid resend request.

  The operation ID and keyed request fingerprint are recorded for accepted and
  neutral outcomes. Email input is never stored. Accepted rows commit with challenge
  replacement, MessageIntent and protected envelope creation. Rows have no expiry so
  later Account or Token changes cannot make an operation ID reusable. This resource
  does not own verification-challenge or Communications state.
  """

  use Ash.Resource, otp_app: :new_you, domain: NewYou.Identity, data_layer: AshPostgres.DataLayer

  postgres do
    table "resend_operations"
    repo NewYou.Repo

    check_constraints do
      check_constraint :request_fingerprint, "resend_operations_binding_complete",
        check:
          "octet_length(request_fingerprint) = 32 AND fingerprint_key_version IS NOT NULL AND fingerprint_key_version <> ''",
        message: "must retain a valid keyed request binding"

      check_constraint :outcome, "resend_operations_terminal_outcome",
        check:
          "(outcome = 'accepted' AND account_id IS NOT NULL AND accepted_at IS NOT NULL) OR (outcome = 'neutral' AND account_id IS NULL AND accepted_at IS NULL)",
        message: "must retain one immutable accepted or neutral outcome"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :accept do
      accept [
        :operation_id,
        :account_id,
        :accepted_at,
        :request_fingerprint,
        :fingerprint_key_version,
        :outcome
      ]

      public? false
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :operation_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :account_id, :uuid do
      allow_nil? true
      public? false
    end

    attribute :accepted_at, AshPostgres.TimestamptzUsec do
      allow_nil? true
      public? false
    end

    attribute :request_fingerprint, :binary do
      allow_nil? false
      sensitive? true
      public? false
    end

    attribute :fingerprint_key_version, :string do
      allow_nil? false
      sensitive? true
      public? false
    end

    attribute :outcome, :atom do
      allow_nil? false
      constraints one_of: [:accepted, :neutral]
      public? false
    end
  end

  identities do
    identity :opaque_operation_id, [:operation_id], message: "has already been used"
  end
end
