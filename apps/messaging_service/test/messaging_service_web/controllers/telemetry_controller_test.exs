defmodule MessagingServiceWeb.TelemetryControllerTest do
  @moduledoc """
  Tests for the TelemetryController endpoints.
  """

  use MessagingServiceWeb.ConnCase

  describe "GET /api/telemetry" do
    test "returns API documentation", %{conn: conn} do
      conn = get(conn, ~p"/api/telemetry")

      assert json_response(conn, 200)
      response = json_response(conn, 200)

      assert response["title"] == "Messaging Service Telemetry API"
      assert response["version"] == "1.0.0"
      assert is_list(response["endpoints"])
      assert length(response["endpoints"]) > 0
    end
  end

  describe "GET /api/telemetry/health" do
    test "returns health status", %{conn: conn} do
      conn = get(conn, ~p"/api/telemetry/health")

      assert json_response(conn, 200)
      response = json_response(conn, 200)

      assert response["status"] == "healthy"
      assert Map.has_key?(response, "timestamp")
      assert Map.has_key?(response, "telemetry")
      assert Map.has_key?(response, "system")

      # Check telemetry section
      telemetry = response["telemetry"]
      assert is_integer(telemetry["handlers_attached"])
      assert is_integer(telemetry["events_processed_last_minute"])
      assert is_boolean(telemetry["metrics_collection_active"])

      # Check system section
      system = response["system"]
      assert is_integer(system["memory_usage_kb"])
      assert Map.has_key?(system, "run_queue_lengths")
      assert Map.has_key?(system, "database_connections")
    end
  end

  describe "GET /api/telemetry/messages/overview" do
    test "returns message delivery overview", %{conn: conn} do
      conn = get(conn, ~p"/api/telemetry/messages/overview")

      assert json_response(conn, 200)
      response = json_response(conn, 200)

      assert Map.has_key?(response, "summary")
      assert Map.has_key?(response, "status_transitions")
      assert Map.has_key?(response, "by_message_type")
      assert Map.has_key?(response, "recent_activity")

      # Check summary section
      summary = response["summary"]
      assert is_integer(summary["total_messages_processed"])
      assert is_number(summary["average_processing_time_ms"])
      assert is_number(summary["success_rate_percent"])

      # Check status transitions
      transitions = response["status_transitions"]
      assert Map.has_key?(transitions, "pending_to_queued")
      assert Map.has_key?(transitions, "queued_to_processing")
      assert Map.has_key?(transitions, "processing_to_sent")
      assert Map.has_key?(transitions, "processing_to_failed")
    end
  end

  describe "GET /api/telemetry/messages/:type" do
    test "returns metrics for valid message type", %{conn: conn} do
      conn = get(conn, ~p"/api/telemetry/messages/sms")

      assert json_response(conn, 200)
      response = json_response(conn, 200)

      assert response["message_type"] == "sms"
      assert Map.has_key?(response, "counts")
      assert Map.has_key?(response, "status_transitions")
      assert Map.has_key?(response, "provider_breakdown")
      assert Map.has_key?(response, "hourly_trends")

      # Check hourly trends is a list
      hourly_trends = response["hourly_trends"]
      assert is_list(hourly_trends)
      assert length(hourly_trends) == 24
    end

    test "returns error for invalid message type", %{conn: conn} do
      conn = get(conn, ~p"/api/telemetry/messages/invalid")

      assert json_response(conn, 400)
      response = json_response(conn, 400)

      assert response["error"] == "Invalid message type. Must be one of: sms, email, mms"
    end
  end

  describe "GET /api/telemetry/trends" do
    test "returns performance trends", %{conn: conn} do
      conn = get(conn, ~p"/api/telemetry/trends")

      assert json_response(conn, 200)
      response = json_response(conn, 200)

      # default
      assert response["timeframe"] == "1h"
      assert Map.has_key?(response, "generated_at")
      assert Map.has_key?(response, "metrics")

      metrics = response["metrics"]
      assert Map.has_key?(metrics, "throughput")
      assert Map.has_key?(metrics, "latency")
      assert Map.has_key?(metrics, "error_rate")
      assert Map.has_key?(metrics, "status_distribution")
    end

    test "accepts custom timeframe parameter", %{conn: conn} do
      conn = get(conn, ~p"/api/telemetry/trends?timeframe=24h")

      assert json_response(conn, 200)
      response = json_response(conn, 200)

      assert response["timeframe"] == "24h"
    end
  end

  describe "GET /api/telemetry/realtime" do
    test "returns realtime streaming info", %{conn: conn} do
      conn = get(conn, ~p"/api/telemetry/realtime")

      assert json_response(conn, 200)
      response = json_response(conn, 200)

      assert response["websocket_endpoint"] == "/api/telemetry/stream"
      assert is_list(response["supported_events"])
      assert is_integer(response["update_frequency_ms"])
      assert Map.has_key?(response, "connection_info")
    end
  end
end
