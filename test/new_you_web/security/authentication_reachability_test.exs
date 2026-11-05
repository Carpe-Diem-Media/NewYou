defmodule NewYouWeb.Security.AuthenticationReachabilityTest do
  use ExUnit.Case, async: true

  test "authentication remains password-only with no sign-in or OAuth strategy routes" do
    resources =
      :new_you
      |> Ash.Info.domains()
      |> Enum.flat_map(&Ash.Domain.Info.resources/1)
      |> Enum.filter(&(AshAuthentication in Ash.Resource.Info.extensions(&1)))

    assert resources == [NewYou.Identity.Account]

    assert [%AshAuthentication.Strategy.Password{} = password] =
             AshAuthentication.Info.authentication_strategies(NewYou.Identity.Account)

    refute password.sign_in_enabled?
    refute password.registration_enabled?
    refute password.sign_in_tokens_enabled?
    assert password.resettable == nil
    assert AshAuthentication.Info.authentication_add_ons(NewYou.Identity.Account) == []

    assert Enum.sort(
             Enum.map(Ash.Resource.Info.actions(NewYou.Identity.Account), &{&1.type, &1.name})
           ) ==
             [
               {:action, :confirm_email},
               {:create, :register},
               {:read, :get_by_subject},
               {:read, :read},
               {:update, :mark_email_verified}
             ]

    assert AshAuthentication.Strategy.routes(password) == []
  end

  test "SQL resources have no context-tenant prefix path" do
    for domain <- Ash.Info.domains(:new_you),
        resource <- Ash.Domain.Info.resources(domain),
        Ash.Resource.Info.data_layer(resource) == AshPostgres.DataLayer do
      assert Ash.Resource.Info.multitenancy_strategy(resource) == nil
      assert AshPostgres.DataLayer.Info.repo(resource, :read) == NewYou.Repo
    end
  end

  test "browser pipeline has no authenticated-session loader" do
    plugs = NewYouWeb.Router.__info__(:functions)
    assert {:browser, 2} in plugs

    conn =
      Plug.Test.conn(:get, "/")
      |> Plug.Test.init_test_session(%{})
      |> NewYouWeb.Router.call(NewYouWeb.Router.init([]))

    refute Map.has_key?(conn.assigns, :current_user)
    refute Map.has_key?(conn.assigns, :current_account)
  end

  test "router exposes only the reviewed public, registration and explicit verification endpoints" do
    routes =
      NewYouWeb.Router.__routes__()
      |> Enum.map(&{&1.verb, &1.path, &1.plug, &1.plug_opts})
      |> Enum.sort()

    assert routes ==
             Enum.sort([
               {:get, "/", NewYouWeb.PageController, :home},
               {:get, "/register", NewYouWeb.RegistrationController, :new},
               {:post, "/register", NewYouWeb.RegistrationController, :create},
               {:post, "/verification/resend", NewYouWeb.RegistrationController, :resend},
               {:get, "/verification/confirm", NewYouWeb.EmailVerificationController, :show},
               {:post, "/verification/confirm", NewYouWeb.EmailVerificationController, :confirm},
               {:get, "/legal/terms", NewYouWeb.RegistrationController, :terms},
               {:get, "/legal/privacy", NewYouWeb.RegistrationController, :privacy}
             ])
  end
end
