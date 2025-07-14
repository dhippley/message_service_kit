defmodule MessagingServiceWeb.ConversationLive.Index do
  @moduledoc """
  LiveView for displaying all conversations.
  """

  use MessagingServiceWeb, :live_view

  alias MessagingService.Conversations

  @default_per_page 12

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    pagination = Conversations.list_conversations_with_messages_paginated(page: page, per_page: @default_per_page)

    {:ok,
     socket
     |> assign(:conversations, pagination.conversations)
     |> assign(:pagination, pagination)
     |> assign(:current_path, "/conversations")
     |> assign(:page_title, "Conversations")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    pagination = Conversations.list_conversations_with_messages_paginated(page: page, per_page: @default_per_page)

    socket =
      socket
      |> assign(:conversations, pagination.conversations)
      |> assign(:pagination, pagination)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "All Conversations")
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    current_page = socket.assigns.pagination.page
    pagination = Conversations.list_conversations_with_messages_paginated(page: current_page, per_page: @default_per_page)

    {:noreply,
     socket
     |> assign(:conversations, pagination.conversations)
     |> assign(:pagination, pagination)}
  end

  @impl true
  def handle_event("goto_page", %{"page" => page_str}, socket) do
    page = String.to_integer(page_str)
    pagination = Conversations.list_conversations_with_messages_paginated(page: page, per_page: @default_per_page)

    {:noreply,
     socket
     |> assign(:conversations, pagination.conversations)
     |> assign(:pagination, pagination)
     |> push_patch(to: ~p"/conversations?page=#{page}")}
  end

  # Helper function to generate pagination range
  defp pagination_range(%{page: current_page, total_pages: total_pages}) do
    max_pages_to_show = 5

    cond do
      total_pages <= max_pages_to_show ->
        1..total_pages

      current_page <= 3 ->
        1..max_pages_to_show

      current_page >= total_pages - 2 ->
        (total_pages - max_pages_to_show + 1)..total_pages

      true ->
        (current_page - 2)..(current_page + 2)
    end
  end
end
