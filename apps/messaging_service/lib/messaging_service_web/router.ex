defmodule MessagingServiceWeb.Router do
  use MessagingServiceWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MessagingServiceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MessagingServiceWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  scope "/api", MessagingServiceWeb do
    pipe_through :api

    # Webhook endpoints for receiving messages
    post "/webhooks/messages", WebhookController, :receive_message
    post "/webhooks/messages/batch", WebhookController, :receive_batch
    get "/webhooks/health", WebhookController, :health_check

    # Mock provider endpoints that simulate external services
    post "/mock/twilio/sms", MockProviderController, :twilio_send_sms
    post "/mock/sendgrid/email", MockProviderController, :sendgrid_send_email
    post "/mock/generic/send", MockProviderController, :generic_send

    # Status and management endpoints
    get "/mock/:provider/status/:message_id", MockProviderController, :get_message_status
    get "/mock/:provider/messages", MockProviderController, :get_all_messages
    delete "/mock/:provider/messages", MockProviderController, :clear_messages
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:messaging_service, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MessagingServiceWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
