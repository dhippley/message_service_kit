defmodule MessagingService.AttachmentsTest do
  use MessagingService.DataCase

  alias MessagingService.Attachments
  alias MessagingService.Attachment

  describe "attachments" do
    @valid_url_attrs %{
      url: "https://example.com/document.pdf",
      attachment_type: "document",
      filename: "document.pdf",
      content_type: "application/pdf",
      size: 1024
    }

    @valid_blob_attrs %{
      blob: <<1, 2, 3, 4, 5>>,
      attachment_type: "image",
      filename: "test.jpg",
      content_type: "image/jpeg"
    }

    @invalid_attrs %{url: nil, blob: nil, attachment_type: nil}

    def url_attachment_fixture(attrs \\ %{}) do
      {:ok, attachment} =
        attrs
        |> Enum.into(@valid_url_attrs)
        |> Attachments.create_url_attachment()

      attachment
    end

    def blob_attachment_fixture(attrs \\ %{}) do
      {:ok, attachment} =
        attrs
        |> Enum.into(@valid_blob_attrs)
        |> Attachments.create_blob_attachment()

      attachment
    end

    test "list_attachments/0 returns all attachments" do
      url_attachment = url_attachment_fixture()
      blob_attachment = blob_attachment_fixture()
      attachments = Attachments.list_attachments()

      assert length(attachments) == 2
      assert Enum.find(attachments, &(&1.id == url_attachment.id))
      assert Enum.find(attachments, &(&1.id == blob_attachment.id))
    end

    test "get_attachment!/1 returns the attachment with given id" do
      attachment = url_attachment_fixture()
      assert Attachments.get_attachment!(attachment.id) == attachment
    end

    test "get_attachment/1 returns the attachment with given id" do
      attachment = url_attachment_fixture()
      assert Attachments.get_attachment(attachment.id) == attachment
    end

    test "get_attachment/1 returns nil for non-existent id" do
      assert Attachments.get_attachment(Ecto.UUID.generate()) == nil
    end

    test "create_url_attachment/1 with valid data creates an attachment" do
      assert {:ok, %Attachment{} = attachment} =
               Attachments.create_url_attachment(@valid_url_attrs)

      assert attachment.url == @valid_url_attrs.url
      assert attachment.attachment_type == @valid_url_attrs.attachment_type
      assert attachment.filename == @valid_url_attrs.filename
      assert attachment.content_type == @valid_url_attrs.content_type
      assert attachment.size == @valid_url_attrs.size
    end

    test "create_blob_attachment/1 with valid data creates an attachment" do
      assert {:ok, %Attachment{} = attachment} =
               Attachments.create_blob_attachment(@valid_blob_attrs)

      assert attachment.blob == @valid_blob_attrs.blob
      assert attachment.attachment_type == @valid_blob_attrs.attachment_type
      assert attachment.filename == @valid_blob_attrs.filename
      assert attachment.content_type == @valid_blob_attrs.content_type
      assert attachment.size == byte_size(@valid_blob_attrs.blob)
      assert attachment.checksum != nil
    end

    test "create_url_attachment/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Attachments.create_url_attachment(@invalid_attrs)
    end

    test "create_blob_attachment/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Attachments.create_blob_attachment(@invalid_attrs)
    end

    test "update_attachment/2 with valid data updates the attachment" do
      attachment = url_attachment_fixture()
      update_attrs = %{filename: "updated_document.pdf"}

      assert {:ok, %Attachment{} = attachment} =
               Attachments.update_attachment(attachment, update_attrs)

      assert attachment.filename == "updated_document.pdf"
    end

    test "update_attachment/2 with invalid data returns error changeset" do
      attachment = url_attachment_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Attachments.update_attachment(attachment, @invalid_attrs)

      assert attachment == Attachments.get_attachment!(attachment.id)
    end

    test "delete_attachment/1 deletes the attachment" do
      attachment = url_attachment_fixture()
      assert {:ok, %Attachment{}} = Attachments.delete_attachment(attachment)
      assert_raise Ecto.NoResultsError, fn -> Attachments.get_attachment!(attachment.id) end
    end

    test "change_attachment/1 returns an attachment changeset" do
      attachment = url_attachment_fixture()
      assert %Ecto.Changeset{} = Attachments.change_attachment(attachment)
    end

    test "list_attachments_by_type/1 returns attachments of specific type" do
      url_attachment_fixture(%{attachment_type: "document"})
      blob_attachment_fixture(%{attachment_type: "image"})

      documents = Attachments.list_attachments_by_type("document")
      images = Attachments.list_attachments_by_type("image")

      assert length(documents) == 1
      assert length(images) == 1
      assert hd(documents).attachment_type == "document"
      assert hd(images).attachment_type == "image"
    end

    test "list_attachments_by_content_type/1 returns attachments of specific content type" do
      url_attachment_fixture(%{content_type: "application/pdf"})
      blob_attachment_fixture(%{content_type: "image/jpeg"})

      pdfs = Attachments.list_attachments_by_content_type("application/pdf")
      jpegs = Attachments.list_attachments_by_content_type("image/jpeg")

      assert length(pdfs) == 1
      assert length(jpegs) == 1
      assert hd(pdfs).content_type == "application/pdf"
      assert hd(jpegs).content_type == "image/jpeg"
    end

    test "get_total_attachment_size/0 returns total size of all attachments" do
      url_attachment_fixture(%{size: 1000})
      # This will auto-calculate size as 5 bytes
      blob_attachment_fixture()

      total_size = Attachments.get_total_attachment_size()
      assert Decimal.to_integer(total_size) == 1005
    end

    test "get_large_attachments/1 returns attachments larger than specified size" do
      small_attachment = url_attachment_fixture(%{size: 100})
      large_attachment = url_attachment_fixture(%{size: 2000})

      large_attachments = Attachments.get_large_attachments(500)

      assert length(large_attachments) == 1
      assert hd(large_attachments).id == large_attachment.id
      refute Enum.find(large_attachments, &(&1.id == small_attachment.id))
    end

    test "validate_attachment_exists/1 returns ok tuple for existing attachment" do
      attachment = url_attachment_fixture()
      assert {:ok, ^attachment} = Attachments.validate_attachment_exists(attachment.id)
    end

    test "validate_attachment_exists/1 returns error tuple for non-existent attachment" do
      assert {:error, :not_found} = Attachments.validate_attachment_exists(Ecto.UUID.generate())
    end

    test "cleanup_orphaned_attachments/0 returns success" do
      assert {:ok, 0} = Attachments.cleanup_orphaned_attachments()
    end
  end
end
