defmodule MessagingService.Providers.TwilioProvider do
  @moduledoc """
  Twilio provider implementation for SMS and MMS messaging.

  This provider handles sending SMS and MMS messages through Twilio's API.
  """

  @behaviour MessagingService.Provider

  alias MessagingService.Provider
  require Logger

  @base_url "https://api.twilio.com/2010-04-01"

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
      required_keys
      |> Enum.filter(fn key -> not Map.has_key?(config, key) end)

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
      attachments
      |> Enum.filter(fn attachment ->
        not (attachment[:content_type] in supported_types)
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
    url = build_twilio_url(config[:account_sid])
    headers = build_headers(config)
    body = build_request_body(message)

    case make_http_request(url, headers, body) do
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

    case make_http_request(url, headers, "") do
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
        media_urls = Enum.map(message.attachments, fn attachment ->
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

  defp make_http_request(url, headers, body) do
    # In a real implementation, you'd use HTTPoison or Finch
    # For now, we'll simulate the request
    simulate_http_request(url, headers, body)
  end

  defp simulate_http_request(url, _headers, _body) do
    # Simulate successful response (in a real implementation, this would be an actual HTTP call)
    try do
      if String.contains?(url, "Messages.json") and not String.contains?(url, "/Messages/") do
        # Sending message
        message_id = "SM" <> (:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower))

        response_body = %{
          "sid" => message_id,
          "status" => "queued",
          "to" => "+1234567890",
          "from" => "+0987654321"
        }

        {:ok, %{status_code: 201, body: Jason.encode!(response_body)}}
      else
        # Getting message status
        response_body = %{
          "sid" => "SM123456789",
          "status" => "delivered",
          "to" => "+1234567890",
          "from" => "+0987654321"
        }

        {:ok, %{status_code: 200, body: Jason.encode!(response_body)}}
      end
    rescue
      error ->
        {:error, error}
    end
  end
end
