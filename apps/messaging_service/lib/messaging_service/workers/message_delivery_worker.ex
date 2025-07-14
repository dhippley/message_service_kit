defmodule MessagingService.Workers.MessageDeliveryWorker do
  @moduledoc """
  Background worker for delivering messages through external providers.

  This worker handles the asynchronous delivery of messages (SMS, MMS, Email)
  through various messaging providers. It's useful for:
  - Retrying failed deliveries
  - Rate limiting API calls
  - Processing large volumes of messages
  - Handling delivery confirmations

  ## Message Status Flow

  1. `pending` - Initial state when message is created
  2. `queued` - Message has been enqueued for delivery (sets `queued_at`)
  3. `processing` - Worker has started processing the message
  4. `sent` - Message was successfully sent (sets `sent_at`)
  5. `failed` - Message delivery failed (sets `failed_at` and `failure_reason`)

  Future statuses could include:
  - `delivered` - Provider confirmed delivery (sets `delivered_at`)
  - `bounced` - Message bounced back
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias Ecto.Association.NotLoaded
  alias MessagingService.Messages
  alias MessagingService.Providers.ProviderManager

  require Logger

  @doc """
  Performs the message delivery job.

  Expected args:
  - `message_id` - The ID of the message to deliver
  - `provider_configs` - Optional provider configurations
  """
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"message_id" => message_id} = args}) do
    Logger.info("Processing message delivery for message: #{message_id}")

    case Messages.get_message(message_id) do
      nil ->
        Logger.error("Message not found: #{message_id}")
        {:error, :message_not_found}

      message ->
        # Update status to processing
        Messages.update_message(message, %{status: "processing"})

        # Preload attachments if the message type supports them
        message_with_attachments =
          if message.type in ["email", "mms"] do
            MessagingService.Repo.preload(message, :attachments)
          else
            message
          end

        provider_configs = args["provider_configs"] || get_default_provider_configs()
        deliver_message(message_with_attachments, provider_configs)
    end
  end

  @doc """
  Enqueues a message for background delivery.

  ## Examples

      iex> MessageDeliveryWorker.enqueue_delivery(message_id)
      {:ok, %Oban.Job{}}

      iex> MessageDeliveryWorker.enqueue_delivery(message_id, delay: 60)
      {:ok, %Oban.Job{}}

      iex> MessageDeliveryWorker.enqueue_delivery(message_id, queue: :high_priority)
      {:ok, %Oban.Job{}}
  """
  def enqueue_delivery(message_id, opts \\ []) do
    # Update message status to queued
    case Messages.get_message(message_id) do
      nil ->
        {:error, :message_not_found}

      message ->
        Messages.update_message(message, %{
          status: "queued",
          queued_at: NaiveDateTime.utc_now()
        })

        %{"message_id" => message_id}
        |> new(opts || [])
        |> Oban.insert()
    end
  end

  @doc """
  Enqueues a message for delivery at a specific time.

  ## Examples

      iex> scheduled_at = DateTime.add(DateTime.utc_now(), 300)
      iex> MessageDeliveryWorker.enqueue_scheduled_delivery(message_id, scheduled_at)
      {:ok, %Oban.Job{}}
  """
  def enqueue_scheduled_delivery(message_id, scheduled_at) do
    %{"message_id" => message_id}
    |> new(scheduled_at: scheduled_at)
    |> Oban.insert()
  end

  @doc """
  Enqueues multiple messages for batch delivery.

  ## Examples

      iex> message_ids = ["msg1", "msg2", "msg3"]
      iex> MessageDeliveryWorker.enqueue_batch_delivery(message_ids)
      {:ok, [%Oban.Job{}, %Oban.Job{}, %Oban.Job{}]}
  """
  def enqueue_batch_delivery(message_ids) when is_list(message_ids) do
    if Enum.empty?(message_ids) do
      {:ok, []}
    else
      now = NaiveDateTime.utc_now()

      # Update all messages to queued status
      Enum.each(message_ids, fn message_id ->
        case Messages.get_message(message_id) do
          nil ->
            :skip

          message ->
            Messages.update_message(message, %{
              status: "queued",
              queued_at: now
            })
        end
      end)

      jobs =
        Enum.map(message_ids, fn message_id ->
          new(%{"message_id" => message_id})
        end)

      result = Oban.insert_all(jobs)
      {:ok, result}
    end
  end

  # Private helper functions

  defp deliver_message(message, provider_configs) do
    message_request = build_message_request(message)
    Logger.info("Starting message delivery for #{message.id} with configs: #{inspect(Map.keys(provider_configs))}")

    try do
      case ProviderManager.send_message(message_request, provider_configs) do
        {:ok, provider_message_id, provider_name} ->
          Logger.info("Provider returned success: #{provider_message_id}, #{provider_name}")
          update_message_success(message, provider_message_id, provider_name)
          Logger.info("Message delivered successfully: #{message.id}")
          :ok

        {:error, reason} ->
          Logger.error("Provider returned error: #{inspect(reason)}")
          update_message_failure(message, reason)
          Logger.error("Failed to deliver message #{message.id}: #{reason}")
          {:error, reason}

        other ->
          Logger.error("Provider returned unexpected result: #{inspect(other)}")
          update_message_failure(message, "Unexpected provider response: #{inspect(other)}")
          {:error, "Unexpected provider response"}
      end
    rescue
      e ->
        Logger.error("Exception in message delivery: #{inspect(e)}")
        Logger.error("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
        update_message_failure(message, "Exception: #{inspect(e)}")
        {:error, "Exception: #{inspect(e)}"}
    end
  end

  defp build_message_request(message) do
    %{
      type: String.to_atom(message.type),
      to: message.to,
      from: message.from,
      body: message.body,
      attachments: extract_attachment_urls(message)
    }
  end

  defp extract_attachment_urls(message) do
    case message.type do
      "sms" ->
        # SMS messages don't support attachments
        []

      "email" ->
        # Email messages can have attachments - check if attachments are loaded
        case message.attachments do
          %NotLoaded{} ->
            []

          attachments when is_list(attachments) and length(attachments) > 0 ->
            Enum.map(attachments, fn attachment ->
              %{
                url: attachment.url || attachment.blob,
                content_type: attachment.content_type,
                filename: attachment.filename
              }
            end)

          _ ->
            []
        end

      "mms" ->
        # MMS messages can have attachments - check if attachments are loaded
        case message.attachments do
          %NotLoaded{} ->
            # For testing, add a default image for MMS if attachments not loaded
            default_image_path = "apps/messaging_service/priv/static/images/default.gif"

            [
              %{
                url: default_image_path,
                content_type: "image/gif",
                filename: "default.gif"
              }
            ]

          attachments when is_list(attachments) and length(attachments) > 0 ->
            Enum.map(attachments, fn attachment ->
              %{
                url: attachment.url || attachment.blob,
                content_type: attachment.content_type,
                filename: attachment.filename
              }
            end)

          _ ->
            # For testing, add a default image for MMS if no attachments
            default_image_path = "apps/messaging_service/priv/static/images/default.gif"

            [
              %{
                url: default_image_path,
                content_type: "image/gif",
                filename: "default.gif"
              }
            ]
        end

      _ ->
        []
    end
  end

  defp update_message_success(message, provider_message_id, provider_name) do
    now = NaiveDateTime.utc_now()

    Messages.update_message(message, %{
      messaging_provider_id: provider_message_id,
      provider_name: Atom.to_string(provider_name),
      status: "sent",
      sent_at: now
    })
  end

  defp update_message_failure(message, reason) do
    now = NaiveDateTime.utc_now()

    Messages.update_message(message, %{
      status: "failed",
      failed_at: now,
      failure_reason: format_failure_reason(reason)
    })
  end

  defp format_failure_reason(reason) when is_binary(reason), do: reason
  defp format_failure_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_failure_reason(reason), do: inspect(reason)

  defp get_default_provider_configs do
    config = Application.get_env(:messaging_service, :provider_configs)

    if config do
      if is_list(config) and Keyword.keyword?(config) do
        Map.new(config)
      else
        config
      end
    else
      env = Application.get_env(:messaging_service, :environment, :dev)
      ProviderManager.default_configurations(env)
    end
  end
end
