---
description: Enforces best practices for Elixir development, focusing on context-aware code generation, modern patterns, and maintainable architecture. Provides comprehensive guidelines for writing clean, efficient, and secure Elixir code with proper context.
globs: **/*.{ex,exs}
---
# Elixir Best Practices

You are an expert in Elixir programming and related technologies.
You understand modern Elixir development practices, architectural patterns, and the importance of providing complete context in code generation.

### Context-Aware Code Generation
- Always provide complete module context including imports and aliases
- Include relevant configuration files (mix.exs, config.exs) when generating projects
- Generate complete function signatures with proper parameters and guards
- Include comprehensive documentation comments explaining the purpose, parameters, and return values
- Provide context about the module's role in the larger system architecture
- Follow proper module organization and application structure

### Code Style and Structure
- Follow Elixir style guide and clean code principles
- Structure code in logical modules following domain-driven design
- Implement proper separation of concerns (contexts, schemas, services)
- Use modern Elixir features (with, for comprehensions, pattern matching) appropriately
- Maintain consistent code formatting using mix format
- Use proper module attributes and function guards
- Implement proper error handling with custom error types
- Use proper logging with structured data

### Functional Programming
- Use proper immutable data structures
- Implement proper function composition
- Use proper pattern matching
- Implement proper recursion patterns
- Use proper higher-order functions
- Implement proper data transformation
- Use proper pipe operator patterns
- Implement proper function purity

### Testing and Quality
- Write comprehensive unit tests with proper test context
- Include integration tests for critical paths
- Use proper test organization with test modules
- Implement proper test helpers and utilities
- Include performance tests for critical components
- Maintain high test coverage for core business logic
- Use proper test data factories
- Implement proper test doubles
- Use proper test organization with test attributes

### Security and Performance
- Implement proper input validation and sanitization
- Use secure authentication and token management
- Configure proper CORS and CSRF protection
- Implement rate limiting and request validation
- Use proper caching strategies
- Optimize memory usage and garbage collection
- Implement proper error handling and logging
- Use proper data validation and sanitization
- Implement proper access control

### API Design
- Follow RESTful principles with proper HTTP methods
- Use proper status codes and error responses
- Implement proper versioning strategies
- Document APIs using OpenAPI/Swagger
- Include proper request/response validation
- Implement proper pagination and filtering
- Use proper serialization and deserialization
- Implement proper rate limiting
- Use proper API authentication

### Concurrency and Distribution
- Use proper process patterns
- Implement proper message passing
- Use proper supervision trees
- Implement proper OTP patterns
- Use proper GenServer patterns
- Implement proper error handling in processes
- Use proper resource cleanup
- Implement proper backpressure
- Use proper distributed patterns

### Build and Deployment
- Use proper mix tasks and dependencies
- Implement proper CI/CD pipelines
- Use Docker for containerization
- Configure proper environment variables
- Implement proper logging and monitoring
- Use proper deployment strategies
- Implement proper backup strategies
- Use proper monitoring tools
- Implement proper error tracking

### Examples

```code
defmodule UserService do
  @moduledoc """
  User service module for handling user-related operations.
  Provides methods for user management and authentication.
  """

  alias UserService.{Cache, ApiClient}
  require Logger

  @doc """
  Finds a user by their email address.

  ## Parameters

    * `email` - The email address to search for

  ## Returns

    * `{:ok, user}` - If the user is found
    * `{:ok, nil}` - If the user is not found
    * `{:error, reason}` - If an error occurs
  """
  def find_user_by_email(email) when is_binary(email) do
    with {:ok, cached_user} <- check_cache(email),
         {:ok, user} <- fetch_from_api(email) do
      {:ok, user}
    else
      {:error, :not_found} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_cache(email) do
    case Cache.get("user:#{email}") do
      {:ok, nil} -> {:error, :not_found}
      {:ok, data} -> {:ok, Jason.decode!(data)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_from_api(email) do
    case ApiClient.get_user(email) do
      {:ok, user} ->
        cache_user(user)
        {:ok, user}
      {:error, reason} ->
        Logger.error("Failed to fetch user: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp cache_user(user) do
    case Jason.encode(user) do
      {:ok, data} -> Cache.set("user:#{user.email}", data)
      {:error, reason} -> Logger.error("Failed to cache user: #{inspect(reason)}")
    end
  end
end

defmodule UserServiceTest do
  use ExUnit.Case, async: true
  alias UserService.{Cache, ApiClient}

  describe "find_user_by_email/1" do
    test "returns user when found in cache" do
      user = %{id: 1, email: "test@example.com"}
      Cache
      |> expect(:get, fn "user:test@example.com" -> {:ok, Jason.encode!(user)} end)

      assert {:ok, ^user} = UserService.find_user_by_email("test@example.com")
    end

    test "returns user when found via API" do
      user = %{id: 1, email: "test@example.com"}
      Cache
      |> expect(:get, fn "user:test@example.com" -> {:ok, nil} end)
      |> expect(:set, fn "user:test@example.com", _ -> :ok end)

      ApiClient
      |> expect(:get_user, fn "test@example.com" -> {:ok, user} end)

      assert {:ok, ^user} = UserService.find_user_by_email("test@example.com")
    end

    test "returns nil when user not found" do
      Cache
      |> expect(:get, fn "user:nonexistent@example.com" -> {:ok, nil} end)

      ApiClient
      |> expect(:get_user, fn "nonexistent@example.com" -> {:error, :not_found} end)

      assert {:ok, nil} = UserService.find_user_by_email("nonexistent@example.com")
    end

    test "returns error when API request fails" do
      Cache
      |> expect(:get, fn "user:test@example.com" -> {:ok, nil} end)

      ApiClient
      |> expect(:get_user, fn "test@example.com" -> {:error, :api_error} end)

      assert {:error, :api_error} = UserService.find_user_by_email("test@example.com")
    end
  end
end
```

### Additional Documentation
- Any documentation in the the form of individual `.md` files except for the projects `README.md` should be created and held in `/docs`
- Demo Scripts and files should be created and held in `/scripts`

### Documentation and Script Organization Compliance

✅ **Current Project Follows Documentation Rules**

The messaging service project properly organizes documentation and scripts:

**Documentation in `/docs/`:**
```
docs/
├── CONVERSATION_INTEGRATION.md    # Conversation threading guide
├── DIRECTORY_STRUCTURE.md         # Project organization documentation
├── OLDREADME.md                   # Previous README for reference
├── WEBHOOK_API.md                 # Webhook API documentation
└── WEBHOOK_TESTING.md             # Webhook testing guide
```

**Scripts in `/scripts/`:**
```
scripts/
├── README.md                      # Script documentation and usage
├── demo.exs                       # General project demonstration
├── outbound_messaging_demo.ex     # Outbound messaging showcase
├── outbound_messaging_demo.exs    # Alternative demo script
└── webhook_demo.exs               # Webhook functionality demo
```

**Root Level (Exception):**
- `README.md` - Main project documentation (properly remains at root)

### ExTest
- Directory structure of the test files should mirror that of the application. 

Ex.Application

lib/messaging_service/attachments/
├── attachment.ex     # Schema (singular)
└── attachments.ex    # Context (pluralized)

Ex. Tests

test/messaging_service/attachments/
├── attachment_test.exs     # Schema (singular)
└── attachments_test.exs    # Context (pluralized)


### Creating Schemas and Contexts

- Schema filenames are singular while the primary context filename should be the pluralized for of the schema
- ExTest for the schemas and contexts should mirror the structure

Ex.

lib/messaging_service/attachments/
├── attachment.ex     # Schema (singular)
└── attachments.ex    # Context (pluralized)

- If additional contexts are required for a schema, its filename should be descriptive of the context
- Schemas and Contexts are grouped together in a folder named for the context
- When attempting to create a new schema and a migration for that schema does not exist, attempt to create the migration first 
- Changes to a schemas structure will almost always need a migration to update the table
- Module names of the Schema and its context should not include the directory

Schema Module Name Example
Use `defmodule App.Instruction` instead of `defmodule App.Instructions.Instruction`

### Directory Structure Compliance

✅ **Current Project Structure Follows Rules**

The messaging service project now properly follows the directory structure mirroring rules:

```
lib/messaging_service/
├── attachments/
│   ├── attachment.ex     # Schema (singular)
│   └── attachments.ex    # Context (pluralized)
├── conversations/
│   ├── conversation.ex   # Schema (singular)
│   └── conversations.ex  # Context (pluralized)
├── messages/
│   ├── message.ex        # Schema (singular)
│   └── messages.ex       # Context (pluralized)
└── providers/
    ├── provider.ex           # Behavior (singular)
    ├── provider_manager.ex   # Additional context
    ├── twilio_provider.ex    # Implementation
    ├── sendgrid_provider.ex  # Implementation
    └── mock_provider.ex      # Implementation
```

**Corresponding Test Structure:**
```
test/messaging_service/
├── attachments/
│   ├── attachment_test.exs     # Schema tests (singular)
│   └── attachments_test.exs    # Context tests (pluralized)
├── conversations/
│   ├── conversation_test.exs   # Schema tests (singular)
│   └── conversations_test.exs  # Context tests (pluralized)
├── messages/
│   ├── message_test.exs        # Schema tests (singular)
│   ├── messages_test.exs       # Context tests (pluralized)
│   └── outbound_messaging_test.exs  # Additional context tests
└── providers/
    ├── provider_test.exs           # Behavior tests (singular)
    ├── provider_manager_test.exs   # Additional context tests
    ├── twilio_provider_test.exs    # Implementation tests
    ├── sendgrid_provider_test.exs  # Implementation tests
    └── mock_provider_test.exs      # Implementation tests
```

All test files now properly mirror the application directory structure as specified in the rules.




