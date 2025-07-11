defmodule MessagingService.Providers.MockProviderTest do
  use MessagingService.DataCase, async: false

  alias MessagingService.Providers.MockProvider

  describe "MockProvider" do
    setup do
      # Start mock servers for testing
      MockProvider.start_mock_servers()

      on_exit(fn ->
        MockProvider.stop_mock_servers()
      end)

      :ok
    end

    test "supported_types/0 returns correct types" do
      assert MockProvider.supported_types() == [:sms, :mms, :email]
    end

    test "provider_name/0 returns correct name" do
      assert MockProvider.provider_name() == "Mock"
    end

    test "validate_recipient/2 with valid recipients" do
      assert MockProvider.validate_recipient("+1234567890", :sms) == :ok
      assert MockProvider.validate_recipient("+1234567890", :mms) == :ok
      assert MockProvider.validate_recipient("test@example.com", :email) == :ok
    end

    test "validate_recipient/2 with invalid recipients" do
      assert {:error, _} = MockProvider.validate_recipient("invalid", :sms)
      assert {:error, _} = MockProvider.validate_recipient("invalid", :email)
    end

    test "validate_config/1 with valid config" do
      config = %{provider_name: :generic}
      assert MockProvider.validate_config(config) == :ok
    end

    test "validate_config/1 with invalid config" do
      assert {:error, _} = MockProvider.validate_config(%{})
    end

    test "send_message/2 with valid SMS" do
      config = %{provider_name: :generic}

      message = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello from Mock"
      }

      assert {:ok, message_id} = MockProvider.send_message(message, config)
      assert is_binary(message_id)
    end

    test "send_message/2 with valid email" do
      config = %{provider_name: :generic}

      message = %{
        type: :email,
        to: "user@example.com",
        from: "test@example.com",
        body: "Hello from Mock"
      }

      assert {:ok, message_id} = MockProvider.send_message(message, config)
      assert is_binary(message_id)
    end

    test "get_message_status/2 returns status" do
      config = %{provider_name: :generic}

      # First send a message
      message = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello from Mock"
      }

      assert {:ok, message_id} = MockProvider.send_message(message, config)
      assert {:ok, status} = MockProvider.get_message_status(message_id, config)
      assert is_binary(status)
    end
  end
end
