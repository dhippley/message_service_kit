defmodule MessagingService.Messages.OutboundMessagingTest do
  use MessagingService.DataCase, async: false

  alias MessagingService.Messages
  alias MessagingService.Message
  alias MessagingService.Providers.MockProvider

  setup do
    # Start mock servers for testing
    MockProvider.start_mock_servers()

    on_exit(fn ->
      MockProvider.stop_mock_servers()
    end)

    :ok
  end

  describe "send_outbound_message/2" do
    test "sends SMS message successfully" do
      message_attrs = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello from outbound messaging!"
      }

      assert {:ok, message} = Messages.send_outbound_message(message_attrs)
      assert %Message{} = message
      assert message.type == "sms"
      assert message.to == "+1234567890"
      assert message.from == "+15551234567"
      assert message.body == "Hello from outbound messaging!"
      assert message.messaging_provider_id != nil
      assert message.provider_name == "mock"
    end

    test "sends email message successfully" do
      message_attrs = %{
        type: :email,
        to: "user@example.com",
        from: "service@example.com",
        body: "Hello from outbound messaging!"
      }

      assert {:ok, message} = Messages.send_outbound_message(message_attrs)
      assert %Message{} = message
      assert message.type == "email"
      assert message.to == "user@example.com"
      assert message.from == "service@example.com"
      assert message.body == "Hello from outbound messaging!"
      assert message.messaging_provider_id != nil
      assert message.provider_name == "mock"
    end

    test "sends MMS message successfully" do
      message_attrs = %{
        type: :mms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello with attachment!",
        attachments: [
          %{
            filename: "test.jpg",
            content_type: "image/jpeg",
            data: "fake_image_data"
          }
        ]
      }

      assert {:ok, message} = Messages.send_outbound_message(message_attrs)
      assert %Message{} = message
      assert message.type == "mms"
      assert message.messaging_provider_id != nil
      assert message.provider_name == "mock"
    end

    test "fails with invalid message" do
      message_attrs = %{
        type: :sms,
        to: "invalid_phone",
        from: "+15551234567",
        body: "Hello"
      }

      assert {:error, _reason} = Messages.send_outbound_message(message_attrs)
    end

    test "fails with unsupported message type" do
      message_attrs = %{
        type: :unsupported,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello"
      }

      assert {:error, _reason} = Messages.send_outbound_message(message_attrs)
    end

    test "uses custom provider configuration" do
      custom_config = %{
        mock: %{
          provider: :mock,
          config: %{provider_name: :custom},
          enabled: true
        }
      }

      message_attrs = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello with custom config"
      }

      assert {:ok, message} = Messages.send_outbound_message(message_attrs, custom_config)
      assert %Message{} = message
      assert message.provider_name == "mock"
    end
  end

  describe "send_sms/4" do
    test "sends SMS message successfully" do
      to = "+1234567890"
      from = "+15551234567"
      body = "Hello SMS!"

      assert {:ok, message} = Messages.send_sms(to, from, body)
      assert %Message{} = message
      assert message.type == "sms"
      assert message.to == to
      assert message.from == from
      assert message.body == body
      assert message.messaging_provider_id != nil
    end

    test "fails with invalid phone number" do
      to = "invalid"
      from = "+15551234567"
      body = "Hello SMS!"

      assert {:error, _reason} = Messages.send_sms(to, from, body)
    end
  end

  describe "send_mms/5" do
    test "sends MMS message successfully" do
      to = "+1234567890"
      from = "+15551234567"
      body = "Hello MMS!"
      attachments = [
        %{
          filename: "test.jpg",
          content_type: "image/jpeg",
          data: "fake_image_data"
        }
      ]

      assert {:ok, message} = Messages.send_mms(to, from, body, attachments)
      assert %Message{} = message
      assert message.type == "mms"
      assert message.to == to
      assert message.from == from
      assert message.body == body
      assert message.messaging_provider_id != nil
    end

    test "sends MMS without attachments" do
      to = "+1234567890"
      from = "+15551234567"
      body = "Hello MMS without attachments!"

      assert {:ok, message} = Messages.send_mms(to, from, body)
      assert %Message{} = message
      assert message.type == "mms"
    end
  end

  describe "send_email/5" do
    test "sends email message successfully" do
      to = "user@example.com"
      from = "service@example.com"
      body = "Hello Email!"

      assert {:ok, message} = Messages.send_email(to, from, body)
      assert %Message{} = message
      assert message.type == "email"
      assert message.to == to
      assert message.from == from
      assert message.body == body
      assert message.messaging_provider_id != nil
    end

    test "sends email with attachments" do
      to = "user@example.com"
      from = "service@example.com"
      body = "Hello Email with attachment!"
      attachments = [
        %{
          filename: "document.pdf",
          content_type: "application/pdf",
          data: "fake_pdf_data"
        }
      ]

      assert {:ok, message} = Messages.send_email(to, from, body, attachments)
      assert %Message{} = message
      assert message.type == "email"
    end

    test "fails with invalid email" do
      to = "invalid_email"
      from = "service@example.com"
      body = "Hello Email!"

      assert {:error, _reason} = Messages.send_email(to, from, body)
    end
  end

  describe "get_outbound_message_status/1" do
    test "gets message status successfully" do
      # First send a message
      message_attrs = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello for status check!"
      }

      assert {:ok, message} = Messages.send_outbound_message(message_attrs)
      assert {:ok, status} = Messages.get_outbound_message_status(message)
      assert is_binary(status)
    end

    test "fails when message has no provider ID" do
      # Create a message without provider ID
      message = %Message{
        type: "sms",
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello",
        messaging_provider_id: nil
      }

      assert {:error, "No provider message ID found"} = Messages.get_outbound_message_status(message)
    end
  end

  describe "list_messaging_providers/0" do
    test "lists all providers" do
      providers = Messages.list_messaging_providers()

      assert Map.has_key?(providers, :twilio)
      assert Map.has_key?(providers, :sendgrid)
      assert Map.has_key?(providers, :mock)

      assert providers[:twilio][:name] == "Twilio"
      assert providers[:sendgrid][:name] == "SendGrid"
      assert providers[:mock][:name] == "Mock"
    end
  end

  describe "validate_provider_configurations/1" do
    test "validates configurations successfully" do
      config = %{
        mock: %{
          provider: :mock,
          config: %{provider_name: :generic},
          enabled: true
        }
      }

      assert :ok = Messages.validate_provider_configurations(config)
    end

    test "returns errors for invalid configurations" do
      config = %{
        mock: %{
          provider: :mock,
          config: %{},
          enabled: true
        }
      }

      assert {:error, errors} = Messages.validate_provider_configurations(config)
      assert length(errors) > 0
    end
  end

  describe "conversation integration" do
    test "outbound messages are integrated with conversations" do
      # Send a message
      message_attrs = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello from conversation integration!"
      }

      assert {:ok, message} = Messages.send_outbound_message(message_attrs)

      # Check that the message is part of a conversation
      assert message.conversation_id != nil

      # Get the conversation
      message_with_conversation = Messages.get_message_with_attachments!(message.id)
      conversation = MessagingService.Repo.preload(message_with_conversation, :conversation).conversation
      assert conversation != nil
      assert conversation.participant_one == "+1234567890"
      assert conversation.participant_two == "+15551234567"
    end

    test "multiple messages create proper conversation thread" do
      # Send first message
      message_attrs_1 = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello first message!"
      }

      assert {:ok, message_1} = Messages.send_outbound_message(message_attrs_1)

      # Send second message in same conversation
      message_attrs_2 = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: "Hello second message!"
      }

      assert {:ok, message_2} = Messages.send_outbound_message(message_attrs_2)

      # Both messages should be in the same conversation
      assert message_1.conversation_id == message_2.conversation_id
    end
  end

  describe "edge cases" do
    test "handles empty body gracefully" do
      message_attrs = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: ""
      }

      assert {:error, _reason} = Messages.send_outbound_message(message_attrs)
    end

    test "handles very long message body" do
      long_body = String.duplicate("a", 1601)

      message_attrs = %{
        type: :sms,
        to: "+1234567890",
        from: "+15551234567",
        body: long_body
      }

      assert {:error, _reason} = Messages.send_outbound_message(message_attrs)
    end

    test "handles missing required fields" do
      message_attrs = %{
        type: :sms,
        to: "+1234567890",
        # Missing 'from' field
        body: "Hello"
      }

      assert {:error, _reason} = Messages.send_outbound_message(message_attrs)
    end
  end
end
