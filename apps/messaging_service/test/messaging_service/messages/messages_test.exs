defmodule MessagingService.MessagesTest do
  use MessagingService.DataCase, async: true

  alias Ecto.Association.NotLoaded
  alias MessagingService.Message
  alias MessagingService.Messages

  @valid_sms_attrs %{
    from: "+12345678901",
    to: "+12345678902",
    body: "Hello SMS"
  }

  @valid_mms_attrs %{
    from: "+12345678901",
    to: "+12345678902",
    body: "Hello MMS"
  }

  @valid_email_attrs %{
    from: "sender@example.com",
    to: "recipient@example.com",
    body: "Hello Email"
  }

  @invalid_attrs %{from: nil, to: nil, body: nil}

  def message_fixture(attrs \\ %{}) do
    {:ok, message} =
      attrs
      |> Enum.into(@valid_sms_attrs)
      |> Messages.create_sms_message()

    message
  end

  describe "list_messages/0" do
    test "returns all messages" do
      message = message_fixture()
      assert Messages.list_messages() == [message]
    end

    test "returns empty list when no messages exist" do
      assert Messages.list_messages() == []
    end
  end

  describe "get_message!/1" do
    test "returns the message with given id" do
      message = message_fixture()
      assert Messages.get_message!(message.id) == message
    end

    test "raises when message does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Messages.get_message!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_message/1" do
    test "returns the message with given id" do
      message = message_fixture()
      assert Messages.get_message(message.id) == message
    end

    test "returns nil when message does not exist" do
      assert Messages.get_message(Ecto.UUID.generate()) == nil
    end
  end

  describe "get_message_with_attachments!/1" do
    test "returns message with preloaded attachments" do
      message = message_fixture()
      result = Messages.get_message_with_attachments!(message.id)

      assert result.id == message.id
      assert %NotLoaded{} != result.attachments
    end

    test "raises when message does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Messages.get_message_with_attachments!(Ecto.UUID.generate())
      end
    end
  end

  describe "create_sms_message/1" do
    test "with valid data creates an SMS message" do
      assert {:ok, %Message{} = message} = Messages.create_sms_message(@valid_sms_attrs)
      assert message.from == "+12345678901"
      assert message.to == "+12345678902"
      assert message.body == "Hello SMS"
      assert message.type == "sms"
      assert message.timestamp != nil
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Messages.create_sms_message(@invalid_attrs)
    end

    test "validates phone number format" do
      invalid_attrs = %{@valid_sms_attrs | from: "invalid-phone"}
      assert {:error, changeset} = Messages.create_sms_message(invalid_attrs)
      assert %{from: ["must be a valid phone number"]} = errors_on(changeset)
    end

    test "validates SMS body length" do
      invalid_attrs = %{@valid_sms_attrs | body: String.duplicate("x", 161)}
      assert {:error, changeset} = Messages.create_sms_message(invalid_attrs)
      assert %{body: ["SMS body cannot exceed 160 characters"]} = errors_on(changeset)
    end
  end

  describe "create_mms_message/1" do
    test "with valid data creates an MMS message" do
      assert {:ok, %Message{} = message} = Messages.create_mms_message(@valid_mms_attrs)
      assert message.from == "+12345678901"
      assert message.to == "+12345678902"
      assert message.body == "Hello MMS"
      assert message.type == "mms"
      assert message.timestamp != nil
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Messages.create_mms_message(@invalid_attrs)
    end

    test "validates MMS body length" do
      invalid_attrs = %{@valid_mms_attrs | body: String.duplicate("x", 1601)}
      assert {:error, changeset} = Messages.create_mms_message(invalid_attrs)
      assert %{body: ["MMS body cannot exceed 1600 characters"]} = errors_on(changeset)
    end
  end

  describe "create_email_message/1" do
    test "with valid data creates an email message" do
      assert {:ok, %Message{} = message} = Messages.create_email_message(@valid_email_attrs)
      assert message.from == "sender@example.com"
      assert message.to == "recipient@example.com"
      assert message.body == "Hello Email"
      assert message.type == "email"
      assert message.timestamp != nil
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Messages.create_email_message(@invalid_attrs)
    end

    test "validates email format" do
      invalid_attrs = %{@valid_email_attrs | from: "invalid-email"}
      assert {:error, changeset} = Messages.create_email_message(invalid_attrs)
      assert %{from: ["must be a valid email address"]} = errors_on(changeset)
    end
  end

  describe "create_message_with_attachments/2" do
    test "creates MMS message with URL attachment" do
      message_attrs = Map.put(@valid_mms_attrs, :type, "mms")

      attachment_attrs = [
        %{
          url: "https://example.com/image.jpg",
          attachment_type: "image",
          filename: "image.jpg",
          content_type: "image/jpeg"
        }
      ]

      assert {:ok, %Message{} = message} =
               Messages.create_message_with_attachments(message_attrs, attachment_attrs)

      assert message.type == "mms"
      assert length(message.attachments) == 1

      attachment = List.first(message.attachments)
      assert attachment.url == "https://example.com/image.jpg"
      assert attachment.message_id == message.id
    end

    test "creates email message with blob attachment" do
      message_attrs = Map.put(@valid_email_attrs, :type, "email")

      attachment_attrs = [
        %{
          blob: <<1, 2, 3, 4>>,
          attachment_type: "document",
          filename: "document.pdf",
          content_type: "application/pdf",
          size: 4
        }
      ]

      assert {:ok, %Message{} = message} =
               Messages.create_message_with_attachments(message_attrs, attachment_attrs)

      assert message.type == "email"
      assert length(message.attachments) == 1

      attachment = List.first(message.attachments)
      assert attachment.blob == <<1, 2, 3, 4>>
      assert attachment.message_id == message.id
    end

    test "fails when message creation fails" do
      message_attrs = @invalid_attrs
      attachment_attrs = []

      assert {:error, %Ecto.Changeset{}} =
               Messages.create_message_with_attachments(message_attrs, attachment_attrs)
    end

    test "fails when attachment creation fails" do
      message_attrs = Map.put(@valid_mms_attrs, :type, "mms")

      attachment_attrs = [
        %{
          # Missing required fields for attachment
          filename: "image.jpg"
        }
      ]

      assert {:error, _} =
               Messages.create_message_with_attachments(message_attrs, attachment_attrs)
    end

    test "rolls back transaction when one attachment fails" do
      message_attrs = Map.put(@valid_mms_attrs, :type, "mms")

      attachment_attrs = [
        %{
          url: "https://example.com/image.jpg",
          attachment_type: "image",
          filename: "image.jpg",
          content_type: "image/jpeg"
        },
        %{
          # This attachment will fail - missing required data
          filename: "failed.jpg"
        }
      ]

      assert {:error, _} =
               Messages.create_message_with_attachments(message_attrs, attachment_attrs)

      # Verify no message was created due to rollback
      assert Messages.list_messages() == []
    end
  end

  describe "update_message/2" do
    test "with valid data updates the message" do
      message = message_fixture()
      update_attrs = %{body: "Updated body", messaging_provider_id: "provider-123"}

      assert {:ok, %Message{} = updated_message} = Messages.update_message(message, update_attrs)
      assert updated_message.body == "Updated body"
      assert updated_message.messaging_provider_id == "provider-123"
      assert updated_message.id == message.id
    end

    test "with invalid data returns error changeset" do
      message = message_fixture()
      assert {:error, %Ecto.Changeset{}} = Messages.update_message(message, @invalid_attrs)
      assert message == Messages.get_message!(message.id)
    end
  end

  describe "delete_message/1" do
    test "deletes the message" do
      message = message_fixture()
      assert {:ok, %Message{}} = Messages.delete_message(message)
      assert_raise Ecto.NoResultsError, fn -> Messages.get_message!(message.id) end
    end
  end

  describe "change_message/1" do
    test "returns a message changeset" do
      message = message_fixture()
      assert %Ecto.Changeset{} = Messages.change_message(message)
    end
  end

  describe "list_messages_by_type/1" do
    test "returns messages of specified type ordered by timestamp desc" do
      sms_message = message_fixture(%{body: "SMS 1"})
      _mms_message = @valid_mms_attrs |> Messages.create_mms_message() |> elem(1)
      sms_message_2 = %{@valid_sms_attrs | body: "SMS 2"} |> Messages.create_sms_message() |> elem(1)

      sms_messages = Messages.list_messages_by_type("sms")

      assert length(sms_messages) == 2
      # Should be ordered by timestamp desc (newest first)
      assert List.first(sms_messages).id == sms_message_2.id
      assert List.last(sms_messages).id == sms_message.id
    end

    test "returns empty list for type with no messages" do
      _sms_message = message_fixture()

      assert Messages.list_messages_by_type("email") == []
    end
  end

  describe "list_conversation_messages/2" do
    test "returns messages between two contacts ordered by timestamp asc" do
      contact1 = "+1111111111"
      contact2 = "+2222222222"

      # Create messages in conversation
      {:ok, msg1} = Messages.create_sms_message(%{from: contact1, to: contact2, body: "First"})
      {:ok, msg2} = Messages.create_sms_message(%{from: contact2, to: contact1, body: "Reply"})
      {:ok, msg3} = Messages.create_sms_message(%{from: contact1, to: contact2, body: "Second"})

      # Create message from different conversation
      Messages.create_sms_message(%{from: "+3333333333", to: contact1, body: "Other"})

      conversation = Messages.list_conversation_messages(contact1, contact2)

      assert length(conversation) == 3
      assert List.first(conversation).id == msg1.id
      assert Enum.at(conversation, 1).id == msg2.id
      assert List.last(conversation).id == msg3.id

      # All messages should have attachments preloaded
      Enum.each(conversation, fn msg ->
        assert %NotLoaded{} != msg.attachments
      end)
    end

    test "returns empty list when no conversation exists" do
      assert Messages.list_conversation_messages("+1111111111", "+2222222222") == []
    end
  end

  describe "list_messages_from/1" do
    test "returns messages from specific contact ordered by timestamp desc" do
      contact = "+1111111111"

      {:ok, msg1} =
        Messages.create_sms_message(%{from: contact, to: "+2222222222", body: "First"})

      {:ok, msg2} =
        Messages.create_sms_message(%{from: contact, to: "+3333333333", body: "Second"})

      Messages.create_sms_message(%{from: "+4444444444", to: contact, body: "To contact"})

      messages = Messages.list_messages_from(contact)

      assert length(messages) == 2
      # Should be ordered by timestamp desc
      assert List.first(messages).id == msg2.id
      assert List.last(messages).id == msg1.id
    end
  end

  describe "list_messages_to/1" do
    test "returns messages to specific contact ordered by timestamp desc" do
      contact = "+1111111111"

      {:ok, msg1} =
        Messages.create_sms_message(%{from: "+2222222222", to: contact, body: "First"})

      {:ok, msg2} =
        Messages.create_sms_message(%{from: "+3333333333", to: contact, body: "Second"})

      Messages.create_sms_message(%{from: contact, to: "+4444444444", body: "From contact"})

      messages = Messages.list_messages_to(contact)

      assert length(messages) == 2
      # Should be ordered by timestamp desc
      assert List.first(messages).id == msg2.id
      assert List.last(messages).id == msg1.id
    end
  end

  describe "get_latest_conversation_message/2" do
    test "returns the most recent message in a conversation" do
      contact1 = "+1111111111"
      contact2 = "+2222222222"

      Messages.create_sms_message(%{from: contact1, to: contact2, body: "First"})
      Messages.create_sms_message(%{from: contact2, to: contact1, body: "Reply"})
      {:ok, latest} = Messages.create_sms_message(%{from: contact1, to: contact2, body: "Latest"})

      result = Messages.get_latest_conversation_message(contact1, contact2)

      assert result.id == latest.id
      assert result.body == "Latest"
    end

    test "returns nil when no conversation exists" do
      result = Messages.get_latest_conversation_message("+1111111111", "+2222222222")
      assert result == nil
    end
  end

  describe "list_conversations/0" do
    test "returns unique conversations with latest messages" do
      # Create conversations
      Messages.create_sms_message(%{from: "+1111111111", to: "+2222222222", body: "Conv1 Msg1"})

      {:ok, conv1_latest} =
        Messages.create_sms_message(%{
          from: "+2222222222",
          to: "+1111111111",
          body: "Conv1 Latest"
        })

      {:ok, conv2_latest} =
        Messages.create_sms_message(%{from: "+3333333333", to: "+4444444444", body: "Conv2 Only"})

      conversations = Messages.list_conversations()

      assert length(conversations) == 2

      # Find conversations
      conv1 =
        Enum.find(conversations, fn c ->
          (c.contact1 == "+1111111111" and c.contact2 == "+2222222222") or
            (c.contact1 == "+2222222222" and c.contact2 == "+1111111111")
        end)

      conv2 =
        Enum.find(conversations, fn c ->
          (c.contact1 == "+3333333333" and c.contact2 == "+4444444444") or
            (c.contact1 == "+4444444444" and c.contact2 == "+3333333333")
        end)

      assert conv1 != nil
      assert conv1.latest_message.id == conv1_latest.id

      assert conv2 != nil
      assert conv2.latest_message.id == conv2_latest.id
    end

    test "returns empty list when no messages exist" do
      assert Messages.list_conversations() == []
    end
  end

  describe "search_messages/1" do
    test "finds messages containing search term" do
      Messages.create_sms_message(%{@valid_sms_attrs | body: "Hello world"})
      {:ok, match} = Messages.create_sms_message(%{@valid_sms_attrs | body: "Goodbye world"})
      Messages.create_sms_message(%{@valid_sms_attrs | body: "Different message"})

      results = Messages.search_messages("world")

      assert length(results) == 2
      assert Enum.any?(results, fn msg -> msg.id == match.id end)

      # Results should have attachments preloaded
      Enum.each(results, fn msg ->
        assert %NotLoaded{} != msg.attachments
      end)
    end

    test "search is case insensitive" do
      {:ok, message} = Messages.create_sms_message(%{@valid_sms_attrs | body: "Hello WORLD"})

      results = Messages.search_messages("world")

      assert length(results) == 1
      assert List.first(results).id == message.id
    end

    test "returns empty list when no matches found" do
      Messages.create_sms_message(@valid_sms_attrs)

      assert Messages.search_messages("nonexistent") == []
    end
  end

  describe "get_message_count_by_type/0" do
    test "returns count of messages by type" do
      Messages.create_sms_message(@valid_sms_attrs)
      Messages.create_sms_message(@valid_sms_attrs)
      Messages.create_mms_message(@valid_mms_attrs)
      Messages.create_email_message(@valid_email_attrs)

      counts = Messages.get_message_count_by_type()

      assert counts["sms"] == 2
      assert counts["mms"] == 1
      assert counts["email"] == 1
    end

    test "returns empty map when no messages exist" do
      assert Messages.get_message_count_by_type() == %{}
    end
  end

  describe "list_messages_with_attachments/0" do
    test "returns only messages that have attachments" do
      # Create message without attachments
      Messages.create_sms_message(@valid_sms_attrs)

      # Create message with attachment
      message_attrs = Map.put(@valid_mms_attrs, :type, "mms")

      attachment_attrs = [
        %{
          url: "https://example.com/image.jpg",
          attachment_type: "image",
          filename: "image.jpg",
          content_type: "image/jpeg"
        }
      ]

      {:ok, message_with_attachment} =
        Messages.create_message_with_attachments(message_attrs, attachment_attrs)

      results = Messages.list_messages_with_attachments()

      assert length(results) == 1
      assert List.first(results).id == message_with_attachment.id
      assert %NotLoaded{} != List.first(results).attachments
    end

    test "returns empty list when no messages have attachments" do
      Messages.create_sms_message(@valid_sms_attrs)

      assert Messages.list_messages_with_attachments() == []
    end
  end

  describe "validate_message_exists/1" do
    test "returns {:ok, message} when message exists" do
      message = message_fixture()

      assert {:ok, returned_message} = Messages.validate_message_exists(message.id)
      assert returned_message.id == message.id
    end

    test "returns {:error, :not_found} when message does not exist" do
      assert {:error, :not_found} = Messages.validate_message_exists(Ecto.UUID.generate())
    end
  end
end
