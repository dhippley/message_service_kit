#!/usr/bin/env elixir

# Test script to verify MessageDeliveryWorker functionality
IO.puts("Testing MessageDeliveryWorker...")

# Start the application (needed for Oban)
Mix.install([
  {:oban, "~> 2.19"},
  {:ecto_sql, "~> 3.0"},
  {:postgrex, ">= 0.0.0"}
])

Application.start(:messaging_service)

# Check if Oban is running
case Process.whereis(Oban) do
  nil -> IO.puts("❌ Oban is not running")
  pid -> IO.puts("✅ Oban is running at #{inspect(pid)}")
end

# Check queue configuration
try do
  queues = Oban.check_queue() |> Map.get(:queues, [])
  IO.puts("📋 Oban queues: #{inspect(queues)}")
catch
  error -> IO.puts("❌ Error checking Oban: #{inspect(error)}")
end

# Check for any existing jobs
try do
  jobs = MessagingService.Repo.all(Oban.Job)
  IO.puts("📝 Total jobs in database: #{length(jobs)}")

  # Group jobs by state
  jobs_by_state = Enum.group_by(jobs, & &1.state)

  Enum.each(jobs_by_state, fn {state, state_jobs} ->
    IO.puts("  #{String.upcase(state)}: #{length(state_jobs)} jobs")
  end)

  # Show detailed info for failed jobs
  failed_jobs = Map.get(jobs_by_state, "discarded", []) ++ Map.get(jobs_by_state, "retryable", [])

  if length(failed_jobs) > 0 do
    IO.puts("\n🔥 FAILED/DISCARDED JOBS:")
    Enum.each(failed_jobs, fn job ->
      IO.puts("  Job #{job.id} (#{job.worker}):")
      IO.puts("    State: #{job.state}")
      IO.puts("    Queue: #{job.queue}")
      IO.puts("    Attempts: #{job.attempt}/#{job.max_attempts}")
      IO.puts("    Args: #{inspect(job.args)}")
      if job.errors && length(job.errors) > 0 do
        IO.puts("    Errors:")
        Enum.each(job.errors, fn error ->
          IO.puts("      - #{inspect(error)}")
        end)
      end
      IO.puts("    Inserted: #{job.inserted_at}")
      if job.attempted_at, do: IO.puts("    Last attempt: #{job.attempted_at}")
      IO.puts("")
    end)
  else
    IO.puts("\n✅ No failed jobs found")
  end

  # Show recent completed jobs
  completed_jobs = Map.get(jobs_by_state, "completed", [])
  if length(completed_jobs) > 0 do
    recent_completed = Enum.take(completed_jobs, 5)
    IO.puts("\n📋 Recent completed jobs:")
    Enum.each(recent_completed, fn job ->
      IO.puts("  Job #{job.id} (#{job.worker}) - completed at #{job.completed_at}")
    end)
  end

catch
  error -> IO.puts("❌ Error querying jobs: #{inspect(error)}")
end

IO.puts("\nTest complete.")
