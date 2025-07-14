defmodule MessagingServiceWeb.DashboardLiveTest do
  @moduledoc """
  Tests for the Dashboard LiveView.
  """

  use MessagingServiceWeb.ConnCase
  import Phoenix.LiveViewTest

  @tag :not_implemented
  test "dashboard renders with loading state", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/dashboard")

    # Should show loading state initially
    assert html =~ "Loading metrics..."
    assert html =~ "Message Delivery Dashboard"

    # Should have the page title
    assert page_title(view) =~ "Dashboard"
  end

  @tag :not_implemented
  test "dashboard has refresh button", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")

    # Should have refresh button
    assert html =~ "Refresh"
    assert html =~ "phx-click=\"refresh\""
  end

  @tag :not_implemented
  test "dashboard has timeframe selector", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")

    # Should have timeframe selector
    assert html =~ "phx-change=\"change_timeframe\""
    assert html =~ "Last Hour"
    assert html =~ "Last 24 Hours"
  end

  @tag :not_implemented
  test "dashboard shows auto-refresh indicator", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")

    # Should show auto-refresh indicator
    assert html =~ "Auto-refreshing every 5 seconds"
    assert html =~ "animate-pulse"
  end
end
