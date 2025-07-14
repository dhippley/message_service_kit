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
    start_time = System.monotonic_time(:millisecond)

    case Messages.get_message(message_id) do
      nil ->
        Logger.error("Message not found: #{message_id}")
        {:error, :message_not_found}

      message ->
        # Emit telemetry for processing start and calculate queue time
        emit_status_transition_telemetry(message, "processing", start_time)

        # Update status to processing
        {:ok, updated_message} = Messages.update_message(message, %{status: "processing"})

        # Preload attachments if the message type supports them
        message_with_attachments =
          if updated_message.type in ["email", "mms"] do
            MessagingService.Repo.preload(updated_message, :attachments)
          else
            updated_message
          end

        provider_configs = args["provider_configs"] || get_default_provider_configs()
        deliver_message(message_with_attachments, provider_configs, start_time)
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
        queue_time = System.monotonic_time(:millisecond)

        # Emit telemetry for queued transition
        emit_status_transition_telemetry(message, "queued", queue_time)

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
      queue_time = System.monotonic_time(:millisecond)

      # Update all messages to queued status and emit telemetry
      Enum.each(message_ids, fn message_id ->
        case Messages.get_message(message_id) do
          nil ->
            :skip

          message ->
            # Emit telemetry for batch queued transition
            emit_status_transition_telemetry(message, "queued", queue_time)

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

      # Emit batch telemetry
      :telemetry.execute(
        [:messaging_service, :message_delivery, :batch_enqueued],
        %{
          count: length(message_ids),
          timestamp: queue_time
        },
        %{
          message_ids: message_ids
        }
      )

      {:ok, result}
    end
  end

  # Private helper functions

  defp deliver_message(message, provider_configs, start_time) do
    message_request = build_message_request(message)
    Logger.info("Starting message delivery for #{message.id} with configs: #{inspect(Map.keys(provider_configs))}")

    try do
      case ProviderManager.send_message(message_request, provider_configs) do
        {:ok, provider_message_id, provider_name} ->
          Logger.info("Provider returned success: #{provider_message_id}, #{provider_name}")
          update_message_success(message, provider_message_id, provider_name, start_time)
          Logger.info("Message delivered successfully: #{message.id}")
          :ok

        {:error, reason} ->
          Logger.error("Provider returned error: #{inspect(reason)}")
          update_message_failure(message, reason, start_time)
          Logger.error("Failed to deliver message #{message.id}: #{reason}")
          {:error, reason}

        other ->
          Logger.error("Provider returned unexpected result: #{inspect(other)}")
          update_message_failure(message, "Unexpected provider response: #{inspect(other)}", start_time)
          {:error, "Unexpected provider response"}
      end
    rescue
      e ->
        Logger.error("Exception in message delivery: #{inspect(e)}")
        Logger.error("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
        update_message_failure(message, "Exception: #{inspect(e)}", start_time)
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

  defp update_message_success(message, provider_message_id, provider_name, start_time) do
    now = NaiveDateTime.utc_now()
    completion_time = System.monotonic_time(:millisecond)

    # Emit telemetry for successful delivery
    emit_status_transition_telemetry(message, "sent", completion_time)
    emit_delivery_completion_telemetry(message, "success", start_time, completion_time)

    Messages.update_message(message, %{
      messaging_provider_id: provider_message_id,
      provider_name: Atom.to_string(provider_name),
      status: "sent",
      sent_at: now
    })
  end

  defp update_message_failure(message, reason, start_time) do
    now = NaiveDateTime.utc_now()
    completion_time = System.monotonic_time(:millisecond)

    # Emit telemetry for failed delivery
    emit_status_transition_telemetry(message, "failed", completion_time)
    emit_delivery_completion_telemetry(message, "failed", start_time, completion_time)

    Messages.update_message(message, %{
      status: "failed",
      failed_at: now,
      failure_reason: format_failure_reason(reason)
    })
  end

  defp format_failure_reason(reason) when is_binary(reason), do: reason
  defp format_failure_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_failure_reason(reason), do: inspect(reason)

  # Telemetry helper functions

  defp emit_status_transition_telemetry(message, new_status, timestamp) do
    # Calculate time since previous status
    time_in_status = calculate_time_in_previous_status(message, timestamp)

    :telemetry.execute(
      [:messaging_service, :message_delivery, :status_transition],
      %{
        duration_ms: time_in_status,
        timestamp: timestamp
      },
      %{
        message_id: message.id,
        message_type: message.type,
        from_status: message.status,
        to_status: new_status,
        conversation_id: message.conversation_id,
        direction: message.direction
      }
    )
  end

  defp emit_delivery_completion_telemetry(message, result, start_time, completion_time) do
    total_duration = completion_time - start_time

    :telemetry.execute(
      [:messaging_service, :message_delivery, :completed],
      %{
        duration_ms: total_duration,
        start_time: start_time,
        completion_time: completion_time
      },
      %{
        message_id: message.id,
        message_type: message.type,
        result: result,
        conversation_id: message.conversation_id,
        direction: message.direction,
        provider_name: message.provider_name
      }
    )
  end

  defp calculate_time_in_previous_status(message, current_timestamp) do
    previous_timestamp = case message.status do
      "pending" ->
        # Convert inserted_at to monotonic time equivalent
        # This is approximate since we don't have the original monotonic time
        message.inserted_at
        |> NaiveDateTime.to_erl()
        |> :calendar.datetime_to_gregorian_seconds()
        |> Kernel.*(1000) # Convert to milliseconds

      "queued" ->
        if message.queued_at do
          message.queued_at
          |> NaiveDateTime.to_erl()
          |> :calendar.datetime_to_gregorian_seconds()
          |> Kernel.*(1000)
        else
          current_timestamp
        end

      "processing" ->
        # For processing, we don't have an exact timestamp, so estimate
        current_timestamp - 100 # Default 100ms ago

      _ ->
        current_timestamp
    end

    # Convert to monotonic time approximation if needed
    if is_integer(previous_timestamp) do
      max(0, current_timestamp - previous_timestamp)
    else
      0
    end
  end

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
