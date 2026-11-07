defmodule NewYou.Communications.ProtectedEnvelope do
  @moduledoc false
  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Communications,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "communications_protected_envelopes"
    repo NewYou.Repo

    references do
      reference :message_intent, on_delete: :delete
    end

    check_constraints do
      check_constraint :nonce, "communications_envelope_nonce_length",
        check: "octet_length(nonce) = 12",
        message: "is invalid"

      check_constraint :tag, "communications_envelope_tag_length",
        check: "octet_length(tag) = 16",
        message: "is invalid"

      check_constraint :source_reference, "communications_envelope_source_reference",
        check: "source_reference ~ '^[0-9a-v]{24}$'",
        message: "is invalid"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    destroy :clear do
      public? false
    end

    create :store do
      public? false

      accept [
        :message_intent_id,
        :source_reference,
        :purpose,
        :key_version,
        :nonce,
        :ciphertext,
        :tag
      ]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    attribute :source_reference, :string,
      allow_nil?: false,
      sensitive?: true,
      constraints: [match: ~r/\A[0-9a-v]{24}\z/],
      public?: false

    attribute :purpose, :string, allow_nil?: false, public?: false
    attribute :key_version, :string, allow_nil?: false, public?: false
    attribute :nonce, :binary, allow_nil?: false, sensitive?: true, public?: false
    attribute :ciphertext, :binary, allow_nil?: false, sensitive?: true, public?: false
    attribute :tag, :binary, allow_nil?: false, sensitive?: true, public?: false
  end

  relationships do
    belongs_to :message_intent, NewYou.Communications.MessageIntent do
      allow_nil? false
      primary_key? true
      public? false
    end
  end

  identities do
    identity :unique_nonce, [:nonce]
  end
end
