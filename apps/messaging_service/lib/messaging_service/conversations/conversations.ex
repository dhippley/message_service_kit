defmodule MessagingService.Conversations do
  @moduledoc """
  The Conversations context.

  This module provides functions for managing conversations between participants,
  including creating, retrieving, and organizing conversations with their messages.
  """

  import Ecto.Query, warn: false

  alias MessagingService.Conversation
  alias MessagingService.Message
  alias MessagingService.Repo

  @doc """
  Returns the list of conversations with preloaded messages.

  ## Examples

      iex> list_conversations_with_messages()
      [%Conversation{messages: [%Message{}, ...]}, ...]

  """
  def list_conversations_with_messages do
    messages_query = from(m in Message, order_by: [asc: m.timestamp])

    Conversation
    |> order_by([c], desc: c.last_message_at)
    |> preload(messages: ^messages_query)
    |> Repo.all()
  end

  @doc """
  Returns a paginated list of conversations with preloaded messages.

  ## Examples

      iex> list_conversations_with_messages_paginated(page: 1, per_page: 10)
      %{
        conversations: [%Conversation{messages: [%Message{}, ...]}, ...],
        total_count: 25,
        page: 1,
        per_page: 10,
        total_pages: 3,
        has_next: true,
        has_prev: false
      }

  """
  def list_conversations_with_messages_paginated(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 12)

    messages_query = from(m in Message, order_by: [asc: m.timestamp])

    # Get total count
    total_count = Repo.aggregate(Conversation, :count, :id)

    # Calculate pagination info
    total_pages = ceil(total_count / per_page)
    offset = (page - 1) * per_page

    # Get paginated conversations
    conversations =
      Conversation
      |> order_by([c], desc: c.last_message_at)
      |> limit(^per_page)
      |> offset(^offset)
      |> preload(messages: ^messages_query)
      |> Repo.all()

    %{
      conversations: conversations,
      total_count: total_count,
      page: page,
      per_page: per_page,
      total_pages: total_pages,
      has_next: page < total_pages,
      has_prev: page > 1
    }
  end

  @doc """
  Gets a single conversation.

  Returns `nil` if the Conversation does not exist.

  ## Examples

      iex> get_conversation(123)
      %Conversation{}

      iex> get_conversation(456)
      nil

  """
  def get_conversation(id), do: Repo.get(Conversation, id)

  @doc """
  Gets a single conversation.

  Raises `Ecto.NoResultsError` if the Conversation does not exist.

  ## Examples

      iex> get_conversation!(123)
      %Conversation{}

      iex> get_conversation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_conversation!(id), do: Repo.get!(Conversation, id)

  @doc """
  Gets a conversation with preloaded messages.

  Returns `nil` if the Conversation does not exist.

  ## Examples

      iex> get_conversation_with_messages(conversation_id)
      %Conversation{messages: [%Message{}, ...]}

      iex> get_conversation_with_messages("nonexistent")
      nil

  """
  def get_conversation_with_messages(id) do
    messages_query = from(m in Message, order_by: [asc: m.timestamp], preload: :attachments)

    Conversation
    |> preload(messages: ^messages_query)
    |> Repo.get(id)
  end

  @doc """
  Gets a conversation with preloaded messages.

  ## Examples

      iex> get_conversation_with_messages!(conversation_id)
      %Conversation{messages: [%Message{}, ...]}

  """
  def get_conversation_with_messages!(id) do
    messages_query = from(m in Message, order_by: [asc: m.timestamp], preload: :attachments)

    Conversation
    |> preload(messages: ^messages_query)
    |> Repo.get!(id)
  end

  @doc """
  Finds or creates a conversation between two participants.

  ## Examples

      iex> find_or_create_conversation("alice@example.com", "bob@example.com")
      {:ok, %Conversation{}}

      iex> find_or_create_conversation("alice@example.com", "alice@example.com")
      {:error, %Ecto.Changeset{}}

  """
  def find_or_create_conversation(participant_one, participant_two) do
    {p1, p2} = Conversation.normalize_participants(participant_one, participant_two)

    case get_conversation_by_participants(p1, p2) do
      nil ->
        create_conversation(%{participant_one: p1, participant_two: p2})

      conversation ->
        {:ok, conversation}
    end
  end

  @doc """
  Gets a conversation by participants.

  ## Examples

      iex> get_conversation_by_participants("alice@example.com", "bob@example.com")
      %Conversation{}

      iex> get_conversation_by_participants("nonexistent1", "nonexistent2")
      nil

  """
  def get_conversation_by_participants(participant_one, participant_two) do
    {p1, p2} = Conversation.normalize_participants(participant_one, participant_two)

    Conversation
    |> where([c], c.participant_one == ^p1 and c.participant_two == ^p2)
    |> Repo.one()
  end

  @doc """
  Creates a conversation.

  ## Examples

      iex> create_conversation(%{participant_one: "alice@example.com", participant_two: "bob@example.com"})
      {:ok, %Conversation{}}

      iex> create_conversation(%{participant_one: "alice@example.com"})
      {:error, %Ecto.Changeset{}}

  """
  def create_conversation(attrs \\ %{}) do
    attrs
    |> Conversation.new_changeset()
    |> Repo.insert()
  end

  @doc """
  Updates a conversation.

  ## Examples

      iex> update_conversation(conversation, %{message_count: 5})
      {:ok, %Conversation{}}

      iex> update_conversation(conversation, %{participant_one: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_conversation(%Conversation{} = conversation, attrs) do
    conversation
    |> Conversation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates conversation metadata when a new message is added.

  ## Examples

      iex> update_conversation_last_message(conversation, ~N[2024-01-01 12:00:00.000000])
      {:ok, %Conversation{}}

  """
  def update_conversation_last_message(%Conversation{} = conversation, message_timestamp) do
    conversation
    |> Conversation.update_last_message_changeset(message_timestamp)
    |> Repo.update()
  end

  @doc """
  Deletes a conversation.

  ## Examples

      iex> delete_conversation(conversation)
      {:ok, %Conversation{}}

      iex> delete_conversation(conversation)
      {:error, %Ecto.Changeset{}}

  """
  def delete_conversation(%Conversation{} = conversation) do
    Repo.delete(conversation)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking conversation changes.

  ## Examples

      iex> change_conversation(conversation)
      %Ecto.Changeset{data: %Conversation{}}

  """
  def change_conversation(%Conversation{} = conversation, attrs \\ %{}) do
    Conversation.changeset(conversation, attrs)
  end

  @doc """
  Lists conversations for a specific participant.

  ## Examples

      iex> list_conversations_for_participant("alice@example.com")
      [%Conversation{}, ...]

  """
  def list_conversations_for_participant(participant) do
    Conversation
    |> where([c], c.participant_one == ^participant or c.participant_two == ^participant)
    |> order_by([c], desc: c.last_message_at)
    |> Repo.all()
  end

  @doc """
  Gets conversations with recent activity (within the last N days).

  ## Examples

      iex> get_recent_conversations(7)
      [%Conversation{}, ...]

  """
  def get_recent_conversations(days_back \\ 30) do
    threshold =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-days_back * 24 * 60 * 60, :second)
      |> NaiveDateTime.truncate(:microsecond)

    Conversation
    |> where([c], c.last_message_at >= ^threshold)
    |> order_by([c], desc: c.last_message_at)
    |> Repo.all()
  end

  @doc """
  Searches conversations by participant.

  ## Examples

      iex> search_conversations("alice")
      [%Conversation{}, ...]

  """
  def search_conversations(search_term) when is_binary(search_term) do
    search_pattern = "%#{search_term}%"

    Conversation
    |> where(
      [c],
      ilike(c.participant_one, ^search_pattern) or
        ilike(c.participant_two, ^search_pattern)
    )
    |> order_by([c], desc: c.last_message_at)
    |> Repo.all()
  end

  @doc """
  Gets conversation statistics.

  ## Examples

      iex> get_conversation_stats()
      %{total: 10, active_last_30_days: 8, average_messages: 5.2}

  """
  def get_conversation_stats do
    total_conversations = Repo.aggregate(Conversation, :count, :id)

    thirty_days_ago =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-30 * 24 * 60 * 60, :second)
      |> NaiveDateTime.truncate(:microsecond)

    active_conversations =
      Conversation
      |> where([c], c.last_message_at >= ^thirty_days_ago)
      |> Repo.aggregate(:count, :id)

    average_messages =
      case Repo.aggregate(Conversation, :avg, :message_count) do
        nil -> 0.0
        %Decimal{} = decimal -> decimal |> Decimal.to_float() |> Float.round(1)
        avg when is_float(avg) -> Float.round(avg, 1)
        avg -> Float.round(avg * 1.0, 1)
      end

    %{
      total: total_conversations,
      active_last_30_days: active_conversations,
      average_messages: average_messages
    }
  end

  @doc """
  Archives conversations older than specified days with no activity.

  This doesn't delete conversations but could be used to mark them as archived.
  For now, it just returns the count of conversations that would be archived.

  ## Examples

      iex> get_archivable_conversations(90)
      5

  """
  def get_archivable_conversations(days_back \\ 90) do
    threshold =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-days_back * 24 * 60 * 60, :second)
      |> NaiveDateTime.truncate(:microsecond)

    Conversation
    |> where([c], c.last_message_at < ^threshold or is_nil(c.last_message_at))
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets the most active conversations (by message count).

  ## Examples

      iex> get_most_active_conversations(5)
      [%Conversation{}, ...]

  """
  def get_most_active_conversations(limit \\ 10) do
    Conversation
    |> where([c], c.message_count > 0)
    |> order_by([c], desc: c.message_count)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Validates if a conversation exists and is accessible.

  ## Examples

      iex> validate_conversation_exists(conversation_id)
      {:ok, %Conversation{}}

      iex> validate_conversation_exists("nonexistent")
      {:error, :not_found}

  """
  def validate_conversation_exists(conversation_id) do
    case get_conversation(conversation_id) do
      nil -> {:error, :not_found}
      conversation -> {:ok, conversation}
    end
  end

  @doc """
  Finds or creates a group conversation with multiple participants.

  ## Examples

      iex> find_or_create_group_conversation(["alice@example.com", "bob@example.com", "charlie@example.com"])
      {:ok, %Conversation{}}

  """
  def find_or_create_group_conversation(participants) when is_list(participants) do
    # Sort participants for consistent lookup
    sorted_participants = participants |> Enum.uniq() |> Enum.sort()

    case get_group_conversation_by_participants(sorted_participants) do
      nil ->
        create_group_conversation(%{participants: sorted_participants})

      conversation ->
        {:ok, conversation}
    end
  end

  @doc """
  Gets a group conversation by participants.

  ## Examples

      iex> get_group_conversation_by_participants(["alice@example.com", "bob@example.com", "charlie@example.com"])
      %Conversation{}

      iex> get_group_conversation_by_participants(["nonexistent1", "nonexistent2"])
      nil

  """
  def get_group_conversation_by_participants(participants) when is_list(participants) do
    # Sort participants for consistent lookup
    sorted_participants = participants |> Enum.uniq() |> Enum.sort()

    Conversation
    |> where([c], c.conversation_type == "group" and c.participants == ^sorted_participants)
    |> Repo.one()
  end

  @doc """
  Creates a group conversation.

  ## Examples

      iex> create_group_conversation(%{participants: ["alice@example.com", "bob@example.com", "charlie@example.com"]})
      {:ok, %Conversation{}}

      iex> create_group_conversation(%{participants: ["alice@example.com"]})
      {:error, %Ecto.Changeset{}}

  """
  def create_group_conversation(attrs \\ %{}) do
    %Conversation{}
    |> Conversation.group_changeset(attrs)
    |> Repo.insert()
  end
end
