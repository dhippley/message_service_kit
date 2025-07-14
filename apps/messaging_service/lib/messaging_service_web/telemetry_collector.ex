defmodule MessagingServiceWeb.TelemetryCollector do
  @moduledoc """
  Collects and stores telemetry metrics for the messaging service.
  Uses ETS tables to store metrics data for fast retrieval.
  """
  use GenServer

  require Logger

  # ETS table names
  @message_metrics_table :message_delivery_metrics
  @status_transitions_table :status_transitions_metrics
  @recent_activity_table :recent_activity_metrics

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Create ETS tables for storing metrics
    :ets.new(@message_metrics_table, [:named_table, :public, :bag])
    :ets.new(@status_transitions_table, [:named_table, :public, :bag])
    :ets.new(@recent_activity_table, [:named_table, :public, :bag])

    # Attach telemetry handlers
    attach_telemetry_handlers()

    Logger.info("[TELEMETRY_COLLECTOR] Started and attached handlers")

    {:ok, %{}}
  end

  defp attach_telemetry_handlers do
    :telemetry.attach_many(
      "messaging-service-telemetry-collector",
      [
        [:messaging_service, :message_delivery, :completed],
        [:messaging_service, :message_delivery, :status_transition],
        [:messaging_service, :message_delivery, :batch_enqueued]
      ],
      &__MODULE__.handle_telemetry_event/4,
      %{}
    )
  end

  def handle_telemetry_event([:messaging_service, :message_delivery, :completed], measurements, metadata, _config) do
    timestamp = System.system_time(:millisecond)

    # Store completed message data
    :ets.insert(@message_metrics_table, {
      timestamp,
      metadata.message_type,
      metadata.result,
      metadata.direction,
      metadata.provider_name,
      measurements.duration_ms
    })

    # Store recent activity
    :ets.insert(@recent_activity_table, {
      timestamp,
      :completed,
      metadata.message_type,
      metadata.result,
      measurements.duration_ms
    })

    # Clean old data (keep last 24 hours)
    cleanup_old_data(timestamp)
  end

  def handle_telemetry_event([:messaging_service, :message_delivery, :status_transition], measurements, metadata, _config) do
    timestamp = System.system_time(:millisecond)

    # Store status transition data
    :ets.insert(@status_transitions_table, {
      timestamp,
      metadata.message_type,
      metadata.from_status,
      metadata.to_status,
      metadata.direction,
      measurements.duration_ms
    })
  end

  def handle_telemetry_event([:messaging_service, :message_delivery, :batch_enqueued], measurements, _metadata, _config) do
    timestamp = System.system_time(:millisecond)

    # Store batch enqueue data
    :ets.insert(@recent_activity_table, {
      timestamp,
      :batch_enqueued,
      measurements.count
    })
  end

  def handle_telemetry_event(event, measurements, metadata, _config) do
    Logger.debug(
      "[TELEMETRY_COLLECTOR] Unhandled event: #{inspect(event)}, " <>
        "measurements: #{inspect(measurements)}, metadata: #{inspect(metadata)}"
    )
  end

  # Public API for querying metrics

  def get_total_messages_processed do
    @message_metrics_table
    |> :ets.tab2list()
    |> length()
  end

  def get_average_processing_time do
    case :ets.tab2list(@message_metrics_table) do
      [] ->
        0

      records ->
        durations = Enum.map(records, fn {_, _, _, _, _, duration} -> duration end)
        Enum.sum(durations) / length(durations)
    end
  end

  def get_success_rate do
    case :ets.tab2list(@message_metrics_table) do
      [] ->
        0

      records ->
        total = length(records)
        successful = Enum.count(records, fn {_, _, result, _, _, _} -> result == "success" end)
        successful / total * 100
    end
  end

  def get_metrics_by_type(message_type) do
    records = :ets.match(@message_metrics_table, {:_, message_type, :_, :_, :_, :_})

    case records do
      [] ->
        %{
          total_count: 0,
          success_count: 0,
          failure_count: 0,
          avg_processing_time_ms: 0,
          success_rate: 0
        }

      _ ->
        all_records = :ets.match(@message_metrics_table, {:_, message_type, :"$1", :_, :_, :"$2"})
        total = length(all_records)
        successful = Enum.count(all_records, fn [result, _] -> result == "success" end)
        failed = total - successful

        durations = Enum.map(all_records, fn [_, duration] -> duration end)
        avg_duration = if total > 0, do: Enum.sum(durations) / total, else: 0
        success_rate = if total > 0, do: successful / total * 100, else: 0

        %{
          total_count: total,
          success_count: successful,
          failure_count: failed,
          avg_processing_time_ms: avg_duration,
          success_rate: success_rate
        }
    end
  end

  def get_transition_metrics(from_status, to_status) do
    pattern = {:_, :_, from_status, to_status, :_, :"$1"}
    durations = @status_transitions_table |> :ets.match(pattern) |> List.flatten()

    case durations do
      [] ->
        %{
          count: 0,
          avg_duration_ms: 0,
          p95_duration_ms: 0,
          p99_duration_ms: 0
        }

      _ ->
        count = length(durations)
        avg_duration = Enum.sum(durations) / count
        sorted_durations = Enum.sort(durations)

        p95_index = trunc(count * 0.95)
        p99_index = trunc(count * 0.99)

        p95_duration = Enum.at(sorted_durations, max(0, p95_index - 1), 0)
        p99_duration = Enum.at(sorted_durations, max(0, p99_index - 1), 0)

        %{
          count: count,
          avg_duration_ms: avg_duration,
          p95_duration_ms: p95_duration,
          p99_duration_ms: p99_duration
        }
    end
  end

  def get_recent_activity_summary do
    now = System.system_time(:millisecond)
    five_minutes_ago = now - 5 * 60 * 1000
    one_hour_ago = now - 60 * 60 * 1000

    # Get last 5 minutes activity
    recent_5min =
      :ets.select(@recent_activity_table, [
        {{:"$1", :completed, :_, :_, :"$2"}, [{:>, :"$1", five_minutes_ago}], [{{:"$1", :"$2"}}]}
      ])

    # Get last hour activity
    recent_1hour =
      :ets.select(@recent_activity_table, [
        {{:"$1", :completed, :_, :_, :"$2"}, [{:>, :"$1", one_hour_ago}], [{{:"$1", :"$2"}}]}
      ])

    # Get errors in each timeframe
    errors_5min =
      @recent_activity_table
      |> :ets.select([
        {{:"$1", :completed, :_, "failed", :_}, [{:>, :"$1", five_minutes_ago}], [:"$1"]}
      ])
      |> length()

    errors_1hour =
      @recent_activity_table
      |> :ets.select([
        {{:"$1", :completed, :_, "failed", :_}, [{:>, :"$1", one_hour_ago}], [:"$1"]}
      ])
      |> length()

    %{
      last_5_minutes: %{
        messages_processed: length(recent_5min),
        avg_processing_time_ms: calculate_avg_from_tuples(recent_5min),
        errors: errors_5min
      },
      last_hour: %{
        messages_processed: length(recent_1hour),
        avg_processing_time_ms: calculate_avg_from_tuples(recent_1hour),
        errors: errors_1hour
      }
    }
  end

  defp calculate_avg_from_tuples([]), do: 0

  defp calculate_avg_from_tuples(tuples) do
    durations = Enum.map(tuples, fn {_, duration} -> duration end)
    Enum.sum(durations) / length(durations)
  end

  defp cleanup_old_data(current_timestamp) do
    # Remove data older than 24 hours
    cutoff = current_timestamp - 24 * 60 * 60 * 1000

    # Clean message metrics
    :ets.select_delete(@message_metrics_table, [{{:"$1", :_, :_, :_, :_, :_}, [{:<, :"$1", cutoff}], [true]}])

    # Clean status transitions
    :ets.select_delete(@status_transitions_table, [{{:"$1", :_, :_, :_, :_, :_}, [{:<, :"$1", cutoff}], [true]}])

    # Clean recent activity
    :ets.select_delete(@recent_activity_table, [{{:"$1", :_, :_}, [{:<, :"$1", cutoff}], [true]}])
    :ets.select_delete(@recent_activity_table, [{{:"$1", :_, :_, :_, :_}, [{:<, :"$1", cutoff}], [true]}])
  end
end
