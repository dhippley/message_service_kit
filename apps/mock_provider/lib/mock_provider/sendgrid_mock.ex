defmodule MockProvider.SendGridMock do
  @moduledoc """
  Mock implementation of SendGrid Email API endpoints.
  """

  import Plug.Conn

  require Logger

  @doc """
  Handles email sending requests, mimicking SendGrid's API response format.
  """
  def send_email(conn) do
    # Simulate processing delay
    :timer.sleep(150)

    params = conn.body_params || %{}

    # Extract email details from SendGrid format
    personalizations = get_in(params, ["personalizations"]) || []
    from_email = get_in(params, ["from", "email"]) || ""
    subject = get_subject(personalizations)

    # Generate mock message ID like SendGrid
    message_id = generate_message_id()

    # SendGrid typically returns 202 with no body on success
    Logger.info("Mock SendGrid email sent: #{message_id} from #{from_email} subject: #{subject}")

    conn
    |> put_resp_header("x-message-id", message_id)
    |> send_resp(202, "")
  end

  defp generate_message_id do
    timestamp = System.system_time(:millisecond)
    random = 8 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)
    "#{timestamp}.#{random}@sendgrid.net"
  end

  defp get_subject(personalizations) when is_list(personalizations) do
    personalizations
    |> List.first()
    |> case do
      %{"subject" => subject} -> subject
      _ -> ""
    end
  end

  defp get_subject(_), do: ""

  @doc """
  Handles requests for message activity, mimicking SendGrid's API response format.
  """
  def get_message_activity(conn) do
    # Simulate processing delay
    :timer.sleep(100)

    # SendGrid Message Activity API returns an array of events
    response = [
      %{
        "sg_event_id" => "SG" <> (8 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)),
        "event" => "delivered",
        "email" => "test@example.com",
        "timestamp" => System.system_time(:second),
        "smtp-id" => "<" <> generate_message_id() <> ">",
        "sg_message_id" => generate_message_id(),
        "response" => "250 2.0.0 OK",
        "attempt" => "1"
      },
      %{
        "sg_event_id" => "SG" <> (8 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)),
        "event" => "processed",
        "email" => "test@example.com",
        "timestamp" => System.system_time(:second) - 10,
        "smtp-id" => "<" <> generate_message_id() <> ">",
        "sg_message_id" => generate_message_id()
      }
    ]

    Logger.info("Mock SendGrid message activity requested")

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end
end
