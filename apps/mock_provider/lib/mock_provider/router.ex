defmodule MockProvider.Router do
  @moduledoc """
  HTTP router for MockProvider that simulates Twilio and SendGrid APIs.
  """

  use Plug.Router

  require Logger

  plug(Plug.Logger)
  plug(:match)
  plug(Plug.Parsers, parsers: [:urlencoded, :json], json_decoder: Jason)
  plug(:dispatch)

  # Twilio-like SMS endpoint
  post "/v1/Accounts/:account_sid/Messages" do
    MockProvider.TwilioMock.send_message(conn)
  end

  # Twilio-like SMS endpoint with .json extension
  post "/v1/Accounts/:account_sid/Messages.json" do
    MockProvider.TwilioMock.send_message(conn)
  end

  # Twilio-like SMS status endpoint
  get "/v1/Accounts/:account_sid/Messages/:message_id.json" do
    MockProvider.TwilioMock.get_message_status(conn)
  end

  # SendGrid-like email endpoint
  post "/v3/mail/send" do
    MockProvider.SendGridMock.send_email(conn)
  end

  # SendGrid message activity endpoint
  get "/v3/messages" do
    MockProvider.SendGridMock.get_message_activity(conn)
  end

  # SMS conversation simulation endpoint
  post "/simulate/sms-conversation" do
    MockProvider.ConversationSimulator.simulate_conversation(conn)
  end

  # SMS stress test endpoint
  post "/simulate/stress-test" do
    MockProvider.ConversationSimulator.stress_test(conn)
  end

  # List available conversation scenarios
  get "/simulate/scenarios" do
    scenarios = MockProvider.ConversationSimulator.list_scenarios()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      200,
      Jason.encode!(%{
        status: "success",
        scenarios: scenarios
      })
    )
  end

  # Health check
  get "/health" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{status: "ok", service: "mock_provider"}))
  end

  # Catch-all
  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "Not found"}))
  end
end
