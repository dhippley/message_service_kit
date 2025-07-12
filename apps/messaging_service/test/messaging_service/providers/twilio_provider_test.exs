defmodule MessagingService.Providers.TwilioProviderTest do
  use MessagingService.DataCase, async: true

  alias MessagingService.Providers.TwilioProvider

  describe "TwilioProvider" do
    test "supported_types/0 returns correct types" do
      assert TwilioProvider.supported_types() == [:sms, :mms]
    end

    test "provider_name/0 returns correct name" do
      assert TwilioProvider.provider_name() == "Twilio"
    end

    test "validate_recipient/2 with valid phone numbers" do
      assert TwilioProvider.validate_recipient("+1234567890", :sms) == :ok
      assert TwilioProvider.validate_recipient("+15551234567", :mms) == :ok
    end

    test "validate_recipient/2 with invalid phone numbers" do
      assert {:error, _} = TwilioProvider.validate_recipient("invalid", :sms)
      assert {:error, _} = TwilioProvider.validate_recipient("test@example.com", :sms)
    end

    test "validate_recipient/2 with unsupported types" do
      assert {:error, _} = TwilioProvider.validate_recipient("+1234567890", :email)
    end

    test "validate_config/1 with valid config" do
      config = %{
        account_sid: "ACtest123",
        auth_token: "test_token_123456789012345678901234",
        from_number: "+15551234567"
      }

      assert TwilioProvider.validate_config(config) == :ok
    end

    test "validate_config/1 with invalid config" do
      # Missing fields
      assert {:error, _} = TwilioProvider.validate_config(%{})

      # Invalid account_sid
      assert {:error, _} =
               TwilioProvider.validate_config(%{
                 account_sid: "invalid",
                 auth_token: "test_token_123456789012345678901234",
                 from_number: "+15551234567"
               })

      # Invalid auth_token
      assert {:error, _} =
               TwilioProvider.validate_config(%{
                 account_sid: "ACtest123",
                 auth_token: "short",
                 from_number: "+15551234567"
               })

      # Invalid from_number
      assert {:error, _} =
               TwilioProvider.validate_config(%{
                 account_sid: "ACtest123",
                 auth_token: "test_token_123456789012345678901234",
                 from_number: "invalid"
               })
    end

    test "send_message/2 with valid SMS" do
      config = %{
        account_sid: "ACtest123",
        auth_token: "test_token_123456789012345678901234",
        from_number: "+15551234567"
      }

      message = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello from Twilio"
      }

      assert {:ok, message_id} = TwilioProvider.send_message(message, config)
      assert is_binary(message_id)
      assert String.starts_with?(message_id, "SM")
    end

    test "send_message/2 with SMS containing attachments fails" do
      config = %{
        account_sid: "ACtest123",
        auth_token: "test_token_123456789012345678901234",
        from_number: "+15551234567"
      }

      message = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello",
        attachments: [%{filename: "test.jpg", content_type: "image/jpeg", data: "data"}]
      }

      assert {:error, _} = TwilioProvider.send_message(message, config)
    end

    test "send_message/2 with valid MMS" do
      config = %{
        account_sid: "ACtest123",
        auth_token: "test_token_123456789012345678901234",
        from_number: "+15551234567"
      }

      message = %{
        type: :mms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello from Twilio",
        attachments: [%{filename: "test.jpg", content_type: "image/jpeg", data: "data"}]
      }

      assert {:ok, message_id} = TwilioProvider.send_message(message, config)
      assert is_binary(message_id)
      assert String.starts_with?(message_id, "SM")
    end

    test "get_message_status/2 returns status" do
      config = %{
        account_sid: "ACtest123",
        auth_token: "test_token_123456789012345678901234",
        from_number: "+15551234567"
      }

      assert {:ok, status} = TwilioProvider.get_message_status("SM123456", config)
      assert is_binary(status)
    end
  end
end
