defmodule MessagingService.Repo.Migrations.AddMessageIdToAttachments do
  use Ecto.Migration

  def change do
    alter table(:attachments) do
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all)
    end

    create index(:attachments, [:message_id])
  end
end
