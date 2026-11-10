defmodule NewYou.Identity.Token do
  @moduledoc """
  Identity's existing AshAuthentication proof and session-token authority.

  Magic-login issuance stores fixed claim metadata, never the signed bearer.
  A current magic-login purpose may become consumed, superseded or revoked;
  transient delivery signing cannot change that state or its original expiry.

  Consumed password-reset rows retain their fixed non-bearer claims and confirmation
  ID as immutable outcome receipts. Expired cleanup preserves those receipts, while
  consumption clears the credential-derived binding. They cannot authorize another
  reset, delivery or Session.
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

    identity_wheres_to_sql one_current_magic_login: "purpose = 'magic_login'",
                           one_current_password_reset: "purpose = 'password_reset'"

    check_constraints do
      check_constraint :recovery_case_id, "tokens_recovery_metadata",
        check:
          "(recovery_case_id IS NULL AND recovery_claims IS NULL AND purpose NOT IN ('recovery','recovery_consumed','recovery_revoked')) OR (recovery_case_id IS NOT NULL AND recovery_claims IS NOT NULL AND purpose IN ('recovery','recovery_consumed','recovery_revoked','revocation') AND COALESCE(recovery_claims->>'purpose' = 'recovery' AND recovery_claims->>'jti' = jti AND recovery_claims->>'sub' = subject AND recovery_claims->>'case_id' = recovery_case_id::text, false))"

      check_constraint :reset_request_id, "tokens_password_reset_metadata",
        check:
          "(purpose NOT IN ('password_reset', 'password_reset_superseded', 'password_reset_consumed') AND reset_request_id IS NULL AND reset_claims IS NULL AND reset_account_binding IS NULL AND reset_locale IS NULL AND reset_consumption_id IS NULL) OR (reset_request_id IS NOT NULL AND reset_claims IS NOT NULL AND reset_locale IS NOT NULL AND reset_locale IN ('en', 'af') AND ((purpose = 'password_reset_consumed' AND reset_consumption_id IS NOT NULL AND reset_account_binding IS NULL) OR (purpose <> 'password_reset_consumed' AND reset_consumption_id IS NULL AND reset_account_binding IS NOT NULL)))"

      check_constraint :magic_request_id, "tokens_magic_login_metadata",
        check:
          "(purpose NOT IN ('magic_login', 'magic_login_superseded', 'magic_login_consumed') AND magic_request_id IS NULL AND magic_claims IS NULL AND magic_account_binding IS NULL AND magic_locale IS NULL) OR (magic_request_id IS NOT NULL AND magic_claims IS NOT NULL AND magic_account_binding IS NOT NULL AND magic_locale IS NOT NULL AND magic_locale IN ('en', 'af'))"
    end
  end

  actions do
    create :issue_recovery do
      public? false
      accept [:recovery_case_id, :recovery_claims]
      argument :token, :string, allow_nil?: false, sensitive?: true
      validate present([:recovery_case_id, :recovery_claims])
      change set_attribute(:purpose, "recovery")
      change AshAuthentication.TokenResource.StoreTokenChange
      change NewYou.Identity.Changes.SetTokenAccount
    end

    update :consume_recovery do
      public? false
      accept []
      change filter(expr(purpose == "recovery" and expires_at > now()))
      change set_attribute(:purpose, "recovery_consumed")
    end

    update :revoke_recovery do
      public? false
      accept []
      change filter(expr(purpose in ["recovery", "recovery_consumed"]))
      change set_attribute(:purpose, "recovery_revoked")
    end

    create :issue_password_reset do
      description "Create one new password-reset proof. Never upsert or reissue an existing JTI."
      public? false
      accept [:reset_request_id, :reset_claims, :reset_account_binding, :reset_locale]
      argument :token, :string, allow_nil?: false, sensitive?: true
      validate present([:reset_request_id, :reset_claims, :reset_account_binding, :reset_locale])
      change set_attribute(:purpose, "password_reset")
      change AshAuthentication.TokenResource.StoreTokenChange
      change NewYou.Identity.Changes.SetTokenAccount
    end

    update :supersede_password_reset do
      public? false
      accept []
      change filter(expr(purpose == "password_reset"))
      change set_attribute(:purpose, "password_reset_superseded")
    end

    update :consume_password_reset do
      public? false
      accept [:reset_consumption_id]
      validate present(:reset_consumption_id)
      change filter(expr(purpose == "password_reset" and expires_at > now()))
      change set_attribute(:purpose, "password_reset_consumed")
      change set_attribute(:reset_account_binding, nil)
    end

    update :revoke_authentication do
      description "Invalidate one linked authentication token without revoking independent proof purposes."
      public? false
      accept []
      change filter(expr(purpose == "user"))
      change set_attribute(:purpose, "revocation")
    end

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

      filter expr(
               expires_at < now() and is_nil(recovery_case_id) and
                 purpose != "password_reset_consumed"
             )

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

      change filter(
               expr(
                 expires_at < now() and is_nil(recovery_case_id) and
                   purpose != "password_reset_consumed"
               )
             )
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
    attribute :recovery_case_id, :uuid, sensitive?: true, public?: false
    attribute :recovery_claims, :map, sensitive?: true, public?: false
    attribute :reset_request_id, :uuid, sensitive?: true, public?: false
    attribute :reset_claims, :map, sensitive?: true, public?: false
    attribute :reset_account_binding, :binary, sensitive?: true, public?: false
    attribute :reset_locale, :string, constraints: [match: ~r/\A(en|af)\z/], public?: false

    attribute :reset_consumption_id, :uuid, sensitive?: true, public?: false

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
    belongs_to :recovery_case, NewYou.Identity.RecoveryCase do
      define_attribute? false
      source_attribute :recovery_case_id
      public? false
    end

    belongs_to :account, NewYou.Identity.Account do
      allow_nil? false
      attribute_writable? false
      public? false
    end
  end

  identities do
    identity :recovery_case_proof, [:recovery_case_id]
    identity :one_current_password_reset, [:account_id], where: expr(purpose == "password_reset")
    identity :password_reset_request, [:reset_request_id]
    identity :password_reset_consumption, [:reset_consumption_id]
    identity :one_current_magic_login, [:account_id], where: expr(purpose == "magic_login")
    identity :magic_login_request, [:magic_request_id]
  end
end
