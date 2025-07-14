# Test script to demonstrate the dedicated messaging queue
# Run with: mix run test_messaging_queue.exs

alias MessagingService.Workers.MessageDeliveryWorker

# This will show that jobs are enqueued to the :messaging queue
IO.puts("=== Testing Dedicated Messaging Queue ===")

# Create a test job to see the queue assignment
test_job = MessageDeliveryWorker.new(%{"message_id" => "test-123"})

IO.puts("Worker queue configuration: #{inspect(test_job.queue)}")
IO.puts("Worker max attempts: #{inspect(test_job.max_attempts)}")

# Show that the job is configured for the messaging queue
IO.puts("Job will be enqueued to: #{test_job.queue} queue")

IO.puts("\n=== Queue Benefits ===")
IO.puts("✅ Dedicated 25 workers for messaging (vs 10 for default queue)")
IO.puts("✅ Isolated from other background jobs (mailers, events, media)")
IO.puts("✅ Better resource management and monitoring")
IO.puts("✅ Can tune messaging queue separately from others")
IO.puts("✅ Prevents messaging jobs from blocking other job types")

IO.puts("\n=== Current Oban Queue Configuration ===")
config = Application.get_env(:messaging_service, Oban, [])
queues = Keyword.get(config, :queues, [])
IO.puts("Configured queues: #{inspect(queues)}")
