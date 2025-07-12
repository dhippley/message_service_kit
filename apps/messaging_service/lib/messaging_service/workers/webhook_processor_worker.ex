defmodule MessagingService.Workers.WebhookProcessorWorker do
  @moduledoc """
  Background worker for processing incoming webhooks from messaging providers.

  This worker handles the asynchronous processing of webhook data from providers
  like Twilio, SendGrid, etc. It's useful for:
  - Processing delivery confirmations
  - Handling status updates
  - Managing bounce/failure notifications
  - Processing inbound messages
  """

  use Oban.Worker, queue: :events, max_attempts: 5

  alias MessagingService.Messages

  require Logger

  @doc """
  Performs the webhook processing job.

  Expected args:
  - `webhook_data` - The webhook payload data
  - `provider` - The provider that sent the webhook
  - `webhook_type` - Type of webhook (delivery_status, inbound_message, etc.)
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    webhook_data = args["webhook_data"]
    provider = args["provider"]
    webhook_type = args["webhook_type"]

    Logger.info("Processing #{webhook_type} webhook from #{provider}")

    case webhook_type do
      "delivery_status" -> process_delivery_status(webhook_data, provider)
      "inbound_message" -> process_inbound_message(webhook_data, provider)
      "bounce_notification" -> process_bounce_notification(webhook_data, provider)
      _ ->
        Logger.warning("Unknown webhook type: #{webhook_type}")
        {:error, :unknown_webhook_type}
    end
  end

  @doc """
  Enqueues a webhook for background processing.

  ## Examples

      iex> WebhookProcessorWorker.enqueue_webhook(webhook_data, "twilio", "delivery_status")
      {:ok, %Oban.Job{}}
  """
  def enqueue_webhook(webhook_data, provider, webhook_type, opts \\ %{}) do
    %{
      webhook_data: webhook_data,
      provider: provider,
      webhook_type: webhook_type
    }
    |> new(opts)
    |> Oban.insert()
  end

  @doc """
  Enqueues multiple webhooks for batch processing.

  ## Examples

      iex> webhooks = [
      ...>   {data1, "twilio", "delivery_status"},
      ...>   {data2, "sendgrid", "inbound_message"}
      ...> ]
      iex> WebhookProcessorWorker.enqueue_batch_webhooks(webhooks)
      {:ok, [%Oban.Job{}, %Oban.Job{}]}
  """
  def enqueue_batch_webhooks(webhook_list) when is_list(webhook_list) do
    jobs =
      Enum.map(webhook_list, fn {webhook_data, provider, webhook_type} ->
        new(%{
          webhook_data: webhook_data,
          provider: provider,
          webhook_type: webhook_type
        })
      end)

    Oban.insert_all(jobs)
  end

  # Private processing functions

  defp process_delivery_status(webhook_data, provider) do
    case extract_message_info(webhook_data, provider) do
      {:ok, provider_message_id, status} ->
        update_message_status(provider_message_id, status)

      {:error, reason} ->
        Logger.error("Failed to extract delivery status: #{reason}")
        {:error, reason}
    end
  end

  defp process_inbound_message(webhook_data, provider) do
    case parse_inbound_message(webhook_data, provider) do
      {:ok, message_attrs} ->
        create_inbound_message(message_attrs)

      {:error, reason} ->
        Logger.error("Failed to parse inbound message: #{reason}")
        {:error, reason}
    end
  end

  defp process_bounce_notification(webhook_data, provider) do
    case extract_bounce_info(webhook_data, provider) do
      {:ok, provider_message_id, bounce_reason} ->
        handle_message_bounce(provider_message_id, bounce_reason)

      {:error, reason} ->
        Logger.error("Failed to process bounce notification: #{reason}")
        {:error, reason}
    end
  end

  # Helper functions for different providers

  defp extract_message_info(webhook_data, "twilio") do
    # Extract Twilio-specific delivery status information
    message_sid = webhook_data["MessageSid"]
    status = webhook_data["MessageStatus"]

    if message_sid && status do
      {:ok, message_sid, normalize_status(status)}
    else
      {:error, "Missing required Twilio fields"}
    end
  end

  defp extract_message_info(webhook_data, "sendgrid") do
    # Extract SendGrid-specific delivery status information
    message_id = webhook_data["sg_message_id"]
    event = webhook_data["event"]

    if message_id && event do
      {:ok, message_id, normalize_sendgrid_event(event)}
    else
      {:error, "Missing required SendGrid fields"}
    end
  end

  defp extract_message_info(_webhook_data, provider) do
    {:error, "Unsupported provider: #{provider}"}
  end

  defp parse_inbound_message(webhook_data, "twilio") do
    # Parse Twilio inbound message
    {:ok, %{
      from: webhook_data["From"],
      to: webhook_data["To"],
      body: webhook_data["Body"],
      type: determine_message_type(webhook_data),
      messaging_provider_id: webhook_data["MessageSid"],
      timestamp: parse_timestamp(webhook_data["DateCreated"])
    }}
  end

  defp parse_inbound_message(webhook_data, "sendgrid") do
    # Parse SendGrid inbound email
    {:ok, %{
      from: webhook_data["from"],
      to: webhook_data["to"],
      body: webhook_data["html"] || webhook_data["text"],
      type: "email",
      messaging_provider_id: webhook_data["sg_message_id"],
      timestamp: parse_timestamp(webhook_data["timestamp"])
    }}
  end

  defp parse_inbound_message(_webhook_data, provider) do
    {:error, "Unsupported provider: #{provider}"}
  end

  defp extract_bounce_info(webhook_data, "sendgrid") do
    message_id = webhook_data["sg_message_id"]
    reason = webhook_data["reason"]

    if message_id && reason do
      {:ok, message_id, reason}
    else
      {:error, "Missing bounce information"}
    end
  end

  defp extract_bounce_info(_webhook_data, provider) do
    {:error, "Bounce processing not implemented for: #{provider}"}
  end

  # Database operations

  defp update_message_status(provider_message_id, status) do
    # Find message by provider ID and update status
    # This would need to be implemented based on your Message schema
    Logger.info("Updating message #{provider_message_id} status to #{status}")
    :ok
  end

  defp create_inbound_message(message_attrs) do
    case message_attrs.type do
      "sms" -> Messages.create_sms_message(message_attrs)
      "mms" -> Messages.create_mms_message(message_attrs)
      "email" -> Messages.create_email_message(message_attrs)
      _ -> {:error, "Unsupported message type: #{message_attrs.type}"}
    end
    |> case do
      {:ok, message} ->
        Logger.info("Created inbound message: #{message.id}")
        :ok

      {:error, changeset} ->
        Logger.error("Failed to create inbound message: #{inspect(changeset)}")
        {:error, changeset}
    end
  end

  defp handle_message_bounce(provider_message_id, bounce_reason) do
    Logger.warning("Message #{provider_message_id} bounced: #{bounce_reason}")
    # Implement bounce handling logic (mark as failed, notify sender, etc.)
    :ok
  end

  # Utility functions

  defp normalize_status("delivered"), do: "delivered"
  defp normalize_status("failed"), do: "failed"
  defp normalize_status("undelivered"), do: "failed"
  defp normalize_status(status), do: status

  defp normalize_sendgrid_event("delivered"), do: "delivered"
  defp normalize_sendgrid_event("bounce"), do: "failed"
  defp normalize_sendgrid_event("dropped"), do: "failed"
  defp normalize_sendgrid_event(event), do: event

  defp determine_message_type(webhook_data) do
    num_media = webhook_data["NumMedia"] |> to_string() |> String.to_integer()
    if num_media > 0, do: "mms", else: "sms"
  rescue
    _ -> "sms"
  end

  defp parse_timestamp(nil), do: NaiveDateTime.utc_now()
  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case NaiveDateTime.from_iso8601(timestamp) do
      {:ok, datetime} -> datetime
      _ -> NaiveDateTime.utc_now()
    end
  end
  defp parse_timestamp(_), do: NaiveDateTime.utc_now()
end
