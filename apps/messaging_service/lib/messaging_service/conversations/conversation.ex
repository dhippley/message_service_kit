defmodule MessagingService.Conversation do
  @moduledoc """
  Schema for storing conversations.

  A conversation represents a group of messages between participants.
  It supports both direct (2 participants) and group conversations (2+ participants).
  For backward compatibility, legacy direct conversations still use participant_one and participant_two fields.
  New group conversations use the participants field which stores a list of participant identifiers.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MessagingService.Message

  @derive {Jason.Encoder, except: [:__meta__, :messages]}

  @type t :: %__MODULE__{
          id: binary() | nil,
          participant_one: String.t() | nil,
          participant_two: String.t() | nil,
          participants: [String.t()] | nil,
          conversation_type: String.t() | nil,
          last_message_at: NaiveDateTime.t() | nil,
          message_count: integer() | nil,
          messages: [Message.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversations" do
    # Legacy fields for backward compatibility with direct conversations
    field :participant_one, :string
    field :participant_two, :string

    # New fields for group messaging
    field :participants, MessagingService.EctoTypes.ParticipantList
    field :conversation_type, :string, default: "direct"

    field :last_message_at, :naive_datetime_usec
    field :message_count, :integer, default: 0

    has_many :messages, Message, foreign_key: :conversation_id

    timestamps(type: :naive_datetime_usec)
  end

  @doc """
  Creates a changeset for a conversation.
  Supports both direct conversations (2 participants) and group conversations (2+ participants).

  ## Examples

      # Direct conversation (legacy format)
      iex> changeset(%Conversation{}, %{participant_one: "alice@example.com", participant_two: "bob@example.com"})
      %Ecto.Changeset{...}

      # Group conversation
      iex> changeset(%Conversation{}, %{participants: ["alice@example.com", "bob@example.com", "charlie@example.com"]})
      %Ecto.Changeset{...}

  """
  def changeset(conversation, attrs) do
    # Determine if this is a group conversation based on participants field
    if Map.has_key?(attrs, :participants) || Map.has_key?(attrs, "participants") do
      group_changeset(conversation, attrs)
    else
      direct_changeset(conversation, attrs)
    end
  end

  @doc """
  Creates a changeset for a direct conversation (2 participants).
  """
  def direct_changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:participant_one, :participant_two, :last_message_at, :message_count])
    |> put_change(:conversation_type, "direct")
    |> validate_required([:participant_one, :participant_two])
    |> validate_participants_different()
    |> normalize_participants()
    |> unique_constraint([:participant_one, :participant_two],
      name: :conversations_participant_one_participant_two_index
    )
  end

  @doc """
  Creates a changeset for a group conversation (2+ participants).
  """
  def group_changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:participants, :last_message_at, :message_count])
    |> put_change(:conversation_type, "group")
    |> validate_required([:participants])
    |> validate_group_participants()
    |> normalize_group_participants()
    |> set_legacy_participants_from_group()
  end

  @doc """
  Creates a changeset for creating a new conversation from two participants.

  Automatically normalizes the participants so that the lexicographically
  smaller participant is always participant_one.

  ## Examples

      iex> new_changeset(%{participant_one: "bob@example.com", participant_two: "alice@example.com"})
      %Ecto.Changeset{changes: %{participant_one: "alice@example.com", participant_two: "bob@example.com"}}

  """
  def new_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> maybe_set_initial_timestamps()
  end

  @doc """
  Creates a changeset for creating a new group conversation from a list of participants.

  ## Examples

      iex> new_group_changeset(["alice@example.com", "bob@example.com", "charlie@example.com"])
      %Ecto.Changeset{...}

  """
  def new_group_changeset(participants) when is_list(participants) do
    %__MODULE__{}
    |> group_changeset(%{participants: participants})
    |> maybe_set_initial_timestamps()
  end

  @doc """
  Updates conversation metadata when a new message is added.

  ## Examples

      iex> update_last_message_changeset(conversation, ~N[2024-01-01 12:00:00.000000])
      %Ecto.Changeset{...}

  """
  def update_last_message_changeset(conversation, message_timestamp) do
    cast(conversation, %{last_message_at: message_timestamp, message_count: (conversation.message_count || 0) + 1}, [
      :last_message_at,
      :message_count
    ])
  end

  @doc """
  Helper function to create a conversation for a given list of recipients and a sender.
  Automatically determines if this should be a direct or group conversation.

  ## Examples

      # Direct conversation (2 participants total)
      iex> for_participants("+1234567890", ["+0987654321"])
      %Ecto.Changeset{...}

      # Group conversation (3+ participants)
      iex> for_participants("+1234567890", ["+0987654321", "+1122334455"])
      %Ecto.Changeset{...}

  """
  def for_participants(sender, recipients) when is_list(recipients) do
    all_participants = [sender | recipients] |> Enum.uniq() |> Enum.sort()

    case length(all_participants) do
      2 ->
        [p1, p2] = all_participants
        new_changeset(%{participant_one: p1, participant_two: p2})
      _ ->
        new_group_changeset(all_participants)
    end
  end

  # Private helper functions

  defp validate_participants_different(changeset) do
    participant_one = get_field(changeset, :participant_one)
    participant_two = get_field(changeset, :participant_two)

    if participant_one && participant_two && participant_one == participant_two do
      changeset
      |> add_error(:participant_one, "cannot be the same as participant_two")
      |> add_error(:participant_two, "cannot be the same as participant_one")
    else
      changeset
    end
  end

  defp normalize_participants(changeset) do
    participant_one = get_field(changeset, :participant_one)
    participant_two = get_field(changeset, :participant_two)

    if participant_one && participant_two do
      # Ensure participant_one is lexicographically smaller than participant_two
      # This creates a consistent ordering for unique constraint
      if participant_one > participant_two do
        changeset
        |> put_change(:participant_one, participant_two)
        |> put_change(:participant_two, participant_one)
      else
        changeset
      end
    else
      changeset
    end
  end

  defp maybe_set_initial_timestamps(changeset) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :microsecond)

    put_change(changeset, :last_message_at, now)
  end

  defp validate_group_participants(changeset) do
    participants = get_field(changeset, :participants)

    cond do
      participants == nil ->
        changeset

      length(participants) < 2 ->
        add_error(changeset, :participants, "must have at least 2 participants")

      length(participants) != length(Enum.uniq(participants)) ->
        add_error(changeset, :participants, "cannot have duplicate participants")

      true ->
        changeset
    end
  end

  defp normalize_group_participants(changeset) do
    participants = get_field(changeset, :participants)

    if participants do
      # Sort participants for consistent ordering and ensure uniqueness
      normalized = participants |> Enum.uniq() |> Enum.sort()
      put_change(changeset, :participants, normalized)
    else
      changeset
    end
  end

  defp set_legacy_participants_from_group(changeset) do
    participants = get_field(changeset, :participants)

    if participants && length(participants) >= 2 do
      # Set participant_one and participant_two to the first two participants (alphabetically)
      # to satisfy database constraints
      sorted_participants = Enum.sort(participants)

      changeset
      |> put_change(:participant_one, Enum.at(sorted_participants, 0))
      |> put_change(:participant_two, Enum.at(sorted_participants, 1))
    else
      changeset
    end
  end

  @doc """
  Helper function to determine if a contact is a participant in the conversation.
  Works with both direct and group conversations.

  ## Examples

      # Direct conversation
      iex> participant?(%Conversation{participant_one: "alice@example.com", participant_two: "bob@example.com"}, "alice@example.com")
      true

      # Group conversation
      iex> participant?(%Conversation{participants: ["alice@example.com", "bob@example.com", "charlie@example.com"]}, "alice@example.com")
      true

      iex> participant?(%Conversation{participant_one: "alice@example.com", participant_two: "bob@example.com"}, "charlie@example.com")
      false

  """
  def participant?(%__MODULE__{conversation_type: "group", participants: participants}, contact) when is_list(participants) do
    contact in participants
  end

  def participant?(%__MODULE__{participant_one: p1, participant_two: p2}, contact) do
    contact == p1 || contact == p2
  end

  @doc """
  Helper function to get all participants in a conversation as a list.

  ## Examples

      # Direct conversation
      iex> get_participants(%Conversation{participant_one: "alice@example.com", participant_two: "bob@example.com"})
      ["alice@example.com", "bob@example.com"]

      # Group conversation
      iex> get_participants(%Conversation{participants: ["alice@example.com", "bob@example.com", "charlie@example.com"]})
      ["alice@example.com", "bob@example.com", "charlie@example.com"]

  """
  def get_participants(%__MODULE__{conversation_type: "group", participants: participants}) when is_list(participants) do
    participants
  end

  def get_participants(%__MODULE__{participant_one: p1, participant_two: p2}) when p1 != nil and p2 != nil do
    [p1, p2]
  end

  def get_participants(_), do: []

  @doc """
  Helper function to get the other participants in a conversation.
  For direct conversations, returns the other participant.
  For group conversations, returns all participants except the specified one.

  ## Examples

      # Direct conversation
      iex> other_participants(%Conversation{participant_one: "alice@example.com", participant_two: "bob@example.com"}, "alice@example.com")
      ["bob@example.com"]

      # Group conversation
      iex> other_participants(%Conversation{participants: ["alice@example.com", "bob@example.com", "charlie@example.com"]}, "alice@example.com")
      ["bob@example.com", "charlie@example.com"]

      iex> other_participants(%Conversation{participant_one: "alice@example.com", participant_two: "bob@example.com"}, "charlie@example.com")
      []

  """
  def other_participants(%__MODULE__{conversation_type: "group", participants: participants}, contact) when is_list(participants) do
    if contact in participants do
      List.delete(participants, contact)
    else
      []
    end
  end

  def other_participants(%__MODULE__{participant_one: p1, participant_two: p2}, contact) do
    cond do
      contact == p1 -> [p2]
      contact == p2 -> [p1]
      true -> []
    end
  end

  @doc """
  Legacy helper function to get the other participant in a direct conversation.
  For backward compatibility only - use other_participants/2 for new code.

  ## Examples

      iex> other_participant(%Conversation{participant_one: "alice@example.com", participant_two: "bob@example.com"}, "alice@example.com")
      "bob@example.com"

      iex> other_participant(%Conversation{participant_one: "alice@example.com", participant_two: "bob@example.com"}, "charlie@example.com")
      nil

  """
  def other_participant(%__MODULE__{participant_one: p1, participant_two: p2}, contact) do
    cond do
      contact == p1 -> p2
      contact == p2 -> p1
      true -> nil
    end
  end

  @doc """
  Helper function to create a normalized participant pair for lookup.

  ## Examples

      iex> normalize_participants("bob@example.com", "alice@example.com")
      {"alice@example.com", "bob@example.com"}

  """
  def normalize_participants(participant_one, participant_two) do
    if participant_one > participant_two do
      {participant_two, participant_one}
    else
      {participant_one, participant_two}
    end
  end

  @doc """
  Helper function to format the conversation display name.
  Works with both direct and group conversations.

  ## Examples

      # Direct conversation
      iex> display_name(%Conversation{participant_one: "alice@example.com", participant_two: "bob@example.com"})
      "alice@example.com ↔ bob@example.com"

      # Group conversation
      iex> display_name(%Conversation{participants: ["alice@example.com", "bob@example.com", "charlie@example.com"]})
      "alice@example.com, bob@example.com, charlie@example.com"

  """
  def display_name(%__MODULE__{conversation_type: "group", participants: participants}) when is_list(participants) do
    Enum.join(participants, ", ")
  end

  def display_name(%__MODULE__{participant_one: p1, participant_two: p2}) when p1 != nil and p2 != nil do
    "#{p1} ↔ #{p2}"
  end

  def display_name(_), do: "Unknown Conversation"

  @doc """
  Helper function to check if a conversation has recent activity.

  ## Examples

      iex> recent_activity?(%Conversation{last_message_at: ~N[2024-01-01 12:00:00.000000]}, ~N[2024-01-01 11:00:00.000000])
      true

  """
  def recent_activity?(%__MODULE__{last_message_at: nil}, _threshold), do: false

  def recent_activity?(%__MODULE__{last_message_at: last_message_at}, threshold) do
    NaiveDateTime.after?(last_message_at, threshold)
  end
end
