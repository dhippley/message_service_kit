defmodule MessagingService.Providers.MockProvider do
  @moduledoc """
  Mock provider implementation that integrates with MockProviderServer.

  This provider allows testing of message sending without hitting real APIs.
  It uses the existing MockProviderServer for simulation.
  """

  @behaviour MessagingService.Provider

  alias MessagingService.Provider
  alias MessagingService.MockProviderServer
  require Logger

  @impl Provider
  def send_message(message, config) do
    with :ok <- validate_config(config),
         :ok <- validate_message_request(message),
         :ok <- validate_message_for_mock(message) do
      send_mock_message(message, config)
    end
  end

  @impl Provider
  def validate_recipient(recipient, type) do
    case type do
      :sms -> Provider.validate_phone_number(recipient)
      :mms -> Provider.validate_phone_number(recipient)
      :email -> Provider.validate_email(recipient)
      _ -> {:error, "Unsupported message type: #{type}"}
    end
  end

  @impl Provider
  def validate_config(config) when is_map(config) do
    # Mock provider requires minimal configuration
    required_keys = [:provider_name]

    missing_keys =
      required_keys
      |> Enum.filter(fn key -> not Map.has_key?(config, key) end)

    if missing_keys == [] do
      :ok
    else
      {:error, "Missing required configuration keys: #{Enum.join(missing_keys, ", ")}"}
    end
  end

  def validate_config(_), do: {:error, "Configuration must be a map"}

  @impl Provider
  def supported_types, do: [:sms, :mms, :email]

  @impl Provider
  def provider_name, do: "Mock"

  @impl Provider
  def get_message_status(message_id, config) do
    with :ok <- validate_config(config) do
      get_mock_message_status(message_id, config)
    end
  end

  # Private functions

  defp validate_message_request(message) do
    Provider.validate_message_request(message)
  end

  defp validate_message_for_mock(message) do
    case message.type do
      type when type in [:sms, :mms, :email] ->
        :ok

      _ ->
        {:error, "Unsupported message type: #{message.type}"}
    end
  end

  defp send_mock_message(message, config) do
    provider_name = config[:provider_name] || :generic
    server_name = get_server_name(provider_name)

    # Convert our message format to MockProviderServer format
    mock_message = %{
      to: message.to,
      from: message.from,
      body: message.body,
      type: Atom.to_string(message.type),
      attachments: message[:attachments] || []
    }

    case MockProviderServer.send_message(server_name, mock_message) do
      %{status_code: status_code, message_id: message_id} when status_code in 200..299 ->
        Logger.info("Mock message sent successfully: #{message_id}")
        {:ok, message_id}

      %{status_code: status_code, body: %{error: error}} ->
        Logger.error("Mock provider error: #{status_code} - #{error}")
        {:error, "Mock provider error: #{error}"}

      %{status_code: status_code} ->
        Logger.error("Mock provider error: #{status_code}")
        {:error, "Mock provider error: #{status_code}"}

      error ->
        Logger.error("Failed to send mock message: #{inspect(error)}")
        {:error, "Mock provider error: #{inspect(error)}"}
    end
  rescue
    error ->
      Logger.error("Error sending mock message: #{inspect(error)}")
      {:error, "Mock provider not available: #{inspect(error)}"}
  end

  defp get_mock_message_status(message_id, config) do
    provider_name = config[:provider_name] || :generic
    server_name = get_server_name(provider_name)

    case MockProviderServer.get_message_status(server_name, message_id) do
      %{status: status} ->
        {:ok, status}

      %{body: %{"status" => status}} ->
        {:ok, status}

      %{error: error} ->
        {:error, error}

      error ->
        {:error, "Failed to get status: #{inspect(error)}"}
    end
  rescue
    error ->
      Logger.error("Error getting mock message status: #{inspect(error)}")
      {:error, "Mock provider not available: #{inspect(error)}"}
  end

  defp get_server_name(provider_name) do
    case provider_name do
      :twilio -> :twilio_server
      :sendgrid -> :sendgrid_server
      :mailgun -> :mailgun_server
      _ -> :generic_server
    end
  end

  @doc """
  Starts mock provider servers for testing.
  This is a utility function for test setup.
  """
  def start_mock_servers(opts \\ []) do
    servers = [
      {:twilio, :twilio_server},
      {:sendgrid, :sendgrid_server},
      {:mailgun, :mailgun_server},
      {:generic, :generic_server}
    ]

    Enum.map(servers, fn {provider_type, server_name} ->
      server_opts = [
        name: server_name,
        provider_type: provider_type,
        failure_rate: Keyword.get(opts, :failure_rate, 0.0),
        delay_range: Keyword.get(opts, :delay_range, {10, 50})
      ]

      case MockProviderServer.start_link(server_opts) do
        {:ok, pid} ->
          {:ok, {provider_type, pid}}

        {:error, {:already_started, pid}} ->
          {:ok, {provider_type, pid}}

        error ->
          {:error, {provider_type, error}}
      end
    end)
  end

  @doc """
  Stops mock provider servers.
  This is a utility function for test cleanup.
  """
  def stop_mock_servers do
    servers = [
      :twilio_server,
      :sendgrid_server,
      :mailgun_server,
      :generic_server
    ]

    Enum.each(servers, fn server_name ->
      case Process.whereis(server_name) do
        nil -> :ok
        pid when is_pid(pid) ->
          try do
            GenServer.stop(server_name, :normal, 1000)
          catch
            :exit, _ -> :ok
          end
      end
    end)
  end
end
