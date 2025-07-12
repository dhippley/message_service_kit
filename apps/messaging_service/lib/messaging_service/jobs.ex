defmodule MessagingService.Jobs do
  @moduledoc """
  Utility functions for managing background jobs in the messaging service.

  This module provides a convenient API for enqueuing and managing
  background jobs using Oban.
  """

  alias MessagingService.Workers.{MessageDeliveryWorker, WebhookProcessorWorker}

  @doc """
  Enqueues a message for background delivery.

  ## Examples

      iex> MessagingService.Jobs.deliver_message_async(message_id)
      {:ok, %Oban.Job{}}

      iex> MessagingService.Jobs.deliver_message_async(message_id, delay: 60)
      {:ok, %Oban.Job{}}
  """
  def deliver_message_async(message_id, opts \\ %{}) do
    MessageDeliveryWorker.enqueue_delivery(message_id, opts)
  end

  @doc """
  Schedules a message for delivery at a specific time.

  ## Examples

      iex> future_time = DateTime.add(DateTime.utc_now(), 300)
      iex> MessagingService.Jobs.schedule_message_delivery(message_id, future_time)
      {:ok, %Oban.Job{}}
  """
  def schedule_message_delivery(message_id, scheduled_at) do
    MessageDeliveryWorker.enqueue_scheduled_delivery(message_id, scheduled_at)
  end

  @doc """
  Enqueues multiple messages for batch delivery.

  ## Examples

      iex> message_ids = ["msg1", "msg2", "msg3"]
      iex> MessagingService.Jobs.deliver_messages_batch(message_ids)
      {:ok, [%Oban.Job{}, %Oban.Job{}, %Oban.Job{}]}
  """
  def deliver_messages_batch(message_ids) when is_list(message_ids) do
    MessageDeliveryWorker.enqueue_batch_delivery(message_ids)
  end

  @doc """
  Enqueues a webhook for background processing.

  ## Examples

      iex> webhook_data = %{"MessageSid" => "SM123", "MessageStatus" => "delivered"}
      iex> MessagingService.Jobs.process_webhook_async(webhook_data, "twilio", "delivery_status")
      {:ok, %Oban.Job{}}
  """
  def process_webhook_async(webhook_data, provider, webhook_type, opts \\ %{}) do
    WebhookProcessorWorker.enqueue_webhook(webhook_data, provider, webhook_type, opts)
  end

  @doc """
  Processes multiple webhooks in batch.

  ## Examples

      iex> webhooks = [
      ...>   {data1, "twilio", "delivery_status"},
      ...>   {data2, "sendgrid", "inbound_message"}
      ...> ]
      iex> MessagingService.Jobs.process_webhooks_batch(webhooks)
      {:ok, [%Oban.Job{}, %Oban.Job{}]}
  """
  def process_webhooks_batch(webhook_list) when is_list(webhook_list) do
    WebhookProcessorWorker.enqueue_batch_webhooks(webhook_list)
  end

  @doc """
  Gets the status of jobs in a specific queue.

  ## Examples

      iex> MessagingService.Jobs.get_queue_stats("default")
      %{available: 0, executing: 2, completed: 10, failed: 1}
  """
  def get_queue_stats(queue_name) do
    import Ecto.Query

    MessagingService.Repo.all(
      from j in Oban.Job,
        where: j.queue == ^queue_name,
        group_by: j.state,
        select: {j.state, count(j.id)}
    )
    |> Map.new()
  end

  @doc """
  Gets recent failed jobs for debugging.

  ## Examples

      iex> MessagingService.Jobs.get_recent_failures(10)
      [%Oban.Job{}, ...]
  """
  def get_recent_failures(limit \\ 10) do
    import Ecto.Query

    MessagingService.Repo.all(
      from j in Oban.Job,
        where: j.state == "failed",
        order_by: [desc: j.inserted_at],
        limit: ^limit
    )
  end

  @doc """
  Retries all failed jobs in a specific queue.

  ## Examples

      iex> MessagingService.Jobs.retry_failed_jobs("default")
      {5, nil}  # 5 jobs were retried
  """
  def retry_failed_jobs(queue_name) do
    import Ecto.Query

    MessagingService.Repo.update_all(
      from(j in Oban.Job,
        where: j.queue == ^queue_name and j.state == "failed"
      ),
      set: [
        state: "available",
        scheduled_at: DateTime.utc_now(),
        attempt: 0
      ]
    )
  end

  @doc """
  Cancels all pending jobs for a specific message.

  This is useful when you want to cancel delivery jobs for a message
  that should no longer be sent.

  ## Examples

      iex> MessagingService.Jobs.cancel_message_jobs(message_id)
      {2, nil}  # 2 jobs were cancelled
  """
  def cancel_message_jobs(message_id) do
    import Ecto.Query

    MessagingService.Repo.update_all(
      from(j in Oban.Job,
        where: j.state in ["available", "scheduled"] and
               fragment("?->>'message_id' = ?", j.args, ^message_id)
      ),
      set: [state: "cancelled"]
    )
  end

  @doc """
  Purges old completed and failed jobs.

  ## Examples

      iex> # Purge jobs older than 7 days
      iex> MessagingService.Jobs.purge_old_jobs(7)
      {100, nil}  # 100 jobs were deleted
  """
  def purge_old_jobs(days_old \\ 7) do
    import Ecto.Query

    cutoff_date = DateTime.add(DateTime.utc_now(), -days_old * 24 * 60 * 60)

    MessagingService.Repo.delete_all(
      from j in Oban.Job,
        where: j.state in ["completed", "discarded"] and
               j.inserted_at < ^cutoff_date
    )
  end
end
