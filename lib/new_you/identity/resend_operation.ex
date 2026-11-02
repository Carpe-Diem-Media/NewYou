defmodule NewYou.Identity.ResendOperation do
  @moduledoc """
  Durable Identity-owned idempotency and minimum audit record for a resend.

  Lifecycle is represented by row existence: no row means the operation has not
  been accepted; a row means it was accepted and is terminal. The row is inserted
  in the same transaction as challenge replacement, MessageIntent and protected
  envelope creation.
  It has no expiry so Token cleanup cannot make an accepted operation ID reusable.
  The Account UUID remains bound if Account or Token retention later changes. This
  resource does not own verification-challenge or Communications state.
  """

  use Ash.Resource, otp_app: :new_you, domain: NewYou.Identity, data_layer: AshPostgres.DataLayer

  postgres do
    table "resend_operations"
    repo NewYou.Repo
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    create :accept do
      accept [:operation_id, :account_id, :accepted_at]
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
      allow_nil? false
      public? false
    end

    attribute :accepted_at, AshPostgres.TimestamptzUsec do
      allow_nil? false
      public? false
    end
  end

  identities do
    identity :opaque_operation_id, [:operation_id], message: "has already been used"
  end
end
