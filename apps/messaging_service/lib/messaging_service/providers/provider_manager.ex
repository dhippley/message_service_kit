defmodule MessagingService.Providers.ProviderManager do
  @moduledoc """
  Provider manager for handling provider selection and configuration.

  This module provides a centralized way to manage messaging providers,
  including configuration, provider selection, and message sending coordination.
  """

  alias MessagingService.Providers.{TwilioProvider, SendGridProvider}
  require Logger

  @type provider_name :: :twilio | :sendgrid | :mock
  @type provider_config :: %{
          provider: provider_name(),
          config: map(),
          enabled: boolean()
        }

  @providers %{
    twilio: TwilioProvider,
    sendgrid: SendGridProvider
  }

  @doc """
  Sends a message using the appropriate provider based on message type and configuration.

  ## Parameters
  - `message` - The message to send
  - `provider_configs` - Map of provider configurations

  ## Returns
  - `{:ok, message_id, provider_name}` - Message sent successfully
  - `{:error, reason}` - Failed to send message
  """
  def send_message(message, provider_configs) do
    with {:ok, provider_name} <- select_provider(message, provider_configs),
         {:ok, provider_module} <- get_provider_module(provider_name),
         {:ok, config} <- get_provider_config(provider_name, provider_configs),
         {:ok, message_id} <- provider_module.send_message(message, config) do
      Logger.info("Message sent via #{provider_name}: #{message_id}")
      {:ok, message_id, provider_name}
    else
      {:error, reason} = error ->
        Logger.error("Failed to send message: #{reason}")
        error
    end
  end

  @doc """
  Gets the status of a message from the appropriate provider.

  ## Parameters
  - `message_id` - The message ID to check
  - `provider_name` - The provider that sent the message
  - `provider_configs` - Map of provider configurations

  ## Returns
  - `{:ok, status}` - Message status retrieved
  - `{:error, reason}` - Failed to get status
  """
  def get_message_status(message_id, provider_name, provider_configs) do
    with {:ok, provider_module} <- get_provider_module(provider_name),
         {:ok, config} <- get_provider_config(provider_name, provider_configs) do
      provider_module.get_message_status(message_id, config)
    end
  end

  @doc """
  Validates provider configurations.

  ## Parameters
  - `provider_configs` - Map of provider configurations

  ## Returns
  - `:ok` - All configurations are valid
  - `{:error, errors}` - Configuration errors
  """
  def validate_configurations(provider_configs) do
    errors =
      provider_configs
      |> Enum.reduce([], fn {provider_name, config}, acc ->
        case validate_provider_configuration(provider_name, config) do
          :ok -> acc
          {:error, reason} -> [{provider_name, reason} | acc]
        end
      end)

    if errors == [] do
      :ok
    else
      {:error, errors}
    end
  end

  @doc """
  Lists all available providers and their supported message types.

  ## Returns
  - Map of provider information
  """
  def list_providers do
    @providers
    |> Enum.map(fn {name, module} ->
      {name, %{
        module: module,
        name: module.provider_name(),
        supported_types: module.supported_types()
      }}
    end)
    |> Map.new()
  end

  @doc """
  Validates a message request against a specific provider.

  ## Parameters
  - `message` - The message to validate
  - `provider_name` - The provider to validate against

  ## Returns
  - `:ok` - Message is valid for the provider
  - `{:error, reason}` - Message is invalid
  """
  def validate_message_for_provider(message, provider_name) do
    with {:ok, provider_module} <- get_provider_module(provider_name) do
      cond do
        message.type not in provider_module.supported_types() ->
          {:error, "Provider #{provider_name} does not support #{message.type} messages"}

        true ->
          provider_module.validate_recipient(message.to, message.type)
      end
    end
  end

  # Private functions

  defp select_provider(message, provider_configs) do
    # Find providers that support the message type and are enabled
    suitable_providers =
      provider_configs
      |> Enum.filter(fn {provider_name, config} ->
        config[:enabled] == true and
          provider_supports_type?(provider_name, message.type)
      end)

    case suitable_providers do
      [] ->
        {:error, "No suitable provider found for #{message.type} messages"}

      [{provider_name, _config}] ->
        {:ok, provider_name}

      multiple_providers ->
        # Use priority-based selection
        selected_provider = select_by_priority(multiple_providers, message.type)
        {:ok, selected_provider}
    end
  end

  defp provider_supports_type?(provider_name, message_type) do
    case get_provider_module(provider_name) do
      {:ok, module} -> message_type in module.supported_types()
      {:error, _} -> false
    end
  end

  defp select_by_priority(providers, message_type) do
    # Priority order: specific providers first, then mock
    priority_order = case message_type do
      :sms -> [:twilio, :mock]
      :mms -> [:twilio, :mock]
      :email -> [:sendgrid, :mock]
    end

    provider_names = Enum.map(providers, fn {name, _config} -> name end)

    selected =
      priority_order
      |> Enum.find(fn provider -> provider in provider_names end)

    selected || hd(provider_names)
  end

  defp get_provider_module(provider_name) do
    case Map.get(@providers, provider_name) do
      nil -> {:error, "Unknown provider: #{provider_name}"}
      module -> {:ok, module}
    end
  end

  defp get_provider_config(provider_name, provider_configs) do
    case Map.get(provider_configs, provider_name) do
      nil -> {:error, "No configuration found for provider: #{provider_name}"}
      config -> {:ok, config[:config] || config}
    end
  end

  defp validate_provider_configuration(provider_name, config) do
    with {:ok, provider_module} <- get_provider_module(provider_name) do
      provider_config = config[:config] || config
      provider_module.validate_config(provider_config)
    end
  end

  @doc """
  Creates default provider configurations for different environments.

  ## Parameters
  - `env` - Environment (:dev, :test, :prod)

  ## Returns
  - Map of default provider configurations
  """
  def default_configurations(env \\ :dev) do
    case env do
      :test ->
        %{
          mock: %{
            provider: :mock,
            config: %{provider_name: :generic},
            enabled: true
          }
        }

      :dev ->
        %{
          twilio: %{
            provider: :twilio,
            config: %{
              account_sid: System.get_env("TWILIO_ACCOUNT_SID", "AC_test_sid"),
              auth_token: System.get_env("TWILIO_AUTH_TOKEN", "test_token_123456789012345678901234"),
              from_number: System.get_env("TWILIO_FROM_NUMBER", "+15551234567")
            },
            enabled: false
          },
          sendgrid: %{
            provider: :sendgrid,
            config: %{
              api_key: System.get_env("SENDGRID_API_KEY", "SG.test_key"),
              from_email: System.get_env("SENDGRID_FROM_EMAIL", "test@example.com"),
              from_name: System.get_env("SENDGRID_FROM_NAME", "Test Service")
            },
            enabled: false
          },
          mock: %{
            provider: :mock,
            config: %{provider_name: :generic},
            enabled: true
          }
        }

      :prod ->
        %{
          twilio: %{
            provider: :twilio,
            config: %{
              account_sid: System.fetch_env!("TWILIO_ACCOUNT_SID"),
              auth_token: System.fetch_env!("TWILIO_AUTH_TOKEN"),
              from_number: System.fetch_env!("TWILIO_FROM_NUMBER")
            },
            enabled: true
          },
          sendgrid: %{
            provider: :sendgrid,
            config: %{
              api_key: System.fetch_env!("SENDGRID_API_KEY"),
              from_email: System.fetch_env!("SENDGRID_FROM_EMAIL"),
              from_name: System.fetch_env!("SENDGRID_FROM_NAME")
            },
            enabled: true
          }
        }
    end
  end
end
