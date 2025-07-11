defmodule MessagingServiceWeb.WebhookController do
  @moduledoc """
  Controller for handling incoming webhook messages.

  This controller accepts HTTP POST requests with message data and creates
  messages in the system. It supports multiple message types (SMS, MMS, Email)
  and includes authentication via the MessageAuth plug.
  """

  use MessagingServiceWeb, :controller
  require Logger

  alias MessagingService.Messages

  # Apply authentication to all webhook endpoints except health check
  plug MessagingServiceWeb.Plugs.MessageAuth when action not in [:health_check]

  @doc """
  Receives a message via HTTP POST and creates it in the system.

  Expected request body formats:

  SMS/MMS:
  ```json
  {
    "type": "sms",
    "from": "+1234567890",
    "to": "+1987654321",
    "body": "Hello world!",
    "timestamp": "2024-01-01T12:00:00Z",
    "provider_id": "twilio-msg-123"
  }
  ```

  Email:
  ```json
  {
    "type": "email",
    "from": "sender@example.com",
    "to": "recipient@example.com",
    "subject": "Test Email",
    "body": "Email body content",
    "timestamp": "2024-01-01T12:00:00Z",
    "provider_id": "sendgrid-msg-456"
  }
  ```

  With attachments:
  ```json
  {
    "type": "mms",
    "from": "+1234567890",
    "to": "+1987654321",
    "body": "Check this out!",
    "attachments": [
      {
        "filename": "image.jpg",
        "content_type": "image/jpeg",
        "url": "https://example.com/image.jpg",
        "attachment_type": "image"
      }
    ]
  }
  ```
  """
  def receive_message(conn, params) do
    Logger.info("Received webhook message: #{inspect(params)}")

    case process_incoming_message(params) do
      {:ok, message} ->
        Logger.info("Successfully created message: #{message.id}")

        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          message_id: message.id,
          conversation_id: message.conversation_id,
          created_at: message.inserted_at
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Failed to create message: #{inspect(changeset.errors)}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Invalid message data",
          details: format_changeset_errors(changeset)
        })

      {:error, reason} ->
        Logger.error("Failed to process message: #{inspect(reason)}")

        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Failed to process message",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  Batch receive multiple messages in a single request.

  Expected request body:
  ```json
  {
    "messages": [
      { "type": "sms", "from": "+1234567890", "to": "+1987654321", "body": "Hello!" },
      { "type": "email", "from": "user@example.com", "to": "contact@example.com", "body": "Hi!" }
    ]
  }
  ```
  """
  def receive_batch(conn, %{"messages" => messages}) when is_list(messages) do
    Logger.info("Received batch of #{length(messages)} messages")

    results =
      messages
      |> Enum.with_index()
      |> Enum.map(fn {message_params, index} ->
        case process_incoming_message(message_params) do
          {:ok, message} ->
            %{
              index: index,
              success: true,
              message_id: message.id,
              conversation_id: message.conversation_id
            }

          {:error, error} ->
            %{
              index: index,
              success: false,
              error: format_error(error)
            }
        end
      end)

    successful_count = Enum.count(results, & &1.success)
    failed_count = length(results) - successful_count

    status = if failed_count == 0, do: :created, else: :multi_status

    conn
    |> put_status(status)
    |> json(%{
      success: failed_count == 0,
      total: length(messages),
      successful: successful_count,
      failed: failed_count,
      results: results
    })
  end

  def receive_batch(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: "Invalid batch format",
      details: "Expected 'messages' array in request body"
    })
  end

  @doc """
  Health check endpoint for webhook availability.
  """
  def health_check(conn, _params) do
    conn
    |> json(%{
      status: "healthy",
      service: "messaging_service_webhook",
      timestamp: DateTime.utc_now()
    })
  end

  # Private helper functions

  defp process_incoming_message(params) do
    # Normalize the message parameters
    message_attrs = normalize_message_params(params)
    attachment_attrs = extract_attachment_params(params)

    # Create the message with or without attachments
    case attachment_attrs do
      [] ->
        create_message_by_type(message_attrs)

      attachments when is_list(attachments) ->
        Messages.create_message_with_attachments(message_attrs, attachments)
    end
  end

  defp normalize_message_params(params) do
    # Convert string keys to atom keys and normalize the data
    normalized = %{
      type: get_param(params, "type"),
      from: get_param(params, "from"),
      to: get_param(params, "to"),
      body: get_param(params, "body"),
      messaging_provider_id: get_param(params, "provider_id")
    }

    # Add email-specific fields
    normalized =
      case get_param(params, "subject") do
        nil -> normalized
        subject -> Map.put(normalized, :subject, subject)
      end

    # Add timestamp if provided
    case get_param(params, "timestamp") do
      nil ->
        normalized

      timestamp_str ->
        case parse_timestamp(timestamp_str) do
          {:ok, timestamp} -> Map.put(normalized, :timestamp, timestamp)
          # Use default timestamp if parsing fails
          :error -> normalized
        end
    end
  end

  defp extract_attachment_params(params) do
    case get_param(params, "attachments") do
      nil ->
        []

      attachments when is_list(attachments) ->
        Enum.map(attachments, &normalize_attachment_params/1)

      _ ->
        []
    end
  end

  defp normalize_attachment_params(attachment) do
    %{
      filename: get_param(attachment, "filename"),
      content_type: get_param(attachment, "content_type"),
      url: get_param(attachment, "url"),
      attachment_type: get_param(attachment, "attachment_type") || "other",
      size: get_param(attachment, "size")
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp create_message_by_type(%{type: "sms"} = attrs) do
    Messages.create_sms_message(attrs)
  end

  defp create_message_by_type(%{type: "mms"} = attrs) do
    Messages.create_mms_message(attrs)
  end

  defp create_message_by_type(%{type: "email"} = attrs) do
    Messages.create_email_message(attrs)
  end

  defp create_message_by_type(%{type: type}) do
    {:error, "Unsupported message type: #{type}"}
  end

  defp create_message_by_type(_attrs) do
    {:error, "Missing message type"}
  end

  defp get_param(params, key) when is_map(params) do
    params[key] || params[String.to_atom(key)]
  end

  defp parse_timestamp(timestamp_str) do
    case DateTime.from_iso8601(timestamp_str) do
      {:ok, datetime, _offset} -> {:ok, DateTime.to_naive(datetime)}
      {:error, _reason} -> :error
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp format_error(%Ecto.Changeset{} = changeset) do
    format_changeset_errors(changeset)
  end

  defp format_error(error) do
    to_string(error)
  end
end
