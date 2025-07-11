# MockProvider

MockProvider is a simple Elixir application that simulates external messaging service APIs like Twilio (SMS/MMS) and SendGrid (Email). It's designed to be used for testing the messaging service without requiring real API credentials or sending actual messages.

## Features

- **Twilio SMS/MMS API Mock**: Simulates Twilio's messaging API with proper response format
- **SendGrid Email API Mock**: Simulates SendGrid's email API with proper response format  
- **Lightweight**: Bare-bones Elixir app using Plug + Cowboy (no Phoenix)
- **Realistic Responses**: Returns properly formatted responses with message IDs and status

## API Endpoints

### Twilio-like SMS/MMS
```
POST /v1/Accounts/{AccountSid}/Messages
```

**Request Body Example:**
```json
{
  "From": "+15551234567",
  "To": "+15559876543",
  "Body": "Hello, this is a test SMS!"
}
```

**Response Example:**
```json
{
  "sid": "SM...",
  "status": "queued",
  "from": "+15551234567",
  "to": "+15559876543",
  "body": "Hello, this is a test SMS!",
  "account_sid": "AC...",
  "date_created": "2025-07-11T18:44:56.731643Z",
  ...
}
```

### SendGrid-like Email
```
POST /v3/mail/send
```

**Request Body Example:**
```json
{
  "personalizations": [
    {
      "to": [{"email": "recipient@example.com"}],
      "subject": "Test Email"
    }
  ],
  "from": {"email": "sender@example.com"},
  "content": [
    {
      "type": "text/plain",
      "value": "This is a test email"
    }
  ]
}
```

**Response:** HTTP 202 with `x-message-id` header

### Health Check
```
GET /health
```

Returns: `{"status": "ok", "service": "mock_provider"}`

## Usage

### Start the Application
```bash
cd apps/mock_provider
mix deps.get
iex -S mix
```

The server will start on port 4001.

### Test with curl

**SMS Example:**
```bash
curl -X POST http://localhost:4001/v1/Accounts/AC123/Messages \
  -H "Content-Type: application/json" \
  -d '{
    "From": "+15551234567",
    "To": "+15559876543", 
    "Body": "Hello from mock Twilio!"
  }'
```

**Email Example:**
```bash
curl -X POST http://localhost:4001/v3/mail/send \
  -H "Content-Type: application/json" \
  -d '{
    "personalizations": [
      {
        "to": [{"email": "test@example.com"}],
        "subject": "Test Email"
      }
    ],
    "from": {"email": "sender@example.com"}
  }'
```

## Configuration

The application runs on port 4001 by default. This can be modified in `lib/mock_provider/application.ex`.

## Testing

```bash
mix test
```

