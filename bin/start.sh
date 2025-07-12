#!/bin/bash

set -e

echo "Starting the Messaging Service Kit..."
echo "Environment: ${MIX_ENV:-dev}"

# Check if dependencies are installed
if [ ! -d "deps" ]; then
  echo "Installing dependencies..."
  mix deps.get
fi

# Compile the application
echo "Compiling application..."
mix compile

# Set up database if needed
echo "Setting up database..."
mix ecto.create --quiet || echo "Database already exists"
mix ecto.migrate --quiet

# Start the mock provider in the background
echo "Starting mock provider..."
cd apps/mock_provider && mix run --no-halt &
MOCK_PID=$!
cd ../..

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

# Start Phoenix server
mix phx.server 