defmodule MockProviderTest do
  use ExUnit.Case, async: true

  doctest MockProvider

  describe "MockProvider" do
    test "returns correct port" do
      assert MockProvider.port() == 4001
    end

    test "returns correct base URL" do
      assert MockProvider.base_url() == "http://localhost:4001"
    end
  end
end
