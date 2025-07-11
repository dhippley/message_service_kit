defmodule MessagingService.Repo do
  use Ecto.Repo,
    otp_app: :messaging_service,
    adapter: Ecto.Adapters.Postgres
end
