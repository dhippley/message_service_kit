defmodule MockProvider do
  @moduledoc """
  MockProvider simulates external messaging service APIs like Twilio and SendGrid.

  This application provides HTTP endpoints that mimic the behavior of:
  - Twilio SMS/MMS API
  - SendGrid Email API

  It runs on port 4001 by default and can be used to test messaging
  functionality without requiring real API credentials or sending actual messages.

  ## Endpoints

  ### Twilio-like SMS/MMS
  - `POST /v1/Accounts/{AccountSid}/Messages` - Send SMS/MMS

  ### SendGrid-like Email
  - `POST /v3/mail/send` - Send Email

  ### Health Check
  - `GET /health` - Service status
  """

  @doc """
  Returns the port the MockProvider is running on.
  """
  def port, do: 4001

  @doc """
  Returns the base URL for the MockProvider service.
  """
  def base_url, do: "http://localhost:#{port()}"
end
