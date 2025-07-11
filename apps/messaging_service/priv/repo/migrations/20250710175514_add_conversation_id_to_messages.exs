defmodule MessagingService.Repo.Migrations.AddConversationIdToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :conversation_id, references(:conversations, on_delete: :delete_all, type: :binary_id)
    end

    create index(:messages, [:conversation_id])
  end
end
