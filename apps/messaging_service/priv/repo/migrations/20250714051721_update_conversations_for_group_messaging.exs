defmodule MessagingService.Repo.Migrations.UpdateConversationsForGroupMessaging do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      # Add new field for storing list of participants as JSON
      add :participants, :text

      # Add conversation type to distinguish between direct and group conversations
      add :conversation_type, :string, default: "direct"
    end

    # Add regular index for participants field for basic lookups
    create index(:conversations, [:participants])
    create index(:conversations, [:conversation_type])

    # Add constraint for valid conversation types
    create constraint(:conversations, :valid_conversation_type,
           check: "conversation_type IN ('direct', 'group')")
  end
end
