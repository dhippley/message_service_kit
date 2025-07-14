defmodule MessagingService.Providers.MockProvider do
  @moduledoc """
  Mock provider for testing and development.

  This provider simulates message sending without actually sending messages
  to external services. It's useful for development and testing environments.
  """

  @behaviour MessagingService.Providers.ProviderBehaviour

  require Logger

  @impl true
  def send_message(message, _config) do
    # Simulate message sending delay
    Process.sleep(100)

    # Generate a fake message ID
    message_id = "MOCK_" <> generate_message_id()

    Logger.info("Mock provider: simulated sending #{message.type} message")
    Logger.info("Mock provider: from #{message.from} to #{inspect(message.to)}")
    Logger.info("Mock provider: body: #{message.body}")

    {:ok, message_id}
  end

  @impl true
  def get_delivery_status(_message_id, _config) do
    # Mock provider always returns delivered status
    {:ok, "delivered"}
  end

  @impl true
  def validate_config(_config) do
    # Mock provider doesn't need any configuration validation
    :ok
  end

  @impl true
  def supported_message_types do
    [:sms, :mms, :email]
  end

  defp generate_message_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16()
  end
end
