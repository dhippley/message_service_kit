defmodule MessagingService.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MessagingServiceWeb.Telemetry,
      MessagingServiceWeb.TelemetryCollector,
      MessagingService.Repo,
      {DNSCluster, query: Application.get_env(:messaging_service, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MessagingService.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: MessagingService.Finch},
      # Start Oban for background job processing
      {Oban, Application.fetch_env!(:messaging_service, Oban)},
      # Start a worker by calling: MessagingService.Worker.start_link(arg)
      # {MessagingService.Worker, arg},
      # Start to serve requests, typically the last entry
      MessagingServiceWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MessagingService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MessagingServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
