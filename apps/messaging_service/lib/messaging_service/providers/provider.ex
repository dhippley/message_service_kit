defmodule MessagingService.Provider do
  @moduledoc """
  Behavior for messaging service providers.

  This module defines the contract that all messaging providers must implement
  to send messages through different channels (SMS, MMS, Email).
  """

  @type message_type :: :sms | :mms | :email
  @type recipient :: String.t()
  @type message_content :: String.t()
  @type attachment :: %{
          filename: String.t(),
          content_type: String.t(),
          data: binary()
        }

  @type message_request :: %{
          type: message_type(),
          to: recipient(),
          from: recipient(),
          body: message_content(),
          attachments: [attachment()] | nil
        }

  @type send_result :: {:ok, message_id :: String.t()} | {:error, reason :: String.t()}
  @type validation_result :: :ok | {:error, reason :: String.t()}

  @doc """
  Sends a message through the provider.

  ## Parameters
  - `message` - The message to send
  - `config` - Provider-specific configuration

  ## Returns
  - `{:ok, message_id}` - Message sent successfully
  - `{:error, reason}` - Failed to send message
  """
  @callback send_message(message_request(), config :: map()) :: send_result()

  @doc """
  Validates a recipient address/phone number for the provider.

  ## Parameters
  - `recipient` - The recipient to validate
  - `type` - The message type (:sms, :mms, :email)

  ## Returns
  - `:ok` - Recipient is valid
  - `{:error, reason}` - Recipient is invalid
  """
  @callback validate_recipient(recipient(), message_type()) :: validation_result()

  @doc """
  Validates the provider configuration.

  ## Parameters
  - `config` - Provider-specific configuration

  ## Returns
  - `:ok` - Configuration is valid
  - `{:error, reason}` - Configuration is invalid
  """
  @callback validate_config(config :: map()) :: validation_result()

  @doc """
  Returns the supported message types for this provider.

  ## Returns
  - List of supported message types
  """
  @callback supported_types() :: [message_type()]

  @doc """
  Returns the provider name as a string.

  ## Returns
  - Provider name
  """
  @callback provider_name() :: String.t()

  @doc """
  Gets the status of a previously sent message.

  ## Parameters
  - `message_id` - The ID of the message to check
  - `config` - Provider-specific configuration

  ## Returns
  - `{:ok, status}` - Message status retrieved
  - `{:error, reason}` - Failed to get status
  """
  @callback get_message_status(message_id :: String.t(), config :: map()) ::
              {:ok, status :: String.t()} | {:error, reason :: String.t()}

  @optional_callbacks get_message_status: 2

  # Helper functions for common validations

  @doc """
  Validates a phone number format for SMS/MMS.
  """
  @spec validate_phone_number(String.t()) :: validation_result()
  def validate_phone_number(phone) when is_binary(phone) do
    # More lenient phone number validation - allow various formats
    cleaned = String.replace(phone, ~r/\s|-|\(|\)/, "")

    cond do
      # E.164 format (international)
      Regex.match?(~r/^\+[1-9]\d{1,14}$/, cleaned) -> :ok
      # US format without country code but with leading 1
      Regex.match?(~r/^1[2-9]\d{9}$/, cleaned) -> :ok
      # 10 digit US format
      Regex.match?(~r/^[2-9]\d{9}$/, cleaned) -> :ok
      true -> {:error, "Invalid phone number format. Must be in E.164 format (e.g., +1234567890)"}
    end
  end

  def validate_phone_number(_), do: {:error, "Phone number must be a string"}

  @doc """
  Validates an email address format.
  """
  @spec validate_email(String.t()) :: validation_result()
  def validate_email(email) when is_binary(email) do
    # Basic email validation
    if Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, email) do
      :ok
    else
      {:error, "Invalid email address format"}
    end
  end

  def validate_email(_), do: {:error, "Email must be a string"}

  @doc """
  Validates message content is not empty and within reasonable limits.
  """
  @spec validate_message_content(String.t()) :: validation_result()
  def validate_message_content(content) when is_binary(content) do
    content = String.trim(content)

    cond do
      content == "" -> {:error, "Message content cannot be empty"}
      String.length(content) > 1600 -> {:error, "Message content too long (max 1600 characters)"}
      true -> :ok
    end
  end

  def validate_message_content(_), do: {:error, "Message content must be a string"}

  @doc """
  Validates message request structure.
  """
  @spec validate_message_request(message_request()) :: validation_result()
  def validate_message_request(message) when is_map(message) do
    with :ok <- validate_required_fields(message),
         :ok <- validate_message_content(message.body),
         :ok <- validate_recipient_for_type(message.to, message.type) do
      validate_recipient_for_type(message.from, message.type)
    end
  end

  def validate_message_request(_), do: {:error, "Message must be a map"}

  defp validate_required_fields(message) do
    required_fields = [:type, :to, :from, :body]

    missing_fields =
      Enum.filter(required_fields, fn field -> not Map.has_key?(message, field) end)

    if missing_fields == [] do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp validate_recipient_for_type(recipient, :sms), do: validate_phone_number(recipient)
  defp validate_recipient_for_type(recipient, :mms), do: validate_phone_number(recipient)
  defp validate_recipient_for_type(recipient, :email), do: validate_email(recipient)
  defp validate_recipient_for_type(_recipient, type), do: {:error, "Unsupported message type: #{type}"}
end
