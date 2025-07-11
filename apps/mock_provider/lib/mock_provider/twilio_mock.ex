defmodule MockProvider.TwilioMock do
  @moduledoc """
  Mock implementation of Twilio SMS/MMS API endpoints.
  """

  import Plug.Conn
  require Logger

  @doc """
  Handles SMS/MMS message sending requests, mimicking Twilio's API response format.
  """
  def send_message(conn) do
    # Simulate processing delay
    :timer.sleep(100)

    params = conn.body_params || %{}

    # Generate mock response like Twilio
    sid = "SM" <> generate_sid()

    response = %{
      account_sid: conn.path_params["account_sid"] || "AC" <> generate_sid(),
      api_version: "2010-04-01",
      body: params["Body"] || "",
      date_created: DateTime.utc_now() |> DateTime.to_iso8601(),
      date_sent: nil,
      date_updated: DateTime.utc_now() |> DateTime.to_iso8601(),
      direction: "outbound-api",
      error_code: nil,
      error_message: nil,
      from: params["From"] || "",
      messaging_service_sid: nil,
      num_media: count_media(params),
      num_segments: "1",
      price: nil,
      price_unit: "USD",
      sid: sid,
      status: "queued",
      subresource_uris: %{
        media:
          "/2010-04-01/Accounts/#{conn.path_params["account_sid"]}/Messages/#{sid}/Media.json"
      },
      to: params["To"] || "",
      uri: "/2010-04-01/Accounts/#{conn.path_params["account_sid"]}/Messages/#{sid}.json"
    }

    Logger.info("Mock Twilio message sent: #{sid} from #{params["From"]} to #{params["To"]}")

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(201, Jason.encode!(response))
  end

  @doc """
  Handles message status requests, mimicking Twilio's API response format.
  """
  def get_message_status(conn) do
    # Simulate processing delay
    :timer.sleep(50)

    account_sid = conn.path_params["account_sid"]
    message_id = conn.path_params["message_id"]

    response = %{
      account_sid: account_sid,
      api_version: "2010-04-01",
      body: "Hello from mock Twilio",
      date_created: DateTime.utc_now() |> DateTime.add(-300) |> DateTime.to_iso8601(),
      date_sent: DateTime.utc_now() |> DateTime.add(-200) |> DateTime.to_iso8601(),
      date_updated: DateTime.utc_now() |> DateTime.to_iso8601(),
      direction: "outbound-api",
      error_code: nil,
      error_message: nil,
      from: "+15551234567",
      messaging_service_sid: nil,
      num_media: "0",
      num_segments: "1",
      price: "-0.00750",
      price_unit: "USD",
      sid: message_id,
      status: "delivered",
      subresource_uris: %{
        media: "/2010-04-01/Accounts/#{account_sid}/Messages/#{message_id}/Media.json"
      },
      to: "+1234567890",
      uri: "/2010-04-01/Accounts/#{account_sid}/Messages/#{message_id}.json"
    }

    Logger.info("Mock Twilio message status requested: #{message_id}")

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  defp generate_sid do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.encode32(case: :lower, padding: false)
    |> String.slice(0, 32)
  end

  defp count_media(params) do
    params
    |> Enum.filter(fn {key, _value} -> String.starts_with?(key, "MediaUrl") end)
    |> length()
    |> to_string()
  end
end
