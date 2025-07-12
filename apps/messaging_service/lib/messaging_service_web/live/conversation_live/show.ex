defmodule MessagingServiceWeb.ConversationLive.Show do
  @moduledoc """
  LiveView for displaying a single conversation with all its messages.
  """

  use MessagingServiceWeb, :live_view

  alias MessagingService.Conversations

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    conversation = Conversations.get_conversation_with_messages!(id)
    
    {:noreply,
     socket
     |> assign(:conversation, conversation)
     |> assign(:page_title, "Conversation Details")
    }
  end

  defp format_participant(participant) do
    if String.contains?(participant, "@") do
      # Email format
      participant
    else
      # Phone format - pretty print
      case String.replace(participant, ~r/\D/, "") do
        <<"+", rest::binary>> -> "+#{rest}"
        <<country_code::binary-size(1), area_code::binary-size(3), prefix::binary-size(3), number::binary-size(4)>> ->
          "+#{country_code} (#{area_code}) #{prefix}-#{number}"
        phone -> phone
      end
    end
  end
end
