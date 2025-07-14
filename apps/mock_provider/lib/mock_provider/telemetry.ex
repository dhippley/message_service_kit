defmodule MockProvider.Telemetry do
  @moduledoc """
  Telemetry event handlers for MockProvider stress testing metrics.
  """

  require Logger

  @doc """
  Attach telemetry handlers for stress test events.
  """
  def attach_handlers do
    # Create ETS table for metrics storage on startup
    # This ensures the table is owned by a persistent process
    case :ets.whereis(:stress_test_metrics) do
      :undefined ->
        Logger.info("[TELEMETRY] Creating ETS table :stress_test_metrics on startup")
        :ets.new(:stress_test_metrics, [:public, :named_table, :set])
        Logger.info("[TELEMETRY] ETS table created successfully")

      _table ->
        Logger.info("[TELEMETRY] ETS table :stress_test_metrics already exists")
    end

    events = [
      [:mock_provider, :stress_test, :start],
      [:mock_provider, :stress_test, :stop],
      [:mock_provider, :stress_test, :error],
      [:mock_provider, :stress_test, :validation_error],
      [:mock_provider, :stress_test, :worker, :start],
      [:mock_provider, :stress_test, :worker, :stop]
    ]

    :telemetry.attach_many(
      "mock_provider_stress_test_handler",
      events,
      &__MODULE__.handle_event/4,
      %{}
    )

    Logger.info("[TELEMETRY] All telemetry handlers attached successfully")
  end

  @doc """
  Handle telemetry events for stress test metrics.
  """
  def handle_event([:mock_provider, :stress_test, :start], measurements, metadata, _config) do
    Logger.info("""
    [TELEMETRY] Stress Test Started
    Test ID: #{measurements.test_id}
    Scenarios: #{measurements.scenario_count}
    Workers: #{measurements.concurrent_workers}
    Delay: #{measurements.delay_between_batches}ms
    Types: #{Enum.join(metadata.scenario_types, ", ")}
    Time: #{metadata.timestamp}
    """)
  end

  def handle_event([:mock_provider, :stress_test, :stop], measurements, metadata, _config) do
    efficiency = Float.round(measurements.total_messages / measurements.concurrent_workers, 2)

    Logger.info("""
    [TELEMETRY] Stress Test Completed
    Test ID: #{measurements.test_id}
    Duration: #{measurements.duration_ms}ms (#{Float.round(measurements.duration_ms / 1000, 2)}s)
    Messages: #{measurements.total_messages}
    Scenarios: #{measurements.successful_scenarios}/#{measurements.scenario_count}
    Throughput: #{measurements.messages_per_second} msg/sec
    Efficiency: #{efficiency} msg/worker
    Workers: #{measurements.concurrent_workers}
    Success: #{metadata.success}
    Time: #{metadata.timestamp}
    """)

    # Store metrics for potential aggregation
    Logger.info("[TELEMETRY] About to store metrics for test: #{measurements.test_id}")
    store_stress_test_metrics(measurements, metadata)
    Logger.info("[TELEMETRY] Metrics stored successfully")
  end

  def handle_event([:mock_provider, :stress_test, :error], measurements, metadata, _config) do
    Logger.error("""
    [TELEMETRY] Stress Test Error
    Test ID: #{measurements.test_id}
    Error: #{metadata.error_message}
    Type: #{measurements.error_type}
    Scenarios: #{measurements.scenario_count}
    Workers: #{measurements.concurrent_workers}
    Time: #{metadata.timestamp}
    """)
  end

  def handle_event([:mock_provider, :stress_test, :validation_error], _measurements, metadata, _config) do
    Logger.warning("""
    [TELEMETRY] Stress Test Validation Error
    Reason: #{metadata.error_reason}
    Params: #{inspect(metadata.params)}
    Time: #{metadata.timestamp}
    """)
  end

  def handle_event([:mock_provider, :stress_test, :worker, :start], measurements, metadata, _config) do
    Logger.debug("""
    [TELEMETRY] Worker Started
    Test ID: #{measurements.test_id}
    Worker: #{measurements.worker_id}
    Scenarios: #{measurements.scenario_count}
    Time: #{metadata.timestamp}
    """)
  end

  def handle_event([:mock_provider, :stress_test, :worker, :stop], measurements, metadata, _config) do
    rate = Float.round(measurements.total_messages / (measurements.duration_ms / 1000), 2)

    Logger.debug("""
    [TELEMETRY] Worker Completed
    Test ID: #{measurements.test_id}
    Worker: #{measurements.worker_id}
    Duration: #{measurements.duration_ms}ms
    Messages: #{measurements.total_messages}
    Rate: #{rate} msg/sec
    Success: #{metadata.success}
    Time: #{metadata.timestamp}
    """)
  end

  # Catch-all for any other events
  def handle_event(event, measurements, metadata, _config) do
    Logger.debug("[TELEMETRY] Unhandled event: #{inspect(event)} - #{inspect(measurements)} - #{inspect(metadata)}")
  end

  # Store stress test metrics for analysis.
  # In a real application, this might store to a database or metrics system.
  defp store_stress_test_metrics(measurements, metadata) do
    Logger.info("[TELEMETRY] store_stress_test_metrics called for test: #{measurements.test_id}")

    # For now, just store in ETS table for demo purposes
    # In production, you might send to DataDog, Prometheus, etc.

    metric = %{
      test_id: measurements.test_id,
      timestamp: metadata.timestamp,
      duration_ms: measurements.duration_ms,
      total_messages: measurements.total_messages,
      messages_per_second: measurements.messages_per_second,
      scenario_count: measurements.scenario_count,
      concurrent_workers: measurements.concurrent_workers,
      scenario_types: metadata.scenario_types,
      success: metadata.success
    }

    Logger.info("[TELEMETRY] Metric object created: #{inspect(metric)}")

    # Store the metric (table should already exist from startup)
    table_ref = :ets.whereis(:stress_test_metrics)
    Logger.info("[TELEMETRY] ETS table reference: #{inspect(table_ref)}")

    if table_ref == :undefined do
      Logger.error("[TELEMETRY] ETS table not found! This shouldn't happen.")
      # Create it as fallback, but this indicates a problem
      :ets.new(:stress_test_metrics, [:public, :named_table, :set])
      Logger.info("[TELEMETRY] Created fallback ETS table")
    end

    Logger.info("[TELEMETRY] Inserting metric into ETS table")
    result = :ets.insert(:stress_test_metrics, {measurements.test_id, metric})
    Logger.info("[TELEMETRY] ETS insert result: #{inspect(result)}")

    # Verify storage
    count = :ets.info(:stress_test_metrics, :size)
    Logger.info("[TELEMETRY] ETS table size after insert: #{count}")
  end

  @doc """
  Get stored stress test metrics.
  """
  def get_stress_test_metrics do
    Logger.info("[TELEMETRY] get_stress_test_metrics called")
    table_ref = :ets.whereis(:stress_test_metrics)
    Logger.info("[TELEMETRY] ETS table :stress_test_metrics reference: #{inspect(table_ref)}")

    case table_ref do
      :undefined ->
        Logger.info("[TELEMETRY] ETS table not found, returning empty list")
        []

      _table ->
        Logger.info("[TELEMETRY] ETS table found, reading data")
        data = :ets.tab2list(:stress_test_metrics)
        Logger.info("[TELEMETRY] Raw ETS data: #{inspect(data)}")

        result =
          data
          |> Enum.map(fn {_id, metric} -> metric end)
          |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})

        Logger.info("[TELEMETRY] Processed metrics: #{inspect(result)}")
        result
    end
  end

  @doc """
  Get metrics summary for the last N stress tests.
  """
  def get_metrics_summary(count \\ 10) do
    metrics = Enum.take(get_stress_test_metrics(), count)

    if Enum.empty?(metrics) do
      %{
        total_tests: 0,
        avg_duration_ms: 0,
        avg_messages_per_second: 0,
        total_messages: 0,
        success_rate: 0
      }
    else
      successful_tests = Enum.filter(metrics, & &1.success)

      %{
        total_tests: length(metrics),
        successful_tests: length(successful_tests),
        avg_duration_ms: avg(metrics, :duration_ms),
        avg_messages_per_second: avg(metrics, :messages_per_second),
        total_messages: Enum.sum(Enum.map(metrics, & &1.total_messages)),
        success_rate: Float.round(length(successful_tests) / length(metrics) * 100, 2),
        last_test_at: List.first(metrics).timestamp
      }
    end
  end

  defp avg(list, field) do
    if Enum.empty?(list) do
      0
    else
      sum = Enum.sum(Enum.map(list, &Map.get(&1, field)))
      Float.round(sum / length(list), 2)
    end
  end
end
