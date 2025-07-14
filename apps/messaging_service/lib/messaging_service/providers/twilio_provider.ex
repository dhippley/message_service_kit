defmodule MessagingService.Providers.TwilioProvider do
  @moduledoc """
  Twilio provider implementation for SMS and MMS messaging.

  This provider handles sending SMS and MMS messages through the mock provider
  that simulates Twilio's API endpoints.
  """

  @behaviour MessagingService.Provider

  alias MessagingService.Provider

  require Logger

  @base_url "http://localhost:4001/v1"

  @impl Provider
  def send_message(message, config) do
    with :ok <- validate_config(config),
         :ok <- validate_message_request(message),
         :ok <- validate_message_for_twilio(message) do
      send_twilio_message(message, config)
    end
  end

  @impl Provider
  def validate_recipient(recipient, type) when type in [:sms, :mms] do
    Provider.validate_phone_number(recipient)
  end

  def validate_recipient(_recipient, type) do
    {:error, "Twilio provider does not support #{type} messages"}
  end

  @impl Provider
  def validate_config(config) when is_map(config) do
    required_keys = [:account_sid, :auth_token, :from_number]

    missing_keys =
      Enum.filter(required_keys, fn key -> not Map.has_key?(config, key) end)

    if missing_keys == [] do
      validate_twilio_credentials(config)
    else
      {:error, "Missing required configuration keys: #{Enum.join(missing_keys, ", ")}"}
    end
  end

  def validate_config(_), do: {:error, "Configuration must be a map"}

  @impl Provider
  def supported_types, do: [:sms, :mms]

  @impl Provider
  def provider_name, do: "Twilio"

  @impl Provider
  def get_message_status(message_id, config) do
    with :ok <- validate_config(config) do
      get_twilio_message_status(message_id, config)
    end
  end

  # Private functions

  defp validate_message_request(message) do
    Provider.validate_message_request(message)
  end

  defp validate_message_for_twilio(message) do
    case message.type do
      :sms ->
        validate_sms_message(message)

      :mms ->
        validate_mms_message(message)

      _ ->
        {:error, "Unsupported message type: #{message.type}"}
    end
  end

  defp validate_sms_message(message) do
    # SMS messages should not have attachments
    if message[:attachments] && length(message.attachments) > 0 do
      {:error, "SMS messages cannot have attachments"}
    else
      :ok
    end
  end

  defp validate_mms_message(message) do
    # MMS messages can have attachments but they should be images
    if message[:attachments] && length(message.attachments) > 0 do
      validate_mms_attachments(message.attachments)
    else
      :ok
    end
  end

  defp validate_mms_attachments(attachments) do
    supported_types = ["image/jpeg", "image/png", "image/gif", "image/webp"]

    invalid_attachments =
      Enum.filter(attachments, fn attachment ->
        attachment[:content_type] not in supported_types
      end)

    if invalid_attachments == [] do
      :ok
    else
      {:error, "MMS attachments must be images (JPEG, PNG, GIF, WebP)"}
    end
  end

  defp validate_twilio_credentials(config) do
    # Basic validation of Twilio credentials format
    account_sid = config[:account_sid]
    auth_token = config[:auth_token]
    from_number = config[:from_number]

    cond do
      not is_binary(account_sid) or not String.starts_with?(account_sid, "AC") ->
        {:error, "Invalid Twilio Account SID format"}

      not is_binary(auth_token) or String.length(auth_token) < 32 ->
        {:error, "Invalid Twilio Auth Token format"}

      not is_binary(from_number) ->
        {:error, "Invalid from_number format"}

      true ->
        Provider.validate_phone_number(from_number)
    end
  end

  defp send_twilio_message(message, config) do
    # Twilio doesn't support multiple recipients in a single call
    # We need to send individual messages for each recipient
    recipients = if is_list(message.to), do: message.to, else: [message.to]

    results =
      Enum.map(recipients, fn recipient ->
        single_message = %{message | to: recipient}
        send_single_twilio_message(single_message, config)
      end)

    # Check if all messages succeeded
    case Enum.split_with(results, fn {status, _} -> status == :ok end) do
      {successful, []} ->
        # All succeeded - return the first message ID
        {_, first_message_id} = hd(successful)
        Logger.info("Twilio messages sent successfully to #{length(recipients)} recipients")
        {:ok, first_message_id}

      {_successful, failed} ->
        # Some failed - return the first error
        {_, error} = hd(failed)
        {:error, error}
    end
  end

  defp send_single_twilio_message(message, config) do
    url = build_twilio_url(config[:account_sid])
    headers = build_headers(config)
    body = build_request_body(message)

    case make_http_request(:post, url, headers, body) do
      {:ok, %{status_code: 201, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"sid" => message_id}} ->
            Logger.info("Twilio message sent successfully: #{message_id}")
            {:ok, message_id}

          {:error, _} ->
            {:error, "Failed to parse Twilio response"}
        end

      {:ok, %{status_code: status_code, body: response_body}} ->
        Logger.error("Twilio API error: #{status_code} - #{response_body}")
        {:error, "Twilio API error: #{status_code}"}

      {:error, reason} ->
        Logger.error("Failed to send Twilio message: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  defp get_twilio_message_status(message_id, config) do
    url = build_twilio_status_url(config[:account_sid], message_id)
    headers = build_headers(config)

    case make_http_request(:get, url, headers, "") do
      {:ok, %{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"status" => status}} ->
            {:ok, status}

          {:error, _} ->
            {:error, "Failed to parse Twilio response"}
        end

      {:ok, %{status_code: status_code}} ->
        {:error, "Twilio API error: #{status_code}"}

      {:error, reason} ->
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  defp build_twilio_url(account_sid) do
    "#{@base_url}/Accounts/#{account_sid}/Messages.json"
  end

  defp build_twilio_status_url(account_sid, message_id) do
    "#{@base_url}/Accounts/#{account_sid}/Messages/#{message_id}.json"
  end

  defp build_headers(config) do
    auth_string = Base.encode64("#{config[:account_sid]}:#{config[:auth_token]}")

    [
      {"Authorization", "Basic #{auth_string}"},
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]
  end

  defp build_request_body(message) do
    params = %{
      "To" => message.to,
      "From" => message.from,
      "Body" => message.body
    }

    # Add media URLs for MMS
    params =
      if message[:attachments] && length(message.attachments) > 0 do
        media_urls =
          Enum.map(message.attachments, fn attachment ->
            # In a real implementation, you'd upload the attachment to a publicly accessible URL
            # For now, we'll use a placeholder
            "https://example.com/media/#{attachment.filename}"
          end)

        Map.put(params, "MediaUrl", Enum.join(media_urls, ","))
      else
        params
      end

    URI.encode_query(params)
  end

  defp make_http_request(method, url, headers, body) do
    request = Finch.build(method, url, headers, body)

    case Finch.request(request, MessagingService.Finch) do
      {:ok, %Finch.Response{status: status, body: body}} ->
        {:ok, %{status_code: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
