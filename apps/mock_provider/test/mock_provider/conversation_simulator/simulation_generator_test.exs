defmodule MockProvider.SimulationGeneratorTest do
  use ExUnit.Case, async: true

  alias MockProvider.SimulationGenerator

  describe "generate_chaos_scenario/0" do
    test "generates chaos scenario with correct structure" do
      scenario = SimulationGenerator.generate_chaos_scenario()

      assert scenario.name == "chaos"
      assert Map.has_key?(scenario, :participants)
      assert Map.has_key?(scenario, :messages)
      assert Map.has_key?(scenario.participants, :participant_a)
      assert Map.has_key?(scenario.participants, :participant_b)
      assert is_list(scenario.messages)
    end

    test "generates random phone numbers for participants" do
      scenario = SimulationGenerator.generate_chaos_scenario()

      assert String.starts_with?(scenario.participants.participant_a, "+1555")
      assert String.starts_with?(scenario.participants.participant_b, "+1555")
      assert scenario.participants.participant_a != scenario.participants.participant_b
    end

    test "generates between 4 and 12 messages" do
      scenario = SimulationGenerator.generate_chaos_scenario()

      message_count = length(scenario.messages)
      assert message_count >= 4
      assert message_count <= 12
    end

    test "multiple calls generate different scenarios" do
      scenario1 = SimulationGenerator.generate_chaos_scenario()
      scenario2 = SimulationGenerator.generate_chaos_scenario()

      # Should have different participants
      assert scenario1.participants.participant_a != scenario2.participants.participant_a
      assert scenario1.participants.participant_b != scenario2.participants.participant_b
    end
  end

  describe "generate_lotr_black_gate_scenario/0" do
    test "generates LOTR scenario with correct structure" do
      scenario = SimulationGenerator.generate_lotr_black_gate_scenario()

      assert scenario.name == "lotr_black_gate"
      assert Map.has_key?(scenario, :participants)
      assert Map.has_key?(scenario, :messages)
      assert Map.has_key?(scenario.participants, :gandalf)
      assert Map.has_key?(scenario.participants, :mouth_of_sauron)
      assert is_list(scenario.messages)
    end

    test "generates random phone numbers for participants" do
      scenario = SimulationGenerator.generate_lotr_black_gate_scenario()

      assert String.starts_with?(scenario.participants.gandalf, "+1555")
      assert String.starts_with?(scenario.participants.mouth_of_sauron, "+1555")
      assert scenario.participants.gandalf != scenario.participants.mouth_of_sauron
    end

    test "has correct number of messages" do
      scenario = SimulationGenerator.generate_lotr_black_gate_scenario()

      assert length(scenario.messages) == 8
    end

    test "messages have correct dialogue content" do
      scenario = SimulationGenerator.generate_lotr_black_gate_scenario()

      first_message = Enum.at(scenario.messages, 0)
      assert String.contains?(first_message.body, "Let the Lord of the Black Land come forth")

      second_message = Enum.at(scenario.messages, 1)
      assert String.contains?(second_message.body, "My master Sauron the Great bids thee welcome")
    end

    test "messages alternate between correct endpoints" do
      scenario = SimulationGenerator.generate_lotr_black_gate_scenario()

      gandalf_phone = scenario.participants.gandalf
      mouth_phone = scenario.participants.mouth_of_sauron

      # Check that Gandalf uses API and Mouth of Sauron uses webhook
      gandalf_messages = Enum.filter(scenario.messages, &(&1.from == gandalf_phone))
      mouth_messages = Enum.filter(scenario.messages, &(&1.from == mouth_phone))

      Enum.each(gandalf_messages, fn msg -> assert msg.endpoint == "api" end)
      Enum.each(mouth_messages, fn msg -> assert msg.endpoint == "webhook" end)
    end
  end

  describe "generate_ghostbusters_elevator_scenario/0" do
    test "generates Ghostbusters scenario with correct structure" do
      scenario = SimulationGenerator.generate_ghostbusters_elevator_scenario()

      assert scenario.name == "ghostbusters_elevator"
      assert Map.has_key?(scenario, :participants)
      assert Map.has_key?(scenario, :messages)
      assert Map.has_key?(scenario.participants, :ray)
      assert Map.has_key?(scenario.participants, :egon)
      assert Map.has_key?(scenario.participants, :peter)
      assert is_list(scenario.messages)
    end

    test "generates random phone numbers for participants" do
      scenario = SimulationGenerator.generate_ghostbusters_elevator_scenario()

      assert String.starts_with?(scenario.participants.ray, "+1555")
      assert String.starts_with?(scenario.participants.egon, "+1555")
      assert String.starts_with?(scenario.participants.peter, "+1555")

      # All participants should have different phone numbers
      phones = [
        scenario.participants.ray,
        scenario.participants.egon,
        scenario.participants.peter
      ]
      assert length(Enum.uniq(phones)) == 3
    end

    test "has correct number of messages" do
      scenario = SimulationGenerator.generate_ghostbusters_elevator_scenario()

      assert length(scenario.messages) == 7
    end

    test "messages have correct dialogue content" do
      scenario = SimulationGenerator.generate_ghostbusters_elevator_scenario()

      first_message = Enum.at(scenario.messages, 0)
      assert String.contains?(first_message.body, "we haven't had a completely successful test")

      blame_message = Enum.at(scenario.messages, 1)
      assert String.contains?(blame_message.body, "I blame myself")

      nuclear_message = Enum.at(scenario.messages, 4)
      assert String.contains?(nuclear_message.body, "unlicensed nuclear accelerator")
    end

    test "messages have appropriate delays" do
      scenario = SimulationGenerator.generate_ghostbusters_elevator_scenario()

      Enum.each(scenario.messages, fn message ->
        assert is_integer(message.delay)
        assert message.delay >= 0
        assert message.delay <= 3000
      end)
    end
  end
end
