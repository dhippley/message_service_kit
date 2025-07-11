defmodule MessagingService.ConversationTest do
  use MessagingService.DataCase, async: true

  alias MessagingService.Conversation

  @valid_attrs %{
    participant_one: "alice@example.com",
    participant_two: "bob@example.com"
  }

  @invalid_attrs %{participant_one: nil, participant_two: nil}

  describe "changeset/2" do
    test "valid attributes" do
      changeset = Conversation.changeset(%Conversation{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires participant_one and participant_two" do
      changeset = Conversation.changeset(%Conversation{}, @invalid_attrs)

      refute changeset.valid?
      assert %{participant_one: ["can't be blank"]} = errors_on(changeset)
      assert %{participant_two: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates participants are different" do
      attrs = %{participant_one: "alice@example.com", participant_two: "alice@example.com"}
      changeset = Conversation.changeset(%Conversation{}, attrs)

      refute changeset.valid?
      assert %{participant_one: ["cannot be the same as participant_two"]} = errors_on(changeset)
      assert %{participant_two: ["cannot be the same as participant_one"]} = errors_on(changeset)
    end

    test "normalizes participants order" do
      # Test with participants in reverse alphabetical order
      attrs = %{participant_one: "zebra@example.com", participant_two: "alice@example.com"}
      changeset = Conversation.changeset(%Conversation{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :participant_one) == "alice@example.com"
      assert get_change(changeset, :participant_two) == "zebra@example.com"
    end

    test "maintains participants order when already normalized" do
      # Test with participants already in alphabetical order
      attrs = %{participant_one: "alice@example.com", participant_two: "zebra@example.com"}
      changeset = Conversation.changeset(%Conversation{}, attrs)

      assert changeset.valid?
      # Should maintain the correct order
      assert get_change(changeset, :participant_one) == "alice@example.com"
      assert get_change(changeset, :participant_two) == "zebra@example.com"
    end

    test "accepts message_count and last_message_at" do
      attrs =
        Map.merge(@valid_attrs, %{
          message_count: 5,
          last_message_at: ~N[2024-01-01 12:00:00.000000]
        })

      changeset = Conversation.changeset(%Conversation{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :message_count) == 5
      assert get_change(changeset, :last_message_at) == ~N[2024-01-01 12:00:00.000000]
    end
  end

  describe "new_changeset/1" do
    test "creates changeset with initial timestamps" do
      changeset = Conversation.new_changeset(@valid_attrs)

      assert changeset.valid?
      assert get_change(changeset, :last_message_at) != nil
    end

    test "normalizes participants in new changeset" do
      attrs = %{participant_one: "zebra@example.com", participant_two: "alice@example.com"}
      changeset = Conversation.new_changeset(attrs)

      assert changeset.valid?
      assert get_change(changeset, :participant_one) == "alice@example.com"
      assert get_change(changeset, :participant_two) == "zebra@example.com"
    end
  end

  describe "update_last_message_changeset/2" do
    test "updates last_message_at and increments message_count" do
      conversation = %Conversation{message_count: 3}
      timestamp = ~N[2024-01-01 15:00:00.000000]

      changeset = Conversation.update_last_message_changeset(conversation, timestamp)

      assert changeset.valid?
      assert get_change(changeset, :last_message_at) == timestamp
      assert get_change(changeset, :message_count) == 4
    end

    test "handles nil message_count" do
      conversation = %Conversation{message_count: nil}
      timestamp = ~N[2024-01-01 15:00:00.000000]

      changeset = Conversation.update_last_message_changeset(conversation, timestamp)

      assert changeset.valid?
      assert get_change(changeset, :message_count) == 1
    end
  end

  describe "helper functions" do
    test "participant?/2" do
      conversation = %Conversation{
        participant_one: "alice@example.com",
        participant_two: "bob@example.com"
      }

      assert Conversation.participant?(conversation, "alice@example.com")
      assert Conversation.participant?(conversation, "bob@example.com")
      refute Conversation.participant?(conversation, "charlie@example.com")
    end

    test "other_participant/2" do
      conversation = %Conversation{
        participant_one: "alice@example.com",
        participant_two: "bob@example.com"
      }

      assert Conversation.other_participant(conversation, "alice@example.com") ==
               "bob@example.com"

      assert Conversation.other_participant(conversation, "bob@example.com") ==
               "alice@example.com"

      assert Conversation.other_participant(conversation, "charlie@example.com") == nil
    end

    test "normalize_participants/2" do
      assert Conversation.normalize_participants("zebra@example.com", "alice@example.com") ==
               {"alice@example.com", "zebra@example.com"}

      assert Conversation.normalize_participants("alice@example.com", "zebra@example.com") ==
               {"alice@example.com", "zebra@example.com"}
    end

    test "display_name/1" do
      conversation = %Conversation{
        participant_one: "alice@example.com",
        participant_two: "bob@example.com"
      }

      assert Conversation.display_name(conversation) == "alice@example.com ↔ bob@example.com"
    end

    test "recent_activity?/2" do
      # Conversation with recent activity
      recent_conversation = %Conversation{
        last_message_at: ~N[2024-01-01 12:00:00.000000]
      }

      threshold = ~N[2024-01-01 11:00:00.000000]
      assert Conversation.recent_activity?(recent_conversation, threshold)

      # Conversation with old activity
      old_conversation = %Conversation{
        last_message_at: ~N[2024-01-01 10:00:00.000000]
      }

      refute Conversation.recent_activity?(old_conversation, threshold)

      # Conversation with no activity
      no_activity_conversation = %Conversation{last_message_at: nil}
      refute Conversation.recent_activity?(no_activity_conversation, threshold)
    end
  end

  describe "associations" do
    test "has_many messages association" do
      association = Conversation.__schema__(:association, :messages)
      assert association.cardinality == :many
      assert association.field == :messages
      assert association.related == MessagingService.Message
    end
  end
end
