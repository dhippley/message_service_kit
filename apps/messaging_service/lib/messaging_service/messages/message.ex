defmodule MessagingService.Message do
  @moduledoc """
  Schema for storing messages.

  This schema handles storing messages from various providers (SMS, MMS, Email)
  and manages the relationship with attachments.
  """

  use Ecto.Schema

  @derive {Jason.Encoder, except: [:__meta__, :attachments, :conversation]}

  import Ecto.Changeset

  alias Ecto.Association.NotLoaded
  alias MessagingService.Attachment

  @type t :: %__MODULE__{
          id: binary() | nil,
          to: String.t() | nil,
          from: String.t() | nil,
          type: String.t() | nil,
          body: String.t() | nil,
          messaging_provider_id: String.t() | nil,
          provider_name: String.t() | nil,
          timestamp: NaiveDateTime.t() | nil,
          conversation_id: binary() | nil,
          attachments: [Attachment.t()] | NotLoaded.t(),
          conversation: MessagingService.Conversation.t() | NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :to, :string
    field :from, :string
    field :type, :string
    field :body, :string
    field :messaging_provider_id, :string
    field :provider_name, :string
    field :timestamp, :naive_datetime_usec
    field :conversation_id, :binary_id
    
    # Status tracking fields
    field :status, :string, default: "pending"
    field :direction, :string, default: "outbound"
    field :queued_at, :naive_datetime_usec
    field :sent_at, :naive_datetime_usec
    field :delivered_at, :naive_datetime_usec
    field :failed_at, :naive_datetime_usec
    field :failure_reason, :string

    has_many :attachments, Attachment, foreign_key: :message_id

    belongs_to :conversation, MessagingService.Conversation,
      foreign_key: :conversation_id,
      define_field: false

    timestamps(type: :naive_datetime_usec)
  end

  @doc """
  Creates a changeset for a message.

  ## Examples

      iex> changeset(%Message{}, %{from: "+1234567890", to: "+0987654321", type: "sms", body: "Hello"})
      %Ecto.Changeset{...}

  """
  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :to,
      :from,
      :type,
      :body,
      :messaging_provider_id,
      :provider_name,
      :timestamp,
      :conversation_id,
      :status,
      :direction,
      :queued_at,
      :sent_at,
      :delivered_at,
      :failed_at,
      :failure_reason
    ])
    |> validate_required([:to, :from, :type, :body])
    |> validate_message_type()
    |> validate_contact_format()
    |> validate_body_content()
    |> maybe_set_timestamp()
  end

  @doc """
  Creates a changeset for SMS messages.

  ## Examples

      iex> sms_changeset(%Message{}, %{from: "+1234567890", to: "+0987654321", body: "Hello"})
      %Ecto.Changeset{...}

  """
  def sms_changeset(message, attrs) do
    attrs_with_type = Map.put(attrs, :type, "sms")

    message
    |> changeset(attrs_with_type)
    |> validate_sms_body_length()
  end

  @doc """
  Creates a changeset for MMS messages.

  ## Examples

      iex> mms_changeset(%Message{}, %{from: "+1234567890", to: "+0987654321", body: "Hello"})
      %Ecto.Changeset{...}

  """
  def mms_changeset(message, attrs) do
    attrs_with_type = Map.put(attrs, :type, "mms")

    message
    |> changeset(attrs_with_type)
    |> validate_mms_body_length()
  end

  @doc """
  Creates a changeset for email messages.

  ## Examples

      iex> email_changeset(%Message{}, %{from: "user@example.com", to: "contact@example.com", body: "Hello"})
      %Ecto.Changeset{...}

  """
  def email_changeset(message, attrs) do
    attrs_with_type = Map.put(attrs, :type, "email")

    message
    |> changeset(attrs_with_type)
    |> validate_email_body()
  end

  # Private validation functions

  defp validate_message_type(changeset) do
    valid_types = ["sms", "mms", "email"]

    validate_inclusion(changeset, :type, valid_types, message: "must be one of: #{Enum.join(valid_types, ", ")}")
  end

  defp validate_contact_format(changeset) do
    message_type = get_field(changeset, :type)

    case message_type do
      type when type in ["sms", "mms"] ->
        changeset
        |> validate_phone_number(:from)
        |> validate_phone_number(:to)

      "email" ->
        changeset
        |> validate_email_address(:from)
        |> validate_email_address(:to)

      _ ->
        changeset
    end
  end

  defp validate_phone_number(changeset, field) do
    changeset
    |> validate_format(field, ~r/^\+?[1-9]\d{1,14}$/, message: "must be a valid phone number")
    |> validate_length(field, min: 10, max: 15)
  end

  defp validate_email_address(changeset, field) do
    changeset
    |> validate_format(field, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email address")
    # RFC 5321 limit
    |> validate_length(field, max: 320)
  end

  defp validate_body_content(changeset) do
    validate_length(changeset, :body, min: 1, message: "cannot be empty")
  end

  defp validate_sms_body_length(changeset) do
    validate_length(changeset, :body, max: 160, message: "SMS body cannot exceed 160 characters")
  end

  defp validate_mms_body_length(changeset) do
    validate_length(changeset, :body, max: 1600, message: "MMS body cannot exceed 1600 characters")
  end

  defp validate_email_body(changeset) do
    # Email bodies can be much longer, but let's set a reasonable limit
    validate_length(changeset, :body, max: 100_000, message: "Email body is too long")
  end

  defp maybe_set_timestamp(changeset) do
    case get_field(changeset, :timestamp) do
      nil ->
        put_change(
          changeset,
          :timestamp,
          NaiveDateTime.truncate(NaiveDateTime.utc_now(), :microsecond)
        )

      _ ->
        changeset
    end
  end

  @doc """
  Helper function to determine if a message is from a phone provider (SMS/MMS).

  ## Examples

      iex> phone_message?(%Message{type: "sms"})
      true

      iex> phone_message?(%Message{type: "email"})
      false

  """
  def phone_message?(%__MODULE__{type: type}) when type in ["sms", "mms"], do: true
  def phone_message?(_), do: false

  @doc """
  Helper function to determine if a message is an email.

  ## Examples

      iex> email_message?(%Message{type: "email"})
      true

      iex> email_message?(%Message{type: "sms"})
      false

  """
  def email_message?(%__MODULE__{type: "email"}), do: true
  def email_message?(_), do: false

  @doc """
  Helper function to check if a message supports attachments.

  ## Examples

      iex> supports_attachments?(%Message{type: "mms"})
      true

      iex> supports_attachments?(%Message{type: "sms"})
      false

  """
  def supports_attachments?(%__MODULE__{type: type}) when type in ["mms", "email"], do: true
  def supports_attachments?(_), do: false

  @doc """
  Helper function to get the character limit for a message type.

  ## Examples

      iex> character_limit(%Message{type: "sms"})
      160

      iex> character_limit(%Message{type: "email"})
      100000

  """
  def character_limit(%__MODULE__{type: "sms"}), do: 160
  def character_limit(%__MODULE__{type: "mms"}), do: 1600
  def character_limit(%__MODULE__{type: "email"}), do: 100_000
  def character_limit(_), do: nil

  @doc """
  Helper function to format the timestamp in ISO8601 format.

  ## Examples

      iex> format_timestamp(%Message{timestamp: ~N[2024-01-01 12:00:00.000000]})
      "2024-01-01T12:00:00Z"

  """
  def format_timestamp(%__MODULE__{timestamp: nil}), do: nil

  def format_timestamp(%__MODULE__{timestamp: timestamp}) do
    timestamp
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end
end
