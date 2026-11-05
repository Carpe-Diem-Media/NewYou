defmodule NewYou.Identity.Token do
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
  end

  actions do
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
end
