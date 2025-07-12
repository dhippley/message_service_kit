defmodule MessagingService.Mailer do
  @moduledoc false
  use Swoosh.Mailer, otp_app: :messaging_service
end
