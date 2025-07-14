defmodule MessagingServiceWeb.DashboardLive do
  @moduledoc """
  LiveView for the telemetry dashboard displaying message delivery metrics.
  """

  use MessagingServiceWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Schedule periodic updates every 5 seconds
      :timer.send_interval(5000, self(), :update_metrics)
    end

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:current_path, "/dashboard")
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> load_initial_data()

    {:ok, socket}
  end

  @impl true
  def handle_info(:update_metrics, socket) do
    socket = load_telemetry_data(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    socket =
      socket
      |> assign(:loading, true)
      |> load_telemetry_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_timeframe", %{"timeframe" => timeframe}, socket) do
    socket =
      socket
      |> assign(:selected_timeframe, timeframe)
      |> assign(:loading, true)
      |> load_trends_data(timeframe)

    {:noreply, socket}
  end

  defp load_initial_data(socket) do
    socket
    |> assign(:selected_timeframe, "1h")
    |> load_telemetry_data()
  end

  defp load_telemetry_data(socket) do
    case fetch_telemetry_overview() do
      {:ok, overview} ->
        socket
        |> assign(:overview, overview)
        |> assign(:loading, false)
        |> assign(:error, nil)
        |> load_health_data()
        |> load_stress_test_data()
        |> load_queue_data()
        |> load_trends_data(socket.assigns[:selected_timeframe] || "1h")

      {:error, reason} ->
        socket
        |> assign(:loading, false)
        |> assign(:error, "Failed to load telemetry data: #{reason}")
    end
  end

  defp load_health_data(socket) do
    case fetch_health_data() do
      {:ok, health} ->
        assign(socket, :health, health)

      {:error, _reason} ->
        assign(socket, :health, %{status: "unknown"})
    end
  end

  defp load_trends_data(socket, timeframe) do
    case fetch_trends_data(timeframe) do
      {:ok, trends} ->
        assign(socket, :trends, trends)

      {:error, _reason} ->
        assign(socket, :trends, %{})
    end
  end

  defp load_stress_test_data(socket) do
    case fetch_stress_test_data() do
      {:ok, stress_data} ->
        assign(socket, :stress_tests, stress_data)

      {:error, _reason} ->
        assign(socket, :stress_tests, %{summary: %{}, recent_tests: []})
    end
  end

  defp load_queue_data(socket) do
    case fetch_queue_data() do
      {:ok, queue_data} ->
        assign(socket, :queue_metrics, queue_data)

      {:error, _reason} ->
        assign(socket, :queue_metrics, %{queues: %{}, summary: %{}, recent_jobs: []})
    end
  end

  # HTTP client functions to call our telemetry endpoints
  defp fetch_telemetry_overview do
    case Req.get("http://localhost:4000/api/telemetry/messages/overview") do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp fetch_health_data do
    case Req.get("http://localhost:4000/api/telemetry/health") do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:error, _} ->
        {:error, "Failed to fetch health data"}
    end
  rescue
    _error -> {:error, "Health check failed"}
  end

  defp fetch_trends_data(timeframe) do
    url = "http://localhost:4000/api/telemetry/trends"

    case Req.get(url, params: [timeframe: timeframe]) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:error, _} ->
        {:error, "Failed to fetch trends data"}
    end
  rescue
    _error -> {:error, "Trends fetch failed"}
  end

  defp fetch_stress_test_data do
    case Req.get("http://localhost:4000/api/telemetry/stress-tests") do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:error, _} ->
        {:error, "Failed to fetch stress test data"}
    end
  rescue
    _error -> {:error, "Stress test fetch failed"}
  end

  defp fetch_queue_data do
    case Req.get("http://localhost:4000/api/telemetry/queue") do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:error, _} ->
        {:error, "Failed to fetch queue data"}
    end
  rescue
    _error -> {:error, "Queue fetch failed"}
  end

  # Helper functions for display
  defp format_number(number) when is_integer(number) do
    # Simple number formatting without external dependency
    number |> Integer.to_string() |> add_commas()
  end

  defp format_number(number) when is_float(number) do
    # Format float with 1 decimal place
    number |> :erlang.float_to_binary(decimals: 1) |> add_commas()
  end

  defp format_number(_), do: "N/A"

  defp add_commas(str) do
    # Simple comma addition for thousands
    str
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_percentage(percentage) when is_number(percentage) do
    "#{:erlang.float_to_binary(percentage * 1.0, decimals: 1)}%"
  end

  defp format_percentage(_), do: "N/A"

  defp format_duration(ms) when is_number(ms) do
    cond do
      ms < 1000 -> "#{round(ms)}ms"
      ms < 60_000 -> "#{:erlang.float_to_binary(ms / 1000, decimals: 1)}s"
      true -> "#{round(ms / 60_000)}m"
    end
  end

  defp format_duration(_), do: "N/A"

  defp status_color("healthy"), do: "text-green-400"
  defp status_color("warning"), do: "text-yellow-400"
  defp status_color("error"), do: "text-red-400"
  defp status_color(_), do: "text-gray-400"

  # Define the preferred order for status transitions
  @transition_order [
    "pending_to_queued",
    "queued_to_processing",
    "processing_to_sent",
    "processing_to_failed"
  ]

  defp sort_status_transitions(status_transitions) when is_map(status_transitions) do
    # Convert to list of tuples and sort by the predefined order
    status_transitions
    |> Enum.to_list()
    |> Enum.sort_by(fn {transition, _metrics} ->
      case Enum.find_index(@transition_order, &(&1 == transition)) do
        # Unknown transitions go to the end
        nil -> 999
        index -> index
      end
    end)
  end

  defp sort_status_transitions(_), do: []

  defp transition_badge_color(transition) do
    case transition do
      "pending_to_queued" -> "bg-blue-500/20 text-blue-300 border-blue-500/30"
      "queued_to_processing" -> "bg-yellow-500/20 text-yellow-300 border-yellow-500/30"
      "processing_to_sent" -> "bg-green-500/20 text-green-300 border-green-500/30"
      "processing_to_failed" -> "bg-red-500/20 text-red-300 border-red-500/30"
      _ -> "bg-gray-500/20 text-gray-300 border-gray-500/30"
    end
  end

  defp transition_label(transition) do
    case transition do
      "pending_to_queued" -> "Pending → Queued"
      "queued_to_processing" -> "Queued → Processing"
      "processing_to_sent" -> "Processing → Sent"
      "processing_to_failed" -> "Processing → Failed"
      _ -> transition |> String.replace("_", " ") |> String.replace(" to ", " → ")
    end
  end

  defp format_test_duration(duration_ms) when is_number(duration_ms) do
    cond do
      duration_ms < 1000 -> "#{round(duration_ms)}ms"
      duration_ms < 60_000 -> "#{:erlang.float_to_binary(duration_ms / 1000, decimals: 1)}s"
      duration_ms < 3_600_000 -> "#{round(duration_ms / 60_000)}m"
      true -> "#{round(duration_ms / 3_600_000)}h"
    end
  end

  defp format_test_duration(_), do: "N/A"

  defp format_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} ->
        dt
        |> DateTime.to_naive()
        |> NaiveDateTime.to_string()
        # Remove microseconds
        |> String.slice(0, 19)

      _ ->
        timestamp
    end
  end

  defp format_timestamp(_), do: "N/A"

  defp stress_test_status_color(true), do: "text-green-400"
  defp stress_test_status_color(false), do: "text-red-400"
  defp stress_test_status_color(_), do: "text-gray-400"

  # Queue-specific helper functions
  defp queue_health_color("healthy"), do: "text-green-400"
  defp queue_health_color("warning"), do: "text-yellow-400"
  defp queue_health_color("unhealthy"), do: "text-red-400"
  defp queue_health_color(_), do: "text-gray-400"

  defp queue_status_color(queue) when is_map(queue) do
    executing = queue["executing"] || 0
    limit = queue["limit"] || 1
    retryable = queue["retryable"] || 0

    utilization = executing / limit

    cond do
      retryable > 10 -> "border-red-500/30 bg-red-500/10"
      utilization > 0.8 -> "border-yellow-500/30 bg-yellow-500/10"
      utilization > 0.5 -> "border-blue-500/30 bg-blue-500/10"
      true -> "border-green-500/30 bg-green-500/10"
    end
  end

  defp queue_status_color(_), do: "border-gray-500/30 bg-gray-500/10"

  defp job_state_color("available"), do: "text-blue-400"
  defp job_state_color("executing"), do: "text-orange-400"
  defp job_state_color("retryable"), do: "text-yellow-400"
  defp job_state_color("scheduled"), do: "text-purple-400"
  defp job_state_color("completed"), do: "text-green-400"
  defp job_state_color("discarded"), do: "text-red-400"
  defp job_state_color(_), do: "text-gray-400"

  defp format_worker_name(worker) when is_binary(worker) do
    worker
    |> String.split(".")
    |> List.last()
    |> String.replace("Worker", "")
  end

  defp format_worker_name(_), do: "Unknown"
end
