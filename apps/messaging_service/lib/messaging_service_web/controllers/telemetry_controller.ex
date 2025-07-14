defmodule MessagingServiceWeb.TelemetryController do
  @moduledoc """
  Controller for exposing telemetry metrics and data via REST API.
  """

  use MessagingServiceWeb, :controller

  require Logger

  @doc """
  Get overview of message delivery metrics.
  Returns aggregated telemetry data for message delivery performance.
  """
  def message_delivery_overview(conn, _params) do
    # In a real implementation, you'd query your metrics storage system
    # (e.g., Prometheus, DataDog, InfluxDB, etc.)
    # For now, we'll return a structure showing what would be available

    overview = %{
      summary: %{
        total_messages_processed: get_counter_value("messaging_service.message_delivery.completed.count"),
        average_processing_time_ms: get_summary_value("messaging_service.message_delivery.completed.duration_ms", :mean),
        success_rate_percent: calculate_success_rate(),
        last_updated: DateTime.utc_now()
      },
      status_transitions: %{
        pending_to_queued: get_transition_metrics("pending", "queued"),
        queued_to_processing: get_transition_metrics("queued", "processing"),
        processing_to_sent: get_transition_metrics("processing", "sent"),
        processing_to_failed: get_transition_metrics("processing", "failed")
      },
      by_message_type: %{
        sms: get_metrics_by_type("sms"),
        email: get_metrics_by_type("email"),
        mms: get_metrics_by_type("mms")
      },
      recent_activity: get_recent_activity_summary()
    }

    json(conn, overview)
  end

  @doc """
  Get detailed metrics for a specific message type.
  """
  def message_type_metrics(conn, %{"type" => message_type}) do
    case message_type do
      type when type in ["sms", "email", "mms"] ->
        metrics = get_detailed_metrics_by_type(type)
        json(conn, metrics)

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid message type. Must be one of: sms, email, mms"})
    end
  end

  @doc """
  Get telemetry health status and system metrics.
  """
  def health(conn, _params) do
    health_data = %{
      status: "healthy",
      timestamp: DateTime.utc_now(),
      telemetry: %{
        handlers_attached: count_attached_handlers(),
        events_processed_last_minute: get_events_processed_count(),
        metrics_collection_active: true
      },
      system: %{
        memory_usage_kb: get_vm_memory(),
        run_queue_lengths: get_run_queue_lengths(),
        database_connections: get_db_connection_info()
      }
    }

    json(conn, health_data)
  end

  @doc """
  Get performance trends over time.
  """
  def performance_trends(conn, params) do
    timeframe = Map.get(params, "timeframe", "1h") # 1h, 24h, 7d, 30d

    trends = %{
      timeframe: timeframe,
      generated_at: DateTime.utc_now(),
      metrics: %{
        throughput: get_throughput_trend(timeframe),
        latency: get_latency_trend(timeframe),
        error_rate: get_error_rate_trend(timeframe),
        status_distribution: get_status_distribution_trend(timeframe)
      }
    }

    json(conn, trends)
  end

  @doc """
  Get real-time telemetry stream endpoint info.
  For WebSocket or Server-Sent Events implementation.
  """
  def realtime_info(conn, _params) do
    info = %{
      websocket_endpoint: "/api/telemetry/stream",
      supported_events: [
        "message_delivery.status_transition",
        "message_delivery.completed",
        "message_delivery.batch_enqueued"
      ],
      update_frequency_ms: 1000,
      connection_info: %{
        max_connections: 100,
        current_connections: 0, # Would track actual connections
        auth_required: false
      }
    }

    json(conn, info)
  end

  @doc """
  Get API documentation for telemetry endpoints.
  """
  def api_docs(conn, _params) do
    docs = %{
      title: "Messaging Service Telemetry API",
      version: "1.0.0",
      description: "REST API for accessing telemetry metrics and performance data",
      base_url: "/api/telemetry",
      endpoints: [
        %{
          path: "/health",
          method: "GET",
          description: "Get telemetry system health status and VM metrics",
          response_example: %{
            status: "healthy",
            timestamp: "2025-07-14T08:26:14.144760Z",
            telemetry: %{
              handlers_attached: 7,
              events_processed_last_minute: 768,
              metrics_collection_active: true
            },
            system: %{
              memory_usage_kb: 85473,
              run_queue_lengths: %{total: 0, cpu: 0, io: 0},
              database_connections: %{pool_size: 10, checked_out: 2, available: 8}
            }
          }
        },
        %{
          path: "/messages/overview",
          method: "GET",
          description: "Get comprehensive overview of message delivery metrics",
          response_fields: [
            "summary - aggregate metrics (total processed, avg time, success rate)",
            "status_transitions - timing for each status change",
            "by_message_type - breakdown by SMS/email/MMS",
            "recent_activity - last 5 minutes and hour activity"
          ]
        },
        %{
          path: "/messages/:type",
          method: "GET",
          description: "Get detailed metrics for specific message type",
          parameters: %{
            type: "Message type (sms, email, mms)"
          },
          response_fields: [
            "counts - total, success, failure counts and rates",
            "status_transitions - timing breakdown by status change",
            "provider_breakdown - metrics by provider",
            "hourly_trends - 24 hours of historical data"
          ]
        },
        %{
          path: "/trends",
          method: "GET",
          description: "Get performance trends over time",
          parameters: %{
            timeframe: "Time range (1h, 24h, 7d, 30d) - optional, defaults to 1h"
          },
          response_fields: [
            "throughput - messages and bytes per hour",
            "latency - p50, p95, p99 latency trends",
            "error_rate - error percentage over time",
            "status_distribution - count of messages in each status"
          ]
        },
        %{
          path: "/realtime",
          method: "GET",
          description: "Get information about real-time telemetry streaming",
          response_fields: [
            "websocket_endpoint - future WebSocket endpoint for live data",
            "supported_events - list of available real-time events",
            "connection_info - limits and requirements"
          ]
        }
      ],
      notes: [
        "All timestamps are in UTC ISO 8601 format",
        "Duration metrics are in milliseconds",
        "Rates and percentages are floating point numbers",
        "This is currently returning mock data for demonstration"
      ]
    }

    json(conn, docs)
  end

  @doc """
  Get stress test metrics from MockProvider.
  """
  def stress_test_metrics(conn, _params) do
    # Get stress test data from MockProvider.Telemetry
    try do
      summary = MockProvider.Telemetry.get_metrics_summary()
      recent_tests = MockProvider.Telemetry.get_stress_test_metrics() |> Enum.take(10)

      metrics = %{
        summary: summary,
        recent_tests: recent_tests,
        timestamp: DateTime.utc_now()
      }

      json(conn, metrics)
    rescue
      error ->
        Logger.error("Failed to fetch stress test metrics: #{inspect(error)}")

        conn
        |> put_status(:service_unavailable)
        |> json(%{
          error: "Stress test metrics unavailable",
          details: Exception.message(error),
          timestamp: DateTime.utc_now()
        })
    end
  end

  # Private helper functions
  # In a real implementation, these would query your metrics storage system

  defp get_counter_value(_metric_name) do
    # Get actual total messages processed from telemetry collector
    MessagingServiceWeb.TelemetryCollector.get_total_messages_processed()
  end

  defp get_summary_value(_metric_name, _statistic) do
    # Get actual average processing time from telemetry collector
    MessagingServiceWeb.TelemetryCollector.get_average_processing_time()
  end

  defp calculate_success_rate do
    # Get actual success rate from telemetry collector
    MessagingServiceWeb.TelemetryCollector.get_success_rate()
  end

  defp get_transition_metrics(from_status, to_status) do
    # Get actual transition metrics from telemetry collector
    MessagingServiceWeb.TelemetryCollector.get_transition_metrics(from_status, to_status)
  end

  defp get_metrics_by_type(message_type) do
    # Get actual metrics by type from telemetry collector
    MessagingServiceWeb.TelemetryCollector.get_metrics_by_type(message_type)
  end

  defp get_detailed_metrics_by_type(message_type) do
    %{
      message_type: message_type,
      timestamp: DateTime.utc_now(),
      counts: get_metrics_by_type(message_type),
      status_transitions: %{
        "pending_to_queued" => get_transition_metrics("pending", "queued"),
        "queued_to_processing" => get_transition_metrics("queued", "processing"),
        "processing_to_sent" => get_transition_metrics("processing", "sent"),
        "processing_to_failed" => get_transition_metrics("processing", "failed")
      },
      provider_breakdown: get_provider_breakdown(message_type),
      hourly_trends: get_hourly_trends(message_type)
    }
  end

  defp get_provider_breakdown(message_type) do
    # TODO: Implement provider-specific metrics collection
    # For now, return zero counts for known providers
    case message_type do
      "sms" ->
        %{
          "twilio" => %{count: 0, success_rate: 0},
          "aws_sns" => %{count: 0, success_rate: 0}
        }
      "email" ->
        %{
          "sendgrid" => %{count: 0, success_rate: 0},
          "aws_ses" => %{count: 0, success_rate: 0}
        }
      _ ->
        %{}
    end
  end

  defp get_hourly_trends(_message_type) do
    # TODO: Implement actual hourly trends from telemetry collector
    # For now, return 24 hours of zero data
    for hour <- 0..23 do
      %{
        hour: hour,
        count: 0,
        avg_duration_ms: 0,
        success_rate: 0
      }
    end
  end

  defp get_recent_activity_summary do
    # Get actual recent activity from telemetry collector
    MessagingServiceWeb.TelemetryCollector.get_recent_activity_summary()
  end

  defp count_attached_handlers do
    # Count actual telemetry handlers
    :telemetry.list_handlers([])
    |> Enum.filter(fn %{id: id} -> is_binary(id) and String.contains?(id, "messaging") end)
    |> length()
  end

  defp get_events_processed_count do
    # Get actual events processed from telemetry collector
    MessagingServiceWeb.TelemetryCollector.get_total_messages_processed()
  end

  defp get_vm_memory do
    case :erlang.memory(:total) do
      memory when is_integer(memory) -> div(memory, 1024)
      _ -> 0
    end
  end

  defp get_run_queue_lengths do
    %{
      total: :erlang.statistics(:run_queue),
      cpu: :erlang.statistics(:run_queue),
      io: 0
    }
  end

  defp get_db_connection_info do
    # Placeholder - would get actual DB pool info
    %{
      pool_size: 10,
      checked_out: 2,
      available: 8
    }
  end

  defp get_throughput_trend(_timeframe) do
    # TODO: Generate actual trend data from telemetry storage
    # For now, return 24 hours of zero data
    for i <- 1..24 do
      %{
        timestamp: DateTime.add(DateTime.utc_now(), -i * 3600, :second),
        messages_per_hour: 0,
        bytes_per_hour: 0
      }
    end
  end

  defp get_latency_trend(_timeframe) do
    # TODO: Generate actual latency trends from telemetry data
    # For now, return 24 hours of zero data
    for i <- 1..24 do
      %{
        timestamp: DateTime.add(DateTime.utc_now(), -i * 3600, :second),
        p50_ms: 0,
        p95_ms: 0,
        p99_ms: 0
      }
    end
  end

  defp get_error_rate_trend(_timeframe) do
    # TODO: Generate actual error rate trends from telemetry data
    # For now, return 24 hours of zero data
    for i <- 1..24 do
      %{
        timestamp: DateTime.add(DateTime.utc_now(), -i * 3600, :second),
        error_rate_percent: 0,
        total_errors: 0
      }
    end
  end

  defp get_status_distribution_trend(_timeframe) do
    # TODO: Generate actual status distribution from telemetry data
    # For now, return 24 hours of zero data
    for i <- 1..24 do
      %{
        timestamp: DateTime.add(DateTime.utc_now(), -i * 3600, :second),
        pending: 0,
        queued: 0,
        processing: 0,
        sent: 0,
        failed: 0
      }
    end
  end
end
