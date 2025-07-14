defmodule MessagingService.EctoTypes.PhoneList do
  @moduledoc """
  Custom Ecto type for handling phone numbers that can be either a single string or a list of strings.
  This supports both individual messages and group messaging.

  When stored in the database:
  - Single phone numbers are stored as plain strings
  - Lists of phone numbers are stored as JSON arrays

  When loaded from the database:
  - Plain strings are returned as-is
  - JSON arrays are parsed back into lists
  """

  use Ecto.Type

  def type, do: :string

  @doc """
  Casts input to either a string or list of strings
  """
  def cast(phone) when is_binary(phone), do: {:ok, phone}

  def cast(phone_list) when is_list(phone_list) do
    # Validate that all items in the list are strings
    if Enum.all?(phone_list, &is_binary/1) do
      {:ok, phone_list}
    else
      :error
    end
  end

  def cast(_), do: :error

  @doc """
  Loads data from the database
  """
  def load(value) when is_binary(value) do
    # Try to parse as JSON first, if that fails treat as plain string
    case Jason.decode(value) do
      {:ok, list} when is_list(list) -> {:ok, list}
      # Plain string
      {:error, _} -> {:ok, value}
    end
  end

  def load(_), do: :error

  @doc """
  Dumps data to the database
  """
  def dump(phone) when is_binary(phone), do: {:ok, phone}

  def dump(phone_list) when is_list(phone_list) do
    case Jason.encode(phone_list) do
      {:ok, json} -> {:ok, json}
      {:error, _} -> :error
    end
  end

  def dump(_), do: :error

  @doc """
  Determines if a change should be made
  """
  def equal?(phone1, phone2), do: phone1 == phone2
end
