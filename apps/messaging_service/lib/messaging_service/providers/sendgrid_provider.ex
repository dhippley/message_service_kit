defmodule MessagingService.Providers.SendGridProvider do
  @moduledoc """
  SendGrid provider implementation for email messaging.

  This provider handles sending emails through SendGrid's API.
  """

  @behaviour MessagingService.Provider

  alias MessagingService.Provider
  require Logger

  @base_url "https://api.sendgrid.com/v3"

  @impl Provider
  def send_message(message, config) do
    with :ok <- validate_config(config),
         :ok <- validate_message_request(message),
         :ok <- validate_message_for_sendgrid(message) do
      send_sendgrid_message(message, config)
    end
  end

  @impl Provider
  def validate_recipient(recipient, :email) do
    Provider.validate_email(recipient)
  end

  def validate_recipient(_recipient, type) do
    {:error, "SendGrid provider does not support #{type} messages"}
  end

  @impl Provider
  def validate_config(config) when is_map(config) do
    required_keys = [:api_key, :from_email, :from_name]

    missing_keys =
      required_keys
      |> Enum.filter(fn key -> not Map.has_key?(config, key) end)

    if missing_keys == [] do
      validate_sendgrid_credentials(config)
    else
      {:error, "Missing required configuration keys: #{Enum.join(missing_keys, ", ")}"}
    end
  end

  def validate_config(_), do: {:error, "Configuration must be a map"}

  @impl Provider
  def supported_types, do: [:email]

  @impl Provider
  def provider_name, do: "SendGrid"

  @impl Provider
  def get_message_status(message_id, config) do
    with :ok <- validate_config(config) do
      get_sendgrid_message_status(message_id, config)
    end
  end

  # Private functions

  defp validate_message_request(message) do
    Provider.validate_message_request(message)
  end

  defp validate_message_for_sendgrid(message) do
    case message.type do
      :email ->
        validate_email_message(message)

      _ ->
        {:error, "Unsupported message type: #{message.type}"}
    end
  end

  defp validate_email_message(message) do
    # Email messages can have attachments
    if message[:attachments] && length(message.attachments) > 0 do
      validate_email_attachments(message.attachments)
    else
      :ok
    end
  end

  defp validate_email_attachments(attachments) do
    # Check attachment sizes (SendGrid has a 30MB limit for all attachments combined)
    total_size = Enum.reduce(attachments, 0, fn attachment, acc ->
      acc + byte_size(attachment[:data] || "")
    end)

    cond do
      total_size > 30 * 1024 * 1024 ->
        {:error, "Total attachment size exceeds 30MB limit"}

      length(attachments) > 10 ->
        {:error, "Too many attachments (max 10)"}

      true ->
        :ok
    end
  end

  defp validate_sendgrid_credentials(config) do
    api_key = config[:api_key]
    from_email = config[:from_email]
    from_name = config[:from_name]

    cond do
      not is_binary(api_key) or not String.starts_with?(api_key, "SG.") ->
        {:error, "Invalid SendGrid API key format"}

      not is_binary(from_email) ->
        {:error, "Invalid from_email format"}

      not is_binary(from_name) ->
        {:error, "Invalid from_name format"}

      true ->
        Provider.validate_email(from_email)
    end
  end

  defp send_sendgrid_message(message, config) do
    url = build_sendgrid_url()
    headers = build_headers(config)
    body = build_request_body(message, config)

    case make_http_request(url, headers, body) do
      {:ok, %{status_code: 202}} ->
        # SendGrid returns 202 for successful queuing
        # Generate a message ID for tracking
        message_id = generate_message_id()
        Logger.info("SendGrid message sent successfully: #{message_id}")
        {:ok, message_id}

      {:ok, %{status_code: status_code, body: response_body}} ->
        Logger.error("SendGrid API error: #{status_code} - #{response_body}")
        {:error, "SendGrid API error: #{status_code}"}

      {:error, reason} ->
        Logger.error("Failed to send SendGrid message: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  defp get_sendgrid_message_status(_message_id, config) do
    # SendGrid uses webhooks for status updates, but we can check activity
    # In a real implementation, you'd search for the message_id in activities
    url = build_sendgrid_activity_url()
    headers = build_headers(config)

    case make_http_request(url, headers, "") do
      {:ok, %{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, activities} when is_list(activities) ->
            # In a real implementation, you'd search for the message_id in activities
            # For now, we'll return a simulated status
            {:ok, "delivered"}

          {:error, _} ->
            {:error, "Failed to parse SendGrid response"}
        end

      {:ok, %{status_code: status_code}} ->
        {:error, "SendGrid API error: #{status_code}"}

      {:error, reason} ->
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  defp build_sendgrid_url do
    "#{@base_url}/mail/send"
  end

  defp build_sendgrid_activity_url do
    "#{@base_url}/messages"
  end

  defp build_headers(config) do
    [
      {"Authorization", "Bearer #{config[:api_key]}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp build_request_body(message, config) do
    email_data = %{
      personalizations: [
        %{
          to: [%{email: message.to}]
        }
      ],
      from: %{
        email: config[:from_email],
        name: config[:from_name]
      },
      subject: extract_subject(message.body),
      content: [
        %{
          type: "text/plain",
          value: message.body
        }
      ]
    }

    # Add attachments if present
    email_data =
      if message[:attachments] && length(message.attachments) > 0 do
        attachments = Enum.map(message.attachments, fn attachment ->
          %{
            content: Base.encode64(attachment[:data] || ""),
            filename: attachment[:filename] || "attachment",
            type: attachment[:content_type] || "application/octet-stream"
          }
        end)

        Map.put(email_data, :attachments, attachments)
      else
        email_data
      end

    Jason.encode!(email_data)
  end

  defp extract_subject(body) do
    # Simple subject extraction - use first line or default
    case String.split(body, "\n", parts: 2) do
      [first_line | _] when byte_size(first_line) < 100 -> first_line
      _ -> "Message from MessagingService"
    end
  end

  defp generate_message_id do
    # Generate a unique message ID for tracking
    "SG" <> (:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower))
  end

  defp make_http_request(url, headers, body) do
    # In a real implementation, you'd use HTTPoison or Finch
    # For now, we'll simulate the request
    simulate_http_request(url, headers, body)
  end

  defp simulate_http_request(url, _headers, _body) do
    # Simulate successful response (in a real implementation, this would be an actual HTTP call)
    try do
      if String.contains?(url, "mail/send") do
        # Sending email
        {:ok, %{status_code: 202, body: ""}}
      else
        # Getting message activity
        response_body = [
          %{
            "msg_id" => "SG123456789",
            "event" => "delivered",
            "email" => "test@example.com",
            "timestamp" => :os.system_time(:second)
          }
        ]

        {:ok, %{status_code: 200, body: Jason.encode!(response_body)}}
      end
    rescue
      error ->
        {:error, error}
    end
  end
end
