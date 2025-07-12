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

