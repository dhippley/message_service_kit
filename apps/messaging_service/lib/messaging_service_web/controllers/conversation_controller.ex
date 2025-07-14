defmodule MessagingServiceWeb.ConversationController do
  @moduledoc """
  Controller for managing conversations and retrieving messages.

  This controller provides endpoints to list conversations and retrieve
  messages within a specific conversation.
  """

  use MessagingServiceWeb, :controller

  alias MessagingService.Conversations

  require Logger

  @doc """
  Lists all conversations.

  Returns a JSON response with all conversations in the system.
  """
  def index(conn, _params) do
    Logger.info("Retrieving all conversations")

    try do
      conversations = Conversations.list_conversations_with_messages()

      formatted_conversations =
        Enum.map(conversations, fn conversation ->
          latest_message = List.last(conversation.messages)

          %{
            id: conversation.id,
            participant_one: conversation.participant_one,
            participant_two: conversation.participant_two,
            last_message_at: conversation.last_message_at,
            message_count: conversation.message_count,
            latest_message: format_message(latest_message)
          }
        end)

      conn
      |> put_status(:ok)
      |> json(%{
        success: true,
        data: formatted_conversations,
        count: length(formatted_conversations)
      })
    rescue
      error ->
        Logger.error("Failed to retrieve conversations: #{inspect(error)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve conversations"
        })
    end
  end

  @doc """
  Shows all messages in a specific conversation.

  Returns a JSON response with all messages belonging to the specified conversation ID.
  """
  def show_messages(conn, %{"id" => conversation_id}) do
    Logger.info("Retrieving messages for conversation #{conversation_id}")

    try do
      case Conversations.get_conversation_with_messages(conversation_id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{
            success: false,
            error: "Conversation not found"
          })

        conversation ->
          formatted_messages =
            Enum.map(conversation.messages, fn message ->
              %{
                id: message.id,
                type: message.type,
                body: message.body,
                to: message.to,
                from: message.from,
                timestamp: message.timestamp
              }
            end)

          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            conversation_id: conversation.id,
            data: formatted_messages,
            count: length(formatted_messages)
          })
      end
    rescue
      error ->
        Logger.error("Failed to retrieve messages for conversation #{conversation_id}: #{inspect(error)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve messages"
        })
    end
  end

  # Helper function to format message data for API responses
  defp format_message(nil), do: nil

  defp format_message(message) do
    %{
      id: message.id,
      type: message.type,
      body: message.body,
      timestamp: message.timestamp
    }
  end
end
