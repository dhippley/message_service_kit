defmodule MockProvider.Application do
  @moduledoc """
  OTP Application for MockProvider.
  
  Starts a simple HTTP server that mocks external messaging providers
  like Twilio (SMS/MMS) and SendGrid (Email).
  """

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    port = 4001

    children = [
      {Plug.Cowboy, scheme: :http, plug: MockProvider.Router, options: [port: port]}
    ]

    Logger.info("Starting MockProvider on port #{port}")

    opts = [strategy: :one_for_one, name: MockProvider.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
