defmodule MessagingServiceWeb.Plugs.RedirectToConversations do
  @moduledoc """
  A plug that redirects the root path to /conversations
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> Phoenix.Controller.redirect(to: "/conversations")
    |> Plug.Conn.halt()
  end
end
