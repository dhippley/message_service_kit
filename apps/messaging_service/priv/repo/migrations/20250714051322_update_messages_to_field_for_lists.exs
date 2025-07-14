defmodule MessagingService.Repo.Migrations.UpdateMessagesToFieldForLists do
  @moduledoc false
  use Ecto.Migration

  def change do
    # Change the 'to' field from string to text to support JSON storage
    # This allows storing both single phone numbers (strings) and lists of phone numbers
    alter table(:messages) do
      modify(:to, :text, null: false)
    end
  end
end
