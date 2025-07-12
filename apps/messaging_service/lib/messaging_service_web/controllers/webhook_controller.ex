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

  defp normalize_attachment_params(attachment) when is_binary(attachment) do
    # Handle simple URL string
    %{
      filename: nil,
      content_type: nil,
      url: attachment,
      attachment_type: "other",
      size: nil
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp normalize_attachment_params(attachment) when is_map(attachment) do
    # Handle attachment object
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

  @doc """
  Receives inbound SMS/MMS messages from providers.

  Expected format for test scripts and generic providers:
  ```json
  {
    "from": "+18045551234",
    "to": "+12016661234",
    "type": "sms",
    "messaging_provider_id": "message-1",
    "body": "This is an incoming SMS message",
    "attachments": null,
    "timestamp": "2024-11-01T14:00:00Z"
  }
  ```
  """
  def receive_inbound_sms(conn, params) do
    Logger.info("Received inbound SMS webhook: #{inspect(params)}")

    # Ensure type is set for SMS/MMS
    params = Map.put(params, "type", params["type"] || "sms")

    case process_incoming_message(params) do
      {:ok, message} ->
        Logger.info("Successfully processed inbound SMS: #{message.id}")

        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          message_id: message.id,
          conversation_id: message.conversation_id,
          status: "received"
        })

      {:error, reason} ->
        Logger.error("Failed to process inbound SMS: #{inspect(reason)}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Failed to process SMS",
          details: format_error(reason)
        })
    end
  end

  @doc """
  Receives inbound email messages from providers.

  Expected format for test scripts and generic providers:
  ```json
  {
    "from": "contact@gmail.com",
    "to": "user@usehatchapp.com",
    "xillio_id": "message-3",
    "body": "<html><body>This is an incoming email with <b>HTML</b> content</body></html>",
    "attachments": ["https://example.com/received-document.pdf"],
    "timestamp": "2024-11-01T14:00:00Z"
  }
  ```
  """
  def receive_inbound_email(conn, params) do
    Logger.info("Received inbound email webhook: #{inspect(params)}")

    # Normalize email-specific params
    normalized_params = params
    |> Map.put("type", "email")
    |> Map.put("provider_id", params["xillio_id"] || params["provider_id"] || params["messaging_provider_id"])
    |> Map.put("subject", params["subject"] || "")

    case process_incoming_message(normalized_params) do
      {:ok, message} ->
        Logger.info("Successfully processed inbound email: #{message.id}")

        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          message_id: message.id,
          conversation_id: message.conversation_id,
          status: "received"
        })

      {:error, reason} ->
        Logger.error("Failed to process inbound email: #{inspect(reason)}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Failed to process email",
          details: format_error(reason)
        })
    end
  end

  @doc """
  Receives webhooks from Twilio for message status updates and inbound messages.

  Handles both delivery status updates and inbound message notifications.
  """
  def receive_twilio_webhook(conn, params) do
    Logger.info("Received Twilio webhook: #{inspect(params)}")

    case determine_twilio_webhook_type(params) do
      :status_update ->
        handle_twilio_status_update(conn, params)

      :inbound_message ->
        handle_twilio_inbound_message(conn, params)

      :unknown ->
        Logger.warning("Unknown Twilio webhook type: #{inspect(params)}")

        conn
        |> put_status(:ok)
        |> json(%{success: true, status: "ignored"})
    end
  end

  @doc """
  Receives webhooks from SendGrid for email delivery events and inbound emails.

  Handles email delivery status updates and inbound email notifications.
  """
  def receive_sendgrid_webhook(conn, params) do
    Logger.info("Received SendGrid webhook: #{inspect(params)}")

    case determine_sendgrid_webhook_type(params) do
      :status_update ->
        handle_sendgrid_status_update(conn, params)

      :inbound_email ->
        handle_sendgrid_inbound_email(conn, params)

      :unknown ->
        Logger.warning("Unknown SendGrid webhook type: #{inspect(params)}")

        conn
        |> put_status(:ok)
        |> json(%{success: true, status: "ignored"})
    end
  end

  # Private helper functions for Twilio webhooks
  defp determine_twilio_webhook_type(params) do
    cond do
      # Inbound message (has From, To, Body)
      params["From"] && params["To"] && params["Body"] ->
        :inbound_message

      # Status update (has MessageStatus or SmsStatus)
      params["MessageStatus"] || params["SmsStatus"] ->
        :status_update

      true ->
        :unknown
    end
  end

  defp handle_twilio_status_update(conn, params) do
    # Handle status updates - would update existing message status
    message_sid = params["MessageSid"] || params["SmsSid"]
    status = params["MessageStatus"] || params["SmsStatus"]

    Logger.info("Twilio status update - SID: #{message_sid}, Status: #{status}")

    # Here you would update the message status in the database
    # For now, just acknowledge receipt
    conn
    |> put_status(:ok)
    |> json(%{success: true, status: "status_updated"})
  end

  defp handle_twilio_inbound_message(conn, params) do
    # Convert Twilio format to our standard format
    normalized_params = %{
      "type" => if(params["NumMedia"] && params["NumMedia"] != "0", do: "mms", else: "sms"),
      "from" => params["From"],
      "to" => params["To"],
      "body" => params["Body"] || "",
      "provider_id" => params["MessageSid"] || params["SmsSid"],
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case process_incoming_message(normalized_params) do
      {:ok, message} ->
        Logger.info("Successfully processed Twilio inbound message: #{message.id}")

        # Twilio expects TwiML response for inbound messages
        conn
        |> put_resp_content_type("text/xml")
        |> send_resp(200, """
        <?xml version="1.0" encoding="UTF-8"?>
        <Response>
          <Message>Message received and processed</Message>
        </Response>
        """)

      {:error, reason} ->
        Logger.error("Failed to process Twilio inbound message: #{inspect(reason)}")

        conn
        |> put_resp_content_type("text/xml")
        |> send_resp(500, """
        <?xml version="1.0" encoding="UTF-8"?>
        <Response>
          <Message>Failed to process message</Message>
        </Response>
        """)
    end
  end

  # Private helper functions for SendGrid webhooks
  defp determine_sendgrid_webhook_type(params) do
    cond do
      # Inbound email parsing webhook
      params["from"] && params["to"] && params["html"] ->
        :inbound_email

      # Event webhook (delivery status)
      is_list(params) || params["event"] ->
        :status_update

      true ->
        :unknown
    end
  end

  defp handle_sendgrid_status_update(conn, params) do
    # Handle SendGrid event webhooks
    events = if is_list(params), do: params, else: [params]

    Logger.info("SendGrid status update - #{length(events)} events")

    # Here you would process each event and update message statuses
    # For now, just acknowledge receipt
    conn
    |> put_status(:ok)
    |> json(%{success: true, status: "events_processed", count: length(events)})
  end

  defp handle_sendgrid_inbound_email(conn, params) do
    # Convert SendGrid inbound email format to our standard format
    normalized_params = %{
      "type" => "email",
      "from" => params["from"],
      "to" => params["to"],
      "subject" => params["subject"] || "",
      "body" => params["html"] || params["text"] || "",
      "provider_id" => "sendgrid_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case process_incoming_message(normalized_params) do
      {:ok, message} ->
        Logger.info("Successfully processed SendGrid inbound email: #{message.id}")

        conn
        |> put_status(:ok)
        |> json(%{success: true, message_id: message.id})

      {:error, reason} ->
        Logger.error("Failed to process SendGrid inbound email: #{inspect(reason)}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, error: format_error(reason)})
    end
  end
end
