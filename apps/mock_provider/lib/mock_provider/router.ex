defmodule MockProvider.Router do
  @moduledoc """
  HTTP router for MockProvider that simulates Twilio and SendGrid APIs.
  """

  use Plug.Router

  require Logger

  plug Plug.Logger
  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  # Twilio-like SMS endpoint
  post "/v1/Accounts/:account_sid/Messages" do
    MockProvider.TwilioMock.send_message(conn)
  end

  # SendGrid-like email endpoint  
  post "/v3/mail/send" do
    MockProvider.SendGridMock.send_email(conn)
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
