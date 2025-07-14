defmodule MessagingService.EctoTypes.ParticipantList do
  @moduledoc """
  Custom Ecto type for handling participant lists in conversations.
  This supports both direct (2 participants) and group conversations (2+ participants).

  When stored in the database:
  - Participant lists are stored as JSON arrays

  When loaded from the database:
  - JSON arrays are parsed back into lists of participant identifiers
  """

  use Ecto.Type

  def type, do: :string

  @doc """
  Casts input to a list of participant identifiers (strings)
  """
  def cast(participants) when is_list(participants) do
    # Validate that all items in the list are strings and remove duplicates
    if Enum.all?(participants, &is_binary/1) do
      # Sort participants for consistent ordering and remove duplicates
      unique_sorted = participants |> Enum.uniq() |> Enum.sort()
      {:ok, unique_sorted}
    else
      :error
    end
  end
  def cast(_), do: :error

  @doc """
  Loads data from the database
  """
  def load(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, list} when is_list(list) -> {:ok, list}
      {:error, _} -> :error
    end
  end
  def load(_), do: :error

  @doc """
  Dumps data to the database
  """
  def dump(participants) when is_list(participants) do
    case Jason.encode(participants) do
      {:ok, json} -> {:ok, json}
      {:error, _} -> :error
    end
  end
  def dump(_), do: :error

  @doc """
  Determines if a change should be made
  """
  def equal?(participants1, participants2), do: participants1 == participants2
end
