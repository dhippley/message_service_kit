defmodule MessagingService.Workers.MessageDeliveryWorkerTest do
  use MessagingService.DataCase, async: true
  use Oban.Testing, repo: MessagingService.Repo

  import ExUnit.CaptureLog

  alias MessagingService.Messages
  alias MessagingService.Workers.MessageDeliveryWorker

  setup do
    # Disable inline testing for specific tests that test job enqueuing
    Oban.Testing.with_testing_mode(:manual, fn -> :ok end)
    :ok
  end

  describe "enqueue_delivery/2" do
    test "successfully enqueues a job with default options" do
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Test message for enqueue",
          type: "sms",
          status: "queued",
          direction: "outbound",
          queued_at: NaiveDateTime.utc_now()
        })

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, job} = MessageDeliveryWorker.enqueue_delivery(message.id)
        assert job.queue == "default"
        assert job.args["message_id"] == message.id
        assert job.max_attempts == 3
      end)
    end

    test "enqueues a job with custom queue" do
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Test message for custom queue",
          type: "sms",
          status: "queued",
          direction: "outbound",
          queued_at: NaiveDateTime.utc_now()
        })

      Oban.Testing.with_testing_mode(:manual, fn ->
        opts = [queue: :high_priority]
        assert {:ok, job} = MessageDeliveryWorker.enqueue_delivery(message.id, opts)
        assert job.queue == "high_priority"
        assert job.args["message_id"] == message.id
      end)
    end

    test "enqueues a job with schedule_in option" do
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Test message for scheduling",
          type: "sms",
          status: "queued",
          direction: "outbound",
          queued_at: NaiveDateTime.utc_now()
        })

      Oban.Testing.with_testing_mode(:manual, fn ->
        opts = [schedule_in: 60]
        assert {:ok, job} = MessageDeliveryWorker.enqueue_delivery(message.id, opts)
        assert job.args["message_id"] == message.id
        # Check that it's scheduled for the future (allow for some timing variance)
        assert DateTime.diff(job.scheduled_at, DateTime.utc_now()) > 50
      end)
    end

    test "enqueues a job with max_attempts override" do
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Test message for max attempts",
          type: "sms",
          status: "queued",
          direction: "outbound",
          queued_at: NaiveDateTime.utc_now()
        })

      Oban.Testing.with_testing_mode(:manual, fn ->
        opts = [max_attempts: 5]
        assert {:ok, job} = MessageDeliveryWorker.enqueue_delivery(message.id, opts)
        assert job.max_attempts == 5
      end)
    end
  end

  describe "enqueue_scheduled_delivery/2" do
    test "successfully enqueues a scheduled job" do
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Test scheduled message",
          type: "sms",
          status: "queued",
          direction: "outbound",
          queued_at: NaiveDateTime.utc_now()
        })

      Oban.Testing.with_testing_mode(:manual, fn ->
        scheduled_at = DateTime.add(DateTime.utc_now(), 300)
        assert {:ok, job} = MessageDeliveryWorker.enqueue_scheduled_delivery(message.id, scheduled_at)
        assert job.args["message_id"] == message.id
        # Allow for small timing differences (within 2 seconds)
        assert abs(DateTime.diff(job.scheduled_at, scheduled_at)) <= 2
      end)
    end
  end

  describe "enqueue_batch_delivery/1" do
    test "successfully enqueues multiple jobs" do
      message_ids =
        Enum.map(1..3, fn i ->
          {:ok, message} =
            Messages.create_sms_message(%{
              to: "+155512345#{i}#{i}",
              from: "+15559876543",
              body: "Batch message #{i}",
              type: "sms",
              status: "queued",
              direction: "outbound",
              queued_at: NaiveDateTime.utc_now()
            })

          message.id
        end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, jobs} = MessageDeliveryWorker.enqueue_batch_delivery(message_ids)
        assert length(jobs) == 3

        jobs
        |> Enum.zip(message_ids)
        |> Enum.each(fn {job, message_id} ->
          assert job.args["message_id"] == message_id
          assert job.queue == "default"
        end)
      end)
    end

    test "handles empty list" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, []} = MessageDeliveryWorker.enqueue_batch_delivery([])
      end)
    end
  end

  describe "perform/1 error handling" do
    test "handles message not found" do
      non_existent_id = Ecto.UUID.generate()

      logs =
        capture_log(fn ->
          assert {:error, :message_not_found} =
                   perform_job(MessageDeliveryWorker, %{"message_id" => non_existent_id})
        end)

      assert logs =~ "Message not found: #{non_existent_id}"
    end

    test "handles malformed job args gracefully" do
      assert_raise FunctionClauseError, fn ->
        perform_job(MessageDeliveryWorker, %{"invalid_key" => "invalid_value"})
      end
    end
  end

  describe "Oban testing helpers (with manual mode)" do
    test "assert_enqueued works with enqueue_delivery" do
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Test assert enqueued",
          type: "sms",
          status: "queued",
          direction: "outbound",
          queued_at: NaiveDateTime.utc_now()
        })

      Oban.Testing.with_testing_mode(:manual, fn ->
        MessageDeliveryWorker.enqueue_delivery(message.id)
        assert_enqueued(worker: MessageDeliveryWorker, args: %{"message_id" => message.id})
      end)
    end

    test "assert_enqueued works with scheduled delivery" do
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Test scheduled assert",
          type: "sms",
          status: "queued",
          direction: "outbound",
          queued_at: NaiveDateTime.utc_now()
        })

      Oban.Testing.with_testing_mode(:manual, fn ->
        scheduled_at = DateTime.add(DateTime.utc_now(), 300)
        MessageDeliveryWorker.enqueue_scheduled_delivery(message.id, scheduled_at)

        assert_enqueued(
          worker: MessageDeliveryWorker,
          args: %{"message_id" => message.id}
          # Note: not checking scheduled_at due to timing precision issues in tests
        )
      end)
    end

    test "refute_enqueued works correctly" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        refute_enqueued(worker: MessageDeliveryWorker)

        {:ok, message} =
          Messages.create_sms_message(%{
            to: "+15551234567",
            from: "+15559876543",
            body: "Test refute enqueued",
            type: "sms",
            status: "queued",
            direction: "outbound",
            queued_at: NaiveDateTime.utc_now()
          })

        MessageDeliveryWorker.enqueue_delivery(message.id)
        assert_enqueued(worker: MessageDeliveryWorker)
      end)
    end

    test "all_enqueued returns correct jobs" do
      message_ids =
        Enum.map(1..3, fn i ->
          {:ok, message} =
            Messages.create_sms_message(%{
              to: "+155512345#{i}#{i}",
              from: "+15559876543",
              body: "Test all enqueued #{i}",
              type: "sms",
              status: "queued",
              direction: "outbound",
              queued_at: NaiveDateTime.utc_now()
            })

          message.id
        end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        Enum.each(message_ids, &MessageDeliveryWorker.enqueue_delivery/1)

        jobs = all_enqueued(worker: MessageDeliveryWorker)
        assert length(jobs) == 3

        enqueued_message_ids = Enum.map(jobs, &get_in(&1.args, ["message_id"]))
        assert Enum.sort(enqueued_message_ids) == Enum.sort(message_ids)
      end)
    end
  end

  describe "job configuration and behavior" do
    test "jobs are created with correct worker and queue" do
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Test worker config",
          type: "sms",
          status: "queued",
          direction: "outbound",
          queued_at: NaiveDateTime.utc_now()
        })

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, job} = MessageDeliveryWorker.enqueue_delivery(message.id)

        assert job.worker == "MessagingService.Workers.MessageDeliveryWorker"
        assert job.queue == "default"
        assert job.max_attempts == 3
      end)
    end

    test "batch delivery creates jobs with consistent configuration" do
      message_ids =
        Enum.map(1..2, fn i ->
          {:ok, message} =
            Messages.create_sms_message(%{
              to: "+155512345#{i}#{i}",
              from: "+15559876543",
              body: "Batch config test #{i}",
              type: "sms",
              status: "queued",
              direction: "outbound",
              queued_at: NaiveDateTime.utc_now()
            })

          message.id
        end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, jobs} = MessageDeliveryWorker.enqueue_batch_delivery(message_ids)

        Enum.each(jobs, fn job ->
          assert job.worker == "MessagingService.Workers.MessageDeliveryWorker"
          assert job.queue == "default"
          assert job.max_attempts == 3
        end)
      end)
    end
  end

  describe "worker execution behavior (with inline mode)" do
    test "worker logs appropriate messages when message not found" do
      non_existent_id = Ecto.UUID.generate()

      # Temporarily set logger level to info to capture info logs
      original_level = Logger.level()
      Logger.configure(level: :info)

      logs =
        capture_log(fn ->
          assert {:error, :message_not_found} =
                   perform_job(MessageDeliveryWorker, %{"message_id" => non_existent_id})
        end)

      # Restore original logger level
      Logger.configure(level: original_level)

      assert logs =~ "Processing message delivery for message: #{non_existent_id}"
      assert logs =~ "Message not found: #{non_existent_id}"
    end

    test "worker handles provider errors gracefully" do
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Test provider error handling",
          type: "sms",
          status: "queued",
          direction: "outbound",
          queued_at: NaiveDateTime.utc_now()
        })

      # Temporarily set logger level to info to capture info logs
      original_level = Logger.level()
      Logger.configure(level: :info)

      logs =
        capture_log(fn ->
          # This will fail because no provider is configured, but we test the error handling
          assert {:error, "No suitable provider found for sms messages"} =
                   perform_job(MessageDeliveryWorker, %{"message_id" => message.id})
        end)

      # Restore original logger level
      Logger.configure(level: original_level)

      assert logs =~ "Processing message delivery for message: #{message.id}"
      assert logs =~ "Failed to deliver message #{message.id}: No suitable provider found for sms messages"
    end
  end

  describe "perform/1 status updates" do
    test "updates message status from queued to failed when no provider configured" do
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Test status transitions",
          type: "sms",
          status: "queued",
          direction: "outbound",
          queued_at: NaiveDateTime.utc_now()
        })

      # Run the job - should fail due to no provider configured
      original_level = Logger.level()
      Logger.configure(level: :error)

      logs =
        capture_log(fn ->
          result = perform_job(MessageDeliveryWorker, %{"message_id" => message.id})
          assert {:error, _reason} = result
        end)

      Logger.configure(level: original_level)

      # Reload message from database to check final status
      updated_message = Messages.get_message!(message.id)
      assert updated_message.status == "failed"
      assert updated_message.failed_at != nil
      assert updated_message.failure_reason != nil
      # Check for the actual log message that gets generated
      assert logs =~ "Failed to deliver message #{message.id}"
    end

    test "enqueue_delivery updates message status to queued with timestamp" do
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Test queued status",
          type: "sms",
          status: "pending",
          direction: "outbound"
        })

      # Ensure message starts as pending
      assert message.status == "pending"
      assert message.queued_at == nil

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _job} = MessageDeliveryWorker.enqueue_delivery(message.id)

        # Reload message from database
        updated_message = Messages.get_message!(message.id)

        assert updated_message.status == "queued"
        assert updated_message.queued_at != nil
        # Ensure queued_at is recent (within last 5 seconds)
        assert NaiveDateTime.diff(NaiveDateTime.utc_now(), updated_message.queued_at) < 5
      end)
    end

    test "handles different message types without crashing" do
      message_types = [
        %{type: "sms", to: "+15551234567", from: "+15559876543", body: "SMS test"},
        %{type: "mms", to: "+15551234567", from: "+15559876543", body: "MMS test"},
        %{type: "email", to: "test@example.com", from: "sender@example.com", body: "Email test"}
      ]

      Enum.each(message_types, fn attrs ->
        base_attrs =
          Map.merge(attrs, %{
            status: "queued",
            direction: "outbound",
            queued_at: NaiveDateTime.utc_now()
          })

        {:ok, message} =
          case attrs.type do
            "sms" -> Messages.create_sms_message(base_attrs)
            "mms" -> Messages.create_mms_message(base_attrs)
            "email" -> Messages.create_email_message(base_attrs)
          end

        # Job should not crash, even if it fails due to no provider
        original_level = Logger.level()
        Logger.configure(level: :error)

        capture_log(fn ->
          perform_job(MessageDeliveryWorker, %{"message_id" => message.id})
        end)

        Logger.configure(level: original_level)

        # Verify message status was updated (should be failed due to no provider)
        updated_message = Messages.get_message!(message.id)
        assert updated_message.status == "failed"
      end)
    end

    test "batch enqueue updates all message statuses" do
      # Create multiple messages
      message_ids =
        Enum.map(1..3, fn i ->
          {:ok, message} =
            Messages.create_sms_message(%{
              to: "+155512345#{i}#{i}",
              from: "+15559876543",
              body: "Batch test #{i}",
              type: "sms",
              status: "pending",
              direction: "outbound"
            })

          message.id
        end)

      # All should start as pending
      messages = Enum.map(message_ids, &Messages.get_message!/1)
      assert Enum.all?(messages, &(&1.status == "pending"))
      assert Enum.all?(messages, &(&1.queued_at == nil))

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, jobs} = MessageDeliveryWorker.enqueue_batch_delivery(message_ids)
        assert length(jobs) == 3

        # All should now be queued
        updated_messages = Enum.map(message_ids, &Messages.get_message!/1)
        assert Enum.all?(updated_messages, &(&1.status == "queued"))
        assert Enum.all?(updated_messages, &(&1.queued_at != nil))
      end)
    end

    test "complete status lifecycle from pending through queued to failed" do
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Complete lifecycle test",
          type: "sms",
          status: "pending",
          direction: "outbound"
        })

      # 1. Initially pending
      assert message.status == "pending"
      assert message.queued_at == nil

      # 2. Enqueue -> queued status
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _job} = MessageDeliveryWorker.enqueue_delivery(message.id)

        queued_message = Messages.get_message!(message.id)
        assert queued_message.status == "queued"
        assert queued_message.queued_at != nil

        # 3. Process -> failed status (since no provider configured)
        original_level = Logger.level()
        Logger.configure(level: :error)

        capture_log(fn ->
          perform_job(MessageDeliveryWorker, %{"message_id" => message.id})
        end)

        Logger.configure(level: original_level)

        final_message = Messages.get_message!(message.id)
        assert final_message.status == "failed"
        # Preserved
        assert final_message.queued_at != nil
        # New
        assert final_message.failed_at != nil
        assert final_message.failure_reason != nil
      end)
    end
  end
end
