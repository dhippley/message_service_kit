# MessagingService

A comprehensive Phoenix-based messaging service that provides a unified API for sending SMS, MMS, and email messages through multiple providers including Twilio and SendGrid. Built with a provider pattern for easy extensibility and featuring webhook handling, message tracking, and conversation management.

## Features

- **Multi-Provider Support**: Twilio for SMS/MMS, SendGrid for email
- **Unified API**: Single interface for all message types with dedicated endpoints
- **Bidirectional Messaging**: Send outbound messages and receive inbound via webhooks
- **Message Tracking**: Real-time status updates and delivery tracking
- **Conversation Management**: Automatic conversation threading and message retrieval
- **Attachment Support**: Handle file attachments for MMS and email
- **Webhook Integration**: Receive inbound messages and delivery status updates
- **Database Persistence**: Full message history and metadata storage with PostgreSQL
- **Provider Abstraction**: Easy to add new messaging providers via behavior pattern
- **Authentication**: Secure webhook endpoints with bearer tokens and API keys
- **Development Support**: Mock provider integration for testing
- **Code Quality**: Integrated Dialyzer, Credo, and formatting tools
- **RESTful API**: Clean, consistent HTTP endpoints for all operations

## Architecture

The application follows a clean architecture pattern with the following layers:

```
├── lib/messaging_service/
│   ├── contexts/           # Business logic and data access
│   │   ├── conversations/  # Conversation management
│   │   ├── messages/       # Message handling and persistence
│   │   └── attachments/    # File attachment management
│   ├── providers/          # External service integrations
│   │   ├── provider.ex     # Provider behavior definition
│   │   ├── twilio_provider.ex
│   │   ├── sendgrid_provider.ex
│   │   └── provider_manager.ex
│   └── schemas/            # Database schemas
│       ├── conversation.ex
│       ├── message.ex
│       └── attachment.ex
├── lib/messaging_service_web/
│   ├── controllers/        # HTTP endpoints
│   │   ├── message_controller.ex     # Outbound message sending
│   │   ├── conversation_controller.ex # Conversation management
│   │   └── webhook_controller.ex     # Inbound message webhooks
│   ├── plugs/             # Authentication and middleware
│   └── router.ex          # Route definitions
```

## API Endpoints Reference

### Outbound Messaging
- `POST /api/messages/sms` - Send SMS/MMS messages
- `POST /api/messages/email` - Send email messages

### Conversation Management  
- `GET /api/conversations` - List all conversations with latest messages
- `GET /api/conversations/:id/messages` - Get all messages for a conversation

### Inbound Webhooks (Generic Format)
- `POST /api/webhooks/sms` - Receive inbound SMS/MMS
- `POST /api/webhooks/email` - Receive inbound email

### Provider-Specific Webhooks (Authenticated)
- `POST /api/webhooks/twilio` - Twilio webhook format
- `POST /api/webhooks/sendgrid` - SendGrid webhook format

### System
- `GET /api/webhooks/health` - Health check endpoint

## Quick Start

### Prerequisites

- Elixir 1.14+
- Phoenix 1.7+
- PostgreSQL
- Node.js (for assets)

### Installation

1. **Install dependencies:**
   ```bash
   mix deps.get
   cd assets && npm install && cd ..
   ```

2. **Setup database:**
   ```bash
   mix ecto.setup
   ```

3. **Configure providers** (see Configuration section below)

4. **Start the server:**
   ```bash
   mix phx.server
   ```

The application will be available at [`localhost:4000`](http://localhost:4000).

## Configuration

### Environment Variables

Configure the following environment variables or update `config/dev.exs`:

#### Database
```elixir
config :messaging_service, MessagingService.Repo,
  username: "messaging_user",
  password: "messaging_password",
  hostname: "localhost",
  database: "messaging_service_dev"
```

#### Provider Configuration

##### Twilio
```elixir
config :messaging_service, :provider_configs,
  twilio: %{
    provider: :twilio,
    config: %{
      account_sid: "your_twilio_account_sid",
      auth_token: "your_twilio_auth_token",
      from_number: "+1234567890"
    },
    enabled: true
  }
```

##### SendGrid
```elixir
config :messaging_service, :provider_configs,
  sendgrid: %{
    provider: :sendgrid,
    config: %{
      api_key: "your_sendgrid_api_key",
      from_email: "sender@yourdomain.com",
      from_name: "Your App Name"
    },
    enabled: true
  }
```

#### Webhook Authentication
```elixir
config :messaging_service, :webhook_auth,
  bearer_tokens: [
    "your-bearer-token-123"
  ],
  api_keys: [
    "your-api-key-456"
  ],
  basic_auth: [
    {"username", "password"}
  ]
```

## API Usage

### Sending Messages

#### Send SMS
```bash
POST /api/messages/sms
Content-Type: application/json

{
  "to": "+1234567890",
  "from": "+0987654321",
  "body": "Hello from MessagingService!"
}
```

Response:
```json
{
  "success": true,
  "status": "queued",
  "message": "SMS queued for delivery",
  "message_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### Send Email
```bash
POST /api/messages/email
Content-Type: application/json

{
  "to": "user@example.com",
  "from": "sender@yourdomain.com",
  "subject": "Welcome!",
  "body": "Welcome to our service!"
}
```

Response:
```json
{
  "success": true,
  "status": "queued", 
  "message": "Email queued for delivery",
  "message_id": "550e8400-e29b-41d4-a716-446655440001"
}
```

#### Send MMS with Attachments
```bash
POST /api/messages/sms
Content-Type: application/json

{
  "to": "+1234567890",
  "from": "+0987654321",
  "body": "Check out this image!",
  "type": "mms",
  "attachments": [
    {
      "filename": "image.jpg",
      "content_type": "image/jpeg",
      "url": "https://example.com/image.jpg"
    }
  ]
}
```

### Conversation Management

#### List All Conversations
```bash
GET /api/conversations
```

Response:
```json
{
  "success": true,
  "count": 2,
  "data": [
    {
      "contact1": "+1234567890",
      "contact2": "+0987654321",
      "latest_timestamp": "2025-07-12T14:46:36.429564",
      "latest_message": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "type": "sms",
        "body": "Hello from MessagingService!",
        "timestamp": "2025-07-12T14:46:36.429564"
      }
    }
  ]
}
```

#### Get Messages for Conversation
```bash
GET /api/conversations/{conversation_id}/messages
```

Response:
```json
{
  "success": true,
  "count": 5,
  "conversation_id": "550e8400-e29b-41d4-a716-446655440000",
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "type": "sms",
      "body": "Hello!",
      "to": "+1234567890",
      "from": "+0987654321",
      "timestamp": "2025-07-12T14:46:36.429564"
    }
  ]
}
```

## Webhooks

The service supports webhooks for both receiving inbound messages and delivery status updates from messaging providers:

### Inbound Message Webhooks

#### Generic Inbound SMS/MMS
```
POST /api/webhooks/sms
```
Expected payload:
```json
{
  "from": "+18045551234",
  "to": "+12016661234", 
  "type": "sms",
  "messaging_provider_id": "message-1",
  "body": "This is an incoming SMS message",
  "attachments": null,
  "timestamp": "2024-11-01T14:00:00Z"
}
```

#### Generic Inbound Email
```
POST /api/webhooks/email
```
Expected payload:
```json
{
  "from": "contact@gmail.com",
  "to": "user@usehatchapp.com",
  "xillio_id": "message-3",
  "body": "<html><body>Incoming email content</body></html>",
  "attachments": ["https://example.com/document.pdf"],
  "timestamp": "2024-11-01T14:00:00Z"
}
```

### Provider-Specific Webhooks

#### Twilio Webhooks
```
POST /api/webhooks/twilio
```
Handles both inbound messages and delivery status updates in Twilio's native format.

#### SendGrid Webhooks
```
POST /api/webhooks/sendgrid
```
Handles both inbound emails and delivery event notifications in SendGrid's native format.

### Legacy Webhook Endpoints
```
POST /api/webhooks/messages        # Generic message webhook
POST /api/webhooks/messages/batch  # Batch message processing
GET  /api/webhooks/health          # Health check
```

### Authentication

All webhook endpoints (except health check) are secured with multiple authentication methods:
- Bearer tokens in `Authorization` header
- API keys in `X-API-Key` header  
- Basic authentication

Example with authentication:
```bash
curl -X POST "http://localhost:4000/api/webhooks/sms" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer dev-bearer-token-123" \
  -d '{"from": "+1234567890", "to": "+0987654321", "type": "sms", "body": "Hello!"}'
```

## Development

### Code Quality Tools

The project includes several code quality tools for maintaining high standards:

```bash
# Format code according to Elixir standards
mix format

# Check if code is properly formatted  
mix format --check-formatted

# Static code analysis with Credo
mix credo
mix credo --strict

# Type analysis with Dialyzer (requires PLT)
mix dialyzer

# Run all quality checks at once
mix quality

# CI-friendly quality check (no auto-fixes)
mix quality.ci
```

#### Setting up Dialyzer

Dialyzer requires a PLT (Persistent Lookup Table) to be built:

```bash
# Build PLT (only needed once, or when deps change)
mix dialyzer --plt
```

#### Credo Configuration

Credo is configured via `.credo.exs` in the project root with:
- Custom file inclusion patterns for umbrella projects
- Relaxed line length limits (120 characters)
- Module documentation requirements
- Alias ordering enforcement

### Mock Provider Integration

For development and testing, the service integrates with an external mock provider that simulates Twilio and SendGrid APIs:

1. **Start the mock provider** (from project root):
   ```bash
   cd apps/mock_provider && mix run --no-halt
   ```

2. **Configure providers to use mock endpoints** (already configured in development):
   - Twilio: `http://localhost:4001/v1`
   - SendGrid: `http://localhost:4001/v3`

### Running Tests

```bash
# Run all tests
mix test

# Run specific test files
mix test test/messaging_service/providers/
mix test test/messaging_service_web/controllers/

# Run with coverage
mix test --cover
```

### Testing the API

A comprehensive test script is provided to verify all endpoints:

```bash
# Make test script executable and run
chmod +x bin/test.sh
./bin/test.sh
```

The test script validates:
- SMS sending endpoint
- Email sending endpoint  
- Inbound SMS webhook
- Inbound email webhook
- Conversation listing
- Message retrieval for conversations

Example test output:
```
=== Testing Messaging Service Endpoints ===
1. Testing SMS send...
{"message":"SMS queued for delivery","status":"queued","success":true,"message_id":"..."}
Status: 201

2. Testing Email send...
{"message":"Email queued for delivery","status":"queued","success":true,"message_id":"..."}
Status: 201

...
=== Test script completed ===
```

### Database Operations

```bash
# Create and migrate database
mix ecto.create
mix ecto.migrate

# Reset database
mix ecto.reset

# Generate new migration
mix ecto.gen.migration add_new_feature
```

## Provider Pattern

Adding a new messaging provider is straightforward:

1. **Create provider module** implementing the `MessagingService.Providers.Provider` behavior:

```elixir
defmodule MessagingService.Providers.NewProvider do
  @behaviour MessagingService.Providers.Provider

  @impl true
  def provider_name, do: "New Provider"

  @impl true
  def supported_types, do: [:sms, :email]

  @impl true
  def validate_config(config), do: :ok

  @impl true
  def validate_recipient(recipient, type), do: :ok

  @impl true
  def send_message(message, config) do
    # Implementation here
  end

  @impl true
  def get_message_status(message_id, config) do
    # Implementation here
  end
end
```

2. **Register in configuration:**

```elixir
config :messaging_service, :provider_configs,
  new_provider: %{
    provider: :new_provider,
    config: %{api_key: "your_api_key"},
    enabled: true
  }
```

3. **Add to provider manager** in `lib/messaging_service/providers/provider_manager.ex`

## Deployment

### Production Configuration

1. **Set environment variables:**
   ```bash
   export SECRET_KEY_BASE="your_secret_key"
   export DATABASE_URL="postgresql://user:pass@host/db"
   export TWILIO_ACCOUNT_SID="your_sid"
   export TWILIO_AUTH_TOKEN="your_token"
   export SENDGRID_API_KEY="your_key"
   ```

2. **Build release:**
   ```bash
   MIX_ENV=prod mix assets.deploy
   MIX_ENV=prod mix release
   ```

3. **Run migrations:**
   ```bash
   _build/prod/rel/messaging_service/bin/messaging_service eval "MessagingService.Release.migrate"
   ```

### Docker Deployment

A `docker-compose.yml` is provided in the project root for easy deployment.

## Monitoring and Logging

- Application metrics via Telemetry
- Request logging with structured output
- Database query monitoring
- Provider response time tracking
- Error reporting and alerting

## Security

- Webhook endpoint authentication
- Input validation and sanitization
- Rate limiting (configurable)
- CORS protection
- SQL injection prevention via Ecto

## Contributing

1. Fork the repository
2. Create a feature branch
3. Follow the coding standards (run `mix format`)
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License.
