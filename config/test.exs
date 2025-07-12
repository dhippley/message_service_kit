import Config

# Print only warnings and errors during test
config :logger, level: :warning

# In test we don't send emails
config :messaging_service, MessagingService.Mailer, adapter: Swoosh.Adapters.Test

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :messaging_service, MessagingService.Repo,
  username: "messaging_user",
  password: "messaging_password",
  hostname: "localhost",
  database: "messaging_service_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :messaging_service, MessagingServiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "z49t8pFuU3DCRpj4Y9BeKVy8b/i5Yy9/bPh0BbBUudoSJxt2RUqp4ilvnS05P05g",
  server: true

# Set environment
config :messaging_service, :env, :test

# Configure the environment for provider manager
config :messaging_service, :environment, :test

# Configure messaging providers for test
config :messaging_service, :provider_configs,
  mock: %{
    provider: :mock,
    config: %{provider_name: :generic},
    enabled: true
  }

# Configure webhook authentication for test
config :messaging_service, :webhook_auth,
  bearer_tokens: [
    "dev-bearer-token-123",
    "webhook-test-token-456"
  ],
  api_keys: [
    "dev-api-key-123",
    "webhook-dev-key-456"
  ],
  basic_auth: [
    {"webhook_user", "dev_password_123"},
    {"dev_webhook", "secret_dev_key"}
  ]

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false
