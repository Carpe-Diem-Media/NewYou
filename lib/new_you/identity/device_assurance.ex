defmodule NewYou.Identity.DeviceAssurance do
  @moduledoc """
  Identity-owned device trust records subject to Account-wide reset revocation.

  This bounded slice implements read and terminal revocation only. It exposes no
  enrolment, trust grant or device authentication interface. Any future grant must
  enforce consent, authenticated current Account security version and expiry under
  the same Account lock as reset. Device trust never supplies elevated assurance.
  """
  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Identity,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "device_assurances"
    repo NewYou.Repo

    check_constraints do
      check_constraint :state, "device_assurances_state",
        check: "state IN ('pending', 'trusted', 'expired', 'revoked')"

      check_constraint :revoked_at, "device_assurances_revocation",
        check:
          "(state = 'revoked' AND revoked_at IS NOT NULL) OR (state <> 'revoked' AND revoked_at IS NULL)"
    end
  end

  actions do
    read :read do
      primary? true
      public? false
    end

    update :revoke do
      description "Terminate current device trust inside an Account-locked security transaction. Revocation cannot restore trust."
      public? false
      accept []
      change filter(expr(state == :trusted))
      change set_attribute(:state, :revoked)
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :fingerprint, :binary, allow_nil?: false, sensitive?: true, public?: false

    attribute :state, :atom,
      allow_nil?: false,
      default: :pending,
      constraints: [one_of: [:pending, :trusted, :expired, :revoked]],
      public?: false

    attribute :security_version, :integer,
      allow_nil?: false,
      constraints: [min: 1],
      public?: false

    attribute :expires_at, :utc_datetime_usec, allow_nil?: false, public?: false
    attribute :revoked_at, :utc_datetime_usec, public?: false
    create_timestamp :created_at
  end

  relationships do
    belongs_to :account, NewYou.Identity.Account do
      allow_nil? false
      public? false
    end
  end
end
