#!/bin/bash

set -e

# Ensure we're in the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Starting the Messaging Service Kit..."
echo "Project root: $(pwd)"
echo "Environment: ${MIX_ENV:-dev}"

# Check if dependencies are installed
if [ ! -d "deps" ]; then
  echo "Installing dependencies..."
  mix deps.get
fi

# Compile the application
echo "Compiling application..."
mix compile

# Check if PostgreSQL is running
echo "Checking database connectivity..."
if ! pg_isready -q -h localhost -p 5432; then
  echo "⚠️  PostgreSQL is not running on localhost:5432"
  echo "Please start PostgreSQL and try again:"
  exit 1
fi

# Set up database if needed
echo "Setting up database..."
mix ecto.create --quiet || echo "Database already exists"
mix ecto.migrate --quiet

# Stop any running Phoenix servers to prevent conflicts
echo "Stopping any running Phoenix servers..."
pkill -f "mix phx.server" || true
pkill -f "mix run --no-halt" || true
sleep 1

# Start the mock provider in the background
echo "Starting mock provider..."
(cd apps/mock_provider && mix run --no-halt) &
MOCK_PID=$!

# Wait a moment for mock provider to start
sleep 2

echo "Mock provider started with PID: $MOCK_PID"

# Start the Phoenix server
echo "Starting Phoenix server..."
echo "Access the application at: http://localhost:4000"
echo "API documentation available in README.md"
echo ""
echo "To stop the application, press Ctrl+C"

# Trap signals to clean up background processes
trap "echo 'Stopping services...'; kill $MOCK_PID 2>/dev/null || true; exit 0" INT TERM

# Start Phoenix server (use subshell to avoid directory change issues)
cd apps/messaging_service && mix phx.server 