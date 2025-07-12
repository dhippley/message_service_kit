defmodule MessagingServiceWeb.WebhookControllerTest do
  use MessagingServiceWeb.ConnCase, async: true

  alias MessagingService.Conversations
  alias MessagingService.Messages

  @valid_bearer_token "dev-bearer-token-123"
  @valid_api_key "dev-api-key-123"
  @valid_basic_auth "webhook_user:dev_password_123"

  describe "POST /api/webhooks/messages" do
    test "creates SMS message with valid bearer token", %{conn: conn} do
      message_params = %{
        type: "sms",
        from: "+1234567890",
        to: "+1987654321",
        body: "Hello from webhook!"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_bearer_token}")
        |> post("/api/webhooks/messages", message_params)

      assert json_response(conn, 201)
      response = json_response(conn, 201)

      assert response["success"] == true
      assert response["message_id"]
      assert response["conversation_id"]
      assert response["created_at"]

      # Verify message was created
      message = Messages.get_message!(response["message_id"])
      assert message.type == "sms"
      assert message.from == "+1234567890"
      assert message.to == "+1987654321"
      assert message.body == "Hello from webhook!"
      assert message.conversation_id == response["conversation_id"]
    end

    test "creates MMS message with attachments", %{conn: conn} do
      message_params = %{
        type: "mms",
        from: "+1234567890",
        to: "+1987654321",
        body: "Check this out!",
        attachments: [
          %{
            filename: "test.jpg",
            content_type: "image/jpeg",
            url: "https://example.com/test.jpg",
            attachment_type: "image"
          }
        ]
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_bearer_token}")
        |> post("/api/webhooks/messages", message_params)

      assert json_response(conn, 201)
      response = json_response(conn, 201)

      # Verify message was created with attachments
      message = Messages.get_message_with_attachments!(response["message_id"])
      assert message.type == "mms"
      assert length(message.attachments) == 1
      assert hd(message.attachments).filename == "test.jpg"
    end

    test "creates email message with API key auth", %{conn: conn} do
      message_params = %{
        type: "email",
        from: "sender@example.com",
        to: "recipient@example.com",
        subject: "Test Email",
        body: "This is a test email from webhook"
      }

      conn =
        conn
        |> put_req_header("authorization", "ApiKey #{@valid_api_key}")
        |> post("/api/webhooks/messages", message_params)

      assert json_response(conn, 201)
      response = json_response(conn, 201)

      # Verify email message was created
      message = Messages.get_message!(response["message_id"])
      assert message.type == "email"
      assert message.from == "sender@example.com"
      assert message.to == "recipient@example.com"
      assert message.body == "This is a test email from webhook"
    end

    test "creates message with basic auth", %{conn: conn} do
      message_params = %{
        type: "sms",
        from: "+1234567890",
        to: "+1987654321",
        body: "Basic auth test"
      }

      basic_auth = Base.encode64(@valid_basic_auth)

      conn =
        conn
        |> put_req_header("authorization", "Basic #{basic_auth}")
        |> post("/api/webhooks/messages", message_params)

      assert json_response(conn, 201)
    end

    test "accepts timestamp parameter", %{conn: conn} do
      message_params = %{
        type: "sms",
        from: "+1234567890",
        to: "+1987654321",
        body: "Timestamped message",
        timestamp: "2024-01-01T12:00:00Z"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_bearer_token}")
        |> post("/api/webhooks/messages", message_params)

      assert json_response(conn, 201)
      response = json_response(conn, 201)

      message = Messages.get_message!(response["message_id"])
      assert message.timestamp == ~N[2024-01-01 12:00:00.000000]
    end

    test "accepts provider_id parameter", %{conn: conn} do
      message_params = %{
        type: "sms",
        from: "+1234567890",
        to: "+1987654321",
        body: "Provider tracked message",
        provider_id: "twilio-msg-123"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_bearer_token}")
        |> post("/api/webhooks/messages", message_params)

      assert json_response(conn, 201)
      response = json_response(conn, 201)

      message = Messages.get_message!(response["message_id"])
      assert message.messaging_provider_id == "twilio-msg-123"
    end

    test "rejects request without authorization", %{conn: conn} do
      message_params = %{
        type: "sms",
        from: "+1234567890",
        to: "+1987654321",
        body: "Unauthorized message"
      }

      conn = post(conn, "/api/webhooks/messages", message_params)

      assert json_response(conn, 401)
      response = json_response(conn, 401)
      assert response["error"] == "Authentication failed"
    end

    test "rejects request with invalid bearer token", %{conn: conn} do
      message_params = %{
        type: "sms",
        from: "+1234567890",
        to: "+1987654321",
        body: "Invalid token message"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")
        |> post("/api/webhooks/messages", message_params)

      assert json_response(conn, 401)
      response = json_response(conn, 401)
      assert response["reason"] == "Invalid bearer token"
    end

    test "rejects request with invalid message data", %{conn: conn} do
      message_params = %{
        type: "sms",
        # Missing required fields
        body: "Invalid message"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_bearer_token}")
        |> post("/api/webhooks/messages", message_params)

      assert json_response(conn, 422)
      response = json_response(conn, 422)
      assert response["success"] == false
      assert response["error"] == "Invalid message data"
      assert response["details"]
    end

    test "rejects unsupported message type", %{conn: conn} do
      message_params = %{
        type: "unsupported_type",
        from: "+1234567890",
        to: "+1987654321",
        body: "Unsupported message"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_bearer_token}")
        |> post("/api/webhooks/messages", message_params)

      assert json_response(conn, 400)
      response = json_response(conn, 400)
      assert response["success"] == false
      assert String.contains?(response["reason"], "Unsupported message type")
    end
  end

  describe "POST /api/webhooks/messages/batch" do
    test "creates multiple messages successfully", %{conn: conn} do
      batch_params = %{
        messages: [
          %{
            type: "sms",
            from: "+1234567890",
            to: "+1987654321",
            body: "First message"
          },
          %{
            type: "email",
            from: "sender@example.com",
            to: "recipient@example.com",
            body: "Second message"
          }
        ]
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_bearer_token}")
        |> post("/api/webhooks/messages/batch", batch_params)

      assert json_response(conn, 201)
      response = json_response(conn, 201)

      assert response["success"] == true
      assert response["total"] == 2
      assert response["successful"] == 2
      assert response["failed"] == 0
      assert length(response["results"]) == 2

      # Verify both messages were created
      Enum.each(response["results"], fn result ->
        assert result["success"] == true
        assert result["message_id"]
        assert Messages.get_message!(result["message_id"])
      end)
    end

    test "handles partial failures in batch", %{conn: conn} do
      batch_params = %{
        messages: [
          %{
            type: "sms",
            from: "+1234567890",
            to: "+1987654321",
            body: "Valid message"
          },
          %{
            type: "sms",
            # Missing required fields
            body: "Invalid message"
          }
        ]
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_bearer_token}")
        |> post("/api/webhooks/messages/batch", batch_params)

      # Multi-status
      assert json_response(conn, 207)
      response = json_response(conn, 207)

      assert response["success"] == false
      assert response["total"] == 2
      assert response["successful"] == 1
      assert response["failed"] == 1

      # Check individual results
      successful_result = Enum.find(response["results"], & &1["success"])
      failed_result = Enum.find(response["results"], &(!&1["success"]))

      assert successful_result["message_id"]
      assert failed_result["error"]
    end

    test "rejects batch with invalid format", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_bearer_token}")
        |> post("/api/webhooks/messages/batch", %{invalid: "format"})

      assert json_response(conn, 400)
      response = json_response(conn, 400)
      assert response["success"] == false
      assert response["error"] == "Invalid batch format"
    end
  end

  describe "GET /api/webhooks/health" do
    test "returns health check without authentication", %{conn: conn} do
      conn = get(conn, "/api/webhooks/health")

      assert json_response(conn, 200)
      response = json_response(conn, 200)

      assert response["status"] == "healthy"
      assert response["service"] == "messaging_service_webhook"
      assert response["timestamp"]
    end
  end

  describe "conversation integration" do
    test "messages between same participants use same conversation", %{conn: conn} do
      # Create first message
      message1_params = %{
        type: "sms",
        from: "+1234567890",
        to: "+1987654321",
        body: "First message"
      }

      conn1 =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_bearer_token}")
        |> post("/api/webhooks/messages", message1_params)

      response1 = json_response(conn1, 201)

      # Create second message (reversed from/to)
      message2_params = %{
        type: "sms",
        from: "+1987654321",
        to: "+1234567890",
        body: "Reply message"
      }

      conn2 =
        conn
        |> put_req_header("authorization", "Bearer #{@valid_bearer_token}")
        |> post("/api/webhooks/messages", message2_params)

      response2 = json_response(conn2, 201)

      # Both messages should belong to the same conversation
      assert response1["conversation_id"] == response2["conversation_id"]

      # Verify conversation has 2 messages
      conversation = Conversations.get_conversation!(response1["conversation_id"])
      assert conversation.message_count == 2
    end
  end
end
