defmodule MessagingService.Providers.SendGridProviderTest do
  use MessagingService.DataCase, async: true

  alias MessagingService.Providers.SendGridProvider

  describe "SendGridProvider" do
    test "supported_types/0 returns correct types" do
      assert SendGridProvider.supported_types() == [:email]
    end

    test "provider_name/0 returns correct name" do
      assert SendGridProvider.provider_name() == "SendGrid"
    end

    test "validate_recipient/2 with valid emails" do
      assert SendGridProvider.validate_recipient("test@example.com", :email) == :ok
    end

    test "validate_recipient/2 with invalid emails" do
      assert {:error, _} = SendGridProvider.validate_recipient("invalid", :email)
    end

    test "validate_recipient/2 with unsupported types" do
      assert {:error, _} = SendGridProvider.validate_recipient("test@example.com", :sms)
    end

    test "validate_config/1 with valid config" do
      config = %{
        api_key: "SG.test_key_123456789012345678901234567890",
        from_email: "test@example.com",
        from_name: "Test Service"
      }

      assert SendGridProvider.validate_config(config) == :ok
    end

    test "validate_config/1 with invalid config" do
      # Missing fields
      assert {:error, _} = SendGridProvider.validate_config(%{})

      # Invalid api_key
      assert {:error, _} =
               SendGridProvider.validate_config(%{
                 api_key: "invalid",
                 from_email: "test@example.com",
                 from_name: "Test Service"
               })

      # Invalid from_email
      assert {:error, _} =
               SendGridProvider.validate_config(%{
                 api_key: "SG.test_key_123456789012345678901234567890",
                 from_email: "invalid",
                 from_name: "Test Service"
               })
    end

    test "send_message/2 with valid email" do
      config = %{
        api_key: "SG.test_key_123456789012345678901234567890",
        from_email: "test@example.com",
        from_name: "Test Service"
      }

      message = %{
        type: :email,
        to: "user@example.com",
        from: "test@example.com",
        body: "Hello from SendGrid"
      }

      assert {:ok, message_id} = SendGridProvider.send_message(message, config)
      assert is_binary(message_id)
      assert String.starts_with?(message_id, "SG")
    end

    test "send_message/2 with email containing attachments" do
      config = %{
        api_key: "SG.test_key_123456789012345678901234567890",
        from_email: "test@example.com",
        from_name: "Test Service"
      }

      message = %{
        type: :email,
        to: "user@example.com",
        from: "test@example.com",
        body: "Hello from SendGrid",
        attachments: [%{filename: "test.pdf", content_type: "application/pdf", data: "data"}]
      }

      assert {:ok, message_id} = SendGridProvider.send_message(message, config)
      assert is_binary(message_id)
      assert String.starts_with?(message_id, "SG")
    end

    test "get_message_status/2 returns status" do
      config = %{
        api_key: "SG.test_key_123456789012345678901234567890",
        from_email: "test@example.com",
        from_name: "Test Service"
      }

      assert {:ok, status} = SendGridProvider.get_message_status("SG123456", config)
      assert is_binary(status)
    end
  end
end
