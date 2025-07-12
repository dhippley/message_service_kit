defmodule MessagingService.Repo.Migrations.AddMessageStatusFields do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :status, :string, default: "pending", null: false
      add :direction, :string, default: "outbound", null: false
      add :queued_at, :naive_datetime_usec
      add :sent_at, :naive_datetime_usec
      add :delivered_at, :naive_datetime_usec
      add :failed_at, :naive_datetime_usec
      add :failure_reason, :text
    end

    # Add indexes for better query performance
    create index(:messages, [:status])
    create index(:messages, [:direction])
    create index(:messages, [:queued_at])
    create index(:messages, [:sent_at])
  end
end
