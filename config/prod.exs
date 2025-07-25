import Config

# Do not print debug messages in production
config :logger, level: :info

# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix assets.deploy` task,
# which you should run after static files are built and
# before starting your production server.
config :messaging_service, MessagingServiceWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

# Configure Oban for production
config :messaging_service, Oban,
  repo: MessagingService.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       # Add any cron jobs here
       # {"0 2 * * *", MyApp.DailyWorker}
     ]}
  ],
  queues: [default: 10, messaging: 25, mailers: 20, events: 50, media: 10]

# Configure webhook authentication for production
# Use environment variables for security
config :messaging_service, :webhook_auth,
  # Runtime production configuration, including reading
  # of environment variables, is done on config/runtime.exs.
  bearer_tokens: "WEBHOOK_BEARER_TOKENS" |> System.get_env("") |> String.split(",") |> Enum.reject(&(&1 == "")),
  api_keys: "WEBHOOK_API_KEYS" |> System.get_env("") |> String.split(",") |> Enum.reject(&(&1 == "")),
  basic_auth:
    Enum.reject(
      [
        {System.get_env("WEBHOOK_USERNAME"), System.get_env("WEBHOOK_PASSWORD")}
      ],
      fn {u, p} -> is_nil(u) or is_nil(p) end
    )

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: MessagingService.Finch

# Disable Swoosh Local Memory Storage
config :swoosh, local: false
