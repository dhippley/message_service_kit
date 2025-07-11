defmodule MessagingService.Attachments do
  @moduledoc """
  The Attachments context.

  This module provides functions for managing message attachments,
  including creating, retrieving, and deleting attachments.
  """

  import Ecto.Query, warn: false
  alias MessagingService.Repo
  alias MessagingService.Attachment

  @doc """
  Returns the list of attachments.

  ## Examples

      iex> list_attachments()
      [%Attachment{}, ...]

  """
  def list_attachments do
    Repo.all(Attachment)
  end

  @doc """
  Gets a single attachment.

  Raises `Ecto.NoResultsError` if the Attachment does not exist.

  ## Examples

      iex> get_attachment!(123)
      %Attachment{}

      iex> get_attachment!(456)
      ** (Ecto.NoResultsError)

  """
  def get_attachment!(id), do: Repo.get!(Attachment, id)

  @doc """
  Gets a single attachment.

  Returns `nil` if the Attachment does not exist.

  ## Examples

      iex> get_attachment(123)
      %Attachment{}

      iex> get_attachment(456)
      nil

  """
  def get_attachment(id), do: Repo.get(Attachment, id)

  @doc """
  Creates an attachment from a URL.

  ## Examples

      iex> create_url_attachment(%{url: "https://example.com/file.pdf", attachment_type: "document"})
      {:ok, %Attachment{}}

      iex> create_url_attachment(%{url: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def create_url_attachment(attrs \\ %{}) do
    %Attachment{}
    |> Attachment.url_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates an attachment from binary data.

  ## Examples

      iex> create_blob_attachment(%{blob: <<data>>, attachment_type: "image", filename: "photo.jpg"})
      {:ok, %Attachment{}}

      iex> create_blob_attachment(%{blob: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_blob_attachment(attrs \\ %{}) do
    %Attachment{}
    |> Attachment.blob_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an attachment.

  ## Examples

      iex> update_attachment(attachment, %{filename: "new_name.pdf"})
      {:ok, %Attachment{}}

      iex> update_attachment(attachment, %{attachment_type: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def update_attachment(%Attachment{} = attachment, attrs) do
    attachment
    |> Attachment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an attachment.

  ## Examples

      iex> delete_attachment(attachment)
      {:ok, %Attachment{}}

      iex> delete_attachment(attachment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_attachment(%Attachment{} = attachment) do
    Repo.delete(attachment)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking attachment changes.

  ## Examples

      iex> change_attachment(attachment)
      %Ecto.Changeset{data: %Attachment{}}

  """
  def change_attachment(%Attachment{} = attachment, attrs \\ %{}) do
    Attachment.changeset(attachment, attrs)
  end

  @doc """
  Lists attachments by type.

  ## Examples

      iex> list_attachments_by_type("image")
      [%Attachment{attachment_type: "image"}, ...]

  """
  def list_attachments_by_type(type) do
    from(a in Attachment, where: a.attachment_type == ^type)
    |> Repo.all()
  end

  @doc """
  Lists attachments by content type.

  ## Examples

      iex> list_attachments_by_content_type("image/jpeg")
      [%Attachment{content_type: "image/jpeg"}, ...]

  """
  def list_attachments_by_content_type(content_type) do
    from(a in Attachment, where: a.content_type == ^content_type)
    |> Repo.all()
  end

  @doc """
  Gets total size of all attachments.

  ## Examples

      iex> get_total_attachment_size()
      1024000

  """
  def get_total_attachment_size do
    from(a in Attachment, select: sum(a.size))
    |> Repo.one()
    |> case do
      nil -> 0
      size -> size
    end
  end

  @doc """
  Gets attachments larger than the specified size.

  ## Examples

      iex> get_large_attachments(1024 * 1024) # 1MB
      [%Attachment{}, ...]

  """
  def get_large_attachments(min_size) do
    from(a in Attachment, where: a.size > ^min_size, order_by: [desc: a.size])
    |> Repo.all()
  end

  @doc """
  Validates if an attachment exists and is accessible.

  ## Examples

      iex> validate_attachment_exists(attachment_id)
      {:ok, %Attachment{}}

      iex> validate_attachment_exists("nonexistent")
      {:error, :not_found}

  """
  def validate_attachment_exists(attachment_id) do
    case get_attachment(attachment_id) do
      nil -> {:error, :not_found}
      attachment -> {:ok, attachment}
    end
  end

  @doc """
  Cleanup orphaned attachments (if you have a relationship with messages in the future).
  For now, this is a placeholder function.

  ## Examples

      iex> cleanup_orphaned_attachments()
      {:ok, 0}

  """
  def cleanup_orphaned_attachments do
    # This would be implemented when attachments are linked to messages
    # For now, just return success with 0 cleaned up
    {:ok, 0}
  end
end
