defmodule MessagingService.ConversationsTest do
  use MessagingService.DataCase, async: true

  alias Ecto.Association.NotLoaded
  alias MessagingService.Conversation
  alias MessagingService.Conversations
  alias MessagingService.Messages

  @valid_attrs %{
    participant_one: "alice@example.com",
    participant_two: "bob@example.com"
  }

  @invalid_attrs %{participant_one: nil, participant_two: nil}

  def conversation_fixture(attrs \\ %{}) do
    {:ok, conversation} =
      attrs
      |> Enum.into(@valid_attrs)
      |> Conversations.create_conversation()

    conversation
  end

  def message_fixture(attrs \\ %{}) do
    default_attrs = %{
      from: "+12345678901",
      to: "+12345678902",
      body: "Test message"
    }

    {:ok, message} =
      attrs
      |> Enum.into(default_attrs)
      |> Messages.create_sms_message()

    message
  end

  describe "list_conversations/0" do
    test "returns all conversations ordered by last_message_at desc" do
      conversation1 = conversation_fixture()

      conversation2 =
        conversation_fixture(%{
          participant_one: "charlie@example.com",
          participant_two: "diane@example.com"
        })

      conversations = Conversations.list_conversations()

      assert length(conversations) == 2
      # Should include both conversations
      conversation_ids = Enum.map(conversations, & &1.id)
      assert conversation1.id in conversation_ids
      assert conversation2.id in conversation_ids
    end

    test "returns empty list when no conversations exist" do
      assert Conversations.list_conversations() == []
    end
  end

  describe "list_conversations_with_messages/0" do
    test "returns conversations with preloaded messages" do
      conversation_fixture()

      conversations = Conversations.list_conversations_with_messages()

      assert length(conversations) == 1
      conversation = List.first(conversations)
      assert %NotLoaded{} != conversation.messages
    end
  end

  describe "get_conversation!/1" do
    test "returns the conversation with given id" do
      conversation = conversation_fixture()
      assert Conversations.get_conversation!(conversation.id) == conversation
    end

    test "raises when conversation does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Conversations.get_conversation!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_conversation/1" do
    test "returns the conversation with given id" do
      conversation = conversation_fixture()
      assert Conversations.get_conversation(conversation.id) == conversation
    end

    test "returns nil when conversation does not exist" do
      assert Conversations.get_conversation(Ecto.UUID.generate()) == nil
    end
  end

  describe "get_conversation_with_messages!/1" do
    test "returns conversation with preloaded messages" do
      conversation = conversation_fixture()
      result = Conversations.get_conversation_with_messages!(conversation.id)

      assert result.id == conversation.id
      assert %NotLoaded{} != result.messages
    end

    test "raises when conversation does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Conversations.get_conversation_with_messages!(Ecto.UUID.generate())
      end
    end
  end

  describe "find_or_create_conversation/2" do
    test "returns existing conversation when participants already have one" do
      existing_conversation = conversation_fixture()

      {:ok, conversation} =
        Conversations.find_or_create_conversation(
          "alice@example.com",
          "bob@example.com"
        )

      assert conversation.id == existing_conversation.id
    end

    test "creates new conversation when participants don't have one" do
      assert {:ok, %Conversation{} = conversation} =
               Conversations.find_or_create_conversation("new1@example.com", "new2@example.com")

      assert conversation.participant_one == "new1@example.com"
      assert conversation.participant_two == "new2@example.com"
    end

    test "normalizes participant order" do
      assert {:ok, %Conversation{} = conversation} =
               Conversations.find_or_create_conversation("zebra@example.com", "alice@example.com")

      assert conversation.participant_one == "alice@example.com"
      assert conversation.participant_two == "zebra@example.com"
    end

    test "returns error when participants are the same" do
      assert {:error, changeset} =
               Conversations.find_or_create_conversation("alice@example.com", "alice@example.com")

      refute changeset.valid?
    end
  end

  describe "get_conversation_by_participants/2" do
    test "returns conversation when participants have one" do
      conversation = conversation_fixture()

      result =
        Conversations.get_conversation_by_participants(
          "alice@example.com",
          "bob@example.com"
        )

      assert result.id == conversation.id
    end

    test "returns conversation regardless of participant order" do
      conversation = conversation_fixture()

      result =
        Conversations.get_conversation_by_participants(
          # Reversed order
          "bob@example.com",
          "alice@example.com"
        )

      assert result.id == conversation.id
    end

    test "returns nil when no conversation exists" do
      result =
        Conversations.get_conversation_by_participants(
          "nonexistent1@example.com",
          "nonexistent2@example.com"
        )

      assert result == nil
    end
  end

  describe "create_conversation/1" do
    test "with valid data creates a conversation" do
      assert {:ok, %Conversation{} = conversation} =
               Conversations.create_conversation(@valid_attrs)

      assert conversation.participant_one == "alice@example.com"
      assert conversation.participant_two == "bob@example.com"
      assert conversation.message_count == 0
      assert conversation.last_message_at != nil
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Conversations.create_conversation(@invalid_attrs)
    end

    test "normalizes participants order" do
      attrs = %{participant_one: "zebra@example.com", participant_two: "alice@example.com"}
      assert {:ok, %Conversation{} = conversation} = Conversations.create_conversation(attrs)

      assert conversation.participant_one == "alice@example.com"
      assert conversation.participant_two == "zebra@example.com"
    end
  end

  describe "update_conversation/2" do
    test "with valid data updates the conversation" do
      conversation = conversation_fixture()
      update_attrs = %{message_count: 5}

      assert {:ok, %Conversation{} = updated_conversation} =
               Conversations.update_conversation(conversation, update_attrs)

      assert updated_conversation.message_count == 5
      assert updated_conversation.id == conversation.id
    end

    test "with invalid data returns error changeset" do
      conversation = conversation_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Conversations.update_conversation(conversation, @invalid_attrs)

      assert conversation == Conversations.get_conversation!(conversation.id)
    end
  end

  describe "update_conversation_last_message/2" do
    test "updates last message timestamp and increments count" do
      conversation = conversation_fixture()
      timestamp = ~N[2024-01-01 15:00:00.000000]

      assert {:ok, %Conversation{} = updated_conversation} =
               Conversations.update_conversation_last_message(conversation, timestamp)

      assert updated_conversation.last_message_at == timestamp
      assert updated_conversation.message_count == 1
    end
  end

  describe "delete_conversation/1" do
    test "deletes the conversation" do
      conversation = conversation_fixture()
      assert {:ok, %Conversation{}} = Conversations.delete_conversation(conversation)

      assert_raise Ecto.NoResultsError, fn ->
        Conversations.get_conversation!(conversation.id)
      end
    end
  end

  describe "change_conversation/1" do
    test "returns a conversation changeset" do
      conversation = conversation_fixture()
      assert %Ecto.Changeset{} = Conversations.change_conversation(conversation)
    end
  end

  describe "list_conversations_for_participant/1" do
    test "returns conversations where participant is involved" do
      conversation1 =
        conversation_fixture(%{
          participant_one: "alice@example.com",
          participant_two: "bob@example.com"
        })

      conversation2 =
        conversation_fixture(%{
          participant_one: "alice@example.com",
          participant_two: "charlie@example.com"
        })

      # Conversation that shouldn't be included
      conversation_fixture(%{
        participant_one: "diane@example.com",
        participant_two: "eve@example.com"
      })

      conversations = Conversations.list_conversations_for_participant("alice@example.com")

      assert length(conversations) == 2
      conversation_ids = Enum.map(conversations, & &1.id)
      assert conversation1.id in conversation_ids
      assert conversation2.id in conversation_ids
    end

    test "returns empty list when participant has no conversations" do
      # Create a conversation not involving the participant
      conversation_fixture()

      conversations = Conversations.list_conversations_for_participant("unknown@example.com")
      assert conversations == []
    end
  end

  describe "get_recent_conversations/1" do
    test "returns conversations with recent activity" do
      # Create conversation with recent activity
      recent_conversation = conversation_fixture()
      recent_timestamp = NaiveDateTime.add(NaiveDateTime.utc_now(), -1, :day)

      {:ok, _} =
        Conversations.update_conversation_last_message(recent_conversation, recent_timestamp)

      # Create conversation with old activity
      old_conversation =
        conversation_fixture(%{
          participant_one: "old1@example.com",
          participant_two: "old2@example.com"
        })

      old_timestamp = NaiveDateTime.add(NaiveDateTime.utc_now(), -40, :day)
      {:ok, _} = Conversations.update_conversation_last_message(old_conversation, old_timestamp)

      # Last 30 days
      recent_conversations = Conversations.get_recent_conversations(30)

      assert length(recent_conversations) == 1
      assert List.first(recent_conversations).id == recent_conversation.id
    end
  end

  describe "search_conversations/1" do
    test "finds conversations by participant" do
      conversation1 =
        conversation_fixture(%{
          participant_one: "alice@example.com",
          participant_two: "bob@example.com"
        })

      conversation_fixture(%{
        participant_one: "charlie@example.com",
        participant_two: "diane@example.com"
      })

      results = Conversations.search_conversations("alice")

      assert length(results) == 1
      assert List.first(results).id == conversation1.id
    end

    test "search is case insensitive" do
      conversation =
        conversation_fixture(%{
          participant_one: "ALICE@example.com",
          participant_two: "bob@example.com"
        })

      results = Conversations.search_conversations("alice")

      assert length(results) == 1
      assert List.first(results).id == conversation.id
    end

    test "returns empty list when no matches found" do
      conversation_fixture()

      assert Conversations.search_conversations("nonexistent") == []
    end
  end

  describe "get_conversation_stats/0" do
    test "returns conversation statistics" do
      conversation_fixture()

      conversation_fixture(%{
        participant_one: "charlie@example.com",
        participant_two: "diane@example.com"
      })

      stats = Conversations.get_conversation_stats()

      assert stats.total == 2
      assert stats.active_last_30_days >= 0
      assert stats.average_messages >= 0.0
    end

    test "returns zero stats when no conversations exist" do
      stats = Conversations.get_conversation_stats()

      assert stats.total == 0
      assert stats.active_last_30_days == 0
      assert stats.average_messages == 0.0
    end
  end

  describe "get_archivable_conversations/1" do
    test "returns count of old conversations" do
      # Create a conversation with old activity
      old_conversation = conversation_fixture()
      old_timestamp = NaiveDateTime.add(NaiveDateTime.utc_now(), -100, :day)
      {:ok, _} = Conversations.update_conversation_last_message(old_conversation, old_timestamp)

      # Create a conversation with recent activity
      recent_conversation =
        conversation_fixture(%{
          participant_one: "recent1@example.com",
          participant_two: "recent2@example.com"
        })

      recent_timestamp = NaiveDateTime.add(NaiveDateTime.utc_now(), -10, :day)

      {:ok, _} =
        Conversations.update_conversation_last_message(recent_conversation, recent_timestamp)

      archivable_count = Conversations.get_archivable_conversations(90)

      assert archivable_count == 1
    end
  end

  describe "get_most_active_conversations/1" do
    test "returns most active conversations by message count" do
      conversation1 = conversation_fixture()
      {:ok, _} = Conversations.update_conversation(conversation1, %{message_count: 10})

      conversation2 =
        conversation_fixture(%{
          participant_one: "active1@example.com",
          participant_two: "active2@example.com"
        })

      {:ok, _} = Conversations.update_conversation(conversation2, %{message_count: 20})

      # Conversation with no messages
      conversation_fixture(%{
        participant_one: "empty1@example.com",
        participant_two: "empty2@example.com"
      })

      active_conversations = Conversations.get_most_active_conversations(5)

      assert length(active_conversations) == 2
      # Should be ordered by message count desc
      assert List.first(active_conversations).message_count == 20
      assert List.last(active_conversations).message_count == 10
    end
  end

  describe "validate_conversation_exists/1" do
    test "returns {:ok, conversation} when conversation exists" do
      conversation = conversation_fixture()

      assert {:ok, returned_conversation} =
               Conversations.validate_conversation_exists(conversation.id)

      assert returned_conversation.id == conversation.id
    end

    test "returns {:error, :not_found} when conversation does not exist" do
      assert {:error, :not_found} =
               Conversations.validate_conversation_exists(Ecto.UUID.generate())
    end
  end
end
