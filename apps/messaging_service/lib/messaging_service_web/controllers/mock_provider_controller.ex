defmodule MessagingServiceWeb.MockProviderController do
  use MessagingServiceWeb, :controller
  require Logger

  @doc """
  Mock Twilio SMS API endpoint.
  Accepts messages and returns Twilio-like responses.
  """
  def twilio_send_sms(conn, params) do
    message = %{
      to: Map.get(params, "To"),
      from: Map.get(params, "From"),
      body: Map.get(params, "Body")
    }

    case MessagingService.MockProviderServer.send_message(:twilio_server, message) do
      %{status_code: status_code, body: body, headers: headers} ->
        conn
        |> add_response_headers(headers)
        |> put_status(status_code)
        |> json(body)
    end
  end

  @doc """
  Mock SendGrid Email API endpoint.
  Accepts email messages and returns SendGrid-like responses.
  """
  def sendgrid_send_email(conn, params) do
    message = %{
      to:
        get_in(params, ["personalizations", Access.at(0), "to", Access.at(0), "email"]) ||
          get_in(params, ["to"]),
      from: get_in(params, ["from", "email"]) || get_in(params, ["from"]),
      subject: Map.get(params, "subject"),
      body: get_in(params, ["content", Access.at(0), "value"]) || Map.get(params, "content")
    }

    case MessagingService.MockProviderServer.send_message(:sendgrid_server, message) do
      %{status_code: status_code, body: body, headers: headers} ->
        conn
        |> add_response_headers(headers)
        |> put_status(status_code)
        |> json(body)
    end
  end

  @doc """
  Generic mock provider endpoint.
  Accepts any message format and returns generic responses.
  """
  def generic_send(conn, params) do
    message = %{
      to: Map.get(params, "to"),
      from: Map.get(params, "from"),
      body: Map.get(params, "body") || Map.get(params, "content"),
      type: Map.get(params, "type", "generic")
    }

    case MessagingService.MockProviderServer.send_message(:generic_server, message) do
      %{status_code: status_code, body: body, headers: headers} ->
        conn
        |> add_response_headers(headers)
        |> put_status(status_code)
        |> json(body)
    end
  end

  @doc """
  Get message status for any provider.
  """
  def get_message_status(conn, %{"provider" => provider, "message_id" => message_id}) do
    server_name = String.to_atom("#{provider}_server")

    case MessagingService.MockProviderServer.get_message_status(server_name, message_id) do
      %{status_code: status_code, body: body, headers: headers} ->
        conn
        |> add_response_headers(headers)
        |> put_status(status_code)
        |> json(body)
    end
  end

  def get_message_status(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing provider or message_id parameter"})
  end

  @doc """
  Get all messages sent to a provider (for testing).
  """
  def get_all_messages(conn, %{"provider" => provider}) do
    server_name = String.to_atom("#{provider}_server")
    messages = MessagingService.MockProviderServer.get_all_messages(server_name)

    conn
    |> put_status(200)
    |> json(%{messages: messages, count: map_size(messages)})
  end

  def get_all_messages(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing provider parameter"})
  end

  @doc """
  Clear all messages for a provider (for testing).
  """
  def clear_messages(conn, %{"provider" => provider}) do
    server_name = String.to_atom("#{provider}_server")
    MessagingService.MockProviderServer.clear_messages(server_name)

    conn
    |> put_status(200)
    |> json(%{message: "Messages cleared"})
  end

  def clear_messages(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing provider parameter"})
  end

  # Helper function to add response headers
  defp add_response_headers(conn, headers) when is_map(headers) do
    Enum.reduce(headers, conn, fn {key, value}, acc ->
      put_resp_header(acc, key, value)
    end)
  end
end
