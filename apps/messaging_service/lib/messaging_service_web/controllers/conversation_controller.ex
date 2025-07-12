defmodule MessagingServiceWeb.ConversationController do
  @moduledoc """
  Controller for managing conversations and retrieving messages.

  This controller provides endpoints to list conversations and retrieve 
  messages within a specific conversation.
  """

  use MessagingServiceWeb, :controller
  require Logger

  alias MessagingService.{Messages, Conversations}

  @doc """
  Lists all conversations.

  Returns a JSON response with all conversations in the system.
  """
  def index(conn, _params) do
    Logger.info("Retrieving all conversations")

    try do
      conversations = Messages.list_conversations()
      
      conn
      |> put_status(:ok)
      |> json(%{
        success: true,
        data: conversations,
        count: length(conversations)
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
      case Conversations.get_conversation(conversation_id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{
            success: false,
            error: "Conversation not found"
          })

        conversation ->
          conversation_with_messages = Conversations.get_conversation_with_messages!(conversation_id)
          
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            conversation_id: conversation.id,
            data: conversation_with_messages.messages,
            count: length(conversation_with_messages.messages)
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
end
