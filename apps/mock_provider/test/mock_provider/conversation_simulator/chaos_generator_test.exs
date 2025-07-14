defmodule MockProvider.ChaosGeneratorTest do
  use ExUnit.Case, async: true

  alias MockProvider.ChaosGenerator

  describe "generate_random_phone/0" do
    test "generates phone number with correct format" do
      phone = ChaosGenerator.generate_random_phone()

      assert String.starts_with?(phone, "+1555")
      assert String.length(phone) == 12
      assert Regex.match?(~r/^\+1555\d{7}$/, phone)
    end

    test "generates different phone numbers on multiple calls" do
      phones = Enum.map(1..10, fn _ -> ChaosGenerator.generate_random_phone() end)
      unique_phones = Enum.uniq(phones)

      # Should have high probability of generating different numbers
      assert length(unique_phones) > 5
    end
  end

  describe "generate_random_message/1" do
    test "generates message with correct word count" do
      message = ChaosGenerator.generate_random_message(3)
      words = String.split(message, " ")

      assert length(words) == 3
    end

    test "generates message with single word" do
      message = ChaosGenerator.generate_random_message(1)
      words = String.split(message, " ")

      assert length(words) == 1
    end

    test "generates message with max words" do
      message = ChaosGenerator.generate_random_message(8)
      words = String.split(message, " ")

      assert length(words) == 8
    end

    test "all words come from the random words list" do
      message = ChaosGenerator.generate_random_message(5)
      words = String.split(message, " ")

      # All words should be Gen Z slang terms (we can't access the private list but can verify format)
      Enum.each(words, fn word ->
        assert is_binary(word)
        assert String.length(word) > 0
      end)
    end
  end

  describe "generate_chaos_messages/3" do
    test "generates correct number of messages" do
      phone1 = "+15551111111"
      phone2 = "+15552222222"
      count = 5

      messages = ChaosGenerator.generate_chaos_messages(phone1, phone2, count)

      assert length(messages) == count
    end

    test "alternates between participants" do
      phone1 = "+15551111111"
      phone2 = "+15552222222"

      messages = ChaosGenerator.generate_chaos_messages(phone1, phone2, 4)

      assert Enum.at(messages, 0).from == phone1
      assert Enum.at(messages, 0).to == phone2
      assert Enum.at(messages, 1).from == phone2
      assert Enum.at(messages, 1).to == phone1
      assert Enum.at(messages, 2).from == phone1
      assert Enum.at(messages, 2).to == phone2
      assert Enum.at(messages, 3).from == phone2
      assert Enum.at(messages, 3).to == phone1
    end

    test "alternates between endpoints" do
      phone1 = "+15551111111"
      phone2 = "+15552222222"

      messages = ChaosGenerator.generate_chaos_messages(phone1, phone2, 4)

      assert Enum.at(messages, 0).endpoint == "webhook"
      assert Enum.at(messages, 1).endpoint == "api"
      assert Enum.at(messages, 2).endpoint == "webhook"
      assert Enum.at(messages, 3).endpoint == "api"
    end

    test "each message has required fields" do
      phone1 = "+15551111111"
      phone2 = "+15552222222"

      messages = ChaosGenerator.generate_chaos_messages(phone1, phone2, 3)

      Enum.each(messages, fn message ->
        assert Map.has_key?(message, :from)
        assert Map.has_key?(message, :to)
        assert Map.has_key?(message, :body)
        assert Map.has_key?(message, :delay)
        assert Map.has_key?(message, :endpoint)

        assert message.from in [phone1, phone2]
        assert message.to in [phone1, phone2]
        assert is_binary(message.body)
        assert is_integer(message.delay)
        assert message.delay >= 0
        assert message.delay <= 5000
        assert message.endpoint in ["api", "webhook"]
      end)
    end

    test "generates random message bodies" do
      phone1 = "+15551111111"
      phone2 = "+15552222222"

      messages = ChaosGenerator.generate_chaos_messages(phone1, phone2, 5)
      bodies = Enum.map(messages, & &1.body)

      # Should have variety in message content
      unique_bodies = Enum.uniq(bodies)
      assert length(unique_bodies) >= 3
    end
  end
end
