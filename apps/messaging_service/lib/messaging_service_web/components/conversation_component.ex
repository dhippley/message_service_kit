defmodule MessagingServiceWeb.ConversationComponent do
  @moduledoc """
  A reusable LiveView component for displaying conversations.

  This component can be used to display conversation cards with messages,
  participants, and status information.
  """

  use MessagingServiceWeb, :live_component

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
      "bg-white overflow-hidden shadow rounded-lg border border-gray-200 transition-all duration-200",
      @clickable && "hover:shadow-md hover:border-gray-300 cursor-pointer",
      @class
    ]}>
      <div class="p-5">
        <!-- Header with participants -->
        <div class="flex items-start justify-between">
          <div class="flex-1 min-w-0">
            <h3 class="text-base font-medium text-gray-900">
              <div class="flex flex-col space-y-1">
                <span class="text-blue-600 truncate"><%= format_participant(@conversation.participant_one) %></span>
                <div class="flex items-center text-gray-400">
                  <.icon name="hero-arrow-down" class="w-3 h-3 mr-1" />
                  <span class="text-green-600 truncate"><%= format_participant(@conversation.participant_two) %></span>
                </div>
              </div>
            </h3>
            <%= if @show_messages do %>
              <p class="mt-2 text-sm text-gray-500 line-clamp-2">
                <%= message_preview(@conversation.messages) %>
              </p>
            <% end %>
          </div>

          <!-- Status badge -->
          <div class={[
            "ml-3 flex-shrink-0 px-2 py-1 text-xs font-medium rounded-full",
            conversation_status_class(@conversation.messages)
          ]}>
            <%= conversation_status_text(@conversation) %>
          </div>
        </div>

        <!-- Conversation metadata -->
        <div class="mt-4 flex flex-col space-y-2 text-sm text-gray-500">
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <.icon name="hero-clock" class="w-4 h-4 mr-1" />
              <span class="truncate"><%= format_timestamp(@conversation.last_message_at) %></span>
            </div>

            <div class="flex items-center">
              <.icon name="hero-chat-bubble-left-right" class="w-4 h-4 mr-1" />
              <%= @conversation.message_count %>
            </div>
          </div>

          <%= if @clickable do %>
            <.link
              navigate={~p"/conversations/#{@conversation.id}"}
              class="text-blue-600 hover:text-blue-900 font-medium transition-colors text-center py-1"
            >
              View Details →
            </.link>
          <% end %>
        </div>

        <!-- Recent messages preview -->
        <%= if @show_messages && has_loaded_messages?(@conversation) do %>
          <div class="mt-4 border-t pt-3">
            <h4 class="text-xs font-medium text-gray-700 mb-2 flex items-center">
              <.icon name="hero-chat-bubble-oval-left" class="w-3 h-3 mr-1" />
              Recent
            </h4>
            <div class="space-y-2 max-h-32 overflow-y-auto">
              <%= for message <- Enum.take(@conversation.messages || [], -2) do %>
                <.message_preview_card message={message} />
              <% end %>
            </div>
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
    <div class="flex items-start space-x-2 p-2 bg-gray-50 rounded-md">
      <div class={[
        "px-1.5 py-0.5 rounded text-xs font-medium shrink-0",
        message_type_class(@message)
      ]}>
        <%= String.upcase(@message.type) %>
      </div>

      <div class="flex-1 min-w-0">
        <div class="flex items-center justify-between">
          <span class={[
            "text-xs font-medium truncate",
            direction_color(@message.direction)
          ]}>
            <%= direction_label(@message.direction) %>
          </span>
          <span class="text-xs text-gray-500 ml-2">
            <%= format_message_time(@message.timestamp) %>
          </span>        </div>
        <p class="text-xs text-gray-900 mt-0.5 line-clamp-2">
          <%= clean_message_body(@message.body, @message.type) %>
        </p>

        <%= if @message.status do %>
          <div class="mt-1 flex items-center">
            <div class={[
              "w-1.5 h-1.5 rounded-full mr-1",
              status_indicator_color(@message.status)
            ]}>
            </div>
            <span class="text-xs text-gray-500 capitalize">
              <%= @message.status %>
            </span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions

  defp format_participant(participant) do
    cond do
      String.contains?(participant, "@") ->
        # Email format - show just the local part for brevity
        participant |> String.split("@") |> List.first()

      String.starts_with?(participant, "+") ->
        # Phone format - pretty print
        case String.replace(participant, ~r/\D/, "") do
          <<country_code::binary-size(1), area_code::binary-size(3), prefix::binary-size(3), number::binary-size(4)>> ->
            "+#{country_code} (#{area_code}) #{prefix}-#{number}"
          phone -> phone
        end

      true -> participant
    end
  end

  defp format_timestamp(nil), do: "No activity"
  defp format_timestamp(timestamp) do
    now = NaiveDateTime.utc_now()
    diff_seconds = NaiveDateTime.diff(now, timestamp)

    cond do
      diff_seconds < 60 -> "Just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      diff_seconds < 604800 -> "#{div(diff_seconds, 86400)}d ago"
      true -> Calendar.strftime(timestamp, "%b %d, %Y")
    end
  end

  defp format_message_time(timestamp) do
    Calendar.strftime(timestamp, "%I:%M %p")
  end

  defp message_preview(messages) when is_list(messages) and length(messages) > 0 do
    last_message = List.last(messages)

    clean_body = clean_message_body(last_message.body, last_message.type)

    preview = if String.length(clean_body) > 60 do
      String.slice(clean_body, 0, 60) <> "..."
    else
      clean_body
    end

    "#{direction_label(last_message.direction)}: #{preview}"
  end
  defp message_preview(%Ecto.Association.NotLoaded{}), do: "Messages not loaded"
  defp message_preview(_), do: "No messages yet"

  defp conversation_status_class(messages) when is_list(messages) and length(messages) > 0 do
    last_message = List.last(messages)

    case last_message.direction do
      "inbound" -> "bg-blue-100 text-blue-800"
      "outbound" -> "bg-green-100 text-green-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
  defp conversation_status_class(%Ecto.Association.NotLoaded{}), do: "bg-gray-100 text-gray-800"
  defp conversation_status_class(_), do: "bg-gray-100 text-gray-800"

  defp conversation_status_text(conversation) do
    case conversation.message_count do
      0 -> "New"
      count when count < 5 -> "Active"
      _ -> "#{conversation.message_count} msgs"
    end
  end

  defp message_type_class(message) do
    case message.type do
      "sms" -> "bg-blue-100 text-blue-800"
      "mms" -> "bg-purple-100 text-purple-800"
      "email" -> "bg-green-100 text-green-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp direction_color(direction) do
    case direction do
      "inbound" -> "text-blue-600"
      "outbound" -> "text-green-600"
      _ -> "text-gray-600"
    end
  end

  defp direction_label(direction) do
    case direction do
      "inbound" -> "Received"
      "outbound" -> "Sent"
      _ -> "Unknown"
    end
  end

  defp status_indicator_color(status) do
    case status do
      "sent" -> "bg-green-500"
      "delivered" -> "bg-blue-500"
      "failed" -> "bg-red-500"
      "queued" -> "bg-yellow-500"
      _ -> "bg-gray-500"
    end
  end

  defp has_loaded_messages?(conversation) do
    case conversation.messages do
      %Ecto.Association.NotLoaded{} -> false
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
