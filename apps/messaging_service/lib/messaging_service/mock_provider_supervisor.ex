defmodule MessagingService.MockProviderSupervisor do
  @moduledoc """
  Supervisor for mock provider servers.

  This supervisor starts and manages multiple mock provider servers
  that simulate different messaging services like Twilio, SendGrid, etc.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Returns the failure rate from application config, defaulting to 0.0 if not set.

  """
  def failure_rate do
    Application.get_env(:messaging_service, MessagingService.MockProviderServer, [])
    |> Keyword.get(:failure_rate, 0.0)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Twilio mock server
      %{
        id: :twilio_server,
        start:
          {MessagingService.MockProviderServer, :start_link,
           [
             [
               name: :twilio_server,
               provider_type: :twilio,
               failure_rate: failure_rate(),
               delay_range: {10, 50},
               config: %{
                 account_sid: "ACtest12345678901234567890",
                 auth_token: "test_token_12345"
               }
             ]
           ]},
        restart: :permanent,
        type: :worker
      },

      # SendGrid mock server
      %{
        id: :sendgrid_server,
        start:
          {MessagingService.MockProviderServer, :start_link,
           [
             [
               name: :sendgrid_server,
               provider_type: :sendgrid,
               failure_rate: failure_rate(),
               delay_range: {10, 50},
               config: %{
                 api_key: "SG.test_key_12345"
               }
             ]
           ]},
        restart: :permanent,
        type: :worker
      },

      # Generic mock server
      %{
        id: :generic_server,
        start:
          {MessagingService.MockProviderServer, :start_link,
           [
             [
               name: :generic_server,
               provider_type: :generic,
               failure_rate: failure_rate(),
               delay_range: {10, 50},
               config: %{}
             ]
           ]},
        restart: :permanent,
        type: :worker
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
