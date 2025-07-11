defmodule MessagingService.Repo.Migrations.CreateAttachments do
  use Ecto.Migration

  def change do
    create table(:attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :url, :string, size: 2048
      add :blob, :binary
      add :attachment_type, :string, null: false
      add :filename, :string
      add :content_type, :string
      add :size, :bigint
      add :checksum, :string

      timestamps(type: :naive_datetime_usec)
    end

    # Add indexes for performance
    create index(:attachments, [:attachment_type])
    create index(:attachments, [:content_type])
    create index(:attachments, [:filename])
    create index(:attachments, [:checksum])

    # Add constraint to ensure either URL or blob is present (but not both)
    create constraint(:attachments, :url_or_blob_check,
             check: "(url IS NOT NULL AND blob IS NULL) OR (url IS NULL AND blob IS NOT NULL)"
           )

    # Add constraint for valid attachment types
    create constraint(:attachments, :valid_attachment_type,
             check:
               "attachment_type IN ('image', 'document', 'video', 'audio', 'archive', 'text', 'other')"
           )

    # Add constraint for positive file size
    create constraint(:attachments, :positive_size, check: "size IS NULL OR size > 0")
  end
end
