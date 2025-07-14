defmodule MockProvider.ConversationSimulator do
  @moduledoc """
  Simulates SMS conversations by making API calls to the messaging_service app.
  This module creates realistic back-and-forth conversations for testing purposes.
  """

  require Logger

  @messaging_service_base_url "http://localhost:4000/api"
  @default_conversation_scenarios [
    %{
      name: "customer_support",
      participants: %{
        customer: "+15551234567",
        agent: "+15559876543"
      },
      # Customer messages use webhook (incoming), agent responses use API (outgoing)
      messages: [
        %{from: "+15551234567", to: "+15559876543", body: "Hi, I need help with my order", delay: 0, endpoint: "webhook"},
        %{from: "+15559876543", to: "+15551234567", body: "Hello! I'd be happy to help. What's your order number?", delay: 2000, endpoint: "api"},
        %{from: "+15551234567", to: "+15559876543", body: "It's #ORD-12345", delay: 3000, endpoint: "webhook"},
        %{from: "+15559876543", to: "+15551234567", body: "Let me look that up for you. One moment please.", delay: 1500, endpoint: "api"},
        %{from: "+15559876543", to: "+15551234567", body: "I found your order! It was shipped yesterday and should arrive tomorrow.", delay: 4000, endpoint: "api"},
        %{from: "+15551234567", to: "+15559876543", body: "Great! Thank you so much for your help!", delay: 2000, endpoint: "webhook"}
      ]
    },
    %{
      name: "delivery_updates",
      participants: %{
        delivery_service: "+15550001111",
        customer: "+15552223333"
      },
      # Delivery service uses API (outgoing), customer responses use webhook (incoming)
      messages: [
        %{from: "+15550001111", to: "+15552223333", body: "Your package is out for delivery today between 2-6 PM", delay: 0, endpoint: "api"},
        %{from: "+15552223333", to: "+15550001111", body: "Thanks! Will someone need to be home to sign for it?", delay: 5000, endpoint: "webhook"},
        %{from: "+15550001111", to: "+15552223333", body: "No signature required. We'll leave it at your door if you're not home.", delay: 3000, endpoint: "api"},
        %{from: "+15552223333", to: "+15550001111", body: "Perfect, thanks for letting me know!", delay: 2000, endpoint: "webhook"},
        %{from: "+15550001111", to: "+15552223333", body: "Your package has been delivered!", delay: 8000, endpoint: "api"}
      ]
    },
    %{
      name: "appointment_booking",
      participants: %{
        clinic: "+15554445555",
        patient: "+15556667777"
      },
      # Patient messages use webhook (incoming), clinic responses use API (outgoing)
      messages: [
        %{from: "+15556667777", to: "+15554445555", body: "Hi, I'd like to schedule an appointment", delay: 0, endpoint: "webhook"},
        %{from: "+15554445555", to: "+15556667777", body: "Of course! What type of appointment are you looking for?", delay: 2000, endpoint: "api"},
        %{from: "+15556667777", to: "+15554445555", body: "Just a routine checkup", delay: 3000, endpoint: "webhook"},
        %{from: "+15554445555", to: "+15556667777", body: "I have availability next Tuesday at 2 PM or Wednesday at 10 AM. Which works better?", delay: 4000, endpoint: "api"},
        %{from: "+15556667777", to: "+15554445555", body: "Tuesday at 2 PM would be perfect", delay: 2500, endpoint: "webhook"},
        %{from: "+15554445555", to: "+15556667777", body: "Great! You're all set for Tuesday, January 16th at 2:00 PM. See you then!", delay: 3000, endpoint: "api"}
      ]
    }
  ]

  def simulate_conversation(conn) do
    with {:ok, params} <- parse_request_params(conn),
         {:ok, scenario} <- get_scenario(params),
         :ok <- execute_conversation(scenario) do

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        status: "success",
        message: "Conversation simulation started",
        scenario: scenario.name,
        participants: scenario.participants,
        message_count: length(scenario.messages)
      }))
    else
      {:error, reason} ->
        Logger.error("Conversation simulation failed: #{inspect(reason)}")
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          status: "error",
          message: reason
        }))
    end
  end

  defp parse_request_params(conn) do
    case conn.body_params do
      %{"scenario" => scenario} when is_binary(scenario) ->
        {:ok, %{scenario: scenario}}

      %{} ->
        {:ok, %{scenario: "random"}}

      _ ->
        {:error, "Invalid request format"}
    end
  end

  defp get_scenario(%{scenario: "random"}) do
    scenario = Enum.random(@default_conversation_scenarios)
    {:ok, scenario}
  end

  defp get_scenario(%{scenario: scenario_name}) do
    case Enum.find(@default_conversation_scenarios, &(&1.name == scenario_name)) do
      nil -> {:error, "Scenario '#{scenario_name}' not found"}
      scenario -> {:ok, scenario}
    end
  end

  defp execute_conversation(scenario) do
    Logger.info("Starting conversation simulation: #{scenario.name}")

    # Spawn a process to handle the conversation asynchronously
    Task.start(fn ->
      Enum.each(scenario.messages, fn message ->
        if message.delay > 0 do
          Process.sleep(message.delay)
        end

        send_message(message)
      end)

      Logger.info("Completed conversation simulation: #{scenario.name}")
    end)

    :ok
  end

  defp send_message(message) do
    case message.endpoint do
      "api" -> send_via_api(message)
      "webhook" -> send_via_webhook(message)
      _ -> {:error, "Unknown endpoint: #{message.endpoint}"}
    end
  end

  defp send_via_api(message) do
    case send_sms_to_messaging_service(message) do
      {:ok, response} ->
        Logger.info("Sent API message: #{message.body} (#{message.from} -> #{message.to})")
        response

      {:error, reason} ->
        Logger.error("Failed to send API message: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp send_via_webhook(message) do
    case send_webhook_to_messaging_service(message) do
      {:ok, response} ->
        Logger.info("Sent webhook message: #{message.body} (#{message.from} -> #{message.to})")
        response

      {:error, reason} ->
        Logger.error("Failed to send webhook message: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp send_sms_to_messaging_service(message) do
    url = "#{@messaging_service_base_url}/messages/sms"

    payload = %{
      to: message.to,
      from: message.from,
      body: message.body
    }

    case Req.post(url, json: payload) do
      {:ok, %{status: 201, body: body}} ->
        {:ok, body}

      {:ok, %{status: status_code, body: body}} ->
        {:error, "HTTP #{status_code}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Network error: #{inspect(reason)}"}
    end
  rescue
    exception ->
      {:error, "Exception occurred: #{inspect(exception)}"}
  end

  defp send_webhook_to_messaging_service(message) do
    url = "#{@messaging_service_base_url}/webhooks/sms"

    # Webhook payload format (using lowercase keys expected by the controller)
    payload = %{
      from: message.from,
      to: message.to,
      body: message.body,
      provider_id: "SM#{:rand.uniform(100000000000000000000000000000000)}",
      type: "sms"
    }

    headers = [
      {"authorization", "ApiKey dev-api-key-123"}
    ]

    case Req.post(url, form: payload, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status_code, body: body}} ->
        {:error, "HTTP #{status_code}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Network error: #{inspect(reason)}"}
    end
  rescue
    exception ->
      {:error, "Exception occurred: #{inspect(exception)}"}
  end

  @doc """
  Returns a list of available conversation scenarios.
  """
  def list_scenarios do
    Enum.map(@default_conversation_scenarios, fn scenario ->
      %{
        name: scenario.name,
        participants: scenario.participants,
        message_count: length(scenario.messages),
        description: get_scenario_description(scenario.name)
      }
    end)
  end

  defp get_scenario_description("customer_support"), do: "A customer service interaction about an order inquiry"
  defp get_scenario_description("delivery_updates"), do: "Package delivery notifications and customer responses"
  defp get_scenario_description("appointment_booking"), do: "Medical appointment scheduling conversation"
  defp get_scenario_description(_), do: "Custom conversation scenario"
end
