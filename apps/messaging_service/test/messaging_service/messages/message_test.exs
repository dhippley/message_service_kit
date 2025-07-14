defmodule MessagingService.MessageTest do
  use MessagingService.DataCase, async: true

  alias MessagingService.Message

  @valid_sms_attrs %{
    from: "+12345678901",
    to: "+12345678902",
    type: "sms",
    body: "Hello SMS"
  }

  @valid_mms_attrs %{
    from: "+12345678901",
    to: "+12345678902",
    type: "mms",
    body: "Hello MMS"
  }

  @valid_email_attrs %{
    from: "sender@example.com",
    to: "recipient@example.com",
    type: "email",
    body: "Hello Email"
  }

  describe "changeset/2" do
    test "valid SMS attributes" do
      changeset = Message.changeset(%Message{}, @valid_sms_attrs)
      assert changeset.valid?
    end

    test "valid MMS attributes" do
      changeset = Message.changeset(%Message{}, @valid_mms_attrs)
      assert changeset.valid?
    end

    test "valid email attributes" do
      changeset = Message.changeset(%Message{}, @valid_email_attrs)
      assert changeset.valid?
    end

    test "requires to, from, type, and body fields" do
      changeset = Message.changeset(%Message{}, %{})

      refute changeset.valid?
      assert %{to: ["can't be blank"]} = errors_on(changeset)
      assert %{from: ["can't be blank"]} = errors_on(changeset)
      assert %{type: ["can't be blank"]} = errors_on(changeset)
      assert %{body: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates message type inclusion" do
      changeset = Message.changeset(%Message{}, %{@valid_sms_attrs | type: "invalid"})

      refute changeset.valid?
      assert %{type: ["must be one of: sms, mms, email"]} = errors_on(changeset)
    end

    test "validates body cannot be empty" do
      changeset = Message.changeset(%Message{}, %{@valid_sms_attrs | body: ""})

      refute changeset.valid?
      assert %{body: ["can't be blank"]} = errors_on(changeset)
    end

    test "sets timestamp when not provided" do
      changeset = Message.changeset(%Message{}, @valid_sms_attrs)

      assert changeset.valid?
      assert get_change(changeset, :timestamp) != nil
    end

    test "preserves timestamp when provided" do
      timestamp = ~N[2024-01-01 12:00:00.000000]
      attrs = Map.put(@valid_sms_attrs, :timestamp, timestamp)
      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :timestamp) == timestamp
    end
  end

  describe "sms_changeset/2" do
    test "valid SMS attributes" do
      changeset = Message.sms_changeset(%Message{}, Map.delete(@valid_sms_attrs, :type))

      assert changeset.valid?
      assert get_change(changeset, :type) == "sms"
    end

    test "validates phone number format for from field" do
      invalid_attrs = %{@valid_sms_attrs | from: "invalid-phone"}
      changeset = Message.sms_changeset(%Message{}, Map.delete(invalid_attrs, :type))

      refute changeset.valid?
      assert %{from: ["Invalid phone number format. Must be in E.164 format (e.g., +1234567890)"]} = errors_on(changeset)
    end

    test "validates phone number format for to field" do
      invalid_attrs = %{@valid_sms_attrs | to: "invalid-phone"}
      changeset = Message.sms_changeset(%Message{}, Map.delete(invalid_attrs, :type))

      refute changeset.valid?
      assert %{to: ["Invalid phone number format. Must be in E.164 format (e.g., +1234567890)"]} = errors_on(changeset)
    end

    test "validates SMS body length limit" do
      long_body = String.duplicate("x", 161)
      invalid_attrs = %{@valid_sms_attrs | body: long_body}
      changeset = Message.sms_changeset(%Message{}, Map.delete(invalid_attrs, :type))

      refute changeset.valid?
      assert %{body: ["SMS body cannot exceed 160 characters"]} = errors_on(changeset)
    end

    test "accepts body at exactly 160 characters" do
      exact_body = String.duplicate("x", 160)
      attrs = %{@valid_sms_attrs | body: exact_body}
      changeset = Message.sms_changeset(%Message{}, Map.delete(attrs, :type))

      assert changeset.valid?
    end
  end

  describe "mms_changeset/2" do
    test "valid MMS attributes" do
      changeset = Message.mms_changeset(%Message{}, Map.delete(@valid_mms_attrs, :type))

      assert changeset.valid?
      assert get_change(changeset, :type) == "mms"
    end

    test "validates phone number format" do
      invalid_attrs = %{@valid_mms_attrs | from: "invalid-phone"}
      changeset = Message.mms_changeset(%Message{}, Map.delete(invalid_attrs, :type))

      refute changeset.valid?
      assert %{from: ["Invalid phone number format. Must be in E.164 format (e.g., +1234567890)"]} = errors_on(changeset)
    end

    test "validates MMS body length limit" do
      long_body = String.duplicate("x", 1601)
      invalid_attrs = %{@valid_mms_attrs | body: long_body}
      changeset = Message.mms_changeset(%Message{}, Map.delete(invalid_attrs, :type))

      refute changeset.valid?
      assert %{body: ["MMS body cannot exceed 1600 characters"]} = errors_on(changeset)
    end

    test "accepts body at exactly 1600 characters" do
      exact_body = String.duplicate("x", 1600)
      attrs = %{@valid_mms_attrs | body: exact_body}
      changeset = Message.mms_changeset(%Message{}, Map.delete(attrs, :type))

      assert changeset.valid?
    end
  end

  describe "email_changeset/2" do
    test "valid email attributes" do
      changeset = Message.email_changeset(%Message{}, Map.delete(@valid_email_attrs, :type))

      assert changeset.valid?
      assert get_change(changeset, :type) == "email"
    end

    test "validates email format for from field" do
      invalid_attrs = %{@valid_email_attrs | from: "invalid-email"}
      changeset = Message.email_changeset(%Message{}, Map.delete(invalid_attrs, :type))

      refute changeset.valid?
      assert %{from: ["must be a valid email address"]} = errors_on(changeset)
    end

    test "validates email format for to field" do
      invalid_attrs = %{@valid_email_attrs | to: "invalid-email"}
      changeset = Message.email_changeset(%Message{}, Map.delete(invalid_attrs, :type))

      refute changeset.valid?
      assert %{to: ["must be a valid email address"]} = errors_on(changeset)
    end

    test "validates email body length limit" do
      long_body = String.duplicate("x", 100_001)
      invalid_attrs = %{@valid_email_attrs | body: long_body}
      changeset = Message.email_changeset(%Message{}, Map.delete(invalid_attrs, :type))

      refute changeset.valid?
      assert %{body: ["Email body is too long"]} = errors_on(changeset)
    end

    test "accepts very long email body within limit" do
      long_body = String.duplicate("x", 50_000)
      attrs = %{@valid_email_attrs | body: long_body}
      changeset = Message.email_changeset(%Message{}, Map.delete(attrs, :type))

      assert changeset.valid?
    end
  end

  describe "helper functions" do
    test "phone_message?/1" do
      sms_message = %Message{type: "sms"}
      mms_message = %Message{type: "mms"}
      email_message = %Message{type: "email"}

      assert Message.phone_message?(sms_message)
      assert Message.phone_message?(mms_message)
      refute Message.phone_message?(email_message)
    end

    test "email_message?/1" do
      sms_message = %Message{type: "sms"}
      email_message = %Message{type: "email"}

      refute Message.email_message?(sms_message)
      assert Message.email_message?(email_message)
    end

    test "supports_attachments?/1" do
      sms_message = %Message{type: "sms"}
      mms_message = %Message{type: "mms"}
      email_message = %Message{type: "email"}

      refute Message.supports_attachments?(sms_message)
      assert Message.supports_attachments?(mms_message)
      assert Message.supports_attachments?(email_message)
    end

    test "character_limit/1" do
      sms_message = %Message{type: "sms"}
      mms_message = %Message{type: "mms"}
      email_message = %Message{type: "email"}
      invalid_message = %Message{type: "invalid"}

      assert Message.character_limit(sms_message) == 160
      assert Message.character_limit(mms_message) == 1600
      assert Message.character_limit(email_message) == 100_000
      assert Message.character_limit(invalid_message) == nil
    end

    test "format_timestamp/1" do
      message_with_timestamp = %Message{timestamp: ~N[2024-01-01 12:00:00.000000]}
      message_without_timestamp = %Message{timestamp: nil}

      assert Message.format_timestamp(message_with_timestamp) == "2024-01-01T12:00:00.000000Z"
      assert Message.format_timestamp(message_without_timestamp) == nil
    end
  end

  describe "associations" do
    test "has_many attachments association" do
      association = Message.__schema__(:association, :attachments)
      assert association.cardinality == :many
      assert association.field == :attachments
      assert association.related == MessagingService.Attachment
    end
  end
end
