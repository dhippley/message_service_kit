defmodule MockProviderTest do
  use ExUnit.Case
  doctest MockProvider

  test "greets the world" do
    assert MockProvider.hello() == :world
  end
end
