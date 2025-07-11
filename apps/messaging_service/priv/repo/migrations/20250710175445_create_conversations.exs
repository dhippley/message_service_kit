defmodule MessagingService.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :participant_one, :string, null: false
      add :participant_two, :string, null: false
      add :last_message_at, :naive_datetime_usec
      add :message_count, :integer, default: 0, null: false

      timestamps(type: :naive_datetime_usec)
    end

    create unique_index(:conversations, [:participant_one, :participant_two])
    create index(:conversations, [:participant_one])
    create index(:conversations, [:participant_two])
    create index(:conversations, [:last_message_at])
  end
end
