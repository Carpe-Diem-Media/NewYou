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
    assert AshAuthentication.Strategy.routes(password) == []
  end

  test "router exposes only the reviewed public and bounded registration endpoints" do
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
               {:get, "/legal/terms", NewYouWeb.RegistrationController, :terms},
               {:get, "/legal/privacy", NewYouWeb.RegistrationController, :privacy}
             ])
  end
end
