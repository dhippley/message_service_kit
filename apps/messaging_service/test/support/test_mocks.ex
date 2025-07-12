defmodule MessagingService.TestMocks do
  @moduledoc """
  Mocks for testing the messaging service.
  """

  # Define mock modules for testing
  Mox.defmock(MessagingService.Providers.ProviderManagerMock, for: MessagingService.Providers.ProviderManager)
  Mox.defmock(MessagingService.MessagesMock, for: MessagingService.Messages)
end
