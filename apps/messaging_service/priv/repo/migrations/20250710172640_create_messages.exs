defmodule MessagingService.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :to, :string, null: false
      add :from, :string, null: false
      add :type, :string, null: false
      add :body, :text, null: false
      add :messaging_provider_id, :string
      add :timestamp, :naive_datetime_usec

      timestamps(type: :naive_datetime_usec)
    end

    # Add indexes for performance
    create index(:messages, [:to])
    create index(:messages, [:from])
    create index(:messages, [:type])
    create index(:messages, [:messaging_provider_id])
    create index(:messages, [:timestamp])

    # Add constraint for valid message types
    create constraint(:messages, :valid_message_type, check: "type IN ('sms', 'mms', 'email')")

    # Add combined index for conversation queries (to, from combination)
    create index(:messages, [:to, :from])
    create index(:messages, [:from, :to])
  end
end
