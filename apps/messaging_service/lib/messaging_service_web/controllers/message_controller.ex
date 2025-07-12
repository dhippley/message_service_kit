defmodule MessagingServiceWeb.MessageController do
  @moduledoc """
  Controller for sending outbound messages.

  This controller handles HTTP POST requests to send messages to external providers
  like Twilio for SMS/MMS and SendGrid for emails.
  """

  use MessagingServiceWeb, :controller

  alias MessagingService.Messages

  require Logger

  @doc """
  Sends an SMS or MMS message.

  Expected request body:
  ```json
  {
    "from": "+1234567890",
    "to": "+1987654321",
    "type": "sms", // or "mms"
    "body": "Hello world!",
    "attachments": null, // or ["url1", "url2"] for MMS
    "timestamp": "2024-01-01T12:00:00Z"
  }
  ```
  """
  def send_sms(conn, params) do
    Logger.info("Received SMS send request: #{inspect(params)}")

    case create_and_send_message(params, "sms") do
      {:ok, message} ->
        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          message_id: message.id,
          status: "queued",
          message: "SMS queued for delivery"
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          errors: format_changeset_errors(changeset)
        })

      {:error, reason} ->
        Logger.error("Failed to send SMS: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to send message"
        })
    end
  end

  @doc """
  Sends an email message.

  Expected request body:
  ```json
  {
    "from": "sender@example.com",
    "to": "recipient@example.com",
    "body": "Email content with <b>HTML</b>",
    "attachments": ["url1", "url2"], // optional
    "timestamp": "2024-01-01T12:00:00Z"
  }
  ```
  """
  def send_email(conn, params) do
    Logger.info("Received email send request: #{inspect(params)}")

    case create_and_send_message(params, "email") do
      {:ok, message} ->
        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          message_id: message.id,
          status: "queued",
          message: "Email queued for delivery"
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          errors: format_changeset_errors(changeset)
        })

      {:error, reason} ->
        Logger.error("Failed to send email: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to send message"
        })
    end
  end

  # Private helper functions

  defp create_and_send_message(params, default_type) do
    message_params = normalize_message_params(params, default_type)
    create_message_by_type(message_params)
  end

  defp normalize_message_params(params, default_type) do
    %{
      from: params["from"],
      to: params["to"],
      type: params["type"] || default_type,
      body: params["body"],
      attachments: normalize_attachments(params["attachments"]),
      timestamp: parse_timestamp(params["timestamp"]) || DateTime.utc_now(),
      status: "pending",
      direction: "outbound"
    }
  end

  defp normalize_attachments(nil), do: []

  defp normalize_attachments(attachments) when is_list(attachments) do
    Enum.map(attachments, fn
      url when is_binary(url) -> %{url: url, filename: nil, content_type: nil}
      attachment when is_map(attachment) -> attachment
    end)
  end

  defp normalize_attachments(_), do: []

  defp create_message_by_type(%{type: "sms"} = attrs) do
    Messages.send_sms(attrs.to, attrs.from, attrs.body)
  end

  defp create_message_by_type(%{type: "mms"} = attrs) do
    Messages.send_mms(attrs.to, attrs.from, attrs.body, attrs.attachments || [])
  end

  defp create_message_by_type(%{type: "email"} = attrs) do
    Messages.send_email(attrs.to, attrs.from, attrs.body, attrs.attachments || [])
  end

  defp create_message_by_type(_attrs) do
    {:error, "Unsupported message type"}
  end

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(timestamp_str) when is_binary(timestamp_str) do
    case DateTime.from_iso8601(timestamp_str) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end

  defp parse_timestamp(_), do: nil

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
