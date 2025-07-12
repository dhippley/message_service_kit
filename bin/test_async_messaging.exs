# Test script for async message sending
# Run with: mix run test_async_messaging.exs

# Start the application
{:ok, _} = Application.ensure_all_started(:messaging_service)

# Test sending an SMS message asynchronously
message_attrs = %{
  type: :sms,
  to: "+15551234567",
  from: "+15559876543",
  body: "Hello from async MessagingService!"
}

case MessagingService.Messages.send_outbound_message(message_attrs) do
  {:ok, message} ->
    IO.puts("✅ Message successfully queued!")
    IO.puts("Message ID: #{message.id}")
    IO.puts("Status: #{message.status}")
    IO.puts("Queued at: #{message.queued_at}")
    
    # Check if there are any Oban jobs
    job_count = Oban.Job |> MessagingService.Repo.aggregate(:count, :id)
    IO.puts("Oban jobs in queue: #{job_count}")
    
  {:error, reason} ->
    IO.puts("❌ Failed to send message: #{inspect(reason)}")
end
