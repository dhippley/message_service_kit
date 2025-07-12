defmodule MessagingServiceWeb.ConversationLive.Index do
  @moduledoc """
  LiveView for displaying all conversations.
  """

  use MessagingServiceWeb, :live_view

  alias MessagingService.Conversations

  @impl true
  def mount(_params, _session, socket) do
    conversations = Conversations.list_conversations_with_messages()

    {:ok,
     socket
     |> assign(:conversations, conversations)
     |> assign(:page_title, "Conversations")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "All Conversations")
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    conversations = Conversations.list_conversations_with_messages()
    {:noreply, assign(socket, :conversations, conversations)}
  end
end
