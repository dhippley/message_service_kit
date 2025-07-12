defmodule MessagingService.Messages do
  @moduledoc """
  The Messages context.

  This module provides functions for managing messages across different providers
  (SMS, MMS, Email), including creating, retrieving, and organizing messages into conversations.
  """

  import Ecto.Query, warn: false

  alias MessagingService.Conversations
  alias MessagingService.Message
  alias MessagingService.Repo

  require Logger

  @doc """
  Returns the list of messages.

  ## Examples

      iex> list_messages()
      [%Message{}, ...]

  """
  def list_messages do
    Repo.all(Message)
  end

  @doc """
  Gets a single message.

  Raises `Ecto.NoResultsError` if the Message does not exist.

  ## Examples

      iex> get_message!(123)
      %Message{}

      iex> get_message!(456)
      ** (Ecto.NoResultsError)

  """
  def get_message!(id), do: Repo.get!(Message, id)

  @doc """
  Gets a single message.

  Returns `nil` if the Message does not exist.

  ## Examples

      iex> get_message(123)
      %Message{}

      iex> get_message(456)
      nil

  """
  def get_message(id), do: Repo.get(Message, id)

  @doc """
  Gets a message with preloaded attachments.

  ## Examples

      iex> get_message_with_attachments!(message_id)
      %Message{attachments: [%MessagingService.Attachment{}, ...]}

  """
  def get_message_with_attachments!(id) do
    Message
    |> preload(:attachments)
    |> Repo.get!(id)
  end

  @doc """
  Creates an SMS message with conversation integration.

  Automatically finds or creates a conversation between the sender and recipient,
  and associates the message with that conversation.

  ## Examples

      iex> create_sms_message(%{from: "+1234567890", to: "+0987654321", body: "Hello"})
      {:ok, %Message{}}

      iex> create_sms_message(%{from: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def create_sms_message(attrs \\ %{}) do
    # If from or to is missing, fallback to creating without conversation
    from = attrs[:from] || attrs["from"]
    to = attrs[:to] || attrs["to"]

    if from && to do
      create_sms_message_with_conversation(attrs)
    else
      create_sms_message_without_conversation(attrs)
    end
  end

  @doc """
  Creates an SMS message with conversation integration.

  ## Examples

      iex> create_sms_message_with_conversation(%{from: "+1234567890", to: "+0987654321", body: "Hello"})
      {:ok, %Message{}}

  """
  def create_sms_message_with_conversation(attrs \\ %{}) do
    with {:ok, conversation} <- find_or_create_conversation_for_message(attrs),
         message_attrs = Map.put(attrs, :conversation_id, conversation.id),
         {:ok, message} <- create_sms_message_without_conversation(message_attrs),
         {:ok, _conversation} <- update_conversation_for_new_message(conversation, message) do
      {:ok, message}
    end
  end

  @doc """
  Creates an SMS message without conversation integration.

  This is a low-level function that creates a message without managing conversations.
  Use create_sms_message/1 instead for normal usage.

  ## Examples

      iex> create_sms_message_without_conversation(%{from: "+1234567890", to: "+0987654321", body: "Hello"})
      {:ok, %Message{}}

  """
  def create_sms_message_without_conversation(attrs \\ %{}) do
    %Message{}
    |> Message.sms_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates an MMS message with conversation integration.

  Automatically finds or creates a conversation between the sender and recipient,
  and associates the message with that conversation.

  ## Examples

      iex> create_mms_message(%{from: "+1234567890", to: "+0987654321", body: "Hello"})
      {:ok, %Message{}}

      iex> create_mms_message(%{from: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def create_mms_message(attrs \\ %{}) do
    # If from or to is missing, fallback to creating without conversation
    from = attrs[:from] || attrs["from"]
    to = attrs[:to] || attrs["to"]

    if from && to do
      create_mms_message_with_conversation(attrs)
    else
      create_mms_message_without_conversation(attrs)
    end
  end

  @doc """
  Creates an MMS message with conversation integration.

  ## Examples

      iex> create_mms_message_with_conversation(%{from: "+1234567890", to: "+0987654321", body: "Hello"})
      {:ok, %Message{}}

  """
  def create_mms_message_with_conversation(attrs \\ %{}) do
    with {:ok, conversation} <- find_or_create_conversation_for_message(attrs),
         message_attrs = Map.put(attrs, :conversation_id, conversation.id),
         {:ok, message} <- create_mms_message_without_conversation(message_attrs),
         {:ok, _conversation} <- update_conversation_for_new_message(conversation, message) do
      {:ok, message}
    end
  end

  @doc """
  Creates an MMS message without conversation integration.

  This is a low-level function that creates a message without managing conversations.
  Use create_mms_message/1 instead for normal usage.

  ## Examples

      iex> create_mms_message_without_conversation(%{from: "+1234567890", to: "+0987654321", body: "Hello"})
      {:ok, %Message{}}

  """
  def create_mms_message_without_conversation(attrs \\ %{}) do
    %Message{}
    |> Message.mms_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates an email message with conversation integration.

  Automatically finds or creates a conversation between the sender and recipient,
  and associates the message with that conversation.

  ## Examples

      iex> create_email_message(%{from: "user@example.com", to: "contact@example.com", body: "Hello"})
      {:ok, %Message{}}

      iex> create_email_message(%{from: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def create_email_message(attrs \\ %{}) do
    # If from or to is missing, fallback to creating without conversation
    from = attrs[:from] || attrs["from"]
    to = attrs[:to] || attrs["to"]

    if from && to do
      create_email_message_with_conversation(attrs)
    else
      create_email_message_without_conversation(attrs)
    end
  end

  @doc """
  Creates an email message with conversation integration.

  ## Examples

      iex> create_email_message_with_conversation(%{from: "user@example.com", to: "contact@example.com", body: "Hello"})
      {:ok, %Message{}}

  """
  def create_email_message_with_conversation(attrs \\ %{}) do
    with {:ok, conversation} <- find_or_create_conversation_for_message(attrs),
         message_attrs = Map.put(attrs, :conversation_id, conversation.id),
         {:ok, message} <- create_email_message_without_conversation(message_attrs),
         {:ok, _conversation} <- update_conversation_for_new_message(conversation, message) do
      {:ok, message}
    end
  end

  @doc """
  Creates an email message without conversation integration.

  This is a low-level function that creates a message without managing conversations.
  Use create_email_message/1 instead for normal usage.

  ## Examples

      iex> create_email_message_without_conversation(%{from: "user@example.com", to: "contact@example.com", body: "Hello"})
      {:ok, %Message{}}

  """
  def create_email_message_without_conversation(attrs \\ %{}) do
    %Message{}
    |> Message.email_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a message with attachments in a transaction.

  This function includes conversation integration - it will find or create
  a conversation for the message based on the from/to fields.

  ## Examples

      iex> create_message_with_attachments(message_attrs, [attachment_attrs])
      {:ok, %Message{attachments: [%MessagingService.Attachment{}]}}

      iex> create_message_with_attachments(invalid_attrs, [])
      {:error, %Ecto.Changeset{}}

  """
  def create_message_with_attachments(message_attrs, attachment_attrs_list) when is_list(attachment_attrs_list) do
    message_type = message_attrs[:type] || message_attrs["type"]

    Repo.transaction(fn ->
      with {:ok, message} <-
             create_message_by_type_with_conversation(message_type, message_attrs),
           {:ok, attachments} <- create_attachments_for_message(message.id, attachment_attrs_list) do
        %{message | attachments: attachments}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Creates a message with attachments in a transaction without conversation integration.

  This is a low-level function that creates a message with attachments without
  managing conversations. Use create_message_with_attachments/2 instead for normal usage.

  ## Examples

      iex> create_message_with_attachments_without_conversation(message_attrs, [attachment_attrs])
      {:ok, %Message{attachments: [%MessagingService.Attachment{}]}}

  """
  def create_message_with_attachments_without_conversation(message_attrs, attachment_attrs_list)
      when is_list(attachment_attrs_list) do
    message_type = message_attrs[:type] || message_attrs["type"]

    Repo.transaction(fn ->
      with {:ok, message} <- create_message_by_type(message_type, message_attrs),
           {:ok, attachments} <- create_attachments_for_message(message.id, attachment_attrs_list) do
        %{message | attachments: attachments}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Updates a message.

  ## Examples

      iex> update_message(message, %{body: "Updated content"})
      {:ok, %Message{}}

      iex> update_message(message, %{type: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a message.

  ## Examples

      iex> delete_message(message)
      {:ok, %Message{}}

      iex> delete_message(message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.

  ## Examples

      iex> change_message(message)
      %Ecto.Changeset{data: %Message{}}

  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  @doc """
  Lists messages by type.

  ## Examples

      iex> list_messages_by_type("sms")
      [%Message{type: "sms"}, ...]

  """
  def list_messages_by_type(type) do
    Repo.all(from(m in Message, where: m.type == ^type, order_by: [desc: m.timestamp]))
  end

  @doc """
  Lists messages in a conversation between two contacts.

  ## Examples

      iex> list_conversation_messages("+1234567890", "+0987654321")
      [%Message{}, ...]

  """
  def list_conversation_messages(contact1, contact2) do
    Repo.all(
      from(m in Message,
        where: (m.from == ^contact1 and m.to == ^contact2) or (m.from == ^contact2 and m.to == ^contact1),
        order_by: [asc: m.timestamp],
        preload: :attachments
      )
    )
  end

  @doc """
  Lists messages sent from a specific contact.

  ## Examples

      iex> list_messages_from("+1234567890")
      [%Message{}, ...]

  """
  def list_messages_from(from_contact) do
    Repo.all(from(m in Message, where: m.from == ^from_contact, order_by: [desc: m.timestamp]))
  end

  @doc """
  Lists messages sent to a specific contact.

  ## Examples

      iex> list_messages_to("+0987654321")
      [%Message{}, ...]

  """
  def list_messages_to(to_contact) do
    Repo.all(from(m in Message, where: m.to == ^to_contact, order_by: [desc: m.timestamp]))
  end

  @doc """
  Gets the latest message in a conversation.

  ## Examples

      iex> get_latest_conversation_message("+1234567890", "+0987654321")
      %Message{}

      iex> get_latest_conversation_message("nonexistent1", "nonexistent2")
      nil

  """
  def get_latest_conversation_message(contact1, contact2) do
    Repo.one(
      from(m in Message,
        where: (m.from == ^contact1 and m.to == ^contact2) or (m.from == ^contact2 and m.to == ^contact1),
        order_by: [desc: m.timestamp],
        limit: 1
      )
    )
  end

  @doc """
  Lists all unique conversations (unique contact pairs).

  Returns a list of maps with contact pairs and their latest message.

  ## Examples

      iex> list_conversations()
      [
        %{contact1: "+1234567890", contact2: "+0987654321", latest_message: %Message{}},
        ...
      ]

  """
  def list_conversations do
    # This is a complex query to get unique conversations
    # We'll get all unique (from, to) pairs and their latest messages
    conversations_query =
      from(m in Message,
        select: %{
          contact1: fragment("LEAST(?, ?)", m.from, m.to),
          contact2: fragment("GREATEST(?, ?)", m.from, m.to),
          latest_timestamp: max(m.timestamp)
        },
        group_by: [
          fragment("LEAST(?, ?)", m.from, m.to),
          fragment("GREATEST(?, ?)", m.from, m.to)
        ]
      )

    conversations = Repo.all(conversations_query)

    # For each conversation, get the latest message
    Enum.map(conversations, fn conv ->
      latest_message = get_latest_conversation_message(conv.contact1, conv.contact2)
      Map.put(conv, :latest_message, latest_message)
    end)
  end

  @doc """
  Searches messages by body content.

  ## Examples

      iex> search_messages("hello")
      [%Message{}, ...]

  """
  def search_messages(search_term) when is_binary(search_term) do
    search_pattern = "%#{search_term}%"

    Repo.all(
      from(m in Message, where: ilike(m.body, ^search_pattern), order_by: [desc: m.timestamp], preload: :attachments)
    )
  end

  @doc """
  Gets message count by type.

  ## Examples

      iex> get_message_count_by_type()
      %{"sms" => 10, "mms" => 5, "email" => 3}

  """
  def get_message_count_by_type do
    from(m in Message,
      group_by: m.type,
      select: {m.type, count(m.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Gets messages with attachments.

  ## Examples

      iex> list_messages_with_attachments()
      [%Message{attachments: [%MessagingService.Attachment{}, ...]}, ...]

  """
  def list_messages_with_attachments do
    Repo.all(from(m in Message, join: a in assoc(m, :attachments), preload: :attachments, order_by: [desc: m.timestamp]))
  end

  @doc """
  Validates if a message exists and is accessible.

  ## Examples

      iex> validate_message_exists(message_id)
      {:ok, %Message{}}

      iex> validate_message_exists("nonexistent")
      {:error, :not_found}

  """
  def validate_message_exists(message_id) do
    case get_message(message_id) do
      nil -> {:error, :not_found}
      message -> {:ok, message}
    end
  end

  # Outbound messaging functions

  @doc """
  Sends an outbound message through the appropriate provider.

  This function handles the complete outbound message flow:
  1. Validates the message
  2. Selects the appropriate provider
  3. Sends the message
  4. Stores the message in the database with provider information

  ## Parameters
  - `message_attrs` - Map containing message attributes
  - `provider_configs` - Optional provider configurations (uses default if not provided)

  ## Examples

      iex> send_outbound_message(%{
      ...>   type: :sms,
      ...>   to: "+1234567890",
      ...>   from: "+0987654321",
      ...>   body: "Hello from MessagingService!"
      ...> })
      {:ok, %Message{}}

      iex> send_outbound_message(%{
      ...>   type: :email,
      ...>   to: "user@example.com",
      ...>   from: "service@example.com",
      ...>   body: "Hello from MessagingService!"
      ...> })
      {:ok, %Message{}}

  ## Returns
  - `{:ok, message}` - Message sent and stored successfully
  - `{:error, reason}` - Failed to send message
  """
  def send_outbound_message(message_attrs, provider_configs \\ nil) do
    alias MessagingService.Providers.ProviderManager

    provider_configs = provider_configs || get_default_provider_configs()

    # Create message request for provider
    message_request = build_message_request(message_attrs)

    with :ok <- validate_outbound_message(message_request),
         {:ok, message_id, provider_name} <- ProviderManager.send_message(message_request, provider_configs),
         {:ok, message} <- store_outbound_message(message_attrs, message_id, provider_name) do
      {:ok, message}
    else
      {:error, reason} = error ->
        Logger.error("Failed to send outbound message: #{reason}")
        error
    end
  end

  @doc """
  Sends an outbound SMS message.

  ## Parameters
  - `to` - Recipient phone number in E.164 format
  - `from` - Sender phone number in E.164 format
  - `body` - Message content
  - `provider_configs` - Optional provider configurations

  ## Examples

      iex> send_sms("+1234567890", "+0987654321", "Hello!")
      {:ok, %Message{}}

  ## Returns
  - `{:ok, message}` - SMS sent and stored successfully
  - `{:error, reason}` - Failed to send SMS
  """
  def send_sms(to, from, body, provider_configs \\ nil) do
    message_attrs = %{
      type: :sms,
      to: to,
      from: from,
      body: body
    }

    send_outbound_message(message_attrs, provider_configs)
  end

  @doc """
  Sends an outbound MMS message.

  ## Parameters
  - `to` - Recipient phone number in E.164 format
  - `from` - Sender phone number in E.164 format
  - `body` - Message content
  - `attachments` - List of attachment maps (optional)
  - `provider_configs` - Optional provider configurations

  ## Examples

      iex> send_mms("+1234567890", "+0987654321", "Hello!", [%{filename: "image.jpg", content_type: "image/jpeg", data: <<binary>>}])
      {:ok, %Message{}}

  ## Returns
  - `{:ok, message}` - MMS sent and stored successfully
  - `{:error, reason}` - Failed to send MMS
  """
  def send_mms(to, from, body, attachments \\ [], provider_configs \\ nil) do
    message_attrs = %{
      type: :mms,
      to: to,
      from: from,
      body: body,
      attachments: attachments
    }

    send_outbound_message(message_attrs, provider_configs)
  end

  @doc """
  Sends an outbound email message.

  ## Parameters
  - `to` - Recipient email address
  - `from` - Sender email address
  - `body` - Message content
  - `attachments` - List of attachment maps (optional)
  - `provider_configs` - Optional provider configurations

  ## Examples

      iex> send_email("user@example.com", "service@example.com", "Hello!")
      {:ok, %Message{}}

  ## Returns
  - `{:ok, message}` - Email sent and stored successfully
  - `{:error, reason}` - Failed to send email
  """
  def send_email(to, from, body, attachments \\ [], provider_configs \\ nil) do
    message_attrs = %{
      type: :email,
      to: to,
      from: from,
      body: body,
      attachments: attachments
    }

    send_outbound_message(message_attrs, provider_configs)
  end

  @doc """
  Gets the delivery status of an outbound message.

  ## Parameters
  - `message` - The message to check status for

  ## Returns
  - `{:ok, status}` - Status retrieved successfully
  - `{:error, reason}` - Failed to get status
  """
  def get_outbound_message_status(message) do
    alias MessagingService.Providers.ProviderManager

    if message.messaging_provider_id do
      # Extract provider name from message (stored in a custom field we'll add)
      provider_name = get_provider_name_from_message(message)
      provider_configs = get_default_provider_configs()

      ProviderManager.get_message_status(message.messaging_provider_id, provider_name, provider_configs)
    else
      {:error, "No provider message ID found"}
    end
  end

  @doc """
  Lists all available messaging providers and their capabilities.

  ## Returns
  - Map of provider information
  """
  def list_messaging_providers do
    alias MessagingService.Providers.ProviderManager

    ProviderManager.list_providers()
  end

  @doc """
  Validates provider configurations.

  ## Parameters
  - `provider_configs` - Map of provider configurations

  ## Returns
  - `:ok` - All configurations are valid
  - `{:error, errors}` - Configuration errors
  """
  def validate_provider_configurations(provider_configs) do
    alias MessagingService.Providers.ProviderManager

    ProviderManager.validate_configurations(provider_configs)
  end

  # Private functions for outbound messaging

  defp build_message_request(message_attrs) do
    %{
      type: message_attrs[:type] || message_attrs["type"],
      to: message_attrs[:to] || message_attrs["to"],
      from: message_attrs[:from] || message_attrs["from"],
      body: message_attrs[:body] || message_attrs["body"],
      attachments: message_attrs[:attachments] || message_attrs["attachments"] || []
    }
  end

  defp validate_outbound_message(message_request) do
    alias MessagingService.Provider

    Provider.validate_message_request(message_request)
  end

  defp store_outbound_message(message_attrs, provider_message_id, provider_name) do
    # Store the message in our database with provider information
    attrs_with_provider =
      message_attrs
      |> Map.put(:messaging_provider_id, provider_message_id)
      |> Map.put(:timestamp, NaiveDateTime.utc_now())
      |> Map.put(:provider_name, Atom.to_string(provider_name))

    case message_attrs[:type] || message_attrs["type"] do
      :sms -> create_sms_message(attrs_with_provider)
      :mms -> create_mms_message(attrs_with_provider)
      :email -> create_email_message(attrs_with_provider)
      type -> {:error, "Unsupported message type: #{type}"}
    end
  end

  defp get_provider_name_from_message(message) do
    # For now, we'll determine provider based on message type and provider_id format
    # In a real implementation, you might store this in a separate field
    cond do
      message.messaging_provider_id && String.starts_with?(message.messaging_provider_id, "SM") -> :twilio
      message.messaging_provider_id && String.starts_with?(message.messaging_provider_id, "SG") -> :sendgrid
      true -> :mock
    end
  end

  defp get_default_provider_configs do
    # Get configurations from application config or use defaults
    config = Application.get_env(:messaging_service, :provider_configs)

    if config do
      # Convert keyword list to map if necessary
      if is_list(config) and Keyword.keyword?(config) do
        Map.new(config)
      else
        config
      end
    else
      alias MessagingService.Providers.ProviderManager

      env = Application.get_env(:messaging_service, :environment, :dev)
      ProviderManager.default_configurations(env)
    end
  end

  # Private helper functions

  defp create_message_by_type_with_conversation("sms", attrs), do: create_sms_message_with_conversation(attrs)

  defp create_message_by_type_with_conversation("mms", attrs), do: create_mms_message_with_conversation(attrs)

  defp create_message_by_type_with_conversation("email", attrs), do: create_email_message_with_conversation(attrs)

  defp create_message_by_type_with_conversation(_, attrs), do: {:error, Message.changeset(%Message{}, attrs)}

  defp create_message_by_type("sms", attrs), do: create_sms_message_without_conversation(attrs)
  defp create_message_by_type("mms", attrs), do: create_mms_message_without_conversation(attrs)

  defp create_message_by_type("email", attrs), do: create_email_message_without_conversation(attrs)

  defp create_message_by_type(_, attrs), do: {:error, Message.changeset(%Message{}, attrs)}

  defp create_attachments_for_message(message_id, attachment_attrs_list) do
    attachments =
      Enum.map(attachment_attrs_list, fn attrs ->
        attrs_with_message_id = Map.put(attrs, :message_id, message_id)

        case determine_attachment_type(attrs_with_message_id) do
          :url -> MessagingService.Attachments.create_url_attachment(attrs_with_message_id)
          :blob -> MessagingService.Attachments.create_blob_attachment(attrs_with_message_id)
          :unknown -> {:error, :invalid_attachment_data}
        end
      end)

    # Check if all attachments were created successfully
    case Enum.find(attachments, &(elem(&1, 0) == :error)) do
      nil ->
        {:ok, Enum.map(attachments, &elem(&1, 1))}

      error ->
        error
    end
  end

  defp determine_attachment_type(attrs) do
    cond do
      attrs[:url] || attrs["url"] -> :url
      attrs[:blob] || attrs["blob"] -> :blob
      true -> :unknown
    end
  end

  defp find_or_create_conversation_for_message(attrs) do
    # Extracting sender and recipient from attrs
    from = attrs[:from] || attrs["from"]
    to = attrs[:to] || attrs["to"]

    # Use the Conversations context to find or create the conversation
    Conversations.find_or_create_conversation(from, to)
  end

  defp update_conversation_for_new_message(conversation, message) do
    # Update the conversation's message count and last message timestamp
    Conversations.update_conversation_last_message(conversation, message.timestamp)
  end
end
