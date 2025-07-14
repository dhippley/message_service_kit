defmodule MessagingService.Workers.MessageDeliveryTelemetryTest do
  @moduledoc """
  Tests for telemetry events emitted by MessageDeliveryWorker.
  """

  use MessagingService.DataCase, async: true
  use Oban.Testing, repo: MessagingService.Repo

  import ExUnit.CaptureLog

  alias MessagingService.Messages
  alias MessagingService.Workers.MessageDeliveryWorker

  # Helper function to receive telemetry events for a specific message ID
  defp receive_telemetry_for_message(message_id, timeout \\ 1000) do
    receive do
      {:telemetry_event, event, measurements, metadata} ->
        if metadata.message_id == message_id do
          {event, measurements, metadata}
        else
          # Not the event we're looking for, keep waiting
          receive_telemetry_for_message(message_id, timeout)
        end
    after
      timeout -> flunk("Did not receive telemetry event for message #{message_id} within #{timeout}ms")
    end
  end

  # Helper function to receive status transition telemetry for a specific message ID
  defp receive_status_transition_for_message(message_id, timeout \\ 1000) do
    receive do
      {:status_transition, event, measurements, metadata} ->
        if metadata.message_id == message_id do
          {event, measurements, metadata}
        else
          # Not the event we're looking for, keep waiting
          receive_status_transition_for_message(message_id, timeout)
        end
    after
      timeout -> flunk("Did not receive status transition for message #{message_id} within #{timeout}ms")
    end
  end

  # Helper function to receive delivery completion telemetry for a specific message ID
  defp receive_delivery_completion_for_message(message_id, timeout \\ 1000) do
    receive do
      {:delivery_completed, event, measurements, metadata} ->
        if metadata.message_id == message_id do
          {event, measurements, metadata}
        else
          # Not the event we're looking for, keep waiting
          receive_delivery_completion_for_message(message_id, timeout)
        end
    after
      timeout -> flunk("Did not receive delivery completion for message #{message_id} within #{timeout}ms")
    end
  end

  describe "telemetry events" do
    test "emits status transition telemetry when enqueueing a message" do
      # Set up telemetry handler to capture events
      test_pid = self()

      handler_id = {:test_status_transition, make_ref()}

      :telemetry.attach(
        handler_id,
        [:messaging_service, :message_delivery, :status_transition],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      # Create a message
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Telemetry test message",
          type: "sms",
          status: "pending",
          direction: "outbound"
        })

      # Enqueue the message - should emit telemetry
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _job} = MessageDeliveryWorker.enqueue_delivery(message.id)
      end)

      # Verify telemetry event was emitted for our specific message
      {event, measurements, metadata} = receive_telemetry_for_message(message.id)

      assert event == [:messaging_service, :message_delivery, :status_transition]
      assert Map.has_key?(measurements, :duration_ms)
      assert Map.has_key?(measurements, :timestamp)
      assert metadata.message_id == message.id
      assert metadata.message_type == "sms"
      assert metadata.from_status == "pending"
      assert metadata.to_status == "queued"
      assert metadata.direction == "outbound"

      # Clean up
      :telemetry.detach(handler_id)
    end

    test "emits completion telemetry when message delivery completes" do
      # Set up telemetry handlers
      test_pid = self()

      status_handler_id = {:test_status_completion, make_ref()}
      completion_handler_id = {:test_delivery_completion, make_ref()}

      :telemetry.attach(
        status_handler_id,
        [:messaging_service, :message_delivery, :status_transition],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:status_transition, event, measurements, metadata})
        end,
        nil
      )

      :telemetry.attach(
        completion_handler_id,
        [:messaging_service, :message_delivery, :completed],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:delivery_completed, event, measurements, metadata})
        end,
        nil
      )

      # Create a message
      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Completion telemetry test",
          type: "sms",
          status: "queued",
          direction: "outbound",
          queued_at: NaiveDateTime.utc_now()
        })

      # Process the message (this will fail due to no provider, but will emit telemetry)
      original_level = Logger.level()
      Logger.configure(level: :error)

      capture_log(fn ->
        perform_job(MessageDeliveryWorker, %{"message_id" => message.id})
      end)

      Logger.configure(level: original_level)

      # Should receive two status transitions: queued -> processing, processing -> failed
      {_event1, _measurements1, metadata1} = receive_status_transition_for_message(message.id)
      assert metadata1.from_status == "queued"
      assert metadata1.to_status == "processing"

      {_event2, _measurements2, metadata2} = receive_status_transition_for_message(message.id)
      assert metadata2.from_status == "processing"
      assert metadata2.to_status == "failed"

      # Should receive completion telemetry
      {event, measurements, metadata} = receive_delivery_completion_for_message(message.id)

      assert event == [:messaging_service, :message_delivery, :completed]
      assert Map.has_key?(measurements, :duration_ms)
      assert Map.has_key?(measurements, :start_time)
      assert Map.has_key?(measurements, :completion_time)
      assert metadata.message_id == message.id
      assert metadata.result == "failed"

      # Clean up
      :telemetry.detach(status_handler_id)
      :telemetry.detach(completion_handler_id)
    end

    test "emits batch enqueue telemetry" do
      # Set up telemetry handler
      test_pid = self()

      handler_id = {:test_batch_enqueue, make_ref()}

      :telemetry.attach(
        handler_id,
        [:messaging_service, :message_delivery, :batch_enqueued],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:batch_enqueued, event, measurements, metadata})
        end,
        nil
      )

      # Create multiple messages
      message_ids =
        Enum.map(1..3, fn i ->
          {:ok, message} =
            Messages.create_sms_message(%{
              to: "+155512345#{i}#{i}",
              from: "+15559876543",
              body: "Batch telemetry test #{i}",
              type: "sms",
              status: "pending",
              direction: "outbound"
            })

          message.id
        end)

      # Enqueue as batch - should emit telemetry
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _jobs} = MessageDeliveryWorker.enqueue_batch_delivery(message_ids)
      end)

      # Verify batch telemetry event was emitted
      assert_receive {:batch_enqueued, event, measurements, metadata}, 1000

      assert event == [:messaging_service, :message_delivery, :batch_enqueued]
      assert measurements.count == 3
      assert Map.has_key?(measurements, :timestamp)
      assert metadata.message_ids == message_ids

      # Clean up
      :telemetry.detach(handler_id)
    end
  end

  describe "telemetry measurements accuracy" do
    test "measures time in status transitions accurately" do
      test_pid = self()

      handler_id = {:test_timing_accuracy, make_ref()}

      :telemetry.attach(
        handler_id,
        [:messaging_service, :message_delivery, :status_transition],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:timing, metadata.from_status, metadata.to_status, measurements.duration_ms})
        end,
        nil
      )

      {:ok, message} =
        Messages.create_sms_message(%{
          to: "+15551234567",
          from: "+15559876543",
          body: "Timing accuracy test",
          type: "sms",
          status: "pending",
          direction: "outbound"
        })

      # Add a small delay before enqueueing to test timing
      :timer.sleep(10)

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _job} = MessageDeliveryWorker.enqueue_delivery(message.id)
      end)

      # Should receive timing measurement
      assert_receive {:timing, "pending", "queued", duration_ms}, 1000

      # Duration should be a non-negative number
      assert is_number(duration_ms)
      assert duration_ms >= 0

      # Clean up
      :telemetry.detach(handler_id)
    end
  end
end
