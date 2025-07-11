defmodule MessagingServiceWeb.Plugs.MessageAuthTest do
  use MessagingServiceWeb.ConnCase, async: true

  alias MessagingServiceWeb.Plugs.MessageAuth

  describe "bearer token authentication" do
    test "accepts valid bearer token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer dev-bearer-token-123")
        |> MessageAuth.call([])

      refute conn.halted
    end

    test "rejects invalid bearer token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")
        |> MessageAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "API key authentication" do
    test "accepts valid API key", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "ApiKey dev-api-key-123")
        |> MessageAuth.call([])

      refute conn.halted
    end

    test "rejects invalid API key", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "ApiKey invalid-key")
        |> MessageAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "basic authentication" do
    test "accepts valid basic auth", %{conn: conn} do
      valid_credentials = Base.encode64("webhook_user:dev_password_123")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{valid_credentials}")
        |> MessageAuth.call([])

      refute conn.halted
    end

    test "rejects invalid basic auth", %{conn: conn} do
      invalid_credentials = Base.encode64("invalid:credentials")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{invalid_credentials}")
        |> MessageAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "missing authentication" do
    test "rejects request without authorization header", %{conn: conn} do
      conn = MessageAuth.call(conn, [])

      assert conn.halted
      assert conn.status == 401

      response = json_response(conn, 401)
      assert response["error"] == "Authentication failed"
      assert response["reason"] == "Missing authorization header"
    end
  end

  describe "unsupported authentication" do
    test "rejects unsupported auth type", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Digest some-digest-value")
        |> MessageAuth.call([])

      assert conn.halted
      assert conn.status == 401

      response = json_response(conn, 401)
      assert response["reason"] == "Unsupported authorization type"
    end
  end
end
