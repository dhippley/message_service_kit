defmodule MessagingService.MessagesIntegrationTest do
  use MessagingService.DataCase

  alias MessagingService.{Messages, Conversations}
  alias MessagingService.Message

  describe "conversation integration" do
    test "create_sms_message creates a conversation when none exists" do
      attrs = %{
        from: "+1234567890",
        to: "+1987654321",
        body: "Hello SMS!",
        type: "sms"
      }

      assert {:ok, %Message{conversation_id: conversation_id}} =
               Messages.create_sms_message(attrs)

      assert conversation_id != nil

      # Verify conversation was created
      conversation = Conversations.get_conversation!(conversation_id)
      assert conversation.participant_one == "+1234567890"
      assert conversation.participant_two == "+1987654321"
      assert conversation.message_count == 1
      assert conversation.last_message_at != nil
    end

    test "create_mms_message creates a conversation when none exists" do
      attrs = %{
        from: "+1234567890",
        to: "+1987654321",
        body: "Hello MMS!",
        type: "mms"
      }

      assert {:ok, %Message{conversation_id: conversation_id}} =
               Messages.create_mms_message(attrs)

      assert conversation_id != nil

      # Verify conversation was created
      conversation = Conversations.get_conversation!(conversation_id)
      assert conversation.participant_one == "+1234567890"
      assert conversation.participant_two == "+1987654321"
      assert conversation.message_count == 1
      assert conversation.last_message_at != nil
    end

    test "create_email_message creates a conversation when none exists" do
      attrs = %{
        from: "user@example.com",
        to: "contact@example.com",
        body: "Hello Email!",
        type: "email"
      }

      assert {:ok, %Message{conversation_id: conversation_id}} =
               Messages.create_email_message(attrs)

      assert conversation_id != nil

      # Verify conversation was created
      conversation = Conversations.get_conversation!(conversation_id)
      assert conversation.participant_one == "contact@example.com"
      assert conversation.participant_two == "user@example.com"
      assert conversation.message_count == 1
      assert conversation.last_message_at != nil
    end

    test "multiple messages use the same conversation" do
      from = "+1234567890"
      to = "+1987654321"

      # Create first message
      attrs1 = %{from: from, to: to, body: "First message", type: "sms"}

      assert {:ok, %Message{conversation_id: conversation_id1}} =
               Messages.create_sms_message(attrs1)

      # Create second message (reversed from/to)
      attrs2 = %{from: to, to: from, body: "Second message", type: "sms"}

      assert {:ok, %Message{conversation_id: conversation_id2}} =
               Messages.create_sms_message(attrs2)

      # Both messages should belong to the same conversation
      assert conversation_id1 == conversation_id2

      # Verify conversation stats
      conversation = Conversations.get_conversation!(conversation_id1)
      assert conversation.message_count == 2
    end

    test "conversation is updated when new message is added" do
      from = "+1234567890"
      to = "+1987654321"

      # Create first message
      attrs1 = %{from: from, to: to, body: "First message", type: "sms"}

      assert {:ok, %Message{conversation_id: conversation_id}} =
               Messages.create_sms_message(attrs1)

      # Get initial conversation state
      conversation = Conversations.get_conversation!(conversation_id)
      assert conversation.message_count == 1

      # Wait a bit and create second message
      :timer.sleep(10)
      attrs2 = %{from: to, to: from, body: "Second message", type: "sms"}
      assert {:ok, %Message{timestamp: timestamp2}} = Messages.create_sms_message(attrs2)

      # Verify conversation was updated
      updated_conversation = Conversations.get_conversation!(conversation_id)
      assert updated_conversation.message_count == 2
      assert NaiveDateTime.compare(updated_conversation.last_message_at, timestamp2) == :eq
    end

    test "messages without from/to don't create conversations" do
      attrs = %{body: "Message without sender/recipient", type: "sms"}
      assert {:error, %Ecto.Changeset{}} = Messages.create_sms_message(attrs)
    end

    test "mixed message types can belong to same conversation" do
      from = "user@example.com"
      to = "contact@example.com"

      # Create email message
      email_attrs = %{from: from, to: to, body: "Email message", type: "email"}

      assert {:ok, %Message{conversation_id: conversation_id1}} =
               Messages.create_email_message(email_attrs)

      # Create another email message (reversed from/to)
      email_attrs2 = %{from: to, to: from, body: "Reply email", type: "email"}

      assert {:ok, %Message{conversation_id: conversation_id2}} =
               Messages.create_email_message(email_attrs2)

      # Both messages should belong to the same conversation
      assert conversation_id1 == conversation_id2

      # Verify conversation stats
      conversation = Conversations.get_conversation!(conversation_id1)
      assert conversation.message_count == 2
    end

    test "create_message_with_attachments includes conversation integration" do
      message_attrs = %{
        from: "+1234567890",
        to: "+1987654321",
        body: "Message with attachment",
        type: "mms"
      }

      attachment_attrs = [
        %{
          filename: "image.jpg",
          content_type: "image/jpeg",
          url: "https://example.com/image.jpg",
          attachment_type: "image"
        }
      ]

      assert {:ok, %Message{conversation_id: conversation_id, attachments: attachments}} =
               Messages.create_message_with_attachments(message_attrs, attachment_attrs)

      assert conversation_id != nil
      assert length(attachments) == 1

      # Verify conversation was created and updated
      conversation = Conversations.get_conversation!(conversation_id)
      assert conversation.message_count == 1
      assert conversation.last_message_at != nil
    end

    test "explicit conversation-aware functions work correctly" do
      attrs = %{
        from: "+1234567890",
        to: "+1987654321",
        body: "Explicit conversation message",
        type: "sms"
      }

      # Test explicit conversation-aware function
      assert {:ok, %Message{conversation_id: conversation_id}} =
               Messages.create_sms_message_with_conversation(attrs)

      assert conversation_id != nil

      # Verify conversation was created
      conversation = Conversations.get_conversation!(conversation_id)
      assert conversation.message_count == 1
    end

    test "non-conversation functions still work" do
      attrs = %{
        from: "+1234567890",
        to: "+1987654321",
        body: "Non-conversation message",
        type: "sms"
      }

      # Test explicit non-conversation function
      assert {:ok, %Message{conversation_id: nil}} =
               Messages.create_sms_message_without_conversation(attrs)
    end
  end
end
