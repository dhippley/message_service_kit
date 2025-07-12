defmodule MessagingService.Repo.Migrations.AddProviderNameToMessages do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add(:provider_name, :string)
    end
  end
end
