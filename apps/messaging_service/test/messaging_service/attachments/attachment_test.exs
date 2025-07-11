defmodule MessagingService.AttachmentTest do
  use MessagingService.DataCase

  alias MessagingService.Attachment

  describe "changeset/2" do
    test "valid URL attachment" do
      attrs = %{
        url: "https://example.com/document.pdf",
        attachment_type: "document",
        filename: "document.pdf",
        content_type: "application/pdf",
        size: 1024
      }

      changeset = Attachment.url_changeset(%Attachment{}, attrs)
      assert changeset.valid?
    end

    test "valid blob attachment" do
      blob_data = <<1, 2, 3, 4, 5>>

      attrs = %{
        blob: blob_data,
        attachment_type: "image",
        filename: "test.jpg",
        content_type: "image/jpeg"
      }

      changeset = Attachment.blob_changeset(%Attachment{}, attrs)
      assert changeset.valid?
      # Size should be automatically calculated
      assert get_change(changeset, :size) == byte_size(blob_data)
      # Checksum should be automatically calculated
      assert get_change(changeset, :checksum) != nil
    end

    test "invalid when both URL and blob are provided" do
      attrs = %{
        url: "https://example.com/file.pdf",
        blob: <<1, 2, 3>>,
        attachment_type: "document"
      }

      changeset = Attachment.changeset(%Attachment{}, attrs)
      refute changeset.valid?
      assert "cannot have both URL and blob" in errors_on(changeset).url
      assert "cannot have both URL and blob" in errors_on(changeset).blob
    end

    test "invalid when neither URL nor blob are provided" do
      attrs = %{attachment_type: "document"}

      changeset = Attachment.changeset(%Attachment{}, attrs)
      refute changeset.valid?
      assert "must provide either URL or blob" in errors_on(changeset).url
      assert "must provide either URL or blob" in errors_on(changeset).blob
    end

    test "invalid attachment type" do
      attrs = %{
        url: "https://example.com/file.pdf",
        attachment_type: "invalid_type"
      }

      changeset = Attachment.url_changeset(%Attachment{}, attrs)
      refute changeset.valid?

      assert "must be one of: image, document, video, audio, archive, text, other" in errors_on(
               changeset
             ).attachment_type
    end

    test "invalid URL format" do
      attrs = %{
        url: "not-a-valid-url",
        attachment_type: "document"
      }

      changeset = Attachment.url_changeset(%Attachment{}, attrs)
      refute changeset.valid?
      assert "must be a valid HTTP or HTTPS URL" in errors_on(changeset).url
    end
  end

  describe "storage_type/1" do
    test "returns :url for URL-based attachments" do
      attachment = %Attachment{url: "https://example.com/file.pdf", blob: nil}
      assert Attachment.storage_type(attachment) == :url
    end

    test "returns :blob for blob-based attachments" do
      attachment = %Attachment{url: nil, blob: <<1, 2, 3>>}
      assert Attachment.storage_type(attachment) == :blob
    end

    test "returns :unknown for invalid attachments" do
      attachment = %Attachment{url: nil, blob: nil}
      assert Attachment.storage_type(attachment) == :unknown
    end
  end

  describe "human_size/1" do
    test "formats bytes correctly" do
      attachment = %Attachment{size: 512}
      assert Attachment.human_size(attachment) == "512 B"
    end

    test "formats kilobytes correctly" do
      # 1.5 KB
      attachment = %Attachment{size: 1536}
      assert Attachment.human_size(attachment) == "1.5 KB"
    end

    test "formats megabytes correctly" do
      # 1.5 MB
      attachment = %Attachment{size: 1_572_864}
      assert Attachment.human_size(attachment) == "1.5 MB"
    end

    test "handles nil size" do
      attachment = %Attachment{size: nil}
      assert Attachment.human_size(attachment) == "Unknown"
    end
  end

  describe "database insertion" do
    test "can insert URL-based attachment" do
      attrs = %{
        url: "https://example.com/document.pdf",
        attachment_type: "document",
        filename: "document.pdf",
        content_type: "application/pdf",
        size: 1024
      }

      changeset = Attachment.url_changeset(%Attachment{}, attrs)
      assert {:ok, attachment} = Repo.insert(changeset)
      assert attachment.url == attrs.url
      assert attachment.attachment_type == attrs.attachment_type
    end

    test "can insert blob-based attachment" do
      blob_data = <<1, 2, 3, 4, 5>>

      attrs = %{
        blob: blob_data,
        attachment_type: "image",
        filename: "test.jpg",
        content_type: "image/jpeg"
      }

      changeset = Attachment.blob_changeset(%Attachment{}, attrs)
      assert {:ok, attachment} = Repo.insert(changeset)
      assert attachment.blob == blob_data
      assert attachment.size == byte_size(blob_data)
      assert attachment.checksum != nil
    end
  end
end
