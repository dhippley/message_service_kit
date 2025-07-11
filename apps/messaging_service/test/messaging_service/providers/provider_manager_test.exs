defmodule MessagingService.Providers.ProviderManagerTest do
  use MessagingService.DataCase, async: true

  alias MessagingService.Providers.{ProviderManager, MockProvider}

  describe "send_message/2" do
    setup do
      # Start mock servers for testing
      MockProvider.start_mock_servers()

      on_exit(fn ->
        MockProvider.stop_mock_servers()
      end)

      :ok
    end

    test "sends SMS message using mock provider" do
      provider_configs = %{
        mock: %{
          provider: :mock,
          config: %{provider_name: :generic},
          enabled: true
        }
      }

      message = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello from ProviderManager"
      }

      assert {:ok, message_id, provider_name} = ProviderManager.send_message(message, provider_configs)
      assert is_binary(message_id)
      assert provider_name == :mock
    end

    test "sends email message using mock provider" do
      provider_configs = %{
        mock: %{
          provider: :mock,
          config: %{provider_name: :generic},
          enabled: true
        }
      }

      message = %{
        type: :email,
        to: "user@example.com",
        from: "service@example.com",
        body: "Hello from ProviderManager"
      }

      assert {:ok, message_id, provider_name} = ProviderManager.send_message(message, provider_configs)
      assert is_binary(message_id)
      assert provider_name == :mock
    end

    test "fails when no suitable provider is found" do
      provider_configs = %{
        mock: %{
          provider: :mock,
          config: %{provider_name: :generic},
          enabled: false
        }
      }

      message = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello"
      }

      assert {:error, "No suitable provider found for sms messages"} =
        ProviderManager.send_message(message, provider_configs)
    end

    test "selects provider based on priority" do
      provider_configs = %{
        twilio: %{
          provider: :twilio,
          config: %{
            account_sid: "ACtest123",
            auth_token: "test_token_123456789012345678901234",
            from_number: "+15551234567"
          },
          enabled: true
        },
        mock: %{
          provider: :mock,
          config: %{provider_name: :generic},
          enabled: true
        }
      }

      message = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello"
      }

      assert {:ok, message_id, provider_name} = ProviderManager.send_message(message, provider_configs)
      assert is_binary(message_id)
      assert provider_name == :twilio
    end
  end

  describe "get_message_status/3" do
    setup do
      MockProvider.start_mock_servers()

      on_exit(fn ->
        MockProvider.stop_mock_servers()
      end)

      :ok
    end

    test "gets message status from provider" do
      provider_configs = %{
        mock: %{
          provider: :mock,
          config: %{provider_name: :generic},
          enabled: true
        }
      }

      # First send a message
      message = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello"
      }

      assert {:ok, message_id, provider_name} = ProviderManager.send_message(message, provider_configs)
      assert {:ok, status} = ProviderManager.get_message_status(message_id, provider_name, provider_configs)
      assert is_binary(status)
    end

    test "fails with unknown provider" do
      provider_configs = %{}

      assert {:error, "Unknown provider: unknown"} =
        ProviderManager.get_message_status("msg123", :unknown, provider_configs)
    end
  end

  describe "validate_configurations/1" do
    test "validates all provider configurations" do
      provider_configs = %{
        twilio: %{
          provider: :twilio,
          config: %{
            account_sid: "ACtest123",
            auth_token: "test_token_123456789012345678901234",
            from_number: "+15551234567"
          },
          enabled: true
        },
        mock: %{
          provider: :mock,
          config: %{provider_name: :generic},
          enabled: true
        }
      }

      assert :ok = ProviderManager.validate_configurations(provider_configs)
    end

    test "returns errors for invalid configurations" do
      provider_configs = %{
        twilio: %{
          provider: :twilio,
          config: %{
            account_sid: "invalid",
            auth_token: "short",
            from_number: "invalid"
          },
          enabled: true
        },
        mock: %{
          provider: :mock,
          config: %{},
          enabled: true
        }
      }

      assert {:error, errors} = ProviderManager.validate_configurations(provider_configs)
      assert length(errors) == 2
    end
  end

  describe "list_providers/0" do
    test "lists all available providers" do
      providers = ProviderManager.list_providers()

      assert Map.has_key?(providers, :twilio)
      assert Map.has_key?(providers, :sendgrid)
      assert Map.has_key?(providers, :mock)

      assert providers[:twilio][:name] == "Twilio"
      assert providers[:sendgrid][:name] == "SendGrid"
      assert providers[:mock][:name] == "Mock"

      assert :sms in providers[:twilio][:supported_types]
      assert :email in providers[:sendgrid][:supported_types]
      assert :sms in providers[:mock][:supported_types]
    end
  end

  describe "validate_message_for_provider/2" do
    test "validates message for specific provider" do
      message = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello"
      }

      assert :ok = ProviderManager.validate_message_for_provider(message, :twilio)
      assert :ok = ProviderManager.validate_message_for_provider(message, :mock)
    end

    test "fails validation for unsupported message type" do
      message = %{
        type: :email,
        to: "user@example.com",
        from: "service@example.com",
        body: "Hello"
      }

      assert {:error, _} = ProviderManager.validate_message_for_provider(message, :twilio)
      assert :ok = ProviderManager.validate_message_for_provider(message, :sendgrid)
    end

    test "fails validation for invalid recipient" do
      message = %{
        type: :sms,
        to: "invalid",
        from: "+15551234567",
        body: "Hello"
      }

      assert {:error, _} = ProviderManager.validate_message_for_provider(message, :twilio)
    end

    test "fails validation for unknown provider" do
      message = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello"
      }

      assert {:error, "Unknown provider: unknown"} =
        ProviderManager.validate_message_for_provider(message, :unknown)
    end
  end

  describe "default_configurations/1" do
    test "returns test configuration" do
      config = ProviderManager.default_configurations(:test)

      assert Map.has_key?(config, :mock)
      assert config[:mock][:enabled] == true
      refute Map.has_key?(config, :twilio)
    end

    test "returns dev configuration" do
      config = ProviderManager.default_configurations(:dev)

      assert Map.has_key?(config, :mock)
      assert Map.has_key?(config, :twilio)
      assert Map.has_key?(config, :sendgrid)

      assert config[:mock][:enabled] == true
      assert config[:twilio][:enabled] == false
      assert config[:sendgrid][:enabled] == false
    end

    test "returns prod configuration" do
      # Set environment variables for prod config
      System.put_env("TWILIO_ACCOUNT_SID", "ACprod123")
      System.put_env("TWILIO_AUTH_TOKEN", "prod_token_123456789012345678901234")
      System.put_env("TWILIO_FROM_NUMBER", "+15551234567")
      System.put_env("SENDGRID_API_KEY", "SG.prod_key")
      System.put_env("SENDGRID_FROM_EMAIL", "prod@example.com")
      System.put_env("SENDGRID_FROM_NAME", "Prod Service")

      config = ProviderManager.default_configurations(:prod)

      assert Map.has_key?(config, :twilio)
      assert Map.has_key?(config, :sendgrid)
      refute Map.has_key?(config, :mock)

      assert config[:twilio][:enabled] == true
      assert config[:sendgrid][:enabled] == true

      # Clean up environment variables
      System.delete_env("TWILIO_ACCOUNT_SID")
      System.delete_env("TWILIO_AUTH_TOKEN")
      System.delete_env("TWILIO_FROM_NUMBER")
      System.delete_env("SENDGRID_API_KEY")
      System.delete_env("SENDGRID_FROM_EMAIL")
      System.delete_env("SENDGRID_FROM_NAME")
    end
  end
end
