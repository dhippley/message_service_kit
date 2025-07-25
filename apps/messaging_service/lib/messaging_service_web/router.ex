defmodule MessagingServiceWeb.Router do
  use MessagingServiceWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MessagingServiceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug MessagingServiceWeb.Plugs.SetCurrentPath
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MessagingServiceWeb do
    pipe_through :browser

    # Redirect root to conversations
    get "/", Plugs.RedirectToConversations, []

    # LiveView routes
    live "/dashboard", DashboardLive, :index
    live "/conversations", ConversationLive.Index, :index
    live "/conversations/:id", ConversationLive.Show, :show
  end

  # Other scopes may use custom stacks.
  scope "/api", MessagingServiceWeb do
    pipe_through :api

    # Message sending endpoints
    post "/messages/sms", MessageController, :send_sms
    post "/messages/email", MessageController, :send_email

    # Conversation endpoints
    get "/conversations", ConversationController, :index
    get "/conversations/:id/messages", ConversationController, :show_messages

    # Webhook endpoints for receiving messages
    post "/webhooks/messages", WebhookController, :receive_message
    post "/webhooks/messages/batch", WebhookController, :receive_batch
    get "/webhooks/health", WebhookController, :health_check

    # Provider-specific inbound webhook endpoints
    post "/webhooks/sms", WebhookController, :receive_inbound_sms
    post "/webhooks/email", WebhookController, :receive_inbound_email
    post "/webhooks/twilio", WebhookController, :receive_twilio_webhook
    post "/webhooks/sendgrid", WebhookController, :receive_sendgrid_webhook

    # Telemetry endpoints
    get "/telemetry", TelemetryController, :api_docs
    get "/telemetry/health", TelemetryController, :health
    get "/telemetry/messages/overview", TelemetryController, :message_delivery_overview
    get "/telemetry/messages/:type", TelemetryController, :message_type_metrics
    get "/telemetry/stress-tests", TelemetryController, :stress_test_metrics
    get "/telemetry/trends", TelemetryController, :performance_trends
    get "/telemetry/queue", TelemetryController, :queue_metrics
    get "/telemetry/realtime", TelemetryController, :realtime_info
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
