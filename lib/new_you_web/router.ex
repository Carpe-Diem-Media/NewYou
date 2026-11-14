defmodule NewYouWeb.Router do
  use NewYouWeb, :router

  # sobelow_skip ["Config.CSP"]
  # Reviewed suppression (WELL-4): the root layout carries an intentional inline
  # theme-bootstrap <script>, which a strict Content-Security-Policy would block.
  # Remove this skip when that script moves to a bundled asset and a CSP is added;
  # the follow-up is tracked in Plane, not in this comment.
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NewYouWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", NewYouWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/register", RegistrationController, :new
    post "/register", RegistrationController, :create, log: false
    post "/verification/resend", RegistrationController, :resend, log: false
    get "/verification/confirm", EmailVerificationController, :show, log: false
    post "/verification/confirm", EmailVerificationController, :confirm, log: false
    get "/primary-email-change/confirm", PrimaryEmailChangeController, :show, log: false
    post "/primary-email-change/confirm", PrimaryEmailChangeController, :confirm, log: false
    get "/recovery", RecoveryController, :new, log: false
    get "/recovery/confirm", RecoveryController, :show, log: false
    post "/recovery", RecoveryController, :request, log: false
    post "/recovery/confirm", RecoveryController, :confirm, log: false
    post "/recovery/complete", RecoveryController, :complete, log: false
    post "/recovery/cancel", RecoveryController, :cancel, log: false
    get "/password/reset", PasswordResetController, :new, log: false
    post "/password/reset", PasswordResetController, :request, log: false
    get "/password/reset/confirm", PasswordResetController, :show, log: false
    post "/password/reset/confirm", PasswordResetController, :confirm, log: false
    get "/login/magic", MagicLoginController, :new, log: false
    post "/login/magic", MagicLoginController, :request, log: false
    get "/login/magic/confirm", MagicLoginController, :show, log: false
    post "/login/magic/confirm", MagicLoginController, :confirm, log: false
    get "/legal/terms", RegistrationController, :terms
    get "/legal/privacy", RegistrationController, :privacy
  end

  # The design reference is a development tool, never a production route.
  if Mix.env() in [:dev, :test] do
    scope "/dev", NewYouWeb do
      pipe_through :browser

      live "/design-system", DesignSystemLive, :index
      live "/design-system/preview", DesignSystemLive, :preview
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", NewYouWeb do
  #   pipe_through :api
  # end
end
