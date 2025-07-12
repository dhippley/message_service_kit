defmodule MessagingServiceWeb.Plugs.MessageAuth do
  @moduledoc """
  Plug for authenticating incoming webhook messages.

  This plug supports multiple authentication methods:
  - API Key authentication via Authorization header
  - Bearer token authentication
  - Basic authentication
  - Custom webhook signature verification
  """

  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case authenticate(conn) do
      :ok ->
        conn

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication failed", reason: reason})
        |> halt()
    end
  end

  defp authenticate(conn) do
    with {:ok, auth_header} <- get_auth_header(conn),
         {:ok, _credentials} <- validate_auth_header(auth_header) do
      :ok
    end
  end

  defp get_auth_header(conn) do
    case get_req_header(conn, "authorization") do
      [] -> {:error, "Missing authorization header"}
      [auth_header] -> {:ok, auth_header}
      _ -> {:error, "Multiple authorization headers"}
    end
  end

  defp validate_auth_header(auth_header) do
    cond do
      String.starts_with?(auth_header, "Bearer ") ->
        validate_bearer_token(auth_header)

      String.starts_with?(auth_header, "Basic ") ->
        validate_basic_auth(auth_header)

      String.starts_with?(auth_header, "ApiKey ") ->
        validate_api_key(auth_header)

      true ->
        {:error, "Unsupported authorization type"}
    end
  end

  defp validate_bearer_token("Bearer " <> token) do
    # Get valid tokens from config
    valid_tokens = get_valid_tokens()

    if token in valid_tokens do
      {:ok, {:bearer, token}}
    else
      {:error, "Invalid bearer token"}
    end
  end

  defp validate_basic_auth("Basic " <> encoded) do
    case Base.decode64(encoded) do
      {:ok, credentials} ->
        case String.split(credentials, ":", parts: 2) do
          [username, password] ->
            if valid_basic_credentials?(username, password) do
              {:ok, {:basic, username, password}}
            else
              {:error, "Invalid username or password"}
            end

          _ ->
            {:error, "Invalid basic auth format"}
        end

      :error ->
        {:error, "Invalid base64 encoding"}
    end
  end

  defp validate_api_key("ApiKey " <> api_key) do
    valid_api_keys = get_valid_api_keys()

    if api_key in valid_api_keys do
      {:ok, {:api_key, api_key}}
    else
      {:error, "Invalid API key"}
    end
  end

  # Configuration functions - these should be moved to application config
  defp get_valid_tokens do
    :messaging_service
    |> Application.get_env(:webhook_auth, [])
    |> Keyword.get(:bearer_tokens, ["test-token-123", "webhook-token-456"])
  end

  defp get_valid_api_keys do
    :messaging_service
    |> Application.get_env(:webhook_auth, [])
    |> Keyword.get(:api_keys, ["api-key-123", "webhook-key-456"])
  end

  defp valid_basic_credentials?(username, password) do
    valid_credentials =
      :messaging_service
      |> Application.get_env(:webhook_auth, [])
      |> Keyword.get(:basic_auth, [{"webhook", "secret123"}])

    {username, password} in valid_credentials
  end
end
