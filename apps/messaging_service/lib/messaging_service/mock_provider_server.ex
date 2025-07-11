defmodule MessagingService.MockProviderServer do
  @moduledoc """
  A GenServer that mimics external messaging providers like Twilio, SendGrid, etc.

  This server simulates the behavior of external messaging services:
  - Accepts messages via HTTP-like interface
  - Returns appropriate HTTP status codes
  - Simulates delays and failures
  - Tracks message history
  - Can simulate different provider behaviors
  """

  use GenServer
  require Logger

  @type provider_type :: :twilio | :sendgrid | :mailgun | :generic
  @type message_status :: :pending | :sent | :delivered | :failed
  @type response :: %{
          status_code: integer(),
          message_id: String.t(),
          body: map(),
          headers: map()
        }

  defstruct [
    :provider_type,
    :config,
    messages: %{},
    failure_rate: 0.0,
    delay_range: {100, 500}
  ]

  ## Client API

  @doc """
  Starts the mock provider server.

  Options:
  - `:provider_type` - :twilio, :sendgrid, :mailgun, or :generic (default: :generic)
  - `:failure_rate` - Float between 0.0 and 1.0 for simulated failures (default: 0.0)
  - `:delay_range` - Tuple {min_ms, max_ms} for simulated delays (default: {100, 500})
  - `:config` - Provider-specific configuration
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Send a message through the mock provider.
  Returns a response similar to what real providers return.
  """
  def send_message(provider \\ __MODULE__, message) do
    GenServer.call(provider, {:send_message, message})
  end

  @doc """
  Get the status of a previously sent message.
  """
  def get_message_status(provider \\ __MODULE__, message_id) do
    GenServer.call(provider, {:get_status, message_id})
  end

  @doc """
  Get all messages sent to this provider (for testing).
  """
  def get_all_messages(provider \\ __MODULE__) do
    GenServer.call(provider, :get_all_messages)
  end

  @doc """
  Clear all message history.
  """
  def clear_messages(provider \\ __MODULE__) do
    GenServer.call(provider, :clear_messages)
  end

  @doc """
  Update provider configuration at runtime.
  """
  def update_config(provider \\ __MODULE__, config_updates) do
    GenServer.call(provider, {:update_config, config_updates})
  end

  @doc """
  Validate provider credentials.
  Returns :ok if valid, {:error, reason} if invalid.
  """
  def validate_provider_credentials(provider \\ __MODULE__) do
    GenServer.call(provider, :validate_credentials)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      provider_type: Keyword.get(opts, :provider_type, :generic),
      failure_rate: Keyword.get(opts, :failure_rate, 0.0),
      delay_range: Keyword.get(opts, :delay_range, {100, 500}),
      config: Keyword.get(opts, :config, %{})
    }

    Logger.info(
      "Mock #{state.provider_type} provider started with config: #{inspect(state.config)}"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:send_message, message}, _from, state) do
    # Validate credentials first
    case validate_credentials(state.provider_type, state.config) do
      :ok ->
        process_message(message, state)

      {:error, reason} ->
        response = create_credential_error_response(state.provider_type, reason)
        {:reply, response, state}
    end
  end

  @impl true
  def handle_call({:get_status, message_id}, _from, state) do
    case Map.get(state.messages, message_id) do
      nil ->
        response = %{
          status_code: 404,
          body: %{error: "Message not found"},
          headers: %{"content-type" => "application/json"}
        }

        {:reply, response, state}

      message_record ->
        # Simulate status progression over time
        current_status = simulate_status_progression(message_record)

        response = %{
          status_code: 200,
          body: create_status_response(state.provider_type, message_record, current_status),
          headers: %{"content-type" => "application/json"}
        }

        {:reply, response, state}
    end
  end

  @impl true
  def handle_call(:get_all_messages, _from, state) do
    {:reply, state.messages, state}
  end

  @impl true
  def handle_call(:clear_messages, _from, state) do
    new_state = %{state | messages: %{}}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:update_config, config_updates}, _from, state) do
    new_config = Map.merge(state.config, config_updates)
    new_state = %{state | config: new_config}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:validate_credentials, _from, state) do
    result = validate_credentials(state.provider_type, state.config)
    {:reply, result, state}
  end

  ## Private Functions

  defp validate_credentials(:twilio, config) do
    cond do
      not Map.has_key?(config, :account_sid) or is_nil(config.account_sid) ->
        {:error, "Missing required Twilio Account SID"}

      not Map.has_key?(config, :auth_token) or is_nil(config.auth_token) ->
        {:error, "Missing required Twilio Auth Token"}

      String.length(config.account_sid) < 10 ->
        {:error, "Invalid Twilio Account SID format"}

      String.length(config.auth_token) < 8 ->
        {:error, "Invalid Twilio Auth Token format"}

      true ->
        :ok
    end
  end

  defp validate_credentials(:sendgrid, config) do
    cond do
      not Map.has_key?(config, :api_key) or is_nil(config.api_key) ->
        {:error, "Missing required SendGrid API Key"}

      not String.starts_with?(config.api_key, "SG.") ->
        {:error, "Invalid SendGrid API Key format (must start with 'SG.')"}

      String.length(config.api_key) < 10 ->
        {:error, "Invalid SendGrid API Key format (too short)"}

      true ->
        :ok
    end
  end

  defp validate_credentials(:generic, _config) do
    # Generic provider doesn't require specific credentials
    :ok
  end

  defp validate_credentials(provider_type, _config) do
    {:error, "Unknown provider type: #{provider_type}"}
  end

  defp process_message(message, state) do
    # Simulate network delay
    simulate_delay(state.delay_range)

    # Generate unique message ID
    message_id = generate_message_id(state.provider_type)

    # Determine if this message should fail
    should_fail = :rand.uniform() < state.failure_rate

    response =
      if should_fail do
        create_failure_response(state.provider_type, message, message_id)
      else
        create_success_response(state.provider_type, message, message_id)
      end

    # Store message in state
    message_record = %{
      id: message_id,
      message: message,
      status: if(should_fail, do: :failed, else: :sent),
      timestamp: DateTime.utc_now(),
      response: response
    }

    new_state = %{state | messages: Map.put(state.messages, message_id, message_record)}

    Logger.info(
      "Mock #{state.provider_type} processed message #{message_id}: #{response.status_code}"
    )

    {:reply, response, new_state}
  end

  defp simulate_delay({min_ms, max_ms}) do
    delay = min_ms + :rand.uniform(max_ms - min_ms)
    Process.sleep(delay)
  end

  defp generate_message_id(provider_type) do
    timestamp = System.system_time(:millisecond)
    random = :rand.uniform(999_999)

    case provider_type do
      :twilio -> "SM#{timestamp}#{random}"
      :sendgrid -> "sg_#{timestamp}_#{random}"
      :mailgun -> "mg_#{timestamp}_#{random}"
      _ -> "msg_#{timestamp}_#{random}"
    end
  end

  defp create_success_response(:twilio, message, message_id) do
    %{
      status_code: 201,
      message_id: message_id,
      body: %{
        "sid" => message_id,
        "status" => "queued",
        "to" => Map.get(message, :to),
        "from" => Map.get(message, :from),
        "body" => Map.get(message, :body),
        "direction" => "outbound-api",
        "date_created" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "price" => "0.0075",
        "price_unit" => "USD"
      },
      headers: %{
        "content-type" => "application/json",
        "x-twilio-request-id" =>
          "RQ#{:rand.uniform(1_000_000_000_000_000_000_000_000_000_000_000)}"
      }
    }
  end

  defp create_success_response(:sendgrid, _message, message_id) do
    %{
      status_code: 202,
      message_id: message_id,
      body: %{
        "message" => "success",
        "message_id" => message_id
      },
      headers: %{
        "content-type" => "application/json",
        "x-message-id" => message_id
      }
    }
  end

  defp create_success_response(_, message, message_id) do
    %{
      status_code: 200,
      message_id: message_id,
      body: %{
        "id" => message_id,
        "status" => "sent",
        "message" => message
      },
      headers: %{
        "content-type" => "application/json"
      }
    }
  end

  defp create_failure_response(:twilio, _message, message_id) do
    %{
      status_code: 400,
      message_id: message_id,
      body: %{
        "code" => 21211,
        "message" => "The 'To' number is not a valid phone number.",
        "more_info" => "https://www.twilio.com/docs/errors/21211",
        "status" => 400
      },
      headers: %{
        "content-type" => "application/json"
      }
    }
  end

  defp create_failure_response(:sendgrid, _message, message_id) do
    %{
      status_code: 400,
      message_id: message_id,
      body: %{
        "errors" => [
          %{
            "message" => "Invalid email address",
            "field" => "to.email",
            "help" => "Please provide a valid email address"
          }
        ]
      },
      headers: %{
        "content-type" => "application/json"
      }
    }
  end

  defp create_failure_response(_, _message, message_id) do
    %{
      status_code: 500,
      message_id: message_id,
      body: %{
        "error" => "Internal server error",
        "message" => "Unable to process message"
      },
      headers: %{
        "content-type" => "application/json"
      }
    }
  end

  defp simulate_status_progression(message_record) do
    # Simulate status changes over time
    age_seconds = DateTime.diff(DateTime.utc_now(), message_record.timestamp)

    case message_record.status do
      :failed -> :failed
      :sent when age_seconds < 5 -> :sent
      :sent when age_seconds < 30 -> :delivered
      :sent -> :delivered
      status -> status
    end
  end

  defp create_status_response(:twilio, message_record, current_status) do
    %{
      "sid" => message_record.id,
      "status" => to_string(current_status),
      "to" => get_in(message_record.message, [:to]),
      "from" => get_in(message_record.message, [:from]),
      "date_sent" => message_record.timestamp |> DateTime.to_iso8601()
    }
  end

  defp create_status_response(:sendgrid, message_record, current_status) do
    %{
      "message_id" => message_record.id,
      "status" => to_string(current_status),
      "events" => [
        %{
          "event" => to_string(current_status),
          "timestamp" => message_record.timestamp |> DateTime.to_unix()
        }
      ]
    }
  end

  defp create_status_response(_, message_record, current_status) do
    %{
      "id" => message_record.id,
      "status" => to_string(current_status),
      "timestamp" => message_record.timestamp |> DateTime.to_iso8601()
    }
  end

  defp create_credential_error_response(:twilio, reason) do
    %{
      status_code: 401,
      message_id: nil,
      body: %{
        "status" => 401,
        "message" => "Authenticate",
        "detail" => reason,
        "code" => 20003
      },
      headers: %{
        "content-type" => "application/json",
        "www-authenticate" => "Basic realm=\"Twilio API\""
      }
    }
  end

  defp create_credential_error_response(:sendgrid, reason) do
    %{
      status_code: 401,
      message_id: nil,
      body: %{
        "errors" => [
          %{
            "message" => reason,
            "field" => "authorization",
            "help" => "Check your API key"
          }
        ]
      },
      headers: %{
        "content-type" => "application/json"
      }
    }
  end

  defp create_credential_error_response(_provider_type, reason) do
    %{
      status_code: 401,
      message_id: nil,
      body: %{
        "error" => "Unauthorized",
        "message" => reason
      },
      headers: %{
        "content-type" => "application/json"
      }
    }
  end
end
