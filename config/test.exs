import Config

config :new_you, :verification_development_fixtures, true

config :new_you, Oban, testing: :manual
config :new_you, :platform_name, "Test Platform"

config :new_you, :identity_registration_legal_versions, %{
  terms_version_id: "NEWYOU-TERMS-EN-DEV-2026-10-27-001",
  privacy_version_id: "NEWYOU-PRIVACY-EN-DEV-2026-10-27-001"
}

config :new_you, :identity_registration_expiry_enabled, false

config :ash,
  policies: [show_policy_breakdowns?: true],
  keyset_signing_secret: "X6qc21Qe1JMpA11OGt/0A+9HNSNalkN9Eb6Jgo4/LZU",
  disable_async?: true

# TEST never uses DEV credentials or DATABASE_URL. See runtime.exs.
config :new_you, NewYou.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  show_sensitive_data_on_connection_error: false,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :new_you, NewYouWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4220],
  secret_key_base: "gp91NQKTdP6ZgafYZWkur9iAb9nzEszkpLY5w2alrJJbt3JlkYoD60St1jU4NMAM",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
