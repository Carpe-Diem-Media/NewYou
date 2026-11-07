defmodule NewYou.Identity.Token do
  @moduledoc """
  Identity's existing AshAuthentication proof and session-token authority.

  Magic-login issuance stores fixed claim metadata, never the signed bearer.
  A current magic-login purpose may become consumed, superseded or revoked;
  transient delivery signing cannot change that state or its original expiry.
  """
  use Ash.Resource,
    otp_app: :new_you,
    domain: NewYou.Identity,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication.TokenResource]

  token do
    domain NewYou.Identity
  end

  postgres do
    table "tokens"
    repo NewYou.Repo
    identity_wheres_to_sql one_current_magic_login: "purpose = 'magic_login'"

    check_constraints do
      check_constraint :magic_request_id, "tokens_magic_login_metadata",
        check:
          "(purpose NOT IN ('magic_login', 'magic_login_superseded', 'magic_login_consumed') AND magic_request_id IS NULL AND magic_claims IS NULL AND magic_account_binding IS NULL AND magic_locale IS NULL) OR (magic_request_id IS NOT NULL AND magic_claims IS NOT NULL AND magic_account_binding IS NOT NULL AND magic_locale IS NOT NULL AND magic_locale IN ('en', 'af'))"
    end
  end

  actions do
    create :issue_magic_login do
      description "Create one new magic-login proof. Never upsert or reissue an existing JTI."
      public? false
      accept [:magic_request_id, :magic_claims, :magic_account_binding, :magic_locale]
      argument :token, :string, allow_nil?: false, sensitive?: true
      validate present([:magic_request_id, :magic_claims, :magic_account_binding, :magic_locale])
      change set_attribute(:purpose, "magic_login")
      change AshAuthentication.TokenResource.StoreTokenChange
      change NewYou.Identity.Changes.SetTokenAccount
    end

    update :supersede_magic_login do
      public? false
      accept []
      change filter(expr(purpose == "magic_login"))
      change set_attribute(:purpose, "magic_login_superseded")
    end

    update :consume_magic_login do
      public? false
      accept []
      change filter(expr(purpose == "magic_login" and expires_at > now()))
      change set_attribute(:purpose, "magic_login_consumed")
    end

    read :read do
      primary? true
      public? false
    end

    read :expired do
      description "Look up expired Identity tokens for framework cleanup"
      filter expr(expires_at < now())
      public? false
    end

    read :get_token do
      description "Look up a token by JTI or bearer and optional purpose"
      get? true
      argument :token, :string, sensitive?: true
      argument :jti, :string, sensitive?: true
      argument :purpose, :string
      public? false
      prepare AshAuthentication.TokenResource.GetTokenPreparation
    end

    action :revoked?, :boolean do
      argument :token, :string, sensitive?: true
      argument :jti, :string, sensitive?: true
      public? false
      run AshAuthentication.TokenResource.IsRevoked
    end

    create :revoke_token do
      accept [:extra_data]
      argument :token, :string, allow_nil?: false, sensitive?: true
      public? false
      change AshAuthentication.TokenResource.RevokeTokenChange
      change NewYou.Identity.Changes.SetTokenAccount
    end

    create :revoke_jti do
      accept [:extra_data]
      argument :subject, :string, allow_nil?: false, sensitive?: true
      argument :jti, :string, allow_nil?: false, sensitive?: true
      public? false
      change AshAuthentication.TokenResource.RevokeJtiChange
      change NewYou.Identity.Changes.SetTokenAccount
    end

    create :store_token do
      accept [:extra_data, :purpose]
      argument :token, :string, allow_nil?: false, sensitive?: true
      public? false
      change AshAuthentication.TokenResource.StoreTokenChange
      change NewYou.Identity.Changes.SetTokenAccount
    end

    destroy :expunge_expired do
      public? false
      change filter(expr(expires_at < now()))
    end

    update :revoke_all_stored_for_subject do
      accept [:extra_data]
      argument :subject, :string, allow_nil?: false, sensitive?: true
      public? false
      change AshAuthentication.TokenResource.RevokeAllStoredForSubjectChange
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end
  end

  attributes do
    attribute :magic_request_id, :uuid, sensitive?: true, public?: false
    attribute :magic_claims, :map, sensitive?: true, public?: false
    attribute :magic_account_binding, :binary, sensitive?: true, public?: false
    attribute :magic_locale, :string, constraints: [match: ~r/\A(en|af)\z/], public?: false

    attribute :jti, :string do
      primary_key? true
      allow_nil? false
      sensitive? true
      public? true
    end

    attribute :subject, :string do
      allow_nil? false
      sensitive? true
      public? false
    end

    attribute :expires_at, :utc_datetime do
      allow_nil? false
      public? false
    end

    attribute :purpose, :string do
      allow_nil? false
      public? true
    end

    attribute :extra_data, :map do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :account, NewYou.Identity.Account do
      allow_nil? false
      attribute_writable? false
      public? false
    end
  end

  identities do
    identity :one_current_magic_login, [:account_id], where: expr(purpose == "magic_login")
    identity :magic_login_request, [:magic_request_id]
  end
end
