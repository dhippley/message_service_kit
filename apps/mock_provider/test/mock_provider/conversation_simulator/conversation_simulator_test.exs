defmodule MockProvider.ConversationSimulatorTest do
  use ExUnit.Case, async: false

  alias MockProvider.ConversationSimulator

  describe "list_scenarios/0" do
    test "returns all available scenarios" do
      scenarios = ConversationSimulator.list_scenarios()

      assert length(scenarios) == 3
      scenario_names = Enum.map(scenarios, & &1.name)
      assert "chaos" in scenario_names
      assert "lotr_black_gate" in scenario_names
      assert "ghostbusters_elevator" in scenario_names
    end

    test "each scenario has required fields" do
      scenarios = ConversationSimulator.list_scenarios()

      Enum.each(scenarios, fn scenario ->
        assert Map.has_key?(scenario, :name)
        assert Map.has_key?(scenario, :participants)
        assert Map.has_key?(scenario, :message_count)
        assert Map.has_key?(scenario, :description)
        assert is_binary(scenario.name)
        assert is_binary(scenario.description)
      end)
    end

    test "scenarios have correct descriptions and message counts" do
      scenarios = ConversationSimulator.list_scenarios()

      chaos_scenario = Enum.find(scenarios, &(&1.name == "chaos"))
      assert String.contains?(chaos_scenario.description, "Random participants")
      assert chaos_scenario.message_count == "5-10 random messages"

      lotr_scenario = Enum.find(scenarios, &(&1.name == "lotr_black_gate"))
      assert String.contains?(lotr_scenario.description, "Aragorn and the Mouth of Sauron")
      assert lotr_scenario.message_count == 10

      ghostbusters_scenario = Enum.find(scenarios, &(&1.name == "ghostbusters_elevator"))
      assert String.contains?(ghostbusters_scenario.description, "Ghostbusters elevator scene")
      assert ghostbusters_scenario.message_count == 7
    end
  end

  # Note: Simulation tests would require mocking HTTP requests to avoid actual network calls
  # For integration testing, those would be better suited in a separate integration test file
end
