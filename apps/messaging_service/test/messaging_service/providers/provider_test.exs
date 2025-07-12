defmodule MessagingService.Providers.ProviderTest do
  use MessagingService.DataCase, async: true

  alias MessagingService.Provider

  describe "Provider behavior validation" do
    test "validate_phone_number/1 with valid phone numbers" do
      assert Provider.validate_phone_number("+1234567890") == :ok
      assert Provider.validate_phone_number("+15551234567") == :ok
      assert Provider.validate_phone_number("+441234567890") == :ok
    end

    test "validate_phone_number/1 with invalid phone numbers" do
      assert {:error, _} = Provider.validate_phone_number("+")
      assert {:error, _} = Provider.validate_phone_number("invalid")
      assert {:error, _} = Provider.validate_phone_number(nil)
      assert {:error, _} = Provider.validate_phone_number("")
    end

    test "validate_email/1 with valid emails" do
      assert Provider.validate_email("test@example.com") == :ok
      assert Provider.validate_email("user.name@domain.co.uk") == :ok
      assert Provider.validate_email("test+tag@example.org") == :ok
    end

    test "validate_email/1 with invalid emails" do
      assert {:error, _} = Provider.validate_email("invalid")
      assert {:error, _} = Provider.validate_email("@example.com")
      assert {:error, _} = Provider.validate_email("test@")
      assert {:error, _} = Provider.validate_email(nil)
    end

    test "validate_message_content/1 with valid content" do
      assert Provider.validate_message_content("Hello world") == :ok
      assert Provider.validate_message_content("Short") == :ok
    end

    test "validate_message_content/1 with invalid content" do
      assert {:error, _} = Provider.validate_message_content("")
      assert {:error, _} = Provider.validate_message_content("   ")
      assert {:error, _} = Provider.validate_message_content(String.duplicate("a", 1601))
      assert {:error, _} = Provider.validate_message_content(nil)
    end

    test "validate_message_request/1 with valid requests" do
      sms_request = %{
        type: :sms,
        to: "+1234567890",
        from: "+19876543210",
        body: "Hello"
      }

      email_request = %{
        type: :email,
        to: "test@example.com",
        from: "sender@example.com",
        body: "Hello"
      }

      assert Provider.validate_message_request(sms_request) == :ok
      assert Provider.validate_message_request(email_request) == :ok
    end

    test "validate_message_request/1 with invalid requests" do
      # Missing required fields
      assert {:error, _} = Provider.validate_message_request(%{})
      assert {:error, _} = Provider.validate_message_request(%{type: :sms})

      # Invalid recipients
      assert {:error, _} =
               Provider.validate_message_request(%{
                 type: :sms,
                 to: "invalid",
                 from: "+1234567890",
                 body: "Hello"
               })

      # Invalid content
      assert {:error, _} =
               Provider.validate_message_request(%{
                 type: :sms,
                 to: "+1234567890",
                 from: "+0987654321",
                 body: ""
               })
    end
  end
end
