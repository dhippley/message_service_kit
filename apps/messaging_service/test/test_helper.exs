# Start the mock provider for testing
{:ok, _} = Application.ensure_all_started(:mock_provider)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MessagingService.Repo, :manual)
