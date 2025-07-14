defmodule MessagingServiceWeb.ConversationComponent do
  @moduledoc """
  A reusable LiveView component for displaying conversations.

  This component can be used to display conversation cards with messages,
  participants, and status information.
  """

  use MessagingServiceWeb, :live_component

  alias Ecto.Association.NotLoaded
  alias MessagingService.Conversation

  @doc """
  Renders a conversation card component.

  ## Attributes

  * `conversation` - The conversation struct to display
  * `show_messages` - Boolean to show/hide message preview (default: true)
  * `clickable` - Boolean to make the card clickable (default: true)
  * `class` - Additional CSS classes to apply

  ## Examples

      <.live_component
        module={MessagingServiceWeb.ConversationComponent}
        id="conversation-123"
        conversation={%Conversation{}}
        show_messages={true}
        clickable={true}
      />
  """

  attr :conversation, :map, required: true
  attr :show_messages, :boolean, default: true
  attr :clickable, :boolean, default: true
  attr :class, :string, default: ""

  def render(assigns) do
    ~H"""
    <div class={[
      "backdrop-blur-sm bg-white/10 border border-white/20 rounded-2xl shadow-xl transition-all duration-300 group overflow-hidden relative",
      @clickable &&
        "hover:bg-white/15 hover:border-white/30 hover:shadow-2xl hover:scale-[1.02] cursor-pointer transform",
      @class
    ]}>
      <!-- Gradient overlay for extra visual interest -->
      <div class="absolute inset-0 bg-gradient-to-br from-purple-500/5 to-pink-500/5 opacity-0 group-hover:opacity-100 transition-opacity duration-300">
      </div>

      <div class="relative p-6">
        <!-- Header with participants -->
        <div class="flex items-start justify-between mb-4">
          <div class="flex-1 min-w-0">
            <h3 class="text-lg font-semibold text-white">
              {render_participants(@conversation)}
            </h3>
          </div>
        </div>

    <!-- Conversation metadata -->
        <div class="flex items-center justify-between text-sm text-gray-400 mb-4">
          <div class="flex items-center">
            <.icon name="hero-clock" class="w-4 h-4 mr-2 text-purple-400" />
            <span>{format_timestamp(@conversation.last_message_at)}</span>
          </div>

          <div class="flex items-center">
            <.icon name="hero-chat-bubble-left-right" class="w-4 h-4 mr-2 text-pink-400" />
            <span class="font-medium">{@conversation.message_count} messages</span>
          </div>
        </div>

    <!-- All messages -->
        <%= if @show_messages && has_loaded_messages?(@conversation) do %>
          <div class="mt-6 pt-4 border-t border-white/10">
            <h4 class="text-xs font-semibold text-gray-300 mb-3 flex items-center">
              <.icon name="hero-chat-bubble-oval-left" class="w-4 h-4 mr-2 text-purple-400" />
              All Messages
            </h4>
            <div class="space-y-3 h-96 overflow-y-auto custom-scrollbar">
              <%= for message <- @conversation.messages || [] do %>
                <.message_preview_card message={message} />
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- View Conversation Button -->
        <%= if @clickable do %>
          <div class="mt-6">
            <.link
              navigate={~p"/conversations/#{@conversation.id}"}
              class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-gradient-to-r from-purple-500/20 to-pink-500/20 border border-purple-500/30 rounded-lg hover:from-purple-500/30 hover:to-pink-500/30 hover:border-purple-400/50 transition-all duration-200 w-full justify-center group-hover:scale-105"
            >
              View Conversation <.icon name="hero-arrow-right" class="w-4 h-4 ml-2" />
            </.link>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Message preview card component
  attr :message, :map, required: true

  defp message_preview_card(assigns) do
    ~H"""
    <div class="flex items-start space-x-3 p-3 bg-white/5 border border-white/10 rounded-xl hover:bg-white/10 transition-all duration-200">
      <div class={[
        "px-2 py-1 rounded-lg text-xs font-semibold shrink-0 border",
        message_type_class(@message)
      ]}>
        {String.upcase(@message.type)}
      </div>

      <div class="flex-1 min-w-0">
        <div class="mb-1">
          <div class={[
            "text-[10px] font-medium truncate flex items-center",
            direction_color(@message.direction)
          ]}>
            {render_message_direction_info(@message)}
          </div>
          <span class="text-xs text-gray-400 font-medium">
            {format_message_time(@message.timestamp)}
          </span>
        </div>
        <p class="text-sm text-gray-200 line-clamp-2 leading-relaxed">
          {clean_message_body(@message.body, @message.type)}
        </p>

        <%= if @message.status do %>
          <div class="mt-2 flex items-center">
            <div class={[
              "w-2 h-2 rounded-full mr-2",
              status_indicator_color(@message.status)
            ]}>
            </div>
            <span class="text-xs text-gray-400 capitalize font-medium">
              {@message.status}
            </span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions

  # Renders participants based on conversation type (direct or group)
  defp render_participants(conversation) do
    participants = Conversation.get_participants(conversation)

    case {conversation.conversation_type, length(participants)} do
      {"group", count} when count > 2 ->
        render_group_participants(participants, count)

      {_, 2} ->
        render_direct_participants(participants)

      _ ->
        assigns = %{participants: participants}

        ~H"""
        <div class="flex flex-col space-y-2">
          <span class="text-purple-300 truncate flex items-center">
            <div class="w-2 h-2 bg-purple-400 rounded-full mr-2 animate-pulse"></div>
            Unknown conversation
          </span>
        </div>
        """
    end
  end

  # Renders direct conversation participants (2 people)
  defp render_direct_participants([p1, p2]) do
    assigns = %{p1: format_participant_name(p1), p2: format_participant_name(p2)}

    ~H"""
    <div class="flex flex-col space-y-2">
      <span class="text-purple-300 truncate flex items-center">
        <.icon name="hero-users" class="w-4 h-4 mr-2 text-purple-400" />
        {@p1}
      </span>
      <div class="flex items-center text-gray-400">
        <.icon name="hero-users" class="w-4 h-4 mr-2 text-gray-500" />
        <span class="text-pink-300 truncate">
          {@p2}
        </span>
      </div>
    </div>
    """
  end

  # Renders group conversation participants (3+ people)
  defp render_group_participants(participants, count) do
    [first, second | _rest] = participants
    rest_count = count - 1

    assigns = %{
      first: format_participant_name(first),
      second: format_participant_name(second),
      rest_count: rest_count
    }

    ~H"""
    <div class="flex flex-col space-y-2">
      <span class="text-purple-300 truncate flex items-center">
        <.icon name="hero-users" class="w-4 h-4 mr-2 text-emerald-400" />
        {@first}
      </span>
      <div class="flex items-center text-gray-400">
        <.icon name="hero-users" class="w-4 h-4 mr-2 text-gray-500" />
        <span class="text-pink-300 truncate">
          +{@rest_count} more ({@rest_count + 1} total)
        </span>
      </div>
    </div>
    """
  end

  # Formats a participant name/identifier for display
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

  defp format_timestamp(nil), do: "No activity"

  defp format_timestamp(timestamp) do
    now = NaiveDateTime.utc_now()
    diff_seconds = NaiveDateTime.diff(now, timestamp)

    cond do
      diff_seconds < 60 -> "Just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)}h ago"
      diff_seconds < 604_800 -> "#{div(diff_seconds, 86_400)}d ago"
      true -> Calendar.strftime(timestamp, "%b %d, %Y")
    end
  end

  defp format_message_time(timestamp) do
    Calendar.strftime(timestamp, "%I:%M %p")
  end

  defp message_type_class(message) do
    case message.type do
      "sms" -> "bg-blue-500/20 text-blue-300 border-blue-500/40"
      "mms" -> "bg-purple-500/20 text-purple-300 border-purple-500/40"
      "email" -> "bg-green-500/20 text-green-300 border-green-500/40"
      _ -> "bg-gray-500/20 text-gray-300 border-gray-500/40"
    end
  end

  defp direction_color(direction) do
    case direction do
      "inbound" -> "text-blue-300"
      "outbound" -> "text-green-300"
      _ -> "text-gray-300"
    end
  end

  defp render_message_direction_info(message) do
    case message.direction do
      "inbound" ->
        assigns = %{from: format_participant_name(message.from)}

        ~H"""
        <.icon name="hero-arrow-right" class="w-3 h-3 mr-1" />
        {@from}
        """

      "outbound" ->
        recipients = if is_list(message.to), do: message.to, else: [message.to]
        recipient_count = length(recipients)

        if recipient_count == 1 do
          assigns = %{to: format_participant_name(List.first(recipients))}

          ~H"""
          <.icon name="hero-arrow-left" class="w-3 h-3 mr-1" />
          {@to}
          """
        else
          assigns = %{count: recipient_count}

          ~H"""
          <.icon name="hero-arrow-left" class="w-3 h-3 mr-1" />
          {@count} recipients
          """
        end

      _ ->
        assigns = %{}

        ~H"""
        <.icon name="hero-question-mark-circle" class="w-3 h-3 mr-1" />
        Unknown
        """
    end
  end

  defp status_indicator_color(status) do
    case status do
      "sent" -> "bg-green-500"
      "received" -> "bg-blue-500"
      "delivered" -> "bg-blue-500"
      "failed" -> "bg-red-500"
      "queued" -> "bg-yellow-500"
      _ -> "bg-gray-500"
    end
  end

  defp has_loaded_messages?(conversation) do
    case conversation.messages do
      %NotLoaded{} -> false
      messages when is_list(messages) -> not Enum.empty?(messages)
      _ -> false
    end
  end

  defp clean_message_body(body, type) do
    case type do
      "email" -> strip_html_tags(body)
      _ -> body
    end
  end

  defp strip_html_tags(html_content) do
    html_content
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
