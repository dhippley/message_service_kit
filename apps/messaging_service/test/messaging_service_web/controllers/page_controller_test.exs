defmodule MessagingServiceWeb.PageControllerTest do
  use MessagingServiceWeb.ConnCase

  test "GET / redirects to conversations", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/conversations"
  end
end
