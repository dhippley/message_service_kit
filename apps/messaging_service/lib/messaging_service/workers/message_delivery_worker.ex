defmodule MessagingService.Workers.MessageDeliveryWorker do
  @moduledoc """
  Background worker for delivering messages through external providers.

  This worker handles the asynchronous delivery of messages (SMS, MMS, Email)
  through various messaging providers. It's useful for:
  - Retrying failed deliveries
  - Rate limiting API calls
  - Processing large volumes of messages
  - Handling delivery confirmations
  """

  use Oban.Worker, queue: :default, max_attempts: 3

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
        provider_configs = args["provider_configs"] || get_default_provider_configs()
        deliver_message(message, provider_configs)
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
    %{"message_id" => message_id}
    |> new(opts)
    |> Oban.insert()
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

    case ProviderManager.send_message(message_request, provider_configs) do
      {:ok, provider_message_id, provider_name} ->
        update_message_with_provider_info(message, provider_message_id, provider_name)
        Logger.info("Message delivered successfully: #{message.id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to deliver message #{message.id}: #{reason}")
        {:error, reason}
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

  defp extract_attachment_urls(_message) do
    # This would typically preload and extract attachment URLs
    # For now, return empty list as attachments aren't preloaded
    []
  end

  defp update_message_with_provider_info(message, provider_message_id, provider_name) do
    Messages.update_message(message, %{
      messaging_provider_id: provider_message_id,
      provider_name: Atom.to_string(provider_name)
    })
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
