defmodule MessagingServiceWeb.ConversationLive.Show do
  @moduledoc """
  LiveView for displaying a single conversation with all its messages.
  """

  use MessagingServiceWeb, :live_view

  alias MessagingService.Conversations
  alias MessagingService.Conversation

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    case Conversations.get_conversation_with_messages(id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Conversation not found")
         |> push_navigate(to: ~p"/conversations")}

      conversation ->
        {:noreply,
         socket
         |> assign(:conversation, conversation)
         |> assign(:page_title, "Conversation Details")}
    end
  end

  defp render_conversation_participants(conversation) do
    participants = Conversation.get_participants(conversation)

    case {conversation.conversation_type, length(participants)} do
      {"group", count} when count > 2 ->
        render_group_participants(participants, count)

      {_, 2} ->
        render_direct_participants(participants)

      _ ->
        assigns = %{participants: participants}

        ~H"""
        <div class="flex items-center">
          <.icon name="hero-users" class="w-5 h-5 mr-3 text-purple-400" />
          <span class="text-purple-300">Unknown conversation</span>
        </div>
        """
    end
  end

  defp render_direct_participants([p1, p2]) do
    assigns = %{p1: format_participant_name(p1), p2: format_participant_name(p2)}

    ~H"""
    <div class="flex items-center">
      <.icon name="hero-users" class="w-5 h-5 mr-3 text-purple-400" />
      <span class="text-purple-300">{@p1}</span>
      <.icon name="hero-arrow-right" class="w-5 h-5 mx-3 text-gray-500" />
      <span class="text-pink-300">{@p2}</span>
    </div>
    """
  end

  defp render_group_participants(participants, count) do
    [first | _rest] = participants
    rest_count = count - 1

    assigns = %{
      first: format_participant_name(first),
      rest_count: rest_count,
      total_count: count
    }

    ~H"""
    <div class="flex items-center">
      <.icon name="hero-users" class="w-5 h-5 mr-3 text-emerald-400" />
      <span class="text-purple-300">{@first}</span>
      <span class="text-gray-400 mx-2">and</span>
      <span class="text-pink-300">{@rest_count} others</span>
      <span class="text-gray-500 ml-2">({@total_count} total)</span>
    </div>
    """
  end

  defp format_participant_name(participant) do
    cond do
      String.contains?(participant, "@") ->
        # Email format - show just the local part for brevity
        participant |> String.split("@") |> List.first()

      String.starts_with?(participant, "+") ->
        # Phone format - pretty print
        case String.replace(participant, ~r/\D/, "") do
          <<country_code::binary-size(1), area_code::binary-size(3), prefix::binary-size(3), number::binary-size(4)>> ->
            "+#{country_code} (#{area_code}) #{prefix}-#{number}"

          phone ->
            phone
        end

      true ->
        participant
    end
  end
end
