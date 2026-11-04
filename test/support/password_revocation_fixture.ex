defmodule NewYou.Security.PasswordRevocationTest do
  @moduledoc false
  # Disposable ETS fixtures exercise the package hook without adding production
  # password-change actions, database tables, or session features.
  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource NewYou.Security.PasswordRevocationTest.User
      resource NewYou.Security.PasswordRevocationTest.Token
    end
  end

  defmodule Token do
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshAuthentication.TokenResource],
      authorizers: [Ash.Policy.Authorizer]

    actions do
      defaults [:read]
    end

    token do
      domain Domain
    end

    policies do
      bypass AshAuthentication.Checks.AshAuthenticationInteraction do
        authorize_if always()
      end
    end
  end

  defmodule User do
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshAuthentication]

    attributes do
      uuid_primary_key :id
      attribute :email, :string, allow_nil?: false, public?: true
      attribute :hashed_password, :string, sensitive?: true
    end

    identities do
      identity :email, [:email], pre_check_with: Domain
    end

    authentication do
      tokens do
        enabled? true
        store_all_tokens? true
        require_token_presence_for_authentication? true
        token_resource Token
        signing_secret fn _, _ -> {:ok, String.duplicate("fixture-secret", 4)} end
      end

      strategies do
        password do
          identity_field :email
          hashed_password_field :hashed_password
          hash_provider AshAuthentication.Argon2Provider
          registration_enabled? false
          sign_in_enabled? false
          sign_in_tokens_enabled? false
        end
      end

      add_ons do
        log_out_everywhere do
          apply_on_password_change? true
        end
      end
    end

    actions do
      defaults [:read]

      create :create do
        accept [:email]
        argument :password, :string, allow_nil?: false, sensitive?: true
        change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
      end

      update :change_password do
        require_atomic? false
        accept []
        argument :password, :string, allow_nil?: false, sensitive?: true
        change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
      end

      update :change_email do
        require_atomic? false
        accept [:email]
      end
    end
  end
end
