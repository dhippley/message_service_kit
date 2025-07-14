defmodule MessagingServiceWeb.Plugs.SetCurrentPath do
  @moduledoc """
  A plug that sets the current path in assigns for navigation state.
  This allows templates to determine which navigation item should be active.
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    Plug.Conn.assign(conn, :current_path, conn.request_path)
  end
end
