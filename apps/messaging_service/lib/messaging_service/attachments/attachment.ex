defmodule MessagingService.Attachment do
  @moduledoc """
  Schema for storing message attachments.

  This schema handles storing attachments that can be included with messages,
  supporting both URL references and binary blob storage.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:__meta__, :blob]}

  @type t :: %__MODULE__{
          id: binary() | nil,
          url: String.t() | nil,
          blob: binary() | nil,
          attachment_type: String.t() | nil,
          filename: String.t() | nil,
          content_type: String.t() | nil,
          size: integer() | nil,
          checksum: String.t() | nil,
          message_id: binary() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "attachments" do
    field :url, :string
    field :blob, :binary
    field :attachment_type, :string
    field :filename, :string
    field :content_type, :string
    field :size, :integer
    field :checksum, :string
    field :message_id, :binary_id

    timestamps(type: :naive_datetime_usec)
  end

  @doc """
  Creates a changeset for an attachment.

  ## Examples

      iex> changeset(%Attachment{}, %{filename: "document.pdf", attachment_type: "document"})
      %Ecto.Changeset{...}

  """
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [
      :url,
      :blob,
      :attachment_type,
      :filename,
      :content_type,
      :size,
      :checksum,
      :message_id
    ])
    |> validate_required([:attachment_type])
    |> validate_attachment_source()
    |> validate_attachment_type()
    |> validate_content_type()
    |> validate_size()
    |> validate_filename()
  end

  @doc """
  Creates a changeset for URL-based attachments.

  ## Examples

      iex> url_changeset(%Attachment{}, %{url: "https://example.com/file.pdf", attachment_type: "document"})
      %Ecto.Changeset{...}

  """
  def url_changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [
      :url,
      :attachment_type,
      :filename,
      :content_type,
      :size,
      :checksum,
      :message_id
    ])
    |> validate_required([:url, :attachment_type])
    |> validate_url_format()
    |> validate_attachment_type()
    |> validate_content_type()
    |> validate_size()
    |> validate_filename()
  end

  @doc """
  Creates a changeset for blob-based attachments.

  ## Examples

      iex> blob_changeset(%Attachment{}, %{blob: <<binary_data>>, attachment_type: "image", filename: "photo.jpg"})
      %Ecto.Changeset{...}

  """
  def blob_changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [
      :blob,
      :attachment_type,
      :filename,
      :content_type,
      :size,
      :checksum,
      :message_id
    ])
    |> validate_required([:blob, :attachment_type])
    |> validate_attachment_type()
    |> validate_content_type()
    |> validate_size()
    |> validate_filename()
    |> maybe_calculate_size()
    |> maybe_calculate_checksum()
  end

  # Private validation functions

  defp validate_attachment_source(changeset) do
    url = get_field(changeset, :url)
    blob = get_field(changeset, :blob)

    cond do
      url && blob ->
        changeset
        |> add_error(:url, "cannot have both URL and blob")
        |> add_error(:blob, "cannot have both URL and blob")

      url || blob ->
        changeset

      true ->
        changeset
        |> add_error(:url, "must provide either URL or blob")
        |> add_error(:blob, "must provide either URL or blob")
    end
  end

  defp validate_url_format(changeset) do
    changeset
    |> validate_format(:url, ~r/^https?:\/\//, message: "must be a valid HTTP or HTTPS URL")
    |> validate_length(:url, max: 2048, message: "URL is too long")
  end

  defp validate_attachment_type(changeset) do
    valid_types = [
      "image",
      "document",
      "video",
      "audio",
      "archive",
      "text",
      "other"
    ]

    validate_inclusion(changeset, :attachment_type, valid_types,
      message: "must be one of: #{Enum.join(valid_types, ", ")}"
    )
  end

  defp validate_content_type(changeset) do
    changeset
    |> validate_format(:content_type, ~r/^[a-z-]+\/[a-z0-9\.\-\+]+$/i, message: "must be a valid MIME type")
    |> validate_length(:content_type, max: 255)
  end

  defp validate_size(changeset) do
    # Maximum file size: 50MB
    max_size = 50 * 1024 * 1024

    changeset
    |> validate_number(:size, greater_than: 0, message: "must be greater than 0")
    |> validate_number(:size,
      less_than_or_equal_to: max_size,
      message: "must be less than 50MB"
    )
  end

  defp validate_filename(changeset) do
    changeset
    |> validate_length(:filename, max: 255)
    |> validate_format(:filename, ~r/^[^\/\\<>:"|?*]+$/, message: "contains invalid characters")
  end

  defp maybe_calculate_size(changeset) do
    case get_field(changeset, :blob) do
      nil ->
        changeset

      blob when is_binary(blob) ->
        put_change(changeset, :size, byte_size(blob))

      _ ->
        changeset
    end
  end

  defp maybe_calculate_checksum(changeset) do
    case get_field(changeset, :blob) do
      nil ->
        changeset

      blob when is_binary(blob) ->
        checksum = :sha256 |> :crypto.hash(blob) |> Base.encode16(case: :lower)
        put_change(changeset, :checksum, checksum)

      _ ->
        changeset
    end
  end

  @doc """
  Helper function to determine if an attachment is stored as a URL or blob.

  ## Examples

      iex> storage_type(%Attachment{url: "https://example.com/file.pdf"})
      :url

      iex> storage_type(%Attachment{blob: <<1, 2, 3>>})
      :blob

  """
  def storage_type(%__MODULE__{url: url, blob: blob}) when not is_nil(url) and is_nil(blob), do: :url

  def storage_type(%__MODULE__{url: url, blob: blob}) when is_nil(url) and not is_nil(blob), do: :blob

  def storage_type(_), do: :unknown

  @doc """
  Helper function to get the human-readable size of an attachment.

  ## Examples

      iex> human_size(%Attachment{size: 1024})
      "1.0 KB"

      iex> human_size(%Attachment{size: 1_048_576})
      "1.0 MB"

  """
  def human_size(%__MODULE__{size: nil}), do: "Unknown"
  def human_size(%__MODULE__{size: size}) when size < 1024, do: "#{size} B"

  def human_size(%__MODULE__{size: size}) when size < 1024 * 1024 do
    "#{Float.round(size / 1024, 1)} KB"
  end

  def human_size(%__MODULE__{size: size}) when size < 1024 * 1024 * 1024 do
    "#{Float.round(size / (1024 * 1024), 1)} MB"
  end

  def human_size(%__MODULE__{size: size}) do
    "#{Float.round(size / (1024 * 1024 * 1024), 1)} GB"
  end
end
