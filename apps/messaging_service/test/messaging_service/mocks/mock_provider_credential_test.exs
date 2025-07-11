defmodule MessagingService.MockProviderCredentialTest do
  @moduledoc """
  Tests for credential validation in MockProviderServer.
  """

  use ExUnit.Case
  alias MessagingService.MockProviderServer

  describe "credential validation" do
    test "Twilio provider validates credentials correctly" do
      # Valid credentials
      {:ok, pid} =
        MockProviderServer.start_link(
          name: :test_twilio_valid,
          provider_type: :twilio,
          config: %{
            account_sid: "ACtest12345678901234567890",
            auth_token: "test_token_12345"
          }
        )

      assert MockProviderServer.validate_provider_credentials(pid) == :ok

      # Test sending message with valid credentials
      message = %{to: "+1234567890", from: "+0987654321", body: "Test"}
      response = MockProviderServer.send_message(pid, message)
      assert response.status_code in [200, 201]

      GenServer.stop(pid)
    end

    test "Twilio provider rejects missing account_sid" do
      {:ok, pid} =
        MockProviderServer.start_link(
          name: :test_twilio_missing_sid,
          provider_type: :twilio,
          config: %{
            auth_token: "test_token_12345"
          }
        )

      assert {:error, "Missing required Twilio Account SID"} =
               MockProviderServer.validate_provider_credentials(pid)

      # Test sending message with invalid credentials
      message = %{to: "+1234567890", from: "+0987654321", body: "Test"}
      response = MockProviderServer.send_message(pid, message)
      assert response.status_code == 401
      assert response.body["detail"] == "Missing required Twilio Account SID"

      GenServer.stop(pid)
    end

    test "Twilio provider rejects missing auth_token" do
      {:ok, pid} =
        MockProviderServer.start_link(
          name: :test_twilio_missing_token,
          provider_type: :twilio,
          config: %{
            account_sid: "ACtest12345678901234567890"
          }
        )

      assert {:error, "Missing required Twilio Auth Token"} =
               MockProviderServer.validate_provider_credentials(pid)

      GenServer.stop(pid)
    end

    test "Twilio provider rejects invalid account_sid format" do
      {:ok, pid} =
        MockProviderServer.start_link(
          name: :test_twilio_invalid_sid,
          provider_type: :twilio,
          config: %{
            # Too short
            account_sid: "AC123",
            auth_token: "test_token_12345"
          }
        )

      assert {:error, "Invalid Twilio Account SID format"} =
               MockProviderServer.validate_provider_credentials(pid)

      GenServer.stop(pid)
    end

    test "SendGrid provider validates credentials correctly" do
      # Valid credentials
      {:ok, pid} =
        MockProviderServer.start_link(
          name: :test_sendgrid_valid,
          provider_type: :sendgrid,
          config: %{
            api_key: "SG.test_key_12345"
          }
        )

      assert MockProviderServer.validate_provider_credentials(pid) == :ok

      # Test sending message with valid credentials
      message = %{
        from: %{email: "test@example.com"},
        to: [%{email: "recipient@example.com"}],
        subject: "Test"
      }

      response = MockProviderServer.send_message(pid, message)
      assert response.status_code in [200, 202]

      GenServer.stop(pid)
    end

    test "SendGrid provider rejects missing api_key" do
      {:ok, pid} =
        MockProviderServer.start_link(
          name: :test_sendgrid_missing_key,
          provider_type: :sendgrid,
          config: %{}
        )

      assert {:error, "Missing required SendGrid API Key"} =
               MockProviderServer.validate_provider_credentials(pid)

      # Test sending message with invalid credentials
      message = %{
        from: %{email: "test@example.com"},
        to: [%{email: "recipient@example.com"}],
        subject: "Test"
      }

      response = MockProviderServer.send_message(pid, message)
      assert response.status_code == 401

      assert Enum.any?(
               response.body["errors"],
               &(&1["message"] == "Missing required SendGrid API Key")
             )

      GenServer.stop(pid)
    end

    test "SendGrid provider rejects invalid api_key format" do
      {:ok, pid} =
        MockProviderServer.start_link(
          name: :test_sendgrid_invalid_key,
          provider_type: :sendgrid,
          config: %{
            # Doesn't start with "SG."
            api_key: "invalid_key_format"
          }
        )

      assert {:error, "Invalid SendGrid API Key format (must start with 'SG.')"} =
               MockProviderServer.validate_provider_credentials(pid)

      GenServer.stop(pid)
    end

    test "Generic provider accepts any configuration" do
      {:ok, pid} =
        MockProviderServer.start_link(
          name: :test_generic,
          provider_type: :generic,
          config: %{}
        )

      assert MockProviderServer.validate_provider_credentials(pid) == :ok

      # Test sending message
      message = %{to: "anyone", from: "system", body: "Test"}
      response = MockProviderServer.send_message(pid, message)
      assert response.status_code == 200

      GenServer.stop(pid)
    end

    test "updating config re-validates credentials" do
      {:ok, pid} =
        MockProviderServer.start_link(
          name: :test_update_config,
          provider_type: :twilio,
          config: %{
            account_sid: "ACtest12345678901234567890",
            auth_token: "test_token_12345"
          }
        )

      # Initially valid
      assert MockProviderServer.validate_provider_credentials(pid) == :ok

      # Update to invalid config
      # Too short
      MockProviderServer.update_config(pid, %{account_sid: "AC123"})

      assert {:error, "Invalid Twilio Account SID format"} =
               MockProviderServer.validate_provider_credentials(pid)

      # Update back to valid config
      MockProviderServer.update_config(pid, %{account_sid: "ACtest12345678901234567890"})
      assert MockProviderServer.validate_provider_credentials(pid) == :ok

      GenServer.stop(pid)
    end
  end
end
