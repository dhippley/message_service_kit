defmodule MessagingService.Conversation do
  @moduledoc """
  Schema for storing conversations.

  A conversation represents a group of messages between two participants.
  It tracks the participants and provides a way to group related messages.
  """

  use Ecto.Schema

  @derive {Jason.Encoder, except: [:__meta__, :messages]}

  import Ecto.Changeset

  alias MessagingService.Message

  @type t :: %__MODULE__{
          id: binary() | nil,
          participant_one: String.t() | nil,
          participant_two: String.t() | nil,
          last_message_at: NaiveDateTime.t() | nil,
          message_count: integer() | nil,
          messages: [Message.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversations" do
    field :participant_one, :string
    field :participant_two, :string
    field :last_message_at, :naive_datetime_usec
    field :message_count, :integer, default: 0

    has_many :messages, Message, foreign_key: :conversation_id

    timestamps(type: :naive_datetime_usec)
  end

  @doc """
  Creates a changeset for a conversation.

  ## Examples

      iex> changeset(%Conversation{}, %{participant_one: "alice@example.com", participant_two: "bob@example.com"})
      %Ecto.Changeset{...}

  """
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:participant_one, :participant_two, :last_message_at, :message_count])
    |> validate_required([:participant_one, :participant_two])
    |> validate_participants_different()
    |> normalize_participants()
    |> unique_constraint([:participant_one, :participant_two],
      name: :conversations_participant_one_participant_two_index
    )
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

  @doc """
  Helper function to determine if a contact is a participant in the conversation.

  ## Examples

      iex> participant?(%Conversation{participant_one: "alice@example.com", participant_two: "bob@example.com"}, "alice@example.com")
      true

      iex> participant?(%Conversation{participant_one: "alice@example.com", participant_two: "bob@example.com"}, "charlie@example.com")
      false

  """
  def participant?(%__MODULE__{participant_one: p1, participant_two: p2}, contact) do
    contact == p1 || contact == p2
  end

  @doc """
  Helper function to get the other participant in a conversation.

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

  ## Examples

      iex> display_name(%Conversation{participant_one: "alice@example.com", participant_two: "bob@example.com"})
      "alice@example.com ↔ bob@example.com"

  """
  def display_name(%__MODULE__{participant_one: p1, participant_two: p2}) do
    "#{p1} ↔ #{p2}"
  end

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
