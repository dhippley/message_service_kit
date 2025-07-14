# MessagingServiceKit

A comprehensive Elixir umbrella project for messaging services, providing a unified API for sending SMS, MMS, and email messages through multiple providers.

## Apps

- **messaging_service**: Phoenix-based main application providing messaging API
- **mock_provider**: Lightweight HTTP server that simulates messaging provider APIs for development and testing

## Quick Start

```bash
# Install dependencies
mix deps.get

# Start the App
./bin/start.sh
```

## Using the Makefile

This project includes a Makefile with convenient commands for common development tasks:

```bash
# Show all available commands
make help

# Set up the project (starts database and waits for it to be ready)
make setup

# Start the application
make run

# Run tests scripts
make test

# Database management
make db-up      # Start PostgreSQL database
make db-down    # Stop PostgreSQL database  
make db-logs    # Show database logs
make db-shell   # Connect to database shell

# Clean up (stop containers and remove temporary files)
make clean
```

**Note**: The Makefile uses Docker Compose to manage the PostgreSQL database. Make sure Docker is installed and running on your system.

## Web Interface

Once the application is running, you can access the web interface at `http://localhost:4000`. The interface provides real-time monitoring and management capabilities for your messaging service.

### Dashboard

The real-time telemetry dashboard (`/dashboard`) offers comprehensive monitoring of your messaging service:

**System Overview**
- **Message Processing Metrics**: Total messages processed, average processing time, and success rates
- **Real-time Activity**: Live updates of message throughput and recent activity (last 5 minutes)
- **System Health**: Memory usage, database connections, and telemetry system status

**Performance Analytics**
- **Status Transitions**: Detailed timing for each message state (pending → queued → processing → sent/failed)
- **Message Type Breakdown**: Performance metrics segmented by SMS, MMS, and email
- **Provider Performance**: Success rates and response times by messaging provider

**Queue Management** 
- **Oban Queue Status**: Real-time view of background job queues with execution counts
- **Messaging Queue Details**: Specific monitoring of the messaging queue with worker utilization
- **Recent Jobs**: Live feed of recent message delivery jobs and their status

**Stress Testing**
- **Test Results**: Performance metrics from stress test runs including throughput and duration
- **Interactive Testing**: Built-in "Party Button" for quick stress testing with 5000 scenarios
- **Historical Data**: Trends and patterns from previous test runs

### Conversations

The conversation management interface (`/conversations`) provides:

**Message Threading**
- **Conversation History**: Complete message threads between participants
- **Multi-participant Support**: Group conversations with multiple recipients
- **Real-time Updates**: Live message updates as conversations progress

**Message Management**
- **Delivery Status**: Visual indicators for message delivery states
- **Message Types**: Support for SMS, MMS, and email within conversations
- **Attachment Handling**: Display and management of media attachments in MMS and email

**Search and Filtering**
- **Contact Search**: Find conversations by participant phone numbers or email addresses
- **Date Filtering**: Browse conversations by time period
- **Status Filtering**: Filter by delivery status or message type

Both interfaces feature:
- **Auto-refresh**: Real-time updates every 5 seconds without page reloads
- **Responsive Design**: Mobile-friendly interface with modern styling
- **Interactive Elements**: Clickable metrics, expandable sections, and live data visualization

### Party Mode (Stress Testing)

The application includes built-in stress testing capabilities accessible through both the web interface and command line:

**Web Interface Testing**
- **Party Button**: Located in the top navigation, click the 🎉 button for instant stress testing
- **Pre-configured Test**: Automatically runs 5000 scenarios with 100 concurrent workers
- **Real-time Feedback**: Live notifications show test progress and completion status
- **Scenario Variety**: Includes chaos, Lord of the Rings, and Ghostbusters themed conversation scenarios

**Command Line Testing**
```bash
# Basic stress test
curl -X POST http://localhost:4001/simulate/stress-test \
  -H "Content-Type: application/json" \
  -d '{
    "scenario_count": 1000,
    "concurrent_workers": 50,
    "delay_between_batches": 25
  }'

# Advanced stress test with all scenarios
curl -X POST http://localhost:4001/simulate/stress-test \
  -H "Content-Type: application/json" \
  -d '{
    "scenario_count": 5000,
    "concurrent_workers": 300,
    "delay_between_batches": 25,
    "scenario_types": ["chaos", "lotr_black_gate", "ghostbusters_elevator"]
  }'
```

**Monitoring Results**
- **Dashboard Integration**: Test results appear automatically on the telemetry dashboard
- **Performance Metrics**: View throughput, duration, success rates, and worker efficiency
- **Queue Impact**: Monitor how stress tests affect message queue processing
- **System Resources**: Track CPU, memory, and database performance during tests

**Configuration Options**
- **scenario_count**: Number of conversation scenarios to simulate (1-100,000)
- **concurrent_workers**: Number of parallel workers (minimum 50)
- **delay_between_batches**: Milliseconds between batches of 10 scenarios (0+ for no delay)
- **scenario_types**: Array of scenario themes to include in the test


## Development

### Code Quality Tools

This project uses several code quality tools:

```bash
# Format code
mix format

# Advanced formatting with Styler
mix style              # Format code with Styler
mix style --check      # Check if code is properly formatted with Styler

# Static analysis with Credo
mix credo
mix credo --strict

# Type analysis with Dialyzer
mix dialyzer

# Test coverage with Coveralls
mix coveralls              # Generate coverage report
mix coveralls.html         # Generate HTML coverage report
mix coveralls.json         # Generate JSON coverage report
mix coveralls.github       # Generate coverage for GitHub Actions

# Convenience aliases (from messaging_service app)
cd apps/messaging_service && mix test.coverage      # Same as coveralls
cd apps/messaging_service && mix test.coverage.html # Same as coveralls.html

# Run all quality checks
cd apps/messaging_service && mix quality
```

### Testing

```bash
# Run all tests
mix test

# Run tests for specific app
mix test apps/messaging_service/
mix test apps/mock_provider/
```

## Project Structure

```
├── apps/
│   ├── messaging_service/     # Main Phoenix application
│   └── mock_provider/         # Development mock server
├── config/                    # Shared configuration
├── deps/                      # Dependencies
└── _build/                    # Build artifacts
```



See individual app READMEs for detailed documentation:
- [MessagingService README](apps/messaging_service/README.md)
- [MockProvider README](apps/mock_provider/README.md)

